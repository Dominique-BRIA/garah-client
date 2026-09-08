import { bootstrapApplication } from '@angular/platform-browser';

import { Racine } from './app/racine';
import { configuration } from './app/configuration';

bootstrapApplication(Racine, configuration).catch((erreur: unknown) => {
  // ⚠️ Un échec d'amorçage laisse l'écran d'attente à l'écran POUR TOUJOURS :
  //    Angular n'a jamais remplacé le contenu de <gb-racine>, donc le visiteur
  //    regarde une animation qui tourne dans le vide, sans le moindre message.
  //
  //    On le dit, et on garde la trace en console pour le diagnostic.
  console.error('GARAH — démarrage impossible', erreur);

  const hote = document.querySelector('gb-racine');
  if (hote) {
    hote.innerHTML = `
      <div style="padding: 32px; text-align: center; font-family: 'Outfit', system-ui, sans-serif;">
        <p style="font-size: 17px; font-weight: 600; margin: 0 0 8px;">La boutique n’a pas pu démarrer</p>
        <p style="font-size: 14px; color: #64748b; margin: 0; line-height: 1.55;">
          Rechargez la page. Si cela se répète, réessayez dans quelques minutes.
        </p>
      </div>`;
  }
});
