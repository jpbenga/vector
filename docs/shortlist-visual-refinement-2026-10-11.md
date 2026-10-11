# Shortlist — refonte du 11 octobre 2026

## Contrat de réalisation

Demande : reprendre l’écran Ma Shortlist selon la maquette fournie par l’utilisateur. Surface de préparation (Operate), extension locale du système Lector. Aucun nouveau monde visuel ni changement global n’a été approuvé. Le contrat produit reste [Shortlist — session de préparation](shortlist-preparation.md) ; le dépôt Flutter ne contient pas de `PRODUCT.md` ni de `DESIGN.md` à la racine.

Référence fournie : `/tmp/codex-remote-attachments/01a0aaf1-05e5-7562-8f19-7332ea8701f5/1C2E721E-FD45-412C-8803-9C45B07F7D40/1-Photo-1.jpg`.

Artefacts de l’écran : [shortlist_page.dart](../lib/features/shortlist/presentation/shortlist_page.dart), [shortlist_widgets.dart](../lib/features/shortlist/presentation/shortlist_widgets.dart) et [shortlist_view.dart](../lib/features/shortlist/presentation/shortlist_view.dart). Les cartes de rencontres des autres écrans restent hors de cette refonte.

### Premier écran

Titre avec compteur, retour et actions. Session compacte, échéance réelle toujours visible et jauge statique. Liste unique, sans catégories d’état. Tri et filtre. Cartes denses, identité des deux équipes, compétition, horaire, sous-sélection et corbeille propre à chaque rencontre. Actions de travail fixes, sans navigation dupliquée.

### Identité et interactions

Couleurs et typographie du thème Lector conservées, accent turquoise local à la Shortlist et violet plein sur Préparer un ticket. Le mode clair reste disponible. Dans les listes sources, le signet rempli indique l’appartenance à la Shortlist ; son changement d’état suffit et ne produit aucun message de succès. Dans Ma Shortlist, la case cochée indique le sous-ensemble à travailler et la corbeille retire uniquement la rencontre de sa carte via l’opération serveur existante. Les erreurs restent signalées. Les filtres ne détruisent pas la sélection et Tout sélectionner agit sur les rencontres visibles. Comparer est activé seulement pour deux rencontres ; préparer exige au moins une rencontre à venir. Les exclusions sportives sont expliquées par le Générateur existant.

La navigation dupliquée du bas est supprimée, ainsi que son raccord spécifique. Le retour conserve le workspace d’origine et sa date ; la barre principale de Lector reste inchangée.

### Données

Les lectures et drapeaux sont issus des publications football/hockey. Le serveur transmet seulement les identifiants, intitulés et indicateurs de contradiction des lectures, sans copier les statistiques volumineuses. Les badges de synthèse Forme +, Avantage et Vigilance sont retirés à la demande de l’utilisateur. Seul le nombre de lectures réellement publiées est affiché. Les données des anciens caches indiquent Lectures à actualiser jusqu’à leur résolution serveur.

Les rencontres Reportées, Annulées et Indisponibles restent consultables, avec leur état explicite et la mention d’exclusion des tickets prématch. L’horaire n’est pas présenté comme une disponibilité lorsque le statut ne la permet pas.

### Adaptation

Cartes et contenu limités à 544 px sur ordinateur. Actions empilées sous 345 px de largeur disponible ou avec texte agrandi. Dans les cartes sous 340 px ou avec texte agrandi, l’horaire et les actions passent sous les équipes, dont les noms peuvent occuper plusieurs lignes. Les actions Voir et Retirer ont des cibles d’au moins 48×48 px et des libellés accessibles. Navigation clavier fournie par les composants Material. Animation de bottom sheet partagée avec Lector ; la jauge du temps restant ne comporte pas d’animation permanente.

## Rattachement au système existant

La comparaison s’appuie sur [theme-application.md](theme-application.md), [app_colors.dart](../lib/core/theme/app_colors.dart), [app_typography.dart](../lib/core/theme/app_typography.dart), [app_spacing.dart](../lib/core/theme/app_spacing.dart) et [app_radius.dart](../lib/core/theme/app_radius.dart). Ces sources restent l’autorité pour les autres surfaces ; cette page documente seulement la composition de la Shortlist.

