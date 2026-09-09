import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideZonelessChangeDetection } from '@angular/core';

import { ServiceSession } from './session';

/**
 * Le contrat entre la boutique et l'API d'authentification.
 *
 * <h2>🎯 Ce que ces tests ferment</h2>
 *
 * <p>La boutique déclarait une réponse qui n'existe pas : <code>jetonAcces</code>
 * et <code>utilisateurId</code> à la racine, là où le serveur envoie
 * <code>jeton</code> et un objet <code>utilisateur</code> imbriqué.</p>
 *
 * <p>Rien ne le signalait. TypeScript ne vérifie <b>rien</b> à l'exécution :
 * <code>post&lt;ResultatConnexion&gt;</code> est une promesse faite au
 * compilateur, pas un contrôle. Lire un champ absent rend
 * <code>undefined</code>, sans erreur — et l'application se croyait connectée
 * avec un nom vide et aucun jeton.</p>
 *
 * <h2>⚠️ Le premier test de cette application</h2>
 *
 * <p>Karma était configuré depuis le début ; aucun fichier <code>.spec.ts</code>
 * n'existait. Un défaut de cette nature — trois noms de champs — ne se voit
 * qu'ici : il compile, il se déploie, et il ne se manifeste que devant
 * l'utilisateur.</p>
 *
 * <p>La réponse ci-dessous est <b>recopiée d'un appel réel</b> à l'API.</p>
 */
describe('ServiceSession', () => {
  // Capturé le 09/09/2026 sur POST /api/auth/connexion.
  const reponseReelle = {
    jeton: 'eyJhbGciOiJIUzI1NiJ9.charge-utile.signature',
    typeJeton: 'Bearer',
    expireDansSecondes: 900,
    utilisateur: {
      id: 42,
      nom: 'Ateba',
      email: 'ateba@garah.cm',
      type: 'CLIENT',
      langue: 'fr',
    },
    permissions: [],
  };

  let session: ServiceSession;
  let http: HttpTestingController;

  beforeEach(() => {
    localStorage.clear();
    TestBed.configureTestingModule({
      providers: [
        provideZonelessChangeDetection(),
        provideHttpClient(),
        provideHttpClientTesting(),
      ],
    });
    session = TestBed.inject(ServiceSession);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  function connecter(reponse: object = reponseReelle): void {
    session.connecter('ateba@garah.cm', 'MotDePasse123').subscribe();
    http.expectOne('/api/auth/connexion').flush(reponse);
    // La fusion du panier part juste après ; on la laisse passer.
    http.match('/api/panier/fusion').forEach((r) => r.flush({}));
  }

  it('⚠️ lit le compte dans l’objet imbriqué, pas à la racine', () => {
    connecter();

    // Lus à la racine, ces trois valaient `undefined` — et l'objet n'étant pas
    // `null`, l'application se déclarait connectée quand même.
    expect(session.connecte()).toBe(true);
    expect(session.nom()).toBe('Ateba');
    expect(session.utilisateurId()).toBe(42);
  });

  it('⚠️ retient le type du compte', () => {
    connecter();

    // Sans lui, le garde ne pouvait pas distinguer un client d'un
    // administrateur : il ne vérifiait que « connecté ».
    expect(session.estClient()).toBe(true);
  });

  it('⚠️ un compte d’administration n’est PAS un client', () => {
    connecter({
      ...reponseReelle,
      utilisateur: { ...reponseReelle.utilisateur, type: 'SUPER_ADMIN' },
    });

    expect(session.connecte()).toBe(true);
    expect(session.estClient()).toBe(false);
  });

  it('une réponse sans utilisateur ne fait pas passer pour connecté', () => {
    // Le cas dégradé : si le contrat changeait à nouveau, on veut un échec
    // franc, pas une session fantôme qui appelle l'API sans jeton.
    session.connecter('ateba@garah.cm', 'MotDePasse123').subscribe();
    http.expectOne('/api/auth/connexion').flush({ jeton: 'x' });

    expect(session.connecte()).toBe(false);
  });
});
