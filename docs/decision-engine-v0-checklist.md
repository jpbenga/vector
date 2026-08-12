# Checklist moteur d'analyse V0

## Validation produit

- [x] Le moteur consomme un `CompiledDecisionProfile`, jamais les réponses
  d'onboarding brutes.
- [x] Le profil compilé est versionné avec `profile_schema_version`.
- [x] Les compétitions activées agissent comme filtre de l'accueil personnalisé.
- [x] Les marchés activés agissent comme filtre d'éligibilité.
- [x] Les seuils de cote utilisateur agissent comme filtre d'éligibilité.
- [x] `Tous les matchs` reste exhaustif et ne supprime pas les rencontres.
- [x] Une rencontre non recommandée reste explicable dans le détail.
- [x] Les cotes ne sont pas interprétées comme probabilité de réussite.
- [x] Les signaux affichent des preuves lisibles et auditables.
- [x] Les données manquantes produisent un message de prudence, pas une fausse
  certitude.
- [x] Les statistiques d'équipe peuvent compléter les classements absents.
- [x] Le moteur détecte une thèse avant de sélectionner un marché.
- [x] Une cote ne peut pas créer seule une recommandation.
- [x] Une thèse sans marché jouable reste en surveillance, pas recommandée.
- [x] `Aucune thèse suffisante` est un résultat produit possible.
- [x] Le profil onboarding peut être sauvegardé localement pour le développement.

## Validation technique

- [x] Le compilateur applique les valeurs par défaut quand une réponse manque.
- [x] Les options non sélectionnées restent présentes avec `enabled = false`.
- [x] Les priorités sont transformées en poids déterministes.
- [x] Les marchés onboarding sont mappés vers les IDs internes normalisés.
- [x] `raw.team_statistics` est normalisé vers `TeamStatisticsSnapshot`.
- [x] Le moteur est déterministe à entrée identique.
- [x] Le repository, pas l'UI, applique le moteur.
- [x] Le détail match reçoit une lecture personnalisée déjà calculée.
- [x] Les tests couvrent filtres compétition, marché, seuil de cote et signaux.
- [x] Les tests couvrent recommandation par thèse et restauration du profil.
- [x] `flutter analyze` passe.
- [x] `flutter test` passe.
