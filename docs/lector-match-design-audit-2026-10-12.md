# Lector — présentation des rencontres, 12 octobre 2026

## Audit et périmètre

Flutter/Dart, Material, extensions de thème dans `app_components.dart`, couleurs dans `app_colors.dart`, police Inter et composants sportifs partagés. GoRouter expose `/` (football), `/sports/:sport` et `/admin`. Les cinq destinations sont des états internes des workspaces, pas cinq routes indépendantes.

| Surface | Implantation actuelle |
| --- | --- |
| Pour moi, Tous, Radar football | `matches_home_page.dart`, `MatchFeedCard`, adaptateurs et classements Form Radar |
| Hockey | `hockey_workspace.dart`, modèles SportFixture et adaptateurs hockey |
| Header / navigation | `LectorWorkspaceHeader`, `LectorWorkspaceNavigation`, sélecteur du SportWorkspacePage |
| Shortlist | `ShortlistPage`, `ShortlistController`, `ShortlistAddButton` et repository serveur |
| Générateur | `LectorGeneratorPage`, repository et fonctions serveur |
| Bilan | `reading_bilan_section.dart`, bilan SQL et snapshots annoncés |

### À conserver

Routes, calendrier et date choisie, sélection de sport, contrôleurs, filtres Pour moi/Tous, lectures/scénarios calculés, classements Radar, flux live, détail match, Shortlist et expiration, conversation, règles de marchés et cotes. SportsAssetBadge et les logos existants restent réutilisés. Aucun algorithme de classement, de lecture ou de pari ne change.

### À modifier après validation des deux cartes

Composition du header (une ligne), navigation (cinq largeurs égales), composition des cartes dans Tous et Pour moi, déclinaisons de compétition. Les détails aujourd’hui embarqués dans de grandes cartes, dont Form Radar joueurs, devront rester accessibles avant leur remplacement.

### Composants à préparer

`LectorCompactMatchCard`, contrat de présentation distinct des données métier, adaptateur football, `RecentFormStrip` utilisant les mêmes cellules que Radar, identités de compétition, icône Shortlist représentant une collection, header compact et navigation géométrique. Briefing européen seulement à l’étape suivante, avec statistiques issues du périmètre réellement disponible.

### Provenance et risques

La forme de MatchAnalysisData possède des historiques de compétition ; TeamFormRadarSnapshotAdapter peut regrouper plusieurs compétitions. Ne jamais appeler ce regroupement « championnat ». Les contextes domestiques existent dans le modèle, mais certaines publications allégées n’en contiennent pas : afficher le périmètre disponible ou un état incomplet. Les historiques sont ordonnés du plus ancien au plus récent ; pas de remplissage artificiel jusqu’à cinq résultats. Pour une forme avant match, exclure les événements postérieurs au coup d’envoi.

Cotes : utiliser seulement le marché matchResult et son ordre Home/Draw/Away, jamais la cote primaryMarket comme substitut. L’état obsolète doit être fourni par l’autorité de données ; ce chantier n’invente pas de nouvelle règle de fraîcheur. Garder l’horodatage et prévoir valeurs absentes/incomplètes et obsolètes.

Risques : étroitesse à 320 px, noms longs, texte agrandi, confusion des groupes domestiques, chronologie, lectures profil vs ensemble complet, cotes d’un autre marché, callbacks Shortlist/détail et conservation des états live. La forme des rencontres terminées est contextualisée avant match ; aucune nouvelle lecture rétrospective.

## Direction de la première étape

Surface Operate. Référence écrite et maquettes utilisateur du répertoire `7EA5F6B5-232F-4A83-8134-7996C37E2E66`. Noir bleuté, graphite, bordure fine, équipes prioritaires, cinq cellules de forme compactes et trois cellules 1/N/2. Trois matières européennes originales placées derrière la partie droite ; pas de halo, ni de navigation basse, ni de faux badges. Le même composant porte les cartes de championnat et européennes. Les textes métier viennent des données publiées.

