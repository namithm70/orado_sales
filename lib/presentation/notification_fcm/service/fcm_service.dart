import 'dart:developer';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:oradosales/core/app/app_ui_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

import 'package:oradosales/presentation/notification_fcm/controller/fcm_controller.dart';

class FCMHandler {
  static FCMHandler? _instance;
  final FCMTokenController _tokenController = FCMTokenController();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  final FlutterTts flutterTts = FlutterTts();

  // Private constructor
  FCMHandler._();

  // Factory constructor to return singleton instance
  factory FCMHandler() {
    _instance ??= FCMHandler._();
    return _instance!;
  }

  // Get instance method
  static FCMHandler get instance => _instance ??= FCMHandler._();

  // Initialize FCM, local notifications, and TTS
  Future<void> initialize() async {
    await Firebase.initializeApp();
    await _initTTS();
    _setupLocalNotifications();
    await _setupFCM();
  }

  Future<void> sendTokenAfterLogin() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await _sendTokenToServer();
  }

  Future<void> _initTTS() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setPitch(1.0);
  }

  void _setupLocalNotifications() {
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _setupFCM() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    log('User granted permission: ${settings.authorizationStatus}');

    await _sendTokenToServer();

    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      log('FCM Token refreshed: $newToken');
      await _sendTokenToServer();
    });

 FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
  log('🟢 [FCM] onMessage triggered');

  final String? orderId = message.data['orderId'];
  log('🟡 [FCM] orderId = $orderId');

  if (orderId == null) return;

  // 🔥 DIRECT STATE CHANGE (NO postFrame)
  AppUIState.orderId = orderId;
  AppUIState.screen.value = VisibleScreen.orderDetails;

  log('✅ [UI] Screen state changed');

  await _showNotificationFromMessage(message);
}



    
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundMessageHandler);
  }

  Future<void> _sendTokenToServer() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token == null) {
        log('FCM token is null');
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      // 🔐 Save token to SharedPreferences
      await prefs.setString('fcmToken', token);
      log('FCM token saved to SharedPreferences: $token');

      String? agentId = prefs.getString('agentId');

      if (agentId == null || agentId.isEmpty) {
        log('Agent ID not found');
        return;
      }

      // Send to server via controller
      bool success = await _tokenController.saveTokenToServer(
        agentId: agentId,
        fcmToken: token,
      );

      if (success) {
        log('Token saved to server successfully');
      } else {
        log('Failed to save token to server');
      }
    } catch (e) {
      log('Error sending token: $e');
    }
  }

  // Public method to resend token after login (when agentId becomes available)
  Future<void> resendTokenToServer() async {
    log('Resending FCM token to server after login...');
    try {
      // Ensure Firebase is initialized
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      await _sendTokenToServer();
    } catch (e) {
      log('Error in resendTokenToServer: $e');
      // Don't throw - let login continue even if FCM fails
    }
  }

  // Normalize and show notification for both data-only and notification messages
  Future<void> _showNotificationFromMessage(RemoteMessage message) async {
    try {
      final title = message.notification?.title ??
          message.data['title'] ??
          'New Order Assignment';
      final body = message.notification?.body ??
          message.data['body'] ??
          'You have a new order';

      // Build payload with orderId if present
      final payload = message.data.isNotEmpty
          ? message.data.toString()
          : '{"type":"order_assignment"}';

    const androidDetails = AndroidNotificationDetails(
        'order_channel',
        'Order Notifications',
      importance: Importance.max,
      priority: Priority.high,
        playSound: true,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.show(
      0,
        title,
        body,
      notificationDetails,
        payload: payload,
      );

      final String spokenText = title;
      await _speak(spokenText);
    } catch (e) {
      log("Notification display error: $e");
    }
  }

  Future<void> _speak(String text) async {
    try {
      await flutterTts.awaitSpeakCompletion(true);
      await flutterTts.speak(text);
    } catch (e) {
      log("TTS error: $e");
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _firebaseBackgroundMessageHandler(
    RemoteMessage message,
  ) async {
    await Firebase.initializeApp();
    log("Handling a background message: ${message.messageId}");
  }
}

