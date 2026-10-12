# Fiche européenne — audit avant implémentation

## Architecture réelle
Flutter/Dart. `MatchDetailPage` utilise `LectorMatchDetailView`, `LiveFixtureBuilder`, les lectures calculées sur Supabase et la Shortlist existante. Données privées : `build-match-feed-snapshot` lit le cache API-Football ; `analyze-match-feed-snapshot` publie un modèle mobile réduit. Le modèle public actuel omet les contextes domestiques et les historiques européens complets : la seule adaptation Flutter ne peut donc pas réaliser le brief.

## Correspondance des sources

| Information | Endpoint et champ réel | Modèle / disponibilité |
| --- | --- | --- |
| Identités, saison, compétition, phase | `/fixtures` : `fixture.id/date/status`, `league.id/name/season/round`, `teams.home/away.id/name/logo` | `NormalizedFixture`, `CompetitionInfo`, `TeamInfo` |
| Stade | `fixture.venue.name/city` | `FixtureVenue` |
| Classement officiel | `/standings` : `league.id/season`, `standings[].team.id`, `rank`, `points`, `all.played/win/draw/lose`, `goalsDiff` | `TeamStandingSnapshot` ; pas de date propre actuellement |
| Saison domestique | cache `/leagues` : `seasons[].year/start/end` ; table contenant `team.id` | `TeamCompetitionContext`; résolution actuelle supposant le même millésime que l’Europe à corriger |
| Forme et adversaires | `/fixtures` : `fixture.id/date`, `teams`, `goals.home/away`, `league.id/season` | `TeamRecentMatchSnapshot` et `recent_league_matches` ; liste normalisée sans saison explicite |
| Bilan domicile/extérieur | `/teams/statistics` : `fixtures.played/wins/draws/loses`, `goals.for/against` | `TeamStatisticsSnapshot`; données cumulées pas systématiquement arrêtées au match |
| Parcours européen | cache complet `/fixtures?league&season` : scores, dates, statut final, round | privé `raw.league_fixtures`, absent du modèle public actuel |
| Classement européen | `/standings?league&season` mêmes champs | exploitable uniquement si collecte antérieure au coup d’envoi et phase compatible |
| Confrontations | `/fixtures/headtohead` : identités, date, compétition, scores | `HeadToHeadFixtureSnapshot`, filtre temporel indispensable |
| Lectures et marchés | `computed.fixtures[].readings/scenarios`, `/odds` | composants de lectures et marchés conservés |
| Provenance | cache `endpoint/query_params/fetched_at/as_of` | enregistrée dans les sources privées, pas transmise dans le dossier mobile actuel |

Preuves locales : `docs/audits/api_football_fixture_audit/raw/` contient les réponses réelles standings, team statistics, fixtures et H2H (PL 2025). Les archives `assets/design_preview/champions.json` contiennent Villarreal–Napoli et un résultat européen par équipe ; aucun contexte domestique dans cette archive.

Documentation primaire : https://www.api-football.com/news/post/how-to-get-started-with-api-football-the-complete-beginners-guide confirme les saisons et les fixtures ; `/teams/statistics` propose un paramètre date, mais le collecteur existant ne l’utilise pas pour ce dossier. Aucun classement officiel historique ne sera déduit d’une table actuelle.

## Données manquantes et règles
- Une table observée après le coup d’envoi est exclue, même pour une rencontre ancienne ; on conserve les résultats antérieurs et on explique l’absence du classement historique.
- Sans métadonnées de saison domestique fiables, le championnat reste non résolu. Ne pas assimiler automatiquement le millésime domestique au millésime européen.
- Un résultat doit être final, daté, de la bonne compétition/saison, antérieur au match ; identités dédupliquées. Si la collecte est postérieure et que la fin n’est pas horodatée, les rencontres proches du coup d’envoi sont écartées.
- Bilan vide = absent, jamais 0V/0N/0D. Un premier match européen vérifié possède un état informatif distinct d’une collecte manquante.
- Aucune évolution du rang sans deux observations datées. Pas d’absences, joueurs clés, qualité des adversaires ou avantage domicile inventés.
- Le cumul aller/retour exige une rencontre précédente identifiée dans le même tour/saison ; le parcours qualificatif est séparé de la phase de ligue et des tours éliminatoires.

## Composants et plan
1. Construire côté serveur un dossier européen versionné à partir du cache existant, avec saisons, provenance, cutoff et qualité par bloc ; le publier dans le modèle détaillé. Aucun appel IA supplémentaire.
2. Décoder ce dossier dans un modèle partagé Dart indépendant des widgets ; réutiliser les types de résultats/classement existants.
3. Ajouter une variante européenne du hero et des sections comparatives compactes utilisant `RecentFormStrip`, les tokens/3 assets européens validés et les détails dépliables.
4. Adapter le contrat de `LectorMatchDetailView` avec des valeurs par défaut inchangées pour les autres rencontres. Onglets actuels : Contexte, Classement, Forme, TAT, Stats si commencé. Ajouter Synthèse et Marchés pour l’Europe ; aucun onglet Historique fictif en doublon de TAT.
5. Conserver Shortlist, lectures, Stats et Générateur. Les outils de lecture du Générateur exposeront le même dossier structuré depuis la publication canonique.
6. Tester les huit scénarios du brief, la provenance, la coupure temporelle et les petites largeurs ; produire des captures réelles de la fiche.

## Risques à contrôler
Contexte absent du modèle public, saison domestique différente de la saison européenne, réutilisation de standings actuels, duplication des fixtures de plusieurs sources, échantillons partiels, temps de détail et volume du dossier. La nouvelle projection n’altère ni les règles de paris ni les algorithmes de lectures existants.
