import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'lecteur_radio.dart';
import 'login_screen.dart';
import 'theme.dart';
import 'version.dart';

const String emailContact = 'radiogeniale@proton.me';

/// Page d'accueil : reprend radiogeniale.neocities.org (logo, écoute du
/// direct, contact) avec en plus l'accès à l'interface correspondant.
class AccueilScreen extends StatelessWidget {
  const AccueilScreen({super.key});

  Future<void> _ouvrirCorrespondant(BuildContext context) async {
    final lecteur = LecteurRadio.instance;
    final etaitActif = lecteur.actif;
    // On coupe toujours la radio : sinon le son du haut-parleur repartirait
    // dans le micro (effet larsen / écho à l'antenne).
    await lecteur.arreter();
    if (etaitActif) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Radio coupée pour éviter l\'écho dans le micro.'),
        ));
      }
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _ecrire(BuildContext context) async {
    final uri = Uri(scheme: 'mailto', path: emailContact);
    bool ok = false;
    try {
      ok = await launchUrl(uri);
    } catch (_) {}
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aucune appli mail trouvée. Écrivez-nous à $emailContact'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset('assets/logo.png', fit: BoxFit.contain),
                        const SizedBox(height: 32),
                        const _ZoneLecteur(),
                        const SizedBox(height: 32),
                        _BlocContact(onEcrire: () => _ecrire(context)),
                        const SizedBox(height: 32),
                        OutlinedButton.icon(
                          onPressed: () => _ouvrirCorrespondant(context),
                          icon: const Icon(Icons.mic),
                          label: const Text('ACCÈS CORRESPONDANT'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: RgColors.texte,
                            side: const BorderSide(
                                color: RgColors.texte, width: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 18),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50)),
                            textStyle: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Pied de page, comme sur le site
            Container(
              width: double.infinity,
              color: RgColors.fondSecondaire,
              padding: EdgeInsets.fromLTRB(
                  16, 14, 16, 14 + MediaQuery.of(context).padding.bottom),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '© Radio Géniale 2026',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                  Text(
                    libelleVersion,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lecteur comme sur le site : bouton vert ECOUTER LA RADIO, titre en
/// cours (métadonnées du flux), bouton noir STOP.
class _ZoneLecteur extends StatelessWidget {
  const _ZoneLecteur();

  static const _vert = Color(0xFF5CB85C);

  Widget _gros(String texte, Color fond, VoidCallback? action,
      {Widget? enTete}) {
    return SizedBox(
      height: 104,
      child: ElevatedButton(
        onPressed: action,
        style: ElevatedButton.styleFrom(
          backgroundColor: fond,
          foregroundColor: Colors.white,
          disabledBackgroundColor: fond.withValues(alpha: 0.6),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w400),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (enTete != null) ...[enTete, const SizedBox(width: 12)],
            Text(texte),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lecteur = LecteurRadio.instance;
    return ListenableBuilder(
      listenable: lecteur,
      builder: (context, _) {
        final etat = lecteur.etat;
        final actif = lecteur.actif;

        Widget? enTete;
        if (etat == EtatLecteur.chargement) {
          enTete = const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white),
          );
        } else if (etat == EtatLecteur.lecture) {
          enTete = const Icon(Icons.graphic_eq, color: Colors.white);
        }

        final String? info;
        switch (etat) {
          case EtatLecteur.chargement:
            info = lecteur.titre ?? 'Connexion au direct…';
            break;
          case EtatLecteur.erreur:
            info = 'Le direct est indisponible pour le moment. '
                'Vérifiez votre connexion et réessayez.';
            break;
          case EtatLecteur.lecture:
          case EtatLecteur.arrete:
            info = lecteur.titre;
            break;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _gros('ECOUTER LA RADIO', _vert,
                  actif ? null : lecteur.ecouter,
                  enTete: enTete),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Text(
                      info ?? ' ',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    if (etat == EtatLecteur.erreur) ...[
                      const SizedBox(height: 6),
                      SelectableText(
                        'Détail : ${lecteur.derniereErreur ?? 'aucun'}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              _gros('STOP', Colors.black, lecteur.arreter),
            ],
          ),
        );
      },
    );
  }
}

class _BlocContact extends StatelessWidget {
  const _BlocContact({required this.onEcrire});

  final VoidCallback onEcrire;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contact',
          style: TextStyle(
              color: RgColors.texte, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Une remarque ? Une question ? Contactez-nous par mail :',
          style: TextStyle(
              color: RgColors.texte, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onEcrire,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mail_outline, color: RgColors.texte),
                SizedBox(width: 8),
                Text(
                  emailContact,
                  style: TextStyle(
                    color: RgColors.texte,
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    decoration: TextDecoration.underline,
                    decorationColor: RgColors.texte,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
