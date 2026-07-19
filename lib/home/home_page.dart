import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../address/address_pages.dart';
import '../address/delivery_address.dart';
import '../app/app_colors.dart';
import '../checkout/checkout_pages.dart';
import '../checkout/checkout_models.dart';
import '../location/location_service.dart';
import '../orders/order_state.dart';
import '../orders/order_tracking_detail_page.dart';
import '../restaurant/restaurant_detail_page.dart';
import 'nearby_restaurant_service.dart';
import 'promo_results_page.dart';
import 'restaurant_repository.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onProfileTap;
  final ValueChanged<bool>? onLocationGateChanged;

  const HomePage({super.key, this.onProfileTap, this.onLocationGateChanged});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _promoDismissedDateKey = 'home_promo_dismissed_date_v1';

  late final PageController _bannerController;
  late final AnimationController _bannerMotionController;
  late final DateTime _flashEndsAt;
  Timer? _bannerTimer;
  Timer? _countdownTimer;

  int _activeBanner = 0;
  int _activeSort = 0;
  Duration _flashRemaining = const Duration(hours: 1);
  AppLocation _location = AppLocation.fallback;
  DeliveryAddress? _selectedDeliveryAddress;
  List<_RestaurantData> _visibleRestaurants = _restaurants;
  bool _isLocating = true;
  bool _showLocationGate = true;
  String? _locationGateAddress;
  bool _promoDialogShown = false;
  bool _showMiniPromo = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bannerController = PageController();
    _bannerMotionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
    _flashEndsAt = DateTime.now().add(const Duration(hours: 1));
    _startBannerTimer();
    _startCountdownTimer();
    _loadNearbyRestaurants();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerTimer?.cancel();
    _countdownTimer?.cancel();
    _bannerMotionController.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_showLocationGate) {
      _loadNearbyRestaurants();
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final frameWidth = constraints.maxWidth <= 600
                  ? constraints.maxWidth
                  : math.min(constraints.maxWidth, 390.0);

              if (_showLocationGate) {
                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: frameWidth,
                    child: _buildLocationLoadingPage(topPadding),
                  ),
                );
              }

              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: frameWidth,
                  child: CustomScrollView(
                    slivers: [
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _HeaderDelegate(
                          topPadding: topPadding,
                          address: _compactHeaderAddress(
                            _selectedDeliveryAddress?.displayAddress ??
                                _location.address,
                          ),
                          onBack: () => Navigator.maybePop(context),
                          onAddressTap: _openAddressBook,
                          onSearchTap: _openSearch,
                        ),
                      ),
                      SliverToBoxAdapter(child: _buildHeroCarousel()),
                      SliverToBoxAdapter(child: _buildCategories()),
                      SliverToBoxAdapter(child: _buildActiveOrdersNotice()),
                      SliverToBoxAdapter(child: _buildDealSection()),
                      SliverToBoxAdapter(child: _buildCollectionSection()),
                      SliverToBoxAdapter(child: _buildFlashSaleSection()),
                      SliverToBoxAdapter(child: _buildRecentSection()),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _WidePromoBanner(
                            title: 'TUTIMI',
                            subtitle: 'Trạm săn deal nửa giá',
                            seed: 'tutimi-mid-banner',
                            colors: const [
                              Color(0xFFEB5E28),
                              Color(0xFFFFB703),
                            ],
                          ),
                        ),
                      ),
                      for (final section in _restaurantSectionsForVisibleItems)
                        SliverToBoxAdapter(
                          child: _buildRestaurantShelf(section),
                        ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SortTabsDelegate(
                          selectedIndex: _activeSort,
                          onTap: (index) => setState(() => _activeSort = index),
                        ),
                      ),
                      SliverToBoxAdapter(child: _buildTopPhotoGrid()),
                      SliverToBoxAdapter(child: _buildRestaurantList()),
                      const SliverToBoxAdapter(child: SizedBox(height: 112)),
                    ],
                  ),
                ),
              );
            },
          ),
          if (!_showLocationGate && _showMiniPromo)
            Positioned(
              right: 8,
              bottom: 12,
              child: _MiniPromoBubble(
                onTap: () => _openPromoResults(
                  context,
                  title: 'Ăn khuya ngon rẻ',
                  subtitle: 'Deal giảm 30.000Đ, món hot giao nhanh',
                  seed: 'late-night-mini-promo',
                ),
                onClose: () => setState(() => _showMiniPromo = false),
              ),
            ),
        ],
      ),
    );
  }

  void _startBannerTimer() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_bannerController.hasClients) return;
      final next = (_activeBanner + 1) % _banners.length;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _startCountdownTimer() {
    void tick() {
      final diff = _flashEndsAt.difference(DateTime.now());
      if (!mounted) return;
      setState(() {
        _flashRemaining = diff.isNegative ? Duration.zero : diff;
      });
    }

    tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<void> _loadNearbyRestaurants() async {
    setState(() {
      _isLocating = true;
      _showLocationGate = true;
      _locationGateAddress = null;
    });
    widget.onLocationGateChanged?.call(true);

    final location = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _location = location;
        _selectedDeliveryAddress = null;
        _locationGateAddress = location.address;
      });
    }

    final activeLocation = location;

    final restaurantResult =
        await RestaurantRepository.loadNearby(activeLocation).timeout(
          const Duration(seconds: 3),
          onTimeout: () =>
              const RestaurantLoadResult(restaurants: [], fromCache: false),
        );

    if (!mounted) return;

    final restaurants = restaurantResult.restaurants.isNotEmpty
        ? _restaurantsFromListings(restaurantResult.restaurants, activeLocation)
        : _localRestaurantsForLocation(activeLocation);

    setState(() {
      _location = activeLocation;
      _visibleRestaurants = restaurants;
      _isLocating = false;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    setState(() {
      _showLocationGate = false;
    });
    widget.onLocationGateChanged?.call(false);
    _maybeShowPromoDialog();
  }

  Future<void> _maybeShowPromoDialog() async {
    if (_promoDialogShown || !mounted) return;
    final dismissedDate = await _readPromoDismissedDate();
    if (!mounted || dismissedDate == _todayKey()) return;

    _promoDialogShown = true;
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 480), () async {
        if (!mounted || _showLocationGate) return;
        await showDialog<void>(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.58),
          builder: (dialogContext) => _HomePromoDialog(
            onClose: () => _closePromoDialog(dialogContext),
            onOpenDeal: () {
              unawaited(_markPromoDismissedToday());
              Navigator.pop(dialogContext);
              _openPromoResults(
                context,
                title: 'Ăn khuya ngon rẻ',
                subtitle: 'Giảm 30.000Đ, voucher nóng cho món gần bạn',
                seed: 'late-night-popup-promo',
              );
            },
          ),
        );
        if (mounted) {
          unawaited(_markPromoDismissedToday());
        }
      }),
    );
  }

  Future<String?> _readPromoDismissedDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_promoDismissedDateKey);
  }

  Future<void> _markPromoDismissedToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_promoDismissedDateKey, _todayKey());
  }

  void _closePromoDialog(BuildContext dialogContext) {
    unawaited(_markPromoDismissedToday());
    Navigator.pop(dialogContext);
  }

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  Future<void> _openAddressBook() async {
    final result = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressBookPage(
          currentLocation: _location,
          selectedAddress: _selectedDeliveryAddress,
        ),
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      _selectedDeliveryAddress = result;
      _location = AppLocation(
        latitude: result.latitude,
        longitude: result.longitude,
        address: result.displayAddress,
        isFallback: false,
      );
      _isLocating = true;
    });

    final location = _location;
    final restaurantResult = await RestaurantRepository.loadNearby(location);
    if (!mounted) return;

    setState(() {
      _visibleRestaurants = restaurantResult.restaurants.isNotEmpty
          ? _restaurantsFromListings(restaurantResult.restaurants, location)
          : _localRestaurantsForLocation(location);
      _isLocating = false;
    });
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _HomeSearchPage(
          restaurants: _visibleRestaurants,
          currentLocation: _location,
        ),
      ),
    );
  }

  Widget _buildLocationLoadingPage(double topPadding) {
    final address = _compactLocationGateAddress(_locationGateAddress);
    final hasAddress = address != null;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompactHeight = screenHeight < 760;

    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, topPadding + 18, 24, 28),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => Navigator.maybePop(context),
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                ),
              ),
              Spacer(flex: isCompactHeight ? 2 : 3),
              Text(
                'Đang tìm vị trí...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF757575),
                  fontSize: isCompactHeight ? 17 : 18,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: isCompactHeight ? 42 : 56),
              AnimatedBuilder(
                animation: _bannerMotionController,
                builder: (context, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: isCompactHeight ? 140 : 156,
                        height: isCompactHeight ? 140 : 156,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1ED),
                          borderRadius: BorderRadius.circular(
                            isCompactHeight ? 70 : 78,
                          ),
                        ),
                        child: CustomPaint(painter: _MapGridPainter()),
                      ),
                      SizedBox(
                        width: isCompactHeight ? 112 : 128,
                        height: isCompactHeight ? 112 : 128,
                        child: CustomPaint(
                          painter: _RadarSweepPainter(
                            progress: _bannerMotionController.value,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.location_on_rounded,
                        color: AppColors.primary,
                        size: 64,
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: isCompactHeight ? 22 : 28),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: ConstrainedBox(
                  key: ValueKey(address ?? 'loading-address'),
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    address ?? 'Đang xác định địa chỉ của bạn',
                    textAlign: TextAlign.center,
                    maxLines: hasAddress ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasAddress
                          ? const Color(0xFF212121)
                          : const Color(0xFF9E9E9E),
                      fontSize: hasAddress ? 17 : 15,
                      height: hasAddress ? 1.24 : 1.3,
                      fontWeight: hasAddress
                          ? FontWeight.w600
                          : FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
              if (_isLocating) SizedBox(height: isCompactHeight ? 34 : 46),
              Spacer(flex: isCompactHeight ? 4 : 5),
            ],
          ),
        ),
      ),
    );
  }

  String? _compactLocationGateAddress(String? rawAddress) {
    final normalized = rawAddress?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized == null || normalized.isEmpty) return null;
    final parts = normalized
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    final compactParts = <String>[];
    for (var i = 0; i < parts.length; i++) {
      final current = parts[i].toLowerCase();
      final previous = compactParts.isEmpty
          ? ''
          : compactParts.last.toLowerCase();
      final next = i + 1 < parts.length ? parts[i + 1].toLowerCase() : '';
      final isDuplicate = compactParts.any(
        (part) => part.toLowerCase() == current,
      );
      final isShortRepeatedNearby =
          current.length <= 6 &&
          ((previous.isNotEmpty && previous.contains(current)) ||
              (next.isNotEmpty && next.contains(current)));
      if (!isDuplicate && !isShortRepeatedNearby) {
        compactParts.add(parts[i]);
      }
    }

    return compactParts.join(', ');
  }

  String _compactHeaderAddress(String rawAddress) {
    final compact = _compactLocationGateAddress(rawAddress) ?? rawAddress;
    final parts = compact
        .split(',')
        .map((part) => part.trim())
        .where(
          (part) =>
              part.isNotEmpty &&
              part.toLowerCase() != 'vietnam' &&
              part.toLowerCase() != 'việt nam',
        )
        .toList();
    if (parts.length <= 4) return parts.join(', ');
    return parts.take(4).join(', ');
  }

  Widget _buildHeroCarousel() {
    return SizedBox(
      height: 172,
      child: Column(
        children: [
          SizedBox(
            height: 154,
            child: PageView.builder(
              controller: _bannerController,
              itemCount: _banners.length,
              onPageChanged: (index) => setState(() => _activeBanner = index),
              itemBuilder: (context, index) {
                return _HeroBanner(
                  data: _banners[index],
                  motion: _bannerMotionController,
                  countdown: _flashRemaining,
                );
              },
            ),
          ),
          Container(
            height: 18,
            color: Colors.white,
            alignment: Alignment.center,
            child: _Dots(
              count: _banners.length,
              activeIndex: _activeBanner,
              activeColor: AppColors.primary,
              inactiveColor: const Color(0xFFDADADA),
              onTap: (index) {
                _bannerController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
      child: Column(
        children: [
          _CategoryRow(items: _categoryRowOne),
          const SizedBox(height: 9),
          _CategoryRow(items: _categoryRowTwo),
          const SizedBox(height: 8),
          const _SmallOrangeDots(),
        ],
      ),
    );
  }

  Widget _buildActiveOrdersNotice() {
    return ValueListenableBuilder<List<OrderEntry>>(
      valueListenable: OrderState.entries,
      builder: (context, entries, _) {
        final activeEntries =
            entries
                .where(
                  (entry) =>
                      entry.status == OrderStatus.delivering ||
                      entry.status == OrderStatus.cart,
                )
                .toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        if (activeEntries.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Hoạt động của bạn',
                      style: const TextStyle(
                        color: Color(0xFF212121),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    for (var i = 0; i < activeEntries.length; i++) ...[
                      _ActiveOrderHomeCard(entry: activeEntries[i]),
                      if (i != activeEntries.length - 1)
                        const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDealSection() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, Color(0xFFF97A5A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'TRÙM DEAL NGON SHOPEEFOOD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _SeeMore(
                  color: Colors.white,
                  onTap: () => _openPromoResults(
                    context,
                    title: 'Trùm deal ngon ShopeeFood',
                    subtitle: 'Các món đang giảm sâu quanh vị trí của bạn',
                    seed: 'home-deal-section',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _DealLargeCard(data: _dealCards.first)),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    children: [
                      _DealSmallCard(data: _dealCards[1]),
                      const SizedBox(height: 7),
                      _DealSmallCard(data: _dealCards[2]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionSection() {
    return _WhiteSection(
      title: 'Bộ sưu tập',
      onSeeMore: () => _openPromoResults(
        context,
        title: 'Bộ sưu tập ShopeeFood',
        subtitle: 'Các nhóm món ngon đang có ưu đãi hôm nay',
        seed: 'home-collection-section',
      ),
      child: _HorizontalRow(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final item in _collections)
            _CollectionCard(item: item, width: 140),
        ],
      ),
    );
  }

  Widget _buildFlashSaleSection() {
    return _WhiteSection(
      onSeeMore: () => _openPromoResults(
        context,
        title: 'Flash Sale',
        subtitle: 'Món ngon giảm sâu trong khung giờ hiện tại',
        seed: 'home-flash-sale-section',
      ),
      titleWidget: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 4),
          const Text(
            'FLASH SALE',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          _Countdown(value: _flashRemaining),
        ],
      ),
      child: _HorizontalRow(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [for (final item in _flashItems) _FlashCard(item: item)],
      ),
    );
  }

  Widget _buildRecentSection() {
    return _WhiteSection(
      title: 'Xem gần đây',
      onSeeMore: () => _openPromoResults(
        context,
        title: 'Xem gần đây',
        subtitle: 'Các món và quán bạn đã xem gần đây',
        seed: 'home-recent-section',
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.builder(
          padding: EdgeInsets.zero,
          itemCount: _recentItems.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.86,
          ),
          itemBuilder: (context, index) => _RecentCard(
            item: _recentItems[index],
            onTap: () => _openPromoResults(
              context,
              title: _recentItems[index].name,
              subtitle: _recentItems[index].viewedAt,
              seed: _recentItems[index].seed,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantShelf(_RestaurantSectionData section) {
    return _WhiteSection(
      title: section.title,
      subtitle: section.subtitle,
      onSeeMore: () => _openPromoResults(
        context,
        title: section.title,
        subtitle: section.subtitle ?? 'Các quán đang có ưu đãi quanh bạn',
        seed: 'restaurant-shelf-${section.title}',
      ),
      child: _HorizontalRow(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final item in section.items)
            _ShelfRestaurantCard(item: item, currentLocation: _location),
        ],
      ),
    );
  }

  Widget _buildTopPhotoGrid() {
    final items = _sortedRestaurants.take(6).toList();
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: GridView.builder(
        itemCount: items.length,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 8,
          childAspectRatio: 0.78,
        ),
        itemBuilder: (context, index) {
          return _TopPhotoCard(item: items[index], currentLocation: _location);
        },
      ),
    );
  }

  Widget _buildRestaurantList() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          for (var i = 0; i < _sortedRestaurants.length; i++) ...[
            _RestaurantRow(
              item: _sortedRestaurants[i],
              currentLocation: _location,
            ),
            if ((i + 1) % 5 == 0)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _WidePromoBanner(
                  title: 'Freeship Xtra',
                  subtitle: 'Món ngon gần bạn, giảm đến 50%',
                  seed: 'restaurant-list-promo',
                  colors: [Color(0xFFE53935), Color(0xFFFF8A00)],
                ),
              ),
          ],
        ],
      ),
    );
  }

  List<_RestaurantData> get _sortedRestaurants {
    final items = List<_RestaurantData>.of(_visibleRestaurants);
    switch (_activeSort) {
      case 1:
        items.sort((a, b) => b.sold.compareTo(a.sold));
      case 2:
        items.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      default:
        items.sort((a, b) => a.distance.compareTo(b.distance));
    }
    return items;
  }

  List<_RestaurantSectionData> get _restaurantSectionsForVisibleItems {
    final sorted = _sortedRestaurants;
    return [
      _RestaurantSectionData(
        title: 'Quán gần bạn',
        subtitle: 'Sắp xếp theo vị trí hiện tại',
        items: sorted.take(5).toList(),
      ),
      _RestaurantSectionData(
        title: 'Được đánh giá tốt',
        subtitle: 'Ưu tiên rating cao quanh khu vực',
        items: sorted.where((item) => item.rating != null).take(5).toList(),
      ),
    ];
  }

  List<_RestaurantData> _localRestaurantsForLocation(AppLocation location) {
    return _restaurants.map((item) {
      final distance = NearbyRestaurantService.distanceInKm(
        fromLat: location.latitude,
        fromLng: location.longitude,
        toLat: item.latitude,
        toLng: item.longitude,
      );
      return item.withDistance(distance);
    }).toList();
  }

  List<_RestaurantData> _restaurantsFromListings(
    List<RestaurantListing> restaurants,
    AppLocation location,
  ) {
    return [
      for (var index = 0; index < restaurants.length; index++)
        _RestaurantData(
          name: restaurants[index].name,
          seed: '${restaurants[index].category}-${restaurants[index].id}',
          rating:
              restaurants[index].rating ??
              _ratingForSeed(restaurants[index].id),
          distance: restaurants[index].distanceFrom(location),
          time: math.max(
            12,
            (restaurants[index].distanceFrom(location) * 7).round() + 8,
          ),
          sold:
              restaurants[index].userRatingCount ??
              _soldCountForSeed(restaurants[index].id),
          badges: [
            if (restaurants[index].openNow) 'Đang mở cửa',
            if ((restaurants[index].rating ?? 4.4) >= 4.3) 'Đánh giá tốt',
            _categoryBadge(restaurants[index].category),
            'Gần bạn',
          ],
          address: restaurants[index].address,
          latitude: restaurants[index].latitude,
          longitude: restaurants[index].longitude,
          imageUrl:
              restaurants[index].photoUrl ??
              _imageUrlForCategory(
                restaurants[index].category,
                restaurants[index].id,
              ),
          category: restaurants[index].category,
          verified: true,
          isFavorite: index < 2,
          freeshipXtra: index.isEven,
        ),
    ];
  }

  double _ratingForSeed(String seed) {
    final value = seed.codeUnits.fold<int>(0, (sum, code) => sum + code);
    return 4.2 + (value % 8) / 10;
  }

  int _soldCountForSeed(String seed) {
    final value = seed.codeUnits.fold<int>(0, (sum, code) => sum + code);
    return 180 + (value % 1400);
  }

  String _categoryBadge(String category) {
    return switch (category) {
      'cafe' => 'Cafe',
      'fast_food' => 'Ăn nhanh',
      'food_court' => 'Food court',
      'bakery' => 'Bánh ngọt',
      _ => 'Quán ăn',
    };
  }
}

class _ActiveOrderHomeCard extends StatelessWidget {
  final OrderEntry entry;

  const _ActiveOrderHomeCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final order = entry.order;
    final firstItem = order.items.isEmpty ? null : order.items.first;
    final isDelivering = entry.status == OrderStatus.delivering;
    final elapsedMinutes = DateTime.now().difference(entry.updatedAt).inMinutes;
    final etaMinutes = math.max(
      1,
      order.restaurant.deliveryMinutes + 12 - elapsedMinutes,
    );

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => isDelivering
              ? OrderTrackingDetailPage(entry: entry)
              : CheckoutPage(order: order),
        ),
      ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 292,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFD7CC), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
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
                  child: Icon(
                    isDelivering
                        ? Icons.delivery_dining_rounded
                        : Icons.shopping_basket_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0ED),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isDelivering ? 'Đang giao' : 'Trong giỏ',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isDelivering ? '$etaMinutes phút' : 'Chờ đặt',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF757575),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
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
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              [
                if (firstItem != null) firstItem.name,
                '${order.itemCount} món',
                checkoutFormatPrice(order.total),
              ].join(' | '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF616161),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _ActiveOrderMetaChip(
                  icon: Icons.access_time_rounded,
                  label: isDelivering ? 'Còn $etaMinutes phút' : 'Đặt tiếp',
                ),
                const SizedBox(width: 6),
                _ActiveOrderMetaChip(
                  icon: Icons.near_me_outlined,
                  label: '${order.restaurant.distanceKm.toStringAsFixed(1)}km',
                ),
                const Spacer(),
                if (isDelivering)
                  const Text(
                    'Xem lộ trình',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                else
                  const Text(
                    'Thanh toán',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
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

class _ActiveOrderMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ActiveOrderMetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF757575)),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF616161),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.72)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pathOne = Path()
      ..moveTo(size.width * 0.12, size.height * 0.30)
      ..lineTo(size.width * 0.40, size.height * 0.18)
      ..lineTo(size.width * 0.58, size.height * 0.42)
      ..lineTo(size.width * 0.86, size.height * 0.34);
    canvas.drawPath(pathOne, paint);

    final pathTwo = Path()
      ..moveTo(size.width * 0.22, size.height * 0.78)
      ..lineTo(size.width * 0.42, size.height * 0.54)
      ..lineTo(size.width * 0.66, size.height * 0.68)
      ..lineTo(size.width * 0.78, size.height * 0.48);
    canvas.drawPath(pathTwo, paint);

    canvas.drawLine(
      Offset(size.width * 0.28, size.height * 0.12),
      Offset(size.width * 0.28, size.height * 0.86),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.72, size.height * 0.12),
      Offset(size.width * 0.72, size.height * 0.86),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RadarSweepPainter extends CustomPainter {
  final double progress;

  const _RadarSweepPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final ringPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [
          AppColors.primary.withValues(alpha: 0),
          AppColors.primary.withValues(alpha: 0.10),
          AppColors.primary.withValues(alpha: 0.34),
          AppColors.primary.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.55, 0.82, 1.0],
        transform: GradientRotation(progress * math.pi * 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius * 0.58, ringPaint);
    canvas.drawCircle(center, radius * 0.80, ringPaint);
    canvas.drawCircle(center, radius * 0.96, ringPaint);
    canvas.drawCircle(center, radius * 0.96, sweepPaint);

    final angle = progress * math.pi * 2 - math.pi / 2;
    final tip = Offset(
      center.dx + math.cos(angle) * radius * 0.96,
      center.dy + math.sin(angle) * radius * 0.96,
    );
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.34)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarSweepPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _HomeSearchPage extends StatefulWidget {
  final List<_RestaurantData> restaurants;
  final AppLocation currentLocation;

  const _HomeSearchPage({
    required this.restaurants,
    required this.currentLocation,
  });

  @override
  State<_HomeSearchPage> createState() => _HomeSearchPageState();
}

class _HomeSearchPageState extends State<_HomeSearchPage> {
  static const _recentSearchesKey = 'home_recent_searches_v1';

  late final TextEditingController _controller;
  String _query = '';
  List<String> _recentSearches = const [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController()
      ..addListener(() => setState(() => _query = _controller.text.trim()));
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hits = _searchHits;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        toolbarHeight: 52,
        backgroundColor: AppColors.primary,
        surfaceTintColor: AppColors.primary,
        leadingWidth: 42,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        titleSpacing: 0,
        title: Container(
          height: 38,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(19),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                color: AppColors.primary,
                size: 17,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Tìm món hoặc quán',
                    hintStyle: TextStyle(color: Color(0xFF9E9E9E)),
                  ),
                  style: const TextStyle(
                    color: Color(0xFF212121),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) => _rememberQuery(value),
                ),
              ),
              if (_query.isNotEmpty)
                InkWell(
                  onTap: _controller.clear,
                  customBorder: const CircleBorder(),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF9E9E9E),
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          if (_query.isEmpty && _recentSearches.isNotEmpty) ...[
            _SearchSectionHeader(
              title: 'Tìm kiếm gần đây',
              actionLabel: 'Xóa',
              onAction: _clearRecentSearches,
            ),
            const SizedBox(height: 7),
            _RecentSearchStrip(items: _recentSearches, onPick: _setQuery),
            const SizedBox(height: 12),
          ],
          if (_query.isEmpty) ...[
            const _SearchSectionHeader(title: 'Từ khóa hot'),
            const SizedBox(height: 7),
            _SearchSuggestionStrip(onPick: _setQuery),
            const SizedBox(height: 12),
            _SearchDealShortcuts(onOpen: _openDealShortcut),
            const SizedBox(height: 12),
          ],
          Text(
            _query.isEmpty ? 'Gợi ý gần bạn' : 'Kết quả phù hợp',
            style: const TextStyle(
              color: Color(0xFF212121),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          if (hits.isEmpty)
            const _SearchEmptyState()
          else
            for (final hit in hits)
              _SearchResultTile(hit: hit, onOpen: () => _openHit(hit)),
        ],
      ),
    );
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _recentSearches = prefs.getStringList(_recentSearchesKey) ?? const [];
    });
  }

  Future<void> _rememberQuery(String value) async {
    final clean = value.trim();
    if (clean.isEmpty) return;
    final next = [
      clean,
      ..._recentSearches.where((item) => item != clean),
    ].take(8).toList();
    setState(() => _recentSearches = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, next);
  }

  Future<void> _clearRecentSearches() async {
    setState(() => _recentSearches = const []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
  }

  void _setQuery(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    unawaited(_rememberQuery(value));
  }

  void _openHit(_SearchHit hit) {
    unawaited(_rememberQuery(_query.isEmpty ? hit.menuItem.name : _query));
    _openRestaurantDetail(
      context,
      hit.restaurant,
      currentLocation: hit.currentLocation,
    );
  }

  void _openDealShortcut(_SearchDealShortcutData data) {
    unawaited(_rememberQuery(data.title));
    _openPromoResults(
      context,
      title: data.title,
      subtitle: data.subtitle,
      seed: data.seed,
    );
  }

  List<_SearchHit> get _searchHits {
    final query = _query.toLowerCase();
    final source = List<_RestaurantData>.of(widget.restaurants)
      ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    final hits = <_SearchHit>[];

    for (final restaurant in source) {
      final input = _restaurantInputForSearch(
        restaurant,
        widget.currentLocation,
      );
      final menuItems = MenuFactory.sectionsFor(
        input,
      ).expand((section) => section.items).take(6).toList();
      final restaurantText =
          '${restaurant.name} ${restaurant.address} ${restaurant.category} ${restaurant.badges.join(' ')}'
              .toLowerCase();

      if (query.isEmpty || restaurantText.contains(query)) {
        hits.add(
          _SearchHit(
            restaurant: restaurant,
            menuItem: menuItems.first,
            currentLocation: widget.currentLocation,
          ),
        );
        continue;
      }

      final matchedItem = menuItems.cast<MenuItemData?>().firstWhere(
        (item) =>
            item != null &&
            '${item.name} ${item.description}'.toLowerCase().contains(query),
        orElse: () => null,
      );
      if (matchedItem != null) {
        hits.add(
          _SearchHit(
            restaurant: restaurant,
            menuItem: matchedItem,
            currentLocation: widget.currentLocation,
          ),
        );
      }
    }

    return hits.take(query.isEmpty ? 10 : 24).toList();
  }
}

