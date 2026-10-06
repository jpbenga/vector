# Classements hockey : contexte de l’opposition et exploration des groupes

Branche : `codex/multisport-hockey`. Version locale, sans push ni déploiement.

## Parcours implémenté

1. Vue du match : positions dans les groupes officiels les plus précis, badges EXT./DOM., points et matchs joués, rendement en points par match sur une échelle commune et moyenne pondérée de la ligue.
2. Sélecteur en feuille mobile : vue du match, conférences, divisions rangées sous leur parent lorsqu’il est attesté par les équipes du classement. Sélection immédiate, sans confirmation ni rang général inventé.
3. Groupe sélectionné : équipe(s) du match mises en évidence, tableau complet partagé avec le football, points par match, V/D/OT expliqués, bilan contre les autres groupes et navigation vers le groupe de l’autre adversaire.

Les trois périmètres Général/Domicile/Extérieur restent accessibles dans chaque vue. Les rangs domicile/extérieur sont recalculés dans le groupe sélectionné. Le badge représente toujours le rôle dans la rencontre consultée, indépendamment du périmètre du tableau.

## Calculs et garde-fous

- Les résultats de saison déjà collectés alimentent le classement par lieu et les comparaisons entre groupes. Un seul jeu de matchs et une seule politique d’inclusion et de points sont utilisés.
- Les totaux sont confrontés aux classements officiels : matchs joués, points, victoires/défaites en temps réglementaire et après prolongation/tirs au but, buts lorsque disponibles.
- Si le classement officiel retarde sur les matchs, on conserve le même préfixe vérifié de résultats pour les deux adversaires. Matchs à venir, live et hors fenêtre de saison régulière sont exclus.
- Une rencontre contre un autre groupe compte une fois pour l’équipe du groupe concerné. Les rencontres internes au groupe sont exclues. Les copies d’une équipe dans une conférence et sa division ne sont pas additionnées.
- Les règles de points explicites existantes distinguent les ligues à 2 et 3 points pour une victoire en temps réglementaire ; la prolongation/tirs au but reste à 2/1 dans ces politiques.
- Part des points possibles = points du groupe contre les autres groupes / (matchs du groupe contre les autres groupes × maximum de points par équipe et match). Le nombre de matchs et les valeurs du numérateur/dénominateur sont affichés.
- Moyenne de ligue = somme des points des équipes uniques / somme de leurs matchs joués. Ce n’est ni une moyenne non pondérée des ratios ni une somme des copies conférence/division.
- La hiérarchie repose sur les noms officiels explicites et l’inclusion stricte des membres. Aucun rattachement géographique n’est deviné. Les groupes d’un même niveau qui se chevauchent ne publient pas de taux comparatif.
- Une couverture partielle ou un barème/saison non pris en charge ne publie pas de taux entre groupes. Zéro match donne une absence de taux, pas 0 % de réussite.
- Le lecteur public vérifie indices, hiérarchie, phase, dates, membres, barème, limites des points, additivité des périmètres et absence de chevauchement entre groupes comparés.

## Interprétation

Le rang est local. Les points par match expriment le rendement dans une ligue et un barème communs ; ils ne corrigent pas la difficulté du calendrier. La part des points obtenus contre les autres groupes est descriptive, pas une note calibrée de force d’une division.

Le seuil de 10 matchs inter-groupes est un garde-fou de présentation : sous ce volume, l’interface signale un échantillon court et évite une synthèse affirmant la supériorité du groupe. Ce seuil n’est pas un intervalle de confiance ni une nouvelle règle sportive. Ces métriques ne déclenchent aucune lecture/scénario automatiquement.

La date de collecte reste affichée. Un ancien match utilise le dernier classement disponible et ne reconstitue pas son classement d’avant-match. La politique de saison régulière reste explicitement versionnée pour 2026 avec les fenêtres conservatrices déjà utilisées ; une autre saison doit recevoir sa politique validée.

## Données locales et coût

Reconstruction du fichier publié de la collecte `1ac3b7ed-761e-4338-b486-59355459dec8`, capturée le 5 octobre 2026 à 17:08:08 UTC. Aucun appel API supplémentaire, aucune migration SQL. Les futures collectes produisent ce contexte dans leur JSON public sans route fournisseur additionnelle.

- NHL, KHL, Extraliga, Magnus, Liiga, SHL : résultats réconciliés avec les tableaux officiels.
- AHL : couverture partielle (deux équipes non réconciliées) ; tableaux conservés, taux entre divisions indisponibles.
- Exemple NHL réel : Atlantic 15/28 points possibles sur 14 matchs inter-divisions ; Metropolitan 11/20 sur 10 ; Pacific 6/8 sur 4, donc échantillon court. Les chiffres des maquettes étaient illustratifs et ne sont pas injectés dans l’application.

## Compatibilité et vérification

Les composants visuels sont dans `core/widgets` et les règles hockey dans son adaptateur. Le tableau football demeure le même ; le sous-texte facultatif en points par match n’est activé que dans le nouveau parcours hockey. Les anciennes publications sans contexte de groupes conservent leur parcours compatible.

Tests couvrant les trois écrans à 360/1100 px, les données NHL réelles, les badges et la navigation de l’adversaire, les rangs par groupe/périmètre, la moyenne pondérée, les publications corrompues, les calendriers incomplets et les ligues sans confrontation entre groupes. Tests serveur à 2/3 points, prolongation/tirs au but, absence de double comptage, retard de classement, hiérarchie et chevauchements. Régression du classement football et règles de thème vérifiées.

Contrôle dans le navigateur local au format mobile sur Philadelphia–Tampa Bay : vue du match, sélecteur et tableau Atlantic. Le message d’actualisation des scores indisponible affiché dans cet aperçu est indépendant de ce chantier de classements.

