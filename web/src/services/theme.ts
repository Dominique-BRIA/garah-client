import { Injectable, computed, signal } from '@angular/core';

export type Theme = 'clair' | 'sombre';

const CLE = 'garah.theme';

/**
 * Le thème de la boutique.
 *
 * <h2>🎯 Le CLAIR est le défaut, pas la préférence du système</h2>
 *
 * <p>Une boutique se regarde comme une vitrine : les photos de produits sont
 * prises sur fond clair, les prix se lisent en noir sur blanc, et un visiteur
 * qui arrive par un lien ne s'attend pas à un fond noir.</p>
 *
 * <p>Suivre {@code prefers-color-scheme} donnait le sombre à tout téléphone
 * réglé ainsi — c'est-à-dire beaucoup — et la boutique n'avait jamais l'air de
 * ce qu'on avait dessiné. Le sombre reste disponible, mais il se
 * <b>choisit</b>.</p>
 *
 * <h2>⚠️ Le thème est posé AVANT qu'Angular ne démarre</h2>
 *
 * <p>Un petit script dans {@code index.html} lit le même stockage et pose
 * {@code data-theme} sur {@code <html>}. Sans lui, la page s'affiche en clair
 * puis bascule en sombre au démarrage d'Angular — un clignotement blanc que
 * tout le monde remarque et que personne ne sait expliquer.</p>
 *
 * <p>Ce service ne fait donc que <b>reprendre</b> ce que le script a posé, et
 * le changer sur demande.</p>
 */
@Injectable({ providedIn: 'root' })
export class ServiceTheme {
  private readonly actuel = signal<Theme>(lire());

  readonly theme = this.actuel.asReadonly();
  readonly sombre = computed(() => this.actuel() === 'sombre');

  basculer(): void {
    this.definir(this.actuel() === 'sombre' ? 'clair' : 'sombre');
  }

  definir(theme: Theme): void {
    this.actuel.set(theme);
    appliquer(theme);

    try {
      localStorage.setItem(CLE, theme);
    } catch {
      // Navigation privée, stockage bloqué : le choix vaut pour cette visite.
      // Faire échouer la bascule serait pire — le bouton ne ferait rien.
    }
  }
}

/**
 * Relit le choix, ou rend le clair.
 *
 * <p>Volontairement <b>sans</b> consultation de {@code prefers-color-scheme} :
 * l'absence de choix veut dire « clair », pas « ce que dit le système ».</p>
 */
function lire(): Theme {
  try {
    return localStorage.getItem(CLE) === 'sombre' ? 'sombre' : 'clair';
  } catch {
    return 'clair';
  }
}

function appliquer(theme: Theme): void {
  // Les valeurs sont celles qu'attend la charte engendrée : `dark` et `light`,
  // pas `sombre` et `clair`. Traduire ici plutôt que dans le SCSS garde le
  // fichier engendré identique pour les trois frontends.
  document.documentElement.setAttribute('data-theme', theme === 'sombre' ? 'dark' : 'light');

  // La barre du navigateur suit : sur un téléphone, un en-tête blanc au-dessus
  // d'une page noire se voit tout de suite.
  document
    .querySelector('meta[name="theme-color"]')
    ?.setAttribute('content', theme === 'sombre' ? '#0c0c14' : '#f8fafc');
}
