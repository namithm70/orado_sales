import 'package:flutter/material.dart';
import 'package:oradosales/presentation/orders/view/order_details_screen.dart';

class OrderDetailsScreen extends StatelessWidget {
  final dynamic order;

  const OrderDetailsScreen({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "December 05",
          style: TextStyle(color: Colors.white),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Center(
                  child: Icon(Icons.keyboard_arrow_down, color: Colors.white),
                ),
                const SizedBox(height: 16),

                /// PICKUP
                _timelineTile(
                  context: context,
                  time: _formatTime(order.createdAt),
                  title: "Pickup",
                  status: _pickupStatus(order),
                  orderId: order.id,
                  address:
                      "${order.restaurant.name}, Mavelikara, Kerala, India",
                  isLast: false,
                ),

                /// DELIVERY
                _timelineTile(
                  context: context,
                  time: _formatTime(
                    order.createdAt.add(const Duration(minutes: 20)),
                  ),
                  title: "Delivery",
                  status: _deliveryStatus(order),
                  orderId: order.id,
                  address:
                      "${order.deliveryAddress.city}, ${order.deliveryAddress.state}, India",
                  isLast: true,
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- STATUS LOGIC ----------------

  String _pickupStatus(dynamic order) {
    final s = order.agentDeliveryStatus;
    if (s == "reached_restaurant" || s == "picked_up") {
      return "Completed";
    }
    return "Pending";
  }

  String _deliveryStatus(dynamic order) {
    final s = order.agentDeliveryStatus;
    if (s == "picked_up" ||
        s == "out_for_delivery" ||
        s == "reached_customer" ||
        s == "delivered") {
      return "In Progress";
    }
    return "Pending";
  }

  // ---------------- TIMELINE TILE ----------------

  Widget _timelineTile({
    required BuildContext context,
    required String time,
    required String title,
    required String status,
    required String orderId,
    required String address,
    required bool isLast,
  }) {
    return InkWell(
      onTap: () {
        context.showOrderBottomSheet(orderId, () {});
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              const Icon(Icons.circle, color: Colors.white, size: 10),
              if (!isLast)
                Container(height: 70, width: 1, color: Colors.white38),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "$time - $title ",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        color:
                            status == "Completed" ? Colors.green : Colors.purple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      " - ${orderId.substring(orderId.length - 8)}",
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: Colors.white54),
                  ],
                ),
                const SizedBox(height: 6),
                Text(address,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    int hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? "PM" : "AM";
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    return "$hour:$minute $period";
  }
}
