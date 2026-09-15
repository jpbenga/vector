# Catalogue V2 des lectures et scénarios pré-match

Statut : contrat produit préparatoire au développement
Périmètre : pré-match uniquement
Hors périmètre : collecte live, lectures live, alertes live et interface live

Le contrat détaillé des dix scénarios existants est défini dans
[`lector_scenario_contract_v2.md`](lector_scenario_contract_v2.md).

## 1. Règle de modélisation

Le catalogue distingue quatre responsabilités :

```text
Donnée brute API
    ↓
Indicateur interne calculé
    ↓
Lecture autonome éventuellement proposée à l'utilisateur
    ↓
Scénario validé par la présence de toutes ses lectures obligatoires
```

Une donnée ou un indicateur ne devient pas automatiquement une lecture.

Une lecture publique doit :

- être compréhensible et utile de façon autonome ;
- décrire un fait précis, sans formulation vague ;
- être vérifiable par une preuve affichable ;
- être remarquable relativement au championnat ;
- pouvoir être reliée à un classement contextuel ou à un marché cohérent ;
- ne pas dupliquer une autre lecture ;
- être effectivement calculée par le moteur avant d'être sélectionnable.

Un scénario est une conjonction stricte :

```text
scenario.requiredReadings.every(reading => reading est détectée)
```

Une lecture obligatoire absente invalide le scénario. Une autre lecture ne
peut jamais la remplacer. Les thèses décrivent le résultat d'un scénario ;
elles ne sont plus des alternatives servant à le valider.

## 2. Principes statistiques et temporels

- Aucune qualification ne repose sur un seuil absolu arbitraire.
- La remarquabilité est déterminée relativement au championnat.
- La maturité `EARLY` ou `ESTABLISHED` module la prudence, jamais l'existence
  d'une lecture calculable.
- Toute preuve pré-match doit avoir un `asOf` antérieur au coup d'envoi.
- Un classement n'est publié que si sa couverture est suffisante pour
  comparer les équipes du championnat.
- Une lecture indisponible dans une compétition n'est pas présentée comme une
  préférence active.

## 3. Capacités de données confirmées

| Source | Données disponibles | Usage pré-match | État actuel dans l'application |
|---|---|---|---|
| `/standings` | général, domicile, extérieur, forme, buts, points | classements Général, Domicile, Extérieur, Forme | `all` normalisé ; `home` et `away` présents dans le brut mais perdus |
| `/fixtures?league&season` | score final, score à la pause, date, journée, équipes | phases aller/retour, mi-temps, BTTS, Over/Under, clean sheets | la fenêtre de fixtures est conservée ; l'historique complet de ligue ne l'est pas |
| `/teams/statistics` | splits home/away, clean sheets, échecs à marquer, buts par tranches | lectures équipe et temporalité des buts | couverture limitée aux équipes de la fenêtre de matchs ; plusieurs champs sont perdus |
| `/fixtures/statistics` | tirs, tirs cadrés, corners, cartons, possession, passes, xG, arrêts | agrégats historiques et lectures de performance | utilisé surtout pour les xG récents ; historique de ligue incomplet |
| `/players` | minutes, titularisations, buts, passes, tirs | lectures joueurs de saison | collecté par équipe de la fenêtre, pas pour toute la ligue |
| `/fixtures/events` | minute, équipe, joueur, type et détail | temporalité précise des événements passés | non intégré au snapshot applicatif |
| `/fixtures/lineups` et `/injuries` | compositions, formation, absences | contexte proche du coup d'envoi | non intégré au snapshot applicatif |

Le score à la pause est directement fourni par
`score.halftime.home/away`. Le score de seconde période est dérivable par
`fulltime - halftime` pour les matchs sans prolongation.

## 4. Typologie du catalogue

### 4.1 Vues de classement, sans lecture publique automatique

Ces données doivent être consultables, mais leur simple existence ne constitue
pas une lecture :

