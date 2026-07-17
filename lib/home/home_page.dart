import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../address/address_pages.dart';
import '../address/delivery_address.dart';
import '../app/app_colors.dart';
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
      body: LayoutBuilder(
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
                      address:
                          _selectedDeliveryAddress?.displayAddress ??
                          _location.address,
                      onBack: () => Navigator.maybePop(context),
                      onAddressTap: _openAddressBook,
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
                        colors: const [Color(0xFFEB5E28), Color(0xFFFFB703)],
                      ),
                    ),
                  ),
                  for (final section in _restaurantSectionsForVisibleItems)
                    SliverToBoxAdapter(child: _buildRestaurantShelf(section)),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SortTabsDelegate(
                      selectedIndex: _activeSort,
                      onTap: (index) => setState(() => _activeSort = index),
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildTopPhotoGrid()),
                  SliverToBoxAdapter(child: _buildRestaurantList()),
                  const SliverToBoxAdapter(child: SizedBox(height: 72)),
                ],
              ),
            ),
          );
        },
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

    final restaurantResult = await RestaurantRepository.loadNearby(
      activeLocation,
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

  Widget _buildLocationLoadingPage(double topPadding) {
    final address = _locationGateAddress;

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
                      size: 30,
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 3),
              const Text(
                'Đang tìm vị trí...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF757575),
                  fontSize: 20,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 64),
              AnimatedBuilder(
                animation: _bannerMotionController,
                builder: (context, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 156,
                        height: 156,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1ED),
                          borderRadius: BorderRadius.circular(78),
                        ),
                        child: CustomPaint(painter: _MapGridPainter()),
                      ),
                      SizedBox(
                        width: 128,
                        height: 128,
                        child: CustomPaint(
                          painter: _RadarSweepPainter(
                            progress: _bannerMotionController.value,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.location_on_rounded,
                        color: AppColors.primary,
                        size: 72,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  address ?? 'Đang xác định địa chỉ của bạn',
                  key: ValueKey(address ?? 'loading-address'),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: address == null
                        ? const Color(0xFF9E9E9E)
                        : const Color(0xFF212121),
                    fontSize: address == null ? 16 : 24,
                    height: 1.22,
                    fontWeight: address == null
                        ? FontWeight.w500
                        : FontWeight.w700,
                  ),
                ),
              ),
              if (_isLocating) const SizedBox(height: 50),
              const Spacer(flex: 5),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCarousel() {
    return SizedBox(
      height: 184,
      child: Column(
        children: [
          SizedBox(
            height: 160,
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
            height: 24,
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
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
      child: Column(
        children: [
          _CategoryRow(items: _categoryRowOne),
          const SizedBox(height: 14),
          _CategoryRow(items: _categoryRowTwo),
          const SizedBox(height: 10),
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
                .where((entry) => entry.status == OrderStatus.delivering)
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
                      '${activeEntries.length} đơn đang hoạt động',
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
      margin: const EdgeInsets.only(top: 8),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'TRÙM DEAL NGON SHOPEEFOOD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _SeeMore(color: Colors.white),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _DealLargeCard(data: _dealCards.first)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      _DealSmallCard(data: _dealCards[1]),
                      const SizedBox(height: 8),
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
      child: _HorizontalRow(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final item in _collections)
            _CollectionCard(item: item, width: 150),
        ],
      ),
    );
  }

  Widget _buildFlashSaleSection() {
    return _WhiteSection(
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [for (final item in _flashItems) _FlashCard(item: item)],
      ),
    );
  }

  Widget _buildRecentSection() {
    return _WhiteSection(
      title: 'Xem gần đây',
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
          itemBuilder: (context, index) =>
              _RecentCard(item: _recentItems[index]),
        ),
      ),
    );
  }

  Widget _buildRestaurantShelf(_RestaurantSectionData section) {
    return _WhiteSection(
      title: section.title,
      subtitle: section.subtitle,
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

    return InkWell(
      onTap: isDelivering
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderTrackingDetailPage(entry: entry),
              ),
            )
          : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 248,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7F4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFD7CC)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDelivering
                    ? Icons.delivery_dining_rounded
                    : Icons.shopping_basket_outlined,
                color: Colors.white,
                size: 21,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDelivering ? 'Đang giao' : 'Đơn trong giỏ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
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
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (firstItem != null) firstItem.name,
                      '${order.itemCount} món',
                      checkoutFormatPrice(order.total),
                    ].join(' | '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF757575),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (isDelivering) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ],
          ],
        ),
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

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topPadding;
  final String address;
  final VoidCallback onBack;
  final VoidCallback onAddressTap;

  const _HeaderDelegate({
    required this.topPadding,
    required this.address,
    required this.onBack,
    required this.onAddressTap,
  });

  // Header vertical budget:
  //   topPadding (SafeArea)
  // + 12 top padding
  // + 38 location row
  // + 10 gap
  // + 40 search bar
  // + 12 bottom padding (search bar không chạm mép dưới)
  // + 6 breathing room
  // = topPadding + 118
  @override
  double get minExtent => topPadding + 118;

  @override
  double get maxExtent => topPadding + 118;

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
        padding: EdgeInsets.fromLTRB(12, topPadding + 12, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(
              height: 38,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Tooltip(
                    message: 'Quay lại',
                    child: InkWell(
                      onTap: onBack,
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 24,
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
                              'Giao đến:',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xD9FFFFFF),
                                fontSize: 12,
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
                                      fontSize: 15,
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
            const SizedBox(height: 10),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                      'Mồi Ngon Cùng Bóng Đá Giảm 45.000Đ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
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

  @override
  bool shouldRebuild(covariant _HeaderDelegate oldDelegate) {
    return oldDelegate.topPadding != topPadding ||
        oldDelegate.address != address ||
        oldDelegate.onAddressTap != onAddressTap;
  }
}

class _SortTabsDelegate extends SliverPersistentHeaderDelegate {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _SortTabsDelegate({required this.selectedIndex, required this.onTap});

  @override
  double get minExtent => 46;

  @override
  double get maxExtent => 46;

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
                height: 46,
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
                    fontSize: 14,
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
      width: 80,
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
                        width: 46,
                        height: 46,
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
                  width: 46,
                  height: 46,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF212121),
                  fontSize: 12,
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
                    fontSize: 11,
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 280,
        decoration: _cardDecoration(12),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _ImageTile(
                  seed: data.seed,
                  width: double.infinity,
                  height: 174,
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
                padding: const EdgeInsets.all(8),
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 136,
        decoration: _cardDecoration(10),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Stack(
              children: [
                _ImageTile(
                  seed: data.seed,
                  width: 78,
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
                padding: const EdgeInsets.all(7),
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
          style: const TextStyle(color: Color(0xFF757575), fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          data.name,
          maxLines: big ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFF212121),
            fontSize: big ? 13 : 12,
            height: 1.12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          formatPrice(data.price),
          style: TextStyle(
            color: AppColors.primary,
            fontSize: big ? 14 : 13,
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

  const _WhiteSection({
    required this.child,
    this.title,
    this.subtitle,
    this.titleWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                              fontSize: 16,
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
                                fontSize: 12,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ],
                      ),
                ),
                const _SeeMore(color: AppColors.primary),
              ],
            ),
          ),
          const SizedBox(height: 10),
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

  const _RecentCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
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

  const _SeeMore({required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Xem thêm >',
      style: TextStyle(
        color: color.withValues(alpha: 0.86),
        fontSize: 12,
        fontWeight: FontWeight.w600,
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
