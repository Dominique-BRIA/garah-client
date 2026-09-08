import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../charte/jetons.dart';
import '../charte/theme.dart';
import '../services/services.dart';
import '../widgets/communs.dart';

/// Une étape du parcours, telle que le serveur la NOMME.
///
/// ⚠️ Le serveur résout les noms de lieux lui-même. Une version précédente du
///    suivi rendait des identifiants, et l'écran affichait « lieu 12 » — ce
///    qui n'a jamais conduit personne quelque part.
class _Etape {
  const _Etape({
    required this.type,
    required this.lieu,
    required this.ville,
    required this.observation,
    required this.dateHeure,
  });

  final String type;

  /// Nul si le lieu a été supprimé. L'étape reste affichée : elle décrit un
  /// mouvement physique qui a bien eu lieu.
  final String? lieu;

  /// La ville suffit souvent à situer sans connaître le nom de l'agence.
  final String? ville;
  final String? observation;
  final DateTime? dateHeure;

  factory _Etape.de(Map<String, dynamic> j) => _Etape(
    type: (j['type'] as String?) ?? '',
    lieu: j['lieu'] as String?,
    ville: j['ville'] as String?,
    observation: j['observation'] as String?,
    dateHeure: DateTime.tryParse((j['dateHeure'] as String?) ?? ''),
  );

  /// « Agence Bangui-Centre · Bangui », ou l'un des deux, ou rien.
  String? get ou {
    final morceaux = [lieu, ville].where((m) => m != null && m.isNotEmpty);
    return morceaux.isEmpty ? null : morceaux.join(' · ');
  }
}

const _libellesEtape = <String, String>{
  'DEPART': 'Parti',
  'ARRIVEE': 'Arrivé',
  'ANOMALIE': 'Incident signalé',
  'REMISE': 'Remis',
};

/// Le suivi public d'un colis.
///
/// ## 🎯 Sans compte, et c'est le sujet
///
/// Un client qui attend un colis n'ouvre pas la boutique pour acheter. Le
/// numéro de suivi se **partage** — on l'envoie à celui qui viendra retirer —
/// et il n'apprend rien d'autre que le trajet.
///
/// ## ⚠️ Le code de retrait n'est JAMAIS ici
///
/// Cet écran est ouvert à qui connaît le numéro. Y mettre le code, qui suffit
/// à emporter la marchandise, reviendrait à donner la clé avec l'adresse.
class EcranSuivi extends StatefulWidget {
  const EcranSuivi({super.key});

  @override
  State<EcranSuivi> createState() => _EcranSuiviState();
}

class _EcranSuiviState extends State<EcranSuivi> {
  final _numero = TextEditingController();

  bool _recherche = false;
  String? _erreur;
  String? _statut;
  String? _numeroTrouve;
  List<_Etape> _etapes = const [];

  @override
  void dispose() {
    _numero.dispose();
    super.dispose();
  }

  Future<void> _chercher() async {
    final numero = _numero.text.trim();
    if (numero.isEmpty || _recherche) return;

    setState(() {
      _recherche = true;
      _erreur = null;
      _etapes = const [];
    });

    try {
      final vue =
          await Services.de(context).api.obtenir(
                '/api/expeditions/suivi/${Uri.encodeComponent(numero)}',
              )
              as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _statut = vue['statut'] as String?;
        _numeroTrouve = vue['numeroSuivi'] as String?;
        _etapes = (vue['etapes'] as List<dynamic>? ?? [])
            .map((e) => _Etape.de(e as Map<String, dynamic>))
            .toList();
        _recherche = false;
      });
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() {
        _recherche = false;
        _erreur = e.statut == 404
            // Un numéro inconnu n'est pas une panne : c'est presque toujours
            // une faute de recopie. Le dire évite de conclure que le colis est
            // perdu.
            ? 'Aucun colis ne porte ce numéro. Vérifiez la saisie.'
            : e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suivre un colis')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Entrez le numéro de suivi qui vous a été communiqué. '
            'Aucun compte n’est nécessaire.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: context.texteAttenue,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _numero,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            onSubmitted: (_) => _chercher(),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Numéro de suivi'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _numero.text.trim().isEmpty || _recherche
                ? null
                : _chercher,
            child: Text(_recherche ? 'Recherche…' : 'Suivre'),
          ),
          const SizedBox(height: 20),
          if (_erreur != null) Alerte(message: _erreur!),
          if (_etapes.isNotEmpty || _statut != null) _leParcours(context),
        ],
      ),
    );
  }

  Widget _leParcours(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_statut != null || _numeroTrouve != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: Jetons.marque.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_statut != null)
                  Text(
                    _statut!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (_numeroTrouve != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Colis $_numeroTrouve',
                    style: TextStyle(fontSize: 13, color: context.texteAttenue),
                  ),
                ],
              ],
            ),
          ),
        const Libelle('Parcours'),
        const SizedBox(height: 10),
        // Le plus RÉCENT en haut : on ouvre ce suivi pour savoir où en est le
        // colis maintenant, pas pour relire son histoire depuis le début.
        for (final e in _etapes.reversed) _uneEtape(context, e),
      ],
    );
  }

  Widget _uneEtape(BuildContext context, _Etape e) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 9,
          height: 9,
          margin: const EdgeInsets.only(top: 5, right: 12),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Jetons.marque,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _libellesEtape[e.type] ?? e.type,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (e.ou != null)
                Text(
                  e.ou!,
                  style: TextStyle(fontSize: 13, color: context.texteAttenue),
                ),
              if (e.observation != null && e.observation!.isNotEmpty)
                Text(
                  e.observation!,
                  style: TextStyle(fontSize: 12.5, color: context.texteAttenue),
                ),
              if (e.dateHeure != null)
                Text(
                  _quand(e.dateHeure!),
                  style: TextStyle(fontSize: 11.5, color: context.texteAttenue),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  static String _quand(DateTime d) {
    final l = d.toLocal();
    String deuxChiffres(int n) => n.toString().padLeft(2, '0');
    return '${deuxChiffres(l.day)}/${deuxChiffres(l.month)}/${l.year} '
        'à ${deuxChiffres(l.hour)}:${deuxChiffres(l.minute)}';
  }
}
