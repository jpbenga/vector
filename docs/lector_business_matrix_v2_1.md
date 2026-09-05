# Lector - Specification metier de la matrice d'analyse V2.1.1

Date de specification : 2026-09-02  
Source de depart : `docs/audits/lector_readings_theses_relation_matrix_audit.md`  
Statut : specification metier cible V2.1.1, sans implementation.  
Perimetre : football analysis, Structural Championship Intelligence, Dynamic Championship Tier System, eligibility gates, evidence families, relations Reading -> Thesis, match intelligence reutilisable, frontiere user matching.

## 1. Objectif

Cette specification transforme l'audit des readings, theses et relations Lector en un modele metier V2.1.1 validable ligne par ligne.

Elle doit permettre de valider individuellement :

- chaque lecture football ;
- chaque these/scenario ;
- chaque Eligibility Gate ;
- chaque famille de preuve ;
- chaque support ;
- chaque contradiction ;
- chaque situation non discriminante ;
- chaque relation Reading -> Thesis.

Elle ne prescrit aucun changement de code immediat. Elle definit le modele cible que l'implementation devra respecter ensuite.

## 2. Principe architectural valide

Regle fondamentale :

> Le moteur analyse le football une fois. Le profil utilisateur intervient ensuite sur le resultat de cette analyse.

Pipeline cible :

```text
MATCH
    -> STRUCTURAL CHAMPIONSHIP INTELLIGENCE
    -> DYNAMIC CHAMPIONSHIP TIER SYSTEM
    -> FULL MATCH ANALYSIS
    -> ALL AVAILABLE READINGS
    -> ALL KNOWN THESES EVALUATED
    -> ELIGIBILITY GATES
    -> EVIDENCE RELATIONSHIP MATRIX
    -> MATCH INTELLIGENCE
    -> PERSISTED / REUSABLE ANALYSIS
    -> USER MATCHING
    -> PROFILE-BASED FILTERING / PRIORITIZATION / PRESENTATION
```

Consequences metier :

- Une competition desactivee dans un profil ne bloque jamais l'analyse football globale.
- Un profil incomplet ne bloque jamais l'analyse football globale.
- Une these non preferee par un utilisateur reste analysee si elle peut renforcer, nuancer ou contredire une autre these.
- Les marches actives par l'utilisateur ne determinent pas l'existence d'une these football ; ils determinent seulement la recommandation, la presentation et la conversion en pick.
- Le moteur doit pouvoir produire une intelligence de match exhaustive, persistable et reutilisable pour plusieurs utilisateurs.

## V2.1.1 - Revision summary

Cette revision integre le Dynamic Championship Tier System comme fonctionnalite metier autonome de la Structural Championship Intelligence.

Decisions integrees :

- introduction d'un Dynamic Championship Tier System profile-independent ;
- definition de 5 Tiers metier : Podium, Groupe superieur, Milieu de tableau, Groupe inferieur, Relegation ;
- frontieres dynamiques fondees sur la distribution interne des points du championnat, sans seuil universel arbitraire ;
- distinction stricte entre classement brut, points bruts, Tier, Tier Gap et separation structurelle ;
- ajout du concept `POINT_GAP_BREAK`, relatif au championnat lui-meme ;
- temporal safety des Tiers via `analysisAsOf` ;
- ajout d'un statut de maturite du Tier System pour debut de saison ou standings insuffisants ;
- integration de la Structural Championship Intelligence dans `EF_HIERARCHY` et dans `MatchAnalysisBundle` ;
- creation du Gate `EG_EXPECTED_DOMINATION_TIER_GAP` ;
- distinction normative entre `GATE_FAILURE`, `RESISTANCE`, `CONTRADICTION` et `STRONG_CONTRADICTION` ;
- correction de `insufficient_data` : absence d'information n'est pas contradiction footballistique ;
- separation de `market_confirmation` et des preuves footballistiques ;
- correction du cas KR Reykjavik vs Vikingur : same Tier implique `expected_domination = NOT_ELIGIBLE`, pas `ELIGIBLE_WITH_WARNINGS`.
- verrouillage de la distinction forme absolue / forme comparative / trajectoire ;
- correction de `positive_streak -> expected_domination` : additional support only, never comparative core evidence ;
- ajout du principe `INDEPENDENT_EVIDENCE` ;
- verrouillage de `avoid_match` : prudence globale significative, pas agregateur automatique d'un seul signal neutre.

## Dynamic Championship Tier System

Le Dynamic Championship Tier System appartient a la couche `Structural Championship Intelligence`. Il n'est pas une condition locale de `expected_domination`, pas une simple reading supplementaire, pas un decoupage fixe du classement et pas une regle `rankGap >= X` ou `pointsGap >= X`.

Pipeline conceptuel :

```text
CHAMPIONSHIP STANDINGS
    -> CHAMPIONSHIP POINT DISTRIBUTION ANALYSIS
    -> DYNAMIC CHAMPIONSHIP TIER SYSTEM
    -> TEAM TIER ASSIGNMENTS
    -> TIER RELATION BETWEEN TWO TEAMS
    -> HIERARCHY READINGS / THESIS GATES / RELATIONS
```

Les 5 Tiers metier sont :

| Tier | Technical concept | French label | Business meaning |
|---|---|---|---|
| `TIER_1` | `PODIUM` | Podium | Zone superieure de reference du championnat. |
| `TIER_2` | `UPPER_CHAMPIONSHIP` | Groupe superieur | Groupe proche du haut mais separe du podium par la structure reelle des points. |
| `TIER_3` | `MIDDLE_CHAMPIONSHIP` | Milieu de tableau | Zone centrale sans ancrage podium/relegation direct. |
| `TIER_4` | `LOWER_CHAMPIONSHIP` | Groupe inferieur | Groupe bas mais pas encore zone de relegation. |
| `TIER_5` | `RELEGATION` | Relegation | Zone inferieure structurelle, selon la competition. |

Les Tiers intermediaires ne doivent pas etre trois blocs de taille identique. Ils doivent etre influences par les ruptures naturelles de points du championnat.

| Concept | Definition | Inputs | Output | Temporal rule | Used by | Status |
|---|---|---|---|---|---|---|
| Championship point distribution | Analyse de la distribution des points entre toutes les equipes d'un championnat a un instant donne. | standings complets, rank, points, played, competitionId, season | Distribution exploitable, gaps voisins, metadata | Doit utiliser les standings disponibles a `analysisAsOf` uniquement. | Tier boundaries, point gap break, maturity | `REQUIRES_PRODUCT_DECISION` for algorithm |
| Podium anchor | Zone superieure footballistiquement speciale. | competition structure, standings, podium positions | Anchor superieur du Tier System | Pre-match only | `TIER_1` assignment | `REQUIRES_DATA_SOURCE` for non-standard competitions |
| Relegation anchor | Zone inferieure footballistiquement speciale. | competition structure, standings descriptions, relegation positions | Anchor inferieur du Tier System | Pre-match only | `TIER_5` assignment | `REQUIRES_DATA_SOURCE` for competition-specific rules |
| Dynamic intermediate boundaries | Frontieres entre upper, middle et lower derivees de la structure reelle des points. | point distribution, anchors, point gap breaks | Boundaries for Tiers 2/3/4 | Recomputed per `analysisAsOf` | team tier assignment | `REQUIRES_PRODUCT_DECISION: Dynamic Tier boundary algorithm` |
| Team Tier Assignment | Attribution d'un Tier a chaque equipe. | standings row + tier boundaries | `TeamTierAssignment(teamId, rank, points, tier, tierLabel, boundary distances)` | No data after match kickoff | hierarchy gates, UI explanation | `REQUIRES_PRODUCT_DECISION` for final field shape |
| Tier Gap | Difference structurelle entre les Tiers de deux equipes. | team A Tier, team B Tier | integer conceptual gap and direction | Same snapshot for both teams | thesis eligibility | `DEFINED`; policy by thesis partly `REQUIRES_PRODUCT_DECISION` |
| Tier maturity | Etat de fiabilite du systeme selon l'avancement du championnat. | played matches, standings completeness, competition schedule | mature / immature / unavailable | As of analyzed match | gate evaluation | `REQUIRES_PRODUCT_DECISION` for minimum maturity |
| Point gap break | Rupture relative de points entre deux zones voisines. | adjacent point gaps, full distribution | structural break marker | Same championship reference | tier boundaries | `REQUIRES_PRODUCT_DECISION` for detection formula |
| Structural separation | Conclusion qu'une equipe appartient a un niveau structurel different d'une autre. | Tier gap, point gap break, anchors | structural relation between teams | Same Tier snapshot | `expected_domination`, hierarchy wording | `DEFINED`; thresholds beyond same Tier require decision |
| Tier snapshot | Snapshot reutilisable de la structure d'un championnat. | competition, season, standings, analysisAsOf | `ChampionshipTierSnapshot` | Fresh for analysisAsOf | multiple match bundles | `CONCEPTUAL_TARGET` |

Sortie conceptuelle :

```text
ChampionshipTierSnapshot
  competitionId
  season
  analysisAsOf
  teamCount
  tierBoundaries[]
  teamAssignments[]
  pointDistributionMetadata
  maturityStatus
```

```text
TeamTierAssignment
  teamId
  rank
  points
  tier
  tierLabel
  distanceToUpperBoundary
  distanceToLowerBoundary
```

Ces champs documentent le besoin metier. Ils ne fixent pas encore l'architecture technique definitive.

## Hierarchy semantics

| Concept | What it proves | What it does NOT prove | Independent evidence? |
|---|---|---|---|
| `rank` | Position factuelle d'une equipe dans un classement donne. | Ne prouve pas un niveau structurel different. | Non, composant brut. |
| `rankGap` | Ecart de places entre deux equipes. | Ne prouve pas une rupture structurelle. | Non, derive du classement brut. |
| `points` | Capital points factuel. | Ne suffit pas a definir le Tier hors distribution globale. | Non, composant brut. |
| `pointsGap` | Ecart de points factuel entre deux equipes. | N'est pas synonyme de `tierGap`. | Non, derive du classement brut. |
| `ranking_superiority` | Avantage factuel au classement disponible. | Ne prouve pas a lui seul `expected_domination`. | Correlated with hierarchy evidence. |
| `structural_level_gap` | Doit prouver une separation structurelle seulement si coherent avec le Tier System. | Ne doit plus signifier simple `rankGap` ou `pointsGap`. | Correlated; not independent from Tier evidence. |
| `teamTier` | Niveau structurel dynamique de l'equipe dans son championnat. | Ne prouve pas une these complete sans autres familles. | Structural artifact, not ordinary reading. |
| `tierGap` | Difference structurelle entre deux equipes. | Ne remplace pas `pointsGap`; ne suffit pas forcement a chaque these. | Structural gate input. |

Regle `CORRELATED_EVIDENCE` :

