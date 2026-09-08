import { Component, computed, inject } from '@angular/core';
import { RouterLink } from '@angular/router';

import { montantLisible } from '../../modeles/catalogue';
import { PanierLocal } from '../../services/panier-local';
import { ServiceSession } from '../../services/session';

/**
 * Le panier.
 *
 * <p>⚠️ Il est PUBLIC, et ce n'est pas un oubli : un visiteur remplit son
 * panier sans compte. Exiger la connexion pour le CONSULTER ferait fuir au
 * premier « Ajouter ».</p>
 *
 * <p>Le total affiché est <b>indicatif</b> : il ignore les paliers de quantité
 * et les frais d'acheminement, que seul le serveur applique. Le presenter
 * comme un prix a payer mentirait.</p>
 */
@Component({
  selector: 'gb-panier',
  imports: [RouterLink],
  templateUrl: './panier.html',
  styleUrl: './panier.scss',
})
export class Panier {
  protected readonly panier = inject(PanierLocal);
  protected readonly session = inject(ServiceSession);

  protected readonly vide = computed(() => this.panier.lignes().length === 0);

  protected montant(valeur: number): string {
    return montantLisible(valeur);
  }
}
