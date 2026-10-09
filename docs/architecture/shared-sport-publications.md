# Publications partagées du multisport

Le transport commun conserve des publications publiques immuables, identifiées
par sport et date réelle de collecte. Les écrans hockey et le Générateur démo
lisent `sport_feed_snapshots` via des RPC contrôlées. Football conserve son
collecteur, ses publications et ses RPC de production existants.

## Collecte et publication

1. Le collecteur serveur produit le compact, ses historiques et sa date réelle.
2. `prepare_hockey_publication.dart` applique `HockeyFeedReadings`, le moteur
   utilisé par l'écran, et ajoute les lectures détectées à chaque rencontre.
3. `publish_sport_feed.py` publie avec le secret serveur existant. La fonction
   `publish-sport-feed` refuse les clients non authentifiés, les données périmées
   et les enveloppes brutes. Aucun secret fournisseur n'est envoyé au navigateur.
4. `publish_sport_feed` archive le document et sa projection légère en transaction.
   Un nouvel envoi de la même version est idempotent ; la modifier est refusé.
5. Le script vérifie que le document serveur est identique au document local.

La mise à jour du collector respecte le quota partagé hockey existant. La
publication et les vérifications n'appellent ni le fournisseur ni OpenAI.

## Lecture progressive

`read_sport_feed` livre la journée, le Radar ou un détail. Le détail est épinglé
à la version chargée avec la journée. Le Radar conserve les historiques exacts
et les identifiants transmis au Générateur. Le stockage conserve les anciennes
versions lorsqu'une nouvelle collecte arrive. Le cache et le préchargement des
journées restent dans le repository commun.

Une démo hébergée lit le serveur hockey ; un aperçu local peut lire son
collecteur, qui publie la même version avant de lancer Flutter. La construction
Vercel refuse de livrer une version locale non disponible au Générateur.

## Générateur

Les RPC `lector_generator_shared_sources` et
`lector_generator_shared_radar_sources` délèguent le football aux lecteurs
existants et ajoutent les compacts des modules sportifs publiés. Elles sont
réservées au serveur. Le périmètre Pour moi respecte les compétitions et les
lectures configurées ; le Radar lit la date exacte affichée, jamais son successeur.
Les historiques des membres restent vérifiés côté serveur.

Le stockage et le reader sont génériques. Un prochain sport ajoute son adaptateur
et ses règles au registre ; il ne duplique pas les tables ou les parcours de
lecture. L'adaptateur de publication actuellement disponible est celui du hockey.

Les compacts hockey ne contiennent actuellement pas de cotes horodatées.
Hector peut analyser les rencontres et les lectures ; le moteur ne crée pas
artificiellement de pari hockey. La collecte des marchés constitue une étape
séparée.

## Installation

`Deploy Supabase` → `lector-generator-sport-publications`, depuis la branche
`codex/multisport-hockey`, après CI réussie pour le commit exact. Installe uniquement
la migration additive des publications et déploie `publish-sport-feed` et
`lector-generator-workshop`. Ne fusionne pas la branche dans main et ne modifie
ni le modèle ni le budget du Générateur.