```text
rankGap + pointsGap + tierGap
```

peuvent tous etre affiches pour expliquer la hierarchie, mais ils ne constituent pas automatiquement trois preuves independantes. Plusieurs representations de la meme realite structurelle ne doivent pas etre double-comptees dans une these.

## 3. Glossaire normatif

| Terme | Definition V2.1.1 |
|---|---|
| `Reading` | Signal atomique interpretable, produit a partir des donnees pre-match ou derive d'autres readings. |
| `Evidence Family` | Famille metier qui regroupe des readings partageant une logique commune : hierarchie, forme, attaque, defense, rythme, xG, etc. |
| `Raw fact` | Donnee brute ou derivee minimale : rank, points, rankGap, pointsGap, played, goals, xG, home record, away record. Un raw fact n'est pas automatiquement une preuve independante. |
| `Structural artifact` | Objet de Structural Championship Intelligence : `teamTier`, `tierGap`, `pointGapBreak`, `ChampionshipTierSnapshot`, structural separation. Il ne doit pas etre transforme artificiellement en reading ordinaire. |
| `Eligibility Gate` | Condition d'eligibilite a verifier avant de considerer une reading, une relation ou une these comme exploitable. |
| `Gate Failure` | Condition necessaire non satisfaite : la these n'existe pas dans ce contexte. Ce n'est ni une contradiction ni une resistance. |
| `Thesis` | Hypothese football ou scenario de match evalue pour le match, independamment du profil utilisateur. |
| `Market Intent` | Marche theorique compatible avec une these. Il ne depend pas encore des preferences utilisateur. |
| `Relation` | Lien explicite entre une reading et une these : support, contradiction, resistance, non-discriminance ou absence de pertinence. |
| `Contradiction` | Signal qui diminue la confiance d'une these sans forcement l'annuler. |
| `Strong contradiction` | Signal qui doit fortement degrader ou rendre non eligible une these sauf decision produit contraire. |
| `Resistance` | Force adverse qui ne nie pas la these, mais empeche de la raconter comme univoque. |
| `Non-discriminating` | Signal vrai mais non utile pour departager deux equipes ou soutenir une these directionnelle. |
| `Match Intelligence` | Resultat complet, profile-independent, contenant readings, theses, gates, relations, warnings et intents de marche. |
| `User Matching` | Couche personnalisee : filtrage, ranking, priorisation, copie, picks, tickets et presentation selon profil. |
| `Structural Championship Intelligence` | Analyse profile-independent de la structure d'un championnat, incluant point distribution, Tiers, Tier assignments, Tier Gap et maturity. |
| `Evidence unavailable` | Donnee absente ou insuffisante. Elle peut rendre une reading ou une these non evaluable, mais ne constitue pas une information contraire. |
| `Independent evidence` | Preuve issue d'une famille ou d'une provenance informationnelle distincte. Plusieurs IDs correles ne creent pas plusieurs preuves independantes. |

## 4. Contrat de sortie cible

Le resultat persistant attendu est un bundle unique par match.

```text
MatchAnalysisBundle
  fixtureId
  kickoff
  analyzedAt
  analysisAsOf
  championshipTierSnapshotRef
  structuralChampionshipIntelligence
  dataQuality
  readings[]
  candidateTheses[]
  eligibilityGateResults[]
  readingThesisRelations[]
  derivedThesisRelations[]
  marketIntents[]
  nonDiscriminatingSituations[]
  temporalWarnings[]
```

Chaque objet doit etre tracable :

```text
Reading
  id
  familyId
  subject: HOME | AWAY | MATCH
  strength: WEAK | MODERATE | STRONG
  value
  sourceFields[]
  asOf
  eligibilityGateResults[]
```

```text
Thesis
  id
  subject: HOME | AWAY | MATCH
  status: ELIGIBLE | ELIGIBLE_WITH_WARNINGS | NOT_ELIGIBLE | NOT_EVALUABLE | NOT_ELIGIBLE_DUE_TO_DATA
  failedGates[]
  coreSupports[]
  additionalSupports[]
  contradictions[]
  strongContradictions[]
  resistances[]
  nonDiscriminatingSignals[]
  eligibilityGateResults[]
  marketIntents[]
```

```text
ReadingThesisRelation
  sourceReadingId
  targetThesisId
  relation
  direction
  familyId
  status
  confidence
  reason
```

## 5. Relation taxonomy

| Relation | Meaning | Effet metier cible |
|---|---|---|
| `GATE_FAILURE` | Une condition necessaire a la these echoue. | La these est `NOT_ELIGIBLE` ou `NOT_EVALUABLE`; ce n'est pas une contradiction. |
| `CORE_SUPPORT` | Preuve centrale necessaire ou quasi necessaire a la these. | Peut rendre la these eligible si les gates sont valides. |
| `ADDITIONAL_SUPPORT` | Preuve complementaire, utile mais non suffisante seule. | Augmente confiance, richesse narrative ou market intent. |
| `RESISTANCE` | Force opposee contextuelle. | Maintient la these possible mais impose une nuance visible. |
| `CONTRADICTION` | Signal contraire significatif. | Degrade confiance et doit etre expose. |
| `STRONG_CONTRADICTION` | Signal contraire majeur. | Peut bloquer l'eligibilite selon la these. |
| `NON_DISCRIMINATING` | Signal vrai mais partage ou non directionnel. | Ne doit pas compter comme support directionnel. |
| `EVIDENCE_UNAVAILABLE` | Donnee manquante ou immature. | Rend une reading/these non evaluable sans creer de contradiction footballistique. |
| `MARKET_CONTEXT` | Information de marche descriptive. | Peut orienter un market intent mais ne renforce pas la verite footballistique. |
| `COEXISTS` | Signal compatible mais sans contribution directe. | Peut rester dans l'analyse sans score. |
| `NOT_RELEVANT` | Aucun lien metier direct. | Ignore dans la matrice. |

Regle par defaut : toute relation absente de la matrice V2.1.1 est `NOT_RELEVANT` jusqu'a validation explicite.

Distinction obligatoire V2.1.1 :

| Concept | Meaning | Example |
|---|---|---|
| Gate Failure | Les conditions necessaires a l'existence de la these ne sont pas reunies. | `tierGap = 0` -> `expected_domination = NOT_ELIGIBLE`. |
| Evidence unavailable | L'information n'est pas disponible ou pas mature. | Tier System immature -> structural gate `NOT_EVALUABLE`. |
| Resistance | La these existe, mais une force adverse doit etre visible. | Favori structurel away vs opponent strong home. |
| Contradiction | Une evidence footballistique va directement contre la these. | Favorite fragile defense vs `controlled_favorite`. |
| Strong contradiction | Contradiction majeure apres satisfaction des gates fondamentaux. | Open profile + opponent high creation vs `controlled_favorite`. |

Regle absolue : `STRONG_CONTRADICTION` ne doit jamais servir a compenser l'absence d'un Eligibility Gate.

Regle `INDEPENDENT_EVIDENCE` :

> Le moteur doit raisonner en familles de preuves independantes et en provenance de l'information, pas uniquement en nombre de reading IDs validees.

Les readings correlees restent disponibles pour l'explication. Elles ne doivent pas multiplier artificiellement le poids d'une meme realite footballistique.

## 6. Evidence Families V2.1.1

| Family ID | Nom | Role | Readings principales | Gates critiques |
|---|---|---|---|---|
| `EF_HIERARCHY` | Hierarchie classement + structure championnat | Distinguer avantage factuel au classement et separation structurelle dynamique. | raw rank/points evidence, `balanced_hierarchy`, `ranking_superiority`, `structural_level_gap`, Tier artifacts | standings comparables, Tier snapshot maturity, correlated evidence. |
| `EF_FORM_ABSOLUTE` | Forme recente absolue | Detecter bonne/mauvaise serie brute. | `positive_streak`, `negative_streak` | fenetre minimale, convention temporelle. |
| `EF_FORM_TRAJECTORY` | Trajectoire de forme | Detecter amelioration/declin. | `improving_form`, `declining_form` | convention ordre de la string. |
| `EF_FORM_COMPARATIVE` | Forme comparative | Decider si la forme est discriminante. | `form_advantage`, `comparable_positive_form` | deux formes disponibles. |
| `EF_CONTEXT_HOME_AWAY` | Contexte domicile/exterieur | Mesurer force ou faiblesse selon lieu. | `strong_home_team`, `strong_away_team`, `weak_home_team`, `weak_away_team`, `home_away_mismatch`, `opposing_context_strengths` | splits home/away disponibles. |
| `EF_ATTACK_OUTPUT` | Production offensive | Mesurer capacite de marquer. | `prolific_attack`, `scoring_difficulty`, `attack_in_form` | matches joues, split total ou contextuel. |
| `EF_DEFENSE_OUTPUT` | Solidite defensive | Mesurer capacite a ne pas conceder. | `solid_defense`, `fragile_defense`, `frequent_clean_sheet`, `declining_defense` | matches joues, clean sheets. |
| `EF_GOAL_RHYTHM` | Rythme buts | Evaluer profil ouvert/ferme du match. | `open_match_profile`, `closed_match_profile`, `frequent_over_25`, `frequent_under_25`, `frequent_btts` | eviter double counting climate. |
| `EF_EXPECTED_GOALS` | Expected goals | Detecter creation, concession et ecarts xG/resultats. | `high_xg_creation`, `low_xg_creation`, `high_xg_conceded`, `offensive_underperformance`, `offensive_overperformance`, `defensive_underperformance`, `defensive_overperformance` | pre-kickoff only, sample xG. |
| `EF_DATA_QUALITY` | Qualite donnees | Signaler insuffisance ou donnees non exploitables. | `insufficient_data` | source, asOf, couverture. |
| `EF_MARKET_CONTEXT` | Contexte marche | Identifier favori, outsider et odds disponibles. | `market_favorite`, `market_outsider`, `market_confirmation` | odds pre-match, pas de profil utilisateur. |

Notes de validation :

- `EF_FORM_COMPARATIVE`, `opposing_context_strengths`, `market_favorite`, `market_outsider` et `market_confirmation` sont des concepts cibles. Ils peuvent etre implementes comme readings explicites ou relations derivees, mais ils doivent exister dans le bundle sous une forme validable.
- Les readings `frequent_over_25`, `frequent_under_25` et `frequent_btts` ne doivent pas pretendre mesurer une frequence historique si elles restent derivees d'un simple climate agregat.
- `EF_HIERARCHY` est revisee en V2.1.1 : elle combine raw hierarchy evidence, Structural Championship Intelligence et readings derivees, mais ne doit pas double-compter ces representations correlees.
- Le Dynamic Championship Tier System alimente `EF_HIERARCHY` via des artifacts/gates structurels ; il ne doit pas etre reduit a une simple reading.
- `EF_FORM_ABSOLUTE`, `EF_FORM_COMPARATIVE` et `EF_FORM_TRAJECTORY` restent distinctes : une bonne serie absolue n'est pas automatiquement un avantage relatif, et une trajectoire temporelle n'est pas equivalente a un total sur cinq matchs.

