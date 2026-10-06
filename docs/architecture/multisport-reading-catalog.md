# Lectures multisport : concepts communs et règles par discipline

> Évolution fonctionnelle du 6 octobre : dix lectures hockey sont maintenant raccordées et les séries générale/domicile/extérieur partagent leur compteur avec le football. Voir [les règles et la vérification de cette itération](../audits/multisport/2026-10-06-hockey-form-and-series-readings.md). Le contenu daté ci-dessous reste une étude historique.

> Évolution du 6 octobre : les tiers Lector hockey et la lecture d’avantage au classement utilisent désormais le moteur de partition commun au football, avec cinq matchs minimum et des repères analytiques de groupe. Voir [la décision et ses contrôles](../audits/multisport/2026-10-06-hockey-standing-tiers.md). Les constats de l’étude ci-dessous décrivent l’état du 5 octobre.

Date : 5 octobre 2026. Branche : `codex/multisport-hockey`.

Complément : [formats des sept ligues et règles de comparaison hockey](hockey-competition-rules-study.md).

## 1. Décision proposée

Une lecture représente un **fait sportif explicable**, par exemple « Forme en
hausse ». Son identité et son sens peuvent être communs à plusieurs sports.
Sa détection dépend du sport, de la compétition et de la phase de saison.

Séparer deux questions :

1. **Le concept s'applique-t-il à ce sport ?**
2. **Avons-nous les données et les règles validées pour le calculer ici ?**

Une lecture commune peut être indisponible dans une ligue. Une lecture propre
au hockey peut être indisponible en NHL avec notre source actuelle. Le nombre
de lectures proposées à l'utilisateur doit découler de cette disponibilité.

« Commun » signifie ici partageable entre football et hockey. Le basket,
baseball et football américain devront déclarer leurs propres compatibilités ;
ils ne recevront pas automatiquement toutes les lectures.

Cette itération établit le catalogue et les prérequis. Elle ne modifie aucun
calcul football, n'active aucune lecture hockey sur les matchs, et ne publie
aucune modification en production ou sur la démo.

## 2. Ce que contient réellement le projet

### Catalogue football

Le catalogue sélectionnable est `ReadingPreferenceCatalog.values`, dans
`lib/features/onboarding/domain/decision_profile_catalogs.dart` : **28 lectures**.
Les catalogues documentaires anciens recensent aussi des candidats et des
indicateurs techniques ; ils ne constituent pas ce catalogue sélectionnable.

Les calculs et la présentation sont encore largement rattachés au football :
`FootballAnalyzer`, `FootballReading`, `OpportunityEngineV2`, les guides, le
bilan et les fonctions de publication. `FootballModule.definition.readings`
est actuellement vide : le registre multisport n'est donc pas encore la source
commune de toutes les définitions des lectures football.

### Hockey

`HockeyReadingEngine` contient trois détecteurs de brouillon :

- `standing_advantage` : au moins 10 matchs par équipe, écart de 15 points de
  pourcentage des points disponibles ;
- `recent_form_advantage` : cinq matchs par équipe, écart de 20 points de
  pourcentage ;
- `winning_streak` : trois victoires consécutives, OT/tirs au but inclus.

Ces seuils sont ceux de `hockey-readings-draft-v1`, **pas des seuils calibrés**.
Depuis la première [itération fonctionnelle du 5 octobre](../audits/multisport/2026-10-05-functional-hockey-readings.md),
ces trois détecteurs sont raccordés au compact réellement lu par Flutter via
`HockeyFeedReadings`. Le module déclare la capacité `readings`. Leur activation
est explicite dans les préférences hockey. Le Radar des joueurs garde son rôle
distinct : la présence d'un joueur n'est pas automatiquement une lecture de match.

Trois erreurs de rapprochement à éviter :

| Brouillon hockey | Rapprochement possible | Rapprochement incorrect |
| --- | --- | --- |
| `standing_advantage` | Supériorité au classement, indicateur d'appui | `structural_level_gap` : un simple avantage n'établit pas une rupture structurelle |
| `recent_form_advantage` | Avantage de forme | `form_gap` : le football exige actuellement 9 points sur 15 d'écart, une différence beaucoup plus marquée |
| `winning_streak` | Série de victoires, concept partageable nouveau | `positive_streak` : une dynamique positive ne signifie pas nécessairement trois victoires consécutives |

