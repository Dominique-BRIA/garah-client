import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideZonelessChangeDetection } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';

import { Verification } from './verification';

/**
 * L'écran de confirmation d'adresse.
 *
 * <h2>🎯 Ce que ces tests protègent</h2>
 *
 * <p>Cet écran est la porte du parcours : sans adresse confirmée, le serveur
 * refuse toute commande. Une régression ici ne se voit pas — le lien
 * s'ouvrirait, une page s'afficherait, et les ventes s'arrêteraient sans
 * qu'aucune erreur ne remonte.</p>
 *
 * <p>⚠️ C'est <b>exactement</b> ce qui se passait avant qu'il existe : la
 * route était absente, la règle de repli renvoyait vers l'accueil, et le jeton
 * disparaissait en silence.</p>
 */
describe('Verification', () => {
  let fixture: ComponentFixture<Verification>;
  let http: HttpTestingController;

  function monter(jeton: string): Verification {
    fixture = TestBed.createComponent(Verification);
    fixture.componentRef.setInput('jeton', jeton);
    fixture.detectChanges();
    return fixture.componentInstance;
  }

  /** Le texte réellement affiché — pas l'état interne. */
  function affiche(): string {
    return (fixture.nativeElement as HTMLElement).textContent ?? '';
  }

  beforeEach(() => {
    localStorage.clear();
    TestBed.configureTestingModule({
      providers: [
        provideZonelessChangeDetection(),
        provideRouter([]),
        provideHttpClient(),
        provideHttpClientTesting(),
      ],
    });
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('⚠️ envoie le jeton reçu dans l’adresse', () => {
    monter('abc123');

    // Le contrat : POST /api/auth/verification avec { jeton }. C'est ce que
    // le serveur attend — vérifié contre l'API réelle.
    const appel = http.expectOne('/api/auth/verification');
    expect(appel.request.method).toBe('POST');
    expect(appel.request.body).toEqual({ jeton: 'abc123' });
    appel.flush({ confirme: true });
  });

  it('annonce la confirmation, et propose la suite', async () => {
    monter('abc123');
    http.expectOne('/api/auth/verification').flush({ confirme: true });
    await fixture.whenStable();
    fixture.detectChanges();

    expect(affiche()).toContain('confirmée');
    // ⚠️ On ne laisse jamais sur une impasse : la personne vient de sa boîte
    //    mail, elle n'a aucune navigation derrière elle.
    expect(affiche()).toContain('Voir les articles');
  });

  it('⚠️ un 410 dit « lien périmé », et propose d’en redemander un', async () => {
    monter('perime');
    http.expectOne('/api/auth/verification').flush(
      { code: 'LIEN_INVALIDE', message: 'Ce lien de confirmation n’est plus valide.' },
      { status: 410, statusText: 'Gone' },
    );
    await fixture.whenStable();
    fixture.detectChanges();

    expect(affiche()).toContain('n’est plus valide');
    // Sans session, le renvoi est impossible : le serveur l'exige, pour ne pas
    // devenir un outil d'envoi de courriels vers n'importe quelle adresse.
    expect(affiche()).toContain('Connectez-vous');
  });

  it('⚠️ une panne réseau n’est PAS annoncée comme un lien périmé', async () => {
    monter('abc123');
    http.expectOne('/api/auth/verification').error(new ProgressEvent('erreur'));
    await fixture.whenStable();
    fixture.detectChanges();

    // Dire « votre lien est mort » quand c'est la connexion ferait jeter un
    // lien parfaitement valide — et redemander un lien qu'on a déjà.
    expect(affiche()).not.toContain('n’est plus valide');
    expect(affiche()).toContain('Réessayer');
  });

  it('une adresse ouverte sans jeton le dit, sans appeler le serveur', async () => {
    monter('');
    await fixture.whenStable();
    fixture.detectChanges();

    expect(affiche()).toContain('Lien incomplet');
    // ⚠️ `http.verify()` en afterEach échouerait si un appel était parti.
  });
});