## 7. Eligibility Gates V2.1.1

| Gate ID | Scope | Rule | Failure result |
|---|---|---|---|
| `EG_PROFILE_INDEPENDENCE` | Bundle | Aucune dependance a un profil utilisateur pendant l'analyse football. | Analyse invalide. |
| `EG_FIXTURE_IDENTIFIED` | Bundle | Le match doit avoir un `fixtureId` stable et deux equipes resolues. | Analyse invalide. |
| `EG_PREMATCH_CUTOFF` | Bundle / reading | Les donnees sportives doivent etre connues avant le kickoff ou marquees comme non pre-match. | Reading exclue ou warning. |
| `EG_AS_OF_TRACEABLE` | Bundle / reading | Chaque evidence doit avoir un `asOf` ou heriter d'un `analysisAsOf` explicite. | Warning si non critique, exclusion si temporellement sensible. |
| `EG_SOURCE_TRACEABLE` | Reading | Chaque reading doit pointer vers les champs sources utilises. | Reading non validable. |
| `EG_STANDINGS_COMPARABLE` | Hierarchy | Les deux equipes doivent appartenir a une table comparable avec rang, points et played exploitables. | Readings hierarchy non eligibles. |
| `EG_MIN_PLAYED_HIERARCHY` | Hierarchy | Les classements ne doivent pas etre issus d'un echantillon trop faible. | Strength plafonnee ou exclusion. |
| `EG_CHAMPIONSHIP_STRUCTURE_METADATA` | Structural Championship Intelligence | Le systeme doit connaitre le nombre d'equipes, les ancres podium/relegation et les particularites utiles de la competition. | Tier snapshot non evaluable si metadata manquante. |
| `EG_TIER_SYSTEM_MATURITY` | Structural Championship Intelligence | Le championnat doit avoir assez d'historique pour produire des Tiers fiables. Le seuil reste `REQUIRES_PRODUCT_DECISION`. | `TIER_SYSTEM_NOT_MATURE`; Tier assignments non evaluables. |
| `EG_TIER_ASSIGNMENT_AVAILABLE` | Structural Championship Intelligence | Les deux equipes du match doivent avoir un Tier calcule depuis le meme `ChampionshipTierSnapshot`. | Relations structurelles non evaluables. |
| `EG_EXPECTED_DOMINATION_TIER_GAP` | Thesis | `expected_domination(subject)` exige `subjectTier != opponentTier`. Si `tierGap = 0`, la these echoue. `tierGap = 1` suffisant ou non reste `REQUIRES_PRODUCT_DECISION`. | `expected_domination = NOT_ELIGIBLE`; failed gate, pas contradiction. |
| `EG_CORRELATED_HIERARCHY_EVIDENCE` | Relation / thesis | Rank, points, rankGap, pointsGap et tierGap peuvent expliquer la meme realite structurelle et ne doivent pas etre comptes comme preuves independantes. | Supports fusionnes/degrades en explanatory evidence. |
| `EG_FORM_WINDOW_MIN` | Form | La fenetre de forme doit contenir au moins 5 resultats exploitables. | Reading form exclue. |
| `EG_FORM_DIRECTION_KNOWN` | Trajectory | La convention d'ordre de la string de forme doit etre officielle. | Readings trajectory exclues. |
| `EG_HOME_AWAY_SPLIT_AVAILABLE` | Context | Les splits domicile/exterieur doivent etre presents ou remplaces explicitement par total avec warning. | Strength plafonnee ou exclusion. |
| `EG_ATTACK_SAMPLE_MIN` | Attack | La production offensive doit avoir un volume minimum de matches. | Reading attack exclue. |
| `EG_DEFENSE_SAMPLE_MIN` | Defense | La production defensive doit avoir un volume minimum de matches. | Reading defense exclue. |
| `EG_RHYTHM_SAMPLE_MIN` | Rhythm | Le climate buts doit reposer sur assez de donnees des deux equipes. | Reading rhythm exclue. |
| `EG_NO_DERIVED_DOUBLE_COUNT` | Relation / thesis | Deux readings derivees du meme calcul ne comptent pas comme deux familles independantes. | Relation degradee en additional ou display. |
| `EG_XG_SAMPLE_MIN` | xG | Les rolling xG doivent avoir un sample suffisant. | Reading xG exclue. |
| `EG_XG_PREMATCH_ONLY` | xG | Un xG date apres kickoff est rejete et cree un warning. | xG reading exclue + `EVIDENCE_UNAVAILABLE`; pas contradiction. |
| `EG_MARKET_PREMATCH` | Market | Les odds doivent etre pre-match et rattachees au bon match. | Market intent indisponible. |
| `EG_MARKET_NOT_PROFILE_FILTERED` | Market | Le marche peut conditionner une these market-aware, mais jamais selon les preferences utilisateur. | Analyse invalide si filtre profil. |
| `EG_DIRECTION_RESOLVED` | Relation | Le lien doit distinguer subject, opponent, home, away ou match. | Relation non validable. |
| `EG_CORE_SUPPORT_PRESENT` | Thesis | Les core supports definis pour la these doivent etre presents. | These non eligible. |
| `EG_MIN_EVIDENCE_FAMILIES` | Thesis | Une these ne doit pas etre portee par plusieurs readings issues d'une seule realite informationnelle sauf exception explicite. Le gate raisonne sur familles/provenances independantes, pas sur le nombre brut d'IDs. | These non eligible ou warning. |
| `EG_NON_DISCRIMINATING_CHECK` | Relation / thesis | Les signaux symetriques ou equivalently forts ne comptent pas comme support directionnel. | Relation `NON_DISCRIMINATING`. |
| `EG_OPPONENT_RESISTANCE_CAPTURED` | Thesis | Une force adverse pertinente doit etre rattachee comme resistance/contradiction. | These eligible with warnings. |
| `EG_STRONG_CONTRADICTION_POLICY` | Thesis | Les strong contradictions doivent avoir une politique : block, downgrade ou expose. | These non validable sans decision. |
| `EG_PERSISTABLE_TRACE` | Bundle | Le bundle doit etre serialisable sans profil et reutilisable. | Analyse non persistable. |
| `EG_UI_ENGINE_ALIGNMENT` | Presentation | L'UI doit afficher les readings et relations du bundle, pas des cartes reconstruites. | Presentation non conforme. |

## 8. Reading Catalog V2.1.1

Statuts :

- `CARRY_FORWARD` : reading existante conservee comme signal moteur.
- `PRODUCE_SYMMETRIC` : reading cible a produire pour combler une asymetrie.
- `DERIVE_OR_PRODUCE` : concept obligatoire dans l'analyse, forme technique a decider.
- `DISPLAY_ONLY_REVIEW` : wording/mapping UI a aligner ou supprimer.
- `DEPRECATE_OR_DEFINE` : ID reference mais sans role metier valide aujourd'hui.

