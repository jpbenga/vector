# Comprendre les lectures et les scénarios

Les réglages de suivi conservent leurs switches et leur mécanisme de sauvegarde.
Un accès explicite à l’aide est ajouté au moment du choix :

- `Mes lectures` → déplier une catégorie → `Comprendre cette lecture` ;
- `Mes scénarios` → bouton d’information `Comprendre ce scénario`.

Consulter l’aide ne modifie pas les préférences. Le retour retrouve la liste,
son défilement et la sélection en cours.

## Fiches de lecture

Chaque lecture sélectionnable, ainsi que chaque lecture de soutien utilisée
par les scénarios, possède une définition, les conditions observées, un exemple
fictif et un contre-exemple. Les termes over/under, BTTS, clean sheet et xG sont
expliqués dans leur contexte. Les données insuffisantes sont distinguées des
critères non remplis.

Les exemples chiffrés ne constituent pas des rencontres réelles et ne sont
injectés ni dans les snapshots, ni dans le Radar, ni dans le bilan.

Le contenu éditorial est dans `lector_guide_catalog.dart`. Ses règles proviennent
de `supabase/functions/publish-reading-announcements/index.ts` et des politiques
partagées de forme, d’écart structurel et de tête-à-tête. Pour les indicateurs
relatifs au championnat, les exemples précisent que la zone haute ou basse est
déjà établie dans un championnat fictif : une moyenne isolée n’est pas présentée
comme un seuil universel.

## Fiches de scénario

Le schéma et les liens de lecture proviennent de `FootballScenarioCatalog`.
Ils identifient le sujet concerné : même équipe, match, adversaire ou au moins
une équipe. Une fiche de scénario donne accès aux explications de chaque
lecture requise, y compris celles qui ne sont pas des préférences séparées.

L’exemple interactif alterne entre toutes les conditions réunies et une
condition manquante. Le verdict est calculé par `FootballScenarioDetector`,
sans créer un deuxième moteur de détection. Il illustre une combinaison de
lectures déjà détectées et ne simule pas un résultat de match.

## Vérification

- Couverture éditoriale de toutes les lectures sélectionnables et de toutes
  les dépendances de scénario.
- Exemples complets et incomplets vérifiés par le vrai détecteur.
- Rejet d’un exemple mélangeant les avantages de deux équipes.
- Navigation vers la bonne lecture et consultation sans modification du suivi.
- Présentation sur écran de 320 pixels avec texte agrandi dans les dix thèmes.

Aucune migration SQL, collecte ou publication de données n’est nécessaire.
