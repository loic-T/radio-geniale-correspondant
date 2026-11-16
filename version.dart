/// Version affichée sur l'écran d'accueil (à augmenter à chaque mise à jour).
const String versionApp = '1.2.0';

/// Numéro de compilation GitHub Actions, injecté par le workflow avec
/// --dart-define=RG_BUILD=<numéro>. Vide en compilation locale.
const String numeroBuild = String.fromEnvironment('RG_BUILD');

String get libelleVersion =>
    numeroBuild.isEmpty ? 'v$versionApp' : 'v$versionApp (build $numeroBuild)';