| Reading ID | Family | Subject | Gate principal | Role V2.1.1 | Status |
|---|---|---|---|---|---|
| `balanced_hierarchy` | `EF_HIERARCHY` | match | standings comparables + Tier context | Lecture explicative de proximite factuelle ; ne remplace pas un Tier Gate. | `CARRY_FORWARD_REPOSITIONED` |
| `ranking_superiority` | `EF_HIERARCHY` | team | standings comparables + Tier context | Avantage factuel au classement ; additional/explanatory only for domination after Tier Gate. | `CARRY_FORWARD_REPOSITIONED` |
| `structural_level_gap` | `EF_HIERARCHY` | team | Tier snapshot available | Doit etre coherent avec `tierGap` / structural separation ; definition finale `REQUIRES_PRODUCT_DECISION`. | `REDEFINE_FROM_TIER_SYSTEM` |
| `positive_streak` | `EF_FORM_ABSOLUTE` | team | form window | Bonne serie absolue ; additional context for directional theses, never comparative core evidence by itself. | `CARRY_FORWARD` |
| `negative_streak` | `EF_FORM_ABSOLUTE` | team | form window | Core difficulty, support outsider adverse. | `CARRY_FORWARD` |
| `improving_form` | `EF_FORM_TRAJECTORY` | team | direction known | Support potentiel, uniquement apres validation de convention. | `CARRY_FORWARD_WITH_GATE` |
| `declining_form` | `EF_FORM_TRAJECTORY` | team | direction known | Support difficulty ou outsider adverse. | `CARRY_FORWARD_WITH_GATE` |
| `form_advantage` | `EF_FORM_COMPARATIVE` | team | both forms known | Signale une forme reellement superieure. | `DERIVE_OR_PRODUCE` |
| `comparable_positive_form` | `EF_FORM_COMPARATIVE` | match | both forms known | Marque deux bonnes formes comme non discriminantes. | `DERIVE_OR_PRODUCE` |
| `strong_home_team` | `EF_CONTEXT_HOME_AWAY` | home | split available | Support home ; resistance or contradiction to away domination according to product policy. | `CARRY_FORWARD` |
| `strong_away_team` | `EF_CONTEXT_HOME_AWAY` | away | split available | Support away ; resistance or contradiction to home domination according to product policy. | `PRODUCE_SYMMETRIC` |
| `weak_home_team` | `EF_CONTEXT_HOME_AWAY` | home | split available | Support difficulty home, support away via opponent weakness. | `PRODUCE_SYMMETRIC` |
| `weak_away_team` | `EF_CONTEXT_HOME_AWAY` | away | split available | Support difficulty away, support home via opponent weakness. | `CARRY_FORWARD` |
| `home_away_mismatch` | `EF_CONTEXT_HOME_AWAY` | match | both contextual readings | Context mismatch display or derived relation. | `CARRY_FORWARD_REVIEW` |
| `opposing_context_strengths` | `EF_CONTEXT_HOME_AWAY` | match | both contextual strengths | Non-discriminating/resistance when both teams strong in context. | `DERIVE_OR_PRODUCE` |
| `prolific_attack` | `EF_ATTACK_OUTPUT` | team | attack sample | Support open, BTTS, domination additional, one-sided. | `CARRY_FORWARD` |
| `scoring_difficulty` | `EF_ATTACK_OUTPUT` | team | attack sample | Core closed/difficulty, contradiction offensive theses. | `CARRY_FORWARD` |
| `attack_in_form` | `EF_ATTACK_OUTPUT` | team | TBD | Keep only if product defines a real producer. | `DISPLAY_ONLY_REVIEW` |
| `solid_defense` | `EF_DEFENSE_OUTPUT` | team | defense sample | Support closed, control, protection; contradiction open. | `CARRY_FORWARD` |
| `fragile_defense` | `EF_DEFENSE_OUTPUT` | team | defense sample | Support open/difficulty/opponent scoring; contradiction control. | `CARRY_FORWARD` |
| `declining_defense` | `EF_DEFENSE_OUTPUT` | team | TBD | Keep only if product defines a real producer. | `DISPLAY_ONLY_REVIEW` |
| `frequent_clean_sheet` | `EF_DEFENSE_OUTPUT` | team | defense sample | Additional closed/control support. | `CARRY_FORWARD` |
| `open_match_profile` | `EF_GOAL_RHYTHM` | match | rhythm sample | Core open thesis, contradiction closed/control. | `CARRY_FORWARD` |
| `frequent_over_25` | `EF_GOAL_RHYTHM` | match | rhythm sample + real frequency or derived flag | Additional only if same climate; core only if real frequency. | `CARRY_FORWARD_REVIEW` |
| `closed_match_profile` | `EF_GOAL_RHYTHM` | match | rhythm sample | Core closed thesis, contradiction open/BTTS. | `CARRY_FORWARD` |
| `frequent_under_25` | `EF_GOAL_RHYTHM` | match | rhythm sample + real frequency or derived flag | Additional only if same climate; core only if real frequency. | `CARRY_FORWARD_REVIEW` |
| `frequent_btts` | `EF_GOAL_RHYTHM` | match | real BTTS frequency | Support BTTS only if real producer exists. | `DISPLAY_ONLY_REVIEW` |
| `high_xg_creation` | `EF_EXPECTED_GOALS` | team | xG pre-match + sample | Support attack, open, BTTS, hidden potential. | `CARRY_FORWARD` |
| `low_xg_creation` | `EF_EXPECTED_GOALS` | team | xG pre-match + sample | Strong contradiction to open/BTTS/team-better. | `CARRY_FORWARD_REMAP` |
| `high_xg_conceded` | `EF_EXPECTED_GOALS` | team | xG pre-match + sample | Support opponent scoring, open, BTTS. | `CARRY_FORWARD` |
| `offensive_underperformance` | `EF_EXPECTED_GOALS` | team | xG pre-match + sample | Core hidden upside with negative results. | `CARRY_FORWARD` |
| `offensive_overperformance` | `EF_EXPECTED_GOALS` | team | xG pre-match + sample | Core worse-than-results. | `CARRY_FORWARD` |
| `defensive_underperformance` | `EF_EXPECTED_GOALS` | team | xG pre-match + sample | Support defensive fragility or difficulty. | `CARRY_FORWARD_REMAP` |
| `defensive_overperformance` | `EF_EXPECTED_GOALS` | team | xG pre-match + sample | Core worse-than-results. | `CARRY_FORWARD` |
| `misleading_result` | `EF_EXPECTED_GOALS` | team | derived xG/result | Support worse-than-results; contradiction to domination/protection. | `CARRY_FORWARD_REMAP` |
| `conflicting_signals` | `EF_DATA_QUALITY` | team | derived contradiction | Core avoid, contradiction team theses. | `CARRY_FORWARD` |
| `insufficient_data` | `EF_DATA_QUALITY` | match/team | source coverage | Evidence unavailable / gate insufficiency ; peut soutenir prudence, jamais contradiction footballistique. | `CARRY_FORWARD_REVIEW` |
| `false_favorite` | `EF_MARKET_CONTEXT` | team | market + sport mismatch | Define as real reading or remove from metadata. | `DEPRECATE_OR_DEFINE` |
| `market_favorite` | `EF_MARKET_CONTEXT` | team | odds pre-match | Required gate for market-aware favorite theses. | `DERIVE_OR_PRODUCE` |
| `market_outsider` | `EF_MARKET_CONTEXT` | team | odds pre-match | Required gate for outsider thesis. | `DERIVE_OR_PRODUCE` |
| `market_confirmation` | `EF_MARKET_CONTEXT` | team/match | odds pre-match | Market context only ; never football evidence. | `DERIVE_OR_PRODUCE` |

## 9. Canonical theses V2.1.1

V2.1.1 conserve les 12 theses V2 comme theses canoniques et reclasse les theses legacy comme aliases, familles profil ou scenarios de fallback non canoniques.

| Thesis ID | Canonical? | Subject | Role V2.1.1 |
|---|---:|---|---|
| `expected_domination` | Oui | team | Suprematie sportive directionnelle. |
| `favorite_with_protection` | Oui | team | Favori marche/sportif a couvrir a cause d'un risque visible. |
| `convergent_open_match` | Oui | match | Scenario buts ouvert. |
| `convergent_closed_match` | Oui | match | Scenario buts ferme. |
| `credible_outsider` | Oui | team | Outsider dont les signaux reduisent l'ecart avec le favori. |
| `team_in_serious_difficulty` | Oui | team | Equipe avec difficulte multi-familles. |
| `controlled_favorite` | Oui | team | Favori avec faible menace adverse et controle defensif. |
| `both_sides_can_score` | Oui | match | Les deux equipes ont une capacite raisonnable de marquer. |
| `one_sided_scoring` | Oui | team | Pression offensive majoritairement dans un sens. |
| `team_better_than_results` | Oui | team | Resultats recents moins bons que la production sous-jacente. |
| `team_worse_than_results` | Oui | team | Resultats recents meilleurs que la production sous-jacente. |
| `avoid_match` | Oui | match | Prudence globale ou ambiguite forte. |
| `solid_favorite` | Non canonique V2.1.1 | team | Profil/famille de matching regroupant domination, controle, protection. |
| `cautious_double_chance` | Non canonique V2.1.1 | team | Market intent, pas these football autonome. |
| `level_gap` | Non canonique V2.1.1 | team | Alias legacy de hierarchy -> domination. |
| `open_match` | Non canonique V2.1.1 | match | Alias legacy de `convergent_open_match`. |
| `closed_match` | Non canonique V2.1.1 | match | Alias legacy de `convergent_closed_match`. |
| `no_sufficient_thesis` | Non canonique V2.1.1 | match | Etat de non-eligibilite / fallback presentation. |

## 10. Thesis cards V2.1.1

### `expected_domination`

| Element | Specification |
|---|---|
| Subject | Home or away. |
| Eligibility gates | `EG_TIER_SYSTEM_MATURITY`, `EG_TIER_ASSIGNMENT_AVAILABLE`, `EG_EXPECTED_DOMINATION_TIER_GAP`, `EG_CORRELATED_HIERARCHY_EVIDENCE`, `EG_CORE_SUPPORT_PRESENT`, `EG_MIN_EVIDENCE_FAMILIES`, `EG_NON_DISCRIMINATING_CHECK`, `EG_OPPONENT_RESISTANCE_CAPTURED`. |
| Tier gate | `subjectTier != opponentTier` is required. If `tierGap = 0`, status is `NOT_ELIGIBLE` with failed gate `EG_EXPECTED_DOMINATION_TIER_GAP`. This is not a warning, resistance or contradiction. |
| Core support | Structural separation from the Dynamic Tier System, plus independent football evidence from another family. `form_advantage` may be comparative core evidence. `ranking_superiority` may explain the hierarchy but cannot replace the Tier Gate. |
| Additional support | subject `positive_streak` as absolute form context, subject contextual strength, subject `prolific_attack`, opponent contextual weakness, opponent `fragile_defense`. |
| Resistance | opponent contextual strength, opponent positive/comparable form, opponent high xG creation. |
| Strong contradiction | strong opponent context strength after Tier Gate passes, subject `team_worse_than_results`. `balanced_hierarchy` is not a strong contradiction to domination; same Tier is handled by the Tier Gate. |
| Non-discriminating | both teams positive form; both teams strong in venue context; hierarchy gap only by one dimension if wording says structural. |
| Market intents | match result, double chance. |

### `favorite_with_protection`

| Element | Specification |
|---|---|
| Subject | Market favorite. |
| Eligibility gates | `EG_MARKET_PREMATCH`, `EG_MARKET_NOT_PROFILE_FILTERED`, `EG_CORE_SUPPORT_PRESENT`, `EG_STRONG_CONTRADICTION_POLICY`. |
| Core support | `market_favorite`, football credibility of the favorite, and favorite `solid_defense`. `ranking_superiority` can be a factual hierarchy component; it must not be presented as structural superiority unless supported by the Tier System. |
| Additional support | favorite `positive_streak`, favorite `frequent_clean_sheet`, opponent `scoring_difficulty`. |
| Resistance | opponent `high_xg_creation`, opponent `prolific_attack`, opponent contextual strength. |
| Strong contradiction | `false_favorite` if defined, favorite `misleading_result`, opponent strong xG + open match profile. |
| Non-discriminating | favorite and opponent both defensively solid without clear market edge. |
| Tier policy | No automatic `EG_EXPECTED_DOMINATION_TIER_GAP`; a market favorite may be same Tier as opponent. |
| Market intents | double chance, protected result. |

### `convergent_open_match`

| Element | Specification |
|---|---|
| Subject | Match. |
| Eligibility gates | `EG_RHYTHM_SAMPLE_MIN`, `EG_NO_DERIVED_DOUBLE_COUNT`, `EG_MIN_EVIDENCE_FAMILIES`. |
| Core support | `open_match_profile` or bilateral creation from both teams. |
| Additional support | `frequent_over_25` if not duplicate core, one/both `prolific_attack`, `high_xg_creation`, `fragile_defense`, `high_xg_conceded`. |
| Resistance | one solid defense, one scoring difficulty, one low xG creation. |
| Strong contradiction | `closed_match_profile`, both teams `solid_defense`, both teams `scoring_difficulty`, both teams `low_xg_creation`. |
| Non-discriminating | both teams fragile supports open but not winner direction. |
| Market intents | goals total over, both teams score yes. |

### `convergent_closed_match`

| Element | Specification |
|---|---|
| Subject | Match. |
| Eligibility gates | `EG_RHYTHM_SAMPLE_MIN`, `EG_NO_DERIVED_DOUBLE_COUNT`, `EG_MIN_EVIDENCE_FAMILIES`. |
| Core support | `closed_match_profile` or combined defensive solidity/low attack from both sides. |
| Additional support | `frequent_under_25` if not duplicate core, `solid_defense`, `frequent_clean_sheet`, `scoring_difficulty`, `low_xg_creation`. |
| Resistance | one team high xG creation, one prolific attack, one fragile defense. |
| Strong contradiction | `open_match_profile`, both teams high creation/prolific attack, multiple high xG conceded. |
| Non-discriminating | one strong defense and one weak attack supports closed but not side result. |
| Market intents | goals total under. |

### `credible_outsider`

