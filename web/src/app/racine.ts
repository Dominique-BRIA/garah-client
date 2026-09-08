import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';

import { Marque } from './marque';

import { PanierLocal } from '../services/panier-local';
import { ServiceSession } from '../services/session';
import { ServiceTheme } from '../services/theme';

/**
 * La coque de la boutique.
 *
 * <h2>Deux navigations, une seule application</h2>
 *
 * <p>🎯 <b>C'est la version WEB.</b> Elle doit être bonne au téléphone
 * <b>comme</b> sur un écran large — l'application installée, elle, sera celle
 * en Flutter.</p>
 *
 * <p>Deux barres coexistent donc, et une seule s'affiche à la fois :</p>
 *
 * <ul>
 *   <li>en dessous de 900 px, une barre <b>en bas</b> — le pouce y arrive,
 *       c'est la convention d'une application mobile ;</li>
 *   <li>au-dessus, un <b>en-tête</b> horizontal — sur un écran large, une
 *       barre collée en bas est loin du regard et loin de la souris.</li>
 * </ul>
 *
 * <p>⚠️ Elles sont écrites <b>deux fois</b> plutôt que déplacées par CSS. Une
 * seule barre repositionnée en média-requête garderait l'ordre des éléments
 * d'un téléphone sur un bureau, et l'ordre est justement ce qui change : au
 * téléphone les quatre destinations sont égales, sur un écran large le nom de
 * la boutique passe devant et la recherche prend la place.</p>
 *
 * <p>La coque ne porte <b>aucun garde</b>, contrairement à celle du
 * back-office : la vitrine est ouverte, et le garde se pose écran par écran.</p>
 */
@Component({
  selector: 'gb-racine',
  imports: [RouterOutlet, RouterLink, RouterLinkActive, FormsModule, Marque],
  templateUrl: './racine.html',
  styleUrl: './racine.scss',
})
export class Racine {
  private readonly routeur = inject(Router);

  protected readonly panier = inject(PanierLocal);
  protected readonly session = inject(ServiceSession);
  protected readonly theme = inject(ServiceTheme);

  protected readonly saisie = signal('');

  /**
   * La recherche depuis n'importe quelle page.
   *
   * <p>🎯 Sur un écran large, on cherche depuis l'en-tête, où qu'on soit. La
   * boutique n'offrait ce champ que sur l'accueil et le catalogue : depuis une
   * fiche produit, il fallait revenir en arrière pour chercher autre chose.</p>
   *
   * <p>Le terme part dans l'URL, et non dans un service : une recherche se
   * partage, se met en favori et survit à un rechargement.</p>
   */
  protected chercher(): void {
    const terme = this.saisie().trim();
    this.routeur.navigate(['/catalogue'], {
      queryParams: terme ? { recherche: terme } : {},
    });
  }
}
