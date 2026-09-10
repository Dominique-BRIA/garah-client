import { ChangeDetectionStrategy, Component, booleanAttribute, inject, input } from '@angular/core';

import { ServiceTheme } from '../services/theme';

/**
 * La bascule clair / sombre.
 *
 * <h2>Copiée sur celle du back-office, à dessein</h2>
 *
 * <p>C'est le même bouton que dans <b>garah-admin</b> : un bouton
 * <b>encadré</b>, une icône, et un <b>libellé écrit</b>. Deux applications de
 * la même maison ne réglent pas leur affichage de deux façons différentes.</p>
 *
 * <p>⚠️ Une icône seule ne suffit pas. Un croissant de lune peut se lire
 * « passer en sombre » comme « vous êtes en sombre » : on hésite une fois sur
 * deux, et on clique pour voir. Le libellé dit ce qu'on <b>obtient</b>, pas
 * l'état actuel — « Thème sombre » sur un fond clair.</p>
 *
 * <p>Les tracés viennent de <b>garah-ui</b>, à l'identique (Font Awesome Free
 * 7.3.1, CC BY 4.0). Les recopier plutôt que dépendre de la bibliothèque du
 * back-office : c'est un autre dépôt, et deux icônes ne justifient pas de l'y
 * relier.</p>
 */
@Component({
  selector: 'gb-bascule-theme',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <!-- ⚠️ En mode compact, le libellé visible raccourcit, mais le nom
         annoncé au lecteur d'écran reste complet : c'est lui qui dit ce que
         fait le bouton. -->
    <button type="button" class="reglage" [class.reglage--compacte]="compacte()"
            [attr.aria-label]="theme.sombre() ? 'Thème clair' : 'Thème sombre'"
            (click)="theme.basculer()">
      <!-- L'attribut fill="currentColor" fait prendre à l'icône la couleur du
           texte : elle suit donc le thème sans une seule règle de plus. -->
      <svg [attr.viewBox]="theme.sombre() ? SOLEIL.boite : LUNE.boite"
           fill="currentColor" aria-hidden="true" focusable="false">
        <path [attr.d]="theme.sombre() ? SOLEIL.trace : LUNE.trace" />
      </svg>
      @if (compacte()) {
        @if (theme.sombre()) { Clair } @else { Sombre }
      } @else {
        @if (theme.sombre()) { Thème clair } @else { Thème sombre }
      }
    </button>
  `,
  styles: [
    `
      :host { display: inline-flex; }

      .reglage {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 0.55rem;
        padding: 0.6rem 0.85rem;
        border: 1px solid var(--champ-bordure);
        border-radius: var(--rayon-moyen);
        background: var(--surface-douce);
        color: var(--texte-attenue);
        font: inherit;
        font-size: 0.82rem;
        font-weight: 600;
        white-space: nowrap;
        cursor: pointer;
        transition: all 0.2s ease-in-out;
      }

      /* L'icône se cale sur la taille du texte, comme dans garah-ui : une
         valeur fixe se décalerait dès que le libellé change de corps. */
      svg { width: 1em; height: 1em; flex-shrink: 0; }

      .reglage:focus-visible { outline: 2px solid var(--primaire); outline-offset: 2px; }

      /* Le mode compact : pour l'en-tête large, où la bascule partage la
         rangée avec le panier, la connexion et l'application. Elle y reste un
         réglage — elle ne doit pas peser autant qu'une destination. */
      .reglage--compacte {
        gap: 0.4rem;
        padding: 0.42rem 0.62rem;
        font-size: 0.74rem;
      }

      /* ⚠️ Sur un écran tactile, le survol reste collé après le toucher : le
         bouton garderait son état survolé jusqu'au prochain appui ailleurs. */
      @media (hover: hover) {
        .reglage:hover {
          border-color: var(--primaire-clair);
          color: var(--texte);
        }
      }
    `,
  ],
})
export class BasculeTheme {
  protected readonly theme = inject(ServiceTheme);

  /** Plus petite, libellé raccourci. Pour l'en-tête large. booleanAttribute : posé nu dans le gabarit, l'attribut arrive en chaîne vide, que TypeScript refuse pour un booléen. */
  readonly compacte = input(false, { transform: booleanAttribute });

  // Tracés extraits de Font Awesome Free 7.3.1 — https://fontawesome.com
  // Licence CC BY 4.0 — https://creativecommons.org/licenses/by/4.0/
  protected readonly SOLEIL = {
    boite: '0 0 576 512',
    trace:
      'M288-32c8.4 0 16.3 4.4 20.6 11.7L364.1 72.3 468.9 46c8.2-2 16.9 .4 22.8 6.3S500 67 498 75.1l-26.3 104.7 92.7 55.5c7.2 4.3 11.7 12.2 11.7 20.6s-4.4 16.3-11.7 20.6L471.7 332.1 498 436.8c2 8.2-.4 16.9-6.3 22.8S477 468 468.9 466l-104.7-26.3-55.5 92.7c-4.3 7.2-12.2 11.7-20.6 11.7s-16.3-4.4-20.6-11.7L211.9 439.7 107.2 466c-8.2 2-16.8-.4-22.8-6.3S76 445 78 436.8l26.2-104.7-92.6-55.5C4.4 272.2 0 264.4 0 256s4.4-16.3 11.7-20.6L104.3 179.9 78 75.1c-2-8.2 .3-16.8 6.3-22.8S99 44 107.2 46l104.7 26.2 55.5-92.6 1.8-2.6c4.5-5.7 11.4-9.1 18.8-9.1zm0 144a144 144 0 1 0 0 288 144 144 0 1 0 0-288zm0 240a96 96 0 1 1 0-192 96 96 0 1 1 0 192z',
  };

  protected readonly LUNE = {
    boite: '0 0 512 512',
    trace:
      'M256 0C114.6 0 0 114.6 0 256S114.6 512 256 512c68.8 0 131.3-27.2 177.3-71.4 7.3-7 9.4-17.9 5.3-27.1s-13.7-14.9-23.8-14.1c-4.9 .4-9.8 .6-14.8 .6-101.6 0-184-82.4-184-184 0-72.1 41.5-134.6 102.1-164.8 9.1-4.5 14.3-14.3 13.1-24.4S322.6 8.5 312.7 6.3C294.4 2.2 275.4 0 256 0z',
  };
}
