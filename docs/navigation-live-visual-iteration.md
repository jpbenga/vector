# Navigation et rencontres : évolution ciblée

La branche multisport conserve header, calendrier, cards, logos, lectures et parcours. Les composants communs portent les changements de navigation, filtres et scores.

- Radar : forme inclinée, vert uni ; Générateur : forme inclinée, violet uni. Le fond de fonctionnalité est permanent ; seul le marqueur inférieur et l'état sémantique indiquent la sélection. Cinq destinations dans l'ordre existant, dimensions vérifiées à 320/360/390 px.
- Filtres : fond accentué, bordure et texte contrastés pour la sélection. Le point Live demeure rouge indépendamment de la sélection.
- Scores : fond rouge sombre discret uniquement pendant le live. Scores finaux neutres avec état Terminé. Horaires et cotes à venir conservés.
- Form Radar : historique gelé avant le coup d'envoi, contributions actuelles séparées. En-tête vert plein, nombre de joueurs signalés décisifs et buts/passes horodatés. Après match, fond atténué et mention Terminé. Aucun taux ou garantie de prédiction.

## Preuves d'avant-match

`form_radar_match_snapshots` est alimentée par les publications immuables football et hockey. Le serveur sélectionne les profils qualifiés sur les trois derniers matchs, avec au moins deux contributions ; les profils de chaque équipe doivent appartenir au dernier historique publié. Les profils et cellules sont enregistrés avant le coup d'envoi. Une publication plus récente peut actualiser un match encore à venir ; la preuve devient figée après son coup d'envoi.

L'installation initialise uniquement les rencontres encore à venir. Elle ne reconstitue aucune détection passée. Sans preuve d'avant-match ou événement confirmé, aucun bandeau de confirmation n'est produit. Les contributions historiques ne changent pas quand un joueur est décisif dans le match suivi.

`form_radar_for_fixtures` expose uniquement les preuves publiques, par lots de 500. Aucun droit d'écriture aux comptes clients. Les transports consultent ce lot en parallèle des scores, avec un délai borné et conservation des preuves reçues si le service est indisponible.

Football : identifiant joueur + équipe, événements Goal, hors buts contre son camp, penalties ratés et séance de tirs au but. Hockey : nom exact + équipe, périodes P1/P2/P3/OT ; pas d'attribution floue à un homonyme. Le format hockey conserve la période et la minute fournie, sans fabriquer de secondes.

Les événements hockey des rencontres avec joueurs repérés utilisent le collecteur existant, jusqu'à quatre appels par passage, cinq minutes entre lectures live et une heure pour les corrections finales dans les 24 premières heures. Les quotas de 3 000 appels live et 7 500 appels totaux par jour sont inchangés. Un échec ne bloque pas les scores. La précédente liste d'événements est conservée quand un passage ne la relit pas.

## Validation

Tests mobiles : cinq libellés, sélection unique, transitions live/final et cellules historiques inchangées. Tests SQL : qualification, actualisation avant match, gel après kickoff, absence de preuve reconstruite après coup et permissions de lecture seule. Tests du collecteur : identité, quota, données invalides et conservation des scores.
