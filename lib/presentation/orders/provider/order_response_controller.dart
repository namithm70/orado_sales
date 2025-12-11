// agent_order_response_controller.dart
import 'package:oradosales/presentation/orders/model/order_response_model.dart';
import 'package:oradosales/presentation/orders/service/order_response_service.dart';
import 'package:flutter/material.dart';

class AgentOrderResponseController extends ChangeNotifier {
  final AgentOrderResponseService _service = AgentOrderResponseService();

  bool isLoading = false;
  String? error;
  OrderResponseModel? response;

  int? loadingIndex; // 0 = Accept, 1 = Reject

  Future<void> respond(String orderId, String action) async {
    // Set loading index
    loadingIndex = action == "accept" ? 0 : 1;
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      response = await _service.respondToOrder(
        orderId: orderId,
        action: action,
      );
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      loadingIndex = null; // reset
      notifyListeners();
    }
  }
}

