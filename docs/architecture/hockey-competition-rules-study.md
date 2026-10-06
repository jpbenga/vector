# Hockey : formats des compétitions et conséquences pour les lectures

> Évolution du 6 octobre : les tiers Lector hockey et la lecture d’avantage au classement utilisent désormais le moteur de partition commun au football, avec cinq matchs minimum et des repères analytiques de groupe. Voir [la décision et ses contrôles](../audits/multisport/2026-10-06-hockey-standing-tiers.md). Les constats de l’étude ci-dessous décrivent l’état du 5 octobre.

Étude du 5 octobre 2026 — branche `codex/multisport-hockey`.

## 1. Conclusion

La bonne unité de configuration est **sport + compétition + saison + phase**.
Un règlement « hockey » ou même « hockey européen » ne suffit pas. Les composants
peuvent être communs ; les règles de classement, de résultat, de comparaison et
de qualification doivent rester explicites et versionnées.

La NHL est une seule compétition. Ses conférences et divisions sont des groupes
internes, pas des championnats indépendants. Un match entre conférences appartient
toujours à la NHL. À l'inverse, une rencontre européenne entre clubs de deux
championnats, disputée dans une coupe, doit garder l'identité de cette coupe.

Le principe de sécurité analytique : **une comparaison impossible rend la lecture
concernée indisponible, pas le match**. Calendrier, score, live, statistiques et
autres lectures suffisamment documentées restent affichables.

Cette étude confronte sources officielles, code et fichiers déjà collectés. Elle
ne modifie aucun calcul et n'active aucune lecture. Aucun nouvel appel API-Hockey,
aucune écriture Supabase, aucun push ou déploiement n'a été effectué pour l'étude.

## 2. Sources et degré de vérification

