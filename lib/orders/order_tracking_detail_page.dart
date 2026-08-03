// Các wrapper `@visibleForTesting` ở cuối file cố ý trả về kiểu private
// (`_TrackingPoints`, `_DriverProfile`): test chỉ nhận chúng qua suy kiểu
// (`final points = resolveTrackingPointsForTesting(...)`) và đọc field, không
// bao giờ viết tên kiểu ra, nên đây không phải rò rỉ API công khai.
// ignore_for_file: library_private_types_in_public_api

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../app/app_colors.dart';
import '../common/food_image.dart';
import '../checkout/checkout_models.dart';
import '../restaurant/dish_images.dart';
import 'order_state.dart';

enum _DeliveryPhase { toShop, waitingAtShop, toCustomer, arrived, delivered }

/// Ảnh chụp trạng thái chuyển động của tài xế tại một khung hình.
///
/// Được đẩy qua một [ValueNotifier] thay vì `setState` cả trang: bản đồ
/// (`FlutterMap`) nằm trong một `ListView` cùng nhiều card khác, gọi
/// `setState` ở tốc độ 60 khung/giây khiến cả cây widget — bao gồm cả
/// `FlutterMap` và `MapOptions` — bị dựng lại mỗi khung, làm bản đồ giật/đứng
/// hình và tài xế trông như không hề di chuyển. Với notifier, chỉ đúng lớp
/// polyline + marker vẽ lại mỗi khung.
@immutable
class _TrackingSnapshot {
  final List<LatLng> route;
  final LatLng driver;
  final double progress;
  final double bearingDegrees;

  const _TrackingSnapshot({
    required this.route,
    required this.driver,
    required this.progress,
    required this.bearingDegrees,
  });
}

class OrderTrackingDetailPage extends StatefulWidget {
  final OrderEntry entry;

  const OrderTrackingDetailPage({super.key, required this.entry});

  @override
  State<OrderTrackingDetailPage> createState() =>
      _OrderTrackingDetailPageState();
}

