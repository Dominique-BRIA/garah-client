# GARAH — application client

La boutique, côté client. Deux frontends pour une seule API :

| Dossier | Quoi | Construit |
|---|---|---|
| `web/` | Angular 20, la vitrine ouverte depuis un lien | localement et par Vercel |
| `mobile/` | Flutter, l'application installée | **par GitHub Actions**, jamais en local |
| `charte/` | Les jetons de charte, source unique | un script Node, sans dépendance |

Le back-office et l'API vivent dans le dépôt **`garah`**, à part. Ici, rien
d'administratif : c'est la règle « deux publics, deux routes » poussée jusqu'à
deux dépôts.

---

## Pourquoi deux clients, et ce qu'ils partagent

L'axe Douala → Bangui se parcourt au téléphone. Mais un client découvre GARAH
par un lien reçu sur WhatsApp, et un lien ne s'installe pas : le **web** est la
porte d'entrée, l'**application** est pour ceux qui reviennent.

🎯 **Ce qui se partage entre Flutter et Angular est très petit**, et c'est
volontaire. Un widget Dart et un composant Angular n'ont rien en commun ;
vouloir les rapprocher coûterait plus cher que de les écrire deux fois. Il
reste trois choses :

| Quoi | Comment | Pourquoi pas autrement |
|---|---|---|
| **Les jetons de charte** | `charte/jetons.json`, d'où l'on engendre le SCSS et le Dart | Une couleur qui diverge entre les deux clients se voit tout de suite, et se corrige à deux endroits pour toujours. |
| **Le vocabulaire métier** | Statuts, libellés, transitions — recopiés dans chaque client | Déjà dupliqué du serveur vers le back-office, **sciemment** : le serveur reste seul juge, la copie ne sert qu'à ne pas proposer un geste qui échouera. |
| **Le contrat d'API** | Les DTO, écrits à la main des deux côtés | L'engendrer depuis Spring serait un chantier à lui seul, pour une poignée de records. |

⚠️ **Ce qu'on ne fait PAS : tirer `garah-ui` ici.** Cette librairie est faite
pour le back-office — tableaux, panneaux latéraux, pagination — dont la
boutique n'utilise presque rien. Ce qu'elle veut, c'est la charte et les
icônes, qui sont des **données**, pas du code Angular.

---

## Ce que l'API impose

Ces règles viennent du serveur. Une interface qui les ignore produit un écran
que le backend refusera.

| Règle | Conséquence à l'écran |
|---|---|
| **Pas de livraison à domicile** (D-05) | Il n'existe aucune table `adresse`. Jamais de formulaire d'adresse : le client choisit un **point de récupération**, et ce choix change le total. |
| **Commander exige un compte** (D-07) | La vitrine est ouverte, le paiement non. La connexion arrive au moment de commander, pas à l'entrée. |
| **On ne s'annule pas soi-même après paiement** (D-12) | La réclamation est la **contrepartie** de cette règle, pas un accessoire. |
| **Les montants sont figés à l'achat** (D-10, D-11) | Une commande passée ne se relit jamais dans le catalogue. |

Le détail des écrans, avec l'intention de chacun, est dans
`garah/docs/application-client.md`.

---

## Le panier vit dans le navigateur

Un visiteur remplit son panier **sans compte**, puis se connecte pour
commander. `POST /api/panier/fusion` reprend le panier local en un seul appel.

🎯 **La fusion garde la plus grande des deux quantités, jamais la somme.** Sur
une connexion instable une requête est réémise, et une fusion additive rejouée
**double les quantités** — ce que le client ne découvre qu'à la facture.

La route rend **les écarts**, pas seulement le panier : article retiré du
catalogue, quantité déjà plus grande ailleurs. Un panier qui change tout seul
juste avant de payer fait perdre la confiance ; le dire est le but de la route.

---

## Démarrer

```bash
# La charte, à relancer après toute modification de charte/jetons.json
node charte/engendrer.mjs

# Le web
cd web && npm install && npm start
```

⚠️ **Flutter ne se construit pas en local** : le `.apk` sort de GitHub Actions.
Les outils de test Flutter, eux, tournent bien en local.
