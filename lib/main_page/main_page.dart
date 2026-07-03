import 'package:flutter/material.dart';

import '../app/app_routes.dart';
import '../shared/app_bottom_navigation.dart';
import 'widgets/category_section.dart';
import 'widgets/main_header.dart';
import 'widgets/promo_banner.dart';
import 'widgets/restaurant_section.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: MainHeader(
              onProfileTap: () =>
                  Navigator.pushNamed(context, AppRoutes.profile),
            ),
          ),
          const SliverToBoxAdapter(child: PromoBanner()),
          const SliverToBoxAdapter(child: CategorySection()),
          const SliverToBoxAdapter(child: RestaurantSection()),
        ],
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: 0),
    );
  }
}
