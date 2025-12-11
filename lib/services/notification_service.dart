import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:oradosales/presentation/orders/view/order_details_screen.dart';
import 'package:oradosales/services/navigation_service.dart';

class NotificationService {
  static Map<String, dynamic> _safeParsePayload(String payload) {
  try {
    return jsonDecode(payload); // Works if valid JSON
  } catch (_) {
    log("⚠ Invalid JSON payload detected, fixing manually...");

    // Convert {key: value} → {"key": "value"}
    final fixed = payload
        .replaceAll("{", "{\"")
        .replaceAll("}", "\"}")
        .replaceAll(": ", "\": \"")
        .replaceAll(", ", "\", \"");

    log("➡ Fixed Payload = $fixed");

    return jsonDecode(fixed);
  }
}

  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// ---------------------------------------------------------
  /// INITIALIZE NOTIFICATIONS
  /// ---------------------------------------------------------
  static Future<void> initialize(BuildContext context) async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        try {
          final payload = response.payload;
          if (payload == null) return;

     final fixedData = _safeParsePayload(payload);
  final orderId = fixedData["orderId"];

          final ctx =
              NavigationService.navigatorKey.currentState!.overlay!.context;

          Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => OrderDetailsBottomSheet(orderId: orderId),
            ),
          );
        } catch (e) {
          log("❌ Notification tap error: $e");
        }
      },
    );

    // Create channels
    const AndroidNotificationChannel orderChannel = AndroidNotificationChannel(
      'order_channel',
      'Order Notifications',
      description: 'Notifications for new orders and updates',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('order_assignment'),
    );

    const AndroidNotificationChannel locationChannel =
        AndroidNotificationChannel(
      'location_service',
      'Location Service',
      description: 'Background location tracking',
      importance: Importance.low,
      playSound: false,
    );

    final androidPlugin =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(orderChannel);
    await androidPlugin?.createNotificationChannel(locationChannel);

    /// ---------------------------------------------------------
    /// FOREGROUND MESSAGE
    /// ---------------------------------------------------------
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleFCMMessage(message);
    });

    /// ---------------------------------------------------------
    /// BACKGROUND (APP OPENED FROM NOTIFICATION)
    /// ---------------------------------------------------------
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      try {
        final data = message.data;
        final orderId = data["orderId"];

        final ctx =
            NavigationService.navigatorKey.currentState!.overlay!.context;

        Navigator.push(
          ctx,
          MaterialPageRoute(
            builder: (_) => OrderDetailsBottomSheet(orderId: orderId),
          ),
        );
      } catch (e) {
        log("❌ Background tap error: $e");
      }
    });

    /// ---------------------------------------------------------
    /// TERMINATED → APP OPENED FROM NOTIFICATION
    /// ---------------------------------------------------------
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      try {
        final data = initialMessage.data;
        final orderId = data["orderId"];

        final ctx =
            NavigationService.navigatorKey.currentState!.overlay!.context;

        Navigator.push(
          ctx,
          MaterialPageRoute(
            builder: (_) => OrderDetailsBottomSheet(orderId: orderId),
          ),
        );
      } catch (e) {
        log("❌ Terminated-state tap error: $e");
      }
    }
  }

  /// ---------------------------------------------------------
  /// SHOW LOCAL NOTIFICATION
  /// ---------------------------------------------------------
  static Future<void> showNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'order_channel',
        'Order Notifications',
        channelDescription: 'Notifications for order updates',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('order_assignment'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
        visibility: NotificationVisibility.public,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'order_assignment.caf',
      );

      NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        0,
        title,
        body,
        platformDetails,
        payload: payload,
      );
    } catch (e) {
      log('❌ Error showing notification: $e');
    }
  }

  /// ---------------------------------------------------------
  /// HANDLE INCOMING FCM MESSAGE
  /// ---------------------------------------------------------
  static void _handleFCMMessage(RemoteMessage message) {
    if (message.data['type'] == 'order_assignment') {
      log("📩 Incoming ORDER_ASSIGNMENT: ${message.toMap()}");

      String title = message.notification?.title ?? 'New Order Assignment';
      String body = message.notification?.body ?? '';

      /// FIXED: Always send VALID JSON payload
      String payload = jsonEncode({
        "orderId": message.data['orderId'] ?? "",
        "address": message.data['address'] ?? "",
        "type": message.data['type'] ?? "",
      });

      showNotification(title: title, body: body, payload: payload);
    }
  }
}
