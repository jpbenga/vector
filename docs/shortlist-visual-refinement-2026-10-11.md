# Shortlist — refonte du 11 octobre 2026

## Contrat de réalisation

Demande : reprendre l’écran Ma Shortlist selon la maquette fournie par l’utilisateur. Surface de préparation (Operate), extension locale du système Lector. Aucun nouveau monde visuel ni changement global n’a été approuvé. Le contrat produit reste [Shortlist — session de préparation](shortlist-preparation.md) ; le dépôt Flutter ne contient pas de `PRODUCT.md` ni de `DESIGN.md` à la racine.

Référence fournie : `/tmp/codex-remote-attachments/01a0aaf1-05e5-7562-8f19-7332ea8701f5/1C2E721E-FD45-412C-8803-9C45B07F7D40/1-Photo-1.jpg`.

Artefacts de l’écran : [shortlist_page.dart](../lib/features/shortlist/presentation/shortlist_page.dart), [shortlist_widgets.dart](../lib/features/shortlist/presentation/shortlist_widgets.dart) et [shortlist_view.dart](../lib/features/shortlist/presentation/shortlist_view.dart). Les cartes de rencontres des autres écrans restent hors de cette refonte.

### Premier écran

Titre avec compteur, retour et actions. Session compacte, échéance réelle toujours visible et jauge statique. Quatre catégories comptées. Tri et filtre. Cartes denses, identité des deux équipes, compétition, horaire, cases distinctes des signets. Actions de travail fixes, puis les cinq destinations existantes.

### Identité et interactions

Couleurs et typographie du thème Lector conservées, accent turquoise local à la Shortlist et violet plein sur Préparer un ticket. Le mode clair reste disponible. Le signet rempli indique l’appartenance à la liste ; la case cochée indique le sous-ensemble à travailler. Le retrait demande l’opération serveur existante. Les filtres ne détruisent pas la sélection et Tout sélectionner agit sur les rencontres visibles. Comparer est activé seulement pour deux rencontres ; préparer exige au moins une rencontre à venir. Les exclusions sportives sont expliquées par le Générateur existant.

Les cinq destinations du bas reviennent au workspace du sport courant sans modifier sa date. Il n’existe aucun faux onglet actif sur cet écran secondaire.

### Données

Les lectures et drapeaux sont issus des publications football/hockey. Le serveur transmet seulement les identifiants, intitulés et indicateurs de contradiction des lectures, sans copier les statistiques volumineuses. Les badges Forme +, Avantage et Vigilance décrivent les familles de lectures présentes ; aucune probabilité ni recommandation supplémentaire n’est inventée. Vigilance est prioritaire lorsque plusieurs familles sont présentes, y compris lorsque la carte n’affiche que deux badges. Équilibre n’est pas affiché faute de lecture correspondante. Les données des anciens caches indiquent Lectures à actualiser jusqu’à leur résolution serveur.

Les rencontres Reportées, Annulées et Indisponibles restent consultables, avec leur état explicite et la mention d’exclusion des tickets prématch. L’horaire n’est pas présenté comme une disponibilité lorsque le statut ne la permet pas.

### Adaptation

Cartes et contenu limités à 544 px sur ordinateur. Catégories défilantes sur les téléphones étroits ; actions empilées sous 345 px de largeur disponible ou avec texte agrandi. Dans les cartes sous 340 px ou avec texte agrandi, l’horaire et les actions passent sous les équipes, dont les noms peuvent occuper plusieurs lignes. Les actions Voir et Retirer ont des cibles d’au moins 48×48 px et des libellés accessibles. Navigation clavier fournie par les composants Material. Animation de bottom sheet partagée avec Lector ; la jauge du temps restant ne comporte pas d’animation permanente.

## Rattachement au système existant

La comparaison s’appuie sur [theme-application.md](theme-application.md), [app_colors.dart](../lib/core/theme/app_colors.dart), [app_typography.dart](../lib/core/theme/app_typography.dart), [app_spacing.dart](../lib/core/theme/app_spacing.dart) et [app_radius.dart](../lib/core/theme/app_radius.dart). Ces sources restent l’autorité pour les autres surfaces ; cette page documente seulement la composition de la Shortlist.

