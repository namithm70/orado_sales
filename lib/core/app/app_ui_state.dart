import 'package:flutter/material.dart';

enum VisibleScreen {
  splash,
  home,
  orderDetails,
}

class AppUIState {
  static final ValueNotifier<VisibleScreen> screen =
      ValueNotifier(VisibleScreen.splash);

  static String? orderId;
}
