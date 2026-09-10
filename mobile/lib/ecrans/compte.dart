import 'package:flutter/material.dart';

import '../charte/theme.dart';
import '../services/services.dart';
import 'connexion.dart';
import 'inscription.dart';
import 'favoris.dart';
import 'mes_commandes.dart';
import 'sav.dart';
import 'suivi.dart';

/// L'espace personnel.
///
/// ## ⚠️ Il attend la reprise de session avant de se dessiner
///
/// Sans cela, l'écran affiche « Se connecter » une demi-seconde à chaque
/// ouverture, sur un compte qui est en fait connecté — et on appuie dessus.
///
/// ## 🎯 Des portes, et aucune liste
///
/// Les commandes s'affichaient ICI, entre l'en-tête et les autres rubriques.
/// Vingt cartes empilées repoussaient « Ma liste » et « Mes discussions » tout
/// en bas, hors de l'écran : on les croyait absentes. Chaque rubrique a
/// maintenant son écran, et celui-ci n'en montre que les portes — comme
/// l'écran « Mon compte » du web.
class EcranCompte extends StatelessWidget {
  const EcranCompte({super.key});

  @override
  Widget build(BuildContext context) {
    final services = Services.de(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mon compte')),
      body: ListenableBuilder(
        listenable: services.session,
        builder: (context, _) {
          if (services.session.enCoursDeReprise) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!services.session.connecte) {
            return _horsSession(context);
          }

          return _espace(context, services);
        },
      ),
    );
  }

  Widget _horsSession(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
    children: [
      const Text(
        'Suivez vos commandes',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(
        'Votre compte garde vos commandes, vos retours et le code qui vous '
        'permet de retirer votre marchandise.',
        style: TextStyle(
          fontSize: 13.5,
          height: 1.5,
          color: context.texteAttenue,
        ),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const EcranConnexion())),
        child: const Text('Se connecter'),
      ),
      const SizedBox(height: 10),
      // 🎯 Sans ce bouton, l'écran d'inscription n'existait pas : rien n'y
      //    menait, et un client sans compte n'avait aucun moyen d'en créer un
      //    depuis le téléphone.
      OutlinedButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const EcranInscription())),
        child: const Text('Créer un compte'),
      ),
      const SizedBox(height: 24),
      const Divider(),
      const SizedBox(height: 16),
      // La seule chose utile SANS compte : elle a sa place ici, où
      // quelqu'un qui attend un colis viendra chercher.
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.local_shipping_outlined),
        title: const Text('Suivre un colis'),
        subtitle: const Text('Sans compte, avec votre numéro de suivi.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const EcranSuivi())),
      ),
    ],
  );

  Widget _espace(BuildContext context, Services services) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    services.session.nom ?? 'Mon compte',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (services.session.email != null)
                    Text(
                      services.session.email!,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.texteAttenue,
                      ),
                    ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: services.session.deconnecter,
              child: const Text('Se déconnecter'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Divider(),
        // ⚠️ « Mes commandes » est une PORTE, plus une liste : c'est la liste
        //    elle-même qui saturait cet écran. Elle ouvre son propre écran,
        //    comme « Ma liste » juste en dessous.
        _entree(
          context,
          icone: Icons.receipt_long_outlined,
          titre: 'Mes commandes',
          ecran: () => const EcranMesCommandes(),
        ),
        _entree(
          context,
          icone: Icons.favorite_border,
          titre: 'Ma liste',
          ecran: () => const EcranFavoris(),
        ),
        // Aussi un onglet de la barre du bas. Le garder ici n'est pas un
        // doublon inutile : c'est ici qu'on cherche « tout ce qui est à moi ».
        _entree(
          context,
          icone: Icons.forum_outlined,
          titre: 'Mes discussions',
          ecran: () => const EcranDiscussions(),
        ),
        _entree(
          context,
          icone: Icons.assignment_return_outlined,
          titre: 'Réclamations et retours',
          ecran: () => const EcranSav(),
        ),
        _entree(
          context,
          icone: Icons.local_shipping_outlined,
          titre: 'Suivre un colis',
          ecran: () => const EcranSuivi(),
        ),
      ],
    );
  }

  /// Une entrée de l'espace personnel.
  ///
  /// Écrite une fois : cinq ListTile recopiés divergeraient au premier
  /// ajustement — l'un garderait sa flèche, l'autre non.
  Widget _entree(
    BuildContext context, {
    required IconData icone,
    required String titre,
    required Widget Function() ecran,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icone),
    title: Text(titre, style: const TextStyle(fontSize: 14.5)),
    trailing: const Icon(Icons.chevron_right),
    onTap: () =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ecran())),
  );
}
