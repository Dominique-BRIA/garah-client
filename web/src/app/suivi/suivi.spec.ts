import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideZonelessChangeDetection } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';

import { Suivi } from './suivi';

/**
 * Le guichet public « Suivre un colis ».
 *
 * <h2>🎯 Ce que ces tests protègent</h2>
 *
 * <p>Deux routes mènent ici : <code>/suivi</code>, qui affiche un champ, et
 * <code>/suivi/GRH…</code>, qui cherche tout de suite. La seconde existe pour
 * qu'un lien partagé — par SMS, par WhatsApp — conduise directement à la
 * réponse.</p>
 *
 * <p>⚠️ Sur la première, le liage d'entrées du routeur pose
 * <code>undefined</code> : la valeur par défaut <code>''</code> ne le rattrape
 * pas. Appeler <code>.trim()</code> dessus levait une TypeError dans l'effet de
 * construction, et Angular vidait le gabarit <b>entier</b> — le client cliquait
 * sur « Suivre un colis » et arrivait sur une page blanche, sans message et
 * sans erreur visible.</p>
 *
 * <p>C'est le même défaut, au même endroit du cycle de vie, que sur l'écran de
 * vérification d'adresse. Le type <code>string</code> est une promesse faite au
 * compilateur, que rien ne vérifie à l'exécution.</p>
 */
describe('Suivi', () => {
  let fixture: ComponentFixture<Suivi>;
  let http: HttpTestingController;

  function monter(numero: string | undefined): void {
    fixture = TestBed.createComponent(Suivi);
    fixture.componentRef.setInput('numero', numero);
    fixture.detectChanges();
  }

  /** Le texte réellement affiché — pas l'état interne. */
  function affiche(): string {
    return (fixture.nativeElement as HTMLElement).textContent ?? '';
  }

  beforeEach(() => {
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

  it("⚠️ s'affiche quand la route ne porte AUCUN numéro", () => {
    // 🎯 LE TEST QUI EMPÊCHE LA PAGE BLANCHE.
    //
    //    `undefined`, et non `''` : c'est ce que pose réellement le routeur,
    //    et c'est ce que les tests précédents ne passaient jamais.
    monter(undefined);

    expect(affiche().trim().length).toBeGreaterThan(0);
    http.expectNone(() => true);
  });

  it('cherche tout seul quand la route porte un numéro', () => {
    // Arriver par un lien partagé doit lancer la recherche : sinon le client
    // voit un champ vide alors qu'il a cliqué sur un lien qui contenait déjà
    // sa réponse.
    monter('GRH-C-0001');

    http.expectOne('/api/expeditions/suivi/GRH-C-0001').flush({
      numeroSuivi: 'GRH-C-0001',
      statut: 'EN_TRANSIT',
      etapes: [],
    });
    fixture.detectChanges();

    expect(affiche()).toContain('GRH-C-0001');
  });
});