On conserve des identités distinctes tant que les définitions ne sont pas
alignées. Aucun rapprochement automatique par libellé, traduction ou ressemblance.

## 3. Matrice des 28 lectures sélectionnables football

### A. 18 concepts communs à football et hockey

Les IDs football existants peuvent devenir les IDs des concepts communs.
Chaque sport fournit une politique et une évaluation distinctes. Les propositions
hockey ci-dessous décrivent le sens attendu, pas des détecteurs déjà activés.

| ID existant | Nom commun | Adaptation nécessaire pour le hockey |
| --- | --- | --- |
| `structural_level_gap` | Écart de niveau structurel | Groupe de classement comparable, maturité, pourcentage de points et rupture significative ; ne pas copier « six places » entre divisions/conférences |
| `positive_streak` | Dynamique positive | Résultats favorables sur une fenêtre complète ; définir séparément victoires finales, matchs avec points et invincibilité à 60 minutes |
| `negative_streak` | Dynamique négative | Faible rendement en points selon le barème de la ligue ; une défaite OT peut rapporter un point |
| `improving_form` | Forme en hausse | Deux fenêtres chronologiques comparables, rendements normalisés, seuil hockey à calibrer |
| `declining_form` | Forme en baisse | Même contrat, évolution inverse |
| `form_gap` | Écart de forme | Opposition forte entre deux fenêtres complètes, avec barème de la ligue ; distinguer avantage modéré et écart marqué |
| `strong_home_team` | Solide à domicile | Échantillon à domicile, points et/ou victoires finales selon la règle annoncée, phase homogène |
| `weak_home_team` | Fragile à domicile | Même périmètre, faiblesse mesurée |
| `strong_away_team` | Solide à l'extérieur | Échantillon à l'extérieur, mêmes contrôles |
| `weak_away_team` | Fragile à l'extérieur | Même périmètre, faiblesse mesurée |
| `home_away_advantage` | Avantage domicile / extérieur | Comparer la solidité du domicile à la fragilité du visiteur, pour le même match |
| `away_home_advantage` | Avantage extérieur / domicile | Comparaison inverse ; l'ordre visuel hockey ne change jamais les rôles métier |
| `prolific_attack` | Attaque prolifique | Buts marqués par match éligible, référence de la même ligue/phase ; séparer 60 minutes, OT et but de résultat des tirs au but |
| `scoring_difficulty` | Production offensive faible | Faible production relative à la ligue ; aucun seuil de buts football recopié |
| `solid_defense` | Défense solide | Buts encaissés dans un périmètre de score déclaré, référence de ligue |
| `fragile_defense` | Défense fragile | Même contrat, profil perméable |
| `head_to_head_dominance` | Domination en tête-à-tête | Confrontations antérieures éligibles, domicile/extérieur, phase et ancienneté ; victoire à 60 minutes distincte de victoire finale |
| `standout_decisive_player` | Joueurs décisifs | Buts et passes décisives vérifiés ; jusqu'à deux assists par but, identité fournie par noms actuellement, temps de glace/présence inconnus |

