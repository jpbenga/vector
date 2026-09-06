# Lector - Cles du match : specification fonctionnelle V1

Date : 2026-09-05
Statut : REFERENCE_PRE_IMPLEMENTATION_DECIDED.
Perimetre : onglet Contexte du detail de match.

## 1. Objet et frontieres

Cles du match repond uniquement a la question :

> Quels faits contextuels caracterisent cette rencontre ?

Principe fondamental :

> Les valeurs brutes servent a expliquer la cle a l'utilisateur.
> Le contexte du championnat sert a determiner si cette valeur merite de
> devenir une cle.

~~~text
valeur du match
        ↓
reference relative au meme championnat / meme snapshot
        ↓
ordinaire ou remarquable
        ↓
selection eventuelle
        ↓
affichage de la valeur brute
~~~

Le pipeline V1 est donc :

~~~text
Donnees contextuelles du match
        ↓
Candidats contextuels
        ↓
Reference championnat et evaluation de remarquabilite
        ↓
Deduplication / fusion semantique
        ↓
Selection de 0 a 4 cles
        ↓
Cles du match
~~~

Le composant est profile-independent et pre-match.

Il ne contient pas :
- de categorisation relationnelle, nature speciale ou traitement specifique;
- de FootballReading, ThesisAssessment, ThesisEvidenceRelation, Opportunity,
  marche, cote, score de these ou recommandation;
- de prediction, probabilite, confiance de pari ou interpretation de scenario;
- de familles Trajectoire, Rythme ou Vigilance.

Une information pouvant nuancer une autre est une cle normale si elle est
remarquable dans le championnat. Une separation Structure et un bilan away
adverse peuvent donc apparaitre ensemble sans relation speciale.

## 2. Sources et preconditions

Entree unique : MatchBoardItem.

Sources utilisees :
- MatchAnalysisData.asOf;
- homeStanding, awayStanding et leagueStandings;
- championshipTierSnapshot et structuralRelation pour Structure seulement;
- homeStatistics et awayStatistics seulement comme informations descriptives
  lorsque leurs donnees ne sont pas disponibles dans leagueStandings.

Preconditions globales :
1. fixture.status doit etre scheduled;
2. analysis.asOf est obligatoire et ne doit pas etre posterieur au kickoff;
3. les valeurs de comparaison et leur reference championnat proviennent du
   meme competitionId, de la meme season et du meme standings snapshot;
4. la famille ne s'active que si tous ses champs obligatoires sont presents;
5. aucune donnee posterieure au kickoff, aucun fallback DateTime.now et aucun
   melange de snapshots ne sont autorises.

FootballAnalysis est hors du flux V1. Une FootballReading ne peut ni creer,
ni supprimer, ni classer une cle.

## 3. Contrat de sortie

MatchContextKey est une valeur profile-independent limitee a :
- family : hierarchy, structure, form, venue, attack, defense, opposition;
- semanticScope : le fait que la carte raconte;
- subjectTeamIds : une ou deux equipes;
- facts : valeurs brutes et derivees transparentes;
- remarkability : remarquable, evaluee depuis une reference relative;
- sourcePaths : champs de MatchAnalysisData et de la reference championnat.

Il n'existe ni nature speciale, ni reference de these, ni relation de preuve
dans MatchContextKey.

## 4. Reference dynamique de championnat

La remarquabilite ne repose sur aucun seuil absolu universel de rang, points,
forme, taux de victoire ou buts par match.

Une reference ephemere est construite par :

~~~text
competitionId + season + standings snapshot
~~~

Elle utilise leagueStandings pour deriver, lorsque les champs sont complets :
- pointsPerGame = points / played;
- scores Forme sur cinq resultats W=3, D=1, L=0;
- buts marques par match = goalsFor / played;
- buts encaisses par match = goalsAgainst / played;
- distributions et comparaisons relatives necessaires a ces valeurs.

Une distribution Tukey n'est construite qu'a partir de 10 equipes exploitables
pour la metrique concernee. Ce minimum concerne le nombre d'equipes de la
distribution championnat, jamais le nombre de matchs joues par une equipe.

La maturite EARLY/ESTABLISHED est independante de la remarquabilite. Une
distribution utilise les lignes dont la valeur est calculable; les lignes
absentes ne bloquent ni l'analyse du match ni les autres familles.

`AnalysisMaturity` est calculee avant le kickoff depuis les matchs reellement
joues : `EARLY` si homePlayed ou awayPlayed est inferieur a 5, `ESTABLISHED`
si les deux equipes ont joue au moins 5 matchs. EARLY conserve les lectures,
theses et cles, mais interdit l'exploitation automatique par Opportunity et
le generateur de tickets.

