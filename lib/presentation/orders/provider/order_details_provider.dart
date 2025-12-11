// lib/presentation/screens/home/orders/controller/order_detail_controller.dart

import 'dart:developer';
import 'package:oradosales/presentation/orders/service/order_details_sevice.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/order_details_model.dart';

class OrderDetailController extends ChangeNotifier {
  final OrderDetailsService _service = OrderDetailsService();

  OrderDetailsModel? orderDetails;
  String? errorMessage;
  String? successMessage;

  Order? get order => orderDetails?.order;
  bool isSlideLoading = false;
  void setSlideLoading(bool value) {
  isSlideLoading = value;
  notifyListeners();
}

  // ---------------- LOAD ORDER DETAILS (NO LOADING INDICATOR) ---------------- //

  Future<void> loadOrderDetails(String orderId) async {
    errorMessage = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('userToken');

      if (token == null) throw Exception('Authentication token not found');

      final fetched = await _service.fetchOrderDetails(
        orderId: orderId,
        token: token,
      );

      if (fetched != null) {
        orderDetails = fetched;
      } else {
        throw Exception('Failed to load order details');
      }

    } catch (e) {
      errorMessage = e.toString();
      log('Error loading order details: $e');
    }

    notifyListeners(); // only one light rebuild
  }

  // ---------------- UPDATE STATUS (SUPER SMOOTH - NO LOADER) ---------------- //

  Future<bool> updateOrderStatus(String status) async {
    if (order == null) return false;

    try {
          setSlideLoading(true);     
      final token = await _getUserToken();

      final response = await _service.updateDeliveryStatus(
        orderId: order!.id,
        status: status,
        token: token,
      );
    setSlideLoading(false);     // 👉 STOP loading
      if (response != null && response.message != null) {
        successMessage = response.message!;
        loadOrderDetails(order!.id); // async refresh
        return true;
      }

      return false;

    } catch (e) {
          setSlideLoading(false); 
      errorMessage = e.toString();
      log('Status update error: $e');
      return false;
    }
  }

  // ---------------- TOKEN ---------------- //

  Future<String> _getUserToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('userToken');
    if (token == null) throw Exception('Authentication token not found');
    return token;
  }

  // ---------------- CLEAR ---------------- //

  void clearMessages() {
    errorMessage = null;
    successMessage = null;
    notifyListeners();
  }
}