class _OrderTrackingDetailPageState extends State<OrderTrackingDetailPage>
        // `TickerProviderStateMixin` (số nhiều) chứ KHÔNG phải
        // `SingleTickerProviderStateMixin`: bản "Single" chỉ cho phép
        // `createTicker` đúng một lần trong cả vòng đời State — nó không đặt lại
        // slot nội bộ khi ticker cũ bị `dispose()`. Màn này phải tạo ticker mới
        // mỗi lần đổi chặng hoặc khi route thật tải xong (`_restartTimers`), nên
        // bản Single ném `multiple tickers were created` ngay lần restart đầu.
        with
        TickerProviderStateMixin {
  late final LatLng _shopPosition;
  late final LatLng _customerPosition;
  late LatLng _startDriverPosition;
  late List<LatLng> _driverToShopRoute;
  late List<LatLng> _shopToCustomerRoute;
  late List<LatLng> _activeRoute;
  late LatLng _driverPosition;

  /// Hồ sơ tài xế sinh ổn định từ chính đơn hàng này (xem [_driverProfileFor]).
  /// Mỗi đơn có một tài xế riêng — hai đơn khác nhau không bao giờ hiện cùng
  /// một tên/biển số, và mở lại cùng một đơn luôn ra đúng tài xế cũ.
  late final _DriverProfile _driverProfile;

  Timer? _waitTimer;
  Timer? _handoffTimer;

  /// Kênh đẩy vị trí tài xế xuống riêng phần bản đồ ở tốc độ khung hình.
  late final ValueNotifier<_TrackingSnapshot> _motion;

  /// Các card chữ (ETA / khoảng cách / mô tả trạng thái) chỉ cần cập nhật vài
  /// lần mỗi giây — làm mới ở nhịp này thay vì 60 lần/giây để không dựng lại
  /// cả `ListView` + `FlutterMap` mỗi khung hình.
  Timer? _textRefreshTimer;
  static const _textRefreshInterval = Duration(milliseconds: 250);

  /// Mô phỏng nhịp GPS thật: cứ mỗi [_gpsPingInterval] lại "chốt" một mốc vị
  /// trí mới ([_targetProgress]) dựa trên thời gian thật đã trôi qua so với
  /// [_phaseTotalDuration] (tính từ khoảng cách route thật / tốc độ trung
  /// bình) — nên quãng đường dài vẫn mất thời gian lâu hơn hợp lý.
  Timer? _pingTimer;

  /// Chạy mỗi khung hình: kéo vị trí HIỂN THỊ ([_phaseProgress]) tiến dần về
  /// mốc GPS mới nhất, mỗi tick chỉ đi khoảng [_chaseStepFraction] (~4-5%)
  /// quãng đường còn lại tới mốc đó — xe không bao giờ "nhảy cóc", luôn trượt
  /// mượt dọc theo polyline thật.
  Ticker? _renderTicker;
  Duration? _lastRenderTick;
  DateTime? _phaseStartedAt;
  Duration _phaseTotalDuration = Duration.zero;
  VoidCallback? _routeDone;

  _DeliveryPhase _phase = _DeliveryPhase.toShop;

  /// Vị trí hiển thị của tài xế dọc theo [_activeRoute], 0 = điểm đầu, 1 =
  /// điểm cuối. Đây là giá trị DUY NHẤT điều khiển marker, phần route đã đi
  /// (mờ dần) và ETA/khoảng cách hiển thị.
  double _phaseProgress = 0;

  /// Mốc GPS "thật" gần nhất — tiến đều theo thời gian thật, [_phaseProgress]
  /// luôn đuổi theo giá trị này chứ không bao giờ vượt qua.
  double _targetProgress = 0;

  /// Góc xoay xe máy (độ la bàn, 0 = hướng lên/Bắc) theo hướng di chuyển.
  double _driverBearingDegrees = 0;

  int _waitSeconds = 10;
  bool _nearbyNotified = false;
  bool _loadingRoadRoute = true;
  bool _trackingStarted = false;
  int _shopRating = 0;
  int _driverRating = 0;

  static const _averageSpeedKmh = 40.0;
  static const _minimumVisualRouteDuration = Duration(seconds: 80);
  static const _maximumVisualRouteDuration = Duration(seconds: 180);
  static const _gpsPingInterval = Duration(milliseconds: 1400);

  /// Mỗi tick hiển thị chỉ đi ~4.5% quãng đường còn lại tới mốc GPS mới nhất
  /// — nằm giữa dải 3-5% để chuyển động mượt, không teleport, và tự động
  /// chậm dần khi gần bắt kịp mốc (giống marker GPS thật trên các app giao
  /// đồ ăn).
  static const _chaseStepFraction = 0.045;
  static const _routeArrivalEpsilon = 0.0015;

  /// Sàn khoảng cách cho chặng tài xế -> quán, sau khi đã ghép route thật
  /// hoặc route dự phòng. Đặt gần bằng [_driverSpawnDistanceKm] để tài xế
  /// luôn xuất phát đủ xa quán — nhìn thấy rõ cả một đoạn "chỉ đường" đang
  /// chạy trên bản đồ, không phải một chấm nằm ngay sát quán.
  static const _minDriverToShopRouteKm = 0.85;

  /// Khung hình tham chiếu (60fps). Tốc độ "đuổi theo" mốc GPS được quy đổi
  /// theo thời gian thực (delta giữa hai tick) chứ không đếm số tick, nên
  /// máy yếu/khoẻ khác nhau vẫn thấy xe chạy nhanh chậm như nhau.
  static const _referenceFrameSeconds = 1 / 60;

  @override
  void initState() {
    super.initState();
    final points = _resolveTrackingPoints(widget.entry.order);
    _shopPosition = points.shop;
    _customerPosition = points.customer;
    _startDriverPosition = points.driver;
    _driverProfile = _driverProfileFor(_driverProfileSeedFor(widget.entry));
    _driverToShopRoute = _fallbackRoadRoute(
      _startDriverPosition,
      _shopPosition,
    );
    _driverToShopRoute = _ensureMinimumRouteDistance(
      _driverToShopRoute,
      _startDriverPosition,
      _shopPosition,
      _minDriverToShopRouteKm,
    );
    _startDriverPosition = _driverToShopRoute.first;
    _driverPosition = _startDriverPosition;
    _shopToCustomerRoute = _fallbackRoadRoute(_shopPosition, _customerPosition);
    _activeRoute = _driverToShopRoute;
    _driverBearingDegrees = _headingBearing(_activeRoute, 0);
    _shopRating = widget.entry.shopRating ?? 0;
    _driverRating = widget.entry.driverRating ?? 0;
    _motion = ValueNotifier<_TrackingSnapshot>(_snapshot());

    // Tài xế bắt đầu chạy NGAY trên route dự phòng, không đợi hai lời gọi
    // HTTP routing xong. Trước đây `_startMovingToShop` chỉ chạy sau khi cả
    // Geoapify lẫn OSRM trả về (hoặc hết timeout ~6-11s) — trên máy mạng chậm
    // hoặc không có mạng, người dùng nhìn thấy một tài xế đứng yên suốt quãng
    // đó và tưởng animation hỏng. Route thật tải xong sẽ được ghép vào sau
    // qua `_restartRouteMotion` mà không làm giật vị trí đang chạy.
    _trackingStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startMovingToShop();
    });

    _textRefreshTimer = Timer.periodic(_textRefreshInterval, (_) {
      if (!mounted) return;
      setState(() {});
    });

    _loadRoadRoutes();
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _renderTicker?.dispose();
    _waitTimer?.cancel();
    _handoffTimer?.cancel();
    _textRefreshTimer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  _TrackingSnapshot _snapshot() {
    return _TrackingSnapshot(
      route: _activeRoute,
      driver: _driverPosition,
      progress: _phaseProgress,
      bearingDegrees: _driverBearingDegrees,
    );
  }

  void _publishMotion() {
    if (!mounted) return;
    _motion.value = _snapshot();
  }

  Future<void> _loadRoadRoutes() async {
    final routes = await Future.wait([
      _fetchBestRoute(_startDriverPosition, _shopPosition),
      _fetchBestRoute(_shopPosition, _customerPosition),
    ]);
    final toShop = routes[0];
    final toCustomer = routes[1];
    if (!mounted) return;

    final nextToShop = toShop?.points ?? _driverToShopRoute;
    final nextToCustomer = toCustomer?.points ?? _shopToCustomerRoute;
    setState(() {
      _driverToShopRoute = _ensureMinimumRouteDistance(
        nextToShop,
        _startDriverPosition,
        _shopPosition,
        _minDriverToShopRouteKm,
      );
      _shopToCustomerRoute = nextToCustomer;
      _loadingRoadRoute = false;
      if (_phase == _DeliveryPhase.toShop) {
        _activeRoute = _driverToShopRoute;
      } else if (_phase == _DeliveryPhase.toCustomer) {
        _activeRoute = _shopToCustomerRoute;
      }
    });
    if (!_trackingStarted) {
      _trackingStarted = true;
      _startMovingToShop();
    } else if (_phase == _DeliveryPhase.toShop ||
        _phase == _DeliveryPhase.toCustomer) {
      _restartRouteMotion();
    } else {
      _publishMotion();
    }
  }

  void _startMovingToShop() {
    setState(() {
      _phase = _DeliveryPhase.toShop;
      _activeRoute = _driverToShopRoute;
    });
    _beginPhaseMotion(_arriveShop);
    _publishMotion();
  }

  void _arriveShop() {
    _stopPhaseMotion();
    _routeDone = null;
    setState(() {
      _phase = _DeliveryPhase.waitingAtShop;
      _driverPosition = _shopPosition;
      _phaseProgress = 1;
      _targetProgress = 1;
      _waitSeconds = 10;
    });
    _publishMotion();
    _showStatusPopup('Tài xế đã tới quán và đang lấy món');
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_waitSeconds <= 1) {
        timer.cancel();
        setState(() => _waitSeconds = 0);
        _handoffTimer = Timer(const Duration(seconds: 2), _startDelivering);
        return;
      }
      setState(() => _waitSeconds--);
    });
  }

  void _startDelivering() {
    if (!mounted) return;
    setState(() {
      _phase = _DeliveryPhase.toCustomer;
      _nearbyNotified = false;
      _driverPosition = _shopPosition;
      _activeRoute = _shopToCustomerRoute;
    });
    _showStatusPopup('Tài xế đang giao hàng cho bạn');
    _beginPhaseMotion(_arriveCustomer);
    _publishMotion();
  }

  void _arriveCustomer() {
    _stopPhaseMotion();
    _routeDone = null;
    setState(() {
      _phase = _DeliveryPhase.arrived;
      _driverPosition = _customerPosition;
      _phaseProgress = 1;
      _targetProgress = 1;
    });
    _publishMotion();
    Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() => _phase = _DeliveryPhase.delivered);
      if (widget.entry.id.isNotEmpty) {
        OrderState.markEntryDelivered(widget.entry.id);
      } else {
        OrderState.markDelivered(widget.entry.order);
      }
      _showStatusPopup('Đơn hàng của bạn đã được giao');
    });
  }

  /// Bắt đầu di chuyển từ đầu route hiện tại ([_activeRoute]) tới cuối route.
  void _beginPhaseMotion(VoidCallback onDone) {
    _routeDone = onDone;
    _phaseTotalDuration = _durationForRoute(_activeRoute);
    _phaseStartedAt = DateTime.now();
    _targetProgress = 0;
    _phaseProgress = 0;
    _driverPosition = _pointAt(_activeRoute, 0);
    _driverBearingDegrees = _headingBearing(_activeRoute, 0);
    _restartTimers();
  }

  /// Route thật tải xong SAU khi xe đã bắt đầu chạy trên route ước lượng:
  /// giữ nguyên % đã đi, chỉ đổi hình dạng đường bên dưới chân tài xế và
  /// tính lại thời lượng còn lại theo khoảng cách route mới.
  void _restartRouteMotion() {
    final progress = _phaseProgress.clamp(0.0, 0.98);
    _routeDone ??= _phase == _DeliveryPhase.toShop
        ? _arriveShop
        : _arriveCustomer;
    _phaseTotalDuration = _durationForRoute(_activeRoute);
    _phaseStartedAt = DateTime.now().subtract(_phaseTotalDuration * progress);
    _targetProgress = progress;
    _phaseProgress = progress;
    _driverPosition = _pointAt(_activeRoute, progress);
    _driverBearingDegrees = _headingBearing(_activeRoute, progress);
    _restartTimers();
    _publishMotion();
  }

  void _restartTimers() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_gpsPingInterval, (_) => _advanceGpsPing());
    _advanceGpsPing();

    _lastRenderTick = null;
    _renderTicker?.dispose();
    _renderTicker = createTicker(_onRenderTick)..start();
  }

  /// "Nhận tín hiệu GPS" mới: đẩy mốc mục tiêu theo đúng tỉ lệ thời gian thật
  /// đã trôi qua so với thời lượng cả chặng — quãng đường dài vẫn tiến chậm
  /// hơn quãng đường ngắn một cách hợp lý.
  void _advanceGpsPing() {
    if (!mounted || _phaseStartedAt == null) return;
    final elapsedMs = DateTime.now()
        .difference(_phaseStartedAt!)
        .inMilliseconds;
    final totalMs = _phaseTotalDuration.inMilliseconds;
    final fraction = totalMs <= 0 ? 1.0 : (elapsedMs / totalMs).clamp(0.0, 1.0);
    _targetProgress = fraction;
    if (fraction >= 1) {
      _pingTimer?.cancel();
    }
  }

  void _onRenderTick(Duration elapsed) {
    if (!mounted) {
      _renderTicker?.stop();
      return;
    }

    final previousTick = _lastRenderTick;
    _lastRenderTick = elapsed;
    final dtSeconds = previousTick == null
        ? _referenceFrameSeconds
        : (elapsed - previousTick).inMicroseconds /
              Duration.microsecondsPerSecond;
    final smoothing = _frameSmoothingFactor(
      dtSeconds,
      _chaseStepFraction,
      _referenceFrameSeconds,
    );

    final next = _chaseTowards(_phaseProgress, _targetProgress, smoothing);
    final reachedEnd =
        _targetProgress >= 1 && (1 - next) < _routeArrivalEpsilon;
    final resolvedNext = reachedEnd ? 1.0 : next;

    if ((resolvedNext - _phaseProgress).abs() > 1e-9) {
      _driverBearingDegrees = _headingBearing(_activeRoute, resolvedNext);
    }
    final nextPosition = _pointAt(_activeRoute, resolvedNext);

    // KHÔNG gọi `setState` ở đây: chỉ đẩy giá trị mới xuống notifier để riêng
    // lớp polyline/marker của bản đồ vẽ lại. Xem chú thích ở
    // [_TrackingSnapshot].
    _phaseProgress = resolvedNext;
    _driverPosition = nextPosition;
    _publishMotion();

    _maybeNotifyNearbyCustomer();

    if (reachedEnd) {
      _stopPhaseMotion();
      final done = _routeDone;
      _routeDone = null;
      done?.call();
    }
  }

  void _stopPhaseMotion() {
    _pingTimer?.cancel();
    _renderTicker?.stop();
  }

  void _maybeNotifyNearbyCustomer() {
    if (_phase != _DeliveryPhase.toCustomer || _nearbyNotified) return;
    if (_remainingKm <= 0.2) {
      _nearbyNotified = true;
      _showStatusPopup('Món của bạn sắp được giao, chuẩn bị nhận đơn nhé!');
    }
  }

  Future<_RoadRoute?> _fetchBestRoute(LatLng from, LatLng to) async {
    final geoapify = await _fetchGeoapifyRoute(from, to);
    if (geoapify != null) return geoapify;
    return _fetchOsrmRoute(from, to);
  }

  Duration _durationForRoute(List<LatLng> route) {
    final realMs = _routeDistanceKm(route) / _averageSpeedKmh * 3600 * 1000;
    return Duration(
      milliseconds: realMs.round().clamp(
        _minimumVisualRouteDuration.inMilliseconds,
        _maximumVisualRouteDuration.inMilliseconds,
      ),
    );
  }

  double get _activeRouteKm => _routeDistanceKm(_activeRoute);

  double get _remainingKm {
    final rawRemaining = _activeRouteKm * (1 - _phaseProgress);
    if (_phase == _DeliveryPhase.toShop &&
        rawRemaining <= 0.05 &&
        _phaseProgress < 0.95) {
      return _minDriverToShopRouteKm * (1 - _phaseProgress);
    }
    if (_phase == _DeliveryPhase.waitingAtShop) {
      return _routeDistanceKm(_shopToCustomerRoute);
    }
    if (_phase == _DeliveryPhase.arrived ||
        _phase == _DeliveryPhase.delivered) {
      return 0;
    }
    return rawRemaining;
  }

  int get _etaMinutes {
    if (_remainingKm <= 0.05) return 0;
    return math.max(1, (_remainingKm / _averageSpeedKmh * 60).ceil());
  }

  String get _phaseTitle {
    return switch (_phase) {
      _DeliveryPhase.toShop => 'Tài xế đang đến quán',
      _DeliveryPhase.waitingAtShop =>
        'Đợi quán chuẩn bị món $_waitSeconds giây',
      _DeliveryPhase.toCustomer => 'Tài xế đang giao hàng',
      _DeliveryPhase.arrived => 'Tài xế đã đến nơi',
      _DeliveryPhase.delivered => 'Đơn hàng đã giao thành công',
    };
  }

  String get _phaseSubtitle {
    return switch (_phase) {
      _DeliveryPhase.toShop =>
        'Tài xế đang di chuyển tới quán, còn ${_formatTrackingDistance(_remainingKm)}',
      _DeliveryPhase.waitingAtShop =>
        'Sau khi lấy món, lộ trình sẽ đổi về địa chỉ của bạn',
      _DeliveryPhase.toCustomer =>
        'Còn ${_formatTrackingDistance(_remainingKm)}, dự kiến $_etaMinutes phút',
      _DeliveryPhase.arrived => 'Tài xế đang bàn giao món cho bạn',
      _DeliveryPhase.delivered =>
        'Bạn có thể đánh giá quán và tài xế ở bên dưới',
    };
  }

  Future<void> _showStatusPopup(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1700),
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.entry.order;
    final firstItem = order.items.isEmpty ? null : order.items.first;
    final showDriver = _phase != _DeliveryPhase.delivered;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        toolbarHeight: 44,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leadingWidth: 42,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.primary,
            size: 18,
          ),
        ),
        title: const Text(
          'Theo dõi đơn hàng',
          style: TextStyle(
            color: Color(0xFF212121),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 18),
            children: [
              _MapCard(
                motion: _motion,
                shop: _shopPosition,
                customer: _customerPosition,
                phase: _phase,
                loadingRoadRoute: _loadingRoadRoute,
                etaMinutes: _etaMinutes,
                distanceKm: _remainingKm,
              ),
              const SizedBox(height: 8),
              _StatusCard(
                title: _phaseTitle,
                subtitle: _phaseSubtitle,
                etaMinutes: _etaMinutes,
                distanceKm: _remainingKm,
                driver: showDriver ? _driverProfile : null,
                onCallDriver: () => _showStatusPopup(
                  'Đang gọi ${_driverProfile.name} · ${_driverProfile.phone} (giả lập)',
                ),
                onChatDriver: () => _showStatusPopup(
                  'Mở trò chuyện với ${_driverProfile.name}... (giả lập)',
                ),
              ),
              const SizedBox(height: 8),
              _OrderSummaryCard(order: order, firstItem: firstItem),
              if (_phase == _DeliveryPhase.delivered) ...[
                const SizedBox(height: 8),
                _RatingCard(
                  shopRating: _shopRating,
                  driverRating: _driverRating,
                  onShopRatingChanged: (value) {
                    setState(() => _shopRating = value);
                    _persistRatingIfComplete();
                  },
                  onDriverRatingChanged: (value) {
                    setState(() => _driverRating = value);
                    _persistRatingIfComplete();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _persistRatingIfComplete() {
    if (_shopRating == 0 || _driverRating == 0) return;
    if (widget.entry.id.isNotEmpty) {
      OrderState.rateEntry(
        entryId: widget.entry.id,
        shopRating: _shopRating,
        driverRating: _driverRating,
      );
    } else {
      OrderState.rateOrder(
        restaurantId: widget.entry.order.restaurant.id,
        shopRating: _shopRating,
        driverRating: _driverRating,
      );
    }
  }
}

class _MapCard extends StatefulWidget {
  final ValueListenable<_TrackingSnapshot> motion;
  final LatLng shop;
  final LatLng customer;
  final _DeliveryPhase phase;
  final bool loadingRoadRoute;
  final int etaMinutes;
  final double distanceKm;

  const _MapCard({
    required this.motion,
    required this.shop,
    required this.customer,
    required this.phase,
    required this.loadingRoadRoute,
    required this.etaMinutes,
    required this.distanceKm,
  });

  @override
  State<_MapCard> createState() => _MapCardState();
}

class _MapCardState extends State<_MapCard> {
  final MapController _controller = MapController();

  /// Dựng MỘT LẦN duy nhất. `MapOptions` mới ở mỗi lần build sẽ khiến
  /// `FlutterMap` coi như cấu hình đã đổi và đặt lại camera theo
  /// `initialCameraFit` — với một trang tự vẽ lại liên tục thì bản đồ bị ghim
  /// cứng, tài xế trông như đứng yên. Sau lần fit đầu, camera chỉ đổi khi
  /// route đổi chặng hoặc người dùng bấm nút định vị lại.
  late final MapOptions _options;
  bool _mapReady = false;
  List<LatLng>? _fittedRoute;

  @override
  void initState() {
    super.initState();
    _fittedRoute = widget.motion.value.route;
    _options = MapOptions(
      initialCameraFit: CameraFit.coordinates(
        coordinates: _cameraTargets(widget.motion.value),
        padding: const EdgeInsets.fromLTRB(28, 48, 28, 54),
      ),
      minZoom: 5,
      maxZoom: 19,
      onMapReady: () {
        _mapReady = true;
        _fittedRoute = widget.motion.value.route;
      },
    );
    widget.motion.addListener(_onMotionChanged);
  }

  @override
  void didUpdateWidget(covariant _MapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.motion, widget.motion)) {
      oldWidget.motion.removeListener(_onMotionChanged);
      widget.motion.addListener(_onMotionChanged);
    }
  }

  @override
  void dispose() {
    widget.motion.removeListener(_onMotionChanged);
    super.dispose();
  }

  /// Khi đổi chặng (tài xế -> quán, rồi quán -> khách) thì route là một danh
  /// sách khác hẳn: fit lại camera đúng một lần cho chặng mới.
  void _onMotionChanged() {
    if (!_mapReady) return;
    final route = widget.motion.value.route;
    if (identical(route, _fittedRoute)) return;
    _fittedRoute = route;
    // Hoãn sang sau khung hình hiện tại: listener này có thể chạy ngay trong
    // pha dựng/animation của frame, đổi camera lúc đó dễ gây assert.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fitCamera(widget.motion.value);
    });
  }

  List<LatLng> _cameraTargets(_TrackingSnapshot snapshot) {
    return <LatLng>[
      ...snapshot.route,
      snapshot.driver,
      widget.shop,
      widget.customer,
    ];
  }

  void _fitCamera(_TrackingSnapshot snapshot) {
    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: _cameraTargets(snapshot),
        padding: const EdgeInsets.fromLTRB(28, 48, 28, 54),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4F7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: _options,
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.shopeefood',
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: widget.customer,
                    radius: 200,
                    useRadiusInMeter: true,
                    color: const Color(0xFF2196F3).withValues(alpha: 0.12),
                    borderColor: const Color(
                      0xFF2196F3,
                    ).withValues(alpha: 0.42),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),
              // Chỉ hai lớp này vẽ lại theo từng khung hình — phần còn lại của
              // bản đồ (tile, vòng tròn khách, các chip) đứng yên.
              ValueListenableBuilder<_TrackingSnapshot>(
                valueListenable: widget.motion,
                builder: (context, snapshot, _) {
                  final remainingRoute = _remainingRoute(
                    snapshot.route,
                    snapshot.progress,
                  );
                  return PolylineLayer(
                    polylines: [
                      // Toàn bộ tuyến đường — phải nhìn rõ là "vạch chỉ đường"
                      // ngay từ đầu (kể cả trước khi tài xế bắt đầu chạy), nên
                      // dùng màu xám đậm có viền trắng dày thay vì gần như
                      // trong suốt. Phần tài xế đã đi qua sẽ lộ ra lớp này —
                      // nhạt hơn hẳn đoạn còn lại — nên vẫn có cảm giác "biến
                      // mất dần" mà không bị vô hình trên nền bản đồ sáng màu.
                      Polyline(
                        points: snapshot.route,
                        strokeWidth: 6,
                        color: const Color(0xFF78909C).withValues(alpha: 0.55),
                        borderColor: Colors.white,
                        borderStrokeWidth: 2.5,
                      ),
                      // Đoạn còn lại, vẽ đè lên bằng màu chính, dày và có viền
                      // trắng rõ để nổi bật trên mọi loại nền tile bản đồ.
                      if (remainingRoute.length > 1)
                        Polyline(
                          points: remainingRoute,
                          strokeWidth: 7,
                          color: AppColors.primary,
                          borderColor: Colors.white,
                          borderStrokeWidth: 3,
                        ),
                    ],
                  );
                },
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.customer,
                    width: 36,
                    height: 36,
                    child: const _CurrentLocationDot(),
                  ),
                  Marker(
                    point: widget.shop,
                    width: 38,
                    height: 48,
                    child: const _MapPin(
                      color: AppColors.success,
                      icon: Icons.storefront_rounded,
                      label: 'Quán',
                    ),
                  ),
                ],
              ),
              // Marker tài xế tách thành một lớp riêng để chỉ nó vẽ lại theo
              // từng khung hình, không kéo theo hai marker tĩnh phía trên.
              ValueListenableBuilder<_TrackingSnapshot>(
                valueListenable: widget.motion,
                builder: (context, snapshot, _) {
                  return MarkerLayer(
                    markers: [
                      Marker(
                        point: snapshot.driver,
                        width: 52,
                        height: 52,
                        child: _DriverMarker(
                          bearingDegrees: snapshot.bearingDegrees,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          Positioned(
            left: 8,
            top: 8,
            child: _MapInfoChip(
              title: switch (widget.phase) {
                _DeliveryPhase.toShop => 'Tài xế tới quán',
                _DeliveryPhase.waitingAtShop => 'Đang lấy món',
                _ => 'Giao tới bạn',
              },
              subtitle: widget.etaMinutes == 0
                  ? 'Sắp đến'
                  : '${widget.etaMinutes} phút',
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: _DistanceChip(distanceKm: widget.distanceKm),
          ),
          Positioned(
            right: 10,
            bottom: 14,
            child: FloatingActionButton.small(
              heroTag: 'tracking-recenter-map',
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF212121),
              onPressed: () => _fitCamera(widget.motion.value),
              child: const Icon(Icons.my_location_rounded, size: 20),
            ),
          ),
          // Trong lúc chờ route thật, tài xế ĐÃ chạy trên route dự phòng nên
          // không che mờ cả bản đồ nữa (lớp phủ trắng cũ làm vạch chỉ đường
          // gần như biến mất) — chỉ hiện một badge nhỏ ở dưới.
          if (widget.loadingRoadRoute)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 46,
              child: Center(child: _RouteLoadingBadge()),
            ),
          Positioned(
            left: 8,
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                child: Text(
                  'OpenStreetMap',
                  style: TextStyle(
                    color: Color(0xFF616161),
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapInfoChip extends StatelessWidget {
  final String title;
  final String subtitle;

  const _MapInfoChip({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.delivery_dining_rounded,
              color: AppColors.primary,
              size: 16,
            ),
            const SizedBox(width: 5),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF212121),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DistanceChip extends StatelessWidget {
  final double distanceKm;

  const _DistanceChip({required this.distanceKm});

  @override
  Widget build(BuildContext context) {
    final label = distanceKm < 1
        ? '${(distanceKm * 1000).round()}m'
        : '${distanceKm.toStringAsFixed(1)}km';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF212121),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// Icon xe máy xoay theo hướng di chuyển thật ([bearingDegrees], độ la bàn —
/// 0 = hướng icon mặc định, tức "lên/Bắc"). Không bọc icon trong nền tròn:
/// chỉ có một chấm trạng thái (online) nhỏ đứng yên ở góc, không xoay theo xe
/// để luôn dễ nhìn.
class _DriverMarker extends StatelessWidget {
  final double bearingDegrees;

  const _DriverMarker({required this.bearingDegrees});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Chỉ hình xe xoay theo hướng đi; chấm trạng thái bên dưới đứng yên.
        Transform.rotate(
          angle: bearingDegrees * math.pi / 180,
          child: const CustomPaint(
            size: Size(52, 52),
            painter: _TopDownBikePainter(),
          ),
        ),
        Positioned(
          right: 6,
          top: 7,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

/// Marker tài xế nhìn từ trên xuống (top-down), kiểu các app giao đồ ăn/gọi
/// xe thật: thân xe bo tròn màu xanh navy, tay lái + người lái màu vàng, viền
/// trắng để nổi trên mọi nền tile bản đồ.
///
/// Vẽ bằng [CustomPainter] thay vì dùng icon Material: bộ Material không có
/// icon xe máy nhìn từ trên xuống ([Icons.two_wheeler_rounded] là hình nhìn
/// ngang), mà hình nhìn ngang thì xoay theo hướng đi trông rất sai. Vẽ tay
/// cũng tránh phải thêm asset ảnh vào `pubspec.yaml`.
///
/// Hệ toạ độ: mũi xe hướng lên trên (góc 0° = hướng Bắc), khớp với
/// [_headingBearing] nên `Transform.rotate` bằng đúng bearing là ra hướng thật.
class _TopDownBikePainter extends CustomPainter {
  const _TopDownBikePainter();

  static const _bodyColor = Color(0xFF16386F);
  static const _accentColor = Color(0xFFFFC02E);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Bóng đổ mềm để marker không "dính" vào mặt bản đồ.
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 2.5), width: 24, height: 34),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    final white = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = Colors.white;

    // Thân xe.
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 17, height: 32),
      const Radius.circular(8.5),
    );
    canvas.drawRRect(body, Paint()..color = _bodyColor);
    canvas.drawRRect(body, white);

    // Tay lái ở phía trước (mũi xe).
    final handlebar = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center.translate(0, -8), width: 26, height: 6),
      const Radius.circular(3),
    );
    canvas.drawRRect(handlebar, Paint()..color = _accentColor);
    canvas.drawRRect(handlebar, white..strokeWidth = 1.8);

    // Người lái / yên xe.
    final rider = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center.translate(0, 3.5), width: 13, height: 16),
      const Radius.circular(6.5),
    );
    canvas.drawRRect(rider, Paint()..color = _accentColor);

    // Mũ bảo hiểm.
    canvas.drawCircle(
      center.translate(0, -1),
      4.4,
      Paint()..color = _bodyColor,
    );
    canvas.drawCircle(center.translate(0, -1), 4.4, white..strokeWidth = 1.6);
  }

  @override
  bool shouldRepaint(covariant _TopDownBikePainter oldDelegate) => false;
}

class _RouteLoadingBadge extends StatelessWidget {
  const _RouteLoadingBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 7),
            Text(
              'Đang tính đường thật...',
              style: TextStyle(
                color: Color(0xFF212121),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;

  const _MapPin({required this.color, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.28),
                blurRadius: 8,
                spreadRadius: 1.5,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF212121),
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _CurrentLocationDot extends StatelessWidget {
  const _CurrentLocationDot();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2196F3).withValues(alpha: 0.30),
              blurRadius: 10,
              spreadRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int etaMinutes;
  final double distanceKm;
  final _DriverProfile? driver;
  final VoidCallback? onCallDriver;
  final VoidCallback? onChatDriver;

  const _StatusCard({
    required this.title,
    required this.subtitle,
    required this.etaMinutes,
    required this.distanceKm,
    this.driver,
    this.onCallDriver,
    this.onChatDriver,
  });

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0ED),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delivery_dining_rounded,
                  color: AppColors.primary,
                  size: 19,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF212121),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF757575),
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTrackingDistance(distanceKm),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    etaMinutes == 0
                        ? distanceKm <= 0.005
                              ? 'đã đến'
                              : 'sắp đến'
                        : '$etaMinutes phút',
                    style: const TextStyle(
                      color: Color(0xFF757575),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (driver != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 9),
              child: Divider(height: 1, color: Color(0xFFF0F0F0)),
            ),
            _DriverRow(
              driver: driver!,
              onCall: onCallDriver,
              onChat: onChatDriver,
            ),
          ],
        ],
      ),
    );
  }
}

