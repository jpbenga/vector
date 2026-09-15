# Contrat V2 des scénarios pré-match

Statut : proposition de contrat métier à valider avant branchement runtime
Périmètre : les dix scénarios actuellement proposés dans `Mes scénarios`
Hors périmètre : scénarios live et nouveaux scénarios issus des mi-temps

## 1. Invariant métier

Un scénario est une combinaison stricte de lectures.

```text
SCENARIO = lecture A ET lecture B ET lecture C
```

- Toutes les lectures obligatoires doivent être détectées.
- Elles doivent concerner le bon sujet : équipe étudiée, adversaire ou match.
- Une lecture non prévue ne remplace jamais une lecture absente.
- Plusieurs scénarios peuvent être validés pour un même match.
- Le profil utilisateur filtre les scénarios après l'analyse globale du match.
- Une préférence de marché ne crée jamais un scénario.
- Une thèse explique un scénario validé ; elle ne sert plus d'alternative de
  sélection.

## 2. Vocabulaire de sujet

| Terme | Définition |
|---|---|
| `sujet` | équipe au bénéfice ou au détriment de laquelle le scénario est formulé |
| `adversaire` | autre équipe de la rencontre |
| `home` / `away` | équipe explicitement située à domicile ou à l'extérieur |
| `match` | lecture qui caractérise la rencontre dans son ensemble |
| `les_deux_equipes` | la même lecture doit être détectée séparément pour home et away |
| `au_moins_une_equipe` | la lecture doit exister pour home ou away ; ce n'est pas une substitution d'ID |

Une contrainte de sujet n'est pas une alternative. Par exemple,
`venue_strength(sujet)` désigne une lecture unique normalisée : force de
l'équipe dans le lieu où elle joue ce match. Sa preuve provient du classement
domicile si le sujet reçoit, et du classement extérieur s'il se déplace.

## 3. Lectures structurelles nécessaires au contrat

Certaines lectures existent déjà dans l'analyse mais ne sont pas toutes
présentées comme préférences publiques. Elles restent de vraies lectures
factuelles utilisables dans un scénario.

| ID de contrat | État | Définition |
|---|---|---|
| `ranking_superiority` | produit actuellement | supériorité relative au classement du championnat |
| `ranking_inferiority` | à produire | situation inverse, portée par l'équipe moins bien classée |
| `form_advantage` | produit actuellement | avantage de forme relatif entre les deux équipes |
| `venue_strength` | à normaliser | force relative du sujet dans le lieu réel du match |
| `structural_level_gap` | produit actuellement | séparation du sujet et de l'adversaire par la structure Dynamic Tier |

Ces lectures ne doivent pas être calculées par des seuils absolus. Elles sont
issues du contexte relatif du championnat et du Dynamic Tier lorsqu'il est
concerné.

## 4. Contrat proposé pour les dix scénarios existants

### 4.1 Dominations attendues — `solid_favorite`

Sujet : équipe dominante attendue.

```text
ranking_superiority(sujet)
ET
form_advantage(sujet)
ET
structural_level_gap(sujet, adversaire)
```

Classements contextuels : Général/Tiers, Forme.
Marchés cohérents : résultat du match, double chance.
Disponibilité cible : possible avec le socle actuel lorsque le Dynamic Tier est
mature.

Ce contrat reprend exactement l'exemple métier validé : classement, état de
forme et écart entre les deux équipes. L'attaque ou la défense ne peuvent pas
remplacer l'un de ces trois éléments.

### 4.2 Équipes en difficulté — `struggling_team`

Sujet : équipe en difficulté.

```text
negative_streak(sujet)
ET
scoring_difficulty(sujet)
ET
fragile_defense(sujet)
```

Classements contextuels : Forme, Attaque, Défense.
Marchés cohérents : résultat ou double chance en faveur de l'adversaire.
Disponibilité cible : possible avec le socle actuel.

La faiblesse domicile/extérieur peut constituer une preuve supplémentaire,
mais ne valide pas le scénario et ne remplace aucun des trois composants.

### 4.3 Matchs ouverts — `offensive_match`

Sujet : match.

```text
open_match_profile(match)
ET
prolific_attack(home)
ET
prolific_attack(away)
ET
fragile_defense(au_moins_une_equipe)
```

Classements contextuels : Attaque des deux équipes, Défense, Rythme, Over/BTTS.
Marchés cohérents : Over buts, BTTS.
Disponibilité cible : bloquée tant que la lecture relative
`open_match_profile` n'est pas de nouveau produite.

### 4.4 Matchs fermés — `defensive_match`

Sujet : match.

```text
closed_match_profile(match)
ET
solid_defense(les_deux_equipes)
ET
scoring_difficulty(les_deux_equipes)
```

Classements contextuels : Défense des deux équipes, Attaque, Rythme, Under.
Marché cohérent : Under buts.
Disponibilité cible : bloquée tant que la lecture relative
`closed_match_profile` n'est pas de nouveau produite.

### 4.5 Écarts de niveau — `ranking_gap`

Sujet : équipe supérieure.

```text
ranking_superiority(sujet)
ET
structural_level_gap(sujet, adversaire)
```