| Vue | Rôle |
|---|---|
| Général | position, points, Tiers et enjeux officiels |
| Domicile | performance des équipes à domicile |
| Extérieur | performance des équipes à l'extérieur |
| Forme | performance sur la fenêtre récente disponible |
| Phase aller | classement recalculé sur la première phase |
| Phase retour | classement recalculé sur la seconde phase |
| Première mi-temps | classement établi avec les scores à la pause |
| Seconde mi-temps | classement établi avec les seuls buts de seconde période |

`Première partie de saison positive` n'est donc pas une lecture publique.
Les performances aller/retour sont des indicateurs de classement. Elles ne
deviennent une lecture que lorsqu'une évolution remarquable et explicable est
observée.

### 4.2 Indicateurs internes non sélectionnables isolément

| Indicateur | Motif |
|---|---|
| Points par match en phase aller | valeur de comparaison, pas une conclusion autonome |
| Points par match en phase retour | valeur de comparaison, pas une conclusion autonome |
| Écart aller/retour | preuve d'une trajectoire, pas son interprétation complète |
| Possession moyenne | ne prouve ni danger ni domination utile |
| Précision de passe | peu exploitable seule pour une décision utilisateur |
| Volume de fautes | doit être contextualisé avec les cartons et l'adversaire |
| Répartition brute des buts par tranche | devient publique seulement si une tranche est remarquable |
| Formation la plus fréquente | information contextuelle, pas une lecture de match isolée |
| Nombre brut de titularisations | preuve possible d'un rôle joueur, pas une lecture |

## 5. Lectures existantes à conserver comme contrat public

Ces lectures ont une valeur autonome. Leur exposition dans les préférences
reste conditionnée à une production réelle par le moteur.

| Famille | Lectures |
|---|---|
| Structure | `structural_level_gap` |
| Forme | `positive_streak`, `negative_streak`, `improving_form`, `declining_form` |
| Domicile/extérieur | `strong_home_team`, `weak_home_team`, `strong_away_team`, `weak_away_team`, `home_away_mismatch` |
| Attaque | `prolific_attack`, `scoring_difficulty` |
| Défense | `solid_defense`, `fragile_defense`, `frequent_clean_sheet` |
| Profil de buts | `open_match_profile`, `frequent_over_25`, `frequent_btts`, `closed_match_profile`, `frequent_under_25` |
| xG | `high_xg_creation`, `low_xg_creation`, `high_xg_conceded`, `offensive_underperformance`, `offensive_overperformance`, `defensive_underperformance`, `defensive_overperformance` |
| Joueur | `standout_goal_scorer` |
| Prudence | `misleading_result` |

`improving_form` et `declining_form` devront être fondées sur deux fenêtres
chronologiques explicites. Une simple interprétation ambiguë de la chaîne
`standings.form` n'est pas suffisante.

## 6. Nouvelles lectures publiques candidates

Les IDs ci-dessous sont des contrats candidats. Ils ne doivent être ajoutés à
la configuration utilisateur qu'au moment où leur producteur, leur preuve et
leur couverture sont opérationnels.

### 6.1 Première et seconde mi-temps

| ID candidat | Libellé utilisateur précis | Preuve principale | Classement associé |
|---|---|---|---|
| `strong_first_half_team` | Solide en première mi-temps | position et points dans le classement des premières mi-temps | Première mi-temps |
| `weak_first_half_team` | Fragile en première mi-temps | position et points dans le classement des premières mi-temps | Première mi-temps |
| `strong_second_half_team` | Solide en seconde mi-temps | position et points dans le classement des secondes mi-temps | Seconde mi-temps |
| `weak_second_half_team` | Fragile en seconde mi-temps | position et points dans le classement des secondes mi-temps | Seconde mi-temps |
| `frequent_halftime_lead` | Souvent devant à la pause | taux de matchs menés à la pause, relatif à la ligue | Première mi-temps |
| `frequent_halftime_draw` | Souvent à égalité à la pause | taux de nuls à la pause, relatif à la ligue | Première mi-temps |
| `strong_lead_retention` | Conserve souvent son avantage | matchs gagnés après avoir mené à la pause | Première mi-temps puis Général |
| `weak_lead_retention` | Perd souvent son avantage | points perdus après avoir mené à la pause | Première mi-temps puis Général |
| `second_half_recovery` | Réagit souvent après la pause | amélioration du résultat entre la pause et la fin | Seconde mi-temps |

