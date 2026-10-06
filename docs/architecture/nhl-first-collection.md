# Première collecte NHL — vérification locale

Branche : `codex/multisport-hockey`. Cette étape permet de consulter les vrais
matchs NHL sans modifier la collecte football en production.

## Lancer les deux disciplines

```bash
cd /Users/chloe/Documents/Codex/2026-09-16/c-2/lector-api-football-orchestration
SPORT_PREVIEW_PORT=8110 bash tool/run_multisport_local.sh 8191 release
```

Le script lit le `.env` existant :

- `SUPABASE_URL` et `SUPABASE_ANON_KEY` alimentent le football existant.
- `API_HOCKEY_KEY` est utilisé s'il existe ; sinon `API_FOOTBALL_KEY`, puisque
  l'abonnement Hockey utilise la même clé API-Sports.
- La clé fournisseur reste dans le processus Deno, jamais dans Flutter.

Le script vérifie les ports avant tout appel fournisseur. S’il existe déjà une
source hockey sur `127.0.0.1:8110`, il vérifie qu’elle sert exactement la publication
compacte de ce projet et la réutilise **sans nouvelle collecte**. Sinon, il démarre
la collecte des sept ligues et attend sa publication avant d’ouvrir Flutter.

Chrome utilise `http://localhost:8191/`. Cette adresse est autorisée dans les
retours OAuth Supabase ; `APP_PUBLIC_URL` est fixé à cette même origine locale.
Un autre port d’application doit également être autorisé dans Supabase avant
un test Google. Les anciens lancements sur 8189 ne sont pas couverts par
l’autorisation ajoutée pour 8191.

Laisser le terminal ouvert. `q` quitte Flutter. Le script arrête uniquement le
collecteur qu’il a créé ; une source déjà existante est conservée. Si le port
8191 est occupé, le script indique le conflit avant toute collecte. Arrêter son
ancien lancement avant de réessayer ; aucun processus n’est supprimé automatiquement.

Choisir Hockey dans le sélecteur de sport, ou ouvrir
`http://localhost:8191/sports/hockey`. Le sélecteur permet de revenir au football.
Les flèches de date parcourent les jours ; toucher une carte ouvre le détail.
Le bouton d'actualisation **relit le compact** : il ne lance pas un appel
fournisseur depuis le navigateur.

## Historique de la première collecte NHL

Les chiffres ci-dessous décrivent la première étape, limitée à la NHL.
La collecte locale actuelle couvre sept ligues et enrichit les équipes, confrontations
et joueurs ; voir les rapports dans `docs/audits/multisport/`.

### Données et coût de la première étape

1. `/leagues?id=57` résout la saison NHL déclarée courante par le fournisseur.
2. `/games?league=57&season=<saison>&timezone=Europe/Paris` récupère le calendrier
   de cette saison en un appel, puis l'adaptateur sélectionne la fenêtre.
3. Les deux réponses brutes sont conservées dans `var/sports/hockey/raw/<run>/`.
4. Le compact est construit et publié atomiquement dans `published.json`.
5. Flutter décode ce contrat partagé et affiche les rencontres du jour choisi.

Une collecte coûte **deux requêtes fournisseur**, pas deux par match.
Une publication de moins de 15 minutes, du même jour civil, est réutilisée.
Le compact est alors reconstruit à partir du brut, sans appel supplémentaire.
Ce script de vérification ne lance pas de boucle quotidienne ou de collecte live.

Fenêtre : **J−7 à J+13**, soit les sept jours précédents et quatorze jours de
calendrier à partir d'aujourd'hui. Les jours sont ceux de `Europe/Paris`, avec
prise en compte du changement d'heure. Une journée vide reste accessible.

La collecte réelle du 4 octobre 2026 a donné **132 rencontres**, dans la fenêtre
27 septembre–17 octobre, pour deux appels. Les seules données publiées sont
les identités, logos, horaires, statut et scores. Le fournisseur n'identifie pas
fiablement la phase de chaque rencontre dans ce contrat : nous n'inventons pas
une classification présaison/saison régulière à partir de la date.

Le score final peut inclure prolongation/tirs au but. Le score à 60 minutes
n'existe que si les trois périodes sont disponibles et terminées. À l'écran,
les visiteurs sont à gauche et le domicile à droite, avec des libellés explicites.
Les lectures/scénarios hockey restent des propositions : ils ne sont pas
calculés sur ces publications. Pas de cotes, statistiques, événements ou H2H
collectés à cette étape ; leurs routes seront étudiées pour le chantier des lectures.

## Sécurité et limites du mode local

Le serveur écoute uniquement sur la boucle locale et n'expose que le compact.
Le brut et les clés ne sont pas des routes HTTP. Les fichiers sont ignorés par
Git ; la collecte publiée et deux dossiers bruts récents sont conservés pour limiter le disque.
Un verrou empêche deux collecteurs locaux simultanés. Le budget local réserve
chaque appel avant l'envoi, y compris un appel échoué, dans un compteur Hockey
indépendant (7 500/jour UTC, 280 sur une minute glissante).

Ce compteur local ne connaît pas les appels réalisés ailleurs avec le même
abonnement. Il sert à ce test ; la garde partagée en base est prévue pour les
futurs collecteurs Supabase. Ne pas lancer les deux modes de collecte en parallèle.
Si la collecte initiale échoue, le script le dit et ne lance pas silencieusement
un aperçu sans données. Une erreur de lecture du compact dans l'application
laisse la navigation et les autres disciplines accessibles.

## Raccordement Supabase préparé, non installé

`20261004140000_sport_feed_collection.sql` crée des tables isolées par sport,
fournisseur et compétition : configuration, runs, brut privé, réservations et
publication compacte publique. `collect-sport-feed` utilise **le même adaptateur**
que le collecteur local. Le lecteur Flutter peut lire la table compacte publique
avec la clé publique, indépendamment de la session du compte.

La migration démarre **désactivée**, sans planificateur. Elle n'a pas été appliquée
à la production ; la fonction n'a pas été déployée. Cela fera partie d'une étape
séparée après validation locale. Avant ce passage : installer et vérifier les
permissions réelles, déployer la fonction et ses secrets, activer la compétition,
faire une collecte contrôlée puis tester le chemin public Supabase. Le passage
au mode Supabase supprimera le besoin du serveur local Hockey.

Les appels backend réservent le budget par abonnement, sous verrou PostgreSQL,
avant chaque requête. Un run expire après trois minutes et ne peut plus publier
ni réserver d'appel. Le compact n'est publié qu'après conservation des deux
réponses brutes, avec la provenance du run. Un échec conserve le compact précédent.

## Vérifications automatisées

- Fixture issue de Winnipeg–Boston : même brut → même compact côté Deno et Dart.
- Périodes 3–3 à 60 minutes ; score final 3–4, affiché Boston 4–3 Winnipeg.
- Front à 360 px et sur grand écran, détail par périodes et rôles domicile/extérieur.
- Jour vide, indisponibilité, jour 14, erreurs fournisseur HTTP 200, changement
  d'heure, doublons et séparation des disciplines.
- PostgreSQL embarqué : brut privé/compact public, budget minute/jour, provenance,
  worker expiré, échec conservant l'ancien compact et publication vide acceptée.
- Suite existante football, y compris son contrat calendrier 14 jours.

Ces tests protègent le contrat ; ils ne remplacent pas la vérification du futur
déploiement Supabase, qui n'a pas encore eu lieu.
