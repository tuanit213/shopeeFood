import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../app/app_colors.dart';
import '../checkout/checkout_models.dart';
import 'order_state.dart';

enum _DeliveryPhase { toShop, waitingAtShop, toCustomer, arrived, delivered }

class OrderTrackingDetailPage extends StatefulWidget {
  final OrderEntry entry;

  const OrderTrackingDetailPage({super.key, required this.entry});

  @override
  State<OrderTrackingDetailPage> createState() =>
      _OrderTrackingDetailPageState();
}

class _OrderTrackingDetailPageState extends State<OrderTrackingDetailPage>
    with SingleTickerProviderStateMixin {
  late final LatLng _shopPosition;
  late final LatLng _customerPosition;
  late LatLng _startDriverPosition;
  late List<LatLng> _driverToShopRoute;
  late List<LatLng> _shopToCustomerRoute;
  late List<LatLng> _activeRoute;
  late LatLng _driverPosition;

  Timer? _waitTimer;
  Timer? _handoffTimer;
  late final AnimationController _moveController;
  VoidCallback? _routeDone;

  _DeliveryPhase _phase = _DeliveryPhase.toShop;
  double _phaseProgress = 0;
  int _waitSeconds = 10;
  bool _nearbyNotified = false;
  bool _loadingRoadRoute = true;
  bool _usingRoadRoute = false;
  bool _trackingStarted = false;
  int _shopRating = 0;
  int _driverRating = 0;

  static const _stepDuration = Duration(milliseconds: 3000);
  static const _averageSpeedKmh = 40.0;
  static const _minimumVisualRouteDuration = Duration(seconds: 80);

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(vsync: this, duration: _stepDuration);
    _moveController.addListener(_updateRoutePosition);
    _moveController.addStatusListener(_handleRouteStatus);
    final points = _resolveTrackingPoints(widget.entry.order);
    _shopPosition = points.shop;
    _customerPosition = points.customer;
    _startDriverPosition = points.driver;
    _driverToShopRoute = _fallbackRoadRoute(
      _startDriverPosition,
      _shopPosition,
    );
    _driverToShopRoute = _ensureMinimumRouteDistance(
      _driverToShopRoute,
      _startDriverPosition,
      _shopPosition,
      0.22,
    );
    _startDriverPosition = _driverToShopRoute.first;
    _driverPosition = _startDriverPosition;
    _shopToCustomerRoute = _fallbackRoadRoute(_shopPosition, _customerPosition);
    _activeRoute = _driverToShopRoute;
    _shopRating = widget.entry.shopRating ?? 0;
    _driverRating = widget.entry.driverRating ?? 0;
    _loadRoadRoutes();
  }

  @override
  void dispose() {
    _moveController
      ..removeListener(_updateRoutePosition)
      ..removeStatusListener(_handleRouteStatus)
      ..dispose();
    _waitTimer?.cancel();
    _handoffTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRoadRoutes() async {
    final routes = await Future.wait([
      _fetchRoadRoute(_startDriverPosition, _shopPosition),
      _fetchRoadRoute(_shopPosition, _customerPosition),
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
        0.22,
      );
      _shopToCustomerRoute = nextToCustomer;
      _usingRoadRoute = toShop != null || toCustomer != null;
      _loadingRoadRoute = false;
      if (_phase == _DeliveryPhase.toShop) {
        _activeRoute = _driverToShopRoute;
        _driverPosition = _pointAt(_activeRoute, _phaseProgress);
      } else if (_phase == _DeliveryPhase.toCustomer) {
        _activeRoute = _shopToCustomerRoute;
        _driverPosition = _pointAt(_activeRoute, _phaseProgress);
      }
    });
    if (!_trackingStarted) {
      _trackingStarted = true;
      _startMovingToShop();
    } else if (_phase == _DeliveryPhase.toShop ||
        _phase == _DeliveryPhase.toCustomer) {
      _restartRouteMotion();
    }
  }

  void _startMovingToShop() {
    setState(() {
      _phase = _DeliveryPhase.toShop;
      _phaseProgress = 0;
      _activeRoute = _driverToShopRoute;
    });
    _startProgressTimer(_arriveShop);
  }

  void _arriveShop() {
    _moveController.stop();
    _routeDone = null;
    setState(() {
      _phase = _DeliveryPhase.waitingAtShop;
      _driverPosition = _shopPosition;
      _phaseProgress = 1;
      _waitSeconds = 10;
    });
    _showStatusPopup('Tài xế đã đến quán và đang đợi lấy món');
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_waitSeconds <= 1) {
        timer.cancel();
        _showStatusPopup('Tài xế đã lấy món');
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
      _phaseProgress = 0;
      _nearbyNotified = false;
      _driverPosition = _shopPosition;
      _activeRoute = _shopToCustomerRoute;
    });
    _showStatusPopup('Tài xế đang bắt đầu giao hàng cho bạn');
    _startProgressTimer(_arriveCustomer);
  }

  void _arriveCustomer() {
    _moveController.stop();
    _routeDone = null;
    setState(() {
      _phase = _DeliveryPhase.arrived;
      _driverPosition = _customerPosition;
      _phaseProgress = 1;
    });
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

  void _startProgressTimer(VoidCallback onDone) {
    _moveController.stop();
    _routeDone = onDone;
    _moveController.duration = _durationForRoute(_activeRoute);
    setState(() {
      _phaseProgress = 0;
      _driverPosition = _pointAt(_activeRoute, 0);
    });
    _moveController.forward(from: 0);
  }

  void _restartRouteMotion() {
    final progress = _phaseProgress.clamp(0.0, 0.98);
    _moveController.stop();
    _routeDone ??= _phase == _DeliveryPhase.toShop
        ? _arriveShop
        : _arriveCustomer;
    _moveController.duration = _durationForRoute(_activeRoute);
    setState(() {
      _phaseProgress = progress;
      _driverPosition = _pointAt(_activeRoute, progress);
    });
    _moveController.forward(from: progress);
  }

  void _updateRoutePosition() {
    if (!mounted) return;
    final progress = Curves.easeInOutCubic.transform(
      _moveController.value.clamp(0.0, 1.0),
    );
    setState(() {
      _phaseProgress = progress;
      _driverPosition = _pointAt(_activeRoute, progress);
    });

    if (_phase == _DeliveryPhase.toCustomer &&
        !_nearbyNotified &&
        _remainingKm <= 0.2) {
      _nearbyNotified = true;
      _showStatusPopup('Món của bạn sắp được giao, chuẩn bị nhận đơn nhé!');
    }
  }

  void _handleRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    final done = _routeDone;
    _routeDone = null;
    setState(() {
      _phaseProgress = 1;
      _driverPosition = _pointAt(_activeRoute, 1);
    });
    done?.call();
  }

  Duration _durationForRoute(List<LatLng> route) {
    final realMs = _routeDistanceKm(route) / _averageSpeedKmh * 3600 * 1000;
    return Duration(
      milliseconds: realMs.round().clamp(
        _minimumVisualRouteDuration.inMilliseconds,
        180000,
      ),
    );
  }

  double get _activeRouteKm => _routeDistanceKm(_activeRoute);

  double get _remainingKm {
    final rawRemaining = _activeRouteKm * (1 - _phaseProgress);
    if (_phase == _DeliveryPhase.toShop &&
        rawRemaining <= 0.05 &&
        _phaseProgress < 0.95) {
      return 0.22 * (1 - _phaseProgress);
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

  double get _toShopKmForDisplay {
    final raw = _routeDistanceKm(_driverToShopRoute);
    if (raw <= 0.05 &&
        (_phase == _DeliveryPhase.toShop ||
            _phase == _DeliveryPhase.waitingAtShop)) {
      return 0.22;
    }
    return raw;
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
        'Đường theo bản đồ thật tới quán, còn ${_formatTrackingDistance(_remainingKm)}',
      _DeliveryPhase.waitingAtShop =>
        'Sau khi lấy món, lộ trình sẽ đổi về địa chỉ của bạn',
      _DeliveryPhase.toCustomer =>
        'Còn ${_formatTrackingDistance(_remainingKm)}, dự kiến $_etaMinutes phút theo 40km/h',
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
                activeRoute: _activeRoute,
                completedProgress: _phaseProgress,
                driver: _driverPosition,
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
              ),
              const SizedBox(height: 8),
              _OrderSummaryCard(order: order, firstItem: firstItem),
              const SizedBox(height: 8),
              _RouteInfoCard(
                toShopKm: _toShopKmForDisplay,
                toCustomerKm: _routeDistanceKm(_shopToCustomerRoute),
                activeRoute: _activeRoute,
                loadingRoadRoute: _loadingRoadRoute,
                usingRoadRoute: _usingRoadRoute,
              ),
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
  final List<LatLng> activeRoute;
  final double completedProgress;
  final LatLng driver;
  final LatLng shop;
  final LatLng customer;
  final _DeliveryPhase phase;
  final bool loadingRoadRoute;
  final int etaMinutes;
  final double distanceKm;

  const _MapCard({
    required this.activeRoute,
    required this.completedProgress,
    required this.driver,
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

  @override
  Widget build(BuildContext context) {
    final remainingRoute = _remainingRoute(
      widget.activeRoute,
      widget.completedProgress,
    );
    final points = <LatLng>[
      ...widget.activeRoute,
      widget.driver,
      widget.shop,
      widget.customer,
    ];

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
            options: MapOptions(
              initialCameraFit: CameraFit.coordinates(
                coordinates: points,
                padding: const EdgeInsets.fromLTRB(28, 48, 28, 54),
              ),
              minZoom: 5,
              maxZoom: 19,
            ),
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
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.activeRoute,
                    strokeWidth: 4,
                    color: const Color(0xFF9E9E9E).withValues(alpha: 0.18),
                    borderColor: Colors.white.withValues(alpha: 0.70),
                    borderStrokeWidth: 1.5,
                  ),
                  if (remainingRoute.length > 1)
                    Polyline(
                      points: remainingRoute,
                      strokeWidth: 5,
                      color: AppColors.primary,
                      borderColor: Colors.white,
                      borderStrokeWidth: 2,
                    ),
                ],
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
                  Marker(
                    point: widget.driver,
                    width: 44,
                    height: 44,
                    child: const _DriverMarker(),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 8,
            top: 8,
            child: _MapInfoChip(
              title: widget.loadingRoadRoute
                  ? 'Đang tính đường'
                  : widget.phase == _DeliveryPhase.toShop
                  ? 'Tài xế tới quán'
                  : widget.phase == _DeliveryPhase.waitingAtShop
                  ? 'Đang lấy món'
                  : 'Giao tới bạn',
              subtitle: widget.loadingRoadRoute
                  ? 'Theo đường thật'
                  : widget.etaMinutes == 0
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
              onPressed: () => _controller.fitCamera(
                CameraFit.coordinates(
                  coordinates: points,
                  padding: const EdgeInsets.fromLTRB(28, 48, 28, 54),
                ),
              ),
              child: const Icon(Icons.my_location_rounded, size: 20),
            ),
          ),
          if (widget.loadingRoadRoute)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.38),
                ),
                child: const Center(child: _RouteLoadingBadge()),
              ),
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

