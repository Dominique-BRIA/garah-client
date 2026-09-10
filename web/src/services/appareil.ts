/**
 * Une version de l'application Android, et pour quels téléphones.
 *
 * <p>Le nom de fichier suit l'ABI Android, parce que c'est ce que produit
 * `flutter build apk --split-per-abi`. Le renommer ferait diverger le
 * téléchargement de ce que la chaîne fabrique.</p>
 */
export interface VersionApk {
  /** L'ABI Android : la façon dont le processeur exécute le code. */
  readonly abi: 'arm64-v8a' | 'armeabi-v7a' | 'x86_64';
  readonly fichier: string;
  /** Ce qu'on écrit à l'écran. Jamais l'ABI brute : elle ne dit rien. */
  readonly libelle: string;
  readonly detail: string;
  readonly poidsMo: number;
}

/**
 * Les trois versions, dans l'ordre où on les propose.
 *
 * <p>⚠️ L'ordre n'est pas décoratif : c'est celui du repli. Le premier est le
 * défaut quand on ne sait pas.</p>
 */
export const VERSIONS: readonly VersionApk[] = [
  {
    abi: 'arm64-v8a',
    fichier: 'garah-arm64-v8a.apk',
    libelle: 'Téléphones récents (64 bits)',
    detail: 'La quasi-totalité des téléphones vendus depuis 2016.',
    poidsMo: 17.8,
  },
  {
    abi: 'armeabi-v7a',
    fichier: 'garah-armeabi-v7a.apk',
    libelle: 'Téléphones anciens (32 bits)',
    detail: 'Modèles d’entrée de gamme, ou achetés avant 2016.',
    poidsMo: 15.4,
  },
  {
    abi: 'x86_64',
    fichier: 'garah-x86_64.apk',
    libelle: 'Émulateur ou tablette Intel',
    detail: 'Presque aucun téléphone. À ne prendre que si vous savez pourquoi.',
    poidsMo: 19.2,
  },
];

/**
 * La version proposée par défaut quand la détection ne tranche pas.
 *
 * <p>⚠️ {@code arm64-v8a} et rien d'autre. Android impose le 64 bits sur le
 * Play Store depuis 2019 : un téléphone vendu ces dernières années l'exécute.
 * Proposer le 32 bits par défaut ferait installer une version plus lente à
 * l'immense majorité — alors que l'inverse, un 64 bits sur un vieux téléphone,
 * refuse simplement de s'installer et se voit tout de suite.</p>
 */
export const VERSION_PAR_DEFAUT = VERSIONS[0];

/** Ce que la détection a conclu, et à quel point elle en est sûre. */
export interface Detection {
  readonly version: VersionApk;
  /**
   * `certaine` : le navigateur a donné l'architecture.
   * `probable` : déduite de la chaîne d'identification.
   * `defaut`   : rien n'a permis de trancher.
   */
  readonly confiance: 'certaine' | 'probable' | 'defaut';
  /** Vrai si l'on n'est pas sur Android : le téléchargement n'a pas de sens. */
  readonly horsAndroid: boolean;
}

/** La forme des données que Chromium expose, quand il les expose. */
interface DonneesUA {
  readonly platform?: string;
  getHighEntropyValues?(champs: string[]): Promise<{
    architecture?: string;
    bitness?: string;
    platform?: string;
  }>;
}

/**
 * Quelle version de l'application proposer à ce visiteur.
 *
 * <h2>⚠️ Le navigateur ne dit PAS l'architecture du processeur</h2>
 *
 * <p>Il n'existe aucun moyen fiable et universel de la connaître depuis une
 * page web. On procède donc par couches, de la plus sûre à la plus faible :</p>
 *
 * <pre>
 * 1. userAgentData.getHighEntropyValues  -> Chromium le donne     (certaine)
 * 2. la chaîne d'identification          -> parfois « aarch64 »   (probable)
 * 3. le défaut                            -> arm64-v8a            (defaut)
 * </pre>
 *
 * <p>⚠️ La couche 1 demande une PERMISSION implicite et une promesse : elle
 * n'est pas disponible sur Firefox ni sur Safari, et pas du tout hors
 * connexion sécurisée. C'est pour cela qu'il y a une couche 3, et non parce
 * qu'on aurait négligé le cas.</p>
 *
 * <p>⚠️ On ne bloque JAMAIS sur cette détection. Elle choisit un défaut
 * meilleur, rien de plus : les trois versions restent proposées à l'écran, et
 * quelqu'un qui sait ce qu'il fait prend la sienne.</p>
 */