/// Hàng thông tin tài xế: avatar, tên, sao đánh giá, biển số, và hai nút
/// gọi/chat giả lập — giống bố cục card theo dõi đơn của ShopeeFood thật.
class _DriverRow extends StatelessWidget {
  final _DriverProfile driver;
  final VoidCallback? onCall;
  final VoidCallback? onChat;

  const _DriverRow({required this.driver, this.onCall, this.onChat});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: Color(0xFFF0F0F0),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_rounded,
            color: Color(0xFF9E9E9E),
            size: 19,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                driver.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF212121),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFB300),
                    size: 12,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    driver.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Color(0xFF757575),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      driver.plate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        _DriverActionButton(
          icon: Icons.call_rounded,
          background: AppColors.success,
          onTap: onCall,
        ),
        const SizedBox(width: 6),
        _DriverActionButton(
          icon: Icons.chat_bubble_rounded,
          background: AppColors.primary,
          onTap: onChat,
        ),
      ],
    );
  }
}

class _DriverActionButton extends StatelessWidget {
  final IconData icon;
  final Color background;
  final VoidCallback? onTap;

  const _DriverActionButton({
    required this.icon,
    required this.background,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final CheckoutOrder order;
  final CartItem? firstItem;

  const _OrderSummaryCard({required this.order, required this.firstItem});

  @override
  Widget build(BuildContext context) {
    // Gán ra biến local: field public `firstItem` không được promote sang
    // non-null nên mỗi lần dùng lại phải thêm `!`.
    final item = firstItem;
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.restaurant.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF212121),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          if (item != null)
            Row(
              children: [
                _FoodThumb(path: item.imageUrl, label: item.name),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF212121),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${order.itemCount} món | ${order.paymentMethod}',
                        style: const TextStyle(
                          color: Color(0xFF757575),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        order.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF9E9E9E),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  checkoutFormatPrice(order.total),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  final int shopRating;
  final int driverRating;
  final ValueChanged<int> onShopRatingChanged;
  final ValueChanged<int> onDriverRatingChanged;

  const _RatingCard({
    required this.shopRating,
    required this.driverRating,
    required this.onShopRatingChanged,
    required this.onDriverRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Đánh giá đơn hàng',
            style: TextStyle(
              color: Color(0xFF212121),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _RatingRow(
            label: 'Đánh giá quán',
            value: shopRating,
            onChanged: onShopRatingChanged,
          ),
          const SizedBox(height: 8),
          _RatingRow(
            label: 'Đánh giá tài xế',
            value: driverRating,
            onChanged: onDriverRatingChanged,
          ),
        ],
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _RatingRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF424242),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (var i = 1; i <= 5; i++)
          InkWell(
            onTap: () => onChanged(i),
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                i <= value ? Icons.star_rounded : Icons.star_border_rounded,
                color: const Color(0xFFFFB300),
                size: 21,
              ),
            ),
          ),
      ],
    );
  }
}