### 4.1 Contrat de fiabilite existant

Les cles du match ne reutilisent aucun minimum legacy du moteur de lectures.
La disponibilite depend uniquement des champs reellement calculables dans le
snapshot partage; la maturite EARLY/ESTABLISHED ne supprime jamais une cle.

| Famille | Champs controles | Regle de fiabilite existante reutilisee |
|---|---|---|
| Hierarchie | rank, points, played | `played > 0` et points presents pour calculer le PPG; la maturite est portee separement. |
| Forme | standings[].form | au moins un resultat W/D/L normalisable; la sequence affiche jusqu'a cinq resultats disponibles. |
| Attaque | goalsFor, played | `played > 0` et goalsFor present pour calculer la moyenne derivee. |
| Defense | goalsAgainst, played | `played > 0` et goalsAgainst present pour calculer la moyenne derivee. |
| Structure | Dynamic Tier | tierStatus et tierMaturity existants determinent deja la disponibilite; aucun minimum parallele n'est ajoute. |

Pour une reference championnat, chaque standing utilise doit posseder les
champs calculables de sa famille. Les lignes inexploitables sont ignorees sans
annuler la reference entiere. Cette exigence de disponibilite ne definit pas
un seuil de remarquabilite.

Les anciennes bornes numeriques des FootballReadings, par exemple les ecarts
de rangs, de points, de forme ou de buts, sont supprimees et ne participent
plus a Cles du match.

### 4.2 Regle relative V1 verrouillee

Pour Hierarchie, Forme, Attaque et Defense :

1. trier les valeurs de la distribution dans l'ordre pertinent, sans separer
   les valeurs egales;
2. calculer les gaps adjacents strictement positifs;
3. calculer Q1, Q3 et IQR = Q3 - Q1 sur ces gaps;
4. une frontiere est separante seulement si :

~~~text
gap > Q3 + 1.5 * IQR
~~~

5. la zone de bord haute ou basse definie par cette frontiere est valide
   seulement si son etendue interne est strictement inferieure au gap :

~~~text
max(zone) - min(zone) < gap
~~~

6. par direction, conserver la frontiere valide au plus grand gap; si les
   meilleures frontieres sont ex aequo et definissent des zones distinctes,
   s'abstenir dans cette direction.

La borne de Tukey est derivee de la distribution du meme championnat et du
meme snapshot. Elle ne constitue pas un seuil football absolu. Aucune limite
en pourcentage de la taille du championnat n'est appliquee.

Les valeurs brutes restent affichables sans afficher necessairement la
reference qui a permis leur selection.

## 5. Catalogue V1 verrouille

### 5.1 Hierarchie

Question : quelle est la position officielle relative des equipes ?

Valeurs brutes :
- homeStanding.rank, awayStanding.rank;
- homeStanding.points, awayStanding.points;
- homeStanding.played, awayStanding.played.

Reference championnat : leagueStandings fournit les points, matchs joues et
PPG de toutes les equipes du meme snapshot. ChampionshipTierSnapshot expose
aussi pointDistribution, ppgDistribution, typicalGap et les assignments.

Regle V1 : si MatchStructuralRelation marque le duel balancedHierarchy, il est
exclu. Sinon, la distribution PPG applique la regle Tukey + compacite de la
section 4.2. La cle existe lorsqu'une ou les deux equipes appartiennent a une
zone PPG separee et que leurs zones ne racontent pas le meme positionnement.
Les rangs et points expliquent le fait affiche; ils ne deviennent pas seuls une
condition universelle de remarquabilite.

Ne pas afficher : rangs seuls, points ou matchs joues absents, absence de
reference championnat calculable, ou duel ordinaire selon la regle relative
validee. Une analyse EARLY reste visible et est marquee comme telle.

Hierarchie reste distincte de Structure : elle decrit la position officielle,
pas une rupture de championnat.

### 5.2 Structure

Question : une rupture reelle de championnat separe-t-elle les equipes ?

Champs :
- structuralRelation.homeTeamTier, awayTeamTier, sameTier;
- structuralBoundaryGap, confirmedBoundariesBetweenTeams;
- tierStatus, tierMaturity;
- confirmedBoundariesBetweenTeams.strength.

Regle V1 : Structure consomme uniquement le Dynamic Tier existant. La candidate
existe si tierStatus et tierMaturity sont mature, sameTier est false et au moins
une boundary confirmee separe les equipes. La force affichee provient de la
boundary existante; aucun Tier ni seuil parallele ne sont recalcules.

Ne pas afficher : Tier absent, immature ou indisponible, meme Tier, ou absence
de boundary confirmee.