| Élément | Système existant et preuve locale |
| --- | --- |
| Surfaces et texte | Fond, surface secondaire, bordures, textes et couleurs sémantiques proviennent du thème courant via ses extensions. Les captures sombre et claire confirment les deux rendus. |
| Typographie | Police Inter héritée ; noms d’équipes à 13 px, poids 700, métadonnées compactes. Aucune nouvelle police. |
| Couleurs métier | Forme + reprend l’accent Radar ; Avantage l’accent Générateur ; Vigilance la couleur warning du thème. |
| Accent Shortlist | Turquoise `AppColors.accent` en sombre (#2FE6D3), `AppLightColors.accent` en clair (#0D8179), cohérent avec la référence. Il s’agit d’une identité locale indépendante de l’accent sélectionnable de l’application. |
| Profondeur | Surfaces et bordures, sans nouvelle ombre décorative ; teinte légère et bordure turquoise pour la sélection. |
| Composition | Colonne unique et panneau d’actions fixe ; la limite de 544 px évite d’étirer les cartes sur ordinateur. |

### Écarts consignés

La documentation du thème signale déjà une dette de couleurs directes, de tailles locales et d’usage incomplet d’AppSpacing. La Shortlist contient également des choix locaux : violet plein du CTA (#692CB4 en sombre, #6630A5 en clair), rayons de cartes à 16 px et de CTA à 13 px, au lieu des tokens généraux de 18 et 14 px, ainsi que des espacements et tailles intermédiaires. Le violet est une valeur locale codée en dur ; sa centralisation prévue par les règles générales de thème reste un écart constaté.

Ces observations ne constituent pas de nouveaux tokens ni des règles globales. Aucun fichier de thème, `DESIGN.md`, sidecar `.impeccable/design.json` ou skill n’est créé ou réparé par ce passage documentaire. La structure, les chiffres, les horaires et les rencontres de la maquette sont une référence illustrative, sans valeur de données sportives réelles.

## Preuves de vérification

Les quatre captures proviennent du véritable widget Flutter avec des fixtures synthétiques. Les dimensions ci-dessous sont celles du viewport ; les fichiers sont rendus à une densité de 2×.

| Scène | Preuve | Ce qu’elle permet de vérifier |
| --- | --- | --- |
| Téléphone 393×852, sombre | [phone.png](../output/shortlist-refinement/phone.png) | Hiérarchie, session, compteurs, cartes, sélection et panneau d’actions. |
| Téléphone étroit 320×844, sombre | [narrow.png](../output/shortlist-refinement/narrow.png) | Catégories défilantes, cartes réorganisées et actions empilées. |
| Ordinateur 1440×900, sombre | [desktop.png](../output/shortlist-refinement/desktop.png) | Colonne centrée et largeur de lecture limitée. |
| Téléphone 320×844, texte 1,5×, clair | [large-text.png](../output/shortlist-refinement/large-text.png) | Texte agrandi, thème clair, retours à la ligne et accès aux actions. |

Les captures utilisent des initiales de remplacement pour les logos et des icônes de remplacement pour les drapeaux. En utilisation réelle SportsAssetBadge conserve les assets publiés. Aucun appel IA ni collecte auprès du fournisseur de données sportives n’a été exécuté pour ces vérifications. Ces rendus ne prouvent pas une session connectée sur appareil physique.

La revue finale Impeccable a donné la disposition **ship** après un verdict **pass** sur les quatre correctifs :

| Correctif | Résolution constatée |
| --- | --- |
| Vigilance prioritaire | Insérée en tête dans `readingTags`, elle reste visible parmi les deux badges retenus. |
| Noms avec texte agrandi | Mise en page étendue et noms sur plusieurs lignes dans les cartes. |
| Statuts explicites | Reporté, Annulé et Indisponible sont distingués, avec exclusion prématch. |
| Cibles d’action | Voir et Retirer imposent une cible de 48×48 px minimum. |

Les quatre observations sont résolues. Validation communiquée à la clôture de la revue : analyse Flutter complète **No issues found** ; **84 tests** de parcours football/hockey réussis ; **4 tests ciblés** de raffinement, dont les statuts, réussis ; test SQL des lectures et de l’isolation par propriétaire **1 réussi** ; test des gardes d’installation **1 réussi**. Les tests de tri, filtres et sélection vérifient notamment la conservation des sélections masquées et l’absence de mutation lors de la navigation.

Limite conservée : aucun essai sur appareil physique pour cette refonte. Les autres variantes de thème ne disposent pas de captures dédiées dans ce lot.

## Statut de publication

La refonte est validée pour livraison. Son déploiement est **en cours** au moment de cette documentation ; aucun déploiement final ni contrôle du site publié n’est attesté ici. Le reçu de publication de la V1 dans [shortlist-preparation.md](shortlist-preparation.md) décrit la version antérieure et ne vaut pas preuve de publication de cette refonte.
