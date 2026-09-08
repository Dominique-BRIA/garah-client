import { Component, input } from '@angular/core';

/**
 * La marque GARAH : la calebasse, ramenée à sa panse et à son anse.
 *
 * <h2>⚠️ Le tracé vient de `garah-ui`, il ne s'invente pas</h2>
 *
 * <p>Il est recopié à l'identique depuis {@code garah-ui/src/lib/marque}. Une
 * marque redessinée « à peu près » cesse d'être une marque — et personne ne
 * s'en aperçoit avant de poser les deux applications côte à côte.</p>
 *
 * <p>C'est la <b>troisième</b> copie du même tracé (back-office, boutique,
 * mobile à venir), et c'est le prix de trois frontends dans deux dépôts. Le
 * jour où la forme change, elle change ici aussi.</p>
 *
 * <h2>La couleur vient du jeton, jamais du fichier</h2>
 *
 * <p>{@code var(--marque)} — la seule valeur de la charte qui ne change ni
 * avec le thème, ni avec l'application. Elle est choisie pour tenir sur le
 * fond clair comme sur le sombre.</p>
 *
 * <p>Le variant <b>mono</b> passe en {@code currentColor} : il sert là où la
 * marque doit prendre la couleur de son contexte — un bouton, une ligne de
 * texte — et non imposer son vert.</p>
 */
@Component({
  selector: 'gb-marque',
  template: `
    <svg viewBox="0 0 48 48" [class.mono]="mono()" role="img" aria-label="GARAH">
      <title>GARAH</title>
      <path class="anse" d="M10 25A15 15 0 0 1 37.29 16.4" />
      <path class="panse" d="M10 25A15 15 0 0 0 40 25Z" />
    </svg>
  `,
  styles: `
    :host {
      display: inline-flex;
      /* La taille est portée par l'hôte, pas par le <svg> : c'est l'hôte qui
         occupe la place dans la mise en page. */
      width: 1.75rem;
      height: 1.75rem;
    }

    svg { width: 100%; height: 100%; display: block; }

    .anse {
      fill: none;
      stroke: var(--marque);
      stroke-width: 5;
      stroke-linecap: butt;
    }

    .panse { fill: var(--marque); }

    svg.mono .anse { stroke: currentColor; }
    svg.mono .panse { fill: currentColor; }
  `,
})
export class Marque {
  /** Prend la couleur du contexte au lieu du vert de la marque. */
  readonly mono = input(false);
}
