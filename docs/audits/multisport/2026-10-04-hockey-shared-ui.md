# Hockey : composants communs et sept ligues — 4 octobre 2026

Travail local sur `codex/multisport-hockey`. Les correctifs football validés sur
`main` (61503be) ont été intégrés à cette branche. Aucun déploiement hockey ou
push sur main n'est réalisé par cette itération.

## Origine de l'écart visuel

La première collecte NHL utilisait un écran de préparation : calendrier en
ChoiceChip, trois sections, carte générique horizontale et largeur 760 px.
L'accueil football possédait ses propres composants privés. Le partage du thème
seul ne suffisait donc pas à partager le design.

Le calendrier, l'en-tête, les cinq onglets, le cadre de carte, la ligne d'équipe,
le panneau de signaux, les badges de résultat et le rail des tiers ont une
implémentation commune dans `lib/core/widgets`. Cette première extraction était
incomplète : elle partageait le cadre de la carte, mais conservait une disposition
distincte et un bottom sheet de détail hockey. La correction suivante partage
la carte complète et la page de détail. Le football utilise ces composants
sans changement de ses analyses, préférences, lectures, cotes ou abonnements live.
Le hockey conserve extérieur à gauche / domicile à droite et ses portées de score
(60 minutes, prolongation, tirs au but, final). Le contenu de chaque sport reste
composé dans son module, sans import du football depuis le hockey.

## Carte complète et parcours de détail communs

Les adaptateurs `MatchFeedCard` et `SportFixtureCard` alimentent désormais le même
`LectorMatchCard` : en-tête, disposition responsive, lignes d'équipes, scores,
action à droite, analyses et panneau de forme. Dans la liste, le hockey présente
l'extérieur en première ligne et le domicile en seconde ligne, avec leurs rôles.
Dans le bandeau du détail, l'extérieur reste à gauche et le domicile à droite.

Le clic utilise `Navigator.push` pour les deux sports. `LectorMatchDetailView`
possède le fond, la largeur responsive, le retour, les actions, le défilement et
les quatre onglets Contexte / Classement / Forme / TAT. `LectorMatchHeroView`
possède le bandeau complet ; ses données de présentation sont indépendantes des
modèles football. Les modules fournissent les données et le contenu des sections.
Les tickets et abonnements live football restent fournis par son adaptateur.

Les tableaux utilisent `LectorStandingTable`, `LectorStandingRow`,
`LectorStandingTeam`, `LectorStandingCell` et `LectorStandingTierGroup` : surface,
lignes, logos, typographie, surbrillance et rails identiques. Les colonnes dépendent
des statistiques disponibles pour la discipline. Les sélecteurs Général / Domicile /
Extérieur utilisent `LectorMatchScopeChip` dans les deux sports.

La collecte comprend désormais les bilans domicile/extérieur et les confrontations
H2H des rencontres publiées. `teams/statistics` fournit matchs joués, victoires,
défaites et buts par lieu, mais aucun point ni découpage des prolongations. Les vues
Domicile/Extérieur sont donc classées par taux de victoire, explicitement annoncé ;
aucun barème NHL n'est appliqué aux autres ligues. Le classement général conserve
les points officiels, ses groupes et ses tiers exploratoires.

`HeadToHeadTimelinePanel` football est un adaptateur du composant commun
`LectorHeadToHeadTimelinePanel`. Le hockey alimente exactement ce composant avec
son historique, son horloge de trois périodes et ses événements buts/pénalités.
Les règles de sélection football restent dans son adaptateur. Le hockey affiche
jusqu'à six confrontations par scope sur les trois années précédant le match et la
collecte ; les scopes championnat/toutes compétitions sont sélectionnés séparément.
Les matchs futurs, la rencontre elle-même et les identités étrangères sont refusés.
Les rôles domicile/extérieur historiques sont explicites et le score final conserve
prolongation/tirs au but. Les lectures et marchés hockey restent à valider.

Tests de régression supplémentaires : les deux sports doivent instancier le même
composant de carte complet (un cadre commun seul ne suffit pas), le même bandeau,
la même page et les quatre mêmes onglets à 360 et 1100 px. Le test du contrat NHL
contrôle la navigation, l'absence de bottom sheet, le retour et la séparation des
scores à 60 minutes et du score final.

## Collecte réelle locale