Les formats ci-dessous concernent 2026–2027 quand une source actuelle a été
trouvée. Une page accessible aujourd'hui peut encore décrire 2025–2026 : la
[page AHL de qualification](https://theahl.com/qualification-rules) est précisément
dans ce cas. Ses répartitions de clubs ne doivent pas servir à configurer 2026–2027.

Les données fournisseur sont une preuve de ce qui a été reçu, **pas une validation
du règlement**. Les descriptions « Promotion », « Play Offs » et « Relegation »
de l'API ne suffisent pas à reconstituer les règles de qualification.

### Panorama vérifié

| Compétition | Organisation observée dans notre compact | Calendrier régulier 2026–2027 vérifié | Particularité à modéliser |
| --- | --- | --- | --- |
| NHL, ID API 57 | 32 équipes ; 2 conférences, 4 divisions | 84 matchs par équipe [N1] | Plusieurs vues du même bilan ; wild cards [N2] |
| AHL, ID 58 | 32 équipes ; divisions de 7, 8, 7 et 10 clubs | 72 matchs par équipe [A1] | Quotas de qualification différents selon division [A2] |
| KHL, ID 35 | 22 équipes ; 2 conférences, 4 divisions | 68 matchs par équipe [K1] | Réorganisation du tableau à partir du deuxième tour [K1] |
| Extraliga tchèque, ID 10 | 14 équipes ; classement général | 52 journées [C1] | Phase régulière, pré-tour, séries et barrage à distinguer |
| Ligue Magnus, ID 18 | 12 équipes ; classement général | Double aller-retour, soit 44 matchs par équipe : déduction du format [M1] | Maintien en poule avec conservation des points [M1] |
| Liiga, ID 16 | 17 équipes ; classement général | 64 matchs par équipe [F1] | Saison de transition et relégations directes [F1] |
| SHL, ID 47 | 14 équipes ; classement général | 364 matchs au total, soit 52 par équipe : déduction [S1] | Réappariement en séries ; maintien distinct [S2] |

Les nombres d'équipes et groupes de la deuxième colonne proviennent du fichier
local `var/sports/hockey/published.json`, capturé le 4 octobre à 19:58:28 UTC.
Le championnat sélectionné est l'unité métier ; le pays sert à la navigation.
Une ligue peut accueillir des clubs de plusieurs pays. Ne pas utiliser le pays
de la ligue comme nationalité de toutes ses équipes ni comme lieu réel du match.

### Ce qui change concrètement selon la compétition

- **NHL :** 84 matchs en 2026–2027. [Calendrier officiel N1](https://www.nhl.com/news/nhl-stats-pack-2026-27-regular-season-schedule).
- **NHL :** qualifications par division et wild cards par conférence. [Format N2](https://www.nhl.com/info/standings-info/playoff-format).
- **AHL :** les 32 clubs jouent 72 matchs chacun. [Calendrier A1](https://theahl.com/news/ahl-unveils-2026-27-schedule).
  Les 23 places en séries sont réparties en 5 Atlantic, 6 North, 5 Central et
  7 Pacific. [Annonce de début de saison A2](https://theahl.com/news/ahl-begins-its-91st-season-tonight).
  Les effectifs sont liés aux franchises NHL : une lecture de joueur doit gérer
  changements de club et de compétition. [Affiliations](https://theahl.com/nhl-affiliations).
- **KHL :** 22 clubs, 68 matchs ; premier tour par conférence, puis classement
  commun pour les appariements à partir du deuxième tour. [Annonce K1](https://en.khl.ru/news/2026/05/29/562946.html).
- **Extraliga :** la saison régulière se termine à la 52e journée. Le calendrier
  distingue ensuite pré-tour et séries. [Annonce C1](https://www.hokej.cz/extraliga-spojuje-sily-s-red-bullem-novy-rocnik-ozdobi-navraty-hvezd-i-oslavy/5097853).
  Les dates publiées comprennent aussi un barrage. [Calendrier des phases](https://www.hokej.cz/extraliga-startuje-ve-stredu-16-zari-v-prvnim-kole-zase-traskave-derby/5096543).
  Le détail des quotas et départages 2026–2027 reste à confirmer avec les normes
  techniques propres à l'Extraliga avant leur automatisation.
- **Magnus :** huit qualifiés pour le titre ; quatre clubs en maintien, avec
  points conservés. Barème 3/2/1/0 ; OT régulière de cinq minutes à trois contre
  trois, puis tirs au but. [Formule M1](https://liguemagnus.com/la-ligue-magnus/formule/).
  Une moyenne de points de la phase de maintien ne peut donc pas être calculée
  comme si son total commençait à zéro.
- **Liiga :** 17 équipes, quatre rencontres contre chaque adversaire, 64 matchs.
  Douze équipes vont en séries ; places 13–14 : fin de saison ; places 15–17 :
  relégation directe pour 2027–2028. [Annonce du club TPS F1](https://hc.tps.fi/fi-fi/article/uutiset/liigan-otteluohjelma-kaudelle-20262027-julkaistu/1814/).
  Le changement vers deux niveaux à compter de 2027–2028 est annoncé par la
  ligue. [Annonce Liiga](https://www.liiga.fi/fi/uutiset/jaakiekon-sm-liiga-oy-tiedottaa-muutoksia-liigan-organisaatioon).
- **SHL :** 364 rencontres régulières annoncées. [Calendrier S1](https://www.shl.se/article/8swateo-403dd/view-40).
  Places 1–6 en quarts, 7–10 au pré-tour au meilleur de trois ; tours suivants
  au meilleur de sept. Les adversaires sont réappariés selon le classement
  régulier à chaque tour. Places 13–14 : série de maintien au meilleur de sept.
  Barème 3/2/1/0. [Formule S2](https://www.shl.se/sa-spelas-shl).

Les formats des séries et les exceptions ne doivent jamais être déduits du seul
nombre d'équipes. Les détails encore non confirmés sont listés en section 10.

## 3. « Cross league » : trois situations différentes

| Situation | Exemple | Traitement recommandé |
| --- | --- | --- |
| Deux divisions d'une même conférence | NHL, Central contre Pacific | Même compétition ; garder chaque appartenance ; comparer dans un périmètre commun |
| Deux conférences d'une même ligue | NHL, Est contre Ouest | Même compétition ; ne pas écarter le match ni ses résultats de forme régulière |
| Deux championnats nationaux | Club SHL contre club Liiga dans une coupe européenne | Compétition de la rencontre distincte ; classements domestiques comme contexte séparé |

**Exemple fictif :** Winnipeg deuxième de Central rencontre une équipe sixième
d'Atlantic. Les rangs ne sont pas directement comparables. On conserve les deux
classements officiels et peut construire une vue analytique NHL commune, à
condition que bilans, phase et date soient cohérents. On ne conclut pas à un
écart structurel de « quatre places ».

**Exemple fictif :** un club troisième de SHL rencontre un club huitième de Liiga.
Un pourcentage de points de 70 % contre 45 % ne prouve pas une différence absolue
de niveau entre pays. Ce sont deux rendements dans deux environnements distincts.
Une future comparaison interchampionnats exigera un modèle calibré, des données
sur les oppositions et une explication spécifique. En première version, on
affiche les contextes domestiques sans déclencher cette lecture comparative.

Il existe aussi des compétitions superposées : la KHL décrit une coupe dont les
rencontres comptent déjà en saison régulière. Une rencontre peut donc contribuer
à plusieurs vues sans être deux matchs. [Cup of Firsts](https://en.khl.ru/news/2026/07/17/563753.html).
Prévoir un identifiant canonique de rencontre et des rattachements de compétition,
plutôt que fusionner ou dupliquer par noms d'équipes et date.

## 4. Les points ne racontent pas tous la même chose

Barèmes réguliers usuels à représenter explicitement :

| Famille | Victoire à 60 min | Victoire OT | Victoire tirs au but | Défaite OT / tirs au but | Défaite à 60 min |
| --- | --- | --- | --- | --- | --- |
| NHL | 2 | 2 | 2 | 1 | 0 |
| AHL | 2 | 2 | 2 | 1 | 0 |
| KHL | 2 | 2 | 2 | 1 | 0 |
| Magnus, SHL | 3 | 2 | 2 | 1 | 0 |
| Liiga, Extraliga | 3 | 2 | 2 | 1 | 0 |

Sources et limites : [NHL, règle 84, édition 2025–2026](https://media.nhl.com/site/asset/public/ext/2025-26/2025-26Rules.pdf),
[AHL, documentation officielle historique](https://theahl.com/news/board-of-governors-approves-changes-for-15-16),
[KHL, annonce actuelle](https://en.khl.ru/news/2026/07/17/563753.html),
[Magnus](https://liguemagnus.com/la-ligue-magnus/formule/),
[SHL](https://www.shl.se/sa-spelas-shl),
[Liiga, règles de compétition](https://www.liiga.fi/fi/liiga/kilpailusaannot),
[fédération tchèque, article 403](https://www.ceskyhokej.cz/data/document/20260520/092606_76fc_Soutezni-a-disciplinarni-rad.pdf).
Le texte tchèque définit plusieurs systèmes : sa formule à trois points doit
être rattachée à la compétition par ses normes techniques. Les références
historiques NHL/AHL et toutes les exceptions doivent être confirmées dans les
éditions actuelles avant de déclarer leurs politiques complètes.

### Rendement normalisé

`rendement = points sportifs gagnés / (matchs joués × maximum par match)`.

Exemple fictif : 14 points sur 10 matchs donnent 70 % sous un barème à 2 points,
mais 46,7 % sous un barème à 3 points. Ce rendement aide à comparer des équipes
ayant joué un nombre différent de matchs **dans un périmètre pertinent**.
Il ne corrige ni difficulté des adversaires, ni calendrier déséquilibré, ni
différence de force entre championnats. Ce n'est pas une probabilité de victoire.

Le barème NHL/KHL distribue généralement deux points si le match se termine à
60 minutes et trois après OT/tirs au but. Le rendement dépend donc aussi de la
fréquence de ces issues. Comparer plusieurs indicateurs plutôt qu'un seul total.

### Conserver quatre notions distinctes

1. **Classement officiel** : rang et points reçus, contexte du groupe et départages.
2. **Rendement analytique** : formule et périmètre affichés, sans remplacer le rang.
3. **Points administratifs / reportés** : sanctions ou acquis d'une autre phase.
4. **État d'une série** : victoires et objectif de qualification, pas un championnat
   à points fictif pendant les playoffs.

Une exception importante figure dans la règle NHL 84.2 de 2025–2026 : une défaite
en OT après sortie volontaire du gardien peut faire perdre le point normalement
acquis, hors pénalité différée. Il faut reconfirmer ce cas en 2026–2027 et vérifier
si la source le distingue. Un simple `overtimeLoss = 1` ne couvre pas tous les cas.
[Règlement NHL](https://media.nhl.com/site/asset/public/ext/2025-26/2025-26Rules.pdf).
Les points officiels doivent garder la priorité sur une reconstruction incomplète.

## 5. Phases, scores et historique

### Phases obligatoires

Pré-saison, saison régulière, pré-tour, playoffs, maintien/barrage, coupe et
rencontre amicale ne doivent pas se mélanger silencieusement. Chaque match doit
porter une phase vérifiée ou un état « phase inconnue ». Le numéro de saison
seul ne suffit pas.

L'API peut employer `2026` pour une saison sportive 2026–2027. Garder la clé
fournisseur et une identité de saison interne explicite ; ne pas basculer les
calculs au 1er janvier. Les changements de format doivent dépendre de cette
saison sportive.

Pour les séries : stocker round, identifiant de série, numéro de match, nombre
de victoires requis, bilan courant et périmètre de qualification. Ne pas figer
un tableau d'adversaires si le règlement prévoit un réappariement.

### Plusieurs résultats d'un même match

- Score à 60 minutes, score après prolongation, résultat final et séance de tirs
  au but : champs et périmètres distincts.
- Le score de la séance de tirs au but ne doit pas être ajouté comme autant de
  buts joués aux statistiques offensives.
- « Victoire », « invaincu à 60 minutes » et « a pris au moins un point » décrivent
  trois faits différents. Les lectures et leur bilan doivent annoncer lequel.
- Un marché « vainqueur, OT incluse » n'est pas un marché à trois issues à 60
  minutes. Chaque évaluation doit conserver les règles du marché exact.
- Pas de nul final pour les matchs réguliers réglés par OT/tirs au but, mais un
  nul à 60 minutes reste possible et utile.

Pour les buts et périodes, préserver la preuve du fournisseur. Aucune animation
ou chronologie inventée à partir du seul score final. L'AHL distingue officiellement
OT régulière de cinq minutes à trois contre trois et OT de playoffs de vingt
minutes à effectif complet. [FAQ AHL](https://theahl.com/faq).
Le modèle doit donc accepter une durée et une règle OT par phase, pas un chrono
universel de cinq minutes.

### H2H, forme et joueurs

Les confrontations doivent conserver compétition d'origine, phase, saison,
rôles domicile/extérieur, périmètre de score et date. Présenter « championnat »
et « toutes compétitions » comme dans le football, avec filtres explicites.

Pour les premières lectures : forme dans la même ligue et même phase ; H2H
officiels identifiés, avec fenêtre et nombre minimal définis. Toute extension à
plusieurs phases ou compétitions doit être une décision de politique visible.

Une fenêtre de cinq **apparitions** d'un joueur diffère de cinq matchs de son
équipe. Sans feuilles d'alignement, une absence d'événement ne prouve ni présence,
ni blessure, ni zéro contribution. Les contributions au Radar restent factuelles,
avec leur couverture ; une photo ou un nom similaire n'établit pas une identité.

Le domicile à droite, choisi pour la présentation hockey, est indépendant des
identités métier. Cotes, buts, statistiques et événements restent rattachés à
l'équipe par identifiant. Une rencontre sur terrain neutre peut avoir un domicile
administratif : afficher cette distinction si elle est connue.

## 6. Audit de nos données : points concrets

Le compact existant contient 475 rencontres et sept compétitions. Comptage
reproduit directement sur `var/sports/hockey/published.json` :

| Ligue | Lignes de classement | Équipes uniques | Matchs joués par équipe dans ces lignes |
| --- | ---: | ---: | --- |
| NHL | 64 | 32 | 1–3 |
| AHL | 32 | 32 | 1–2 |
| KHL | 44 | 22 | 9–13 |
| Extraliga | 14 | 14 | 6–8 |
| Magnus | 12 | 12 | 7 |
| Liiga | 17 | 17 | 8–11 |
| SHL | 14 | 14 | 4–5 |

**NHL :** les 64 lignes sont 32 vues par conférence et 32 vues par division.
Le brut `var/sports/hockey/audit/standings-57.json` contient en plus 32 lignes
de pré-saison, soit 96 lignes au total. Additionner les bilans serait une erreur.

**KHL :** même problème potentiel avec 44 lignes pour 22 équipes. Pour créer une
vue analytique de toute la ligue, retenir une seule ligne canonique cohérente
par équipe, puis vérifier que ses différentes vues ont les mêmes totaux.
La vérification effectuée sur ce compact ne trouve aucun désaccord entre les
vues pour matchs joués, points, victoires, défaites et résultats OT. Elle établit
leur cohérence interne à cette date, pas leur exactitude réglementaire complète.

**AHL :** les groupes ne sont pas de taille égale. Le compact ne fournit pas
de table de conférence ; une hiérarchie supplémentaire doit venir d'une
configuration vérifiée, jamais de la position dans la réponse JSON.

**Phases :** `formPhaseVerified` est faux pour la NHL, vrai pour les six autres.
Dans `hockey_feed.ts`, ce booléen est fondé sur les intitulés des classements.
Il ne démontre pas que chaque match historique appartient à la saison régulière.

Le collecteur signale lui-même que les réponses `games` ne donnent pas cette
phase pour la NHL. Le futur champ ne peut donc pas être rempli en recopiant le
libellé du classement. Prévoir une correspondance vérifiée avec le calendrier
officiel, une source qui fournit la phase, ou une politique de calendrier
documentée avec gestion des exceptions. Une date de début seule n'est pas une
preuve générale ; ce qui ne peut pas être établi reste inconnu.

L'audit API existant a montré un exemple où les statistiques saisonnières de
Winnipeg combinaient pré-saison et saison régulière. Une collecte réussie peut
donc donner un agrégat impropre à une lecture. Voir
`docs/audits/api-hockey/2026-10-04/README.md`.

Ces fichiers sont des captures du 4 octobre, pas une vérification du live actuel.

## 7. Audit du code : écarts à résoudre

| Élément actuel | Limite observée | Évolution nécessaire |
| --- | --- | --- |
| `SportStandingTable(stage, group, rows)` | Groupe en texte libre, aucune hiérarchie typée | Identifiant de phase, type de groupe, parent, saison et portée |
| `HockeyStanding.comparisonGroup` | Égalité de chaîne seulement | Résolveur du périmètre commun ; distinction classement officiel / analytique |
| `HockeyMatchContext` / `HockeyRecentGame` | Compétition et saison, sans phase | Phase par match, preuve et contrôle des fenêtres |
| `HockeyPointsRules` | Barèmes 2/1/0 et 3/2/1/0 disponibles, pas de registre complet des ligues | Politique explicite par compétition/saison/phase ; exceptions et ajustements |
| `_usableStanding` | Rejette points négatifs ; ne distingue pas sanctions/report | Séparer points sportifs, points officiels et ajustements connus |
| `HockeyTierPreview` | Seuil de 0,45 point/match pour toutes les ligues | Seuil normalisé/calibré ; base de comparaison conservée avec chaque tier |
| `formPhaseVerified` | Heuristique de libellé de classement | Vérification par match et contrôle de concordance des agrégats |
| `SportVenueStandings` | Taux de victoires, pas rendement officiel en points | Nommer exactement l'indicateur ; ajouter points seulement avec preuve complète |

Le preview des tiers n'alimente actuellement aucune lecture ni conclusion de
pari. Son tier 1 dans une division ne signifie pas tier 1 comparable partout.
L'échantillon minimal actuel de cinq matchs et le seuil 0,45 sont des hypothèses
de preview, pas une règle sportive validée.

`HockeyReadingEngine` reste un brouillon de trois détecteurs. Son minimum de
dix matchs exclurait actuellement les classements NHL et AHL ; c'est une
abstention attendue au début de saison, pas un échec de collecte. Il ne faut
pas copier ce seuil à toutes les futures lectures sans calibration.

## 8. Architecture recommandée

```text
Concept de lecture partagé
  └── Implémentation par sport
       └── CompetitionSeasonPolicy
            ├── phase et groupes / hiérarchie
            ├── barème et exceptions de points
            ├── périmètres de résultat et de marché
            ├── classement officiel et départages
            ├── qualification / séries / maintien
            └── AnalyticalPolicy : fenêtres, comparabilité, seuils
```

Les règlements factuels et les hypothèses analytiques doivent être deux objets
distincts. Changer un seuil de forme ne doit pas changer les règles officielles.

Configuration déclarative versionnée, avec algorithmes typés testés :

- Clé : `hockey / api-hockey / competitionId / seasonId / phaseId`.
- Références officielles, date de vérification, état `verified / partial / unknown`.
- Groupes stables identifiés, appartenances d'équipe datées, liens parent/enfant.
- Vue officielle choisie pour l'affichage ; pool analytique choisi pour la lecture.
- Politique d'historique et capacités effectivement prouvées par le fournisseur.
- Règles de départage référencées, pas un simple tri `points puis buts` universel.
- Politique inconnue : données factuelles affichées ; calcul dépendant suspendu.

Un registre de compétition remplit ces objets ; l'adaptateur normalise la donnée.
Les widgets communs présentent les résultats déjà préparés. Aucun widget n'a à
connaître le nombre de conférences ou le barème d'une ligue.

**Hiérarchie NHL à représenter**, d'après les groupes effectivement collectés :

```text
NHL / saison 2026–2027 / saison régulière
├── Eastern Conference
│   ├── Atlantic Division
│   └── Metropolitan Division
└── Western Conference
    ├── Central Division
    └── Pacific Division
```

Les vues de groupe contiennent des références à un même bilan canonique. Une
vue générale analytique éventuelle se construit séparément et porte ce libellé.
Elle ne remplace ni classement de conférence, ni place de qualification.

## 9. Tests à prévoir avant activation

1. **Identités et vues :** 64 lignes NHL → 32 bilans ; 44 KHL → 22. Un désaccord
   entre vues est signalé, pas résolu en additionnant ou choisissant au hasard.
2. **Cross division / conférence :** le match reste affiché ; rangs incomparables
   ne déclenchent pas `structural_level_gap`. Les autres lectures restent évaluées.
3. **Cross championnat :** aucune comparaison automatique des rangs ou tiers
   SHL/Liiga ; contextes domestiques présents avec leur périmètre.
4. **Phases :** présaison et playoffs exclus d'une fenêtre régulière ; phase
   inconnue → abstention pour les calculs qui en dépendent.
5. **Points :** six issues par barème ; ajustements/report séparés ; exception
   non renseignée empêche la reconstruction des points concernés.
6. **Résultats :** 3–3 à 60 min, 4–3 OT → nul réglementaire et victoire finale ;
   tirs au but séparés des buts joués et marchés évalués dans leur périmètre.
7. **Saisons :** changement de politique 2026–2027 / 2027–2028 sans réécrire les
   évaluations passées ; aucune fuite de données postérieures au coup d'envoi.
8. **Séries / maintien :** bilan de série, réappariement et points reportés sans
   appliquer le rendement régulier à des totaux d'une autre phase.
9. **Rôles et UI :** visiteur à gauche / domicile à droite sans inversion des
   statistiques, cotes, événements et filtres de confrontation.
10. **Publication :** brut → contexte normalisé → compact → lecture publique →
    affichage, avec cas vide valide et lecture indisponible sans écran bloquant.
11. **Football :** non-régression des calculs, préférences, parcours et publications
    existants lors de l'introduction du registre de politiques commun.

Ces tests sont un plan de couverture ; ils n'ont pas été ajoutés ou exécutés
dans cette itération documentaire. Les vérifications effectuées ici sont la
lecture du code, le comptage du brut/compact et la confrontation aux sources.

## 10. Ordre de mise en œuvre et points restant à confirmer

### Chantier 1 : sécuriser le contexte

Ajouter phases, groupes typés, bilans canoniques, politique de saison et preuves
de couverture. Conserver les classements fournisseur pour l'affichage ; aucune
lecture de niveau sans périmètre commun validé. Corriger le preview des tiers
avant de lui donner une portée analytique.

### Chantier 2 : lectures régulières

Commencer par résultats et forme explicites, domicile/extérieur, production de
buts et H2H. Puis calibrer écarts de forme et de niveau. Les séries de victoires,
matchs avec points et invincibilité à 60 minutes restent des concepts distincts.

### Chantier 3 : particularités documentées

Qualification, contexte de série, unités spéciales, gardiens et fatigue uniquement
avec règles et données vérifiées. Les championnats inconnus ne reçoivent aucune
politique NHL par défaut.

### Vérifications ciblées encore nécessaires

- Télécharger/consulter les règlements 2026–2027 NHL et AHL pour départages,
  exceptions de points et règles de séries ; l'outil de lecture n'a pas extrait
  le PDF NHL courant ni le contenu du livre AHL intégré à un lecteur externe.
- Obtenir les normes techniques Extraliga 2026–2027 : quotas, départages et
  modalités exactes du barrage. Le calendrier et le règlement fédéral seuls
  ne suffisent pas à certifier l'ensemble de la politique.
- Confirmer les départages, modalités OT et tours de séries actuels des autres
  ligues, ainsi que la base précise des points conservés en maintien Magnus.
- Vérifier les champs fournisseur par phase et les conventions tirs au but,
  matchs sur terrain neutre, sanctions et compétitions superposées.
- Vérifier couverture PP/PK, tirs, gardiens, présences et temps de glace avant
  toute lecture qui les utilise. Les statistiques visibles sur le site d'une
  ligue ne prouvent pas leur disponibilité dans notre abonnement API.

L'étude établit le modèle et les risques concrets. Elle ne certifie pas encore
une politique complète et automatisable pour les sept ligues. Cette validation
doit être faite champ par champ avec les sources et les données correspondantes.

## 11. Coût et infrastructure

La hiérarchie des classements, les politiques et la normalisation sont surtout
du travail de modèle, d'adaptateur et de tests. Elles n'ajoutent pas mécaniquement
d'appels fournisseur : les réponses existantes contiennent déjà les groupes.

La consommation supplémentaire viendra surtout d'historiques à compléter,
événements, statistiques et actualisations live. Elle doit être chiffrée après
mesure de la couverture et des routes réellement nécessaires. Les 7 500 appels
quotidiens ne constituent pas une preuve suffisante pour n'importe quel rythme.

Ce chantier n'impose pas de nouvelle infrastructure. Supabase peut conserver
compétitions, saisons, politiques, bilans et publications qualifiés par sport.
La capacité réelle devra être mesurée sur le volume stocké, la fréquence des
écritures, la rétention et le trafic ; rien dans l'étude ne justifie une migration
d'infrastructure à ce stade.
