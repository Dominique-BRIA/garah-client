#!/usr/bin/env node
/**
 * Engendre la charte des deux clients depuis `jetons.json`.
 *
 * 🎯 POURQUOI CE SCRIPT EXISTE
 *
 * Angular lit du SCSS, Flutter lit du Dart. Recopier quarante couleurs à la
 * main dans deux langages, c'est garantir qu'elles divergeront — et une teinte
 * qui n'est plus la même d'un client à l'autre ne se remarque qu'en les posant
 * côte à côte, longtemps après.
 *
 * ⚠️ LES FICHIERS PRODUITS NE SE MODIFIENT PAS À LA MAIN. Ils portent un
 *    en-tête qui le dit, et la prochaine exécution les écrase sans prévenir.
 *
 * Aucune dépendance : `node charte/engendrer.mjs` suffit. Ajouter un
 * générateur npm ici obligerait à installer un arbre de paquets pour produire
 * deux fichiers de texte.
 */

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ICI = dirname(fileURLToPath(import.meta.url));
const RACINE = join(ICI, '..');

const jetons = JSON.parse(readFileSync(join(ICI, 'jetons.json'), 'utf8'));

/** Les clés de service ne sont pas des jetons : elles documentent le JSON. */
const estJeton = ([cle]) => !cle.startsWith('_');

const AVERTISSEMENT = [
  'ENGENDRÉ PAR charte/engendrer.mjs — NE PAS MODIFIER À LA MAIN.',
  '',
  'Toute correction se fait dans charte/jetons.json, puis :',
  '    node charte/engendrer.mjs',
  '',
  'Modifier ce fichier directement fait diverger le web et le mobile,',
  'et la prochaine exécution efface le changement sans prévenir.',
];

// -----------------------------------------------------------------------------
// SCSS — pour l'application web
// -----------------------------------------------------------------------------

/** `primaireClair` → `--primaire-clair`. */
const enTiret = (cle) => cle.replace(/[A-Z]/g, (l) => '-' + l.toLowerCase());

function bloc(source, indentation = '  ') {
  return Object.entries(source)
    .filter(estJeton)
    .map(([cle, valeur]) => `${indentation}--${enTiret(cle)}: ${valeur};`)
    .join('\n');
}

function versScss() {
  const lignes = [
    ...AVERTISSEMENT.map((l) => (l ? `// ${l}` : '//')),
    '',
    ':root {',
    '  // La marque et les intentions ne changent pas avec le thème :',
    '  // un danger n\'est pas moins dangereux la nuit.',
    bloc(jetons.constantes),
    bloc(jetons.intentions),
    '',
    '  // Les rayons, en pixels.',
    Object.entries(jetons.rayons)
      .filter(estJeton)
      .map(([cle, px]) => `  --rayon-${enTiret(cle)}: ${px}px;`)
      .join('\n'),
    '',
    `  --police: ${jetons.polices.texte};`,
    `  --police-mono: ${jetons.polices.mono};`,
    '',
    `  // La plus petite cible tactile acceptable.`,
    `  --cible-tactile-min: ${jetons.cibles.tactileMin}px;`,
    '',
    '  // Le thème clair, par défaut.',
    bloc(jetons.clair),
    '}',
    '',
    '@mixin jetons-sombres {',
    bloc(jetons.sombre),
    '}',
    '',
    '// ⚠️ La garde `:not([data-theme="light"])` est indispensable : sans elle,',
    '//    forcer le mode clair sur un système en sombre donne quand même le',
    '//    thème sombre, et la bascule paraît cassée.',
    '@media (prefers-color-scheme: dark) {',
    '  :root:not([data-theme=\'light\']) { @include jetons-sombres; }',
    '}',
    '',
    ':root[data-theme=\'dark\'] { @include jetons-sombres; }',
    '',
  ];

  return lignes.join('\n');
}

// -----------------------------------------------------------------------------
// Dart — pour l'application mobile
// -----------------------------------------------------------------------------

/**
 * Une couleur CSS vers un `Color` Dart.
 *
 * ⚠️ Flutter n'a pas d'équivalent de `rgba()` en littéral : une couleur
 * translucide doit s'écrire en ARGB, l'alpha D'ABORD. Traduire dans le mauvais
 * ordre donne des surfaces opaques qui paraissent seulement « un peu
 * différentes » — le genre d'écart qu'on ne relie jamais à sa cause.
 */
function versCouleurDart(valeur) {
  const hex = valeur.match(/^#([0-9a-f]{6})$/i);
  if (hex) {
    return `Color(0xFF${hex[1].toUpperCase()})`;
  }

  const rgba = valeur.match(
    /^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)$/i,
  );
  if (rgba) {
    const [, r, v, b, a] = rgba;
    const alpha = Math.round((a === undefined ? 1 : Number(a)) * 255);
    const octet = (n) => Number(n).toString(16).padStart(2, '0').toUpperCase();
    return `Color(0x${octet(alpha)}${octet(r)}${octet(v)}${octet(b)})`;
  }

  // Une ombre ou toute valeur composée : Dart ne saurait qu'en faire, et la
  // traduire en silence produirait du code qui ne compile pas.
  return null;
}

function couleursDart(source, prefixe = '') {
  return Object.entries(source)
    .filter(estJeton)
    .map(([cle, valeur]) => {
      const couleur = versCouleurDart(valeur);
      const nom = prefixe + (prefixe ? cle[0].toUpperCase() + cle.slice(1) : cle);
      return couleur
        ? `  static const ${nom} = ${couleur};`
        : `  // ${nom} : « ${valeur} » n'est pas une couleur simple, à porter par le widget.`;
    })
    .join('\n');
}

function versDart() {
  return [
    ...AVERTISSEMENT.map((l) => (l ? `// ${l}` : '//')),
    '',
    "import 'package:flutter/material.dart';",
    '',
    '/// Les jetons de la charte GARAH, partagés avec l’application web.',
    'abstract final class Jetons {',
    couleursDart(jetons.constantes),
    couleursDart(jetons.intentions),
    '',
    '  // --- Thème clair ---',
    couleursDart(jetons.clair, 'clair'),
    '',
    '  // --- Thème sombre ---',
    couleursDart(jetons.sombre, 'sombre'),
    '',
    '  // --- Rayons ---',
    Object.entries(jetons.rayons)
      .filter(estJeton)
      .map(([cle, px]) => `  static const rayon${cle[0].toUpperCase() + cle.slice(1)} = ${px}.0;`)
      .join('\n'),
    '',
    `  static const police = '${jetons.polices.familleFlutter}';`,
    '',
    '  /// En dessous, on rate le bouton une fois sur trois.',
    `  static const cibleTactileMin = ${jetons.cibles.tactileMin}.0;`,
    '}',
    '',
  ].join('\n');
}

// -----------------------------------------------------------------------------

function ecrire(chemin, contenu) {
  const complet = join(RACINE, chemin);
  mkdirSync(dirname(complet), { recursive: true });
  writeFileSync(complet, contenu, 'utf8');
  console.log(`  ${chemin}`);
}

console.log('Charte GARAH — engendrée depuis charte/jetons.json :');
ecrire('web/src/theme/_jetons.scss', versScss());
ecrire('mobile/lib/charte/jetons.dart', versDart());