export async function detecterVersion(): Promise<Detection> {
  const nav = typeof navigator === 'undefined' ? undefined : navigator;
  if (!nav) {
    return { version: VERSION_PAR_DEFAUT, confiance: 'defaut', horsAndroid: false };
  }

  const ua = (nav.userAgent || '').toLowerCase();
  const donnees = (nav as unknown as { userAgentData?: DonneesUA }).userAgentData;

  // ⚠️ L'UN OU L'AUTRE suffit, et surtout PAS « userAgentData en priorité ».
  //
  //    La première version faisait confiance à `userAgentData.platform` seul
  //    quand il existait. Or il peut dire « Windows » là où la chaîne dit
  //    Android — c'est le cas d'un navigateur embarqué, ou d'une machine de
  //    test. Le visiteur, sur un vrai téléphone, lisait alors « Vous ne
  //    semblez pas être sur un téléphone Android » et n'osait plus installer.
  //
  //    Des deux erreurs possibles, celle-là est la pire : elle EMPÊCHE le
  //    geste. Se tromper dans l'autre sens ne fait qu'omettre un avertissement
  //    à quelqu'un qui, sur un ordinateur, verra de toute façon qu'il ne peut
  //    rien ouvrir.
  const plateforme = (donnees?.platform || '').toLowerCase();
  const estAndroid = plateforme === 'android' || ua.includes('android');

  // ⚠️ HORS ANDROID, ON NE DÉTECTE RIEN DU TOUT — et c'est le point le plus
  //    facile à rater.
  //
  //    Le navigateur décrit LA MACHINE QUI NAVIGUE, pas le téléphone où
  //    l'application sera installée. Quelqu'un qui télécharge depuis son
  //    ordinateur Windows se voyait proposer la version « Intel » : celle
  //    d'un émulateur, qui ne s'installe sur aucun téléphone.
  //
  //    Dans ce cas, un seul choix a du sens : la version la plus répandue.
  if (!estAndroid) {
    return { version: VERSION_PAR_DEFAUT, confiance: 'defaut', horsAndroid: true };
  }

  // --- Couche 1 : ce que Chromium veut bien dire -----------------------------
  if (donnees?.getHighEntropyValues) {
    try {
      const haute = await donnees.getHighEntropyValues(['architecture', 'bitness', 'platform']);
      const arch = (haute.architecture || '').toLowerCase();
      const bits = haute.bitness || '';

      if (arch.startsWith('arm')) {
        return {
          version: bits === '32' ? version('armeabi-v7a') : version('arm64-v8a'),
          confiance: 'certaine',
          horsAndroid: false,
        };
      }
      if (arch.startsWith('x86') && bits === '64') {
        return { version: version('x86_64'), confiance: 'certaine', horsAndroid: false };
      }
    } catch {
      // ⚠️ Volontairement avalé. Cette API rejette dans plusieurs cas — hors
      //    connexion sécurisée, ou refus du navigateur — et aucun d'eux ne
      //    justifie de priver le visiteur de son téléchargement.
    }
  }

  // --- Couche 2 : ce que la chaîne d'identification laisse parfois filtrer ---
  // Rare sur Android, plus courant sur les navigateurs de constructeurs.
  if (/aarch64|arm64|armv8/.test(ua)) {
    return { version: version('arm64-v8a'), confiance: 'probable', horsAndroid: false };
  }
  if (/armv7|armeabi/.test(ua)) {
    return { version: version('armeabi-v7a'), confiance: 'probable', horsAndroid: false };
  }

  // --- Couche 3 : le défaut ------------------------------------------------
  return { version: VERSION_PAR_DEFAUT, confiance: 'defaut', horsAndroid: false };
}

function version(abi: VersionApk['abi']): VersionApk {
  return VERSIONS.find((v) => v.abi === abi) ?? VERSION_PAR_DEFAUT;
}