### 6.2 Temporalité explicite des buts

Une lecture temporelle doit toujours afficher la tranche concernée. Le libellé
générique `démarre fort` est interdit sans précision.

| ID candidat | Libellé utilisateur | Preuve principale | Classement associé |
|---|---|---|---|
| `early_scoring_0_15` | Marque fréquemment entre 0 et 15 minutes | part et fréquence des buts 0–15 relatives à la ligue | Buts 0–15 |
| `early_conceding_0_15` | Concède fréquemment entre 0 et 15 minutes | part et fréquence des buts encaissés 0–15 | Buts encaissés 0–15 |
| `pre_halftime_scoring_31_45` | Dangereuse avant la pause, entre 31 et 45 minutes | buts 31–45 relatifs à la ligue | Buts 31–45 |
| `pre_halftime_conceding_31_45` | Vulnérable avant la pause, entre 31 et 45 minutes | buts encaissés 31–45 | Buts encaissés 31–45 |
| `late_scoring_76_90` | Marque fréquemment entre 76 et 90 minutes | buts 76–90 relatifs à la ligue | Buts 76–90 |
| `late_conceding_76_90` | Concède fréquemment entre 76 et 90 minutes | buts encaissés 76–90 | Buts encaissés 76–90 |

Les tranches 16–30, 46–60 et 61–75 restent des indicateurs calculables. Elles
ne deviennent des entrées publiques que si les données réelles montrent une
valeur produit distincte et non redondante.

### 6.3 Tirs et efficacité

| ID candidat | Libellé utilisateur | Preuve principale | Classement associé |
|---|---|---|---|
| `high_shot_volume` | Volume de tirs élevé | tirs par match relatifs à la ligue | Tirs |
| `low_shot_volume` | Faible volume de tirs | tirs par match relatifs à la ligue | Tirs |
| `high_shots_on_target` | Nombreux tirs cadrés | tirs cadrés par match | Tirs cadrés |
| `low_shot_accuracy` | Difficulté à cadrer | ratio tirs cadrés/tirs | Précision des tirs |
| `high_shots_conceded` | Concède beaucoup de tirs | tirs adverses par match | Tirs concédés |
| `high_shots_on_target_conceded` | Concède beaucoup de tirs cadrés | tirs cadrés adverses par match | Tirs cadrés concédés |

La conversion tirs/buts et les écarts buts/xG doivent être examinés ensemble
pour éviter de dupliquer les lectures xG de surperformance.

### 6.4 Corners

| ID candidat | Libellé utilisateur | Preuve principale | Classement associé |
|---|---|---|---|
| `high_corner_creation` | Obtient beaucoup de corners | corners obtenus par match | Corners obtenus |
| `high_corners_conceded` | Concède beaucoup de corners | corners adverses par match | Corners concédés |
| `high_total_corners_profile` | Matchs riches en corners | total de corners dans les matchs de l'équipe | Total corners |
| `low_total_corners_profile` | Matchs pauvres en corners | total de corners dans les matchs de l'équipe | Total corners |

### 6.5 Cartons et discipline

| ID candidat | Libellé utilisateur | Preuve principale | Classement associé |
|---|---|---|---|
| `high_card_rate` | Reçoit beaucoup de cartons | cartons reçus par match | Cartons reçus |
| `low_card_rate` | Équipe disciplinée | cartons reçus par match | Cartons reçus |
| `high_total_cards_profile` | Matchs riches en cartons | total de cartons dans les matchs de l'équipe | Total cartons |
| `second_half_cards_profile` | Cartons surtout après la pause | part des cartons reçus après la pause | Cartons par période |

### 6.6 Joueurs et disponibilité proche du match