Un appel `leagues`, un appel `games` pour la saison courante et un appel
`standings` par ligue : **21 appels** pour la base calendrier/classement général. Le contrôle
initial a consommé 22 appels, dont un paramètre `timezone` refusé sur standings,
corrigé dans le collecteur et couvert par un test. Cache local 15 minutes,
réservation durable avant appel, verrou du collecteur, plafonds locaux 7 500/jour
et au maximum 240/minute, ajustés à la baisse selon le fournisseur. Ce compteur protège l'aperçu local ; il ne remplace pas une future
réservation distribuée dans les opérations Supabase.

Réponses récupérées :

| Ligue | ID | Calendrier public J−7 à J+13 | Équipes au classement | Équipes avec 5 résultats comparables |
| --- | --- | ---: | ---: | ---: |
| NHL | 57 | 132 | 32 | 0 |
| AHL | 58 | 78 | 32 | 0 |
| KHL | 35 | 81 | 22 | 22 |
| Extraliga | 10 | 47 | 14 | 14 |
| Ligue Magnus | 18 | 38 | 12 | 12 |
| Liiga | 16 | 54 | 17 | 17 |
| SHL | 47 | 45 | 14 | 14 |
| Total | | **475** | **143** | **79** |

Le calendrier comprend les résultats récents et 14 jours, aujourd'hui inclus.
Les réponses privées de la saison complète restent sous `var/sports/hockey/raw`.
Le navigateur ne reçoit que le contrat compact public, sans clé fournisseur.
Une erreur dans une seule ligue empêche de remplacer la dernière publication
complète. Les conférences et divisions sont conservées séparément, sans déduire
un classement global de rangs locaux.

## Forme

Les 5 derniers résultats terminés sont affichés du plus ancien au plus récent.
La forme d'une rencontre exclut cette rencontre et tout résultat dont l'horaire
est postérieur au début de la rencontre ou à la collecte. Le radar classe les
équipes par nombre de victoires (prolongation et tirs au but inclus), sans appliquer
un barème de points d'une autre ligue. Top 50, pages de 10, filtre de compétition.
La forme du radar et les classements correspondent à la collecte actuelle ; ils
ne constituent pas une reconstruction des classements historiques.

La NHL fournit des tables de préparation et de saison régulière, alors que les
objets games n'exposent pas la phase. Sa forme est donc exclue du radar : impossible
de mélanger ces matchs silencieusement. Les tables de préparation sont exclues du
classement présenté. L'AHL n'a pas encore cinq résultats par équipe. Pour les autres
ligues, une seule phase régulière est présente au classement ; la forme est tirée
des rencontres de cette compétition/saison. Les données de joueurs ne sont pas
collectées ici : le radar hockey de cette itération concerne les équipes.

## Tiers exploratoires

Le rail visuel des tiers est celui du football. La politique hockey reste distincte,
provisoire et ne déclenche aucune lecture. Conditions : au moins 5 matchs par
équipe ; écart au nombre médian de matchs inférieur ou égal à un tiers de cette
médiane ; groupes d'au moins deux équipes ; rupture d'au moins 0,45 point par match
entre deux groupes adjacents. Le barème provient des points fournis par le classement,
sans calcul supposant le barème NHL. Les groupes sont ordonnés par points/match,
avec le rang officiel conservé. Le groupe de conférence/division ne change jamais.

Ces paramètres permettent de vérifier le rendu avec des données réelles. Ils
restent à valider avant toute lecture de supériorité. Sans rupture ou maturité,
le classement reste visible et aucun tier n'est inventé.

## Vérification locale

```bash
cd /Users/chloe/Documents/Codex/2026-09-16/c-2/lector-api-football-orchestration
SPORT_PREVIEW_PORT=8110 bash tool/run_multisport_local.sh 8189 release
```

Le script lit `.env` côté serveur. Football lit Supabase, hockey lit le collecteur
local. Choisir Hockey via le sélecteur de sport ; Tous montre le calendrier ; Radar
montre la forme et les classements. Le bouton d'information conserve les propositions
de lectures/scénarios dans une fiche séparée. Les sections personnalisées/générateur/
bilan ne produisent pas de lectures hockey avant validation des règles.

Tests de contrats : publication de sept saisons/compétitions distinctes, échec
atomique, absence de résultat futur dans la forme, séparation préparation/saison,
ordre des participants et portées des scores. Tests d'interface 360 et 1100 px,
composants partagés et accès aux classements. Les tests football existants vérifient
le maintien des lectures, du live et du calendrier.