class _WhiteCard extends StatelessWidget {
  final Widget child;

  const _WhiteCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: child,
    );
  }
}

class _FoodThumb extends StatelessWidget {
  final String path;
  final String label;

  const _FoodThumb({required this.path, required this.label});

  @override
  Widget build(BuildContext context) {
    return FoodImage(
      source: DishImages.normalize(label: label, imageUrl: path),
      label: label,
      width: 48,
      height: 48,
      radius: 6,
      showLabel: false,
    );
  }
}

class _TrackingPoints {
  final LatLng driver;
  final LatLng shop;
  final LatLng customer;

  const _TrackingPoints({
    required this.driver,
    required this.shop,
    required this.customer,
  });
}

class _RoadRoute {
  final List<LatLng> points;

  /// 'geoapify' | 'osrm' — nguồn API đã trả về route này (giữ lại để log/gỡ
  /// lỗi và cho khả năng mở rộng sau).
  final String source;

  const _RoadRoute({required this.points, required this.source});
}

class _RouteNode {
  final LatLng point;
  final List<int> neighbors;

  const _RouteNode(this.point, this.neighbors);
}

/// Hồ sơ tài xế giả lập cho MỘT đơn hàng cụ thể — xem [_driverProfileFor].
class _DriverProfile {
  final String name;
  final String phone;
  final String plate;
  final double rating;

