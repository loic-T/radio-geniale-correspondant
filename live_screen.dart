import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../src/call_sample/signaling.dart';
import 'arriere_plan.dart';
import 'lecteur_radio.dart';
import 'signal.dart';
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
    return PopScope(
      canPop: _etat == _Etat.erreur,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmerSortie();
      },
      child: Scaffold(
        body: SafeArea(
          // L'écran s'adapte à la place disponible : plein écran, écran
          // partagé (ex. avec Signal), fenêtre flottante, paysage…
          child: LayoutBuilder(
            builder: (context, c) {
              final compact = c.maxHeight < 520;
              final paysage = c.maxWidth > c.maxHeight * 1.3;
              if (compact && paysage) return _dispositionPaysage(c);
              return _dispositionVerticale(c, compact);
            },
          ),
        ),
      ),
    );
  }

  bool get _pret => _signaling != null && _etat != _Etat.erreur && _debut != null;

  /// Pastille d'état + durée.
  Widget _statutLigne({required bool compact}) {
    final statut = _statut;
    final taille = compact ? 14.0 : 16.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: compact ? 10 : 12, color: statut.couleur),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _duree.isEmpty ? statut.texte : '${statut.texte} · $_duree',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: statut.couleur,
              fontSize: taille,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _ouvrirSignal() async {
    final ok = await SignalApp.ouvrirACote();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Signal n\'est pas installé : ouverture du Play Store.'),
      ));
    }
  }

  /// Boutons du bas : Terminer + (Android) Signal à côté.
  Widget _actions({required bool compact}) {
    final signal = SignalApp.disponible && _etat != _Etat.erreur;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        _boutonTerminer(compact: compact),
        if (signal)
          TextButton.icon(
            onPressed: _ouvrirSignal,
            icon: const Icon(Icons.vertical_split, color: RgColors.texte),
            label: Text(compact ? 'Signal' : 'Signal à côté',
                style: const TextStyle(color: RgColors.texte, fontSize: 16)),
          ),
      ],
    );
  }

  Widget _boutonTerminer({required bool compact}) {
    if (_etat == _Etat.erreur) {
      return ElevatedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('RETOUR'),
      );
    }
    return TextButton.icon(
      onPressed: _confirmerSortie,
      icon: const Icon(Icons.call_end, color: RgColors.texte),
      label: Text(compact ? 'Terminer' : 'Terminer le direct',
          style: const TextStyle(color: RgColors.texte, fontSize: 16)),
    );
  }

  /// Zone centrale : bouton micro (taille calculée selon la place), erreur
  /// ou chargement. FittedBox garantit qu'aucun débordement n'est possible.
  Widget _zoneCentrale(double largeur, double hauteur, {required bool compact}) {
    Widget contenu;
    if (_etat == _Etat.erreur) {
      contenu = SizedBox(
          width: largeur.clamp(200.0, 480.0).toDouble(), child: _blocErreur());
    } else if (_pret) {
      final aide = compact ? 0.0 : 48.0;
      final diametre =
          [hauteur - aide - 16, largeur - 32, 230.0].reduce((a, b) => a < b ? a : b)
              .clamp(96.0, 230.0).toDouble();
      contenu = _boutonMicro(diametre, avecAide: !compact);
    } else {
      contenu = const CircularProgressIndicator(color: RgColors.texte);
    }
    return Center(child: FittedBox(fit: BoxFit.scaleDown, child: contenu));
  }

  Widget _dispositionVerticale(BoxConstraints c, bool compact) {
    final logo = c.maxHeight >= 640 ? 90.0 : (c.maxHeight >= 520 ? 60.0 : 0.0);
    return Column(
      children: [
        if (logo > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Image.asset('assets/logo.png', height: logo),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, compact ? 6 : 4, 16, 0),
          child: Text(
            widget.nom,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: RgColors.texte,
                fontSize: compact ? 18 : 22,
                fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: _statutLigne(compact: compact),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, zone) =>
                _zoneCentrale(zone.maxWidth, zone.maxHeight, compact: compact),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: compact ? 2 : 16),
          child: _actions(compact: compact),
        ),
      ],
    );
  }

  /// Fenêtre basse et large (écran partagé en paysage) : infos à gauche,
  /// bouton micro à droite.
  Widget _dispositionPaysage(BoxConstraints c) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (c.maxHeight >= 260)
                  Flexible(
                    child: Image.asset('assets/logo.png', height: 60),
                  ),
                Text(
                  widget.nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: RgColors.texte,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                _statutLigne(compact: true),
                const SizedBox(height: 4),
                _actions(compact: true),
              ],
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, zone) =>
                _zoneCentrale(zone.maxWidth, zone.maxHeight, compact: true),
          ),
        ),
      ],
    );
  }

  Widget _boutonMicro(double diametre, {required bool avecAide}) {
    final coupe = _microCoupe;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: diametre,
          height: diametre,
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
                Icon(coupe ? Icons.mic_off : Icons.mic, size: diametre * 0.28),
                SizedBox(height: diametre * 0.03),
                Text(
                  coupe ? 'MUTÉ' : 'DÉ-MUTÉ',
                  style: TextStyle(
                      fontSize: diametre * 0.13, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
        ),
        if (avecAide) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: 300,
            child: Text(
              coupe
                  ? 'Micro coupé – touchez pour reprendre la parole'
                  : 'Micro ouvert – vous pouvez verrouiller le téléphone',
              textAlign: TextAlign.center,
              style: const TextStyle(color: RgColors.texte),
            ),
          ),
        ],
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
