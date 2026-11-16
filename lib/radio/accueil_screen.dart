import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'lecteur_radio.dart';
import 'login_screen.dart';
import 'theme.dart';

const String emailContact = 'radiogeniale@proton.me';

/// Page d'accueil : reprend radiogeniale.neocities.org (logo, écoute du
/// direct, contact) avec en plus l'accès à l'interface correspondant.
class AccueilScreen extends StatelessWidget {
  const AccueilScreen({super.key});

  Future<void> _ouvrirCorrespondant(BuildContext context) async {
    final lecteur = LecteurRadio.instance;
    if (lecteur.actif) {
      // On coupe la radio : sinon le son du haut-parleur repartirait dans
      // le micro (effet larsen / écho à l'antenne).
      await lecteur.arreter();
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
                        const SizedBox(height: 16),
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
              child: const Text(
                '© Radio Géniale 2026',
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Zone orange avec le bouton ÉCOUTER LA RADIO / STOP.
class _ZoneLecteur extends StatelessWidget {
  const _ZoneLecteur();

  @override
  Widget build(BuildContext context) {
    final lecteur = LecteurRadio.instance;
    return ListenableBuilder(
      listenable: lecteur,
      builder: (context, _) {
        final etat = lecteur.etat;
        final actif = lecteur.actif;

        final String sousTitre;
        switch (etat) {
          case EtatLecteur.arrete:
            sousTitre = 'Le direct de Radio Géniale';
            break;
          case EtatLecteur.chargement:
            sousTitre = 'Connexion au direct…';
            break;
          case EtatLecteur.lecture:
            sousTitre = 'En direct';
            break;
          case EtatLecteur.erreur:
            sousTitre = 'Le direct est indisponible pour le moment. '
                'Vérifiez votre connexion et réessayez.';
            break;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: RgColors.fondTertiaire,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: ElevatedButton(
                  onPressed: actif ? lecteur.arreter : lecteur.ecouter,
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                    backgroundColor: RgColors.fond,
                    foregroundColor: RgColors.texte,
                  ),
                  child: etat == EtatLecteur.chargement
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                              strokeWidth: 3, color: RgColors.texte),
                        )
                      : Icon(actif ? Icons.stop : Icons.play_arrow, size: 44),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (etat == EtatLecteur.lecture) ...[
                          const Icon(Icons.circle,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            actif ? 'STOP' : 'ÉCOUTER LA RADIO',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(sousTitre,
                        style: const TextStyle(
                            color: RgColors.texte, fontSize: 14)),
                  ],
                ),
              ),
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
