# Parité du détail hockey et actualisation des résultats — 5 octobre

## Causes constatées

La page détail partageait la structure de navigation et le bandeau avec le
football, mais pas le corps des onglets Contexte et Forme. Le hockey présentait
ses propres blocs ; le détail des lectures utilisait également une autre
présentation. La mutualisation du cadre n'était donc pas une parité complète.

La démo Vercel servait un compact figé : collecte du 4 octobre à 19:58:28 UTC.
Aucun collecteur distant hockey ni lecteur périodique des scores hockey n'était
installé. Le live football ne pouvait pas mettre à jour les identités API-Hockey.

Une requête d'audit sur `/games?id=430525` a confirmé : Magnitogorsk à domicile,
Vladivostok à l'extérieur, `FT`, 2–5 ; périodes 0–0, 1–4, 1–1. Le départ est le
5 octobre à 14:00 UTC, soit 16:00 à Paris. L'ancien compact conservait `NS`.

## Correction de présentation

- `LectorMatchFormView` est extrait du composant football existant. Les deux
  adaptateurs l'utilisent pour les résultats, points, comparaison, derniers
  matchs et synthèse. Le barème reste fourni par la discipline : 10 points
  maximum sur cinq matchs pour NHL/KHL, 15 pour les ligues à trois points.
- `LectorMatchContextView`, `LectorEvidenceTeamCard` et `LectorEvidenceRow`
  partagent la présentation des clés du match et des preuves.
- `LectorAnalysisSheet` et son en-tête reprennent la fiche d'analyse football.
  Le hockey ouvre cette même fiche depuis « Vos lectures » / « Voir le détail ».
- Les scores à 60 minutes, finaux et par période restent disponibles dans Stats.
  Aucun score après prolongation n'est utilisé comme score à 60 minutes manquant.
- Les préférences et moteurs ne sont pas fusionnés. Sans choix hockey, Pour moi
  reste vide ; le calendrier Tous demeure consultable.

## Collecte actualisée

Une collecte réelle des sept ligues a utilisé 816 appels API, avec le compteur
local existant et une reprise après une réponse de limite par minute. Publication :
491 rencontres, fenêtre 28 septembre → 18 octobre, `capturedAt`
`2026-10-05T17:08:08.900Z`, base `2026-10-05T17:07:56.470Z`.
Le résultat 2–5 de la rencontre 430525 figure dans ce compact.

## Live automatique préparé

La migration `20261005180000_hockey_live_collection.sql` et la fonction
`sync-hockey-live` sont séparées des tables et fonctions football.
Installation désactivée par défaut. Le cron fonctionne une fois par minute.
Deux appels groupés lisent aujourd'hui et hier, toutes ligues confondues ;
une journée de rattrapage est ajoutée à chaque début d'heure. Plafond du live :
3000 appels hockey par jour ; quota commun : 7500/jour et 200/minute.
Le collecteur local réserve également chaque requête via le nouvel endpoint privé
une fois installé ; avant installation (HTTP 404), il conserve son compteur local.
Une panne d’un endpoint déjà installé interdit de dépenser sans réservation.

Les RPC d'exécution sont réservées au service serveur. Les clients ne peuvent
que lire `sport_live_states`, qui contient les faits publics des rencontres.
Le collecteur possède un bail avec jeton ; arrêt et expiration interdisent les
réservations et publications tardives. Les réponses API incomplètes/en erreur
n'effacent pas les derniers résultats valides.

`SportLiveController` lit ces états toutes les 60 secondes et actualise cartes,
regroupements temporels et détail déjà ouvert. L'identité du match, de la ligue,
de la saison et des deux équipes est vérifiée. Le score ne remplace ni la forme,
ni le tête-à-tête, ni les lectures de la publication d'avant-match. Un échec du
service est signalé, sans inventer un live à partir de l'heure de début.

Cette collecte ne rafraîchit pas les classements, les joueurs et les événements
complets. Ceux-ci restent datés de leur collecte initiale. Une collecte quotidienne
distante du compact hockey reste un chantier distinct ; le compact de démonstration
reste soumis à la politique de fraîcheur existante, sans timestamp fabriqué.

## Autorisation de déploiement

La revue automatique a refusé la saisie du nouveau code dans l'éditeur Supabase :
accord explicite requis pour cette destination et cette fonction hockey.
Une demande d'accord couvre la migration, la fonction, l'authentification par le
secret serveur existant avec vérification JWT de passerelle désactivée, et
l'activation. Aucun accès au trousseau macOS n'est tenté.

Tant que cet accord et les vérifications distantes ne sont pas obtenus, le live
automatique n'est pas présenté comme installé. La mise à jour ponctuelle du
compact et la correction des écrans peuvent être publiées indépendamment sur
l'aperçu Vercel. Aucune publication football sur main dans cette étape.

## Vérifications

- Tests partagés : pages football/hockey aux largeurs 360 et 1100 ; assertions
  sur les composants réels de Contexte et Forme, pas seulement leurs cadres.
- Test des barèmes NHL/Suède, opt-in et isolation par identité/sport.
- Détail ouvert : réception d'un état live puis final, ordre extérieur/domicile.
- Transport public : pas de JWT du compte, rejet d'identités incohérentes.
- Contrôleur : maintien des faits d'avant-match, dernier score conservé lors
  d'une panne et absence de retour intempestif d'un résultat final vers le live.
- 4 tests Deno/PGlite : normalisation du vrai cas KHL, réponse fournisseur
  invalide, quota, droits SQL, arrêt du collecteur et absence de mutation football.
- Analyse Dart sans anomalies ; compilation release et scan des valeurs privées
  du `.env` dans l'artefact. Aucune clé fournisseur/serveur n'y apparaît.

La suite complète a donné 706 réussites et deux tests ignorés ; deux anciens tests
hockey attendaient les scores dans Contexte. Après mise à jour pour vérifier ces
faits dans Stats et le composant partagé dans Contexte, les quatre tests du fichier
ont réussi (dont les deux cas mobile/desktop concernés).

## Publication de l’interface et de la collecte ponctuelle

Vercel confirme `READY` pour `dpl_ZfBmBAXTuZHcY5kLTU5fLrGBFBeq`,
`https://lector-sports-djusfnjou-lector1.vercel.app` (preview).
L'artefact final a été reconstruit après les dernières corrections, en 80,5 s.
Le scan des valeurs privées du `.env` n'a trouvé aucun secret dans l'artefact.
La protection Vercel existante est conservée. Le contrôle visuel a été réalisé
sur le build local, pas par une requête à l'URL publiée.
Les 11 derniers tests ciblés de parité, barèmes, live ouvert et scores Stats
sont tous passés, après les corrections. L'analyse finale ne signale rien.

L'alias `lector-sports-demo-lector1.vercel.app` a été affecté par le CLI Vercel
au nouveau déploiement. C'est l'adresse stable déjà inscrite dans les retours
Google. Aucun retour OAuth supplémentaire n'a été ajouté.
