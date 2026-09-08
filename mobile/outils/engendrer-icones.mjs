/*
 * Engendre les icônes de lancement Android à partir de la calebasse.
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * 🎯 POURQUOI UN SCRIPT PLUTÔT QUE CINQ PNG DÉPOSÉS À LA MAIN
 * ═══════════════════════════════════════════════════════════════════════════
 * Cinq fichiers binaires dans un dépôt, personne ne sait plus d'où ils
 * viennent ni comment les refaire. Le jour où la marque bouge d'un cheveu, on
 * en corrige trois sur cinq et deux densités gardent l'ancien logo — un défaut
 * qui ne se voit que sur certains téléphones.
 *
 * Ici, la source est le TRACÉ, et le tracé est le même que partout ailleurs.
 *
 *     node outils/engendrer-icones.mjs
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * ⚠️ AUCUNE DÉPENDANCE
 * ═══════════════════════════════════════════════════════════════════════════
 * Ni `sharp`, ni `canvas`, ni ImageMagick : sur une connexion comptée, ajouter
 * une bibliothèque de rendu d'images pour dessiner deux arcs de cercle serait
 * hors de proportion. Le PNG est écrit à la main — `zlib` est dans Node.
 *
 * La forme s'y prête : la calebasse EST deux arcs du MÊME cercle, de centre
 * (25, 25) et de rayon 15 dans le repère 48×48 du logo.
 *
 *   la panse   le demi-disque du BAS, plein
 *   l'anse     un arc du HAUT, tracé, épaisseur 5
 */

import { deflateSync } from 'node:zlib';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ICI = dirname(fileURLToPath(import.meta.url));
const RES = join(ICI, '..', 'android', 'app', 'src', 'main', 'res');

// --- La charte ---------------------------------------------------------------
// ⚠️ Recopiées de charte/jetons.json : ce script tourne hors de l'application,
//    il n'a pas accès aux jetons engendrés. Elles doivent y rester égales.
const VERT = [0x12, 0xa5, 0x94]; // constantes.marque
const FOND = [0xf8, 0xfa, 0xfc]; // clair.fond

// --- La géométrie du logo, dans son repère 48×48 -----------------------------
const CX = 25;
const CY = 25;
const R = 15;
const EPAISSEUR = 5;

/**
 * L'angle de fin de l'anse, en degrés.
 *
 * Le tracé va de (10, 25) — soit 180° — à (37.29, 16.4). Ce second point est
 * bien sur le cercle : dx = 12.29, dy = −8.6, et 12.29² + 8.6² = 225 = 15².
 * Son angle vaut atan2(8.6, 12.29) ≈ 35°.
 */
const ANSE_FIN = (Math.atan2(25 - 16.4, 37.29 - 25) * 180) / Math.PI;

/**
 * Les densités Android, et la taille correspondante.
 *
 * ⚠️ Elles ne sont pas décoratives : un téléphone ne charge QUE celle de sa
 *    densité. En oublier une donne une icône floue — Android remet à l'échelle
 *    la plus proche — sur exactement les appareils qu'on n'a pas sous la main.
 */
const DENSITES = [
  ['mipmap-mdpi', 48],
  ['mipmap-hdpi', 72],
  ['mipmap-xhdpi', 96],
  ['mipmap-xxhdpi', 144],
  ['mipmap-xxxhdpi', 192],
];

/** Combien d'échantillons par pixel, pour lisser les bords. */
const LISSAGE = 4;

/**
 * Dit ce qu'il y a en un point du repère du logo.
 *
 * Rend `null` pour le vide, sinon la couleur.
 */
function couleurEn(x, y) {
  const dx = x - CX;
  const dy = y - CY;
  const distance = Math.hypot(dx, dy);

  // L'angle, repère mathématique (y vers le haut).
  const angle = (Math.atan2(CY - y, dx) * 180) / Math.PI;

  // L'ANSE : un arc du haut, tracé de part et d'autre du cercle.
  if (
    Math.abs(distance - R) <= EPAISSEUR / 2 &&
    angle >= ANSE_FIN &&
    angle <= 180
  ) {
    return VERT;
  }

  // LA PANSE : le demi-disque du bas. `angle <= 0` sélectionne y >= CY.
  if (distance <= R && angle <= 0) {
    return VERT;
  }

  return null;
}

