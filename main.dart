// Radio Géniale – Correspondant
// Application de prise d'antenne à distance pour les correspondants de
// Radio Géniale. Basée sur l'application open source VDO.Ninja
// (https://github.com/steveseguin/vdon_flutter, licence GPL-3.0).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'radio/accueil_screen.dart';
import 'radio/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: RgColors.fond,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const RadioGenialeApp());
}

class RadioGenialeApp extends StatelessWidget {
  const RadioGenialeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radio Géniale',
      debugShowCheckedModeBanner: false,
      theme: rgTheme(),
      home: const AccueilScreen(),
    );
  }
}
