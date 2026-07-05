import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_colors.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onProfileTap;

  const HomePage({super.key, this.onProfileTap});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  int _activeServiceIndex = 0;

  final List<_ServiceItem> _services = const [
    _ServiceItem('ShopeeFood', Icons.delivery_dining_rounded),
    _ServiceItem('ShopeeFood Mart', Icons.storefront_rounded),
    _ServiceItem('Shopee Express', Icons.local_shipping_rounded),
  ];

  final List<_CategoryItemData> _categories = const [
    _CategoryItemData('Cơm', Icons.rice_bowl_rounded, Color(0xFFFF9800)),
    _CategoryItemData('Phở/Bún', Icons.ramen_dining_rounded, Color(0xFF795548)),
    _CategoryItemData('Pizza', Icons.local_pizza_rounded, Color(0xFFF44336)),
    _CategoryItemData('Burger', Icons.fastfood_rounded, Color(0xFFFFB300)),
    _CategoryItemData('Salad', Icons.eco_rounded, Color(0xFF4CAF50)),
    _CategoryItemData('Trà sữa', Icons.local_cafe_rounded, Color(0xFF8D6E63)),
    _CategoryItemData('Đồ uống', Icons.local_drink_rounded, Color(0xFF03A9F4)),
    _CategoryItemData('Tráng miệng', Icons.icecream_rounded, Color(0xFFE91E63)),
    _CategoryItemData('Xem thêm', Icons.more_horiz_rounded, Color(0xFF616161)),
  ];

  final List<_RestaurantData> _restaurants = const [
    _RestaurantData(
      name: 'Bún Bò Huế Dì Liên',
      rating: '4.8',
      distance: '1.2km',
      time: '25 phút',
      price: 'Từ 25.000đ',
      seed: 'bun-bo-hue-di-lien',
      imageUrl:
          'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?auto=format&fit=crop&w=800&q=80',
      isFreeship: true,
      hasDeal: true,
    ),
    _RestaurantData(
      name: 'KFC Nguyễn Huệ',
      rating: '4.7',
      distance: '0.9km',
      time: '18 phút',
      price: 'Từ 45.000đ',
      seed: 'kfc-nguyen-hue',
      imageUrl:
          'https://images.unsplash.com/photo-1562967914-608f82629710?auto=format&fit=crop&w=800&q=80',
      isFreeship: true,
      hasDeal: true,
    ),
    _RestaurantData(
      name: 'Cơm Tấm Ba Ghi',
      rating: '4.5',
      distance: '2.1km',
      time: '30 phút',
      price: 'Từ 35.000đ',
      seed: 'com-tam-ba-ghi',
      imageUrl:
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=800&q=80',
      isFreeship: false,
      hasDeal: true,
    ),
    _RestaurantData(
      name: 'Pizza 4P Lê Thánh Tôn',
      rating: '4.9',
      distance: '1.8km',
      time: '28 phút',
      price: 'Từ 79.000đ',
      seed: 'pizza-4p-le-thanh-ton',
      imageUrl:
          'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=800&q=80',
      isFreeship: true,
      hasDeal: false,
    ),
    _RestaurantData(
      name: 'Phở Thìn Pasteur',
      rating: '4.6',
      distance: '1.5km',
      time: '22 phút',
      price: 'Từ 50.000đ',
      seed: 'pho-thin-pasteur',
      imageUrl:
          'https://images.unsplash.com/photo-1612929633738-8fe44f7ec841?auto=format&fit=crop&w=800&q=80',
      isFreeship: false,
      hasDeal: true,
    ),
    _RestaurantData(
      name: 'TocoToco Nguyễn Trãi',
      rating: '4.4',
      distance: '2.4km',
      time: '26 phút',
      price: 'Từ 32.000đ',
      seed: 'tocotoco-nguyen-trai',
      imageUrl:
          'https://images.unsplash.com/photo-1551024601-bec78aea704b?auto=format&fit=crop&w=800&q=80',
      isFreeship: true,
      hasDeal: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 768;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(isDesktop),
                _buildServiceTabs(),
                _maxWidth(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 0 : 16,
                      16,
                      isDesktop ? 0 : 16,
                      0,
                    ),
                    child: const _PromoBanner(),
                  ),
                ),
                _maxWidth(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 0 : 16,
                      28,
                      isDesktop ? 0 : 16,
                      28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(title: 'Danh mục', onSeeAll: () {}),
                        const SizedBox(height: 16),
                        _buildCategoryList(),
                        const SizedBox(height: 28),
                        _SectionHeader(
                          title: 'Gợi ý cho bạn',
                          trailingIcon: Icons.tune_rounded,
                          onSeeAll: () {},
                        ),
                        const SizedBox(height: 16),
                        _buildRestaurantGrid(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _maxWidth({required Widget child}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: child,
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: _maxWidth(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 0 : 16,
              16,
              isDesktop ? 0 : 16,
              16,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Quận 1, TP.HCM',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.white),
                    const Spacer(),
                    if (isDesktop) ...[
                      _HeaderLink(label: 'Khám phá', onTap: () {}),
                      _HeaderLink(label: 'Đơn hàng', onTap: () {}),
                      _HeaderLink(label: 'Tin nhắn', onTap: () {}),
                      const SizedBox(width: 12),
                      Tooltip(
                        message: 'Tài khoản',
                        child: InkWell(
                          onTap: widget.onProfileTap,
                          customBorder: const CircleBorder(),
                          child: const CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.person_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white,
                      ),
                      tooltip: 'Thông báo',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: AppColors.gray500,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Tìm món ăn, nhà hàng...',
                          style: TextStyle(
                            color: AppColors.gray500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceTabs() {
    return ColoredBox(
      color: const Color(0xFFD84315),
      child: _maxWidth(
        child: SizedBox(
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_services.length, (index) {
              final service = _services[index];
              final isActive = index == _activeServiceIndex;

              return Expanded(
                child: _ServiceTab(
                  item: service,
                  isActive: isActive,
                  onTap: () => setState(() => _activeServiceIndex = index),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          for (final category in _categories) ...[
            _CategoryTile(category: category),
            if (category != _categories.last) const SizedBox(width: 32),
          ],
        ],
      ),
    );
  }

  Widget _buildRestaurantGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1024
            ? 3
            : constraints.maxWidth >= 768
            ? 2
            : 1;
        final cardWidth =
            (constraints.maxWidth - ((columns - 1) * 16)) / columns;
        final targetHeight = columns == 1 ? 320.0 : 304.0;
        final childAspectRatio = cardWidth / targetHeight;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: GridView.builder(
            key: ValueKey(_isLoading),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _isLoading ? 6 : _restaurants.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: childAspectRatio,
            ),
            itemBuilder: (context, index) {
              if (_isLoading) {
                return const _SkeletonRestaurantCard();
              }

              return _RestaurantCard(data: _restaurants[index]);
            },
          ),
        );
      },
    );
  }
}

class _ServiceItem {
  final String label;
  final IconData icon;

  const _ServiceItem(this.label, this.icon);
}

class _CategoryItemData {
  final String title;
  final IconData icon;
  final Color color;

  const _CategoryItemData(this.title, this.icon, this.color);
}

class _RestaurantData {
  final String name;
  final String rating;
  final String distance;
  final String time;
  final String price;
  final String seed;
  final String imageUrl;
  final bool isFreeship;
  final bool hasDeal;

  const _RestaurantData({
    required this.name,
    required this.rating,
    required this.distance,
    required this.time,
    required this.price,
    required this.seed,
    required this.imageUrl,
    required this.isFreeship,
    required this.hasDeal,
  });
}

class _HeaderLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _HeaderLink({required this.label, required this.onTap});

  @override
  State<_HeaderLink> createState() => _HeaderLinkState();
}

class _HeaderLinkState extends State<_HeaderLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(
              color: _hovered
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.82),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}

class _ServiceTab extends StatefulWidget {
  final _ServiceItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _ServiceTab({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_ServiceTab> createState() => _ServiceTabState();
}

class _ServiceTabState extends State<_ServiceTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isHighlighted = widget.isActive || _hovered;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: TextStyle(
            color: isHighlighted
                ? Colors.white
                : Colors.white.withValues(alpha: 0.75),
            fontSize: 12,
            fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.item.icon,
                    color: isHighlighted
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.75),
                    size: 16,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      widget.item.label,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Container(
                width: 92,
                height: 2,
                color: widget.isActive ? Colors.white : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFC0392B), Color(0xFF922B21)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Freeship 0đ hôm nay!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.18,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Áp dụng đến 23:59',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.bento_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData? trailingIcon;
  final VoidCallback onSeeAll;

  const _SectionHeader({
    required this.title,
    required this.onSeeAll,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF212121),
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(trailingIcon, size: 17, color: AppColors.gray500),
        ],
        const Spacer(),
        TextButton(
          onPressed: onSeeAll,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Xem tất cả',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 2),
        const Icon(
          Icons.arrow_forward_rounded,
          size: 14,
          color: AppColors.primary,
        ),
      ],
    );
  }
}

class _CategoryTile extends StatefulWidget {
  final _CategoryItemData category;

  const _CategoryTile({required this.category});

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Column(
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 150),
              scale: _hovered ? 1.05 : 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _hovered
                      ? const Color(0xFFFFE0D0)
                      : const Color(0xFFFFF5F3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  widget.category.icon,
                  color: widget.category.color,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.category.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF424242)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestaurantCard extends StatefulWidget {
  final _RestaurantData data;

  const _RestaurantCard({required this.data});

  @override
  State<_RestaurantCard> createState() => _RestaurantCardState();
}

class _RestaurantCardState extends State<_RestaurantCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF0F0F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hovered ? 0.12 : 0.03),
              blurRadius: _hovered ? 20 : 8,
              offset: Offset(0, _hovered ? 4 : 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 160,
              width: double.infinity,
              child: _RestaurantThumbnail(data: widget.data),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.data.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFB300),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${widget.data.rating} · ${widget.data.distance} · ${widget.data.time}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF757575),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (widget.data.isFreeship)
                          const _Badge(
                            label: 'FREESHIP',
                            background: Color(0xFFE8F5E9),
                            foreground: Color(0xFF2E7D32),
                          ),
                        if (widget.data.hasDeal)
                          const _Badge(
                            label: 'Ưu đãi',
                            background: Color(0xFFFFF3E0),
                            foreground: Color(0xFFE65100),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      widget.data.price,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF424242),
                        fontWeight: FontWeight.w500,
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
}