class _DriverMarker extends StatelessWidget {
  const _DriverMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(
            left: 10,
            top: 12,
            child: Icon(
              Icons.two_wheeler_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          Icon(
            Icons.two_wheeler_rounded,
            color: AppColors.primary,
            size: 30,
            shadows: [
              Shadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 9,
                offset: const Offset(0, 2),
              ),
              const Shadow(color: Colors.white, blurRadius: 2),
            ],
          ),
          Positioned(
            right: 6,
            top: 7,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
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

  const _StatusCard({
    required this.title,
    required this.subtitle,
    required this.etaMinutes,
    required this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Row(
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
                style: const TextStyle(color: Color(0xFF757575), fontSize: 10),
              ),
            ],
          ),
        ],
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
          if (firstItem != null)
            Row(
              children: [
                _FoodThumb(path: firstItem!.imageUrl),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstItem!.name,
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

class _RouteInfoCard extends StatelessWidget {
  final double toShopKm;
  final double toCustomerKm;
  final List<LatLng> activeRoute;
  final bool loadingRoadRoute;
  final bool usingRoadRoute;

  const _RouteInfoCard({
    required this.toShopKm,
    required this.toCustomerKm,
    required this.activeRoute,
    required this.loadingRoadRoute,
    required this.usingRoadRoute,
  });

  @override
  Widget build(BuildContext context) {
    final routeSource = loadingRoadRoute
        ? 'Đang lấy route thật'
        : usingRoadRoute
        ? 'OSRM road route'
        : 'Fallback Dijkstra';

    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lộ trình giao hàng',
            style: TextStyle(
              color: Color(0xFF212121),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          _RouteMetric(
            label: 'Tài xế tới quán',
            value: _formatTrackingDistance(toShopKm),
          ),
          const SizedBox(height: 4),
          _RouteMetric(
            label: 'Quán tới khách',
            value: _formatTrackingDistance(toCustomerKm),
          ),
          const SizedBox(height: 4),
          _RouteMetric(
            label: 'Nguồn tuyến đường',
            value: '$routeSource | ${activeRoute.length} điểm',
          ),
        ],
      ),
    );
  }
}

class _RouteMetric extends StatelessWidget {
  final String label;
  final String value;

  const _RouteMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF757575), fontSize: 11),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF212121),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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

  const _FoodThumb({required this.path});

  @override
  Widget build(BuildContext context) {
    final isAsset = path.startsWith('assets/');
    final image = isAsset
        ? Image.asset(path, width: 48, height: 48, fit: BoxFit.cover)
        : Image.network(path, width: 48, height: 48, fit: BoxFit.cover);
    return ClipRRect(borderRadius: BorderRadius.circular(6), child: image);
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

  const _RoadRoute({required this.points});
}