  const _DriverProfile({
    required this.name,
    required this.phone,
    required this.plate,
    required this.rating,
  });
}

const _driverNamePool = <String>[
  'Nguyễn Văn Long',
  'Trần Minh Khoa',
  'Lê Hoàng Phúc',
  'Phạm Anh Tuấn',
  'Đỗ Quang Huy',
  'Vũ Thành Đạt',
  'Hoàng Gia Bảo',
  'Bùi Xuân Sơn',
  'Ngô Đức Thịnh',
  'Đặng Công Minh',
  'Trịnh Bảo Long',
  'Lý Trung Kiên',
];

/// Khoá ổn định để sinh hồ sơ tài xế cho một đơn — ưu tiên `entry.id` (luôn
/// có khi đơn đã tạo qua [OrderState]); rơi về tổ hợp thông tin quán/khách
/// khi đơn không có id (dữ liệu cũ). Hai đơn khác nhau gần như chắc chắn ra
/// hai khoá khác nhau, nên KHÔNG có chuyện mọi đơn cùng hiện một tài xế.
String _driverProfileSeedFor(OrderEntry entry) {
  if (entry.id.isNotEmpty) return entry.id;
  final order = entry.order;
  return '${order.restaurant.id}-${order.receiverPhone}-${order.address}';
}

