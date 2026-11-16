import 'dart:convert';

import 'package:http/http.dart' as http;

/// Serveurs STUN/TURN de secours (repris de l'application VDO.Ninja).
const List<Map<String, String>> _turnParDefaut = [
  {'url': 'stun:stun.l.google.com:19302'},
  {
    'url': 'turn:turn-use1.vdo.ninja:3478',
    'username': 'vdoninja',
    'credential': 'EastSideRepresentZ'
  },
  {
    'url': 'turns:www.turn.vdo.ninja:443',
    'username': 'vdoninja',
    'credential': 'IchBinSteveDerNinja'
  },
];

/// Récupère la liste des serveurs TURN publiée par vdo.ninja (indispensable
/// pour passer certains réseaux 4G/5G ou Wi-Fi d'entreprise). En cas d'échec,
/// renvoie la liste par défaut.
Future<List<Map<String, String>>> chargerServeursTurn() async {
  try {
    final uri = Uri.parse('https://turnservers.vdo.ninja/?flutter='
        '${DateTime.now().microsecondsSinceEpoch}');
    final reponse = await http.get(uri).timeout(const Duration(seconds: 8));
    if (reponse.statusCode != 200) return List.of(_turnParDefaut);

    final serveurs = jsonDecode(reponse.body)['servers'];
    if (serveurs is! List) return List.of(_turnParDefaut);

    final liste = <Map<String, String>>[
      {'url': 'stun:stun.l.google.com:19302'},
    ];
    for (final s in serveurs) {
      if (s is! Map) continue;
      final username = s['username']?.toString();
      final credential = s['credential']?.toString();
      final urls = <String>[];
      if (s['url'] is String) {
        urls.add(s['url'] as String);
      } else if (s['urls'] is String) {
        urls.add(s['urls'] as String);
      } else if (s['urls'] is List) {
        urls.addAll((s['urls'] as List).map((u) => u.toString()));
      }
      for (final url in urls) {
        liste.add({
          'url': url,
          if (username != null) 'username': username,
          if (credential != null) 'credential': credential,
        });
      }
    }
    return liste.length > 1 ? liste : List.of(_turnParDefaut);
  } catch (_) {
    return List.of(_turnParDefaut);
  }
}