## Résultats des vérifications

- Après le partage de la carte complète, du détail et des tables : **641 tests
  Flutter réussis, 2 ignorés** ; analyse sans diagnostic et formatage propre
  (317 fichiers). Les nouvelles régressions comparent effectivement les widgets
  des deux sports à 360 et 1100 px.
- `flutter analyze --no-pub` : aucun diagnostic.
- Suite complète Flutter : 636 tests réussis, 2 ignorés.
- Après les derniers garde-fous de lecture, 47 tests ciblés contrat/navigation/thème
  réussis ; 5 tests ciblés hockey réussis après le libellé championnat/pays.
- Après le partage de la présentation du compte, 62 tests ciblés hockey/navigation/
  accueil football réussis.
- Deno `_shared`, avec les permissions env utilisées par la CI : 33 tests réussis,
  dont 6 sports (échec atomique des sept ligues et les 21 appels).
- `git diff --check` : propre.
- Chrome local : calendrier et cartes réelles à 390 px, radar top 50 et pagination,
  classement KHL avec ses deux tiers inspectés.

Les comptes de collecte ci-dessus correspondent à l'audit, pas à une promesse
que les effectifs ou le nombre de matchs resteront identiques à la prochaine collecte.

## Enrichissement domicile/extérieur et H2H — même itération

