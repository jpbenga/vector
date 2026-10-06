# Audit et correction des classements football / hockey

Mise à jour du 6 octobre : les classements domicile/extérieur par points sont
désormais reconstruits à partir des résultats de saison, et les deux groupes
d'une opposition entre conférences apparaissent dès l'ouverture. Voir
[l'audit complémentaire](2026-10-06-home-away-standings.md). Le bilan sans points
décrit ci-dessous correspond à l'étape précédente.

## Périmètre

Branche `codex/multisport-hockey`, corrections locales. Référence : le classement football dans `match_detail_page.dart`. Cet audit ne publie ni main ni la démo et ne modifie aucun service Supabase.

## Pourquoi les différences étaient possibles

Les sports utilisaient les mêmes petites briques (`LectorStandingRow`, `LectorStandingTeam`, etc.), mais construisaient chacun la carte, les sélecteurs, les colonnes et les groupes. Le partage ne couvrait donc pas le composant complet. Ajouter des badges hockey dans cet assemblage séparé ne suffisait pas : la précédente correction employait D/X alors que la référence football emploie DOM./EXT.

| Élément | Constat avant correction | Correction |
| --- | --- | --- |
| Carte et contrôles | Assemblages indépendants | `LectorStandingPanel` possède le titre, les espacements, la carte et les contrôles communs |
| Tableau | Chaque sport crée ses lignes et cellules | `LectorStandingDataTable` reçoit uniquement colonnes, cellules factuelles et annotations |
| Domicile / extérieur | Badge et couleur fournis par chaque sport | `LectorStandingRole` définit DOM./EXT. et les couleurs une seule fois ; les adaptateurs transmettent l’identité réelle de l’équipe |
| Tiers et zones officielles | Deux légendes et palettes | `LectorStandingLegend` et `lectorStandingTierColor` communs ; règles d’attribution propres aux sports |
| Ordre hockey | Réordonné selon les tiers / points par match malgré un rang officiel affiché | Ordre des positions fourni par l’API, à l’intérieur de chaque phase et groupe |
| Domicile / extérieur hockey | Rang calculé par taux de victoire, colonne % V | Bilan factuel sans pourcentage ni rang inventé ; points / position indisponibles explicites |
| Buts et zones hockey | Présents dans le brut mais absents du compact | Transmission et décodage de BP, BC et description officielle ; absence conservée comme inconnue |

## Origine précise du pourcentage

Le classement général `/standings` contient `position` et `points`, ainsi que le détail victoires/défaites en temps réglementaire et prolongation. Ces points ne nécessitent aucune reconstruction.

Les vues domicile/extérieur viennent de `/teams/statistics`. L’enrichissement les triait par `wins / played`, attribuait un rang calculé, puis l’écran affichait `% V`. C’était une décision de notre implémentation. Ce ratio ne répond pas à la demande d’un classement par points.

Exemple brut KHL (Yekaterinburg, ligue 35 / équipe 388) : domicile 5 matchs, 3 victoires, 2 défaites ; extérieur 7 matchs, 2 victoires, 5 défaites. Le bilan fournit aussi les buts. Il ne donne ni points par lieu ni ventilation des résultats après prolongation. Les phases peuvent être mélangées.

Il est donc impossible de retrouver les points officiels domicile/extérieur avec ces seules sommes : multiplier toutes les victoires par deux ou trois produirait un résultat potentiellement faux. L’écran conserve J/V/D/BP/BC/Diff, affiche `—` pour position et points, et présente les équipes alphabétiquement avec une explication. Les badges DOM./EXT. désignent toujours le lieu du match consulté, indépendamment de la vue choisie.

Pour produire ensuite un vrai classement par points domicile/extérieur, il faudra collecter les résultats complets de la saison et de la phase concernée, connaître le statut réglementaire/prolongation/tirs au but de chaque rencontre, appliquer le barème de la compétition, puis garantir la couverture complète et les éventuels ajustements officiels. Ce chantier n’est pas remplacé par un ratio.

## Ce qui reste spécifique à chaque sport

- Football : nuls, classements forme/attaque/défense/xG et autres vues réellement disponibles, préférences des lectures/scénarios, règles des zones officielles existantes.
- Hockey : conférences/divisions et phases du fournisseur, pas de colonne N dans ces classements, V/D incluant les résultats après prolongation, points officiels de chaque ligue.
- Les tiers hockey restent un aperçu exploratoire fondé sur les points par match, avec les garde-fous existants (au moins cinq matchs, calendrier suffisamment équilibré et rupture de 0,45). Ils ne réordonnent pas les positions officielles et ne déclenchent pas de lectures.

Le composant visuel et le comportement des contrôles sont communs ; la configuration des colonnes et les calculs restent des données des adaptateurs.

## Données locales

197 lignes du snapshot `1ac3b7ed-761e-4338-b486-59355459dec8`, capturé le 5 octobre à 17:08:08.900 UTC, ont reçu BP/BC/description depuis les réponses brutes de cette même collecte. Une vérification a exigé l’égalité de la saison, phase, groupe, équipe, position, points et matchs joués avant chaque enrichissement. Aucun nouvel appel API. Les scores, joueurs, préférences et horodatages de collecte n’ont pas été remplacés. Le collecteur conserve maintenant ces champs pour les publications suivantes.

## Vérifications

- Tests widget hockey : DOM./EXT. dans les trois vues à 360 et 1100 px ; identité conservée après changement de conférence et inversion domicile/extérieur.
- Contrôle d’architecture : échec si un fichier de fonctionnalité reconstruit directement les lignes/cellules du classement partagé.
- Ordre officiel conservé même lorsque l’équipe classée deuxième a plus de points par match ; points officiels inchangés ; aucune fabrication de points domicile/extérieur.
- Décodage : points, buts et description conservés ; buts absents inconnus et valeur négative rejetée.
- Football à 360 px : même carte/table/légende, vrais tiers dynamiques, zones officielles et DOM./EXT. ; aucun défilement horizontal ajouté au tableau.
- Données hockey réelles : classements domicile/extérieur, onglet confrontations et événements à 360 et 1100 px, sans débordement.
- Design system : tokens et règles de couleurs/rayons vérifiés.
- 35 tests Flutter réussis (34 hockey/données/design system et 1 classement football).
- 13 tests Deno réussis (publication NHL, sept ligues, champs du classement et enrichissement).
- Analyse Flutter sans problème.

Ces tests protègent les contrats contrôlés ; ils ne constituent pas une garantie de disponibilité future des données du fournisseur. Le manque de points domicile/extérieur est affiché comme tel.
