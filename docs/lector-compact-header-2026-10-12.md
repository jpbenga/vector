# Lector — partie supérieure compacte

## Référence et périmètre

Ajustement ciblé d’après la capture `776442A7-6F03-4C0D-A869-4B3FD65FEE37/1-Photo-1.jpg`. Elle précise la nouvelle présentation souhaitée du header, du calendrier et de la navigation. Les cards validées dans le chantier précédent ne sont pas modifiées.

| Avant | Après | Intention |
| --- | --- | --- |
| Header de 52 px, logo 27 px | Header de 48 px, logo 30 px, sélecteur et Shortlist mieux proportionnés | Reconnaissance sans ajouter de hauteur |
| Dates en pastilles avec soulignement | Date choisie en rectangle arrondi, bordure bleue, date contrastée | Retrouver la sélection de la référence |
| Navigation angulaire de 54 px, icône au-dessus | Navigation arrondie de 44 px, icône à côté du texte aux largeurs usuelles | Simplifier et réduire l’encombrement |
| Icône de calendrier 34 × 38 px | Zone tactile 44 × 44 px | Maintenir une action utilisable sur téléphone |

Les cinq rubriques gardent des largeurs égales et leur ordre. Une seule est sélectionnée ; Radar et Générateur conservent leur identité permanente. Les couleurs viennent des tokens existants. Aucun halo, aucune simulation de barre iOS/Safari et aucune navigation inférieure ne sont ajoutés.

À 320 px ou avec de grands caractères, les icônes reviennent au-dessus du texte pour conserver les cinq libellés. La Shortlist masque son libellé quand l’espace ne permet pas de le montrer ; son pictogramme, son compteur et son infobulle restent les points d’accès. La même présentation est partagée par les workspaces football et hockey.

## Vérifications

- 47 tests ciblés réussis : navigation et sélection unique, défilement/sélection de dates, sélecteur de sport, Shortlist, tokens, rendus intégrés.
- flutter analyze : No issues found.
- Rendus Flutter à 320, 375, 390, 430 et 768 px ; également 320 px, thème clair et texte 1,5×. Inter et les pictogrammes Material sont chargés.
- Détecteur Impeccable, portée layout, avant et après : aucun signalement. Le rendu visuel et les tests Flutter constituent la vérification de la composition.
- Aucun nouvel asset, aucune collecte fournisseur et aucun prompt payant.

## Comportements conservés

Les callbacks de sport, profil, réglages, Shortlist, dates et cinq rubriques sont conservés. La plage des dates et leur révélation au défilement ne sont pas modifiées. La personnalisation, les cartes, les lectures, les algorithmes, les tickets, le Générateur et les données serveur restent ceux de la version précédente.

Les contrôles mobiles utilisent des rendus Flutter et le navigateur ; aucun téléphone physique n’est utilisé.

## Livraison

Code : `0ec7df002ca3166e7581e5eb98f79fc8844832ce`, branche `codex/multisport-hockey`. [CI](https://github.com/jpbenga/vector/actions/runs/38229534736) réussie pour Flutter et supabase-functions. La compilation release a réussi en 388 secondes.

Vercel confirme READY pour `dpl_CRFVNTG3FxbiYbuvckomUtR7fbyq`. La [démo habituelle](https://lector-sports-demo-lector1.vercel.app/) pointe vers [ce déploiement](https://lector-sports-2h7i91jum-lector1.vercel.app/). L’ouverture neuve de l’alias atteint Lector en mode invité sans écran Vercel. La sélection de Tous et du 13 octobre est vérifiée sur cet alias : le nouveau header, la date choisie et la navigation sont présents ; les 19 rencontres publiées de cette date sont chargées.

Le gros plan ci-dessous est une capture directe du navigateur, à 390 px, cadrée sur les trois lignes demandées. Il ne comporte aucune barre système simulée. Le compte de vérification est invité : le pictogramme du profil est donc affiché à la place des initiales d’un utilisateur connecté.

![Partie supérieure — démo publiée](/Users/chloe/.codex/visualizations/2026/09/16/01a0aaf1-05e5-7562-8f19-7332ea8701f5/lector-compact-header-demo-390.png)

[Capture complète de l’écran](/Users/chloe/.codex/visualizations/2026/09/16/01a0aaf1-05e5-7562-8f19-7332ea8701f5/lector-compact-header-demo-full-390.png)

Reçu : `lector-compact-header-delivery-2026-10-12.json`. L’onglet de vérification est fermé et le viewport du navigateur est restauré.
