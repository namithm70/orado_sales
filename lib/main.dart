import 'dart:developer';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // ✅ ADDED
import 'package:oradosales/core/app/app_route.dart';
import 'package:permission_handler/permission_handler.dart'; // ✅ ADDED
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oradosales/presentation/earnings/provider/earnings_controller.dart';
import 'package:oradosales/presentation/incentive/controller/incentive_controller.dart';
import 'package:oradosales/presentation/leave/controller/leave_controller.dart';
import 'package:oradosales/presentation/letters/controller/letter_controller.dart';
import 'package:oradosales/presentation/mileston/controller/milestone_controller.dart';
import 'package:oradosales/presentation/notification_fcm/controller/notification_get_controlller.dart';
import 'package:oradosales/presentation/notification_fcm/service/fcm_service.dart';
import 'package:oradosales/presentation/auth/provider/login_reg_provider.dart';
import 'package:oradosales/presentation/auth/provider/upload_selfi_controller.dart';
import 'package:oradosales/presentation/auth/provider/user_provider.dart';
import 'package:oradosales/presentation/home/home/provider/home_provider.dart';
import 'package:oradosales/presentation/orders/provider/order_details_provider.dart';
import 'package:oradosales/presentation/orders/provider/order_provider.dart';
import 'package:oradosales/presentation/orders/provider/order_response_controller.dart';
import 'package:oradosales/presentation/home/home/provider/available_provider.dart';
import 'package:oradosales/presentation/home/home/provider/drawer_controller.dart';
import 'package:oradosales/presentation/socket_io/socket_controller.dart';
import 'package:oradosales/presentation/splash_Screen/splash_screen.dart';
import 'package:oradosales/presentation/user/controller/user_controller.dart';
import 'package:oradosales/services/api_services.dart';
import 'package:oradosales/services/app_life_cycle_handler.dart';
import 'package:oradosales/services/navigation_service.dart';
import 'package:oradosales/services/notification_service.dart';

/// ✅ ADDED: notification plugin instance
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// ✅ ADDED: create foreground notification channel
Future<void> _createForegroundNotificationChannel() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'foreground_service',
    'Foreground Service',
    description: 'Background location service',
    importance: Importance.low, // Low importance for background service (no sound/vibration)
    playSound: false,
    enableVibration: false,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  log('✅ Foreground notification channel created');
}

/// ✅ Request runtime notification permission (Android 13+)
Future<void> _ensureNotificationPermission() async {
  if (!Platform.isAndroid) return;

  final status = await Permission.notification.status;
  log('🔔 Notification permission status: $status');

  if (!status.isGranted) {
    final result = await Permission.notification.request();
    log('🔔 Notification permission request result: $result');
  }
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    /// ✅ ADDED (VERY IMPORTANT – MUST BE FIRST)
    await _createForegroundNotificationChannel();
    await _ensureNotificationPermission();

    // ---------------- FIREBASE ----------------
    try {
      await Firebase.initializeApp();
      log('Firebase initialized successfully');
    } catch (e) {
      log('Error initializing Firebase: $e');
    }

    FlutterError.onError = (errorDetails) {
      log('Flutter error: ${errorDetails.exception}');
      try {
        FirebaseCrashlytics.instance.recordFlutterError(errorDetails);
      } catch (_) {}
    };

    // ---------------- SHARED PREFS ----------------
    final sharedPreferences = await SharedPreferences.getInstance();
    log('SharedPreferences initialized');

    final token = sharedPreferences.getString("token");
    if (token != null) {
      APIServices.headers.addAll({'Authorization': 'Bearer $token'});
      log('API token loaded');
    } else {
      log('No API token found');
    }

    // ---------------- SOCKET ----------------
    final socketController = SocketController.instance;
    try {
      await socketController.initializeApp();
      log('Socket controller initialized');
    } catch (e) {
      log('Socket controller error: $e');
    }

    final agentAvailableController =
        AgentAvailableController(socketController);

    // ---------------- FCM ----------------
    final fcmHandler = FCMHandler();
    try {
      await fcmHandler.initialize();
      log('FCM initialized successfully');
    } catch (e) {
      log('FCM init error: $e');
    }

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthController()),
          ChangeNotifierProvider(create: (_) => EarningsController()),
          ChangeNotifierProvider(create: (_) => AgentHomeProvider()),
          ChangeNotifierProvider(create: (_) => AgentProvider()),
          ChangeNotifierProvider(create: (_) => DrawerProvider()),
          ChangeNotifierProvider.value(value: agentAvailableController),
          ChangeNotifierProvider.value(value: socketController),
          ChangeNotifierProvider(create: (_) => OrderController()),
          ChangeNotifierProvider(create: (_) => MilestoneController()),
          ChangeNotifierProvider(create: (_) => OrderDetailController()),
          ChangeNotifierProvider(create: (_) => NotificationController()),
          ChangeNotifierProvider(create: (_) => AgentOrderResponseController()),
          ChangeNotifierProvider(create: (_) => SelfieUploadController()),
          ChangeNotifierProvider(create: (_) => LetterController()),
          ChangeNotifierProvider(create: (_) => LeaveController()),
          ChangeNotifierProvider(create: (_) => AgentProfileController()),
          ChangeNotifierProvider(create: (_) => IncentiveController()),
        ],
        child: const MyApp(),
      ),
    );

    // ---------------- LOCAL NOTIFICATIONS ----------------
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        NotificationService.initialize(
          NavigationService.navigatorKey.currentContext!,
        );
        log('NotificationService initialized');
      } catch (e) {
        log('NotificationService error: $e');
      }
    });
  } catch (e) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Error initializing app')),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final socketController = SocketController.instance;

    return MaterialApp(
      title: 'ORADO Delivery',
      debugShowCheckedModeBanner: false,
      navigatorKey: NavigationService.navigatorKey,
      theme: ThemeData(useMaterial3: true),
      home: AppLifecycleWrapper(
        socketController: socketController,
        child: AppRoot(),
      ),
    );
  }
}