class _RouteNode {
  final LatLng point;
  final List<int> neighbors;

  const _RouteNode(this.point, this.neighbors);
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
    0.26 + (restaurant.id.hashCode.abs() % 5) / 100,
    250 + restaurant.id.hashCode.abs() % 70,
  );

  return _TrackingPoints(driver: driver, shop: shop, customer: customer);
}

bool _validCoordinate(double? value) => value != null && value.abs() > 0.001;

Future<_RoadRoute?> _fetchRoadRoute(LatLng from, LatLng to) async {
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
    final coordinates = geometry?['coordinates'] as List<dynamic>?;
    if (coordinates == null || coordinates.length < 2) return null;

    final points = coordinates
        .map((raw) {
          final pair = raw as List<dynamic>;
          return LatLng(
            (pair[1] as num).toDouble(),
            (pair[0] as num).toDouble(),
          );
        })
        .toList(growable: false);
    return _RoadRoute(points: _normalizeRoadRoute(from, to, points));
  } catch (_) {
    return null;
  }
}

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
  const distance = Distance();

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
  if (progress >= 0.995) return [route.last];
  final target = _routeDistanceKm(route) * progress;
  var walked = 0.0;
  const distance = Distance();

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
  const distance = Distance();

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

double _routeDistanceKm(List<LatLng> route) {
  if (route.length < 2) return 0;
  var distanceKm = 0.0;
  const distance = Distance();
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
