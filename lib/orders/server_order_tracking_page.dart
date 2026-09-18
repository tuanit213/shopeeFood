import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import '../domain/order/order_v2.dart';

class ServerOrderTrackingPage extends StatelessWidget {
  final OrderV2 order;

  const ServerOrderTrackingPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Theo dõi đơn hàng')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.check_circle, color: AppColors.primary, size: 64),
          const SizedBox(height: 16),
          Text(
            'Đơn hàng đã được tiếp nhận',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Mã đơn: ${order.id}',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          _StatusCard(status: order.status),
          const SizedBox(height: 20),
          const Text(
            'Tài xế chưa được gán. Vị trí sẽ chỉ xuất hiện khi backend có dữ liệu tài xế thật.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final OrderStatus status;
  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: const Text('Trạng thái đơn'),
        subtitle: Text(status.wireName),
      ),
    );
  }
}