class _Badge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RestaurantThumbnail extends StatelessWidget {
  final _RestaurantData data;

  const _RestaurantThumbnail({required this.data});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _FoodFallback(seed: data.seed),
        Image.network(
          data.imageUrl,
          fit: BoxFit.cover,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              return child;
            }
            return const SizedBox.shrink();
          },
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

class _FoodFallback extends StatelessWidget {
  final String seed;

  const _FoodFallback({required this.seed});

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(seed);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -24,
            child: Icon(
              Icons.ramen_dining_rounded,
              size: 126,
              color: Colors.white.withValues(alpha: 0.22),
            ),
          ),
          Center(
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.restaurant_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _colorsFor(String value) {
    final palettes = const [
      [Color(0xFFFF7043), Color(0xFFD84315)],
      [Color(0xFFFFB74D), Color(0xFFF57C00)],
      [Color(0xFFEF5350), Color(0xFFC62828)],
      [Color(0xFF8D6E63), Color(0xFF5D4037)],
      [Color(0xFF66BB6A), Color(0xFF2E7D32)],
      [Color(0xFF29B6F6), Color(0xFF0277BD)],
    ];
    final index =
        value.codeUnits.fold<int>(0, (sum, code) => sum + code) %
        palettes.length;
    return palettes[index];
  }
}

class _SkeletonRestaurantCard extends StatelessWidget {
  const _SkeletonRestaurantCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBox(width: double.infinity, height: 160, radius: 0),
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(width: 180, height: 16, radius: 4),
                SizedBox(height: 10),
                _ShimmerBox(width: 130, height: 12, radius: 4),
                SizedBox(height: 12),
                Row(
                  children: [
                    _ShimmerBox(width: 72, height: 18, radius: 4),
                    SizedBox(width: 8),
                    _ShimmerBox(width: 58, height: 18, radius: 4),
                  ],
                ),
                SizedBox(height: 16),
                _ShimmerBox(width: 92, height: 13, radius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + (_controller.value * 3), 0),
              end: Alignment(-0.5 + (_controller.value * 3), 0),
              colors: const [
                Color(0xFFF0F0F0),
                Color(0xFFE0E0E0),
                Color(0xFFF0F0F0),
              ],
            ),
          ),
        );
      },
    );
  }
}