_DriverProfile _driverProfileFor(String seed) {
  final hash = _stableHash(seed);
  final name = _driverNamePool[hash % _driverNamePool.length];
  final province = 43 + hash % 55;
  final seriesLetter = String.fromCharCode(65 + (hash ~/ 7) % 26);
  final seriesDigit = 1 + (hash ~/ 11) % 9;
  final serialA = 100 + (hash ~/ 13) % 900;
  final serialB = 10 + (hash ~/ 17) % 90;
  final plate = '$province$seriesLetter$seriesDigit-$serialA.$serialB';
  final phoneBody = 10000000 + (hash ~/ 3) % 90000000;
  final phone = '09$phoneBody';
  final rating = 4.5 + (hash % 5) / 10;
  return _DriverProfile(name: name, phone: phone, plate: plate, rating: rating);
}

int _stableHash(String value) {
  var hash = 0x811C9DC5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

_TrackingPoints _resolveTrackingPoints(CheckoutOrder order) {
  final restaurant = order.restaurant;
  final shop = LatLng(
    _validCoordinate(restaurant.latitude) ? restaurant.latitude! : 10.7843,
    _validCoordinate(restaurant.longitude) ? restaurant.longitude! : 106.5682,
  );

  final fallbackCustomer = _offsetPoint(
    shop,
    math.max(0.7, restaurant.distanceKm),
    130 + restaurant.id.hashCode.abs() % 50,
  );
  final customer = LatLng(
    _validCoordinate(order.deliveryLatitude)
        ? order.deliveryLatitude!
        : fallbackCustomer.latitude,
    _validCoordinate(order.deliveryLongitude)
        ? order.deliveryLongitude!
        : fallbackCustomer.longitude,
  );

  final driver = _offsetPoint(
    shop,
    _driverSpawnDistanceKm + (restaurant.id.hashCode.abs() % 12) / 100,
    250 + restaurant.id.hashCode.abs() % 70,
  );

  return _TrackingPoints(driver: driver, shop: shop, customer: customer);
}

/// Khoảng cách tài xế xuất phát cách quán khi bắt đầu theo dõi đơn (~0.95km
/// đến ~1.07km tuỳ đơn, lệch nhẹ theo hash id quán để mỗi đơn spawn một
/// điểm khác nhau). Mở màn hình lên là thấy ngay một đoạn đường + tài xế
/// đang chạy tới quán, không phải một chấm đứng sát ngay quán.
const _driverSpawnDistanceKm = 0.95;

bool _validCoordinate(double? value) => value != null && value.abs() > 0.001;

const _geoapifyRoutingApiKey = String.fromEnvironment('GEOAPIFY_API_KEY');

/// Ưu tiên #1: Geoapify Routing API (dùng khi project đã build kèm
/// `--dart-define=GEOAPIFY_API_KEY=...`, xem `tools/run_app_with_maps_key.ps1`).
/// Cho ra tuyến đường thật theo hướng đi xe máy.
Future<_RoadRoute?> _fetchGeoapifyRoute(LatLng from, LatLng to) async {
  if (_geoapifyRoutingApiKey.trim().isEmpty) return null;

  final uri = Uri.https('api.geoapify.com', '/v1/routing', {
    'waypoints':
        '${from.latitude},${from.longitude}|${to.latitude},${to.longitude}',
    'mode': 'motorcycle',
    'apiKey': _geoapifyRoutingApiKey,
  });

  try {
    final response = await http.get(uri).timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) return null;
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final features = payload['features'] as List<dynamic>?;
    if (features == null || features.isEmpty) return null;
    final geometry =
        (features.first as Map<String, dynamic>)['geometry']
            as Map<String, dynamic>?;
    final points = _flattenLngLatCoordinates(geometry?['coordinates']);
    if (points.length < 2) return null;
    return _RoadRoute(
      points: _normalizeRoadRoute(from, to, points),
      source: 'geoapify',
    );
  } catch (error) {
    debugPrint('[Tracking] Geoapify routing lỗi: $error');
    return null;
  }
}