**Exemple de différence de calcul.** Le football attribue 3/1/0 points à V/N/D.
En saison régulière NHL, une victoire rapporte 2 points et une défaite OT/tirs
au but peut rapporter 1 point. Ainsi, quatre victoires et une défaite OT donnent
9/10 points : ce peut être une bonne dynamique, sans constituer cinq victoires
ni une série invaincue au résultat final. La règle et la preuve doivent exprimer
exactement ce qui est mesuré. Le barème NHL est documenté par
[Seattle Kraken / NHL](https://www.nhl.com/kraken/news/seattle-kraken-nhl-league-standings-explainer-326957072).

Le concept « attaque prolifique » n'impose pas la même quantité de buts dans
tous les sports. Une règle pourrait comparer l'équipe à une zone haute de sa
ligue, mais la couverture de cette référence et sa maturité doivent être vérifiées.
Le seuil relatif ne sera pas déterminé à partir des seules deux équipes du match.

### B. 4 concepts partageables sous conditions

Ils ne sont pas intrinsèquement réservés au football. Leur transfert au hockey
nécessite une définition utile et des données suffisantes.

| ID existant | Football actuel | Position pour le hockey |
| --- | --- | --- |
| `frequent_clean_sheet` | Clean sheets fréquents | Concept « cage inviolée » partageable ; libellé hockey « blanchissages fréquents ». Fréquence et minimum d'échantillon à recalibrer, sans attribuer le résultat à un gardien inconnu |
| `frequent_btts` | BTTS fréquent | Les deux équipes qui marquent est calculable au hockey, mais peut être trop fréquent pour être discriminant. Étudier sa distribution avant de l'exposer ; ne pas le transformer silencieusement en « deux équipes à 2+ buts » |
| `misleading_result` | Résultats à nuancer, appuyé notamment sur les xG | Concept commun ; hockey indisponible avec les seules données actuelles. Une victoire OT ou un écart faible ne prouve pas à eux seuls un résultat trompeur |
| `key_player_unavailable` | Joueur important absent | Concept commun ; exiger absence factuelle, identité et rôle. Zéro contribution dans les événements ne prouve ni absence ni non-participation |

Les xG, tirs et performances sous-jacentes appartiennent aussi à des familles
partageables. **Indisponible chez notre fournisseur hockey dans l'échantillon
audité ne signifie pas réservé au football.**

### C. 6 variantes actuelles à conserver dans le football

| ID football | Libellé | Traitement multisport |
| --- | --- | --- |
| `frequent_over_25` | Tendance over 2,5 buts | Variante football actuelle. Créer un concept de total paramétré pour le hockey, avec ligne et périmètre explicites ; ne pas renommer cet ID en over 5,5 |
| `frequent_under_25` | Tendance under 2,5 buts | Même principe |
| `frequent_first_half_scoring` | Marque souvent en première mi-temps | Variante football de la famille « production par période » |
| `frequent_first_half_conceding` | Encaisse souvent en première mi-temps | Idem |
| `frequent_second_half_scoring` | Marque souvent en seconde mi-temps | Idem |
| `frequent_second_half_conceding` | Encaisse souvent en seconde mi-temps | Idem |

La ligne 2,5 n'est pas physiquement impossible au hockey : c'est **la variante
du produit football existant** qui reste dans son module. Le concept parent
« tendance au-dessus d'un total » est commun. Les mi-temps football ne deviennent
pas les tiers hockey par simple changement de texte : durée, nombre de périodes,
historique et règles changent.

Les **corners** et **cartons jaunes/rouges** constituent d'autres métriques propres
au football dans les deux modules étudiés. Le moteur et les documents candidats
en contiennent, mais ils ne figurent pas dans les 28 préférences ci-dessus.
Le concept parent « discipline » peut être partagé ; sa variante « cartons »
ne doit jamais compter les pénalités hockey.

## 4. Variantes propres au hockey et nouvelles familles communes

### Variantes hockey à étudier

| Proposition | Nature | Données nécessaires / état actuel |
| --- | --- | --- |
| Efficacité en supériorité numérique | Hockey : power play | Buts PP **et opportunités PP** ; opportunités non établies dans les données auditées |
| Solidité en infériorité numérique | Hockey : penalty kill | Situations d'infériorité et buts concédés dans ces situations ; non établis |
| Gardien titulaire en forme | Variante hockey du concept générique « joueur clé / poste » | Gardien attendu/confirmé, arrêts, tirs reçus, temps de jeu, échantillon comparable ; non établis |
| Domination à cinq contre cinq | Variante hockey | Buts/tirs avec effectifs à cinq contre cinq et temps comparable ; non établis |
| Départs forts au premier tiers | Variante hockey de « production par période » | Score P1 et historique éligible ; scores par période présents dans les historiques H2H, pas dans toutes les formes compactées |
| Fragilité au troisième tiers | Même famille | Score P3, contexte et échantillon ; étudier si le gardien retiré doit être distingué lorsque l'information existe |
| Performance en prolongation / tirs au but | Variante hockey de « fin après temps réglementaire » | Statuts, score à 60 minutes et score final ; ne pas attribuer une victoire finale à une victoire à 60 minutes |

La NHL distingue officiellement les victoires en temps réglementaire, avec
prolongation et avec tirs au but, comme décrit dans
[sa procédure de classement](https://media.nhl.com/site/asset/public/ext/2019-20/Start%20of%20Season/2019-20_TiebreakingProcedure.pdf).
Le score de résultat des tirs au but comprend
un but attribué au vainqueur ; ce but ne doit pas devenir un but de joueur ni
une occasion dans les lectures d'attaque. Voir
[les règles de départage NHL](https://www.nhl.com/info/standings-info/tie-breaking-procedure).

### Familles nouvelles à rendre communes dès leur création

- **Avantage de repos / calendrier chargé** : horaires et calendrier complet ;
  pertinente pour hockey et football, même si la fréquence et les seuils diffèrent.
  Un enchaînement deux jours de suite est une variante, pas un nouveau moteur commun.
- **Série de victoires** : concept commun distinct de dynamique positive ;
  préciser victoire réglementaire ou finale dans la règle et la preuve.
- **Match ouvert / fermé** : famille commune, référence et distribution propres
  au sport ; ne pas assimiler automatiquement match ouvert à over d'une ligne donnée.
- **Production par période** : famille commune, avec identifiant de variante
  `football.first_half` ou `hockey.first_period`, par exemple.
- **Tendance de total** : paramètres ligne, durée et inclusion OT/tirs au but.
- **Écart entre production et résultat** : commun lorsque tirs/xG ou autres
  données pertinentes sont réellement disponibles.

Le hockey enrichit le catalogue sans entraîner de changement de sens des
lectures déjà enregistrées dans les profils football.

## 5. Données disponibles : photographie du 4 octobre

Analyse locale de `var/sports/hockey/published.json`, capturé le
**4 octobre 2026 à 19:58:28 UTC**. Aucune nouvelle requête fournisseur effectuée
pour ce cadrage. Ces nombres décrivent cette publication, pas l'état actuel des ligues.

| Ligue | Matchs dans la fenêtre | Équipes avec 5 résultats dans la forme publiée | Équipes ayant joué au moins 10 matchs dans le classement | Drapeau actuel `formPhaseVerified` |
| --- | ---: | ---: | ---: | --- |
| NHL | 132 | 0 | 0 | false |
| AHL | 78 | 0 | 0 | true |
| KHL | 81 | 22 | 21 | true |
| Extraliga | 47 | 14 | 0 | true |
| Ligue Magnus | 38 | 12 | 0 | true |
| Liiga | 54 | 17 | 11 | true |
| SHL | 45 | 14 | 0 | true |

Total : **475 matchs**, sept ligues. Le Radar contient **815 profils**, issus
des événements ; couverture de 69 équipes complète, 30 historiques insuffisants
et 12 journaux d'événements incomplets. Ces statuts empêchent de traiter une
absence de données comme un zéro confirmé. Ils ne valident pas une identité
globale de joueur ni sa participation : la source reste `event-name`.

### Deux prérequis à renforcer avant l'activation

1. **Phase de saison.** Le drapeau `formPhaseVerified` repose actuellement sur
   un classement ne contenant qu'une phase « Regular Season ». Les matchs bruts
   n'ont pas de phase explicite. Ce contrôle bloque le mélange constaté en NHL,
   mais il ne constitue pas une preuve individuelle de la phase de chaque match.
   Déclarer cette preuve ou conserver `phase_unknown` ; ne pas considérer le
   seul drapeau comme une garantie pour de nouvelles lectures publiées.
   `HockeyMatchContext` n'a pas encore de champ de phase : il doit être ajouté
   au raccordement du moteur.
2. **Périmètre des scores historiques.** La forme compacte conserve résultat,
   statut, buts et date, mais pas tous les scores par période/régulation.
   Le calendrier et les historiques H2H conservent davantage de scores. Pour
   les lectures à 60 minutes ou par tiers, enrichir le contexte analytique depuis
   ces sources sans déduire le score réglementaire du score final.

Les barèmes des sept ligues et de leurs phases restent à enregistrer depuis
leurs règles officielles. Le modèle possède un barème NHL et un barème à trois
points ; leur existence ne prouve pas lequel utiliser pour chacune des ligues.
Une compétition inconnue ne reçoit pas de barème par défaut.

### Statistiques indisponibles dans l'échantillon audité

Le précédent appel `games/statistics?game=444616` a reçu HTTP 200 avec une erreur
de point d'accès. L'audit de Winnipeg–Boston fournit résultats, périodes,
événements et agrégats buts/victoires, mais pas de tirs, temps de glace, gardien
titulaire, xG ou dénominateurs PP/PK. Cela borne notre source vérifiée ; ce n'est
pas une affirmation d'absence chez tous les fournisseurs.

Le [guide officiel API-Sports hockey](https://www.api-football.com/news/post/ice-hockey-world-championship-2026-guide-to-using-data-with-api-sports)
décrit les routes de classement, statistiques d'équipe, H2H et événements.
La [documentation interactive](https://api-sports.io/documentation/hockey/v1)
n'a pas fourni de texte exploitable au lecteur utilisé ici. Les capacités
ci-dessus sont donc fondées surtout sur les réponses brutes conservées et
sur le compact réel, pas sur des endpoints supposés.

## 6. Architecture à mettre en place

### Trois niveaux de configuration typée

**Catalogue commun des concepts**

- `conceptId` stable, sens, famille et type de sujet : équipe, joueur ou match ;
- nom commun et éventuelles variantes de libellé ;
- exemples et explications cohérents avec chaque variante ;
- sports compatibles déclarés explicitement.

**Politique par sport et variante**

- `ruleId`, `ruleVersion`, `conceptId` et paramètres validés ;
- fenêtres, maturité, minimum d'échantillon, métriques et dénominateurs ;
- périmètre de score : réglementaire, final, période ;
- sources requises, couverture et conditions de comparaison ;
- détecteur dans le module football ou hockey ;
- règle de suivi dans le bilan, distincte de la détection avant match.

**Règles de compétition et phase**

- barème de points, format, durée des périodes, OT/tirs au but ;
- saison régulière / présaison / playoffs et groupes comparables ;
- exceptions déclarées, aucune déduction de règles depuis un nom de ligue.

Exemple de contrat conceptuel, non encore ajouté au runtime :

```text
conceptId: form_gap
sport: hockey
competition: api-hockey:57
phase: regular_season
ruleId: hockey.form_gap
ruleVersion: <version validée>
parameters:
  window: <fenêtre calibrée>
  minimumSample: <échantillon validé>
  pointsSystem: nhl_regular_season
  minimumNormalizedGap: <seuil calibré>
outcomeScope: <périmètre explicitement choisi>
```

Les ID historiques football restent inchangés pour préserver profils, annonces
et bilan. Une implémentation hockey peut partager `conceptId: form_gap`, avec
une clé complète de résultat contenant le sport. Pour les variantes spécifiques,
utiliser des ID propres, sans changer la signification d'un ID existant.

**Partager les fonctions génériques** : tri chronologique, déduplication,
fenêtres avant coup d'envoi, contrôles d'échantillon, calcul de ratios,
références de ligue, preuves et rendu. Les interprétations de résultat et les
règles de décision restent dans les politiques de discipline.

Le résultat commun doit conserver au minimum : sport, match, sujet, concept,
variante, version de règle, phase, date d'évaluation, matchs sources, métriques,
statut (`detected`, `notDetected`, `insufficientData`) et raison d'indisponibilité.
Étendre `SportReadingAssessment` dans ce sens. La provenance ne doit pas se
réduire à une phrase et un compteur de matchs.

### Préférences et parcours

Une activation utilisateur est enregistrée **par compte et par sport**, même si
le concept est partagé. Les lectures football ne sont pas automatiquement
activées au hockey. `ScopedSportPersistence` fournit déjà cette séparation
locale ; le stockage distant des préférences hockey doit également la respecter.

Le rendu et les composants restent communs. `Pour moi` applique compétitions
et lectures choisies ; le Radar peut explorer des compétitions hors préférences
en montrant les lectures hockey sélectionnées pour ce compte. Aucun profil
football ne doit entrer dans la sélection hockey. Une lecture détectée mais
non choisie n'est pas une sélection utilisateur implicite.

### Scénarios, marchés et bilan

Un scénario réunit des lectures pour **le même match, sujet et instant**. Les
noms de scénarios peuvent être communs, mais leurs dépendances et seuils doivent
être déclarés par discipline. Le catalogue des scénarios sera étudié après
validation des lectures ; ne pas simplement copier les scénarios football.

Une lecture n'a pas besoin de cote pour être affichée. Un marché associé exige
une cote réelle et un périmètre explicite. Winnipeg–Boston illustre la différence :
Boston gagne 4–3 au final, mais le résultat à 60 minutes est 3–3.

Le bilan conserve la lecture évaluée avant match ; il ne la recalcule pas avec
les données finales. « Défense solide » ne veut pas automatiquement dire
« équipe gagnante » : une défaite 0–1 peut rester compatible avec une faible
production adverse. Pour chaque lecture, définir ce qui est observé après match,
le verdict possible et le cas non évaluable. Ni succès arbitraire ni assimilation
à un pari gagnant. Un changement de règle reste traçable par sa version.

## 7. Ordre d'implémentation recommandé

1. **Catalogue commun et contrats de règles** : référencer les 28 IDs existants,
   connecter progressivement le module football via un adaptateur, conserver ses
   sorties. Remplacer les seuls brouillons hockey après alignement sémantique.
2. **Contexte hockey fiable** : règles explicites des sept ligues, phase et
   historique éligible, résultats réglementaires/finals, provenance/couverture.
   Tester d'abord une ligue ayant de la matière, par exemple KHL ou Liiga,
   plutôt que d'abaisser les exigences pour afficher des lectures en NHL.
3. **Premier lot commun** : forme positive/négative, évolution, écart de forme,
   domicile/extérieur, attaque/défense. Ajouter H2H après filtres de phase et
   d'ancienneté ; niveau structurel après référence comparable et maturité.
4. **Joueurs et profils** : réutiliser les contributions vérifiées du Radar,
   expliciter l'identité par noms et l'absence de preuve de participation ;
   brancher la lecture sélectionnable sans la confondre avec le classement Radar.
5. **Spécificités hockey** : commencer par périodes et prolongation lorsque
   l'historique le permet. PP/PK, gardiens et tirs restent conditionnés à la source.
6. **Scénarios puis bilan** : convergence stricte, annonce figée avant match,
   suivi explicite, aucune contamination entre sports.

### Vérifications requises pour activer les lectures

- mêmes données football → mêmes IDs, détections et préférences qu'avant ;
- un même concept produit des preuves différentes et cohérentes pour chaque sport ;
- barème NHL et autre barème testés séparément ;
- phase inconnue, présaison mélangée et fenêtre incomplète → données insuffisantes ;
- pas d'utilisation de résultat ou classement connu après l'instant d'analyse ;
- OT/tirs au but, zéro confirmé et donnée absente distingués ;
- compte connecté, invité et sport actif ne mélangent pas leurs sélections ;
- collecte → brut → analyse versionnée → compact → front : test de contrat réel,
  incluant journée vide et lecture non disponible ;
- résultat après match relié à l'annonce et à la version de règle d'origine.

La calibration doit respecter la chronologie, avec une période de validation
distincte de celle servant au choix des seuils. Un test déterministe assure
l'exécution d'une règle ; il ne prouve pas sa valeur prédictive.

## 8. Coût de ce cadrage et de la suite

Ce cadrage utilise les fichiers existants : **zéro appel API-Hockey**, aucun
déploiement, aucune migration. Calculer plusieurs lectures sur un même historique
n'exige pas un appel fournisseur par lecture ou par utilisateur.

Les coûts supplémentaires viennent de la complétude des historiques, des
événements manquants et de nouvelles sources statistiques éventuelles. Les
résultats, fenêtres et événements déjà collectés doivent être mutualisés et mis
en cache. PP/PK ou gardiens ne peuvent pas être chiffrés sérieusement avant
confirmation d'une source couvrant ces champs.

Le premier lot peut rester dans l'infrastructure Supabase prévue ; son activation
distante et le stockage des analyses hockey constituent encore un chantier
distinct. La démo actuelle utilise une copie publique du compact hockey.
