import 'package:flutter/material.dart';
import 'package:oradosales/presentation/orders/view/order_details_screen.dart';
import 'package:provider/provider.dart';
import 'package:oradosales/presentation/orders/provider/order_details_provider.dart';

class OrderDetailsScreen extends StatefulWidget {
  final dynamic order;

  const OrderDetailsScreen({
    super.key,
    required this.order,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure this screen stays updated with latest delivery status.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final orderId = (widget.order.id ?? '').toString();
        if (orderId.isNotEmpty) {
          await context.read<OrderDetailController>().loadOrderDetails(orderId);
        }
      } catch (_) {
        // If widget.order doesn't have expected shape, ignore and fallback to passed order.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderDetailController>(
      builder: (context, detailController, _) {
        // Prefer live order details if they match this orderId.
        dynamic currentOrder = widget.order;
        try {
          final orderId = (widget.order.id ?? '').toString();
          final live = detailController.order;
          if (live != null && live.id.toString() == orderId) {
            currentOrder = live;
          }
        } catch (_) {}

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
          time: _formatTime(currentOrder.createdAt),
                  title: "Pickup",
                  status: _pickupStatus(currentOrder),
          orderId: currentOrder.id?.toString() ?? '',
                  address:
                      "${currentOrder.restaurant?.name ?? ''}, Mavelikara, Kerala, India",
                  isLast: false,
                ),

                /// DELIVERY
                _timelineTile(
                  context: context,
                  time: _formatTime(
                    (currentOrder.createdAt as DateTime?)?.add(const Duration(minutes: 20)),
                  ),
                  title: "Delivery",
                  status: _deliveryStatus(currentOrder),
          orderId: currentOrder.id?.toString() ?? '',
                  address:
                      "${currentOrder.deliveryAddress?.city ?? ''}, ${currentOrder.deliveryAddress?.state ?? ''}, India",
                  isLast: true,
                  enabled: _isPickupCompleted(currentOrder),
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
    );
  }

  // ---------------- STATUS LOGIC ----------------

  String _getAgentStatus(dynamic order) {
    // Orders list passes `AssignedOrder` which has `status`
    // Order details passes `Order` which has `agentDeliveryStatus`
    try {
      final v = order.agentDeliveryStatus;
      if (v is String) return v;
    } catch (_) {}
    try {
      final v = order.status;
      if (v is String) return v;
    } catch (_) {}
    return '';
  }

  bool _isPickupCompleted(dynamic order) {
    final s = _getAgentStatus(order).toLowerCase();
    return s == "picked_up" ||
        s == "out_for_delivery" ||
        s == "reached_customer" ||
        s == "delivered";
  }

  String _pickupStatus(dynamic order) {
    final s = _getAgentStatus(order).toLowerCase();

    // Pickup is completed only once rider has picked up.
    if (s == "picked_up" ||
        s == "out_for_delivery" ||
        s == "reached_customer" ||
        s == "delivered") {
      return "Completed";
    }

    if (s == "start_journey_to_restaurant" || s == "reached_restaurant") {
      return "In Progress";
    }

    return "Pending";
  }

  String _deliveryStatus(dynamic order) {
    final s = _getAgentStatus(order).toLowerCase();

    if (s == "delivered") return "Completed";

    // Delivery starts after pickup completed.
    if (s == "picked_up" || s == "out_for_delivery" || s == "reached_customer") {
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
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled
          ? () {
              context.showOrderBottomSheet(orderId, () {});
            }
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Complete Pickup first to unlock Delivery"),
                ),
              );
            },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(
                enabled ? Icons.circle : Icons.lock,
                color: enabled ? Colors.white : Colors.white54,
                size: 10,
              ),
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
                    Icon(
                      enabled ? Icons.chevron_right : Icons.lock,
                      color: Colors.white54,
                    ),
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

  String _formatTime(DateTime? date) {
    if (date == null) return "--";
    int hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? "PM" : "AM";
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    return "$hour:$minute $period";
  }
}
