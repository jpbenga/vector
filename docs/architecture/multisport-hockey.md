# Socle multisport — première étape hockey

Branche : `codex/multisport-hockey`, créée depuis `de1c0b5`.

## Décision d’architecture

Une application et un compte communs, avec des espaces métier distincts.
Le compte, l’authentification, les thèmes et les composants visuels restent communs.
Chaque discipline possède ses adaptateurs de données, ses règles, ses lectures,
ses scénarios, ses marchés et sa mesure des résultats.

Le point d’entrée propose un sélecteur de sport. Le football reste accessible
sur `/`, le hockey sur `/sports/hockey`. Basket, baseball et football américain
sont recensés comme modules à venir. Aucun appel fournisseur hockey n’est lancé.

Une configuration **typée par module** est préférable à un grand JSON universel :
le compilateur vérifie les paramètres et les conditions ; les algorithmes propres
au sport restent dans leur module. Les paramètres exposés à l’administration
pourront ensuite être stockés en base, avec validation et version de règles.

## Audit du code existant

| Zone | Constat | Stratégie |
| --- | --- | --- |
| `CopilotFlowPage` | Charge le profil football et ses stratégies | Point d’entrée du module football pendant la migration progressive |
| `MatchFeedRepository` / `ApiFootballMatchAdapter` | Le modèle inclut les buts, les marchés 1N2, les lectures et les données football | Adapter chaque source vers son modèle ; ne pas faire passer le hockey dans cet adaptateur |
| `FootballReading`, `FootballScenario` et moteurs d’opportunités | Les preuves et exigences sont spécifiques au football | Nouveau contrat de résultat partagé, moteurs par sport |
| Catalogue des compétitions et profils | Les IDs sont ceux d’API-Football | Ajouter sport, fournisseur et type d’entité aux nouvelles clés |
| Radar | Fenêtres, contributions et départages football | Interface visuelle réutilisable, calcul hockey à construire après audit des statistiques disponibles |
| Bilan et tickets | Validation des marchés football, notamment 1N2 et totaux | Définir les périmètres de score et les règles de règlement hockey avant tout verdict |
| Supabase / workers / live | Tables, quotas et fonctions nommés football | Garder le chemin football ; ajouter le chemin hockey explicitement au futur orchestrateur commun |

L’application n’est donc pas encore entièrement découplée. Renommer toutes les
classes football en « sport » masquerait ces dépendances. Cette étape établit
la frontière pour ajouter le hockey, puis extraire les composants réellement communs.

## Ce qui est implémenté

- `core/sports/domain/sport.dart` : cinq disciplines, identifiants incluant
  sport/fournisseur/type/ID, nouvelles clés locales incluant identité et sport.
  Les anciennes clés des comptes football ne sont pas migrées ni renommées.
- `sport_module.dart` : configuration des capacités, définitions des lectures et
  scénarios, résultat d’analyse avec match, sujet, preuves, date et statut.
- `sport_snapshot.dart` : publication typée, versionnée, avec fenêtre indépendante
  du nombre de rencontres. Une publication hockey ne peut contenir du football.
  Une journée couverte sans rencontre constitue un état vide valide.
  Ce contrat n’est pas encore relié à une nouvelle table Supabase.
- `features/sports` : registre, sélecteur et routage des espaces de sport.
- `features/hockey/domain` : contexte d’analyse, barèmes explicites, premier moteur.
- Espace hockey : Matchs, Lectures et Scénarios ; conditions et exemples illustratifs.
  L’absence de source connectée est présentée dans l’espace, sans bloquer la navigation.

## Lectures hockey : propositions initiales

Les seuils sont des **hypothèses analytiques de version `hockey-readings-draft-v1`**,
à calibrer avec les données et à valider avant une utilisation réelle.
Ce ne sont pas des règles sportives, des probabilités ni des garanties de résultat.

| Lecture | Détection proposée | Données indispensables |
| --- | --- | --- |
| Avantage au classement | Écart d’au moins 15 points de pourcentage des points disponibles, après au moins 10 matchs par équipe | Points, matchs disputés, compétition, saison, groupe de comparaison, date |
| Avantage de forme | Écart d’au moins 20 points de pourcentage sur 5 matchs terminés par équipe | Résultats avec distinction victoire/défaite à 60 minutes, prolongation et tirs au but |
| Série de victoires | Trois dernières rencontres gagnées, prolongation et tirs au but inclus | Résultats terminés avant l’analyse |
| Avantage du gardien | À étudier | Gardien attendu, statut confirmé, performances et taille d’échantillon |
| Situations numériques | À étudier | Power play / penalty kill sur une fenêtre comparable |
| Repos et calendrier | À étudier | Horaires exacts, rencontres successives, déplacements si disponibles |

