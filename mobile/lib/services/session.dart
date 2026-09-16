import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/client_api.dart';
import 'google.dart';
import 'panier_local.dart';

/// Qui est connecté, et pour combien de temps.
///
/// ## ⚠️ Le jeton de RAFRAÎCHISSEMENT seul est conservé
///
/// Pas le jeton d'accès : il vaut quelques minutes, et le stocker n'éviterait
/// rien tout en laissant traîner un laissez-passer valide dans les
/// préférences du téléphone. Au démarrage on rafraîchit — un aller-retour, et
/// on est connecté.
///
/// ## Le panier local fusionne à la connexion
///
/// C'est le moment, et le seul : avant, il n'y a pas de compte où fusionner ;
/// après, on aurait déjà montré un panier serveur incomplet.
class ServiceSession extends ChangeNotifier {
  ServiceSession(this._api, this._panier) {
    _api.surSessionPerdue = () {
      _utilisateur = null;
      _oublierLeCookie();
      notifyListeners();
    };
  }

  static const _cleRafraichissement = 'garah.rafraichissement';

  final ClientApi _api;
  final PanierLocal _panier;

  /// Posé par `main` après construction.
  ///
  /// ⚠️ Une propriété, et non un paramètre du constructeur : `ServiceGoogle`
  /// a besoin de `ClientApi`, comme cette classe. Les passer l'un à l'autre
  /// dans les constructeurs ferait un ordre d'initialisation fragile pour un
  /// lien dont la session n'a besoin qu'à la déconnexion.
  ///
  /// Nullable : les tests construisent une session sans Google, et
  /// `deconnecter()` doit marcher sans lui.
  ServiceGoogle? google;

  ({int id, String nom, String email})? _utilisateur;

  /// Vrai pendant la tentative de reprise au démarrage.
  ///
  /// L'écran doit l'attendre : sans cela, on affiche « Se connecter » une
  /// demi-seconde à chaque ouverture, sur un compte qui est en fait connecté.
  bool _reprise = true;

  bool get connecte => _utilisateur != null;
  bool get enCoursDeReprise => _reprise;
  String? get nom => _utilisateur?.nom;
  String? get email => _utilisateur?.email;
  int? get utilisateurId => _utilisateur?.id;