/**
 * Dessine l'icône à une taille donnée.
 *
 * ⚠️ Le logo est posé sur un DISQUE, pas sur un carré transparent.
 *
 *    Une icône transparente disparaît sur un fond d'écran vert — et sur un
 *    téléphone, le fond d'écran est une photo de famille dont on ne sait rien.
 *    Le disque garantit un contraste, quel que soit ce qu'il y a derrière.
 *
 * ⚠️ Le logo est réduit à 76 % et non collé aux bords : les lanceurs rognent
 *    les coins, et une anse qui touche le bord se fait couper.
 */
function dessiner(taille) {
  const pixels = Buffer.alloc(taille * taille * 4);
  const rayonDisque = taille / 2;
  const echelle = (taille * 0.76) / 48;
  const decalage = (taille - 48 * echelle) / 2;

  for (let py = 0; py < taille; py++) {
    for (let px = 0; px < taille; px++) {
      let r = 0;
      let v = 0;
      let b = 0;
      let a = 0;

      for (let sy = 0; sy < LISSAGE; sy++) {
        for (let sx = 0; sx < LISSAGE; sx++) {
          const ex = px + (sx + 0.5) / LISSAGE;
          const ey = py + (sy + 0.5) / LISSAGE;

          // Hors du disque : transparent.
          if (Math.hypot(ex - rayonDisque, ey - rayonDisque) > rayonDisque) {
            continue;
          }

          const trace = couleurEn(
            (ex - decalage) / echelle,
            (ey - decalage) / echelle,
          );
          const couleur = trace ?? FOND;

          r += couleur[0];
          v += couleur[1];
          b += couleur[2];
          a += 255;
        }
      }

      const total = LISSAGE * LISSAGE;
      const i = (py * taille + px) * 4;
      // ⚠️ Moyenne sur les échantillons COUVERTS, pas sur tous : diviser par
      //    le total noircirait les bords, la couleur des échantillons vides
      //    valant zéro.
      const couverts = a / 255;
      if (couverts > 0) {
        pixels[i] = Math.round(r / couverts);
        pixels[i + 1] = Math.round(v / couverts);
        pixels[i + 2] = Math.round(b / couverts);
        pixels[i + 3] = Math.round(a / total);
      }
    }
  }

  return pixels;
}

// --- L'écriture du PNG -------------------------------------------------------

function morceau(nom, donnees) {
  const longueur = Buffer.alloc(4);
  longueur.writeUInt32BE(donnees.length);

  const corps = Buffer.concat([Buffer.from(nom, 'ascii'), donnees]);

  const somme = Buffer.alloc(4);
  somme.writeUInt32BE(crc32(corps) >>> 0);

  return Buffer.concat([longueur, corps, somme]);
}

const TABLE_CRC = (() => {
  const table = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) {
      c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    table[n] = c;
  }
  return table;
})();

function crc32(octets) {
  let c = 0xffffffff;
  for (const octet of octets) {
    c = TABLE_CRC[(c ^ octet) & 0xff] ^ (c >>> 8);
  }
  return c ^ 0xffffffff;
}

function versPng(pixels, taille) {
  // Chaque ligne est précédée d'un octet de FILTRE. Zéro = aucun : le gain
  // d'un filtre adaptatif ne vaut pas le code sur des images de 192 px.
  const brut = Buffer.alloc(taille * (taille * 4 + 1));
  for (let y = 0; y < taille; y++) {
    brut[y * (taille * 4 + 1)] = 0;
    pixels.copy(
      brut,
      y * (taille * 4 + 1) + 1,
      y * taille * 4,
      (y + 1) * taille * 4,
    );
  }

  const entete = Buffer.alloc(13);
  entete.writeUInt32BE(taille, 0);
  entete.writeUInt32BE(taille, 4);
  entete[8] = 8; // 8 bits par canal
  entete[9] = 6; // couleur vraie avec alpha
  entete[10] = 0; // compression : deflate
  entete[11] = 0; // filtrage : standard
  entete[12] = 0; // entrelacement : aucun

  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    morceau('IHDR', entete),
    morceau('IDAT', deflateSync(brut, { level: 9 })),
    morceau('IEND', Buffer.alloc(0)),
  ]);
}

// --- Exécution ---------------------------------------------------------------

for (const [dossier, taille] of DENSITES) {
  const chemin = join(RES, dossier);
  mkdirSync(chemin, { recursive: true });
  const png = versPng(dessiner(taille), taille);
  writeFileSync(join(chemin, 'ic_launcher.png'), png);
  console.log(`${dossier}/ic_launcher.png  ${taille}x${taille}  ${png.length} octets`);
}

console.log('\nIcônes engendrées depuis le tracé de la calebasse.');
