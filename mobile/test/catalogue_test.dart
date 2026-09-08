import 'package:flutter_test/flutter_test.dart';
import 'package:garah_mobile/modeles/catalogue.dart';

void main() {
  group('montantLisible', () {
    test('sépare les milliers et nomme le franc CFA', () {
      // ⚠️ L'espace est INSÉCABLE ÉTROIT (U+202F), pas une espace ordinaire :
      //    sans lui, « 106 000 FCFA » se coupe en fin de ligne entre 106 et
      //    000, et le prix devient illisible sur un écran étroit.
      expect(montantLisible(106000), '106 000 FCFA');
      expect(montantLisible(900), '900 FCFA');
    });

    test('rend un tiret pour un prix absent', () {
      // Un brouillon sans tarif : « 0 FCFA » ferait croire à un article
      // gratuit, ce qui est faux et invendable.
      expect(montantLisible(null), '—');
    });

    test('garde la devise quand ce n’est pas le franc CFA', () {
      expect(montantLisible(1500, 'EUR'), '1 500 EUR');
    });
  });

  group('PalierPrix', () {
    const petit = PalierPrix(
      quantiteMin: 1,
      quantiteMax: 5,
      prixUnitaire: 1000,
    );
    const moyen = PalierPrix(
      quantiteMin: 6,
      quantiteMax: 11,
      prixUnitaire: 900,
    );
    const gros = PalierPrix(
      quantiteMin: 12,
      quantiteMax: null,
      prixUnitaire: 800,
    );

    test('le dernier palier se lit « et + »', () {
      expect(petit.plage, '1 – 5');
      expect(gros.plage, '12 et +');
    });

    test('couvre bornes comprises', () {
      expect(petit.couvre(1), isTrue);
      expect(petit.couvre(5), isTrue);
      expect(petit.couvre(6), isFalse);
      // Sans maximum, le dernier palier couvre tout ce qui dépasse.
      expect(gros.couvre(9999), isTrue);
    });

    group('sur une déclinaison', () {
      Declinaison avec({required int disponible}) => Declinaison(
        id: 1,
        libelle: 'M',
        paliers: const [petit, moyen, gros],
        disponible: disponible,
        quantiteMinimale: 1,
      );

      test('le palier applicable suit la quantité', () {
        final d = avec(disponible: 50);
        expect(d.palierPour(3)?.prixUnitaire, 1000);
        expect(d.palierPour(8)?.prixUnitaire, 900);
        expect(d.palierPour(40)?.prixUnitaire, 800);
      });

      test('invite au palier suivant quand le stock suit', () {
        final d = avec(disponible: 50);
        expect(d.palierSuivant(3)?.quantiteMin, 6);
      });

      test('⚠️ SE TAIT quand le stock ne suit pas', () {
        // Promettre un tarif qu'on ne peut pas honorer est pire que se taire :
        // le client monte sa quantité, et découvre au panier qu'il n'y a pas
        // assez d'articles pour le prix annoncé.
        final d = avec(disponible: 4);
        expect(d.palierSuivant(3), isNull);
      });

      test('achetable exige un prix ET du stock', () {
        expect(avec(disponible: 10).achetable, isTrue);
        expect(avec(disponible: 0).achetable, isFalse);

        // En rayon mais sans tarif : se laisserait mettre au panier et
        // échouerait au paiement, au pire moment.
        const sansPrix = Declinaison(
          id: 2,
          libelle: 'L',
          paliers: [],
          disponible: 10,
          quantiteMinimale: 1,
        );
        expect(sansPrix.achetable, isFalse);
      });
    });
  });

  group('FicheVitrine', () {
    test('met la photo principale en tête, puis suit l’ordre', () {
      final fiche = FicheVitrine.de({
        'id': 1,
        'nom': 'Chaussure',
        'slug': 'chaussure',
        'description': null,
        'tauxTva': 0,
        'marchandNom': 'BRIA',
        'categorie': {'id': 3, 'nom': 'Chaussure', 'slug': 'chaussure'},
        'declinaisons': [],
        'medias': [
          {'id': 10, 'url': 'b.jpg', 'principal': false, 'ordre': 2},
          {'id': 11, 'url': 'c.jpg', 'principal': false, 'ordre': 1},
          {'id': 12, 'url': 'a.jpg', 'principal': true, 'ordre': 9},
        ],
      });

      // La couverture d'abord : c'est elle qui part au panier, quelle que soit
      // la photo qu'on regarde à l'écran.
      expect(fiche.medias.map((m) => m.url), ['a.jpg', 'c.jpg', 'b.jpg']);
      expect(fiche.categorieNom, 'Chaussure');
    });

    test('supporte un marchand disparu', () {
      final fiche = FicheVitrine.de({
        'id': 1,
        'nom': 'X',
        'slug': 'x',
        'tauxTva': 19.25,
        'marchandNom': null,
        'declinaisons': [],
        'medias': [],
      });
      // L'écran écrira « vendeur inconnu » : faire échouer la fiche entière
      // pour un nom manquant rendrait un article inaccessible.
      expect(fiche.marchandNom, isNull);
      expect(fiche.tauxTva, 19.25);
    });
  });

  group('PageDe', () {
    test('déduit « dernière page » du numéro et du total', () {
      final page = PageDe.de({
        'content': [
          {
            'id': 1,
            'nom': 'A',
            'slug': 'a',
            'devise': 'XAF',
            'quantiteDisponible': 3,
          },
        ],
        'page': {'size': 24, 'number': 2, 'totalElements': 60, 'totalPages': 3},
      }, ResumeProduit.de);

      expect(page.contenu.single.nom, 'A');
      expect(page.total, 60);
      expect(page.derniere, isTrue);
    });

    test('une page absente ne fait pas échouer la lecture', () {
      // Certaines routes rendent une liste sans métadonnées de pagination.
      final page = PageDe.de({'content': <dynamic>[]}, ResumeProduit.de);
      expect(page.contenu, isEmpty);
      expect(page.derniere, isTrue);
    });
  });
}
