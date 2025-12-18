import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:oradosales/core/app/app_ui_state.dart';
import 'package:oradosales/presentation/auth/view/login.dart';
import 'package:oradosales/presentation/home/main_screen.dart';
import 'package:oradosales/presentation/orders/view/new_task_screen.dart';
import 'package:oradosales/presentation/orders/view/order_details_screen.dart';
import 'package:oradosales/presentation/splash_Screen/splash_screen.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    log('🧱 [AppRoot] build() called');

    return ValueListenableBuilder<VisibleScreen>(
      valueListenable: AppUIState.screen,
      builder: (context, screen, _) {
        log('🟦 [AppRoot] ValueListenableBuilder rebuild → $screen');

        switch (screen) {
          case VisibleScreen.orderDetails:
            log('🟩 [AppRoot] Rendering OrderDetailsNotificationRoute');
            return const NewTaskScreen();

          case VisibleScreen.login:
            log('🟧 [AppRoot] Rendering LoginScreen');
            return const LoginScreen();

          case VisibleScreen.home:
            log('🟨 [AppRoot] Rendering HomeScreen');
            return const  MainScreen();

          case VisibleScreen.splash:
            log('🟥 [AppRoot] Rendering SplashScreen');
            return const SplashScreen();
        }
      },
    );
  }
}