Le scénario « Avantages convergents » exige les deux premières lectures pour
la **même équipe, le même match et la même date d’évaluation**.

Le moteur écarte les matchs d’une autre compétition ou saison, les doublons et
les résultats postérieurs à la date d’analyse. Un échantillon incomplet donne
« données insuffisantes », jamais une lecture détectée. Il refuse un contexte
football, des équipes identiques ou une analyse après le début du match.

### Règles par championnat

Le barème NHL de saison régulière distingue défaite à 60 minutes et défaite
après prolongation/tirs au but. Un second barème à trois points est disponible
comme règle explicite pour les compétitions qui l’emploient. Le futur adaptateur
doit sélectionner le barème correspondant à la compétition et à sa phase.
**Une compétition inconnue n’hérite jamais automatiquement du barème NHL.**

Le classement doit indiquer le groupe de comparaison : on ne compare pas
aveuglément des rangs de divisions différentes. Le premier moteur utilise le
pourcentage des points disponibles dans un groupe commun déclaré.

Sources officielles consultées :
- [NHL — explication des points](https://www.nhl.com/kraken/news/seattle-kraken-nhl-league-standings-explainer-326957072)
- [NHL — départage des classements](https://www.nhl.com/info/standings-info/tie-breaking-procedure)
- [API-Sports — documentation hockey](https://api-sports.io/documentation/hockey/v1)

## Prochaine étape : intégrer les vraies données

1. Confirmer le fournisseur, le forfait hockey, ses quotas et des exemples de
   réponses : compétitions, saisons, calendrier, résultats, classements,
   statistiques, événements, joueurs et cotes. Aucun endpoint ni ID NHL n’est
   codé à ce stade.
2. Choisir les compétitions initiales, dont la NHL, et définir leurs règles
   (saison régulière / playoffs, barème, périmètres des cotes).
3. Adapter les réponses dans le backend : conserver le score à 60 minutes,
   le score après prolongation et le résultat final **séparément**, sans déduire
   une victoire à 60 minutes d’un simple score final. Le contrat exact dépendra
   des champs réellement fournis.
4. Ajouter les migrations hockey : collectes brutes, snapshots analysés,
   publications compactes, annonces avant match et résultats. Séparer les
   politiques d’accès aux données publiques des préférences privées du compte.
5. Brancher les collecteurs hockey sur l’orchestrateur, avec lots reprenables,
   quotas atomiques par contrat fournisseur et priorités live / collecte quotidienne.
   Une limite globale partagée n’est correcte que si le fournisseur partage
   réellement ce quota entre football et hockey ; ne pas supposer que les
   75 000 appels football couvrent les autres sports.
6. Tester le parcours réel complet : collecte → brut → analyse → publication
   compacte → lecture anonyme/authentifiée → affichage, y compris une journée
   vide et le passage de minuit. Les tests de contrat de cette première étape
   ne remplacent pas ce futur test d’intégration Supabase.
7. Calibrer les lectures et revoir les scénarios, puis intégrer cartes de matchs,
   radar, préférences, bilan et live avec les règles de résultat hockey.

## Infrastructure

La structure proposée permet de commencer dans le même projet Supabase :
modules, données et politiques d’accès peuvent y être séparés. Aucun changement
ou coût supplémentaire d’infrastructure n’est déclenché par cette étape locale.
La nécessité d’augmenter les ressources devra être mesurée avec le volume réel,
la taille des publications, la rétention, les temps des workers et les lectures
publiques. Aucun tarif hockey ni budget d’appels fiable ne peut être établi
avant de connaître le fournisseur et son contrat.

## Vérification locale

```bash
cd /Users/chloe/Documents/Codex/2026-09-16/c-2/lector-api-football-orchestration
bash tool/run_web_with_env.sh 8099 release
```

Le script conserve la configuration Supabase du football. Choisir **Hockey**
dans le sélecteur de sport ou ouvrir `/sports/hockey`. Il n’y a pas encore de
rencontres réelles hockey : les lectures sont consultables avec leurs exemples.
Cette branche n’est ni fusionnée sur main, ni déployée en production.
