import { Component, computed, signal } from '@angular/core';

import {
  Detection,
  VERSIONS,
  VERSION_PAR_DEFAUT,
  VersionApk,
  detecterVersion,
} from '../../services/appareil';

/** Le dossier servi depuis `web/public/` : les fichiers sont à la racine. */
const DOSSIER = '/apk/';

/**
 * La page de téléchargement de l'application Android.
 *
 * <h2>🎯 Un seul gros bouton, et le bon fichier derrière</h2>
 *
 * <p>Android livre l'application en trois versions, une par famille de
 * processeur. Demander à quelqu'un de choisir entre {@code arm64-v8a},
 * {@code armeabi-v7a} et {@code x86_64} n'a pas de sens : ces mots ne veulent
 * rien dire pour qui veut simplement installer une application.</p>
 *
 * <p>La page devine donc, et propose UN bouton. Les deux autres versions
 * restent accessibles en dessous, pour qui sait ce qu'il fait ou pour qui la
 * première a refusé de s'installer.</p>
 *
 * <h2>⚠️ On ne bloque jamais sur la détection</h2>
 *
 * <p>Le navigateur ne dit pas l'architecture du processeur de façon fiable.
 * Quand il ne dit rien, on propose le 64 bits — la quasi-totalité des
 * téléphones vendus depuis 2016. Le bouton est là dès le premier affichage, et
 * il se corrige tout seul si la détection aboutit.</p>
 *
 * <h2>⚠️ Ce que le fichier PÈSE est écrit</h2>
 *
 * <p>Dix-huit mégaoctets sur un forfait qui se compte, ce n'est pas un détail
 * d'ingénieur. Lancer un téléchargement de cette taille sans prévenir, c'est
 * prendre l'argent de quelqu'un sans le lui dire.</p>
 */
@Component({
  selector: 'gb-application',
  templateUrl: './application.html',
  styleUrl: './application.scss',
})
export class Application {
  protected readonly versions = VERSIONS;

  /**
   * Ce que la détection a conclu.
   *
   * <p>Nul tant qu'elle n'a pas répondu — mais l'écran n'attend pas : il
   * affiche le défaut, et le remplace si besoin.</p>
   */
  protected readonly detection = signal<Detection | null>(null);

  protected readonly conseillee = computed<VersionApk>(
    () => this.detection()?.version ?? VERSION_PAR_DEFAUT,
  );

  /** Les autres versions, celles qu'on ne met pas en avant. */
  protected readonly autres = computed(() =>
    this.versions.filter((v) => v.abi !== this.conseillee().abi),
  );

  protected readonly horsAndroid = computed(() => this.detection()?.horsAndroid ?? false);

  /** Vrai quand rien n'a permis de trancher : on le DIT, on ne le cache pas. */
  protected readonly incertain = computed(() => this.detection()?.confiance === 'defaut');

  constructor() {
    // ⚠️ En dehors du constructeur d'un signal : la détection est asynchrone
    //    (l'API de Chromium rend une promesse) et ne doit pas retarder le
    //    premier affichage.
    void detecterVersion().then((d) => this.detection.set(d));
  }

  protected lien(v: VersionApk): string {
    return DOSSIER + v.fichier;
  }
}
