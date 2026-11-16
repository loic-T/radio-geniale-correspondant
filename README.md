# Radio Géniale – Correspondant

Application Android et iPhone pour les correspondants de **Radio Géniale**.
Elle remplace la page web `radiogeniale.neocities.org/correspondant` : le correspondant saisit son nom et le mot de passe, appuie sur **COMMENCER**, et son micro part en direct vers la régie via VDO.Ninja. Le gros bouton **MUTÉ / DÉ-MUTÉ** est conservé.

Différences avec la page web :

- **Le micro continue de fonctionner quand l'appli passe en arrière-plan** ou que le téléphone est verrouillé, sur Android comme sur iPhone. La page web ne pouvait pas le faire, parce que les navigateurs mobiles coupent le micro.
- Le son passe par du WebRTC natif et non par une iframe. Les réglages de la page sont repris : audio seul (`&vd=0`), micro sans traitement (`&proaudio`) et mono (`&monomic`).
- Le nom et le mot de passe peuvent être mémorisés sur le téléphone.
- L'écran affiche l'état de la connexion, le nombre de récepteurs connectés et la durée du direct.

## Côté régie

Rien ne change. La régie ouvre le même lien qu'avant :

```
https://vdo.ninja/?view=NOM_DU_CORRESPONDANT&p=MOT_DE_PASSE
```

Si le correspondant n'a pas saisi de mot de passe, le lien n'a pas besoin de `&p=`. Les caractères autres que A-Z, a-z et 0-9 dans le nom (accents, espaces) sont remplacés par `_`, comme sur la version web.

## Compiler les applications (GitHub Actions)

1. Créez un dépôt GitHub. Il doit être **public** pour que les machines macOS soient gratuites ; la licence GPL l'impose de toute façon pour une diffusion.
2. Envoyez-y le contenu de ce dossier, par exemple avec GitHub Desktop, ou en ligne de commande :
   ```bash
   git init && git add . && git commit -m "Radio Géniale Correspondant"
   git branch -M main
   git remote add origin https://github.com/VOTRE_COMPTE/radio-geniale-correspondant.git
   git push -u origin main
   ```
3. Ouvrez l'onglet **Actions** du dépôt. La compilation démarre toute seule et prend environ 10 à 15 minutes.
4. Une fois la compilation terminée, cliquez dessus et téléchargez l'artefact **RadioGeniale-Correspondant-android**. Il contient l'APK.

### Installer sur Android

Copiez l'APK sur le téléphone et ouvrez-le. Android demandera d'autoriser l'installation depuis cette source. Au premier lancement, autorisez le **micro** et les **notifications**.

Pendant un direct, une notification « Radio Géniale – micro actif » reste affichée. Android l'impose pour garder le micro en arrière-plan.

> **Économie de batterie** : certains téléphones (Xiaomi, Huawei, Samsung, Oppo…) ferment quand même les applis en arrière-plan. Dans ce cas, réglez **Paramètres › Applications › Radio Géniale › Batterie** sur **Sans restriction**.

> **Mises à jour** : sans clé de signature fixe, chaque compilation est signée avec une clé de test différente. Il faut alors désinstaller l'ancienne version avant d'installer la nouvelle. Pour l'éviter, et pour publier sur le Play Store, ajoutez une clé (voir plus bas).

### Clé de signature Android (recommandée)

Générez une clé une seule fois et **gardez-la précieusement** :

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 \
        -validity 10000 -alias radiogeniale
base64 -w0 upload-keystore.jks > keystore.txt     # sur macOS : base64 -i upload-keystore.jks
```

Ajoutez ensuite ces secrets dans **Settings › Secrets and variables › Actions** :

| Secret | Valeur |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | le contenu de `keystore.txt` |
| `ANDROID_KEYSTORE_PASSWORD` | le mot de passe du keystore |
| `ANDROID_KEY_ALIAS` | `radiogeniale` |
| `ANDROID_KEY_PASSWORD` | le mot de passe de la clé |

Les compilations suivantes produiront aussi le fichier `.aab` pour le Google Play Store.

### iPhone

GitHub Actions vérifie que l'app iOS compile, mais **Apple impose une signature** pour l'installer sur un iPhone. Il faut :

- un **Mac** avec Xcode et Flutter installés ;
- un **compte Apple Developer** (99 €/an) pour distribuer via TestFlight ou l'App Store. Un compte Apple gratuit permet seulement de tester sur votre propre iPhone, pendant 7 jours.

Sur le Mac :

```bash
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
```

Dans Xcode, sélectionnez la cible **Runner**, puis l'onglet *Signing & Capabilities*. Choisissez votre *Team*. Si l'identifiant `fr.radiogeniale.correspondant` est déjà pris, remplacez-le. Ensuite, utilisez *Product › Archive* pour envoyer l'app sur TestFlight.

Le micro en arrière-plan repose sur le mode « Audio » (déjà activé dans `Info.plist`). Pendant un direct, iOS affiche l'indicateur orange ou rouge du micro.

## Personnaliser

| Quoi | Où |
|---|---|
| Nom affiché sous l'icône | `android/app/src/main/AndroidManifest.xml` (`android:label`) et `ios/Runner/Info.plist` (`CFBundleDisplayName`) |
| Identifiant de l'app | `android/app/build.gradle` (`applicationId`) et Xcode (Bundle Identifier) |
| Couleurs | `lib/radio/theme.dart` (reprises de `style.css`) |
| Logo | `assets/logo.png` |
| Traitements audio (équivalent de `&proaudio`) | `rgProAudio` en haut de `lib/src/call_sample/signaling.dart`. Passez-le à `false` si le son est trop faible ou trop bruité : cela active le gain automatique et la réduction de bruit |
| Textes des écrans | `lib/radio/login_screen.dart` et `lib/radio/live_screen.dart` |

## Structure

```
lib/main.dart                      point d'entrée
lib/radio/login_screen.dart        écran nom + mot de passe + COMMENCER
lib/radio/live_screen.dart         écran de direct (bouton MUTÉ / DÉ-MUTÉ)
lib/radio/arriere_plan.dart        maintien du micro en arrière-plan
lib/radio/turn_servers.dart        serveurs TURN de vdo.ninja
lib/src/call_sample/signaling.dart protocole VDO.Ninja (repris de l'app officielle)
android/.../MicService.kt          service Android « micro actif »
.github/workflows/build.yml        compilation automatique
```

## Licence et origine

Ce projet est une version modifiée de **VDO.Ninja Flutter** de Steve Seguin
(<https://github.com/steveseguin/vdon_flutter>). Il est distribué sous la même licence, la **GNU GPL v3** (voir `LICENSE`).
Toute diffusion de l'application doit s'accompagner de son code source.

Modifications apportées par Radio Géniale (novembre 2026) :

- nouvelle interface (écran de connexion et écran de direct) aux couleurs de Radio Géniale ;
- mode audio seul, sans traitement du micro, avec le mot de passe saisi par le correspondant ;
- service Android de premier plan dédié au micro, avec verrous de veille et Wi-Fi ;
- suppression des écrans caméra et partage d'écran, des autorisations inutiles, et changement des icônes et identifiants.
