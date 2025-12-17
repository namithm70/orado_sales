// lib/presentation/screens/splash_screen.dart

import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oradosales/core/app/app_ui_state.dart'; // ✅ ADDED
import 'package:oradosales/presentation/auth/provider/user_provider.dart';
import 'package:oradosales/presentation/auth/service/selfi_status_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timeoutTimer;
  bool _completed = false; // ✅ prevents double execution

  @override
  void initState() {
    super.initState();

    log("🟥 [Splash] initState");

    // Wait for first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthStatus();
    });

    /// ⏱️ Safety timeout (never stay on splash forever)
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (!_completed) {
        log("⚠️ [Splash] Timeout reached → forcing HOME");
        AppUIState.screen.value = VisibleScreen.home;
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  /// --------------------------------------------------
  /// 🔍 AUTH CHECK (STATE-DRIVEN, NO NAVIGATOR)
  /// --------------------------------------------------
  Future<void> _checkAuthStatus() async {
    try {
      log("🔍 [Splash] Starting auth status check");

      _timeoutTimer?.cancel();

      final prefs = await SharedPreferences.getInstance();
      final fcmToken = prefs.getString('fcmToken') ?? '';
      log("📱 [Splash] FCM token: ${fcmToken.isEmpty ? 'not found' : 'exists'}");

      final authController = context.read<AuthController>();

      // Give provider time to restore token
      await Future.delayed(const Duration(milliseconds: 100));

      final token = authController.token;
      log("🔑 [Splash] Auth token: ${token != null && token.isNotEmpty ? 'exists' : 'null'}");

      if (token != null && token.isNotEmpty) {
        log("✅ [Splash] Token found → checking selfie status");

        final selfieStatus = await SelfieStatusService()
            .fetchSelfieStatus()
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                log("⏱️ [Splash] Selfie check timeout → continue");
                return null;
              },
            );

        log("📸 [Splash] Selfie required: ${selfieStatus?.selfieRequired}");

        /// ❌ OLD (REMOVED)
        /// Navigator.of(context).pushReplacement(...)
        ///
        /// ✅ NEW (STATE BASED)
        AppUIState.screen.value = VisibleScreen.home;
        log("🟢 [Splash] Screen → HOME");
      } else {
        log("🚪 [Splash] No token → HOME / LOGIN FLOW");

        /// ❌ OLD
        /// Navigator.of(context).pushReplacement(LoginScreen)
        ///
        /// ✅ NEW
        AppUIState.screen.value = VisibleScreen.home;
      }

      _completed = true;
    } catch (e, stackTrace) {
      log("❌ [Splash] Error in auth check: $e");
      log("❌ [Splash] StackTrace: $stackTrace");

      /// ❌ OLD
      /// Navigator.of(context).pushReplacement(LoginScreen)
      ///
      /// ✅ NEW (FAIL SAFE)
      AppUIState.screen.value = VisibleScreen.home;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.asset(
          'asstes/oradoLogo.png',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