Sources réelles : `/teams/statistics`, `/games/h2h` et `/games/events`.
Première alimentation : **3 061 ressources uniques** (143 bilans d'équipes,
422 paires non ordonnées, 2 496 réponses d'événements). **3 090 réservations locales**
pendant cette opération, y compris les reprises après refus minute et 21 appels
pour actualiser la base en fin d'opération. Ces compteurs représentent cette
fenêtre de 475 rencontres ; le volume varie avec le calendrier.

Les 475 rencontres référencent 2 554 confrontations historiques distinctes. Sur
cette capture, 13 rencontres n'ont aucune confrontation éligible retournée. Parmi
les historiques, 58 ne proposent pas d'événements et 19 ont des identités/horloges
incohérentes dans la réponse événements. Ces dernières sont isolées sans attribuer
leurs faits à une autre équipe. Le résultat factuel reste affiché. Quatre événements
SHL ne donnent pas de minute : celle-ci reste nulle et les faits sont présentés
par période avec « minute non renseignée », sans inventer une position temporelle.

Cache privé sous `var/sports/hockey/enrichment-cache` : bilans et H2H au maximum
24 h, avec renouvellement au changement de journée à Paris ; événements récents
(moins de 48 h) au maximum une heure, historiques plus anciens 30 jours. Aucun
appel fournisseur au clic sur une rencontre. La reprise après une erreur exploite
les réponses déjà enregistrées. Une erreur API n'est jamais transformée en réponse
vide. Les réservations précèdent chaque appel, y compris les tentatives refusées.
Les refus minute entraînent attente et reprise, avec débit réduit. Ce garde-fou
local ne coordonne pas les éventuels appels de production partageant la clé :
le déploiement hockey devra utiliser une réservation distribuée commune.

Le calendrier et le classement général ont leur propre date de collecte, conservée
comme `baseCapturedAt` ; reconstruire l'enrichissement depuis le cache ne prolonge
pas artificiellement leur fraîcheur. La publication est remplacée par renommage
atomique après validation ; le serveur déjà ouvert relit cette publication sur GET.
`--enrich-only` utilise un verrou d'écriture distinct de la durée de vie du serveur,
pour actualiser le contexte sans fermer la prévisualisation de l'utilisateur.
Le lanceur attend jusqu'à 30 minutes pour une première collecte froide, avec les
compteurs d'avancement du collecteur, au lieu de la tuer au bout de 90 secondes.

Vérifications finales : **646 tests Flutter réussis, 2 ignorés** ; **38 tests Deno
`_shared` réussis**, dont 11 collecte hockey ; analyse Flutter sans diagnostic.
La fixture réelle `hockey_enriched_compact.json` couvre NHL/KHL/SHL et vérifie la
chaîne réponse compactée → lecteur public → tableaux et TAT communs à 360/1100 px.
Les identités croisées, résultats futurs, horloges incohérentes et minutes absentes
ont des tests explicites. Une nouvelle reprise de l'enrichissement a été effectuée
avec **0 appel API**, confirmant l'utilisation réelle du cache.

Le disque s'est saturé pendant les vérifications. Huit anciens caches de compilation
Flutter régénérables ont été supprimés (417 Mio), en conservant les sources et les
compilations utilisées. La collecte et les tests ont ensuite été repris depuis
leurs données conservées. Aucun changement de production n'a été effectué.

Dernier contrôle visuel : les événements ne portent plus leurs longs libellés sur
les rails étroits du mobile. Les marqueurs gardent leur infobulle et « Voir les
événements » donne la liste chronologique complète, noms et horloges compris.
Chaque confrontation hockey respecte son propre extérieur à gauche/domicile à
droite, y compris quand les rôles sont inversés par rapport au match consulté.
Neuf tests de rendu partagé/hockey et le test TAT football ont repassé après
ces ajustements. La compilation web de l'aperçu local a réussi.


## Correction du parcours Pour moi / Tous / Radar

Constats de cette itération : le bloc hockey « Pour moi » affichait un message,
puis poursuivait dans `_matches`, exactement comme « Tous ». Le calendrier hockey
était groupé directement par ligue, sans la navigation par pays du football.
Le classement Radar et le panneau de forme des cartes étaient des présentations
hockey distinctes, malgré le partage de la carte de rencontre complète.

Corrections locales :

- « Pour moi » est le point d'entrée et n'affiche aucune carte de rencontre.
  Aucune préférence/lecture hockey publiée n'est actuellement raccordée ; le
  calendrier public et les préférences football ne sont jamais utilisés comme
  recommandations hockey. Une future activation devra brancher le profil propre
  à cette discipline, sans réintroduire de repli vers le calendrier global.
- `LectorCompetitionGroup` reprend l'accordéon pays/ligue du football. Les deux
  sports l'utilisent. Les pays sont repliés, puis les ligues, puis leurs matchs.
  Les enfants ne sont montés qu'à la première ouverture. Les tests football
  parcourent désormais les contrôles visibles plutôt que les descendants
  auparavant construits sous des accordéons fermés.
- « Tous » hockey regroupe le jour sélectionné par pays puis ligue, avec logos
  et drapeaux. Les publications suivantes incluent code/drapeau du pays issus
  du fournisseur ; les publications existantes restent compatibles. Le pays
  d'une compétition reste celui de l'API : NHL/AHL sont rattachées aux États-Unis.
  Les anciennes publications sans métadonnées de ligue restent navigables sous
  « International », sans inventer de pays.
- `LectorRadarRankingPanel`, `LectorRadarEntryCard`, `LectorRadarTeamRow`,
  `LectorFormResultStrip`, `LectorRadarPagination` et `LectorRadarModeToggle`
  sont partagés. Top 50, 10 par page, cellules de résultats, logos et relief
  reprennent la présentation football. Le calcul hockey reste les victoires
  sur cinq résultats et la série de victoires, prolongation/tirs au but inclus.
  Aucun barème football 3/1/0 n'est appliqué au hockey. Le Radar hockey est un
  Radar d'équipes : aucun profil de joueur non collecté n'est créé.
- Les rencontres des équipes du top sont proposées sous le classement Radar,
  avec `LectorCompetitionHeader` et la même `LectorMatchCard` que dans « Tous ».
- `LectorFormRadarSignalPanel` et `LectorFormRadarSignalRow` sont le panneau
  et les lignes intégrés communs aux cartes. Football : contributions des
  joueurs et fenêtre récente de trois matchs. Hockey : résultats des équipes,
  jusqu'à cinq matchs. Même mise en page ; les faits et leurs fenêtres sont
  explicitement distincts. La forme dans une carte est arrêtée avant le match.
- Les rôles domicile/extérieur sont intégrés à `LectorTeamLine`. Le header du
  détail montre des badges contrastés et adaptables à 360 px. Le hockey conserve
  l'extérieur à gauche et le domicile à droite ; les scores ne sont pas inversés
  dans le stockage. Les TAT suivent les rôles de chaque confrontation historique.

Aucun déploiement, push ou appel API supplémentaire pour ces corrections
visuelles. Les contrôles couvrent le calendrier vide, Pour moi sans cartes,
la navigation pays/ligue, les identités/logos, la pagination, le partage effectif
des classes de widgets et les parcours football invité/compte connecté.

Vérifications de cette correction : **648 tests Flutter réussis, 2 ignorés** ;
**38 tests Deno réussis** ; analyse Flutter sans diagnostic, formatage de
325 fichiers sans changement, `git diff --check` propre. Les tests de navigation
football vérifient désormais les ouvertures réelles et les rechargements de date,
au lieu de dépendre de descendants invisibles dans les accordéons fermés.

Compilation web réussie avec Supabase football et la source hockey locale
configurés ; le serveur d'aperçu 8191 sert cette compilation. Contrôle Chrome
à 390 px : navigation « Tous », pays repliés, drapeaux réels et compteurs
inspectés. La capture `output/playwright/hockey-parity-countries-mobile.png`
conserve ce rendu. Les contrôles automatiques vérifient également l'état
Pour moi vide, les cartes ouvertes et les badges domicile/extérieur du détail.

## Radar des joueurs — correction du 4 octobre

Le sélecteur hockey « Équipes / Classements » était une mauvaise substitution :
la collecte ne préparait pas de profils joueurs. Le Radar présente désormais
« Joueurs / Équipes ». Le classement général reste dans le détail de la rencontre.

Le football et le hockey instancient les mêmes classes :

- `LectorRadarRankingPanel`, `LectorRadarEntryCard`, `LectorRadarPagination` ;
- `LectorRadarPlayerRow`, `LectorPlayerActivityMatrix`,
  `LectorPlayerPeriodLabel`, `LectorPlayerRadarLegend` ;
- `LectorFormRadarSignalPanel`, `LectorFormRadarSignalRow` et
  `LectorPlayerSignalDescription` pour les cartes de rencontre.

Les wrappers football gardent leurs profils, règles et navigation. Le hockey
fournit ses propres profils factuels et son classement. Les widgets communs
n'importent aucun modèle football/hockey et ne décident pas des joueurs éligibles.

### Données et limites

La collecte réutilise les calendriers de saison et le cache `/games/events`.
Elle consulte les trois derniers matchs terminés de chaque équipe, pas seulement
ses confrontations avec l'adversaire. Un match n'est exploitable que si ses buts
reconstituent le score. Le but décisif conventionnel des tirs au but n'est pas
attribué à un joueur. Une équipe est exclue si un des trois matchs n'a pas des
événements exploitables ; aucune absence ou contribution nulle n'est inventée.

L'API fournit des noms/initiales dans ces événements, sans identifiant joueur
stable. Les clés sont donc explicitement marquées `event-name` et séparées par
compétition, saison et équipe. Deux noms identiques dans une même équipe ne
peuvent pas être distingués avec cette source. Les photos, compositions et temps
de jeu ne sont pas déduits. La case neutre hockey signifie zéro contribution,
jamais « absent » ou « titulaire ».

Règle hockey de cette première itération : au moins deux contributions (buts +
passes) sur trois matchs ; tri par régularité, série, volume, puis nom. Top 50,
10 joueurs par page. Cette règle n'est pas une lecture personnalisée activée dans
« Pour moi », qui demeure vide sans configuration hockey.

Résultat réel au 4 octobre, 18:49 UTC : 870 profils, 418 éligibles sur KHL,
Extraliga, Magnus, Liiga et SHL ; 75 équipes à couverture complète, 30 sans trois
matchs, 6 à événements incomplets. NHL exclue pour phase non vérifiée ; AHL sans
historique suffisant. 124 appels supplémentaires, cache commun et quota durable
7 500/jour conservés. Les cartes affichent les joueurs de leurs équipes seulement
si leur historique est antérieur à la rencontre et à la collecte.

Tests : collecte dédupliquée, homonymes entre équipes, événements manquants,
score incomplet, tirs au but, identité croisée, phase non vérifiée ; décodage du
compact réel et classement ; rendu et pagination à 360/1100 px. Les tests football
vérifient eux aussi les types des widgets partagés.

Chantier local sur `codex/multisport-hockey`, sans déploiement ni push.

Vérification finale de cette correction : 54 tests Flutter ciblés réussis
(contrat public, hockey/football Radar, cartes partagées et système de thème),
43 tests Deno `_shared` réussis. Compilation web release réussie. Contrôle à
390 px dans Chrome : sélecteur Joueurs/Équipes, Top 50, matrice lisible et clic
sur une case ouvrant les trois matchs avec adversaire, lieu, score et contributions.
Les deux anciens caches de compilation régénérables ont été supprimés ; aucun
serveur utilisateur ni fichier de données du projet n'a été supprimé.