  /// Tente de reprendre la session au lancement.
  Future<void> reprendre() async {
    _reprise = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final cookie = prefs.getString(_cleRafraichissement);
      if (cookie != null) {
        _api.poserJeton(null, rafraichissement: cookie);
        final moi = await _api.obtenir('/api/profil');
        _poser(moi as Map<String, dynamic>);
      }
    } catch (_) {
      // Session expirée ou hors réseau : on ouvre déconnecté. C'est le bon
      // défaut — la vitrine est ouverte à tous.
      _utilisateur = null;
    } finally {
      _reprise = false;
      notifyListeners();
    }
  }

  Future<void> connecter(String email, String motDePasse) async {
    await _ouvrir(await _api.connecter(email, motDePasse), secours: email);
  }

  /// « Continuer avec Google ».
  ///
  /// Le jeton vient de `ServiceGoogle`, le serveur le vérifie et décide seul
  /// (D-51). Une fois la réponse reçue, il ne se passe rien de particulier :
  /// elle a **exactement** la même forme que celle du mot de passe, donc elle
  /// emprunte le même chemin.
  Future<void> connecterAvecGoogle(String jetonGoogle) async {
    await _ouvrir(await _api.connecterAvecGoogle(jetonGoogle), secours: '');
  }

  /// Ce qui suit TOUTE connexion réussie, quelle qu'en soit la porte.
  ///
  /// ⚠️ **Extrait de [connecter] sans rien changer**, pour que la connexion
  /// Google ne puisse pas en diverger. Le défaut décrit ci-dessous a coûté une
  /// session de diagnostic ; le laisser en double, c'eût été accepter de le
  /// reproduire dans la moitié des chemins le jour d'une correction.
  ///
  /// `secours` est ce qu'on affiche si le serveur ne renvoyait ni nom ni
  /// adresse : l'adresse saisie pour le mot de passe, rien pour Google — où
  /// l'utilisateur n'a rien tapé.
  Future<void> _ouvrir(
    Map<String, dynamic> reponse, {
    required String secours,
  }) async {
    // ⚠️ Le compte est IMBRIQUE dans la reponse : `utilisateur: { id, nom,
    //    ... }`. Ces trois champs etaient lus a la racine — `utilisateurId`,
    //    `nom`, `email` — ou ils n'ont jamais existe.
    //
    //    Le cast `as num` sur un `null` levait alors une TypeError. Elle
    //    n'est PAS une ErreurApi : l'ecran de connexion ne la rattrapait pas,
    //    son indicateur d'envoi restait arme, et le bouton tournait
    //    indefiniment SANS message. C'est le symptome qu'on voyait.
    final compte = reponse['utilisateur'] as Map<String, dynamic>?;
    if (compte == null) {
      throw ErreurApi(0, 'Reponse inattendue du serveur.');
    }

    _utilisateur = (
      id: (compte['id'] as num).toInt(),
      nom: (compte['nom'] as String?) ?? secours,
      email: (compte['email'] as String?) ?? secours,
    );

    await _retenirLeCookie();
    // ⚠️ Son echec ne doit PAS faire echouer la connexion. On vient de
    //    saisir un mot de passe : renvoyer sur l ecran de connexion parce
    //    qu un panier n a pas suivi ferait recommencer pour rien. Il
    //    repartira au moment de commander, ou la synchronisation est
    //    refaite.
    try {
      await synchroniserLePanier();
    } catch (_) {
      // Volontairement avale : voir ci-dessus.
    }
    notifyListeners();
  }

  Future<void> deconnecter() async {
    try {
      await _api.poster('/api/auth/deconnexion');
    } catch (_) {
      // Le serveur n'a pas répondu : on se déconnecte quand même ici. Rester
      // connecté à l'écran après un clic sur « Se déconnecter » est le pire
      // des deux mondes, surtout sur un téléphone partagé.
    }
    _api.oublier();

    // ⚠️ Oublier AUSSI le compte choisi chez Google.
    //
    //    Sans cela, Google reproposerait silencieusement le même compte au
    //    prochain clic : la personne appuierait sur « Se déconnecter », puis
    //    sur « Continuer avec Google », et se retrouverait sur le compte
    //    qu'elle voulait quitter. Changer de compte deviendrait impossible
    //    depuis l'application — un défaut vécu comme « je ne peux pas me
    //    déconnecter », et qui ne se voit qu'avec deux comptes sur le même
    //    téléphone.
    await google?.oublier();

    _utilisateur = null;
    await _oublierLeCookie();
    notifyListeners();
  }

  /// Pousse le panier du téléphone vers le serveur.
  ///
  /// ## 🎯 « Votre panier est vide » sur un panier qui ne l'était pas
  ///
  /// L'écran de commande lit `/api/panier` — le panier du SERVEUR, seul juge
  /// du stock et du prix. Le panier local, lui, ne partait qu'à la CONNEXION.
  ///
  /// Quelqu'un déjà connecté qui ajoutait un article ne l'envoyait donc nulle
  /// part : le panier affichait « 1 article, 2 000 FCFA », et l'écran suivant
  /// annonçait un panier vide. Les deux écrans disaient vrai — ils ne
  /// regardaient pas le même panier.
  ///
  /// ## ⚠️ NON DESTRUCTIF, contrairement à ce qui se faisait
  ///
  /// La fusion vidait le panier local. C'était tenable quand elle n'arrivait
  /// qu'une fois, à la connexion ; appelée avant chaque commande, elle
  /// viderait l'écran du panier dès qu'on revient en arrière depuis la
  /// commande.
  ///
  /// Le local reste donc ce qu'on affiche, le serveur ce qui fait foi au
  /// moment de payer. Le panier local est vidé quand la commande est
  /// RÉELLEMENT passée, et pas avant.
  ///
  /// ## ⚠️ La rejouer est sans danger
  ///
  /// `/api/panier/fusion` garde le PLUS GRAND des deux côtés, jamais la somme.
  /// La rejouer dix fois donne le même panier — c'est ce qui permet de
  /// l'appeler à chaque passage en commande sans multiplier les quantités.
  Future<void> synchroniserLePanier() async {
    final lignes = _panier.pourFusion();
    if (lignes.isEmpty) return;
    await _api.poster('/api/panier/fusion', {'lignes': lignes});
  }

  void _poser(Map<String, dynamic> profil) {
    _utilisateur = (
      id: (profil['id'] as num).toInt(),
      nom: (profil['nom'] as String?) ?? '',
      email: (profil['email'] as String?) ?? '',
    );
  }

  Future<void> _retenirLeCookie() async {
    final cookie = _api.jetonRafraichissement;
    if (cookie == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cleRafraichissement, cookie);
    } catch (_) {
      // Session valable jusqu'à la fermeture de l'application. Sans
      // conséquence immédiate.
    }
  }

  Future<void> _oublierLeCookie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cleRafraichissement);
    } catch (_) {
      // Rien à faire de plus.
    }
  }
}
