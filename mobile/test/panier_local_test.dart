import 'package:flutter_test/flutter_test.dart';
import 'package:garah_mobile/services/panier_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

LigneLocale ligne(int varianteId, int quantite, {num prix = 1000}) =>
    LigneLocale(
      varianteId: varianteId,
      quantite: quantite,
      nomProduit: 'Article $varianteId',
      libelleDeclinaison: null,
      urlPhoto: null,
      prixIndicatif: prix,
    );

void main() {
  setUp(() {
    // Le stockage du téléphone, remplacé par une carte en mémoire : les tests
    // ne doivent pas dépendre de ce qu'une exécution précédente a laissé.
    SharedPreferences.setMockInitialValues({});
  });

  test('ajoute une ligne et compte les articles', () async {
    final panier = PanierLocal();
    await panier.ajouter(ligne(1, 2));
    await panier.ajouter(ligne(2, 3));

    expect(panier.lignes.length, 2);
    expect(panier.nombreArticles, 5);
    expect(panier.sousTotal, 5000);
  });

  test(
    '⚠️ un ajout répété RELÈVE la quantité, il ne l’additionne pas',
    () async {
      // Sur une connexion instable, le même ajout part parfois deux fois.
      // Additionner ferait grimper le panier tout seul, sans que personne n'ait
      // rien demandé — et on découvre trois articles au moment de payer.
      final panier = PanierLocal();
      await panier.ajouter(ligne(1, 2));
      await panier.ajouter(ligne(1, 2));

      expect(panier.lignes.single.quantite, 2);
    },
  );

  test('une quantité plus grande l’emporte', () async {
    final panier = PanierLocal();
    await panier.ajouter(ligne(1, 2));
    await panier.ajouter(ligne(1, 5));

    expect(panier.lignes.single.quantite, 5);
  });

  test(
    'une quantité plus petite ne rabaisse pas ce qui est au panier',
    () async {
      final panier = PanierLocal();
      await panier.ajouter(ligne(1, 5));
      await panier.ajouter(ligne(1, 2));

      expect(panier.lignes.single.quantite, 5);
    },
  );

  test('descendre à zéro SUPPRIME la ligne', () async {
    // C'est ce qu'on veut dire en retirant la dernière unité. Laisser une
    // ligne à zéro obligerait à chercher un second geste.
    final panier = PanierLocal();
    await panier.ajouter(ligne(1, 1));
    await panier.changerQuantite(1, 0);

    expect(panier.lignes, isEmpty);
  });

  test('le panier survit à la fermeture de l’application', () async {
    final premier = PanierLocal();
    await premier.ajouter(ligne(7, 4));

    // Une nouvelle instance : c'est ce qui se passe au redémarrage.
    final second = PanierLocal();
    await second.relire();

    expect(second.lignes.single.varianteId, 7);
    expect(second.lignes.single.quantite, 4);
  });

  test('la charge de fusion ne porte que ce que le serveur décide', () async {
    // ⚠️ Ni le prix, ni le nom : le panier local n'est JAMAIS la vérité. Le
    //    serveur recalcule au bon palier et vérifie le stock — lui envoyer un
    //    prix reviendrait à le laisser fixer par le téléphone.
    final panier = PanierLocal();
    await panier.ajouter(ligne(1, 2));

    expect(panier.pourFusion(), [
      {'varianteId': 1, 'quantite': 2},
    ]);
  });

  test('un stockage illisible donne un panier vide, pas un plantage', () async {
    SharedPreferences.setMockInitialValues({
      'garah.panier': 'ceci n’est pas du JSON',
    });

    final panier = PanierLocal();
    await panier.relire();

    // Une préférence corrompue ne doit pas empêcher l'application de démarrer.
    expect(panier.lignes, isEmpty);
  });
}