| Élément | Système existant et preuve locale |
| --- | --- |
| Surfaces et texte | Fond, surface secondaire, bordures, textes et couleurs sémantiques proviennent du thème courant via ses extensions. Les captures sombre et claire confirment les deux rendus. |
| Typographie | Police Inter héritée ; noms d’équipes à 13 px, poids 700, métadonnées compactes. Aucune nouvelle police. |
| Lectures | Compteur réel uniquement ; les badges de synthèse de la maquette sont retirés. |
| Accent Shortlist | Turquoise `AppColors.accent` en sombre (#2FE6D3), `AppLightColors.accent` en clair (#0D8179), cohérent avec la référence. Il s’agit d’une identité locale indépendante de l’accent sélectionnable de l’application. |
| Profondeur | Surfaces et bordures, sans nouvelle ombre décorative ; teinte légère et bordure turquoise pour la sélection. |
| Composition | Colonne unique et panneau d’actions fixe ; la limite de 544 px évite d’étirer les cartes sur ordinateur. |

### Écarts consignés

La documentation du thème signale déjà une dette de couleurs directes, de tailles locales et d’usage incomplet d’AppSpacing. La Shortlist contient également des choix locaux : violet plein du CTA (#692CB4 en sombre, #6630A5 en clair), rayons de cartes à 16 px et de CTA à 13 px, au lieu des tokens généraux de 18 et 14 px, ainsi que des espacements et tailles intermédiaires. Les couleurs locales de Shortlist et du CTA sont centralisées dans AppFeatureColors et exposées par AppFeaturePalette. Les arrondis canoniques utilisent AppRadius ; les valeurs intermédiaires restent propres à cette composition.

Cette extension de palette conserve exactement les couleurs validées lors de la revue. Elle ne modifie pas les autres surfaces. Aucun `DESIGN.md`, sidecar `.impeccable/design.json` ou skill n’est créé par ce passage documentaire. La structure, les chiffres, les horaires et les rencontres de la maquette sont une référence illustrative, sans valeur de données sportives réelles.

## Preuves de vérification

Les quatre captures proviennent du véritable widget Flutter avec des fixtures synthétiques. Les dimensions ci-dessous sont celles du viewport ; les fichiers sont rendus à une densité de 2×.

| Scène | Preuve | Ce qu’elle permet de vérifier |
| --- | --- | --- |
| Téléphone 393×852, sombre | [phone.png](../output/shortlist-refinement/phone.png) | Hiérarchie, session, compteur de rencontres, cartes, sélection et panneau d’actions. |
| Téléphone étroit 320×844, sombre | [narrow.png](../output/shortlist-refinement/narrow.png) | Liste unique, cartes réorganisées et actions empilées. |
| Ordinateur 1440×900, sombre | [desktop.png](../output/shortlist-refinement/desktop.png) | Colonne centrée et largeur de lecture limitée. |
| Téléphone 320×844, texte 1,5×, clair | [large-text.png](../output/shortlist-refinement/large-text.png) | Texte agrandi, thème clair, retours à la ligne et accès aux actions. |

Les captures utilisent des initiales de remplacement pour les logos et des icônes de remplacement pour les drapeaux. En utilisation réelle SportsAssetBadge conserve les assets publiés. Aucun appel IA ni collecte auprès du fournisseur de données sportives n’a été exécuté pour ces vérifications. Ces rendus ne prouvent pas une session connectée sur appareil physique.

La revue de la première refonte, avant les corrections utilisateur ci-dessous, a donné la disposition **ship** après un verdict **pass** sur les quatre correctifs :

| Correctif | Résolution constatée |
| --- | --- |
| Vigilance prioritaire | Insérée en tête dans `readingTags`, elle reste visible parmi les deux badges retenus. |
| Noms avec texte agrandi | Mise en page étendue et noms sur plusieurs lignes dans les cartes. |
| Statuts explicites | Reporté, Annulé et Indisponible sont distingués, avec exclusion prématch. |
| Cibles d’action | Voir et Retirer imposent une cible de 48×48 px minimum. |

Les quatre observations sont résolues. Validation communiquée à la clôture de la revue : analyse Flutter complète **No issues found** ; **84 tests** de parcours football/hockey réussis ; **4 tests ciblés** de raffinement, dont les statuts, réussis ; test SQL des lectures et de l’isolation par propriétaire **1 réussi** ; test des gardes d’installation **1 réussi**. Les tests de tri, filtres et sélection vérifient notamment la conservation des sélections masquées et l’absence de mutation lors de la navigation.

Après centralisation des couleurs et arrondis, les **36 tests** du thème et de la Shortlist passent, y compris les quatre contrôles statiques de la CI qui avaient signalé les déclarations locales. L’analyse Flutter ne signale aucune anomalie. Les quatre PNG sont identiques octet pour octet aux rendus approuvés avant cette centralisation. La [CI complète de la révision 2f221c0](https://github.com/jpbenga/vector/actions/runs/38173169507) réussit pour Flutter et les fonctions Supabase.

Limite conservée : aucun essai sur appareil physique pour cette refonte. Les autres variantes de thème ne disposent pas de captures dédiées dans ce lot.

## Statut de publication

La [mise à jour serveur](https://github.com/jpbenga/vector/actions/runs/38173419815) est installée depuis la révision `2f221c0c81986676a6a064f4d430fbe80a137324`. Les deux migrations de Shortlist sont vérifiées ; le nouvel enrichissement des cartes est actif. Le reçu confirme : accès anonyme refusé (401), lecture serveur autorisée, lecture du propriétaire étranger et écriture directe refusées, nettoyage horaire actif, zéro appel de modèle payant, zéro appel fournisseur et aucun secret modifié.

Compilation release réussie : 457,3 secondes ; paquet complet contrôlé, avec script vocal, manifestes et polices. Déploiement Vercel `dpl_DMXqb4KQKaiQSaYUSDR6HXCHGnpH`, état READY, sur [lector-sports-go54elz7f-lector1.vercel.app](https://lector-sports-go54elz7f-lector1.vercel.app/). L’alias public [démo](https://lector-sports-demo-lector1.vercel.app/) pointe vers ce déploiement. Une navigation neuve dans le navigateur atteint l’application et l’état invité de Ma Shortlist, sans écran d’authentification Vercel ; la connexion Lector reste requise pour accéder à la préparation personnelle. Le reçu de publication de la V1 dans [shortlist-preparation.md](shortlist-preparation.md) décrit la version antérieure et ne vaut pas preuve de publication de cette refonte.

### Contrôle du site publié

Contrôle navigateur à 393×852 : nouvelle application chargée et écran Ma Shortlist atteint, sans connexion Vercel. Le navigateur de vérification ne dispose pas de session Lector connectée ; le contrôle publié porte donc sur l’état invité, pas sur une préparation personnelle réelle. Les données, cartes et actions connectées sont couvertes par les tests de widgets et SQL décrits ci-dessus. Aucune rencontre personnelle n’a été ajoutée, retirée ou prolongée pendant ce contrôle. Le format du navigateur a été restauré après vérification.

![Ma Shortlist publiée — état invité](/Users/chloe/.codex/visualizations/2026/09/16/01a0aaf1-05e5-7562-8f19-7332ea8701f5/shortlist-published-2026-10-11.jpg)

## Simplification demandée après essai de la démo

Référence : captures utilisateur du 11 octobre, répertoire `05CE9087-F0BA-4EB3-B2BA-0E8FF86F20F8`. Cette correction remplace les catégories et badges de la première refonte.

- Suppression des badges de synthèse Forme +, Avantage et Vigilance.
- Ajout et retrait silencieux dans toutes les listes sources, avec état du signet et maintien des messages d’erreur.
- Une liste unique : rencontres à venir, en direct, terminées ou indisponibles restent consultables et affichent leur état. L’éligibilité prématch reste contrôlée.
- Suppression de la navigation dupliquée et de son infrastructure devenue inutilisée.
- Suppression des boutons Vider et remplacement du signet de chaque carte par une corbeille explicite. La mutation remove cible un identifiant sport/rencontre ; elle ne vide pas la session.
- Sous-sélection, comparaison, préparation, tri, filtres, prolongation et données personnelles conservés.

Vérification locale : 107 tests de Shortlist, thème et parcours football/hockey réussis ; le test adapté du signet vérifie aussi ajout/retrait silencieux et état rempli. Analyse Flutter : No issues found. Les quatre captures ci-dessus sont régénérées depuis le widget corrigé ; aucun débordement observé à 393 px, 320 px, 1440 px et avec texte 1,5×. Aucun appel IA ni collecte fournisseur. Le reçu de publication de cette correction sera ajouté après livraison.
