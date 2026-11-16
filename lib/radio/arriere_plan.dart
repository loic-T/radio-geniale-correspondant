import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Maintien du micro quand l'application passe en arrière-plan.
///
/// * Android : démarre un « service de premier plan » de type micro
///   (notification permanente « Micro actif »), avec verrou de veille et
///   verrou Wi-Fi. C'est la seule façon autorisée par Android 9+ de garder
///   l'accès au micro quand l'écran est éteint ou l'appli en arrière-plan.
/// * iOS : configure la session audio en lecture+enregistrement. Le mode
///   d'arrière-plan « audio » (Info.plist) garde alors la capture active.
class ArrierePlan {
  static const _canal = MethodChannel('radiogeniale/micservice');

  static Future<void> demarrer({required String nom}) async {
    if (Platform.isAndroid) {
      try {
        await _canal.invokeMethod('start', {
          'titre': 'Radio Géniale – micro actif',
          'texte': 'En direct : $nom. Touchez pour revenir à l\'appli.',
        });
      } catch (e) {
        // ignore: avoid_print
        print('Service micro non démarré : $e');
      }
    } else if (Platform.isIOS) {
      try {
        await AppleNativeAudioManagement.setAppleAudioConfiguration(
          AppleAudioConfiguration(
            appleAudioCategory: AppleAudioCategory.playAndRecord,
            appleAudioCategoryOptions: const {
              AppleAudioCategoryOption.allowBluetooth,
              AppleAudioCategoryOption.defaultToSpeaker,
              AppleAudioCategoryOption.mixWithOthers,
            },
            appleAudioMode: AppleAudioMode.default_,
          ),
        );
      } catch (e) {
        // ignore: avoid_print
        print('Configuration audio iOS impossible : $e');
      }
    }
  }

  static Future<void> arreter() async {
    if (Platform.isAndroid) {
      try {
        await _canal.invokeMethod('stop');
      } catch (_) {}
    }
  }
}
