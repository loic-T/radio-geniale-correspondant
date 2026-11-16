import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Ouvre Signal en écran partagé à côté de l'appli (Android uniquement).
class SignalApp {
  static const _canal = MethodChannel('radiogeniale/micservice');

  static bool get disponible => Platform.isAndroid;

  /// Renvoie true si Signal a été ouvert, false s'il n'est pas installé
  /// (le Play Store s'ouvre alors sur sa fiche).
  static Future<bool> ouvrirACote() async {
    try {
      final r = await _canal.invokeMethod<String>('signalACote');
      return r == 'ok';
    } catch (_) {
      return false;
    }
  }
}