class _SearchSuggestionStrip extends StatelessWidget {
  final ValueChanged<String> onPick;

  const _SearchSuggestionStrip({required this.onPick});

  @override
  Widget build(BuildContext context) {
    const suggestions = ['trà sữa', 'cơm tấm', 'gà rán', 'bún bò', 'freeship'];
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = suggestions[index];
          return ActionChip(
            onPressed: () => onPick(label),
            label: Text(label),
            labelStyle: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            backgroundColor: const Color(0xFFFFF0ED),
            side: BorderSide.none,
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}

class _SearchSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SearchSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF212121),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF757575),
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

class _RecentSearchStrip extends StatelessWidget {
  final List<String> items;
  final ValueChanged<String> onPick;

  const _RecentSearchStrip({required this.items, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = items[index];
          return ActionChip(
            onPressed: () => onPick(label),
            avatar: const Icon(
              Icons.history_rounded,
              color: Color(0xFF757575),
              size: 15,
            ),
            label: Text(label),
            labelStyle: const TextStyle(
              color: Color(0xFF424242),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFEDEDED)),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}

class _SearchDealShortcutData {
  final String title;
  final String subtitle;
  final String seed;
  final IconData icon;
  final Color color;

  const _SearchDealShortcutData({
    required this.title,
    required this.subtitle,
    required this.seed,
    required this.icon,
    required this.color,
  });
}

const _searchDealShortcuts = [
  _SearchDealShortcutData(
    title: 'Flash Sale',
    subtitle: 'Món hot giảm sâu trong khung giờ vàng',
    seed: 'search-flash-sale',
    icon: Icons.flash_on_rounded,
    color: Color(0xFFFF9800),
  ),
  _SearchDealShortcutData(
    title: 'Freeship Xtra',
    subtitle: 'Quán có mã freeship quanh bạn',
    seed: 'search-freeship',
    icon: Icons.local_shipping_outlined,
    color: AppColors.success,
  ),
  _SearchDealShortcutData(
    title: 'Trà sữa giảm 50%',
    subtitle: 'Ly lạnh, giá mềm, giao nhanh',
    seed: 'search-milk-tea',
    icon: Icons.local_cafe_outlined,
    color: AppColors.primary,
  ),
];

class _SearchDealShortcuts extends StatelessWidget {
  final ValueChanged<_SearchDealShortcutData> onOpen;

  const _SearchDealShortcuts({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SearchSectionHeader(title: 'Săn deal nhanh'),
        const SizedBox(height: 7),
        SizedBox(
          height: 74,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _searchDealShortcuts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = _searchDealShortcuts[index];
              return InkWell(
                onTap: () => onOpen(item),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 156,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEDEDED)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(item.icon, color: item.color, size: 21),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF212121),
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF757575),
                                fontSize: 10.5,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final _SearchHit hit;
  final VoidCallback onOpen;

  const _SearchResultTile({required this.hit, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final item = hit.menuItem;
    final restaurant = hit.restaurant;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: _SearchFoodImage(path: item.imageUrl),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF212121),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF424242),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${formatRating(restaurant.rating)} | ${restaurant.distance.toStringAsFixed(1)}km | ${restaurant.time} phút',
                      style: const TextStyle(
                        color: Color(0xFF757575),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      checkoutFormatPrice(item.price),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SearchAddButton(hit: hit),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchAddButton extends StatelessWidget {
  final _SearchHit hit;

  const _SearchAddButton({required this.hit});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        OrderState.mergeCartItem(_checkoutOrderFromSearchHit(hit));
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('Đã thêm ${hit.menuItem.name} vào giỏ'),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(milliseconds: 900),
            ),
          );
      },
      customBorder: const CircleBorder(),
      child: Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 19),
      ),
    );
  }
}

