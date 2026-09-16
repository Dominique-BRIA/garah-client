import { Component } from '@angular/core';

/**
 * Les règles de confidentialité.
 *
 * <h2>Pourquoi cette page existe, et pourquoi elle est écrite ainsi</h2>
 *
 * <p>Google l'exige pour publier une application OAuth « Externe » — sans
 * elle, seuls des comptes inscrits comme testeurs peuvent se connecter. Mais
 * la contrainte n'est pas la raison : quelqu'un qui confie son numéro et son
 * argent à une boutique inconnue a le droit de savoir ce qu'elle en fait.</p>
 *
 * <p>⚠️ <b>Le contenu décrit le schéma RÉEL</b>, table par table : les champs
 * de {@code utilisateur}, la rétention de 90 jours de {@code vue_produit}
 * (D-15), l'absence de table {@code adresse} (D-05), le fait qu'aucune
 * coordonnée bancaire ne transite par GARAH (D-06).</p>
 *
 * <p>🎯 <b>Une politique recopiée d'un modèle serait pire qu'absente.</b> Elle
 * annoncerait des traitements qui n'existent pas — et tairait ceux qui
 * existent, comme le journal des événements de sécurité ou le score de risque.
 * Publier un texte faux, c'est prendre un engagement qu'on ne tient pas.</p>
 *
 * <p>📌 <b>À relire à chaque migration qui touche une donnée personnelle.</b>
 * Une colonne ajoutée sans que cette page bouge la rend fausse le jour même,
 * et silencieusement.</p>
 */
@Component({
  selector: 'gb-confidentialite',
  templateUrl: './confidentialite.html',
  styleUrl: './legal.scss',
})
export class Confidentialite {}