La règle utilisateur impose une validation préalable d’une carte de championnat et d’une carte Champions League sur captures de l’application. Cette étape prépare les composants et leur prévisualisation isolée ; la généralisation et la publication sur la démo attendent cette validation. Les maquettes fixent la direction, pas les chiffres ou équipes de production.

## Assets

Logo Lector et logos équipes/compétitions : assets et URLs déjà présents. Nouvelles matières limitées aux trois compétitions européennes : créations originales ImageGen, sans logo ou trophée officiel, intégrées dans `assets/backgrounds/competition-*-original-v1.png`. Pas d’asset créé pour les autres championnats.

Les captures provenant de sites tiers servent d’inspiration. Aucune autorisation commerciale de réutilisation de ces images n’est établie. Les [conditions UEFA](https://www.uefa.com/termsconditions/) et l’[article 12](https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-12-Intellectual-property-rights-Online) réservent les identités et visuels officiels. La licence du fournisseur pour les logos existants reste à vérifier avant exploitation commerciale ; ces logos ne sont pas présentés comme nouvellement autorisés par ce chantier.

## Premier point de validation — résultat

Composants préparés : contrat CompactMatchData, adaptateur football, LectorCompactMatchCard, RecentFormStrip, CompetitionCardTheme, LectorShortlistIcon, LectorCompactWorkspaceHeader et LectorGeometricNavigation. Ils sont accessibles via l’entrée isolée `tool/previews/compact_matches_preview.dart`. Ils ne remplacent pas encore les cartes et headers des workspaces publiés.

Les données de l’aperçu viennent des publications déjà livrées : Hull City–Everton (`1557422`, source `9760221e-91ce-49ad-8b12-89d55d95ec02`, capture 10 octobre), Villarreal–Napoli (`1635748`, source `3485f609-6d33-4807-849c-db714390bf49`, capture 9 octobre). Leur décodage utilise le repository de snapshots de l’application. Ces données sont archivées : ni leurs cotes ni leurs statuts ne sont présentés comme actualisés en direct. Le compte de lectures respecte le retrait TAT déjà existant : six observations visibles sur le premier match. Une analyse personnalisée explicitement fournie, même vide, reste prioritaire.

La forme de championnat du premier match affiche ses cinq résultats ; le deuxième possède un seul résultat par équipe dans la compétition et aucun contexte domestique publié. Il affiche Forme (compétition), 1/5, sans remplissage. Le périmètre de compétition est le défaut conservateur ; un championnat est déclaré explicitement par le fournisseur de la présentation. Pour les européens, les deux contextes domestiques doivent être disponibles avant d’afficher leur forme de championnat.

Les cotes respectent Home/Draw/Away, sans substituer un autre marché. La fraîcheur doit être fournie par l’autorité de données ; le composant prévoit le cas obsolète sans créer une nouvelle règle. Le bookmaker et la date de relevé restent accessibles via l’infobulle de la zone de cotes. Les scores sont réservés aux rencontres live ou terminées.

### Vérifications

- Contrats : quatre tests réussis sur chronologie avant match, marché 1/N/2, séparation profil/publication et indépendance des actions.
- Thème : contrôles existants réussis avec les premiers tests de composant (31 au total dans ce lot).
- Rendus du vrai widget : 320, 375, 390, 430 et 768 px, plus 320 px avec texte 1,5× en thème clair ; chargement des assets attendu avant capture.
- Après le premier rendu, la zone lectures/cotes est regroupée pour réduire la hauteur. Les noms et cotes restent lisibles et la navigation possède cinq largeurs égales.
- Calendrier : avec texte agrandi, ses cellules et sa hauteur s’adaptent ; le défilement et la sélection sont conservés.
- Navigateur : aperçu Flutter réel à 390×900, logos réseau chargés, fonds originaux, sélection indépendante et compteur à un, sans message de succès. L’ouverture de la fiche existante est vérifiée avec ses onglets Contexte, Classement et Forme.
- Aucun appel au Générateur, aucune collecte fournisseur, aucune écriture dans une préparation personnelle. Les sélections de l’aperçu sont seulement en mémoire.

![Pour moi — aperçu navigateur](/Users/chloe/.codex/visualizations/2026/09/16/01a0aaf1-05e5-7562-8f19-7332ea8701f5/lector-premium-for-me-browser-390.jpg)

![Tous — aperçu navigateur](/Users/chloe/.codex/visualizations/2026/09/16/01a0aaf1-05e5-7562-8f19-7332ea8701f5/lector-premium-all-browser-390.jpg)

### Typographie et limites

Inter, la famille déjà prévue dans Lector, est désormais auto-hébergée depuis le [dépôt Google Fonts](https://github.com/google/fonts/tree/main/ofl/inter), avec sa licence OFL incluse. Les rendus de test utilisent cette police, pas une police de remplacement. Les logos réseau sont remplacés par des initiales dans les tests de widgets ; leur rendu réel est vérifié dans le navigateur.

Ces contrôles portent sur le premier point de validation, pas sur une refonte déjà généralisée. Aucun essai sur téléphone physique n’est effectué. Il reste l’intégration des callbacks et des données dans Tous et Pour moi, le raccord du header multisport, le traitement hockey applicable, le briefing européen conditionnel, puis la validation complète et la publication sur la démo. Les filtres réels, la personnalisation, les panneaux live/Radar, le stockage Shortlist, le Générateur, le Bilan et les règles métier ne sont pas réécrits par ce prototype.

Dernier contrôle local : 12 tests de conservation du calendrier, du classement des équipes Radar et des contrats des cartes réussis. Analyse Flutter : No issues found. Le serveur de prévisualisation est arrêté et le navigateur restauré après vérification afin de libérer les ressources de la machine.


## Révision après retour visuel utilisateur

Référence prioritaire : la maquette Pour moi transmise dans `2513E695-A092-4608-991D-E397385E9797/1-Photo-1.jpg`. Le retour porte sur la fidélité des cartes. Le header et la navigation de l’aperçu restent hors de cette correction.

| Première proposition | Composition corrigée | Motif |
| --- | --- | --- |
| Petits logos, horaire en haut | Logos de 30 px, équipes à gauche, horaire au centre avec séparateur fin | Reprendre les groupes de la référence |
| Forme dominante dans la zone droite | Cellules compactes sous chaque nom, périmètre près de l’horaire | Les équipes restent la première information |
| Compétition en texte bleu et logo sur plaque | Intitulé capitalisé, phase réelle traduite, silhouette de logo claire | Retrouver la hiérarchie de la maquette |
| Fonds européens très atténués | Matière originale visible à droite, voile sombre côté texte | Identité plus lisible sans halo |
| Petits badges empilés et cotes séparées | Lectures et signaux en ligne, cotes dans un groupe régulier 1/N/2 | Reprendre la ligne inférieure compacte |

Les badges réutilisent les identités de lecture existantes. « Baisse » et « Forme + » sont des libellés courts de deux lectures réelles ; leurs textes complets restent accessibles par infobulle et dans la fiche. Une carte étroite peut montrer un seul signal représentatif au lieu de deux. Aucun badge Vigilance fictif n’est ajouté. Le watermark générique réutilise le logo fourni de la compétition ; aucun nouveau fichier de championnat n’est produit.

La forme reste celle des snapshots archivés, du plus ancien au plus récent. Le paramètre visuel `cellScale` du composant Radar conserve sa valeur par défaut à 1 dans les écrans existants. La correction n’introduit aucune règle d’analyse, de classement ou de pari.

La prévisualisation reste un jalon isolé, avant intégration aux écrans réels et publication sur la démo.
