# Comparateur de classement hockey — 9 octobre 2026

Branche : `codex/multisport-hockey`. Itération destinée à la démo multisport.

## Diagnostic de Washington–New York

La publication hockey capturée le 9 octobre à 12:04:07 UTC contient six tableaux NHL : deux conférences de seize équipes et quatre divisions de huit équipes. Le détail public Supabase `read_sport_feed` du match Washington Capitals–New York Rangers, identifiant `444663`, restitue ces mêmes six tableaux. Les deux équipes appartiennent à Metropolitan Division et Eastern Conference.

La livraison statique conserve également les tableaux complets. Aucun retrait de lignes n'a été observé dans cette source. L'ancienne vue privilégiait le plus petit groupe commun et cachait l'accès à la conférence dans le sélecteur : le diagnostic porte sur la visibilité et le choix de niveau. Il ne prouve pas l'état exact de l'écran vu par l'utilisateur.

## Parcours

- Vue du match : division commune si elle existe ; sinon conférence commune ; sinon deux conférences complètes côte à côte. En absence de hiérarchie attestée, repli sur les groupes réels disponibles.
- Divisions / Conférences : accès direct aux tableaux complets des adversaires. Un tableau unique lorsque le groupe est commun ; deux tableaux compacts lorsque les groupes diffèrent.
- Tous les classements : sélecteur permanent contenant tous les groupes de la compétition, leurs nombres d'équipes, leurs parents vérifiés et les rôles DOM./EXT.
- Général / Domicile / Extérieur : conservés dans toutes les vues. Les rangs calculés par lieu sont explicitement distingués des rangs officiels. Retour à la vue du match avec conservation du périmètre.

Chaque tableau réutilise `LectorStandingDataTable`, ses lignes compactes, ses logos, ses surlignages, ses badges et ses bandes de tiers. Aucune limite sur le nombre de lignes n'est introduite.

## Faits et interprétation

Les positions de division et de conférence sont affichées séparément. Le repère commun utilise les points par match, la différence de buts lorsqu'elle est disponible, l'écart numérique de rendement et la moyenne de ligue pondérée par les matchs joués, sans compter plusieurs fois une équipe.

Pour les oppositions entre groupes, ce repère apparaît avant les tableaux complets. Les barèmes à deux ou trois points proviennent du contexte de compétition existant ; aucune équivalence NHL/KHL/SHL n'est supposée.

La synthèse « Lecture du contexte Lector » est descriptive : meilleur rendement comptable, éventuelle inversion de l'impression donnée par les rangs locaux, faible volume de résultats, bilan domicile/extérieur et forme récente uniquement si la phase et les cinq résultats finaux sont vérifiés. Elle ne prétend pas mesurer la force intrinsèque ni neutraliser la qualité des adversaires. La forme NHL dont la phase n'est pas attestée demeure explicitement exclue.

Les lectures automatiques validées et leurs seuils de tiers ne sont pas modifiés. Un futur signal inter-conférences doit recevoir une politique distincte et validée ; un rang local ou un simple écart de points par match ne déclenche pas « avantage au classement ».

## Données manquantes

Un tableau domicile/extérieur dont un membre officiel manque n'est plus rendu comme un classement complet tronqué. L'écran signale l'indisponibilité du tableau dans ce périmètre. Le classement général reste consultable. Aucune ligne, aucun point et aucune position ne sont inventés. La moyenne de ligue reste indisponible si les bilans ne couvrent pas tous ses membres. Zéro match joué donne un rendement indéfini, jamais une fausse valeur de zéro.

Le classement affiché est celui de la dernière collecte, pas une reconstitution historique au moment du match. La date et cette limite restent visibles.

## Références et vérification

Les rangs officiels du fournisseur sont conservés. Les départages domicile/extérieur calculés localement ne sont pas présentés comme les départages officiels NHL. Référence : [procédure NHL](https://www.nhl.com/info/standings-info/tie-breaking-procedure).

Tests des trois relations, de Washington–Rangers (8/16 membres), de jeux inégaux inversant l'impression des rangs, des bilans incomplets, des trois périmètres, des rôles, des tiers et des parcours à 320, 390 et 1100 pixels. Rendu des vrais composants Flutter à 390 pixels dans `tool/render_hockey_standing_comparison_test.dart`. Aucun nouvel appel fournisseur, migration SQL ou changement de politique de lecture n'est nécessaire pour cette itération.
