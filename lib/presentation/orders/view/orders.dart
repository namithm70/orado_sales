import 'dart:developer';

import 'package:oradosales/presentation/orders/provider/order_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oradosales/presentation/orders/view/delivery_task_bottom_screen.dart';

class OrdersListScreen extends StatefulWidget {
  static String route = 'ordersListScreen';

  const OrdersListScreen({Key? key}) : super(key: key);

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  Future<void> _loadOrders() async {
    await Provider.of<OrderController>(context, listen: false).fetchOrders();
  }

 Color _getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'awaiting_start':            // Not started yet
      return Colors.orange;

    case 'accepted_by_restaurant':    // Restaurant accepted
      return Colors.blue;

    case 'start_journey_to_restaurant':
    case 'on_the_way':                // Agent traveling
    case 'going_to_pickup':
      return Colors.lightBlue;

    case 'reached_restaurant':
      return Colors.purple;

    case 'picked_up':
      return Colors.teal;

    case 'out_for_delivery':
      return Colors.indigo;

    case 'reached_customer':
      return Colors.deepOrange;

    case 'delivered':                  // Completed
      return Colors.green;

    case 'cancelled':
      return Colors.red;

    default:
      return Colors.grey;              // Unknown status
  }
}
String getStatusActionLabel(String status) {
  switch (status.toLowerCase()) {

    case 'awaiting_start':
    case 'accepted_by_restaurant':
      return "Start Pickup";

    case 'start_journey_to_restaurant':
    case 'on_the_way':
    case 'going_to_pickup':
      return "Go to Restaurant";

    case 'reached_restaurant':
      return "Reached Restaurant";

    case 'picked_up':
      return "Picked Up - Start Delivery";

    case 'out_for_delivery':
      return "Delivering to Customer";

    case 'reached_customer':
      return "Reached Customer";

    case 'delivered':
      return "Delivery Completed";

    case 'cancelled':
      return "Order Cancelled";

    default:
      return "Unknown Status";
  }
}



  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderController = Provider.of<OrderController>(context);
    final orders = orderController.orders;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Orders'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrders),
          ],
        ),
        body:
            orderController.isLoading
                ? const Center(child: CircularProgressIndicator())
                : orders.isEmpty
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No orders found',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
                : RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            log(
                              "Navigating to order details with ID: ${order.id}",
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderDetailsScreen(order: order),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Order #${order.id?.substring(order.id!.length - 5)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(
                                          order.status ?? '',
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        getStatusActionLabel(order.status ?? ''),
                                        style: TextStyle(
                                          color: _getStatusColor(
                                            order.status ?? '',
                                          ),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.store,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        order.restaurant?.name ?? '',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        order.customer?.name ?? '',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Created: ${_getTimeAgo(order.createdAt ?? DateTime.now())}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      ),
    );
  }
}
