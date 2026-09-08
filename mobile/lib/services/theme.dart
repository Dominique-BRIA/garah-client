import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Le thème choisi.
///
/// ## ⚠️ Le CLAIR est le défaut, pas le réglage du système
///
/// Une boutique se regarde comme une vitrine : photos sur fond clair, prix en
/// noir sur blanc. Suivre `prefers-color-scheme` donnait le sombre à tout
/// téléphone réglé ainsi — c'est-à-dire beaucoup — et la boutique n'avait
/// jamais l'air de ce qu'on avait dessiné. Le sombre reste disponible, mais il
/// se **choisit**.
///
/// C'est la même règle que sur le web : deux applications de la même maison ne
/// s'ouvrent pas sur deux fonds différents.
class ServiceTheme extends ChangeNotifier {
  static const _cle = 'garah.theme';

  bool _sombre = false;

  bool get sombre => _sombre;

  Future<void> relire() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _sombre = prefs.getString(_cle) == 'sombre';
      notifyListeners();
    } catch (_) {
      // Préférences illisibles : on garde le clair, qui est le défaut voulu.
    }
  }

  Future<void> basculer() async {
    _sombre = !_sombre;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cle, _sombre ? 'sombre' : 'clair');
    } catch (_) {
      // Le choix vaut pour cette session. Faire échouer la bascule serait
      // pire : le bouton ne ferait rien.
    }
  }
}
