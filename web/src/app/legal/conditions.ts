import { Component } from '@angular/core';
import { RouterLink } from '@angular/router';

/**
 * Les conditions d'utilisation.
 *
 * <h2>Ce qu'elles doivent dire, et que personne ne devine</h2>
 *
 * <p>GARAH prend quatre décisions qui surprennent quelqu'un habitué aux
 * boutiques en ligne, et chacune est écrite en tête de page plutôt qu'enterrée
 * au paragraphe 7 :</p>
 *
 * <pre>
 * D-05   pas de livraison a domicile, un POINT DE RECUPERATION
 * D-06   on paie AVANT l expedition, et jamais en especes
 * D-12   une commande payee ne s annule pas depuis l application
 * D-39   les prix sont FERMES : la negociation est fermee
 * </pre>
 *
 * <p>🎯 <b>Un résumé en tête, et non un texte à lire en entier.</b> Personne ne
 * lit des conditions d'utilisation ; si la seule forme disponible est le texte
 * complet, l'information est <i>publiée</i> mais pas <i>communiquée</i>. Les
 * quatre points du haut sont donc vrais à eux seuls, pas une accroche vers le
 * reste.</p>
 *
 * <p>⚠️ La justification de D-12 est écrite <b>telle qu'elle est</b> : un
 * paiement encaissé engage un remboursement, une marchandise à rapatrier et un
 * commerçant à recréditer. Cacher cette règle derrière une formule juridique la
 * ferait découvrir au pire moment — quand quelqu'un cherche le bouton qui
 * n'existe pas.</p>
 */
@Component({
  selector: 'gb-conditions',
  imports: [RouterLink],
  templateUrl: './conditions.html',
  styleUrl: './legal.scss',
})
export class Conditions {}