/// Ưu tiên #2: OSRM public router (miễn phí, không cần key) khi không có
/// Geoapify key hoặc Geoapify lỗi/hết hạn mức.
Future<_RoadRoute?> _fetchOsrmRoute(LatLng from, LatLng to) async {
  final uri = Uri.https(
    'router.project-osrm.org',
    '/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}',
    {'overview': 'full', 'geometries': 'geojson', 'steps': 'false'},
  );

  try {
    final response = await http.get(uri).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return null;
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = payload['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return null;
    final geometry = routes.first['geometry'] as Map<String, dynamic>?;
    final points = _flattenLngLatCoordinates(geometry?['coordinates']);
    if (points.length < 2) return null;
    return _RoadRoute(
      points: _normalizeRoadRoute(from, to, points),
      source: 'osrm',
    );
  } catch (error) {
    debugPrint('[Tracking] OSRM routing lỗi: $error');
    return null;
  }
}

/// Đệ quy phẳng hoá toạ độ GeoJSON dạng `[lon, lat]`. Chấp nhận cả
/// `LineString` (`[[lon,lat],...]`) lẫn `MultiLineString`
/// (`[[[lon,lat],...],...]`) vì OSRM và Geoapify không trả cùng cấu trúc lồng.
List<LatLng> _flattenLngLatCoordinates(dynamic node) {
  final points = <LatLng>[];
  void visit(dynamic value) {
    if (value is List &&
        value.length >= 2 &&
        value[0] is num &&
        value[1] is num) {
      points.add(
        LatLng((value[1] as num).toDouble(), (value[0] as num).toDouble()),
      );
      return;
    }
    if (value is List) {
      for (final child in value) {
        visit(child);
      }
    }
  }

  visit(node);
  return points;
}

/// Route dự phòng khi cả hai API routing đều lỗi/không có mạng: KHÔNG bao giờ
/// là đường thẳng — dựng một lưới điểm trung gian lệch hai bên trục
/// start->end rồi tìm đường đi ngắn nhất (Dijkstra) qua lưới đó, cho ra một
/// tuyến có khúc rẽ hợp lý thay vì một mũi tên thẳng tắp.
List<LatLng> _fallbackRoadRoute(LatLng start, LatLng end) {
  final midA = LatLng(
    start.latitude,
    _lerp(start.longitude, end.longitude, 0.35),
  );
  final midB = LatLng(
    _lerp(start.latitude, end.latitude, 0.45),
    midA.longitude,
  );
  final midC = LatLng(
    midB.latitude,
    _lerp(start.longitude, end.longitude, 0.72),
  );
  final midD = LatLng(
    _lerp(start.latitude, end.latitude, 0.78),
    midC.longitude,
  );

  final nodes = <_RouteNode>[
    _RouteNode(start, const [2]),
    _RouteNode(end, const [5]),
    _RouteNode(midA, const [0, 3, 6]),
    _RouteNode(midB, const [2, 4, 7]),
    _RouteNode(midC, const [3, 5, 8]),
    _RouteNode(midD, const [1, 4]),
    _RouteNode(
      LatLng(_lerp(start.latitude, end.latitude, 0.18), start.longitude),
      const [2, 7],
    ),
    _RouteNode(
      LatLng(
        _lerp(start.latitude, end.latitude, 0.50),
        _lerp(start.longitude, end.longitude, 0.55),
      ),
      const [3, 6, 8],
    ),
    _RouteNode(
      LatLng(end.latitude, _lerp(start.longitude, end.longitude, 0.80)),
      const [4, 7, 5],
    ),
  ];

  return _densifyRoute(_shortestPath(nodes, 0, 1), minPointCount: 42);
}

List<LatLng> _normalizeRoadRoute(
  LatLng start,
  LatLng end,
  List<LatLng> roadPoints,
) {
  if (roadPoints.length < 2) {
    return _fallbackRoadRoute(start, end);
  }

  final route = <LatLng>[start, ...roadPoints, end];
  return _densifyRoute(route, minPointCount: 64);
}

List<LatLng> _densifyRoute(List<LatLng> route, {int minPointCount = 21}) {
  if (route.length >= minPointCount) return route;
  return [
    for (var index = 0; index < minPointCount; index++)
      _pointAt(route, index / (minPointCount - 1)),
  ];
}

List<LatLng> _ensureMinimumRouteDistance(
  List<LatLng> route,
  LatLng start,
  LatLng end,
  double minKm,
) {
  if (_routeDistanceKm(route) >= minKm) return route;
  final repairedStart = _offsetPoint(end, minKm, _bearingDegrees(end, start));
  return _fallbackRoadRoute(repairedStart, end);
}

List<LatLng> _shortestPath(List<_RouteNode> nodes, int start, int end) {
  final dist = List<double>.filled(nodes.length, double.infinity);
  final previous = List<int?>.filled(nodes.length, null);
  final unvisited = <int>{for (var i = 0; i < nodes.length; i++) i};
  dist[start] = 0;
  const distance = _preciseDistance;

  while (unvisited.isNotEmpty) {
    final current = unvisited.reduce((a, b) => dist[a] <= dist[b] ? a : b);
    if (current == end) break;
    unvisited.remove(current);
    for (final neighbor in nodes[current].neighbors) {
      if (!unvisited.contains(neighbor)) continue;
      final nextDistance =
          dist[current] +
          distance.as(
            LengthUnit.Kilometer,
            nodes[current].point,
            nodes[neighbor].point,
          );
      if (nextDistance < dist[neighbor]) {
        dist[neighbor] = nextDistance;
        previous[neighbor] = current;
      }
    }
  }

  final path = <LatLng>[nodes[end].point];
  var cursor = end;
  while (cursor != start && previous[cursor] != null) {
    cursor = previous[cursor]!;
    path.insert(0, nodes[cursor].point);
  }
  if (path.first != nodes[start].point) path.insert(0, nodes[start].point);
  return path;
}

List<LatLng> _remainingRoute(List<LatLng> route, double progress) {
  if (route.length < 2) return route;
  if (progress >= 0.99) return [route.last];
  final target = _routeDistanceKm(route) * progress;
  var walked = 0.0;
  const distance = _preciseDistance;

  for (var i = 0; i < route.length - 1; i++) {
    final a = route[i];
    final b = route[i + 1];
    final segment = distance.as(LengthUnit.Kilometer, a, b);
    if (walked + segment >= target) {
      final local = ((target - walked) / segment).clamp(0.0, 1.0);
      return [_lerpLatLng(a, b, local), ...route.skip(i + 1)];
    }
    walked += segment;
  }

  return [route.last];
}

LatLng _pointAt(List<LatLng> route, double progress) {
  if (route.isEmpty) return const LatLng(10.7843, 106.5682);
  if (route.length == 1) return route.first;
  final target = _routeDistanceKm(route) * progress;
  var walked = 0.0;
  const distance = _preciseDistance;

  for (var i = 0; i < route.length - 1; i++) {
    final a = route[i];
    final b = route[i + 1];
    final segment = distance.as(LengthUnit.Kilometer, a, b);
    if (walked + segment >= target) {
      final local = ((target - walked) / segment).clamp(0.0, 1.0);
      return _lerpLatLng(a, b, local);
    }
    walked += segment;
  }
  return route.last;
}

/// LỖI GỐC ĐÃ TỪNG LÀM HỎNG TOÀN BỘ MÀN TRACKING:
///
/// `Distance()` của latlong2 mặc định `roundResult: true`, và `.as(unit, ...)`
/// LÀM TRÒN **theo chính đơn vị được hỏi**. Nên `distance.as(
/// LengthUnit.Kilometer, a, b)` với hai điểm cách nhau 30m trả về `0.0` chứ
/// không phải `0.03`. Route dự phòng gồm 42 điểm, mỗi đoạn vài chục mét → mọi
/// đoạn đều làm tròn về 0 → cả tuyến dài "0 km".
///
/// Hệ quả đúng như những gì nhìn thấy trên máy thật: `_pointAt` luôn tính
/// `target = 0` nên tài xế đứng nguyên ở điểm đầu dù tiến độ vẫn chạy; card
/// "Quán tới khách" hiện `0m`; còn số km "vẫn giảm" chỉ vì rơi vào nhánh dự
/// phòng `_minDriverToShopRouteKm * (1 - progress)` (hiện đúng 850m rồi giảm
/// dần) chứ không phải vì tài xế thực sự đi được mét nào.
///
/// Vì vậy toàn bộ file dùng bản `roundResult: false` này.
const _preciseDistance = Distance(roundResult: false);

double _routeDistanceKm(List<LatLng> route) {
  if (route.length < 2) return 0;
  var distanceKm = 0.0;
  const distance = _preciseDistance;
  for (var i = 0; i < route.length - 1; i++) {
    distanceKm += distance.as(LengthUnit.Kilometer, route[i], route[i + 1]);
  }
  return distanceKm;
}

String _formatTrackingDistance(double distanceKm) {
  if (distanceKm <= 0.005) return '0m';
  if (distanceKm < 1) return '${math.max(10, (distanceKm * 1000).round())}m';
  return '${distanceKm.toStringAsFixed(1)}km';
}

LatLng _lerpLatLng(LatLng a, LatLng b, double t) {
  return LatLng(
    _lerp(a.latitude, b.latitude, t),
    _lerp(a.longitude, b.longitude, t),
  );
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

int _bearingDegrees(LatLng from, LatLng to) {
  final lat1 = from.latitude * math.pi / 180;
  final lat2 = to.latitude * math.pi / 180;
  final deltaLng = (to.longitude - from.longitude) * math.pi / 180;
  final y = math.sin(deltaLng) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(deltaLng);
  final bearing = math.atan2(y, x) * 180 / math.pi;
  return ((bearing + 360) % 360).round();
}

/// Hướng di chuyển ổn định tại một điểm trên route: lấy điểm cách đó ~20m về
/// phía trước (hoặc phía sau, nếu đã gần cuối route) rồi tính bearing giữa
/// hai điểm — tránh hướng bị "rung" khi hai điểm liên tiếp trong danh sách
/// quá gần nhau.
double _headingBearing(List<LatLng> route, double progress) {
  if (route.length < 2) return 0;
  final totalKm = _routeDistanceKm(route);
  if (totalKm <= 0) return 0;

  const lookaheadKm = 0.02;
  final aheadFraction = (lookaheadKm / totalKm).clamp(0.0, 1.0);
  final clampedProgress = progress.clamp(0.0, 1.0);
  var a = clampedProgress;
  var b = (clampedProgress + aheadFraction).clamp(0.0, 1.0);
  if (b - a < aheadFraction * 0.5) {
    a = (clampedProgress - aheadFraction).clamp(0.0, 1.0);
    b = clampedProgress;
  }
  if (b <= a) return 0;
  return _bearingDegrees(_pointAt(route, a), _pointAt(route, b)).toDouble();
}

/// Kéo [current] tới gần [target] hơn một phần [stepFraction] của khoảng
/// cách còn lại — không bao giờ vượt qua target, càng gần target thì bước đi
/// càng nhỏ (tự nhiên chậm dần).
double _chaseTowards(double current, double target, double stepFraction) {
  final next = current + (target - current) * stepFraction;
  return next.clamp(0.0, 1.0);
}

/// Quy đổi bước đuổi theo "mỗi khung hình ~[baseStepFraction]" sang đúng tỉ
/// lệ cho một khung hình DÀI [dtSeconds] giây (khung tham chiếu là
/// [referenceFrameSeconds], mặc định 1/60s). Nhờ vậy tốc độ "đuổi theo" mốc
/// GPS luôn như nhau dù máy chạy 30fps hay 120fps — không phụ thuộc số lần
/// callback được gọi.
double _frameSmoothingFactor(
  double dtSeconds,
  double baseStepFraction,
  double referenceFrameSeconds,
) {
  if (dtSeconds <= 0) return 0;
  final ratio = dtSeconds / referenceFrameSeconds;
  return 1 - math.pow(1 - baseStepFraction, ratio).toDouble();
}

LatLng _offsetPoint(LatLng origin, double distanceKm, int bearingDegrees) {
  const earthRadiusKm = 6371.0;
  final bearing = bearingDegrees * math.pi / 180;
  final lat1 = origin.latitude * math.pi / 180;
  final lng1 = origin.longitude * math.pi / 180;
  final angularDistance = distanceKm / earthRadiusKm;

  final lat2 = math.asin(
    math.sin(lat1) * math.cos(angularDistance) +
        math.cos(lat1) * math.sin(angularDistance) * math.cos(bearing),
  );
  final lng2 =
      lng1 +
      math.atan2(
        math.sin(bearing) * math.sin(angularDistance) * math.cos(lat1),
        math.cos(angularDistance) - math.sin(lat1) * math.sin(lat2),
      );

  return LatLng(lat2 * 180 / math.pi, lng2 * 180 / math.pi);
}

// ---------------------------------------------------------------------------
// Wrappers `@visibleForTesting`: các hàm/lớp phía trên đều là private (tiền
// tố `_`) vì chỉ dùng nội bộ file này. Test ở `test/orders/` nằm trong một
// library khác nên không gọi thẳng được — các hàm dưới đây expose lại đúng
// logic đó, không đổi hành vi, chỉ để test truy cập được.
// ---------------------------------------------------------------------------

@visibleForTesting
_TrackingPoints resolveTrackingPointsForTesting(CheckoutOrder order) =>
    _resolveTrackingPoints(order);

@visibleForTesting
List<LatLng> fallbackRoadRouteForTesting(LatLng start, LatLng end) =>
    _fallbackRoadRoute(start, end);

@visibleForTesting
double routeDistanceKmForTesting(List<LatLng> route) => _routeDistanceKm(route);

@visibleForTesting
LatLng pointAtForTesting(List<LatLng> route, double progress) =>
    _pointAt(route, progress);

@visibleForTesting
List<LatLng> remainingRouteForTesting(List<LatLng> route, double progress) =>
    _remainingRoute(route, progress);

@visibleForTesting
double headingBearingForTesting(List<LatLng> route, double progress) =>
    _headingBearing(route, progress);

@visibleForTesting
int bearingDegreesForTesting(LatLng from, LatLng to) =>
    _bearingDegrees(from, to);

@visibleForTesting
double chaseTowardsForTesting(
  double current,
  double target,
  double stepFraction,
) => _chaseTowards(current, target, stepFraction);

@visibleForTesting
double frameSmoothingFactorForTesting(
  double dtSeconds,
  double baseStepFraction,
  double referenceFrameSeconds,
) => _frameSmoothingFactor(dtSeconds, baseStepFraction, referenceFrameSeconds);

@visibleForTesting
_DriverProfile driverProfileForTesting(String seed) => _driverProfileFor(seed);

@visibleForTesting
String driverProfileSeedForTesting(OrderEntry entry) =>
    _driverProfileSeedFor(entry);

@visibleForTesting
String formatTrackingDistanceForTesting(double distanceKm) =>
    _formatTrackingDistance(distanceKm);