Classement contextuel : Général/Tiers.
Marchés cohérents : résultat du match et double chance en faveur du sujet,
uniquement lorsque les sélections et cotes existent réellement.
Disponibilité cible : possible avec le socle actuel lorsque le Dynamic Tier est
mature.

Une attaque prolifique contre une défense fragile ne constitue pas, à elle
seule, un écart de niveau structurel.

### 4.6 Outsiders crédibles — `credible_outsider`

Sujet : équipe sportivement inférieure au classement mais crédible dans le
contexte du match.

```text
ranking_inferiority(sujet)
ET
positive_streak(sujet)
ET
form_advantage(sujet)
ET
venue_strength(sujet)
ET
fragile_defense(adversaire)
```

Classements contextuels : Général/Tiers, Forme, Domicile ou Extérieur, Défense
adverse.
Marchés cohérents : double chance puis résultat, si les cotes existent.
Disponibilité cible : bloquée jusqu'à la production de `ranking_inferiority`
et la normalisation de `venue_strength`.

La cote peut confirmer le statut commercial d'outsider, mais elle ne remplace
aucune lecture sportive obligatoire.

### 4.7 Défenses fragiles — `fragile_defense`

Sujet : équipe défensivement fragile.

```text
fragile_defense(sujet)
ET
high_xg_conceded(sujet)
ET
high_shots_on_target_conceded(sujet)
```

Classements contextuels : Défense, xG concédés, Tirs cadrés concédés.
Marchés cohérents : marchés de buts dirigés vers l'adversaire, seulement dans
le cadre d'un scénario offensif complet.
Disponibilité cible : bloquée jusqu'à la couverture championnat des xG et des
tirs cadrés concédés.

### 4.8 Attaques prolifiques — `prolific_attack`

Sujet : équipe offensivement productive.

```text
prolific_attack(sujet)
ET
high_xg_creation(sujet)
ET
high_shots_on_target(sujet)
```

Classements contextuels : Attaque, xG créés, Tirs cadrés.
Marchés cohérents : buts de l'équipe, résultat seulement avec un scénario de
supériorité complet.
Disponibilité cible : bloquée jusqu'à la couverture championnat des xG et des
tirs cadrés.

### 4.9 Séries positives — `positive_series`

Sujet : équipe en dynamique positive confirmée.

```text
positive_streak(sujet)
ET
improving_form(sujet)
ET
high_xg_creation(sujet)
```

Classements contextuels : Forme, trajectoire récente, xG créés.
Marchés cohérents : aucun marché de résultat automatique sans scénario de
supériorité complémentaire.
Disponibilité cible : bloquée jusqu'à la production chronologique fiable de
`improving_form` et à la couverture championnat des xG.

Une domination attendue ne valide plus automatiquement une série positive.

### 4.10 Séries négatives — `negative_series`

Sujet : équipe en dynamique négative confirmée.

```text
negative_streak(sujet)
ET
declining_form(sujet)
ET
low_xg_creation(sujet)
```

Classements contextuels : Forme, trajectoire récente, xG créés.
Marchés cohérents : aucun marché dirigé automatiquement sans scénario complet
porté par l'adversaire.
Disponibilité cible : bloquée jusqu'à la production chronologique fiable de
`declining_form` et à la couverture championnat des xG.

Une défense fragile ou une difficulté offensive ne valide plus, à elle seule,
une série négative.

## 5. Disponibilité résultante

| Scénario | Peut être rendu strict avec les lectures actuelles | Dépendance restante |
|---|---:|---|
| Dominations attendues | oui | Dynamic Tier mature et trois lectures présentes |
| Équipes en difficulté | oui | trois lectures présentes pour le même sujet |
| Matchs ouverts | non | profil de rythme relatif championnat |
| Matchs fermés | non | profil de rythme relatif championnat |
| Écarts de niveau | oui | Dynamic Tier mature |
| Outsiders crédibles | non | infériorité et force contextuelle normalisées |
| Défenses fragiles | non | xG et tirs cadrés concédés de toute la ligue |
| Attaques prolifiques | non | xG et tirs cadrés de toute la ligue |
| Séries positives | non | trajectoire chronologique et xG de toute la ligue |
| Séries négatives | non | trajectoire chronologique et xG de toute la ligue |

Un scénario non calculable ne doit pas produire de faux résultat. Avant son
activation dans les préférences, l'interface devra soit le masquer, soit
indiquer explicitement que ses données ne sont pas encore disponibles.

## 6. Conséquences pour le prochain changement de code

Le branchement runtime devra :

1. remplacer `OpportunityProfileDefinition.thesisIds` par une définition de
   lectures obligatoires orientées par sujet ;
2. évaluer tous les scénarios à partir de la `MatchIntelligence` globale ;
3. conserver toutes les correspondances de scénarios d'un match ;
4. appliquer ensuite les préférences utilisateur ;
5. générer les thèses et marchés à partir des scénarios validés ;
6. empêcher une lecture individuelle ou un marché de créer un scénario ;
7. ajouter des tests négatifs retirant chaque lecture obligatoire à tour de
   rôle.

Ce contrat ne contient aucune logique live.