### 5.3 Forme

Question : quel est le niveau de resultats recents des equipes dans le contexte
de ce championnat ?

Valeurs brutes : sequence W/D/L et total sur quinze points de chaque equipe.

Champs : homeStanding.form et awayStanding.form. homeStatistics.form ou
awayStatistics.form ne sont qu'un secours descriptif et ne peuvent pas fournir
la distribution championnat.

Reference championnat : parser les form de leagueStandings dans le meme ordre
que le snapshot, puis comparer les scores et l'ecart du duel aux autres formes
exploitables de ce championnat.

Regle V1 : candidate seulement si les deux series et la reference championnat
sont exploitables, et si au moins une equipe appartient a une zone haute ou
basse remarquable selon la regle Tukey + compacite. Aucun seuil fixe tel que
4, 7, 13/15 ou 4/15 ne decide la remarquabilite.

Ne pas afficher : absence de resultat W/D/L normalisable pour les equipes du
duel, absence de distribution calculable, ou fait ordinaire dans la reference
championnat. La sequence peut contenir moins de cinq resultats en EARLY.

### 5.4 Domicile / Exterieur

Question : le lieu cree-t-il un contraste de bilan remarquable ?

Valeurs brutes definies :
- homeStatistics.playedHome, winsHome, drawsHome, lossesHome;
- awayStatistics.playedAway, winsAway, drawsAway, lossesAway;
- winRate = wins / played, affichable a titre descriptif.

Statut V1 : famille definie fonctionnellement mais non activable en selection
dynamique V1. Le snapshot ne garantit pas les splits home/away de toutes les
equipes de leagueStandings : il ne permet donc pas une reference championnat
fiable. Aucun winRate gap universel ne doit etre utilise pour la sauver.

Si cette famille est activee dans une version future, sa prudence suivra la
maturite commune sans introduire un minimum legacy distinct.

### 5.5 Attaque

Question : une production offensive est-elle remarquable dans ce championnat ?

Valeurs brutes : buts marques par match et matchs joues de chaque equipe.

Champs de selection et d'affichage de reference : TeamStandingSnapshot.goalsFor
et played pour les deux equipes et pour leagueStandings. Le taux est derive par
goalsFor / played dans le meme standings snapshot.

homeStatistics.goalsForAverageTotal peut rester une information descriptive
secondaire si disponible, mais ne fournit pas une distribution complete et ne
participe pas a la selection V1.

Regle V1 : situer les productions des deux equipes dans la distribution
offensive derivee de leagueStandings. Une carte existe si au moins une equipe
appartient a une zone haute ou basse remarquable selon la regle Tukey +
compacite et si les echantillons sont fiables. Aucun averageGap universel ne
s'applique.

Ne pas afficher : champs non calculables ou fait ordinaire dans la reference
championnat. Une valeur sur peu de matchs peut etre remarquable mais reste
EARLY tant que les deux equipes n'ont pas cinq matchs precedents.

### 5.6 Defense

Question : une exposition defensive est-elle remarquable dans ce championnat ?

Valeurs brutes : buts encaisses par match et matchs joues de chaque equipe.

Champs de selection et d'affichage de reference :
TeamStandingSnapshot.goalsAgainst et played pour les deux equipes et pour
leagueStandings. Le taux est derive par goalsAgainst / played dans le meme
standings snapshot.

homeStatistics.goalsAgainstAverageTotal peut rester descriptif secondaire.
cleanSheetsTotal, cleanSheetsHome et cleanSheetsAway peuvent egalement etre
affiches lorsqu'ils existent, mais ne participent jamais a la selection.

Regle V1 : situer les expositions defensives dans la distribution defensive
derivee de leagueStandings. Une carte existe si au moins une equipe appartient
a une zone basse solide ou haute exposee remarquable selon la regle Tukey +
compacite et si les echantillons sont fiables. Aucun averageGap universel ne
s'applique.

Ne pas afficher : champs non calculables ou fait ordinaire dans la reference
championnat. Une valeur sur peu de matchs peut etre remarquable mais reste
EARLY tant que les deux equipes n'ont pas cinq matchs precedents.

### 5.7 Opposition

Question : une attaque contextuellement forte rencontre-t-elle une defense
adverse contextuellement exposee ?

Champs : les memes goalsFor / played et goalsAgainst / played derives de
leagueStandings, avec les matchs joues correspondants.

Regle V1 : Opposition ne possede aucune logique statistique autonome. Pour une
direction A attaque vers B defense, elle existe seulement si :
1. l'attaque de A est deja remarquable dans la distribution offensive;
2. la defense de B est deja remarquable comme exposee dans la distribution
   defensive;