class _SearchFoodImage extends StatelessWidget {
  final String path;

  const _SearchFoodImage({required this.path});

  @override
  Widget build(BuildContext context) {
    Widget fallback() {
      return Container(
        width: 58,
        height: 58,
        color: const Color(0xFFEDEDED),
        child: const Icon(Icons.restaurant_rounded, color: Colors.white),
      );
    }

    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        width: 58,
        height: 58,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    }

    return Image.network(
      path,
      width: 58,
      height: 58,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback(),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.search_off_rounded, color: Color(0xFFBDBDBD), size: 42),
          SizedBox(height: 10),
          Text(
            'Chưa tìm thấy món phù hợp',
            style: TextStyle(
              color: Color(0xFF616161),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Thử tìm tên món khác hoặc tên quán gần bạn.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SearchHit {
  final _RestaurantData restaurant;
  final MenuItemData menuItem;
  final AppLocation currentLocation;

  const _SearchHit({
    required this.restaurant,
    required this.menuItem,
    required this.currentLocation,
  });
}

RestaurantDetailInput _restaurantInputForSearch(
  _RestaurantData restaurant,
  AppLocation currentLocation,
) {
  return RestaurantDetailInput(
    id: restaurant.seed,
    name: restaurant.name,
    address: restaurant.address,
    seed: restaurant.seed,
    category: restaurant.category,
    rating: restaurant.rating,
    distance: restaurant.distance,
    time: restaurant.time,
    sold: restaurant.sold,
    imageUrl: restaurant.imageUrl ?? _imageUrlForSeed(restaurant.seed),
    openNow: !restaurant.isClosingSoon,
    latitude: restaurant.latitude,
    longitude: restaurant.longitude,
    customerLatitude: currentLocation.latitude,
    customerLongitude: currentLocation.longitude,
  );
}

CheckoutOrder _checkoutOrderFromSearchHit(_SearchHit hit) {
  final restaurant = hit.restaurant;
  final item = hit.menuItem;
  return CheckoutOrder(
    restaurant: CheckoutRestaurantInfo(
      id: restaurant.seed,
      name: restaurant.name,
      address: restaurant.address,
      deliveryMinutes: restaurant.time,
      distanceKm: restaurant.distance,
      latitude: restaurant.latitude,
      longitude: restaurant.longitude,
    ),
    items: [
      CartItem(
        id: '${restaurant.seed}-${item.name}',
        name: item.name,
        description: item.description,
        imageUrl: item.imageUrl,
        unitPrice: item.price,
        quantity: 1,
        toppings: const [],
        note: '',
      ),
    ],
    address: 'Vị trí hiện tại của bạn',
    receiverName: 'Khách hàng',
    receiverPhone: '0961687964',
  );
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topPadding;
  final String address;
  final VoidCallback onBack;
  final VoidCallback onAddressTap;
  final VoidCallback onSearchTap;

  const _HeaderDelegate({
    required this.topPadding,
    required this.address,
    required this.onBack,
    required this.onAddressTap,
    required this.onSearchTap,
  });

  @override
  double get minExtent => topPadding + 102;

  @override
  double get maxExtent => topPadding + 102;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      height: maxExtent,
      child: Container(
        color: AppColors.primary,
        padding: EdgeInsets.fromLTRB(8, topPadding + 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(
              height: 36,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Tooltip(
                    message: 'Quay lại',
                    child: InkWell(
                      onTap: onBack,
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 34,
                        height: 34,
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: onAddressTap,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Giao đến',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xD9FFFFFF),
                                fontSize: 10,
                                height: 1.1,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      letterSpacing: 0,
                                      height: 1.1,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: onSearchTap,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tìm món, quán, mã giảm giá',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HeaderDelegate oldDelegate) {
    return oldDelegate.topPadding != topPadding ||
        oldDelegate.address != address ||
        oldDelegate.onAddressTap != onAddressTap ||
        oldDelegate.onSearchTap != onSearchTap;
  }
}

class _SortTabsDelegate extends SliverPersistentHeaderDelegate {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _SortTabsDelegate({required this.selectedIndex, required this.onTap});

  @override
  double get minExtent => 40;

  @override
  double get maxExtent => 40;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    const tabs = ['Gần tôi', 'Bán chạy', 'Đánh giá'];

    return Container(
      color: Colors.white,
      child: Row(
        children: List.generate(tabs.length, (index) {
          final active = index == selectedIndex;

          return Expanded(
            child: InkWell(
              onTap: () => onTap(index),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active
                          ? AppColors.primary
                          : const Color(0xFFF0F0F0),
                      width: active ? 2 : 1,
                    ),
                  ),
                ),
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    color: active ? AppColors.primary : const Color(0xFF757575),
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SortTabsDelegate oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex;
  }
}

class _HeroBanner extends StatelessWidget {
  final _BannerData data;
  final Animation<double> motion;
  final Duration countdown;

  const _HeroBanner({
    required this.data,
    required this.motion,
    required this.countdown,
  });

  @override
  Widget build(BuildContext context) {
    final child = switch (data.variant) {
      _BannerVariant.deal77 => _Deal77Banner(data: data, motion: motion),
      _BannerVariant.phucLong => _PhucLongBanner(data: data, motion: motion),
      _BannerVariant.freeship => _FreeshipBanner(data: data, motion: motion),
      _BannerVariant.flashCountdown => _FlashCountdownBanner(
        data: data,
        motion: motion,
        countdown: countdown,
      ),
      _BannerVariant.hiddenDeal => _HiddenDealBanner(
        data: data,
        motion: motion,
      ),
    };

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _openPromoResults(
          context,
          title: data.title,
          subtitle: '${data.kicker} · ${data.badge}',
          seed: data.seed,
        ),
        child: child,
      ),
    );
  }
}

class _Deal77Banner extends StatelessWidget {
  final _BannerData data;
  final Animation<double> motion;

  const _Deal77Banner({required this.data, required this.motion});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFEE4D2D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          _MotionDecor(motion: motion, variant: _DecorVariant.bubbles),
          const _CircleDecor(left: 142, bottom: -50, size: 120, alpha: 0.08),
          const _CircleDecor(right: -28, top: -34, size: 92, alpha: 0.12),
          const _CircleDecor(left: 258, top: 10, size: 66, alpha: 0.09),
          const _CircleDecor(left: -28, bottom: -24, size: 72, alpha: 0.08),
          Positioned(
            right: -8,
            bottom: -8,
            width: 176,
            height: 176,
            child: _BannerNetworkImage(seed: data.seed, fit: BoxFit.contain),
          ),
          const _PercentBadge(),
          Positioned(
            left: 12,
            top: 8,
            width: 210,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BannerPill(
                  label: 'DEAL 7.7 HÔM NAY',
                  background: Color(0x40000000),
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                const SizedBox(height: 3),
                Text(
                  data.dealLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  data.value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 31,
                    height: 1.0,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  data.subValue,
                  style: const TextStyle(
                    color: Color(0xFFFFE082),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Row(
                  children: [
                    _BannerPill(
                      label: 'FREESHIP',
                      background: Color(0xFF2ECC71),
                      color: Colors.white,
                    ),
                    SizedBox(width: 6),
                    _BannerPill(
                      label: 'Mã hôm nay',
                      background: Color(0x40FFFFFF),
                      color: Colors.white,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _CtaButton(label: data.badge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhucLongBanner extends StatelessWidget {
  final _BannerData data;
  final Animation<double> motion;

  const _PhucLongBanner({required this.data, required this.motion});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF9A825), Color(0xFFF57F17), Color(0xFF4CAF50)],
          stops: [0, 0.5, 1],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Stack(
        children: [
          _MotionDecor(motion: motion, variant: _DecorVariant.leaves),
          const _TeaLeaf(left: 30, top: 18, rotation: -0.4),
          const _TeaLeaf(left: 214, top: 18, rotation: 0.35),
          const _TeaLeaf(left: 258, bottom: 16, rotation: -0.1),
          const _TeaLeaf(left: 96, bottom: 24, rotation: 0.2),
          Positioned(
            right: -4,
            top: 0,
            height: 160,
            width: 178,
            child: Image.asset(
              'assets/images/banners/phuc_long_drinks.jpg',
              fit: BoxFit.contain,
              alignment: Alignment.centerRight,
            ),
          ),
          const _PercentBadge(label: 'HOT', right: 12, top: 10),
          Positioned(
            left: 12,
            top: 15,
            right: 142,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BannerPill(
                  label: 'PHÚC LONG HÈ ĐẬM VỊ',
                  background: Color(0xFF1B5E20),
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    _PriceBox(title: 'COMBO', price: '99.000'),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      child: Text(
                        '+',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _PriceBox(title: 'VOUCHER', price: '40.000'),
                  ],
                ),
                const SizedBox(height: 12),
                _CtaButton(label: data.badge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeshipBanner extends StatelessWidget {
  final _BannerData data;
  final Animation<double> motion;

  const _FreeshipBanner({required this.data, required this.motion});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(color: Color(0xFFC62828)),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: const _LightRaysPainter()),
          ),
          _MotionDecor(motion: motion, variant: _DecorVariant.rays),
          Positioned(
            right: 0,
            top: 0,
            width: 234,
            height: 160,
            child: _BannerNetworkImage(seed: data.seed, fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFC62828).withValues(alpha: 0.95),
                    const Color(0xFFC62828).withValues(alpha: 0.72),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.4, 1],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          const _PercentBadge(label: '-50%', right: 10, top: 10),
          Positioned(
            left: 14,
            top: 14,
            width: 168,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BannerPill(
                  label: 'SIÊU TIỆC FREESHIP',
                  background: Color(0x33FFFFFF),
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Combo ngon',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'giảm tới',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const Text(
                  '50%',
                  style: TextStyle(
                    color: Color(0xFFFFE082),
                    fontSize: 48,
                    height: 1.0,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlashCountdownBanner extends StatelessWidget {
  final _BannerData data;
  final Animation<double> motion;
  final Duration countdown;

  const _FlashCountdownBanner({
    required this.data,
    required this.motion,
    required this.countdown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B1226), Color(0xFF263A8B), Color(0xFF00B8D4)],
          stops: [0, 0.58, 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          _MotionDecor(motion: motion, variant: _DecorVariant.spark),
          Positioned(
            right: -10,
            bottom: -14,
            width: 196,
            height: 178,
            child: _BannerNetworkImage(seed: data.seed, fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0B1226).withValues(alpha: 0.95),
                    const Color(0xFF0B1226).withValues(alpha: 0.56),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.5, 1],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          const _PercentBadge(label: '-60%', right: 10, top: 10),
          Positioned(
            left: 14,
            top: 12,
            width: 210,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BannerPill(
                  label: 'FLASH SALE 30 PHÚT',
                  background: Color(0xFFFFD600),
                  color: Color(0xFF1A237E),
                  fontWeight: FontWeight.w900,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Món hot',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'giảm sâu',
                  style: TextStyle(
                    color: Color(0xFF80DEEA),
                    fontSize: 30,
                    height: 1.0,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                _BannerCountdown(value: countdown),
                const SizedBox(height: 7),
                _CtaButton(label: data.badge, compact: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HiddenDealBanner extends StatelessWidget {
  final _BannerData data;
  final Animation<double> motion;

  const _HiddenDealBanner({required this.data, required this.motion});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2E1065), Color(0xFF7C3AED), Color(0xFFFFD166)],
          stops: [0, 0.58, 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          _MotionDecor(motion: motion, variant: _DecorVariant.confetti),
          Positioned(
            right: -20,
            top: -8,
            width: 196,
            height: 178,
            child: _BannerNetworkImage(seed: data.seed, fit: BoxFit.cover),
          ),
          Positioned(
            right: 18,
            bottom: 12,
            child: Transform.rotate(
              angle: -0.08,
              child: const _ScratchDealCard(),
            ),
          ),
          Positioned(
            left: 14,
            top: 13,
            width: 178,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BannerPill(
                  label: 'MÃ ẨN HÔM NAY',
                  background: Color(0x33000000),
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
                const SizedBox(height: 9),
                const Text(
                  'Lắc nhẹ mở deal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Voucher bí mật tới 70K',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _CtaButton(label: data.badge, compact: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleDecor extends StatelessWidget {
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final double size;
  final double alpha;

  const _CircleDecor({
    this.left,
    this.right,
    this.top,
    this.bottom,
    required this.size,
    required this.alpha,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: alpha),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _MotionDecor extends StatelessWidget {
  final Animation<double> motion;
  final _DecorVariant variant;

  const _MotionDecor({required this.motion, required this.variant});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: motion,
          builder: (_, _) {
            return CustomPaint(
              painter: _MotionDecorPainter(
                progress: motion.value,
                variant: variant,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MotionDecorPainter extends CustomPainter {
  final double progress;
  final _DecorVariant variant;

  const _MotionDecorPainter({required this.progress, required this.variant});

  @override
  void paint(Canvas canvas, Size size) {
    switch (variant) {
      case _DecorVariant.bubbles:
        _paintBubbles(canvas, size);
      case _DecorVariant.leaves:
        _paintLeaves(canvas, size);
      case _DecorVariant.rays:
        _paintRays(canvas, size);
      case _DecorVariant.spark:
        _paintSpark(canvas, size);
      case _DecorVariant.confetti:
        _paintConfetti(canvas, size);
    }
  }

  void _paintBubbles(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final specs = [
      (0.18, 0.18, 18.0, 0.10),
      (0.52, 0.68, 38.0, 0.09),
      (0.80, 0.22, 24.0, 0.11),
      (0.40, 0.34, 14.0, 0.08),
    ];
    for (final spec in specs) {
      final wobble = math.sin((progress * math.pi * 2) + spec.$1 * 8) * 7;
      paint.color = Colors.white.withValues(alpha: spec.$4);
      canvas.drawCircle(
        Offset(size.width * spec.$1 + wobble, size.height * spec.$2 - wobble),
        spec.$3,
        paint,
      );
    }
  }

  void _paintLeaves(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1B5E20).withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 8; i++) {
      final x = (i * 54 + progress * 46) % (size.width + 36) - 18;
      final y = 20 + (i % 4) * 34 + math.sin(progress * 6 + i) * 4;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(-0.55 + i * 0.18);
      canvas.drawOval(const Rect.fromLTWH(-6, -12, 12, 24), paint);
      canvas.restore();
    }
  }

  void _paintRays(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1.2;
    final offset = progress * 22;
    for (var i = -3; i < 8; i++) {
      final x = i * 54 + offset;
      canvas.drawLine(Offset(x, 0), Offset(x + 92, size.height), paint);
    }
  }

  void _paintSpark(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFFFFD600).withValues(alpha: 0.48)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final dot = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 12; i++) {
      final x = (i * 37 + progress * 60) % size.width;
      final y = 16.0 + ((i * 23) % 126);
      canvas.drawCircle(Offset(x, y), 2.0 + (i % 3), dot);
      if (i.isEven) {
        canvas.drawLine(Offset(x - 5.0, y), Offset(x + 5.0, y), line);
        canvas.drawLine(Offset(x, y - 5.0), Offset(x, y + 5.0), line);
      }
    }
  }

  void _paintConfetti(Canvas canvas, Size size) {
    final colors = [
      Colors.white.withValues(alpha: 0.26),
      const Color(0xFFFFD166).withValues(alpha: 0.36),
      const Color(0xFF2DD4BF).withValues(alpha: 0.28),
    ];
    for (var i = 0; i < 18; i++) {
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;
      final x = (i * 31 + progress * 72) % (size.width + 20) - 10;
      final y = (i * 19 + math.sin(progress * 8 + i) * 8) % size.height;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * math.pi * 2 + i);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-5, -2, 10, 4),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _MotionDecorPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.variant != variant;
  }
}

enum _DecorVariant { bubbles, leaves, rays, spark, confetti }

class _BannerPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color color;
  final FontWeight fontWeight;

  const _BannerPill({
    required this.label,
    required this.background,
    required this.color,
    this.fontWeight = FontWeight.w700,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontSize: 10, fontWeight: fontWeight),
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  final String label;
  final bool compact;

  const _CtaButton({required this.label, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 28 : 32,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.primary,
            size: compact ? 15 : 17,
          ),
        ],
      ),
    );
  }
}

class _BannerCountdown extends StatelessWidget {
  final Duration value;

  const _BannerCountdown({required this.value});

  @override
  Widget build(BuildContext context) {
    final hours = value.inHours.toString().padLeft(2, '0');
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BannerTimeBox(hours),
        const _TimeColon(),
        _BannerTimeBox(minutes),
        const _TimeColon(),
        _BannerTimeBox(seconds),
      ],
    );
  }
}

class _BannerTimeBox extends StatelessWidget {
  final String value;

  const _BannerTimeBox(this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Color(0xFF1A237E),
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TimeColon extends StatelessWidget {
  const _TimeColon();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 3),
      child: Text(
        ':',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ScratchDealCard extends StatelessWidget {
  const _ScratchDealCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 54,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEAL ẨN',
            style: TextStyle(
              color: Color(0xFF7C3AED),
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          Spacer(),
          Text(
            '-70K',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 22,
              height: 0.9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PercentBadge extends StatelessWidget {
  final String label;
  final double right;
  final double top;

  const _PercentBadge({this.label = '-50%', this.right = 10, this.top = 10});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1C40F),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7D6608),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _BannerNetworkImage extends StatelessWidget {
  final String seed;
  final BoxFit fit;

  const _BannerNetworkImage({required this.seed, required this.fit});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Image.network(
        _imageUrlForSeed(seed),
        fit: fit,
        alignment: Alignment.bottomRight,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

class _PriceBox extends StatelessWidget {
  final String title;
  final String price;

  const _PriceBox({required this.title, required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            price,
            style: const TextStyle(
              color: Color(0xFFF9A825),
              fontSize: 22,
              height: 1.0,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'ĐỒNG',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeaLeaf extends StatelessWidget {
  final double? left;
  final double? top;
  final double? bottom;
  final double rotation;

  const _TeaLeaf({this.left, this.top, this.bottom, required this.rotation});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      bottom: bottom,
      child: Transform.rotate(
        angle: rotation,
        child: Icon(
          Icons.eco_rounded,
          color: const Color(0xFF1B5E20).withValues(alpha: 0.18),
          size: 26,
        ),
      ),
    );
  }
}

class _LightRaysPainter extends CustomPainter {
  const _LightRaysPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.72, size.height * 0.5);
    final radial = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x44EF5350), Color(0x00EF5350)],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.8));
    canvas.drawRect(Offset.zero & size, radial);

    final ray = Paint()..color = Colors.white.withValues(alpha: 0.06);
    for (var i = -3; i <= 3; i++) {
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(size.width, center.dy + i * 26 - 9)
        ..lineTo(size.width, center.dy + i * 26 + 9)
        ..close();
      canvas.drawPath(path, ray);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CategoryRow extends StatelessWidget {
  final List<_CategoryData> items;

  const _CategoryRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return _HorizontalRow(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      gap: 0,
      children: [for (final item in items) _CategoryItem(item: item)],
    );
  }
}

class _CategoryItem extends StatefulWidget {
  final _CategoryData item;

  const _CategoryItem({required this.item});

  @override
  State<_CategoryItem> createState() => _CategoryItemState();
}

class _CategoryItemState extends State<_CategoryItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _translateY;
  late final Animation<double> _shadowOpacity;
  late final Animation<double> _shadowBlur;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 220),
    );

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _scale = Tween<double>(begin: 1, end: 1.10).animate(curved);
    _translateY = Tween<double>(begin: 0, end: -5).animate(curved);
    _shadowOpacity = Tween<double>(begin: 0, end: 0.45).animate(curved);
    _shadowBlur = Tween<double>(begin: 0, end: 12).animate(curved);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pressIn() => _controller.forward();

  void _pressOut() => _controller.reverse();

  void _handleHoverEnter(PointerEnterEvent event) {
    _hovered = true;
    _pressIn();
  }

  void _handleHoverExit(PointerExitEvent event) {
    _hovered = false;
    _pressOut();
  }

  void _handleTapEnd() {
    if (_hovered) {
      _pressIn();
    } else {
      _pressOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: _handleHoverEnter,
        onExit: _handleHoverExit,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _pressIn(),
          onTapUp: (_) => _handleTapEnd(),
          onTapCancel: _handleTapEnd,
          onTap: () => _openPromoResults(
            context,
            title: widget.item.label,
            subtitle: widget.item.sub,
            seed: widget.item.assetPath,
          ),
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _translateY.value),
                    child: Transform.scale(
                      scale: _scale.value,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: _shadowOpacity.value,
                              ),
                              blurRadius: _shadowBlur.value,
                              spreadRadius: 0,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: child,
                      ),
                    ),
                  );
                },
                child: Image.asset(
                  widget.item.assetPath,
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF212121),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.item.sub.isNotEmpty)
                Text(
                  widget.item.sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DealLargeCard extends StatelessWidget {
  final _DealData data;

  const _DealLargeCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openPromoResults(
        context,
        title: data.name,
        subtitle: '${data.restaurant} · Giảm ${data.discount}%',
        seed: data.seed,
      ),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 250,
        decoration: _cardDecoration(8),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _ImageTile(
                  seed: data.seed,
                  width: double.infinity,
                  height: 152,
                  radius: 0,
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: _DiscountPill(discount: data.discount),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: _DealText(data: data, big: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DealSmallCard extends StatelessWidget {
  final _DealData data;

  const _DealSmallCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openPromoResults(
        context,
        title: data.name,
        subtitle: '${data.restaurant} · Giảm ${data.discount}%',
        seed: data.seed,
      ),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 121.5,
        decoration: _cardDecoration(8),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Stack(
              children: [
                _ImageTile(
                  seed: data.seed,
                  width: 70,
                  height: double.infinity,
                  radius: 0,
                ),
                Positioned(
                  top: 6,
                  left: 5,
                  child: _DiscountPill(discount: data.discount),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: _DealText(data: data, big: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DealText extends StatelessWidget {
  final _DealData data;
  final bool big;

  const _DealText({required this.data, required this.big});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.restaurant,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF757575), fontSize: 10),
        ),
        const SizedBox(height: 3),
        Text(
          data.name,
          maxLines: big ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFF212121),
            fontSize: big ? 12 : 11,
            height: 1.12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          formatPrice(data.price),
          style: TextStyle(
            color: AppColors.primary,
            fontSize: big ? 13 : 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          formatPrice(data.originalPrice),
          style: const TextStyle(
            color: Color(0xFF9E9E9E),
            fontSize: 11,
            decoration: TextDecoration.lineThrough,
          ),
        ),
      ],
    );
  }
}

class _WhiteSection extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? titleWidget;
  final Widget child;
  final VoidCallback? onSeeMore;

  const _WhiteSection({
    required this.child,
    this.title,
    this.subtitle,
    this.titleWidget,
    this.onSeeMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child:
                      titleWidget ??
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title ?? '',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF757575),
                                fontSize: 11,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ],
                      ),
                ),
                _SeeMore(color: AppColors.primary, onTap: onSeeMore),
              ],
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final _CollectionData item;
  final double width;

  const _CollectionCard({required this.item, required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => _openPromoResults(
          context,
          title: item.name,
          subtitle: 'Bộ sưu tập món giảm đang có',
          seed: item.seed,
        ),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _ImageTile(
                  seed: item.seed,
                  width: width,
                  height: 180,
                  radius: 12,
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.32),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  left: 8,
                  bottom: 8,
                  child: _MiniBadge(label: 'Hot', dark: true),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF212121),
                fontSize: 12,
                height: 1.18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlashCard extends StatelessWidget {
  final _FlashData item;

  const _FlashCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openPromoResults(
        context,
        title: item.name,
        subtitle: 'Flash Sale giảm ${item.discount}%',
        seed: item.seed,
      ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 140,
        decoration: _cardDecoration(10),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _ImageTile(seed: item.seed, width: 140, height: 130, radius: 0),
                Positioned(
                  top: 7,
                  left: 7,
                  child: _DiscountPill(discount: item.discount),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF212121),
                      fontSize: 12,
                      height: 1.16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatPrice(item.price),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: item.hot
                          ? const Color(0xFFFFEBEE)
                          : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: item.hot
                            ? const Color(0xFFEF9A9A)
                            : const Color(0xFFA5D6A7),
                      ),
                    ),
                    child: Text(
                      item.hot ? 'ĐANG BÁN CHẠY' : '${item.soldCount} ĐÃ BÁN',
                      style: TextStyle(
                        color: item.hot
                            ? const Color(0xFFC62828)
                            : const Color(0xFF2E7D32),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  final _RecentData item;
  final VoidCallback onTap;

  const _RecentCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: _cardDecoration(10),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _ImageTile(
                  seed: item.seed,
                  width: double.infinity,
                  height: 92,
                  radius: 0,
                ),
                Positioned(
                  left: 7,
                  bottom: 7,
                  child: _MiniBadge(label: item.badge, dark: true),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF212121),
                      fontSize: 12,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.viewedAt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const _DiscountBadge(label: 'Mã giảm 22%'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfRestaurantCard extends StatelessWidget {
  final _RestaurantData item;
  final AppLocation currentLocation;

  const _ShelfRestaurantCard({
    required this.item,
    required this.currentLocation,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openRestaurantDetail(
          context,
          item,
          currentLocation: currentLocation,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _ImageTile(
                  seed: item.seed,
                  imageUrl: item.imageUrl,
                  width: 112,
                  height: 112,
                  radius: 10,
                ),
                if (item.isFavorite)
                  const Positioned(top: 6, left: 6, child: _FavoriteBadge()),
                const Positioned(
                  left: 6,
                  bottom: 6,
                  child: _MiniBadge(label: 'Siêu tiệc 99K'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.verified)
                  const Padding(
                    padding: EdgeInsets.only(top: 1, right: 3),
                    child: Icon(
                      Icons.verified_rounded,
                      color: Color(0xFFFFB300),
                      size: 13,
                    ),
                  ),
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF212121),
                      fontSize: 11,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final badge in item.badges.take(2))
                  _DiscountBadge(label: badge),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TopPhotoCard extends StatelessWidget {
  final _RestaurantData item;
  final AppLocation currentLocation;

  const _TopPhotoCard({required this.item, required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openRestaurantDetail(
        context,
        item,
        currentLocation: currentLocation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: _ImageTile(
                  seed: item.seed,
                  imageUrl: item.imageUrl,
                  width: double.infinity,
                  height: double.infinity,
                  radius: 8,
                ),
              ),
              const Positioned(
                left: 5,
                bottom: 5,
                child: _MiniBadge(label: 'FREESHIP'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF212121),
                fontSize: 10.5,
                height: 1.12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantRow extends StatelessWidget {
  final _RestaurantData item;
  final AppLocation currentLocation;

  const _RestaurantRow({required this.item, required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openRestaurantDetail(
        context,
        item,
        currentLocation: currentLocation,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFF0F0F0), width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _ImageTile(
                  seed: item.seed,
                  imageUrl: item.imageUrl,
                  width: 88,
                  height: 88,
                  radius: 10,
                ),
                if (item.isFavorite)
                  const Positioned(top: 5, left: 5, child: _FavoriteBadge()),
                Positioned(
                  left: 5,
                  bottom: 5,
                  child: _MiniBadge(
                    label: item.freeshipXtra ? 'X9 FREESHIP' : 'Siêu tiệc',
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.isClosingSoon) ...[
                    Text(
                      'Sắp đóng cửa · Đóng cửa lúc ${item.closingAt}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.verified)
                        const Padding(
                          padding: EdgeInsets.only(top: 2, right: 4),
                          child: Icon(
                            Icons.verified_rounded,
                            color: Color(0xFFFFB300),
                            size: 13,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF212121),
                            fontSize: 13,
                            height: 1.16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(
                        item.rating == null
                            ? Icons.star_border_rounded
                            : Icons.star_rounded,
                        color: const Color(0xFFFFB300),
                        size: 15,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          '${formatRating(item.rating)} | ${item.distance.toStringAsFixed(1)}km | ${item.time} phút',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF757575),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (item.address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          color: Color(0xFF9E9E9E),
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            item.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF9E9E9E),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (final badge in item.badges)
                        _DiscountBadge(label: badge),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WidePromoBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final String seed;
  final List<Color> colors;

  const _WidePromoBanner({
    required this.title,
    required this.subtitle,
    required this.seed,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _openPromoResults(
          context,
          title: title,
          subtitle: subtitle,
          seed: seed,
        ),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                right: -10,
                bottom: -16,
                child: _ImageTile(
                  seed: seed,
                  width: 160,
                  height: 130,
                  radius: 60,
                ),
              ),
              Positioned(
                left: 16,
                top: 20,
                right: 130,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.touch_app_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Chạm để xem deal',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _openPromoResults(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String seed,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          PromoResultsPage(title: title, subtitle: subtitle, seed: seed),
    ),
  );
}

void _openRestaurantDetail(
  BuildContext context,
  _RestaurantData item, {
  required AppLocation currentLocation,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RestaurantDetailPage(
        restaurant: RestaurantDetailInput(
          id: item.seed,
          name: item.name,
          address: item.address,
          seed: item.seed,
          category: item.category,
          rating: item.rating,
          distance: item.distance,
          time: item.time,
          sold: item.sold,
          imageUrl: item.imageUrl ?? _imageUrlForSeed(item.seed),
          openNow: !item.isClosingSoon,
          latitude: item.latitude,
          longitude: item.longitude,
          customerLatitude: currentLocation.latitude,
          customerLongitude: currentLocation.longitude,
        ),
      ),
    ),
  );
}

class _HomePromoDialog extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onOpenDeal;

  const _HomePromoDialog({required this.onClose, required this.onOpenDeal});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 54),
      backgroundColor: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topRight,
        children: [
          InkWell(
            onTap: onOpenDeal,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: 292,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFBFE0FF), Color(0xFF0B64E5)],
                ),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 28,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _WavePromoPainter()),
                  ),
                  Positioned(
                    top: 22,
                    left: 16,
                    right: 16,
                    child: Column(
                      children: [
                        const Text(
                          'ĂN KHUYA NGON RẺ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            height: 1.0,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(
                                color: Color(0x66000000),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFFFE0B2),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 62,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.horizontal(
                                    left: Radius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'GIẢM',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '30.000Đ',
                                    style: TextStyle(
                                      color: Color(0xFF0B64E5),
                                      fontSize: 36,
                                      height: 1,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 18,
                    bottom: 72,
                    child: _PromoFoodOrb(size: 62, seed: 'flash-tra-sua-thai'),
                  ),
                  Positioned(
                    right: 18,
                    bottom: 71,
                    child: _PromoFoodOrb(size: 58, seed: 'recent-com-tam'),
                  ),
                  Positioned(
                    left: 54,
                    right: 54,
                    bottom: 58,
                    child: _PromoFoodOrb(
                      size: 96,
                      seed: 'collection-deal-dinh',
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 18,
                    child: Center(
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Text(
                          'ĐẶT NGAY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: -10,
            top: -12,
            child: IconButton.filled(
              onPressed: onClose,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF757575),
                minimumSize: const Size(34, 34),
              ),
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPromoBubble extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _MiniPromoBubble({required this.onTap, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(9),
            child: Container(
              width: 62,
              height: 52,
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1C7CFF), Color(0xFF0838B8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'ĂN KHUYA',
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    '-20K',
                    style: TextStyle(
                      color: Color(0xFFFFF176),
                      fontSize: 20,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'ĐẶT NGAY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 7.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -8,
            right: -8,
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFF616161),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoFoodOrb extends StatelessWidget {
  final double size;
  final String seed;

  const _PromoFoodOrb({required this.size, required this.seed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: ClipOval(
        child: _ImageTile(seed: seed, width: size, height: size, radius: size),
      ),
    );
  }
}

class _WavePromoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 6; i++) {
      final y = 150.0 + i * 22;
      final path = Path()..moveTo(0, y);
      path.cubicTo(
        size.width * 0.28,
        y - 24,
        size.width * 0.58,
        y + 24,
        size.width,
        y - 6,
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HorizontalRow extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double gap;

  const _HorizontalRow({
    required this.children,
    this.padding = EdgeInsets.zero,
    this.gap = 12,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      physics: const BouncingScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) SizedBox(width: gap),
          ],
        ],
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final String seed;
  final String? imageUrl;
  final double width;
  final double height;
  final double radius;

  const _ImageTile({
    required this.seed,
    this.imageUrl,
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedImage = imageUrl ?? _imageUrlForSeed(seed);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Container(
            width: width,
            height: height,
            color: const Color(0xFFE0E0E0),
            child: const Icon(
              Icons.restaurant_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          if (resolvedImage.startsWith('assets/'))
            Image.asset(
              resolvedImage,
              width: width,
              height: height,
              fit: BoxFit.cover,
            )
          else
            Image.network(
              resolvedImage,
              width: width,
              height: height,
              fit: BoxFit.cover,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) return child;
                return const SizedBox.shrink();
              },
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

String _imageUrlForSeed(String seed) {
  const imageMap = {
    'shopee-drinks-banner':
        'https://images.unsplash.com/photo-1551024601-bec78aea704b?auto=format&fit=crop&w=800&q=80',
    'tutimi-orange-banner':
        'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=800&q=80',
    'dau-homemade-banner':
        'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?auto=format&fit=crop&w=800&q=80',
    'flash-sale-food-banner':
        'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=800&q=80',
    'tutimi-mid-banner':
        'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=900&q=80',
    'restaurant-list-promo':
        'https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=900&q=80',
    'popeyes-fried-chicken':
        'https://images.unsplash.com/photo-1562967914-608f82629710?auto=format&fit=crop&w=800&q=80',
    'kfc-combo-deal':
        'https://images.unsplash.com/photo-1571091718767-18b5b1457add?auto=format&fit=crop&w=800&q=80',
    'bun-dau-mam-tom':
        'https://images.unsplash.com/photo-1585032226651-759b368d7246?auto=format&fit=crop&w=800&q=80',
    'collection-deal-dinh':
        'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=800&q=80',
    'collection-freeship':
        'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=800&q=80',
    'collection-noodle':
        'https://images.unsplash.com/photo-1612929633738-8fe44f7ec841?auto=format&fit=crop&w=800&q=80',
    'flash-mi-y':
        'https://images.unsplash.com/photo-1551183053-bf91a1d81141?auto=format&fit=crop&w=800&q=80',
    'flash-tra-sua-thai':
        'https://images.unsplash.com/photo-1558857563-b371033873b8?auto=format&fit=crop&w=800&q=80',
    'flash-com-suon':
        'https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=800&q=80',
    'flash-ga-ran':
        'https://images.unsplash.com/photo-1562967914-608f82629710?auto=format&fit=crop&w=800&q=80',
    'recent-bun-dau':
        'https://images.unsplash.com/photo-1585032226651-759b368d7246?auto=format&fit=crop&w=800&q=80',
    'recent-matcha-mi':
        'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?auto=format&fit=crop&w=800&q=80',
    'recent-com-tam':
        'https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=800&q=80',
    'recent-ga-nuong':
        'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=800&q=80',
    'bun-dau-met-ap-1a':
        'https://images.unsplash.com/photo-1585032226651-759b368d7246?auto=format&fit=crop&w=800&q=80',
    'bun-dau-vinh-loc-a':
        'https://images.unsplash.com/photo-1612929633738-8fe44f7ec841?auto=format&fit=crop&w=800&q=80',
    'matcha-latte-mi-cay':
        'https://images.unsplash.com/photo-1551024506-0bccd828d307?auto=format&fit=crop&w=800&q=80',
    'banh-loc-hue':
        'https://images.unsplash.com/photo-1505253716362-afaea1d3d1af?auto=format&fit=crop&w=800&q=80',
    'pmt-beefsteak-pasta':
        'https://images.unsplash.com/photo-1551183053-bf91a1d81141?auto=format&fit=crop&w=800&q=80',
    'an-vat-hem':
        'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?auto=format&fit=crop&w=800&q=80',
    'mai-coffee-le-thi-ngay':
        'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=800&q=80',
    'com-tam-dem-hoang-truong':
        'https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=800&q=80',
    'chan-ga-chien-mr-kay':
        'https://images.unsplash.com/photo-1562967914-608f82629710?auto=format&fit=crop&w=800&q=80',
    'ga-nuong-com-lam':
        'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=800&q=80',
  };

  return imageMap[seed] ??
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=800&q=80';
}

String _imageUrlForCategory(String category, String seed) {
  const cafeImages = [
    'assets/images/restaurants/food_05.jpg',
    'assets/images/restaurants/food_04.jpg',
    'assets/images/restaurants/food_08.jpg',
    'assets/images/restaurants/food_12.jpg',
  ];
  const fastFoodImages = [
    'assets/images/restaurants/food_06.jpg',
    'assets/images/restaurants/food_07.jpg',
    'assets/images/restaurants/food_01.jpg',
    'assets/images/restaurants/food_11.jpg',
  ];
  const foodCourtImages = [
    'assets/images/restaurants/food_01.jpg',
    'assets/images/restaurants/food_02.jpg',
    'assets/images/restaurants/food_03.jpg',
    'assets/images/restaurants/food_09.jpg',
  ];
  const bakeryImages = [
    'assets/images/restaurants/food_10.jpg',
    'assets/images/restaurants/food_12.jpg',
    'assets/images/restaurants/food_08.jpg',
    'assets/images/restaurants/food_05.jpg',
  ];
  const restaurantImages = [
    'assets/images/restaurants/food_01.jpg',
    'assets/images/restaurants/food_02.jpg',
    'assets/images/restaurants/food_07.jpg',
    'assets/images/restaurants/food_09.jpg',
  ];

  final pool = switch (category) {
    'cafe' => cafeImages,
    'fast_food' => fastFoodImages,
    'food_court' => foodCourtImages,
    'bakery' => bakeryImages,
    _ => restaurantImages,
  };
  final index = seed.codeUnits.fold<int>(0, (sum, code) => sum + code);
  return pool[index % pool.length];
}

class _Countdown extends StatelessWidget {
  final Duration value;

  const _Countdown({required this.value});

  @override
  Widget build(BuildContext context) {
    final hours = value.inHours.toString().padLeft(2, '0');
    final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');

    return Row(
      children: [
        _TimeBox(value: hours),
        const _Colon(),
        _TimeBox(value: minutes),
        const _Colon(),
        _TimeBox(value: seconds),
      ],
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String value;

  const _TimeBox({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF212121),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontFeatures: [FontFeature.tabularFigures()],
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Colon extends StatelessWidget {
  const _Colon();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        ':',
        style: TextStyle(
          color: Color(0xFF212121),
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int activeIndex;
  final ValueChanged<int>? onTap;
  final Color activeColor;
  final Color inactiveColor;

  const _Dots({
    required this.count,
    required this.activeIndex,
    this.onTap,
    this.activeColor = Colors.white,
    this.inactiveColor = const Color(0x80FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == activeIndex;
        return GestureDetector(
          onTap: onTap == null ? null : () => onTap!(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: active ? 18 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: active ? activeColor : inactiveColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }),
    );
  }
}

class _SmallOrangeDots extends StatelessWidget {
  const _SmallOrangeDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 16,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFFFCCBB),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

class _SeeMore extends StatelessWidget {
  final Color color;
  final VoidCallback? onTap;

  const _SeeMore({required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Text(
      'Xem thêm >',
      style: TextStyle(
        color: color.withValues(alpha: 0.86),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );

    if (onTap == null) return text;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: text,
      ),
    );
  }
}

class _DiscountPill extends StatelessWidget {
  final int discount;

  const _DiscountPill({required this.discount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1C40F),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '-$discount%',
        style: const TextStyle(
          color: Color(0xFF7D6608),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DiscountBadge extends StatelessWidget {
  final String label;

  const _DiscountBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    final isFlash = normalized.contains('flash');
    final isFood = normalized.contains('mon') || normalized.contains('món');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isFlash
            ? const Color(0xFFFFEBEE)
            : isFood
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isFlash
              ? const Color(0xFFC62828)
              : isFood
              ? const Color(0xFF2E7D32)
              : const Color(0xFFE65100),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final bool dark;

  const _MiniBadge({required this.label, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: dark ? Colors.black.withValues(alpha: 0.58) : AppColors.primary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FavoriteBadge extends StatelessWidget {
  const _FavoriteBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFCE4EC),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'Yêu thích',
        style: TextStyle(
          color: Color(0xFFC62828),
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration(double radius) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFFF0F0F0)),
  );
}

String formatPrice(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(raw[i]);
  }
  return '${buffer.toString()}đ';
}

String formatRating(double? rating) {
  if (rating == null) return 'Chưa có';
  return rating.toStringAsFixed(1);
}

class _BannerData {
  final _BannerVariant variant;
  final String kicker;
  final String title;
  final String badge;
  final String seed;
  final List<Color> colors;
  final String dealLabel;
  final String value;
  final String subValue;

  const _BannerData({
    required this.variant,
    required this.kicker,
    required this.title,
    required this.badge,
    required this.seed,
    required this.colors,
    this.dealLabel = '',
    this.value = '',
    this.subValue = '',
  });
}

enum _BannerVariant { deal77, phucLong, freeship, flashCountdown, hiddenDeal }

class _CategoryData {
  final String assetPath;
  final String label;
  final String sub;

  const _CategoryData(this.assetPath, this.label, this.sub);
}

class _DealData {
  final String restaurant;
  final String name;
  final int price;
  final int originalPrice;
  final int discount;
  final String seed;

  const _DealData({
    required this.restaurant,
    required this.name,
    required this.price,
    required this.originalPrice,
    required this.discount,
    required this.seed,
  });
}

class _CollectionData {
  final String name;
  final String seed;

  const _CollectionData({required this.name, required this.seed});
}

class _FlashData {
  final String name;
  final int price;
  final int discount;
  final String seed;
  final bool hot;
  final int soldCount;

  const _FlashData({
    required this.name,
    required this.price,
    required this.discount,
    required this.seed,
    required this.hot,
    this.soldCount = 0,
  });
}

class _RecentData {
  final String name;
  final String seed;
  final String viewedAt;
  final String badge;

  const _RecentData({
    required this.name,
    required this.seed,
    required this.viewedAt,
    required this.badge,
  });
}

class _RestaurantSectionData {
  final String title;
  final String? subtitle;
  final List<_RestaurantData> items;

  const _RestaurantSectionData({
    required this.title,
    required this.items,
    this.subtitle,
  });
}

class _RestaurantData {
  final String name;
  final String seed;
  final double? rating;
  final double distance;
  final int time;
  final int sold;
  final List<String> badges;
  final String address;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final String category;
  final bool verified;
  final bool isFavorite;
  final bool isClosingSoon;
  final bool freeshipXtra;
  final String closingAt;

  const _RestaurantData({
    required this.name,
    required this.seed,
    required this.rating,
    required this.distance,
    required this.time,
    required this.sold,
    required this.badges,
    this.address = '',
    this.latitude = 10.7843,
    this.longitude = 106.5682,
    this.imageUrl,
    this.category = 'restaurant',
    this.verified = true,
    this.isFavorite = false,
    this.isClosingSoon = false,
    this.freeshipXtra = false,
    this.closingAt = '',
  });

  _RestaurantData withDistance(double value) {
    return _RestaurantData(
      name: name,
      seed: seed,
      rating: rating,
      distance: value,
      time: math.max(12, (value * 7).round() + 8),
      sold: sold,
      badges: badges,
      address: address,
      latitude: latitude,
      longitude: longitude,
      imageUrl: imageUrl,
      category: category,
      verified: verified,
      isFavorite: isFavorite,
      isClosingSoon: isClosingSoon,
      freeshipXtra: freeshipXtra,
      closingAt: closingAt,
    );
  }
}

const _banners = [
  _BannerData(
    variant: _BannerVariant.deal77,
    kicker: 'DEAL 7.7 HÔM NAY',
    title: 'Trà sữa 1.000Đ + Voucher 40.000Đ',
    badge: 'Bấm săn ngay',
    seed: 'shopee-drinks-banner',
    colors: [Color(0xFFFF6B35), Color(0xFFEE4D2D)],
    dealLabel: 'Trà sữa',
    value: '1.000Đ',
    subValue: '+ Voucher 40.000Đ',
  ),
  _BannerData(
    variant: _BannerVariant.flashCountdown,
    kicker: 'FLASH SALE 30 PHÚT',
    title: 'Món hot giảm sâu',
    badge: 'Săn ngay',
    seed: 'flash-sale-food-banner',
    colors: [Color(0xFF0B1226), Color(0xFF263A8B), Color(0xFF00B8D4)],
  ),
  _BannerData(
    variant: _BannerVariant.phucLong,
    kicker: 'PHÚC LONG HÈ ĐẬM VỊ',
    title: 'Combo 99.000Đ + Voucher 40.000Đ',
    badge: 'Xem deal',
    seed: 'dau-homemade-banner',
    colors: [Color(0xFFF9A825), Color(0xFFF57F17), Color(0xFF4CAF50)],
  ),
  _BannerData(
    variant: _BannerVariant.hiddenDeal,
    kicker: 'MÃ ẨN HÔM NAY',
    title: 'Lắc nhẹ mở deal bí mật',
    badge: 'Mở mã',
    seed: 'collection-freeship',
    colors: [Color(0xFF2E1065), Color(0xFF7C3AED), Color(0xFFFFD166)],
  ),
  _BannerData(
    variant: _BannerVariant.freeship,
    kicker: 'SIÊU TIỆC FREESHIP',
    title: 'Combo ngon giảm tới 50%',
    badge: 'Chốt đơn',
    seed: 'tutimi-orange-banner',
    colors: [Color(0xFFC62828), Color(0xFFE53935)],
  ),
];

const _categoryRowOne = [
  _CategoryData(
    'assets/icons/categories/deal_dinh.png',
    'Deal Đỉnh',
    'Giảm 50%',
  ),
  _CategoryData(
    'assets/icons/categories/mon_han.png',
    'Món Hàn',
    'Gà Rán -50%',
  ),
  _CategoryData('assets/icons/categories/mart.png', 'Mart', 'Giảm 177K'),
  _CategoryData(
    'assets/icons/categories/xien_que.png',
    'Xiên Que',
    'Freeship 0Đ',
  ),
  _CategoryData('assets/icons/categories/giam_50k.png', 'Giảm 50K', ''),
];

const _categoryRowTwo = [
  _CategoryData(
    'assets/icons/categories/katinat.png',
    'KATINAT',
    'Giảm Đến 100K',
  ),
  _CategoryData(
    'assets/icons/categories/dat_truoc.png',
    'Đặt Trước',
    'Lấy Tại Quán',
  ),
  _CategoryData('assets/icons/categories/vi_dung_dinh.png', 'Ví Đúng Đỉnh', ''),
  _CategoryData(
    'assets/icons/categories/deal_le_hoi.png',
    'Deal Lễ Hội',
    'Giảm 40K',
  ),
  _CategoryData(
    'assets/icons/categories/freeship_xtra.png',
    'Freeship Xtra',
    '',
  ),
];

const _dealCards = [
  _DealData(
    restaurant: 'Gà Rán Popeyes',
    name: '1 Miếng Gà Rán Giòn + Khoai Tây',
    price: 64900,
    originalPrice: 118000,
    discount: 45,
    seed: 'popeyes-fried-chicken',
  ),
  _DealData(
    restaurant: 'Gà Rán KFC - Nguyễn Thị Tú',
    name: 'Combo Trùm Deal 79',
    price: 69000,
    originalPrice: 94000,
    discount: 27,
    seed: 'kfc-combo-deal',
  ),
  _DealData(
    restaurant: 'Bún Đậu Mắm Tôm 1975',
    name: 'Bún Đậu Nem Chua Chả Cốm',
    price: 27000,
    originalPrice: 80000,
    discount: 66,
    seed: 'bun-dau-mam-tom',
  ),
];

const _collections = [
  _CollectionData(
    name: 'Món Ngon Deal Đỉnh, Giảm Tới 50%',
    seed: 'collection-deal-dinh',
  ),
  _CollectionData(
    name: 'Tung Deal Toàn Sàn, Freeship 0Đ',
    seed: 'collection-freeship',
  ),
  _CollectionData(
    name: 'Món Ngon Bún Phở Giảm 55.000Đ',
    seed: 'collection-noodle',
  ),
];

const _flashItems = [
  _FlashData(
    name: 'Mì Ý Kem Tôm Sốt Cay',
    price: 54450,
    discount: 45,
    seed: 'flash-mi-y',
    hot: true,
  ),
  _FlashData(
    name: 'Trà Sữa Thái Trân Châu',
    price: 9000,
    discount: 53,
    seed: 'flash-tra-sua-thai',
    hot: false,
    soldCount: 4,
  ),
  _FlashData(
    name: 'Combo Cơm Sườn Nướng',
    price: 54750,
    discount: 38,
    seed: 'flash-com-suon',
    hot: true,
  ),
  _FlashData(
    name: 'Gà Rán Giòn Cay',
    price: 35000,
    discount: 25,
    seed: 'flash-ga-ran',
    hot: true,
  ),
];

const _recentItems = [
  _RecentData(
    name: 'Bún Đậu Mẹt Ấp 1A',
    seed: 'recent-bun-dau',
    viewedAt: 'Đã xem 4 ngày trước',
    badge: 'X9',
  ),
  _RecentData(
    name: 'Matcha Latte & Mì Trộn',
    seed: 'recent-matcha-mi',
    viewedAt: 'Đã xem hôm qua',
    badge: 'Siêu tiệc',
  ),
  _RecentData(
    name: 'Cơm Tấm Đêm Hoàng Trường',
    seed: 'recent-com-tam',
    viewedAt: 'Đã xem 2 ngày trước',
    badge: 'Freeship',
  ),
  _RecentData(
    name: 'Gà Nướng Cơm Lam',
    seed: 'recent-ga-nuong',
    viewedAt: 'Đã xem 5 ngày trước',
    badge: 'Mã giảm',
  ),
];

const _restaurants = [
  _RestaurantData(
    name: 'Bún Đậu Mẹt Ấp 1A',
    seed: 'bun-dau-met-ap-1a',
    address: 'Ap 1A, Vinh Loc A, Binh Chanh',
    latitude: 10.7870,
    longitude: 106.5658,
    rating: 4.7,
    distance: 0.5,
    time: 22,
    sold: 980,
    badges: ['Mã giảm 22%'],
    imageUrl: 'assets/images/restaurants/food_01.jpg',
  ),
  _RestaurantData(
    name: 'Bún Đậu Mắm Tôm Hà Nội - Vĩnh Lộc A',
    seed: 'bun-dau-vinh-loc-a',
    address: 'Vinh Loc A, Binh Chanh',
    latitude: 10.7848,
    longitude: 106.5701,
    rating: 4.6,
    distance: 0.4,
    time: 22,
    sold: 1120,
    badges: ['Mã giảm 11%'],
    imageUrl: 'assets/images/restaurants/food_02.jpg',
  ),
  _RestaurantData(
    name: 'MƠ - Matcha Latte, Mì Cay & Mì Trộn',
    seed: 'matcha-latte-mi-cay',
    address: 'Duong Vinh Loc, Binh Chanh',
    latitude: 10.7789,
    longitude: 106.5764,
    rating: 4.9,
    distance: 1.7,
    time: 22,
    sold: 1520,
    badges: ['Giảm món', 'Mã giảm 22%'],
    isFavorite: true,
    imageUrl: 'assets/images/restaurants/food_03.jpg',
  ),
  _RestaurantData(
    name: 'Bánh Lọc Huế - Kinh Trung Ương',
    seed: 'banh-loc-hue',
    address: 'Kinh Trung Uong, Vinh Loc A',
    latitude: 10.7905,
    longitude: 106.5625,
    rating: null,
    distance: 1.0,
    time: 22,
    sold: 180,
    badges: ['Mã giảm 22%'],
    verified: false,
    imageUrl: 'assets/images/restaurants/food_04.jpg',
  ),
  _RestaurantData(
    name: 'PMT Beefsteak & Pasta - Ap 3A',
    seed: 'pmt-beefsteak-pasta',
    address: 'Ap 3A, Vinh Loc B, Binh Chanh',
    latitude: 10.8021,
    longitude: 106.5572,
    rating: 4.5,
    distance: 3.0,
    time: 27,
    sold: 730,
    badges: ['Flash Sale', 'Mã giảm 22%'],
    imageUrl: 'assets/images/restaurants/food_05.jpg',
  ),
  _RestaurantData(
    name: 'Ăn Vặt Hẻm - Sứa Sốt Mắm Nhĩ',
    seed: 'an-vat-hem',
    address: 'Hem Sua Sot Mam Nhi, Binh Chanh',
    latitude: 10.7813,
    longitude: 106.5812,
    rating: 4.8,
    distance: 1.2,
    time: 22,
    sold: 870,
    badges: ['Mã giảm 22%'],
    imageUrl: 'assets/images/restaurants/food_06.jpg',
  ),
  _RestaurantData(
    name: 'Mai Coffee - Cà Phê - Lê Thị Ngay',
    seed: 'mai-coffee-le-thi-ngay',
    address: 'Le Thi Ngay, Vinh Loc A',
    latitude: 10.7754,
    longitude: 106.5706,
    rating: null,
    distance: 0.7,
    time: 22,
    sold: 210,
    badges: ['Mã giảm 22%'],
    isClosingSoon: true,
    closingAt: '23:30',
    imageUrl: 'assets/images/restaurants/food_07.jpg',
  ),
  _RestaurantData(
    name: 'Cơm Tấm Đêm Hoàng Trường',
    seed: 'com-tam-dem-hoang-truong',
    address: 'Dem Hoang Truong, Binh Chanh',
    latitude: 10.7696,
    longitude: 106.5869,
    rating: 4.4,
    distance: 2.7,
    time: 27,
    sold: 640,
    badges: ['Giảm món', 'Mã giảm 22%'],
    imageUrl: 'assets/images/restaurants/food_08.jpg',
  ),
  _RestaurantData(
    name: 'Chân Gà Chiên - Mr. Kay',
    seed: 'chan-ga-chien-mr-kay',
    address: 'Mr. Kay, Vinh Loc B',
    latitude: 10.8072,
    longitude: 106.5528,
    rating: 4.8,
    distance: 3.6,
    time: 27,
    sold: 905,
    badges: ['Giảm món', 'Mã giảm 22%'],
    isFavorite: true,
    imageUrl: 'assets/images/restaurants/food_09.jpg',
  ),
  _RestaurantData(
    name: 'Gà Nướng Cơm Lam - Bánh Bao Kim Chi',
    seed: 'ga-nuong-com-lam',
    address: 'Ga nuong Com Lam, Binh Tan',
    latitude: 10.8138,
    longitude: 106.6021,
    rating: 4.5,
    distance: 4.6,
    time: 40,
    sold: 520,
    badges: ['Mã giảm 22%'],
    freeshipXtra: true,
    imageUrl: 'assets/images/restaurants/food_10.jpg',
  ),
];

// ignore: unused_element
final _restaurantSections = [
  _RestaurantSectionData(
    title: 'Quán Ngon Hội Tụ',
    subtitle: 'Nhiều món hot, mã FREESHIP mỗi ngày',
    items: _restaurants.take(5).toList(),
  ),
  _RestaurantSectionData(
    title: 'Quán Mới Deal Hời',
    subtitle: 'Quán mới lên sàn, giảm món liền tay',
    items: _restaurants.skip(2).take(5).toList(),
  ),
  _RestaurantSectionData(
    title: 'Chợ Hè Giảm 50%',
    subtitle: 'Săn voucher hè, ăn ngon giá mềm',
    items: _restaurants.skip(4).take(5).toList(),
  ),
  _RestaurantSectionData(
    title: 'Cú Đêm Ăn Ngon',
    subtitle: 'Món đêm giao nhanh, deal đến khuya',
    items: _restaurants.skip(5).take(5).toList(),
  ),
];
