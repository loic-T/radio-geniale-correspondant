import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'live_screen.dart';
import 'theme.dart';

/// Écran d'accueil : équivalent de la page /correspondant du site
/// (nom du correspondant + mot de passe + bouton COMMENCER).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nomController = TextEditingController();
  final _mdpController = TextEditingController();
  bool _mdpVisible = false;
  bool _memoriser = true;

  @override
  void initState() {
    super.initState();
    _chargerPreferences();
  }

  Future<void> _chargerPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nomController.text = prefs.getString('rg_nom') ?? '';
      _mdpController.text = prefs.getString('rg_mdp') ?? '';
      _memoriser = prefs.getBool('rg_memoriser') ?? true;
    });
  }

  Future<void> _sauverPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rg_memoriser', _memoriser);
    if (_memoriser) {
      await prefs.setString('rg_nom', _nomController.text.trim());
      await prefs.setString('rg_mdp', _mdpController.text);
    } else {
      await prefs.remove('rg_nom');
      await prefs.remove('rg_mdp');
    }
  }

  Future<void> _commencer() async {
    final nom = _nomController.text.trim();
    if (nom.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indiquez le nom du correspondant.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    await _sauverPreferences();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LiveScreen(nom: nom, motDePasse: _mdpController.text),
    ));
  }

  @override
  void dispose() {
    _nomController.dispose();
    _mdpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset('assets/logo.png', fit: BoxFit.contain),
                  const SizedBox(height: 8),
                  const Text(
                    'Interface correspondant',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: RgColors.texte,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nomController,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    style: const TextStyle(color: Colors.black, fontSize: 18),
                    decoration: const InputDecoration(
                      hintText: 'nom du correspondant',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _mdpController,
                    obscureText: !_mdpVisible,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _commencer(),
                    style: const TextStyle(color: Colors.black, fontSize: 18),
                    decoration: InputDecoration(
                      hintText: 'mot de passe',
                      suffixIcon: IconButton(
                        color: Colors.black54,
                        icon: Icon(_mdpVisible
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _mdpVisible = !_mdpVisible),
                      ),
                    ),
                  ),
                  CheckboxListTile(
                    value: _memoriser,
                    onChanged: (v) => setState(() => _memoriser = v ?? true),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: RgColors.texte,
                    checkColor: RgColors.fond,
                    title: const Text(
                      'Se souvenir de moi sur ce téléphone',
                      style: TextStyle(color: RgColors.texte),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _commencer,
                    child: const Text('COMMENCER'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
