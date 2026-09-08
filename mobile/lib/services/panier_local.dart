import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Une ligne du panier local.
///
/// [prixIndicatif] est bien indicatif : le serveur recalcule au bon palier et
/// fige le prix à la commande. L'afficher comme un engagement mentirait le
/// jour où un tarif change entre l'ajout et le paiement.
class LigneLocale {
  const LigneLocale({
    required this.varianteId,
    required this.quantite,
    required this.nomProduit,
    required this.libelleDeclinaison,
    required this.urlPhoto,
    required this.prixIndicatif,
  });

  final int varianteId;
  final int quantite;
  final String nomProduit;
  final String? libelleDeclinaison;
  final String? urlPhoto;
  final num? prixIndicatif;

  LigneLocale avecQuantite(int q) => LigneLocale(
    varianteId: varianteId,
    quantite: q,
    nomProduit: nomProduit,
    libelleDeclinaison: libelleDeclinaison,
    urlPhoto: urlPhoto,
    prixIndicatif: prixIndicatif,
  );

  Map<String, dynamic> versJson() => {
    'varianteId': varianteId,
    'quantite': quantite,
    'nomProduit': nomProduit,
    'libelleDeclinaison': libelleDeclinaison,
    'urlPhoto': urlPhoto,
    'prixIndicatif': prixIndicatif,
  };

  factory LigneLocale.de(Map<String, dynamic> j) => LigneLocale(
    varianteId: (j['varianteId'] as num).toInt(),
    quantite: (j['quantite'] as num).toInt(),
    nomProduit: (j['nomProduit'] as String?) ?? 'Article',
    libelleDeclinaison: j['libelleDeclinaison'] as String?,
    urlPhoto: j['urlPhoto'] as String?,
    prixIndicatif: j['prixIndicatif'] as num?,
  );
}

/// Le panier qui vit dans le téléphone.
///
/// ## 🎯 On remplit son panier SANS COMPTE
///
/// Exiger la connexion pour ajouter un article ferait fuir au premier
/// « Ajouter ». La connexion arrive au moment de commander, pas avant — et à
/// ce moment-là le panier local est FUSIONNÉ avec celui du serveur.
///
/// ## ⚠️ Ce panier n'est JAMAIS la vérité
///
/// Le serveur décide du stock et du prix. Lui faire confiance, c'est vendre ce
/// qu'on n'a plus. Il ne sert qu'à ne pas perdre ce qu'on a choisi.
class PanierLocal extends ChangeNotifier {
  static const _cle = 'garah.panier';

  final List<LigneLocale> _lignes = [];

  List<LigneLocale> get lignes => List.unmodifiable(_lignes);

  int get nombreArticles => _lignes.fold(0, (somme, l) => somme + l.quantite);

  num get sousTotal => _lignes.fold<num>(
    0,
    (somme, l) => somme + (l.prixIndicatif ?? 0) * l.quantite,
  );

  Future<void> relire() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brut = prefs.getString(_cle);
      if (brut == null) return;
      _lignes
        ..clear()
        ..addAll(
          (jsonDecode(brut) as List<dynamic>).map(
            (e) => LigneLocale.de(e as Map<String, dynamic>),
          ),
        );
      notifyListeners();
    } catch (_) {
      // Stockage illisible ou format d'une version précédente : on repart d'un
      // panier vide plutôt que d'empêcher l'application de démarrer.
      _lignes.clear();
    }
  }

  /// Ajoute, ou RELÈVE la quantité si l'article y est déjà.
  ///
  /// ⚠️ On ne cumule pas les deux quantités : sur une connexion instable, le
  ///    même ajout part parfois deux fois. Prendre la plus grande rend le
  ///    geste idempotent ; additionner ferait grimper le panier tout seul.
  Future<void> ajouter(LigneLocale ligne) async {
    final i = _lignes.indexWhere((l) => l.varianteId == ligne.varianteId);
    if (i >= 0) {
      final existante = _lignes[i];
      if (ligne.quantite > existante.quantite) {
        _lignes[i] = existante.avecQuantite(ligne.quantite);
      }
    } else {
      _lignes.add(ligne);
    }
    await _ecrire();
  }

  Future<void> changerQuantite(int varianteId, int quantite) async {
    final i = _lignes.indexWhere((l) => l.varianteId == varianteId);
    if (i < 0) return;
    if (quantite <= 0) {
      _lignes.removeAt(i);
    } else {
      _lignes[i] = _lignes[i].avecQuantite(quantite);
    }
    await _ecrire();
  }

  Future<void> retirer(int varianteId) async {
    _lignes.removeWhere((l) => l.varianteId == varianteId);
    await _ecrire();
  }

  Future<void> vider() async {
    _lignes.clear();
    await _ecrire();
  }

  /// Ce qu'on envoie au serveur à la connexion.
  List<Map<String, dynamic>> pourFusion() => _lignes
      .map((l) => {'varianteId': l.varianteId, 'quantite': l.quantite})
      .toList();

  Future<void> _ecrire() async {
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cle,
        jsonEncode(_lignes.map((l) => l.versJson()).toList()),
      );
    } catch (_) {
      // Écriture refusée : le panier vaut pour cette session. Faire échouer
      // l'ajout serait pire — le bouton ne ferait rien.
    }
  }
}