3. les deux faits appartiennent au meme championnat et au meme snapshot.

Si les deux directions sont eligibles, conserver la direction domicile vers
exterieur. Opposition ne recalcule jamais une regle statistique autonome.

## 6. Rythme, Trajectoire et Vigilance exclus

Rythme est une lecture match-level et non un fait contextuel brut avec les
donnees actuelles. Trajectoire et Vigilance ne font pas partie du catalogue V1.
Les contradictions et resistances restent dans ThesisAssessment et
ThesisEvidenceRelation, hors de Cles du match.

## 7. Deduplication et fusion semantique

Les familles restent distinctes dans le modele. La selection compare leurs
propositions semantiques, pas leurs noms.

Deux candidates sont redondantes si elles ont :
1. le meme sujet ou la meme paire;
2. le meme axe de contexte;
3. la meme direction;
4. aucun fait additionnel utile pour comprendre le match.

Resolution :
- conserver les deux si elles repondent a des questions distinctes;
- fusionner dans une cle composite si elles expliquent exactement le meme fait;
- a contribution egale, privilegier la candidate avec les faits sources les
  plus complets; egalite : Structure, Hierarchie, Forme, Opposition, Attaque,
  Defense, Domicile/Exterieur;
- Domicile/Exterieur ne peut pas etre retenue tant que son statut V1 reste
  indisponible.

Fusion autorisee :
- Hierarchie + Structure : Positionnement dans le championnat, avec sous-bloc
  officiel et sous-bloc structural;
- Attaque + Defense : seulement si elles sont les deux sources exactes de la
  meme Opposition.

Fusion interdite :
- une Structure et un bilan away adverse;
- Opposition et Defense propre d'une autre equipe.

## 8. Selection finale

1. Construire une candidate par famille eligible; Opposition evalue ses deux
   directions mais conserve au plus une candidate.
2. Retirer les candidates indisponibles, non fiables, ordinaires selon la
   reference championnat, et les redondances resolues.
3. Trier les composites avant les simples, puis appliquer l'ordre de famille de
   la section 7.
4. Retenir les quatre premieres.
5. Ne pas completer la liste : de zero a quatre cles sont valides.

Etats UI :
- aucune source exploitable : Contexte indisponible pour ce snapshot;
- sources exploitables mais aucune candidate remarquable : Peu d'elements
  differenciants ressortent avant cette rencontre;
- une a quatre candidates : afficher uniquement les cartes retenues.

## 9. Wireframes et champs exacts

### Hierarchie

~~~text
┌ Positionnement officiel ──────────────┐
│ <home team>              <away team>  │
│ #<home rank>             #<away rank> │
│ <home points> pts        <away points> pts│
│        <points gap> pts              │
│ <home played> J          <away played> J│
└───────────────────────────────────────┘
~~~

Champs affiches : match.homeTeam.name, match.awayTeam.name, homeStanding.rank,
awayStanding.rank, homeStanding.points, awayStanding.points,
homeStanding.played, awayStanding.played. La selection utilise la reference
relative PPG/points de leagueStandings; elle n'est pas obligee d'etre affichee.

### Structure

~~~text
┌ Structure du championnat ─────────────┐
│ <home team>  [<home tier>]             │
│              ── ║ ║ ──                 │
│ <away team>  [<away tier>]             │
│ <boundary count> frontiere(s) confirmee(s)│
└───────────────────────────────────────┘
~~~

Champs : structuralRelation.homeTeamTier, awayTeamTier,
structuralBoundaryGap, confirmedBoundariesBetweenTeams.strength.

### Forme

~~~text
┌ Forme recente ────────────────────────┐
│ <home team>  <home W/D/L> <home pts>/15│
│ <away team>  <away W/D/L> <away pts>/15│
│              <form points gap> pts    │
└───────────────────────────────────────┘
~~~

Champs affiches : homeStanding.form et awayStanding.form. Points et gap derives
de W=3, D=1, L=0. La selection utilise les formes exploitables de
leagueStandings.

### Domicile / Exterieur

~~~text
┌ Domicile / exterieur ─────────────────┐
│ <home team> a domicile                 │
│ <home wins> V · <home draws> N · <home losses> D│
│ <away team> a l'exterieur              │
│ <away wins> V · <away draws> N · <away losses> D│
│ <home win rate> vs <away win rate>     │
└───────────────────────────────────────┘
~~~

Champs definis : homeStatistics.playedHome/winsHome/drawsHome/lossesHome,
awayStatistics.playedAway/winsAway/drawsAway/lossesAway. Cette carte ne peut
pas etre selectionnee dynamiquement en V1 avec les donnees actuelles.