Résultats de vérification : 49 tests Flutter ciblés + 1 régression football réussis ; 24 tests Deno réussis ; analyse des huit fichiers Dart concernés sans anomalie ; compilation web release réussie. Aperçu de contrôle : http://localhost:8194/sports/hockey.

## Correction visuelle après retour sur la première maquette

Les deux cartes sont désormais des cartes sœurs, séparées des contrôles du classement. « Position dans leur division » reprend les deux colonnes, les accents domicile/extérieur, les rangs blancs en grand, les points et matchs, la séparation verticale et les rails à marqueurs circulaires. Le titre s’adapte à la nature du groupe officiel (division, conférence ou groupe).

« Repère commun » remplace les barres indépendantes par un seul axe numérique, deux points colorés et une ligne pointillée pour la moyenne pondérée de la ligue. Les annotations des équipes sont placées au-dessus et au-dessous pour rester distinctes lorsque leurs valeurs sont proches. Un rendement manquant ne crée aucun marqueur ; deux valeurs identiques partagent un point bicolore. DOM./EXT. identifient les points sans inventer des abréviations officielles absentes des données.

Le composant partagé `LectorMatchHeroView` reçoit maintenant un asset facultatif ; son défaut conserve le stade de football. Le détail hockey utilise `assets/backgrounds/match-card-hockey-arena-premium.png`, généré avec le tool intégré imagegen et copié dans les assets du projet. La patinoire, ses bandes, sa glace et ses marquages sont visibles dans le vrai en-tête mobile ; le voile de contraste commun est conservé.

Prompt exact de génération :

```text
Use case: photorealistic-natural. Asset type: wide background photograph for a premium mobile ice-hockey match header in Lector. Generate a cinematic, realistic indoor ice hockey arena, photographed symmetrically from rink-side center ice, looking across the rink. The smooth ice occupies the lower half with a real center circle, red center line and subtle blue hockey markings, boards and protective glass surround the rink, dark spectator stands and roof trusses above, cool white-blue arena spotlights and subtle reflections on the ice. Wide landscape panorama, approximately 2.5:1 framing; composed so a center-cropped mobile version remains unmistakably a hockey rink. Dark navy and charcoal atmosphere, restrained cyan highlights, attractive photographic detail, readable negative space for team crests and white UI text that the app will overlay. Empty rink, no players, no people foreground, no text, no labels, no logos, no advertising, no watermark, no football pitch, no grass. This is solely a background asset, not a mockup or screenshot.
```

Vérification de cette correction : 36 tests Flutter (parcours groupé, badges et design system), une régression du classement football et les deux tests du détail partagé à 360/1100 px. Analyse des cinq fichiers de production modifiés sans anomalie ; compilation web release réussie. Contrôle visuel dans le navigateur à 390 × 844 sur Philadelphia–Tampa Bay. Capture : `output/previews/hockey-standings-corrected-mobile.jpg`. Aucun nouvel appel fournisseur et aucune publication distante pour cette correction.

## Intégration de la maquette avec les deux classements

La vue du match comporte maintenant les deux tableaux locaux côte à côte si les adversaires appartiennent à des groupes différents. Toutes les équipes de chaque groupe sont conservées et ordonnées dans leur propre classement ; aucun classement artificiel fusionnant les divisions n'est créé. Les tableaux sont placés entre « Position dans leur division » et « Repère commun ».

Le même composant `LectorStandingDataTable` rend le tableau complet et sa présentation compacte. Sur mobile, les colonnes sont rang, équipe, matchs et points ; victoires, défaites réglementaires, défaites après prolongation/tirs au but et points par match restent visibles sous le nom. Sur grand écran, les colonnes du bilan sont aussi affichées. Les logos, les badges DOM./EXT., les couleurs sémantiques et les surlignages sont communs. Le bouton « Voir le classement complet » ouvre le tableau avec J/V/D/OT/Pts et le résumé de l'équipe concernée.

Général/Domicile/Extérieur est un seul sélecteur de la vue : il pilote les deux tableaux, les rangs locaux, les points par match, la moyenne pondérée et le contexte inter-groupes. Son état est conservé lors de l'ouverture d'un classement, de la visite du groupe adverse et du retour à la vue du match. La navigation remonte au début de la section Classement. Si les adversaires appartiennent au même groupe, le tableau complet de ce groupe s'affiche directement et les deux équipes y sont surlignées.

Les périmètres sans données ne reprennent pas le classement général en prétendant être un classement domicile/extérieur. La sélection des groupes du match reste fondée sur leur appartenance officielle, même si des résultats de périmètre sont manquants.

Vérification : 6 tests du parcours groupé, 8 tests des badges/identités, 23 tests du design system et 1 régression du classement football réussis. Les tableaux côte à côte sont testés à 360 et 1100 pixels (hauteur 844), avec comparaison de toutes leurs équipes, rangs et points aux données de chaque périmètre ; navigation et retour au début de section vérifiés. Données partielles et absence de rencontres inter-groupes testées aussi à domicile et à l'extérieur. Analyse des quatre fichiers concernés sans anomalie. Contrôle visuel sur Philadelphia–Tampa Bay à 390 pixels, ouverture du tableau Atlantic depuis la comparaison en périmètre domicile. Capture : `output/previews/hockey-cross-division-comparison-mobile.jpg`.

Changements locaux sur `codex/multisport-hockey`, sans nouvelle collecte API, migration, push ou déploiement distant.

Compilation web release finale réussie. La navigation depuis le bas des deux tableaux et le retour à la comparaison ont aussi été vérifiés dans le navigateur après intégration du repositionnement. Capture du classement individuel : `output/previews/hockey-single-division-ranking-mobile.jpg`.
