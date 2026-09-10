import 'package:flutter/widgets.dart';

import '../api/client_api.dart';
import 'panier_local.dart';
import 'session.dart';
import 'temps_reel.dart';
import 'theme.dart';

/// Les services de l'application, accessibles depuis n'importe quel écran.
///
/// ## Pourquoi pas un paquet d'injection
///
/// Cinq objets, aucune construction conditionnelle, aucune portée imbriquée :
/// un `InheritedWidget` suffit et ne coûte ni téléchargement, ni génération de
/// code, ni montée de version à surveiller. Sur ce projet, la liste des
/// dépendances est un choix, pas une fatalité.
///
/// ⚠️ `updateShouldNotify` rend **false** : ces objets ne sont jamais
///    remplacés, ils changent d'état à l'intérieur. Ce sont leurs
///    `ChangeNotifier` que les écrans écoutent, via `ListenableBuilder` — pas
///    cet `InheritedWidget`, qui reconstruirait tout l'arbre à chaque
///    battement.
class Services extends InheritedWidget {
  const Services({
    super.key,
    required this.api,
    required this.session,
    required this.panier,
    required this.theme,
    required this.tempsReel,
    required super.child,
  });

  final ClientApi api;
  final ServiceSession session;
  final PanierLocal panier;
  final ServiceTheme theme;

  /// Le temps reel des conversations. Une SEULE prise pour toute
  /// l application : une par ecran reveillerait la radio d autant de fois.
  final ServiceTempsReel tempsReel;

  static Services de(BuildContext context) {
    final services = context.dependOnInheritedWidgetOfExactType<Services>();
    assert(services != null, 'Aucun Services au-dessus de ce widget.');
    return services!;
  }

  @override
  bool updateShouldNotify(Services ancien) => false;
}
