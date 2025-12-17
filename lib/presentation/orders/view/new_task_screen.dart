import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:oradosales/presentation/orders/view/delivery_task_bottom_screen.dart';
import 'package:oradosales/presentation/orders/view/order_details_screen.dart';
import 'package:provider/provider.dart';

import 'package:oradosales/core/app/app_ui_state.dart';
import 'package:oradosales/presentation/orders/provider/order_details_provider.dart';

class NewTaskScreen extends StatefulWidget {
  const NewTaskScreen({super.key});

  @override
  State<NewTaskScreen> createState() => _NewTaskScreenState();
}

class _NewTaskScreenState extends State<NewTaskScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orderId = AppUIState.orderId;

      if (orderId == null) {
        log('❌ orderId is NULL');
        return;
      }

      context.read<OrderDetailController>().loadOrderDetails(orderId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderDetailController>(
      builder: (context, controller, _) {
        if (controller.order == null) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        final order = controller.order!;

        return Scaffold(
          backgroundColor: Colors.black,

          /// ---------------- APP BAR ----------------
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                AppUIState.screen.value = VisibleScreen.home;
              },
            ),
            title: const Text(
              "1 new Task",
              style: TextStyle(color: Colors.white),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  AppUIState.screen.value = VisibleScreen.home;
                },
              ),
              const SizedBox(width: 12),
            ],
          ),

          /// ---------------- BODY ----------------
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                const Text(
                  "Just Now",
                  style: TextStyle(color: Colors.white70),
                ),

                const SizedBox(height: 20),

                /// ================= PICKUP =================
                _pickupTile(
                  time: _formatTime(order.createdAt),
                  orderId: order.id,
                  shopName: order.restaurant.name,
                  distance: "0.48 KM Away",
                ),

                const Divider(color: Colors.white30, height: 32),

                /// ================= DELIVERY =================
                _deliveryTile(
                  time: _formatTime(
                    order.createdAt.add(const Duration(minutes: 20)),
                  ),
                  orderId: order.id,
                  address:
                      "${order.deliveryAddress.city}, ${order.deliveryAddress.state}, India",
                ),

                const Spacer(),

                /// ================= ACKNOWLEDGE =================
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(order: order),
      ),
    );
                    },
                    child: const Text(
                      "Acknowledge",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  /// ================= PICKUP TILE =================
  Widget _pickupTile({
    required String time,
    required String orderId,
    required String shopName,
    required String distance,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.circle, color: Colors.white, size: 10),
        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "$time - Pickup - ",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    orderId.substring(orderId.length - 8),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const Spacer(),
                  Text(
                    distance,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                shopName,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              const Text(
                "Mavelikara, Kerala, India",
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// ================= DELIVERY TILE =================
  Widget _deliveryTile({
    required String time,
    required String orderId,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.circle, color: Colors.white, size: 10),
        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "$time - Delivery - ",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    orderId.substring(orderId.length - 8),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                address,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// ================= TIME FORMAT =================
  String _formatTime(DateTime date) {
    int hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? "PM" : "AM";
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    return "$hour:$minute $period";
  }
}