| Element | Specification |
|---|---|
| Subject | Market outsider. |
| Eligibility gates | `EG_MARKET_PREMATCH`, `EG_MARKET_NOT_PROFILE_FILTERED`, `EG_DIRECTION_RESOLVED`, `EG_MIN_EVIDENCE_FAMILIES`. |
| Core support | `market_outsider` plus at least two gap-reducing sport signals: `balanced_hierarchy`, outsider contextual strength, outsider form advantage, outsider high xG creation, favorite weakness. |
| Additional support | favorite `negative_streak`, favorite `declining_form`, favorite `fragile_defense`, outsider `prolific_attack`. |
| Resistance | favorite ranking superiority, favorite solid defense, outsider scoring difficulty. |
| Strong contradiction | favorite structural separation may become contradiction or strong contradiction according to future policy; outsider low xG creation and outsider weak context can strongly weaken the thesis. |
| Non-discriminating | balanced hierarchy is stronger support than generic positive form if both teams are in form. |
| Tier policy | Being in a lower Tier does not automatically make `credible_outsider` impossible; exact policy remains `REQUIRES_PRODUCT_DECISION`. |
| Market intents | double chance outsider, match result outsider when odds policy allows. |

### `team_in_serious_difficulty`

| Element | Specification |
|---|---|
| Subject | Home or away. |
| Eligibility gates | `EG_MIN_EVIDENCE_FAMILIES`, `EG_CORE_SUPPORT_PRESENT`, `EG_OPPONENT_RESISTANCE_CAPTURED`. |
| Core support | At least two families among `negative_streak`, `scoring_difficulty`, `fragile_defense`, contextual weakness. |
| Additional support | opponent ranking superiority, opponent prolific attack, opponent high xG creation, `declining_form`. |
| Resistance | subject high xG creation, subject offensive underperformance, subject solid defense, subject positive/improving form. |
| Strong contradiction | subject `team_better_than_results` if hidden creation is strong and defensive risk is not severe. |
| Non-discriminating | both teams weak offensively supports closed match more than single-team difficulty. |
| Market intents | opponent double chance, opponent result, avoid betting on subject. |

### `controlled_favorite`

| Element | Specification |
|---|---|
| Subject | Market favorite. |
| Eligibility gates | `EG_MARKET_PREMATCH`, `EG_CORE_SUPPORT_PRESENT`, `EG_MIN_EVIDENCE_FAMILIES`. |
| Core support | `market_favorite`, favorite `solid_defense`, opponent low threat (`scoring_difficulty` or `low_xg_creation`). |
| Additional support | favorite `ranking_superiority`, `structural_level_gap`, favorite `frequent_clean_sheet`, `closed_match_profile`. |
| Resistance | opponent high xG creation, opponent prolific attack, opponent contextual strength. |
| Strong contradiction | `open_match_profile`, favorite fragile defense, opponent strong attack plus high xG. |
| Non-discriminating | both teams solid can support closed match without proving favorite control. |
| Tier policy | Tier separation may reinforce as additional structural context but is not an automatic gate. |
| Market intents | match result favorite, double chance favorite, under-compatible protected angle. |

### `both_sides_can_score`

| Element | Specification |
|---|---|
| Subject | Match. |
| Eligibility gates | `EG_CORE_SUPPORT_PRESENT`, `EG_MIN_EVIDENCE_FAMILIES`, `EG_NON_DISCRIMINATING_CHECK`. |
| Core support | Creation/scoring capacity for both teams: each side has `high_xg_creation` or `prolific_attack`. |
| Additional support | `open_match_profile`, `frequent_btts` if real, one/both `fragile_defense`, one/both `high_xg_conceded`. |
| Resistance | one team solid defense, one team scoring difficulty. |
| Strong contradiction | one team `low_xg_creation`, one team severe `scoring_difficulty`, `closed_match_profile`, two solid defenses. |
| Non-discriminating | both attacks strong supports BTTS/open, not a side winner. |
| Market intents | both teams score yes. |

### `one_sided_scoring`

| Element | Specification |
|---|---|
| Subject | Target team. |
| Eligibility gates | `EG_DIRECTION_RESOLVED`, `EG_CORE_SUPPORT_PRESENT`, `EG_MIN_EVIDENCE_FAMILIES`. |
| Core support | target attack capacity plus opponent defensive weakness. |
| Additional support | opponent scoring difficulty, target solid defense, target ranking superiority. |
| Resistance | opponent high xG creation, opponent prolific attack, opponent contextual strength. |
| Strong contradiction | target low xG creation or scoring difficulty; `both_sides_can_score` with strong bilateral creation. |
| Non-discriminating | both teams prolific should route to open/BTTS, not one-sided. |
| Market intents | target team total, target result where hierarchy supports. |

### `team_better_than_results`

| Element | Specification |
|---|---|
| Subject | Home or away. |
| Eligibility gates | `EG_XG_PREMATCH_ONLY`, `EG_CORE_SUPPORT_PRESENT`, `EG_MIN_EVIDENCE_FAMILIES`. |
| Core support | `negative_streak`, `offensive_underperformance`, `high_xg_creation`. |
| Additional support | opponent fragile defense, improving form, contextual strength. |
| Resistance | subject fragile defense, opponent solid defense. |
| Strong contradiction | subject `low_xg_creation`, subject severe `scoring_difficulty`. |
| Non-discriminating | negative results from both teams do not imply hidden upside. |
| Market intents | double chance, watchlist value, cautious rebound. |

### `team_worse_than_results`

| Element | Specification |
|---|---|
| Subject | Home or away. |
| Eligibility gates | `EG_XG_PREMATCH_ONLY`, `EG_CORE_SUPPORT_PRESENT`. |
| Core support | `positive_streak` plus xG overperformance signals. |
| Additional support | `misleading_result`, weak underlying creation, defensive overperformance. |
| Resistance | high xG creation, solid defense, ranking superiority if genuinely structural. |
| Strong contradiction | sustained high creation plus strong defense across enough sample. |
| Non-discriminating | positive streak shared by both teams is not enough. |
| Market intents | no automatic positive market; caution, downgrade, avoid overconfidence. |

### `avoid_match`

| Element | Specification |
|---|---|
| Subject | Match. |
| Eligibility gates | `EG_CORE_SUPPORT_PRESENT`, `EG_OPPONENT_RESISTANCE_CAPTURED`, `EG_STRONG_CONTRADICTION_POLICY`. |
| Core support | meaningful global ambiguity from data insufficiency, conflicting signals, balanced hierarchy, strong unresolved contradictions or scenario opposition. |
| Additional support | opposing context strengths, comparable positive form, open/closed conflict, market/sport mismatch. |
| Resistance | None. This is itself the prudence layer. |
| Strong contradiction | None. |
| Non-discriminating | Non-discriminating situations may contribute only when they create meaningful global ambiguity. One neutral signal alone must not produce `avoid_match`. |
| Market intents | none. |

## 11. Reading -> Thesis matrix V2.1.1

### Hierarchy

Tier facts are structural artifacts/gate inputs, not ordinary Reading rows. `EG_EXPECTED_DOMINATION_TIER_GAP` is evaluated before hierarchy readings can support `expected_domination`.

| Source | Target | Relation | Direction | Confidence |
|---|---|---|---|---|
| `structural_level_gap` | `expected_domination` | `CORE_SUPPORT` only after `EG_EXPECTED_DOMINATION_TIER_GAP`; otherwise no relation | subject | HIGH |
| `structural_level_gap` | `credible_outsider` | `CONTRADICTION` only if backed by Dynamic Tier separation | favorite/opponent | HIGH |
| `structural_level_gap` | `controlled_favorite` | `ADDITIONAL_SUPPORT` | favorite | MEDIUM |
| `structural_level_gap` | `one_sided_scoring` | `ADDITIONAL_SUPPORT` | target | MEDIUM |
| `ranking_superiority` | `expected_domination` | `ADDITIONAL_SUPPORT` / explanatory after Tier Gate; never core by itself | subject | HIGH |
| `ranking_superiority` | `favorite_with_protection` | `CORE_SUPPORT` | favorite | HIGH |
| `ranking_superiority` | `controlled_favorite` | `ADDITIONAL_SUPPORT` | favorite | MEDIUM |
| `ranking_superiority` | `team_worse_than_results` | `RESISTANCE` | subject | MEDIUM |
| `balanced_hierarchy` | `expected_domination` | `COEXISTS` / explanatory only; same Tier failure belongs to gate | match | HIGH |
| `balanced_hierarchy` | `credible_outsider` | `CORE_SUPPORT` | match | HIGH |
| `balanced_hierarchy` | `avoid_match` | `CORE_SUPPORT` | match | HIGH |

### Form

| Source | Target | Relation | Direction | Confidence |
|---|---|---|---|---|
| `positive_streak` | `expected_domination` | `ADDITIONAL_SUPPORT` when relevant; never comparative core evidence | subject | HIGH |
| `positive_streak` | `credible_outsider` | `ADDITIONAL_SUPPORT` when relevant; `NON_DISCRIMINATING` if both teams share comparable form | outsider | MEDIUM |
| `positive_streak` | `team_worse_than_results` | `CORE_SUPPORT` | subject | HIGH |
| `positive_streak` | `team_in_serious_difficulty` | `CONTRADICTION` | subject | MEDIUM |
| `negative_streak` | `team_in_serious_difficulty` | `CORE_SUPPORT` | subject | HIGH |
| `negative_streak` | `credible_outsider` | `ADDITIONAL_SUPPORT` | opponent/favorite | MEDIUM |
| `negative_streak` | `team_better_than_results` | `CORE_SUPPORT` | subject | HIGH |
| `improving_form` | `team_better_than_results` | `ADDITIONAL_SUPPORT` | subject | MEDIUM |
| `improving_form` | `credible_outsider` | `ADDITIONAL_SUPPORT` | outsider | LOW until form direction validated |
| `declining_form` | `team_in_serious_difficulty` | `ADDITIONAL_SUPPORT` | subject | MEDIUM |
| `declining_form` | `credible_outsider` | `ADDITIONAL_SUPPORT` | favorite/opponent | MEDIUM |
| `form_advantage` | `expected_domination` | `CORE_SUPPORT` | subject | HIGH |
| `form_advantage` | `credible_outsider` | `CORE_SUPPORT` | outsider | HIGH |
| `comparable_positive_form` | `expected_domination` | `NON_DISCRIMINATING` | match | HIGH |
| `comparable_positive_form` | `avoid_match` | `ADDITIONAL_SUPPORT` only if part of broader ambiguity | match | MEDIUM |

### Context home/away