| ID candidat | Libellé utilisateur | Preuve principale | Vue associée |
|---|---|---|---|
| `high_volume_shooter` | Joueur à fort volume de tirs | tirs et minutes du joueur relatifs aux joueurs de la ligue | Joueurs — tirs |
| `accurate_shooter` | Joueur qui cadre fréquemment | tirs cadrés par 90 minutes | Joueurs — tirs cadrés |
| `standout_creator` | Créateur qui se distingue | passes décisives et occasions créées disponibles | Joueurs — création |
| `identified_penalty_taker` | Tireur de penalty identifié | penalties tentés et marqués, avec minutes jouées | Joueurs — penalties |
| `key_player_unavailable` | Absence d'un joueur important | absence factuelle + rôle objectivé par minutes et contributions | Contexte effectif |

`key_player_unavailable` ne peut être calculée qu'après publication fiable de
l'absence. Elle reste une lecture pré-match tardive, jamais une supposition.

## 7. Concepts qui ne deviennent pas des lectures autonomes

| Concept écarté comme lecture isolée | Destination correcte |
|---|---|
| Première partie de saison positive | classement Phase aller ou preuve d'une trajectoire |
| Deuxième partie de saison positive | classement Phase retour ou preuve d'une trajectoire |
| Possession élevée | indicateur interne ou composant d'un scénario de contrôle |
| Précision de passe élevée | indicateur interne |
| Nombre de fautes élevé | indicateur interne d'un scénario disciplinaire |
| Formation habituelle | contexte d'équipe |
| Changement de formation | contexte proche du match, tant qu'un impact objectif n'est pas établi |
| Historique H2H favorable | contexte secondaire, pas lecture forte autonome |

## 8. Scénarios candidats stricts rendus possibles par les nouvelles lectures

Chaque ligne est une conjonction. Aucun composant n'est optionnel et aucune
lecture de remplacement n'est implicite.

### `first_half_advantage`

Libellé : Avantage attendu en première mi-temps

```text
strong_first_half_team(sujet)
ET
weak_first_half_team(adversaire)
ET
frequent_halftime_lead(sujet)
```

### `early_goal_pressure`

Libellé : Pression pour un but précoce

```text
early_scoring_0_15(sujet)
ET
early_conceding_0_15(adversaire)
ET
high_shots_on_target(sujet)
```

### `second_half_swing`

Libellé : Bascule attendue après la pause

```text
strong_second_half_team(sujet)
ET
weak_second_half_team(adversaire)
ET
second_half_recovery(sujet)
```

### `late_goal_pressure`

Libellé : Pression pour un but tardif

```text
late_scoring_76_90(sujet)
ET
late_conceding_76_90(adversaire)
ET
strong_second_half_team(sujet)
```

### `corner_pressure`

Libellé : Pression favorable aux corners

```text
high_corner_creation(sujet)
ET
high_corners_conceded(adversaire)
ET
high_shot_volume(sujet)
```

### `disciplinary_tension`

Libellé : Rencontre sous tension disciplinaire

```text
high_card_rate(équipe A)
ET
high_card_rate(équipe B)
ET
high_total_cards_profile(match)
```

### `standout_scorer_exposure`

Libellé : Buteur particulièrement exposé

```text
standout_goal_scorer(joueur du sujet)
ET
high_volume_shooter(même joueur)
ET
high_shots_on_target_conceded(adversaire)
```

## 9. Relation avec les classements personnalisés

Pour un match ouvert depuis `Pour moi` :

1. afficher Général ;
2. ajouter les classements des lectures directement sélectionnées et détectées ;
3. ajouter les classements de toutes les lectures constitutives des scénarios
   sélectionnés et validés ;
4. dédupliquer les vues ;
5. compléter avec les vues standards disponibles.

Une lecture ou un scénario ne déclenche jamais un classement dont la donnée
n'est pas couverte pour l'ensemble du championnat.

## 10. Conditions de passage à l'implémentation

Avant exposition d'une nouvelle lecture :

- producteur déterministe implémenté ;
- comparaison relative au championnat implémentée ;
- preuve et provenance disponibles ;
- maturité propagée ;
- classement associé disponible ou indisponibilité explicite ;
- tests EARLY et ESTABLISHED ;
- couverture réelle vérifiée sur plusieurs compétitions ;
- marché associé seulement si une cote correspondante existe réellement.

Le nombre final de lectures publiques est une conséquence de ces validations,
pas un objectif quantitatif.