### Attaque

~~~text
┌ Production offensive ─────────────────┐
│ <home team>          <away team>       │
│ <home goals for avg> <away goals for avg>│
│ buts marques / match                  │
│ <home played total> J  <away played total> J│
└───────────────────────────────────────┘
~~~

Champs : goalsFor et played des TeamStandingSnapshot des deux equipes. La
moyenne affichee est derivee de goalsFor / played; la reference utilise les
memes champs sur leagueStandings.

### Defense

~~~text
┌ Defense ──────────────────────────────┐
│ <home team>          <away team>       │
│ <home goals against> <away goals against>│
│ buts encaisses / match                │
│ <home clean sheets>   <away clean sheets>│
└───────────────────────────────────────┘
~~~

Champs de selection : goalsAgainst et played des TeamStandingSnapshot des deux
equipes et de leagueStandings. cleanSheetsTotal des TeamStatisticsSnapshot est
optionnel et descriptif uniquement.

### Opposition

~~~text
┌ Opposition ───────────────────────────┐
│ Attaque <team A>     Defense <team B>  │
│ <A goals for avg>    <B goals against avg>│
│ <A played total> J   <B played total> J│
│ Attaque <A> face a defense <B>         │
└───────────────────────────────────────┘
~~~

Champs : goalsFor / played de A, goalsAgainst / played de B et leurs matchs
joues, tous derives de leagueStandings. La carte existe seulement apres la
qualification dynamique de ses deux faits sources.

### Positionnement dans le championnat, carte composite

~~~text
┌ Positionnement dans le championnat ───┐
│ #<home rank> · <home points> pts       │
│ #<away rank> · <away points> pts       │
│ [<home tier>]  ── ║ ║ ── [<away tier>] │
│ <boundary count> frontiere(s)          │
└───────────────────────────────────────┘
~~~

Champs : tous les champs Hierarchie et Structure. Cette carte existe seulement
si la deduplication juge que les deux familles racontent la meme separation.

## 10. Compositions de reference

### Match A - separation de championnat

~~~text
CLES DU MATCH

[ Positionnement dans le championnat ]
#<home rank> · <home points> pts | #<away rank> · <away points> pts
<boundary count> frontiere(s) entre <home tier> et <away tier>

[ Forme recente ]
<home form> · <home form points>/15
<away form> · <away form points>/15

[ Defense ]
<home team> : <home goals against avg> encaisses/match
~~~

Chaque carte est retenue seulement si son fait est remarquable dans la
reference dynamique du championnat.

### Match B - standings proches, opposition differenciee

~~~text
CLES DU MATCH

[ Forme recente ]
<home form> · <home form points>/15
<away form> · <away form points>/15

[ Opposition ]
Attaque <home team> : <home goals for avg> buts/match
Defense <away team> : <away goals against avg> encaisses/match

[ Defense ]
<home team> : <home goals against avg> encaisses/match
~~~

Aucune carte Hierarchie ou Structure si leurs faits restent ordinaires dans le
classement ou si le Tier ne confirme aucune boundary.

## 11. Integration V1 et impact architectural minimal

~~~text
MatchBoardItem
  + reference ephemere du championnat
  -> MatchContextKeyBuilder
  -> MatchContextKey[]
  -> MatchIntelligence
  -> MatchDetailPage
~~~

La reference est calculee une fois par competitionId + season + standings
snapshot et reutilisee pour les matchs de cette competition dans le feed. Elle
derive uniquement PPG, forme, buts marques/match et buts encaisses/match depuis
leagueStandings.

Il n'y a aucune persistance supplementaire, aucun nouveau moteur analytique,
aucune nouvelle table et aucun changement au Dynamic Tier. Structure continue
a consommer le ChampionshipTierSnapshot et MatchStructuralRelation existants.

## 12. Regle metier verrouillee avant implementation

La remarquabilite relative V1 est decidee : borne haute de Tukey sur les gaps
positifs, zone de bord compacte, meilleure frontiere par direction et
abstention en cas d'ex aequo distinct. Les valeurs non calculables sont
ignorees; il n'existe ni minimum legacy de taille de championnat ni plafond
artificiel de taille de zone.

Les familles utilisent ce principe commun selon leur objet : PPG pour
Hierarchie, points sur cinq resultats pour Forme, buts marques/match pour
Attaque et buts encaisses/match pour Defense. Opposition compose exclusivement
une zone offensive haute et une zone defensive adverse exposee deja
qualifiees. Structure reste exclusivement alimentee par Dynamic Tier.