| Source | Target | Relation | Direction | Confidence |
|---|---|---|---|---|
| `strong_home_team` | `expected_domination` | `ADDITIONAL_SUPPORT` | subject home | HIGH |
| `strong_home_team` | `expected_domination` | `RESISTANCE` or `CONTRADICTION` | opponent vs away subject | HIGH |
| `strong_home_team` | `credible_outsider` | `CORE_SUPPORT` | outsider home | HIGH |
| `strong_home_team` | `one_sided_scoring` | `ADDITIONAL_SUPPORT` | target home | MEDIUM |
| `strong_away_team` | `expected_domination` | `ADDITIONAL_SUPPORT` | subject away | HIGH |
| `strong_away_team` | `expected_domination` | `RESISTANCE` or `CONTRADICTION` | opponent vs home subject | HIGH |
| `strong_away_team` | `credible_outsider` | `CORE_SUPPORT` | outsider away | HIGH |
| `weak_home_team` | `team_in_serious_difficulty` | `CORE_SUPPORT` | subject home | HIGH |
| `weak_home_team` | `expected_domination` | `ADDITIONAL_SUPPORT` | opponent weakness for away subject | HIGH |
| `weak_away_team` | `team_in_serious_difficulty` | `CORE_SUPPORT` | subject away | HIGH |
| `weak_away_team` | `expected_domination` | `ADDITIONAL_SUPPORT` | opponent weakness for home subject | HIGH |
| `home_away_mismatch` | `expected_domination` | `ADDITIONAL_SUPPORT` | match/context | MEDIUM |
| `opposing_context_strengths` | `expected_domination` | `RESISTANCE` | match | HIGH |
| `opposing_context_strengths` | `avoid_match` | `ADDITIONAL_SUPPORT` | match | HIGH |

### Attack and defense

| Source | Target | Relation | Direction | Confidence |
|---|---|---|---|---|
| `prolific_attack` | `convergent_open_match` | `ADDITIONAL_SUPPORT` | any team | MEDIUM |
| `prolific_attack` | `both_sides_can_score` | `CORE_SUPPORT` when both sides covered | each team | HIGH |
| `prolific_attack` | `one_sided_scoring` | `CORE_SUPPORT` | target | HIGH |
| `prolific_attack` | `expected_domination` | `ADDITIONAL_SUPPORT` | subject | MEDIUM |
| `prolific_attack` | `controlled_favorite` | `CONTRADICTION` | opponent | MEDIUM |
| `scoring_difficulty` | `convergent_closed_match` | `ADDITIONAL_SUPPORT` | any team | HIGH |
| `scoring_difficulty` | `team_in_serious_difficulty` | `CORE_SUPPORT` | subject | HIGH |
| `scoring_difficulty` | `both_sides_can_score` | `STRONG_CONTRADICTION` | any required scorer | HIGH |
| `scoring_difficulty` | `team_better_than_results` | `STRONG_CONTRADICTION` | subject | HIGH |
| `scoring_difficulty` | `controlled_favorite` | `CORE_SUPPORT` | opponent | HIGH |
| `solid_defense` | `convergent_closed_match` | `ADDITIONAL_SUPPORT` | any team | HIGH |
| `solid_defense` | `favorite_with_protection` | `CORE_SUPPORT` | favorite | HIGH |
| `solid_defense` | `controlled_favorite` | `CORE_SUPPORT` | favorite | HIGH |
| `solid_defense` | `one_sided_scoring` | `ADDITIONAL_SUPPORT` | target | MEDIUM |
| `solid_defense` | `convergent_open_match` | `CONTRADICTION` | both teams if mirrored | MEDIUM |
| `fragile_defense` | `convergent_open_match` | `ADDITIONAL_SUPPORT` | any team | HIGH |
| `fragile_defense` | `team_in_serious_difficulty` | `CORE_SUPPORT` | subject | HIGH |
| `fragile_defense` | `one_sided_scoring` | `CORE_SUPPORT` | opponent | HIGH |
| `fragile_defense` | `expected_domination` | `CONTRADICTION` | subject | MEDIUM |
| `fragile_defense` | `controlled_favorite` | `STRONG_CONTRADICTION` | favorite | HIGH |
| `frequent_clean_sheet` | `convergent_closed_match` | `ADDITIONAL_SUPPORT` | any team | HIGH |
| `frequent_clean_sheet` | `controlled_favorite` | `ADDITIONAL_SUPPORT` | favorite | MEDIUM |
| `declining_defense` | `team_in_serious_difficulty` | `ADDITIONAL_SUPPORT` if defined | subject | LOW until produced |

### Rhythm and BTTS

| Source | Target | Relation | Direction | Confidence |
|---|---|---|---|---|
| `open_match_profile` | `convergent_open_match` | `CORE_SUPPORT` | match | HIGH |
| `open_match_profile` | `convergent_closed_match` | `STRONG_CONTRADICTION` | match | HIGH |
| `open_match_profile` | `controlled_favorite` | `CONTRADICTION` | match | HIGH |
| `open_match_profile` | `both_sides_can_score` | `ADDITIONAL_SUPPORT` | match | MEDIUM |
| `frequent_over_25` | `convergent_open_match` | `ADDITIONAL_SUPPORT` unless real frequency | match | HIGH |
| `closed_match_profile` | `convergent_closed_match` | `CORE_SUPPORT` | match | HIGH |
| `closed_match_profile` | `convergent_open_match` | `STRONG_CONTRADICTION` | match | HIGH |
| `closed_match_profile` | `both_sides_can_score` | `CONTRADICTION` | match | MEDIUM |
| `closed_match_profile` | `controlled_favorite` | `ADDITIONAL_SUPPORT` | match | HIGH |
| `frequent_under_25` | `convergent_closed_match` | `ADDITIONAL_SUPPORT` unless real frequency | match | HIGH |
| `frequent_btts` | `both_sides_can_score` | `ADDITIONAL_SUPPORT` or `CORE_SUPPORT` if real frequency | match | MEDIUM |

### Expected goals

| Source | Target | Relation | Direction | Confidence |
|---|---|---|---|---|
| `high_xg_creation` | `convergent_open_match` | `ADDITIONAL_SUPPORT` | any team | HIGH |
| `high_xg_creation` | `both_sides_can_score` | `CORE_SUPPORT` when both sides covered | each team | HIGH |
| `high_xg_creation` | `one_sided_scoring` | `CORE_SUPPORT` | target | HIGH |
| `high_xg_creation` | `team_better_than_results` | `CORE_SUPPORT` | subject | HIGH |
| `high_xg_creation` | `team_in_serious_difficulty` | `CONTRADICTION` | subject | MEDIUM |
| `high_xg_creation` | `controlled_favorite` | `CONTRADICTION` | opponent | HIGH |
| `high_xg_creation` | `team_worse_than_results` | `RESISTANCE` | subject | MEDIUM |
| `low_xg_creation` | `convergent_open_match` | `CONTRADICTION` | any team | MEDIUM |
| `low_xg_creation` | `both_sides_can_score` | `STRONG_CONTRADICTION` | any required scorer | HIGH |
| `low_xg_creation` | `team_better_than_results` | `STRONG_CONTRADICTION` | subject | HIGH |
| `low_xg_creation` | `one_sided_scoring` | `STRONG_CONTRADICTION` | target | HIGH |
| `low_xg_creation` | `controlled_favorite` | `CORE_SUPPORT` | opponent | MEDIUM |
| `high_xg_conceded` | `convergent_open_match` | `ADDITIONAL_SUPPORT` | any team | HIGH |
| `high_xg_conceded` | `both_sides_can_score` | `ADDITIONAL_SUPPORT` | any defense | HIGH |
| `high_xg_conceded` | `one_sided_scoring` | `CORE_SUPPORT` | opponent | HIGH |
| `offensive_underperformance` | `team_better_than_results` | `CORE_SUPPORT` | subject | HIGH |
| `offensive_underperformance` | `team_in_serious_difficulty` | `RESISTANCE` | subject | MEDIUM |
| `offensive_overperformance` | `team_worse_than_results` | `CORE_SUPPORT` | subject | HIGH |
| `defensive_overperformance` | `team_worse_than_results` | `CORE_SUPPORT` | subject | HIGH |
| `defensive_underperformance` | `team_in_serious_difficulty` | `ADDITIONAL_SUPPORT` | subject | MEDIUM |
| `defensive_underperformance` | `one_sided_scoring` | `ADDITIONAL_SUPPORT` | opponent | MEDIUM |
| `misleading_result` | `team_worse_than_results` | `ADDITIONAL_SUPPORT` | subject | HIGH |
| `misleading_result` | `expected_domination` | `CONTRADICTION` | subject | HIGH |
| `misleading_result` | `favorite_with_protection` | `CONTRADICTION` | favorite | HIGH |

### Data quality and market context

| Source | Target | Relation | Direction | Confidence |
|---|---|---|---|---|
| `conflicting_signals` | `avoid_match` | `CORE_SUPPORT` | match/team | HIGH |
| `conflicting_signals` | any directional team thesis | `CONTRADICTION` | subject | MEDIUM |
| `insufficient_data` | `avoid_match` | `CORE_SUPPORT` | match/team | HIGH |
| `insufficient_data` | any thesis requiring missing family | `EVIDENCE_UNAVAILABLE` / gate failure, not football contradiction | match/team | HIGH |
| `market_favorite` | `favorite_with_protection` | `CORE_SUPPORT` | subject | HIGH |
| `market_favorite` | `controlled_favorite` | `CORE_SUPPORT` | subject | HIGH |
| `market_favorite` | `expected_domination` | `COEXISTS` | subject | MEDIUM |
| `market_outsider` | `credible_outsider` | `CORE_SUPPORT` | subject | HIGH |
| `market_confirmation` | `expected_domination` | `MARKET_CONTEXT` / `COEXISTS`; never football support | subject | MEDIUM |
| `false_favorite` | `favorite_with_protection` | `STRONG_CONTRADICTION` if defined | subject | LOW until defined |
| `false_favorite` | `credible_outsider` | `ADDITIONAL_SUPPORT` if defined | favorite/opponent | LOW until defined |

## 12. Non-discriminating situations

| Situation | Classification | Impact V2.1.1 |
|---|---|---|
| Both teams have `positive_streak` with comparable scores | `NON_DISCRIMINATING` | Cannot count as direction support for domination or outsider. |
| Both teams have contextual strength in the relevant venue | `RESISTANCE` / `NON_DISCRIMINATING` | Adds resistance to domination and possible support to `avoid_match`. |
| Both teams have `prolific_attack` | Match-level support | Supports open/BTTS, not winner direction. |
| Both teams have `fragile_defense` | Match-level support | Supports open, not one-sided thesis. |
| Both teams have `solid_defense` | Match-level support | Supports closed, contradicts open/BTTS. |
| Rank gap small but points gap high | Ambiguous hierarchy | Cannot imply structural separation without Dynamic Tier System confirmation. |
| `frequent_over_25` derived from same climate as `open_match_profile` | Duplicate evidence | May enrich display but cannot count as independent family. |
| `frequent_under_25` derived from same climate as `closed_match_profile` | Duplicate evidence | Same rule. |
| One team high attack, opponent solid defense | Opposing strengths | Records resistance; does not auto-resolve. |
| Closed match profile plus one strong attack | Opposing rhythm | Closed remains possible with attack resistance. |
| Open match profile plus one strong defense | Opposing rhythm | Open remains possible with defensive resistance. |

