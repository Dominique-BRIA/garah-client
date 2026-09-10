// =============================================================================
//  Inscrit le POIDS RÉEL des APK dans le code de la page de téléchargement.
// =============================================================================
//
//  Usage, depuis web/ :
//      node outils/poids-apk.mjs
//
//  🎯 POURQUOI CE SCRIPT EXISTE
//
//  La page annonce le poids du fichier sur le bouton — et elle doit le faire :
//  dix-huit mégaoctets sur un forfait qui se compte, ce n'est pas un détail.
//
//  Mais ce poids était écrit À LA MAIN dans appareil.ts. À la première mise à
//  jour des APK, la page continuait d'annoncer l'ancien chiffre. Personne ne
//  s'en aperçoit : le téléchargement marche, il coûte simplement autre chose
//  que ce qui était promis.
//
//  ⚠️ À LANCER À CHAQUE FOIS QU'ON REMPLACE LES APK. Le script échoue
//     bruyamment si un fichier manque, plutôt que de laisser un poids périmé.
//
// =============================================================================

import { readFileSync, writeFileSync, statSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const ICI = dirname(fileURLToPath(import.meta.url));
const DOSSIER_APK = join(ICI, '..', 'public', 'apk');
const SOURCE = join(ICI, '..', 'src', 'services', 'appareil.ts');

let code = readFileSync(SOURCE, 'utf8');
const lignes = [];
let manquant = false;

// On relit les fichiers déclarés DANS le code : la liste ne se recopie pas
// ici, sinon les deux divergeraient — ce qu'on cherche justement à éviter.
for (const [, fichier] of code.matchAll(/fichier: '([^']+)'/g)) {
  const chemin = join(DOSSIER_APK, fichier);

  if (!existsSync(chemin)) {
    lignes.push(`  !! ${fichier} : ABSENT de public/apk/`);
    manquant = true;
    continue;
  }

  // Un chiffre après la virgule : au-delà, on donne une précision qui ne veut
  // rien dire à quelqu'un qui regarde son forfait.
  const mo = Math.round((statSync(chemin).size / 1048576) * 10) / 10;

  // On remplace le poidsMo qui SUIT ce fichier-là, et lui seul.
  const bloc = new RegExp(`(fichier: '${fichier.replace('.', '\\.')}'[\\s\\S]*?poidsMo: )([0-9.]+)`);
  const avant = code.match(bloc);
  if (!avant) {
    lignes.push(`  !! ${fichier} : poidsMo introuvable dans appareil.ts`);
    manquant = true;
    continue;
  }

  const ancien = Number(avant[2]);
  code = code.replace(bloc, `$1${mo}`);
  lignes.push(
    `  ${fichier.padEnd(26)} ${String(mo).padStart(5)} Mo` +
      (ancien === mo ? '   (inchangé)' : `   <- etait ${ancien} Mo`),
  );
}

if (manquant) {
  console.error('Poids des APK — ECHEC :\n' + lignes.join('\n'));
  process.exit(1);
}

writeFileSync(SOURCE, code, 'utf8');
console.log('Poids des APK, releves dans public/apk/ :\n' + lignes.join('\n'));
