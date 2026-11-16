import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'arriere_plan.dart';

/// Flux en direct de Radio Géniale (le même que sur le site).
const String urlFluxRadio = 'https://stream1.world-stream.net/radiogeniale/stream';

enum EtatLecteur { arrete, chargement, lecture, erreur }

/// Lecteur du direct, partagé par toute l'application.
class LecteurRadio extends ChangeNotifier {
  LecteurRadio._();
  static final LecteurRadio instance = LecteurRadio._();

  AudioPlayer? _player;
  // ignore: unused_field
  StreamSubscription<PlayerState>? _abonnement;
  EtatLecteur _etat = EtatLecteur.arrete;
  bool _veutJouer = false;
  bool _aDemarre = false;

  EtatLecteur get etat => _etat;

  /// Détail technique de la dernière erreur (affiché pour le diagnostic).
  String? derniereErreur;

  /// Titre en cours d'après les métadonnées du flux (ex. « MANIFESTATION -
  /// 24 octobre 2026 - Paris (rediffusion) »), null si inconnu.
  String? titre;
  bool get actif =>
      _etat == EtatLecteur.lecture || _etat == EtatLecteur.chargement;

  void _changerEtat(EtatLecteur e) {
    if (_etat == e) return;
    _etat = e;
    notifyListeners();
  }

  Future<void> ecouter() async {
    _veutJouer = true;
    _aDemarre = false;
    derniereErreur = null;
    _changerEtat(EtatLecteur.chargement);
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);

      // User-Agent de navigateur : certains serveurs de flux refusent les
      // lecteurs inconnus alors qu'ils acceptent Chrome.
      final player = _player ??
          AudioPlayer(
            userAgent: 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36 '
                'RadioGeniale/1.0',
          );
      if (_player == null) {
        _player = player;
        _abonnement = player.playerStateStream.listen((s) {
          if (!_veutJouer) {
            _changerEtat(EtatLecteur.arrete);
          } else if (s.processingState == ProcessingState.completed) {
            // Le direct s'est interrompu côté serveur.
            _veutJouer = false;
            _changerEtat(EtatLecteur.arrete);
            ArrierePlan.arreterRadio();
          } else if (s.playing && s.processingState == ProcessingState.ready) {
            _aDemarre = true;
            _changerEtat(EtatLecteur.lecture);
          } else if (_aDemarre && !s.playing) {
            // Mise en pause par le système (appel entrant, casque débranché…).
            _veutJouer = false;
            _changerEtat(EtatLecteur.arrete);
            ArrierePlan.arreterRadio();
          } else {
            _changerEtat(EtatLecteur.chargement);
          }
        }, onError: (Object e, StackTrace st) {
          derniereErreur = e.toString();
          _veutJouer = false;
          _changerEtat(EtatLecteur.erreur);
          ArrierePlan.arreterRadio();
        });
        // Métadonnées ICY envoyées par le serveur (titre de l'émission).
        player.icyMetadataStream.listen((meta) {
          final t = meta?.info?.title?.trim();
          if (t != null && t.isNotEmpty && t != titre) {
            titre = t;
            notifyListeners();
          }
        }, onError: (Object e, StackTrace st) {});
      }

      // On recharge l'URL à chaque fois pour repartir du direct.
      await player.setUrl(urlFluxRadio);
      if (!_veutJouer) return; // STOP pressé pendant le chargement
      await ArrierePlan.demarrerRadio();
      // play() ne se termine qu'à l'arrêt : on ne l'attend pas.
      unawaited(player.play());
    } catch (e) {
      debugPrint('Lecture impossible : $e');
      derniereErreur = e.toString();
      _veutJouer = false;
      _changerEtat(EtatLecteur.erreur);
      await ArrierePlan.arreterRadio();
    }
  }

  Future<void> arreter() async {
    _veutJouer = false;
    try {
      await _player?.stop();
    } catch (_) {}
    _changerEtat(EtatLecteur.arrete);
    await ArrierePlan.arreterRadio();
  }
}