## 13. Contradiction policy

V2.1.1 distingue quatre niveaux :

| Level | Meaning | Handling |
|---|---|---|
| `LIMIT` | Nuance faible ou incomplete. | Exposee dans limits, n'affecte pas l'eligibilite. |
| `RESISTANCE` | Force adverse contextuelle. | Exposee et degrade confiance narrative. |
| `CONTRADICTION` | Signal contraire direct. | Degrade confidence, peut changer market intent. |
| `STRONG_CONTRADICTION` | Signal contraire majeur. | Bloque ou downgrades la these selon policy explicite. |

Policy par these :

| Thesis | Strong contradiction handling |
|---|---|
| `expected_domination` | Same Tier is not handled here: it is `NOT_ELIGIBLE` via `EG_EXPECTED_DOMINATION_TIER_GAP`. After the Tier Gate passes, multiple strong contradictions may downgrade or block according to product policy. |
| `favorite_with_protection` | May remain eligible because protection often exists because of risk; must expose risk. |
| `convergent_open_match` | Block if direct closed profile plus bilateral low attack. |
| `convergent_closed_match` | Block if direct open profile plus bilateral high creation. |
| `credible_outsider` | Block if favorite structural gap is strong and outsider lacks creation/context support. |
| `team_in_serious_difficulty` | Downgrade if hidden xG upside is strong. |
| `controlled_favorite` | Block if open profile and opponent high creation are both strong. |
| `both_sides_can_score` | Block if either side has severe low creation/scoring difficulty. |
| `one_sided_scoring` | Block if target cannot create or opponent has equally strong creation. |
| `team_better_than_results` | Block if low xG creation contradicts hidden potential. |
| `team_worse_than_results` | Downgrade if strong xG creation confirms results. |
| `avoid_match` | No contradiction policy; it absorbs ambiguity. |

## 14. Thesis-to-thesis relationships

Les relations thesis -> thesis doivent etre derivees en priorite de la matrice Reading -> Thesis.

| Source thesis | Target thesis | Relation | Rule |
|---|---|---|---|
| `expected_domination(A)` | `controlled_favorite(A)` | `REINFORCES` | Shared hierarchy + favorite defense + opponent low threat. |
| `controlled_favorite(A)` | `expected_domination(A)` | `REINFORCES` | Shared favorite and control supports. |
| `credible_outsider(B)` | `expected_domination(A)` | `CONTRADICTS` | Outsider has gap-reducing core supports. |
| `convergent_open_match` | `convergent_closed_match` | `STRONGLY_CONTRADICTS` | Direct rhythm opposition. |
| `convergent_open_match` | `both_sides_can_score` | `REINFORCES` | Open rhythm + bilateral creation. |
| `convergent_closed_match` | `controlled_favorite(A)` | `REINFORCES` | Closed climate supports control. |
| `both_sides_can_score` | `one_sided_scoring(A)` | `CONTRADICTS` | Opponent also has creation capacity. |
| `team_in_serious_difficulty(B)` | `one_sided_scoring(A)` | `REINFORCES` | Opponent difficulty supports target pressure. |
| `team_better_than_results(A)` | `team_in_serious_difficulty(A)` | `CONTRADICTS` | Hidden potential weakens serious difficulty. |
| `team_worse_than_results(A)` | `expected_domination(A)` | `CONTRADICTS` | Positive results may be misleading. |
| `avoid_match` | any recommended thesis | `CAUTION_OVERLAY` | Ambiguity should be visible after matching. |

## Championship Structural Intelligence and persistence

The Dynamic Tier System is shared by multiple matches in the same championship. Conceptually, a championship-level snapshot may feed several match-level bundles.

```text
ChampionshipTierSnapshot
    -> Match A vs B
    -> MatchAnalysisBundle
```

Responsibilities:

- Tier calculation, Team Tier Assignment, Tier Gap and hierarchy gate results belong to the engine/backend.
- A `ChampionshipTierSnapshot` is reusable for multiple matches with the same competition, season and compatible `analysisAsOf`, subject to future freshness rules.
- The UI receives Tier facts through the bundle and must not recalculate Tiers from visible standings.
- If the Tier System is immature or unavailable, related theses are `NOT_EVALUABLE`; this is not equivalent to `tierGap = 0`.
- No cache or storage infrastructure is specified in V2.1.1.

Existing repository status from inspection:

| Item | Status | Notes |
|---|---|---|
| Explicit Tier implementation | `NO` | No Tier System, Tier assignment or Tier Gap model found. |
| Standings data | `PARTIAL` | `TeamStandingSnapshot` maps rank, points, played, wins/draws/losses, goal diff, form and group. |
| Full standings by league | `PARTIAL` | `ApiFootballMatchAdapter` can build sorted standings per league from snapshot data. |
| Competition structure metadata | `PARTIAL / REQUIRES_DATA_SOURCE` | API-Football raw standings include `description` such as promotion/relegation, but current `TeamStandingSnapshot` does not retain it. |
| Runtime competition list | `PARTIAL` | `RuntimeCompetitionCatalog.apiFootballLeagueIds` lists supported leagues, but not podium/relegation rules. |
| Reusable logic | `PARTIAL` | Existing standings normalization can feed a future `ChampionshipTierSnapshot`; current hierarchy readings are raw rank/points rules. |

## 15. Market intents and user matching boundary

Market context belongs to the global analysis only when it describes the match market itself.

Profile matching is separate.

| Layer | Allowed operations |
|---|---|
| Match Intelligence | Detect favorite/outsider, market confirmation, theoretical market intents, no user filtering. |
| User Matching | Hide disabled competitions, prefer selected thesis families, filter markets, rank picks, apply odds preferences, write personalized copy. |
| Presentation | Select what to show for "Pour moi", "Tous", ticket, detail sheet, explanations. |

Required boundary tests for future implementation:

- A match with no user profile still produces `MatchAnalysisBundle`.
- A disabled competition still has a full analysis bundle.
- A non-preferred thesis still appears in relations if it contradicts or reinforces a preferred thesis.
- A disabled market removes the pick recommendation, not the underlying thesis.
- UI reading sheets display bundle readings/relations rather than fixed cards.

## 16. UI alignment rules

The UI must not reconstruct football intelligence from labels, standings snippets or fixed cards.

Rules:

- Detail sheets must render actual `supportingReadings`, `contradictions`, `resistances` and `nonDiscriminatingSignals` from the bundle.
- Ticket explanations must use engine IDs, not guessed IDs from localized text.
- Presentation-only IDs must either receive real producers or disappear from explanatory surfaces.
- Counts must reflect actual relations, not fixed card counts.
- Copy must expose semantic nuance: "ecart au classement" is safer than "ecart structurel" when only one hierarchy dimension is strong.
- Structural wording must come from the Dynamic Tier System. `rankGap` or `pointsGap` alone may justify "avantage au classement", but never "ecart structurel eleve".
- Example: 1st vs 3rd in the same Tier may preserve ranking edge copy, but must not display a high structural level gap.

## 17. Legacy disposition

| Legacy ID | V2.1.1 disposition |
|---|---|
| `solid_favorite` | User intent/profile family, not canonical thesis. It can group `expected_domination`, `controlled_favorite`, `favorite_with_protection`. |
| `cautious_double_chance` | Market intent derived from eligible theses, not football thesis. |
| `level_gap` | Alias of hierarchy evidence used by `expected_domination`. |
| `open_match` | Alias/migration target to `convergent_open_match`. |
| `closed_match` | Alias/migration target to `convergent_closed_match`. |
| `no_sufficient_thesis` | Analysis state when no canonical thesis is eligible; not an opportunity thesis. |

## 18. Validation checklist

Before implementation, each row must be validated with product and domain review.

### Reading validation

- ID stable and unique.
- Producer defined or status explicitly `DISPLAY_ONLY_REVIEW` / `DEPRECATE_OR_DEFINE`.
- Evidence family assigned.
- Subject type defined.
- Input fields listed.
- Sample and temporal gates defined.
- Strength semantics defined.
- User-facing wording aligned with calculation.

### Thesis validation

- Subject type defined.
- Core supports listed.
- Additional supports listed.
- Contradictions and strong contradictions listed.
- Non-discriminating situations listed.
- Market intents listed separately from user profile markets.
- Eligibility gates listed.
- Policy for strong contradictions defined.

### Relation validation

- Source reading ID exists or is proposed.
- Target thesis ID is canonical or explicitly legacy.
- Direction is resolved.
- Relation type is one of the V2.1.1 taxonomy values.
- Confidence is assigned.
- Duplicate evidence risk is checked.
- Contradiction/resistance wording is user-safe.

### Bundle validation

- No profile field required.
- All readings preserved even if no thesis is eligible.
- All known theses evaluated.
- Non-eligible theses preserve gate failure reasons.
- The output is serializable and reusable.
- The UI can render explanations directly from the bundle.

## 19. Generic acceptance cases

### Case A - Same Tier

Given:

```text
A = Tier 1
B = Tier 1
A rank = 1
B rank = 3
pointsGap = important
```

Expected:

- ranking edge may exist ;
- points edge may exist ;
- `expected_domination = NOT_ELIGIBLE` ;
- `failedGate = EG_EXPECTED_DOMINATION_TIER_GAP` ;
- reason = same structural Tier ;
- not `RESISTANCE`, not `CONTRADICTION`, not `STRONG_CONTRADICTION`.

### Case B - Different Tiers, small raw point gap

Given:

```text
A = Tier 1
B = Tier 2
pointsGap = relatively small
point distribution shows a real break between groups
```

Expected:

- structural separation can be valid ;
- `EG_EXPECTED_DOMINATION_TIER_GAP = PASS` ;
- the final thesis is not automatically eligible ;
- other gates, supports, non-discriminating situations and resistances still apply.

### Case C - Different Tiers + opponent context resistance

Given:

```text
A = structurally superior Tier
B = lower Tier
B = very strong home team
```

Expected:

- Tier Gate passes ;
- `strong_home_team(B)` becomes `RESISTANCE` or `CONTRADICTION` according to validated policy ;
- `expected_domination(A)` remains evaluable ;
- opponent strength must be exposed in Match Intelligence.

### Case D - Tier System immature

Given:

```text
championship sample insufficient
```

Expected:

- Tier assignment = unavailable / immature ;
- `expected_domination` structural gate = `NOT_EVALUABLE` ;
- not `tierGap = 0` ;
- not `STRONG_CONTRADICTION`.

### Case E - Absolute form vs comparative form

Given:

```text
Team A form = 11/15
Team B form = 11/15
```

Expected:

