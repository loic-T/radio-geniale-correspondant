import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../src/call_sample/signaling.dart';
import 'arriere_plan.dart';
import 'lecteur_radio.dart';
import 'theme.dart';
import 'turn_servers.dart';

/// Mot de passe par défaut de VDO.Ninja quand aucun n'est saisi
/// (identique à la version web et à l'application officielle).
const _motDePasseParDefaut = 'someEncryptionKey123';

enum _Etat { preparation, connexion, enLigne, horsLigne, erreur }

/// Écran de direct : remplace l'iframe vdo.ninja de la page web
/// (?push=<nom>&p=<mdp>&ad=1&vd=0&monomic&ng=0&aec=0&dn=0&agc=0) par une connexion
/// WebRTC native, et reprend le gros bouton MUTÉ / DÉ-MUTÉ.
class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key, required this.nom, required this.motDePasse});

  final String nom;
  final String motDePasse;

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  Signaling? _signaling;
  Timer? _minuteur;
  _Etat _etat = _Etat.preparation;
  String? _messageErreur;
  bool _microCoupe = false;
  int _recepteurs = 0;
  DateTime? _debut;
  bool _termine = false;

  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  Future<void> _demarrer() async {
    // Sécurité : la radio ne doit jamais jouer pendant un direct correspondant.
    await LecteurRadio.instance.arreter();

    // 1. Autorisations (Android). Sur iOS, la demande système d'accès au
    //    micro s'affiche automatiquement à la première capture.
    if (Platform.isAndroid) {
      final micro = await Permission.microphone.request();
      if (!micro.isGranted) {
        _echec(micro.isPermanentlyDenied
            ? 'Accès au micro refusé. Autorisez-le dans les réglages '
                'Android de l\'application, puis réessayez.'
            : 'L\'application a besoin du micro pour passer à l\'antenne.');
        return;
      }
      // Android 13+ : nécessaire pour afficher la notification « micro actif ».
      await Permission.notification.request();
    }
    if (!mounted || _termine) return;

    // 2. Maintien en arrière-plan (service micro Android / session audio iOS).
    await ArrierePlan.demarrer(nom: widget.nom);

    // 3. Connexion à VDO.Ninja.
    setState(() => _etat = _Etat.connexion);
    final turn = await chargerServeursTurn();
    if (!mounted || _termine) return;

    final signaling = Signaling(
      widget.nom,
      'microphone', // audio seul (équivalent de &vd=0)
      'default',
      '', // pas de salle
      false,
      'wss://wss.vdo.ninja:443',
      turn,
      widget.motDePasse.isEmpty ? _motDePasseParDefaut : widget.motDePasse,
      0,
      'vdo.ninja',
    );
    _signaling = signaling;

    signaling.onSignalingStateChange = (SignalingState etat) {
      if (!mounted) return;
      setState(() {
        if (etat == SignalingState.ConnectionOpen) {
          _etat = _Etat.enLigne;
        } else if (_etat != _Etat.erreur) {
          _etat = _Etat.horsLigne;
        }
      });
    };
    signaling.onCallStateChange = (CallState etat) {};
    signaling.onLocalStream = (MediaStream flux) {};
    signaling.onAddRemoteStream = (MediaStream flux) {};
    signaling.onRemoveRemoteStream = (MediaStream flux) {};
    signaling.onPeersUpdate = (dynamic evenement) {};
    signaling.onDataChannel = (RTCDataChannel canal) {};
    signaling.onDataChannelMessage =
        (RTCDataChannel canal, RTCDataChannelMessage message) {};

    await signaling.connect();
    if (!mounted || _termine) return;

    if (signaling.getLocalStream() == null) {
      _echec(Platform.isIOS
          ? 'Micro inaccessible. Vérifiez Réglages > Radio Géniale > Micro.'
          : 'Micro inaccessible. Il est peut-être utilisé par une autre '
              'application (appel en cours ?).');
      return;
    }

    _debut = DateTime.now();
    _minuteur = Timer.periodic(const Duration(seconds: 1), (_) => _rafraichir());
    _rafraichir();
  }

  void _rafraichir() {
    final s = _signaling;
    if (s == null || !mounted) return;

    // Si toutes les tentatives automatiques de reconnexion ont échoué
    // (coupure réseau prolongée), on relance une série de tentatives.
    if (!s.serveurConnecte &&
        s.active &&
        s.reconnectionAttempt >= s.maxReconnectionAttempts) {
      s.reconnectionAttempt = 0;
      s.attemptConnection();
    }

    setState(() {
      _recepteurs = s.nombreRecepteurs;
      _microCoupe = s.microCoupe;
      if (_etat != _Etat.erreur) {
        _etat = s.serveurConnecte ? _Etat.enLigne : _Etat.horsLigne;
      }
    });
  }

  void _echec(String message) {
    if (!mounted) return;
    setState(() {
      _etat = _Etat.erreur;
      _messageErreur = message;
    });
    _arreter();
  }

  void _basculerMicro() {
    final s = _signaling;
    if (s == null) return;
    final coupe = !_microCoupe;
    s.definirMicroCoupe(coupe);
    setState(() => _microCoupe = coupe);
  }

  Future<void> _arreter() async {
    if (_termine) return;
    _termine = true;
    _minuteur?.cancel();
    final s = _signaling;
    _signaling = null;
    try {
      await s?.close();
    } catch (_) {}
    await ArrierePlan.arreter();
  }

  Future<void> _confirmerSortie() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RgColors.fondSecondaire,
        title: const Text('Terminer le direct ?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Le micro sera coupé et la régie ne vous entendra plus.',
            style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Terminer',
                style: TextStyle(
                    color: RgColors.texte, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _arreter();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _arreter();
    super.dispose();
  }

  String get _duree {
    final debut = _debut;
    if (debut == null) return '';
    final d = DateTime.now().difference(debut);
    String deux(int n) => n.toString().padLeft(2, '0');
    return '${deux(d.inHours)}:${deux(d.inMinutes % 60)}:${deux(d.inSeconds % 60)}';
  }

  ({String texte, Color couleur}) get _statut {
    switch (_etat) {
      case _Etat.preparation:
        return (texte: 'Préparation…', couleur: Colors.white70);
      case _Etat.connexion:
        return (texte: 'Connexion…', couleur: Colors.white70);
      case _Etat.enLigne:
        if (_recepteurs == 0) {
          return (
            texte: 'En ligne – en attente de la régie',
            couleur: Colors.amberAccent
          );
        }
        return (
          texte: 'À l\'antenne · $_recepteurs récepteur${_recepteurs > 1 ? 's' : ''}',
          couleur: RgColors.micOuvert
        );
      case _Etat.horsLigne:
        return (
          texte: 'Connexion perdue – reconnexion…',
          couleur: Colors.orangeAccent
        );
      case _Etat.erreur:
        return (texte: 'Erreur', couleur: Colors.redAccent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statut = _statut;
    final pret = _signaling != null && _etat != _Etat.erreur && _debut != null;

    return PopScope(
      canPop: _etat == _Etat.erreur,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmerSortie();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Image.asset('assets/logo.png', height: 90),
              ),
              Text(
                widget.nom,
                style: const TextStyle(
                    color: RgColors.texte,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.circle, size: 12, color: statut.couleur),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(statut.texte,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: statut.couleur, fontSize: 16)),
                  ),
                ],
              ),
              if (_duree.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_duree,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontFeatures: [FontFeature.tabularFigures()])),
                ),
              Expanded(
                child: Center(
                  child: _etat == _Etat.erreur
                      ? _blocErreur()
                      : pret
                          ? _boutonMicro()
                          : const CircularProgressIndicator(
                              color: RgColors.texte),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _etat == _Etat.erreur
                    ? ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('RETOUR'),
                      )
                    : TextButton.icon(
                        onPressed: _confirmerSortie,
                        icon: const Icon(Icons.call_end, color: RgColors.texte),
                        label: const Text('Terminer le direct',
                            style:
                                TextStyle(color: RgColors.texte, fontSize: 16)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _boutonMicro() {
    final coupe = _microCoupe;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 230,
          height: 230,
          child: ElevatedButton(
            onPressed: _basculerMicro,
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              backgroundColor: coupe ? RgColors.micCoupe : RgColors.micOuvert,
              foregroundColor: Colors.black,
              elevation: 8,
              padding: EdgeInsets.zero,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(coupe ? Icons.mic_off : Icons.mic, size: 64),
                const SizedBox(height: 8),
                Text(
                  coupe ? 'MUTÉ' : 'DÉ-MUTÉ',
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          coupe
              ? 'Micro coupé – touchez pour reprendre la parole'
              : 'Micro ouvert – vous pouvez verrouiller le téléphone',
          textAlign: TextAlign.center,
          style: const TextStyle(color: RgColors.texte),
        ),
      ],
    );
  }

  Widget _blocErreur() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mic_off, size: 72, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(
            _messageErreur ?? 'Une erreur est survenue.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          if (Platform.isAndroid) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: openAppSettings,
              child: const Text('Ouvrir les réglages',
                  style: TextStyle(color: RgColors.texte)),
            ),
          ],
        ],
      ),
    );
  }
}
