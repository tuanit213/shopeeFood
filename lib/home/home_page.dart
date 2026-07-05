import 'package:flutter/material.dart';
import '../app/app_colors.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: AppColors.primary,
              padding: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 16),
              child: Column(
                children: [
                  Row(
                    children: const [
                      Icon(Icons.location_on, color: Colors.white, size: 20),
                      SizedBox(width: 4),
                      Text(
                        'Quận 1, TP.HCM',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Icon(Icons.arrow_drop_down, color: Colors.white),
                      Spacer(),
                      Icon(Icons.notifications_none, color: Colors.white),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: AppColors.gray500, size: 20),
                        const SizedBox(width: 8),
                        Text('Tìm món ăn, nhà hàng...', style: TextStyle(color: AppColors.gray500, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildServiceChip('ShopeeFood', Icons.delivery_dining),
                      _buildServiceChip('ShopeeFood Mart', Icons.storefront),
                      _buildServiceChip('Shopee Express', Icons.local_shipping),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF7355), AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            '🔥 Freeship 0đ\nhôm nay!',
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.2),
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
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.bento, color: Colors.white, size: 40),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Danh mục', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCategoryItem('Cơm', Icons.rice_bowl, Colors.orange),
                      _buildCategoryItem('Phở/Bún', Icons.ramen_dining, Colors.brown),
                      _buildCategoryItem('Pizza', Icons.local_pizza, Colors.red),
                      _buildCategoryItem('Burger', Icons.fastfood, Colors.amber),
                      _buildCategoryItem('Salad', Icons.eco, Colors.green),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Gợi ý cho bạn 🍴', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                  const SizedBox(height: 12),
                  _buildRestaurantCard(
                    name: 'Bún Bò Huế Dì Liên',
                    rating: '4.8',
                    distance: '1.2km',
                    time: '25 phút',
                    price: 'Từ 25.000đ',
                    isFreeship: true,
                  ),
                  const SizedBox(height: 12),
                  _buildRestaurantCard(
                    name: 'KFC Nguyễn Huệ',
                    rating: '4.7',
                    distance: '0.9km',
                    time: '18 phút',
                    price: 'Từ 45.000đ',
                    isFreeship: true,
                  ),
                  const SizedBox(height: 12),
                  _buildRestaurantCard(
                    name: 'Cơm Tấm Ba Ghi',
                    rating: '4.5',
                    distance: '2.1km',
                    time: '30 phút',
                    price: 'Từ 35.000đ',
                    isFreeship: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceChip(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  Widget _buildCategoryItem(String title, IconData icon, Color iconColor) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 12, color: AppColors.gray700)),
      ],
    );
  }

  Widget _buildRestaurantCard({
    required String name,
    required String rating,
    required String distance,
    required String time,
    required String price,
    required bool isFreeship,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.restaurant, color: AppColors.primaryLight, size: 40),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text('$rating · $distance · $time', style: const TextStyle(fontSize: 13, color: AppColors.gray500)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (isFreeship)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('FREESHIP', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Ưu đãi', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(price, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}