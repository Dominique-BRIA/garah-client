import 'package:flutter/material.dart';

import 'api/client_api.dart';
import 'charte/theme.dart';
import 'coque.dart';
import 'services/panier_local.dart';
import 'services/services.dart';
import 'services/session.dart';
import 'services/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ApplicationGarah());
}

/// GARAH, sur téléphone.
///
/// ## Ce que cette application n'est pas
///
/// Ce n'est **pas** la version web enveloppée. Les deux partagent la charte —
/// engendrée depuis `charte/jetons.json` — et rien d'autre. Le web doit être
/// bon du téléphone à l'écran large ; celle-ci n'a qu'un format à servir, et
/// s'en sert : barre du bas, panier qui survit à la fermeture, session qui ne
/// redemande pas le mot de passe à chaque ouverture.
class ApplicationGarah extends StatefulWidget {
  const ApplicationGarah({super.key});

  @override
  State<ApplicationGarah> createState() => _ApplicationGarahState();
}

class _ApplicationGarahState extends State<ApplicationGarah> {
  late final ClientApi _api;
  late final PanierLocal _panier;
  late final ServiceSession _session;
  late final ServiceTheme _theme;

  @override
  void initState() {
    super.initState();
    _api = ClientApi();
    _panier = PanierLocal();
    _session = ServiceSession(_api, _panier);
    _theme = ServiceTheme();

    // Trois lectures locales, aucune bloquante : l'application s'ouvre tout de
    // suite — en clair et déconnectée — puis se corrige. Attendre le réseau
    // pour afficher la première image donnerait un écran blanc de plusieurs
    // secondes sur une connexion lente.
    _theme.relire();
    _panier.relire();
    _session.reprendre();
  }

  @override
  void dispose() {
    _session.dispose();
    _panier.dispose();
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Services(
      api: _api,
      session: _session,
      panier: _panier,
      theme: _theme,
      child: ListenableBuilder(
        listenable: _theme,
        builder: (context, _) => MaterialApp(
          title: 'GARAH',
          debugShowCheckedModeBanner: false,
          theme: ThemeGarah.clair,
          darkTheme: ThemeGarah.sombre,
          // ⚠️ JAMAIS `ThemeMode.system` : voir ServiceTheme. Le défaut est le
          //    clair, et il se change au doigt, pas au réglage du téléphone.
          themeMode: _theme.sombre ? ThemeMode.dark : ThemeMode.light,
          home: const Coque(),
        ),
      ),
    );
  }
}
