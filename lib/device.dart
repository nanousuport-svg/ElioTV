import 'dart:io';

import 'package:flutter/services.dart';

/// Type d'appareil : la mise en page et la navigation changent entre téléphone, ordinateur et télévision.
class Device {
  static bool isTv = false;

  static bool get isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    try {
      // Android TV / Fire TV déclarent la fonction « leanback » (interface pour télécommande).
      isTv =
          await const MethodChannel('eliotv/device')
              .invokeMethod<bool>('isTv') ??
          false;
    } catch (_) {}
  }
}