- `positive_streak(A)` may exist ;
- `positive_streak(B)` may exist ;
- `comparable_positive_form = true` ;
- for a directional thesis, `positive_streak(A)` is not core comparative evidence ;
- for a directional thesis, `positive_streak(B)` is not core comparative evidence ;
- the form family is directionally `NON_DISCRIMINATING`.

Given:

```text
Team A form = 13/15
Team B form = 5/15
```

Expected:

- `positive_streak(A)` may exist ;
- `form_advantage(A)` may exist ;
- for a compatible directional thesis, `positive_streak(A)` is absolute supporting context ;
- for a compatible directional thesis, `form_advantage(A)` is comparative directional evidence ;
- the engine must not confuse those two concepts.

### Case F - Correlated hierarchy evidence

Given:

```text
ranking_superiority(A) = true
structural_level_gap(A) = true
rankGap available
pointsGap available
tierGap available
```

Expected:

- the bundle may preserve all explanatory facts/readings ;
- the thesis engine must not interpret them as five independent confirmations ;
- they belong to the same structural evidence lineage / `EF_HIERARCHY` ;
- the engine must preserve explainability without artificial evidence inflation.

### Case G - Gate failure is not opposition

Given:

```text
A and B are same Tier
```

Expected:

- `expected_domination(A) = NOT_ELIGIBLE` ;
- reason = `EG_EXPECTED_DOMINATION_TIER_GAP` failed ;
- do not create `CONTRADICTION`, `STRONG_CONTRADICTION` or `RESISTANCE` solely because the teams share a Tier ;
- the thesis simply does not satisfy its structural existence condition.

### Case H - Thesis eligible but opponent resists

Given:

```text
A = higher structural Tier
B = lower structural Tier
Tier Gate passes
A has additional compatible support
B is extremely strong in the relevant home context
```

Expected:

- `expected_domination(A)` remains evaluable ;
- `strong_home_team(B)` must be preserved ;
- it must influence the thesis as `RESISTANCE` or `CONTRADICTION` according to the still-open product decision ;
- it must not be silently ignored ;
- it must not retroactively become a Tier Gate failure.

## 20. Case study acceptance: KR Reykjavik vs Vikingur

Pre-match facts:

- Vikingur 1st, 51 points.
- KR 3rd, 43 points.
- Rank gap 2, points gap 8.
- KR home: 8W, 2D, 0L.
- Vikingur away: 8W, 1D, 1L.
- Comparable form around 11/15.

Expected V2.1.1 analysis behavior:

- The Dynamic Championship Tier System is queried before validating `expected_domination`.
- If Vikingur = `TIER_1` and KR = `TIER_1`, then `tierGap = 0`.
- In that configuration, `expected_domination(Vikingur)` must be `NOT_ELIGIBLE`.
- The failed gate must be `EG_EXPECTED_DOMINATION_TIER_GAP`.
- This remains true even if `pointsGap = 8`, `ranking_superiority(Vikingur) = true`, `positive_streak(Vikingur) = true` and `strong_away_team(Vikingur) = true`.
- None of those signals can bypass the Tier Gate.
- `ranking_superiority(Vikingur)` remains preserved as factual hierarchy evidence.
- `strong_away_team(Vikingur)` remains preserved as contextual strength once produced.
- `strong_home_team(KR)` remains preserved as opposing contextual strength.
- Comparable positive form must downgrade `positive_streak(Vikingur)` from directional support to `NON_DISCRIMINATING`.
- `opposing_context_strengths` should support caution or `avoid_match` if both venue strengths are strong.
- `credible_outsider(KR)` can coexist if market outsider gates and KR supports are present.
- All 12 canonical theses must continue to be evaluated.
- The final result of the match must not be used.

Acceptance criterion :

```text
If Vikingur and KR are assigned to the same Tier:
  expected_domination(Vikingur).status = NOT_ELIGIBLE
  failedGate = EG_EXPECTED_DOMINATION_TIER_GAP

The bundle still preserves:
  ranking_superiority(Vikingur)
  strong_away_team(Vikingur)
  strong_home_team(KR)
  comparable_positive_form
  all other available readings
  evaluation of all other canonical theses
```

The engine must never produce `expected_domination = ELIGIBLE_WITH_WARNINGS` in the same-Tier configuration.

## 21. Counts for validation

| Item | Count |
|---|---:|
| Evidence families | 11 |
| Eligibility gates before V2.1.1 | 26 |
| Eligibility gates after V2.1.1 | 31 |
| Reading IDs covered | 41 |
| Canonical V2.1.1 theses | 12 |
| Legacy IDs assigned a disposition | 6 |
| Reading -> Thesis relation rows inspected | 109 |
| Reading -> Thesis relation rows modified in V2.1.1 | 8 |
| Reading -> Thesis relation rows removed in V2.1.1 | 0 |
| Reading -> Thesis relation rows added in V2.1.1 | 0 |
| Reading -> Thesis relation rows marked `REQUIRES_PRODUCT_DECISION` | 4 |
| Non-discriminating situations | 11 |
| Thesis -> Thesis relation rows | 11 |

## 22. V2.1.1 relation coherence audit

The 109 Reading -> Thesis relation rows were reviewed against the V2.1.1 rules.

Rows modified:

| Source | Target | Previous V2.1 relation | V2.1.1 correction | Reason |
|---|---|---|---|---|
| `structural_level_gap` | `expected_domination` | `CORE_SUPPORT` | Core only after `EG_EXPECTED_DOMINATION_TIER_GAP`; otherwise no relation. | Raw hierarchy cannot bypass Dynamic Tier System. |
| `ranking_superiority` | `expected_domination` | `CORE_SUPPORT` | `ADDITIONAL_SUPPORT` / explanatory only after Tier Gate. | Rank edge does not prove structural domination. |
| `balanced_hierarchy` | `expected_domination` | `STRONG_CONTRADICTION` | `COEXISTS` / explanatory only. | Same Tier is Gate Failure, not contradiction. |
| `insufficient_data` | any thesis requiring missing family | `CONTRADICTION` | `EVIDENCE_UNAVAILABLE` / gate failure. | Absence of information is not contrary football evidence. |
| `market_confirmation` | `expected_domination` | `ADDITIONAL_SUPPORT` | `MARKET_CONTEXT` / `COEXISTS`. | Market does not strengthen football truth. |
| `positive_streak` | `expected_domination` | `CORE_SUPPORT` if discriminant | `ADDITIONAL_SUPPORT` when relevant; never comparative core evidence. | Absolute form is not comparative advantage. |
| `positive_streak` | `credible_outsider` | `CORE_SUPPORT` if outsider-specific | `ADDITIONAL_SUPPORT` when relevant; `NON_DISCRIMINATING` if comparable. | Absolute form is not comparative advantage. |
| `comparable_positive_form` | `avoid_match` | `ADDITIONAL_SUPPORT` | Additional only if part of broader ambiguity. | One neutral/non-discriminating signal must not create `avoid_match`. |

Rows marked `REQUIRES_PRODUCT_DECISION`:

- `structural_level_gap -> expected_domination`: final definition of structural gap from Tier System.
- `structural_level_gap -> credible_outsider`: exact policy when favorite is structurally superior.
- `ranking_superiority -> expected_domination`: whether it remains additional support or pure explanation after Tier Gate.
- `strong_home_team/strong_away_team opponent -> expected_domination`: resistance vs contradiction policy.

## 23. Locked Business Principles Before Dynamic Tier Algorithm

| # | Principle | Status |
|---:|---|---|
| 1 | Football analysis is profile-independent. | `VALIDATED / LOCKED` |
| 2 | Every available reading is preserved. | `VALIDATED / LOCKED` |
| 3 | Every canonical thesis is evaluated. | `VALIDATED / LOCKED` |
| 4 | User matching occurs after Match Intelligence. | `VALIDATED / LOCKED` |
| 5 | Raw facts are not automatically independent evidence. | `VALIDATED / LOCKED` |
| 6 | Structural artifacts are distinct from ordinary readings. | `VALIDATED / LOCKED` |
| 7 | Gate Failure is not contradiction. | `VALIDATED / LOCKED` |
| 8 | Evidence unavailable is not contradiction. | `VALIDATED / LOCKED` |
| 9 | Absence of support is not contradiction. | `VALIDATED / LOCKED` |
| 10 | Absolute strength is not automatically comparative advantage. | `VALIDATED / LOCKED` |
| 11 | Non-discriminating evidence cannot support a directional thesis. | `VALIDATED / LOCKED` |
| 12 | Resistance is distinct from contradiction. | `VALIDATED / LOCKED` |
| 13 | Correlated readings cannot inflate evidence count. | `VALIDATED / LOCKED` |
| 14 | Evidence families matter more than raw reading count. | `VALIDATED / LOCKED` |
| 15 | Market context cannot manufacture football evidence. | `VALIDATED / LOCKED` |
| 16 | Same Tier blocks `expected_domination`. | `VALIDATED / LOCKED` |
| 17 | A passed Tier Gate does not automatically validate `expected_domination`. | `VALIDATED / LOCKED` |
| 18 | `positive_streak` is absolute evidence. | `VALIDATED / LOCKED` |
| 19 | `form_advantage` is comparative evidence. | `VALIDATED / LOCKED` |
| 20 | Form trajectory is distinct from aggregate recent form. | `VALIDATED / LOCKED` |
| 21 | Opponent strengths must remain visible. | `VALIDATED / LOCKED` |
| 22 | Thesis -> Thesis logic should be derived whenever possible. | `VALIDATED / LOCKED` |
| 23 | `avoid_match` requires meaningful global ambiguity, not one neutral signal. | `VALIDATED / LOCKED` |
| 24 | Final match results are forbidden from pre-match reasoning. | `VALIDATED / LOCKED` |
| 25 | Match Intelligence must remain persistable and reusable across users. | `VALIDATED / LOCKED` |

## 24. Open product confirmations

These are the remaining confirmations before implementation can start safely:

### Dynamic Tier System

1. Exact Dynamic Tier boundary algorithm.
2. Exact `POINT_GAP_BREAK` detection.
3. Championship maturity threshold.
4. Atypical competitions, playoffs, split seasons, groups and leagues without relegation.
5. Podium/relegation metadata source.
6. Exact policy for `tierGap = 1` by thesis, especially `expected_domination`.
7. Final technical representation of Tier artifacts.
8. Final semantics and producer of `structural_level_gap` after Tier integration.

### Engine decisions still requiring validation

9. Exact `STRONG_CONTRADICTION` blocking policy where not already locked.
10. Resistance vs contradiction for opponent contextual strength in `expected_domination`.
11. Exact implementation form of derived concepts vs explicit readings.
12. Exact historical frequency implementation for over/under/BTTS.
13. Official temporal convention for form strings.
14. Final semantics/producer of any currently display-only readings.
15. Whether `insufficient_data` should be split into `insufficient_match_data` and `invalid_temporal_data`.
