# Architecture du moteur — Decision Profile & Profile Compiler

## Principe fondamental

Le moteur ne doit jamais connaître « Q1 », « Q2 », « Q3 »…

Il ne doit même pas savoir qu’un onboarding existe.

Les réponses de l’onboarding doivent être transformées en un **profil métier**, et le moteur travaille uniquement avec ce profil.

C’est précisément ce principe qui permet d’ajouter, supprimer, reformuler ou réorganiser des questions plus tard sans casser le moteur.

L’architecture cible est donc :

```text
ONBOARDING
   ↓
Réponses utilisateur
   ↓
PROFILE COMPILER
   ↓
Profil décisionnel normalisé
   ↓
MOTEUR
   ↓
Classement / marchés / tickets / explications
```

Le **Profile Compiler** est la pièce centrale qui découple l’onboarding du moteur.

---

# 1. Une sélection supprimée n’est pas une donnée perdue

Pour Q1 à Q7, une option supprimée par l’utilisateur ne doit jamais être physiquement supprimée de la base.

Exemple avec Q1 :

```text
Premier League
selected = true
priority = 1

Ligue 1
selected = true
priority = 2

Serie A
selected = false
priority = null

Bundesliga
selected = true
priority = 3
```

La Serie A existe toujours dans le catalogue.

Elle est simplement **désactivée pour cet utilisateur**.

L’interface peut donc immédiatement proposer :

```text
+ Ajouter Serie A
```

Et une fois réactivée :

```text
selected = true
priority = 4
```

L’utilisateur peut ensuite la déplacer où il le souhaite.

Cette approche est beaucoup plus robuste qu’une suppression réelle des données.

---

# 2. Chaque réponse sélectionnable doit avoir trois notions

Pour Q1 à Q7, les choix doivent être représentés de manière cohérente avec au minimum :

```text
option_id
enabled
priority
```

Éventuellement, le profil compilé pourra aussi contenir :

```text
weight
```

Mais ce poids ne doit pas être saisi directement par l’utilisateur.

Il doit être calculé par le **Profile Compiler**.

Exemple de mapping possible :

```text
Priorité 1 → poids 1.00
Priorité 2 → poids 0.80
Priorité 3 → poids 0.60
Priorité 4 → poids 0.40
```

Ce barème pourra évoluer plus tard sans modifier les réponses enregistrées.

---

# 3. Toutes les questions ne doivent pas agir de la même manière

Le moteur ne doit surtout pas additionner naïvement toutes les réponses dans un score unique.

Les réponses de l’onboarding doivent être classées en plusieurs catégories métier.

| Type | Questions | Effet |
|---|---|---|
| **Filtres d’éligibilité** | Q1, Q2, Q8 | Détermine ce qui peut être proposé |
| **Pondération du moteur** | Q4, Q5, Q13 | Influence le classement |
| **Préférences d’information** | Q3, Q9 | Influence surtout la présentation |
| **Construction des tickets** | Q6, Q7 | Contraintes / préférences de génération |
| **Profil comportemental** | Q10, Q11, Q12 | Personnalisation et futur coaching |

Chaque question doit donc produire un effet adapté à sa nature.

---

# 4. Q1 — Compétitions

Q1 fonctionne presque comme un **hard filter**.

Si l’utilisateur enlève :

```text
Serie A
```

alors :

```text
personalized_feed(Serie A) = false
```

Aucun match de Serie A ne doit apparaître dans son accueil personnalisé.

Il faut toutefois distinguer l’accueil personnalisé de l’accès global aux rencontres.

```text
Accueil personnalisé
→ uniquement compétitions activées

"Voir toutes les rencontres"
→ toutes les compétitions disponibles
```

Ainsi, l’utilisateur ne voit jamais spontanément la Serie A, mais il peut volontairement aller la consulter.

---

# 5. Q2 — Marchés

Même logique que pour les compétitions.

Si l’utilisateur sélectionne uniquement :

```text
Victoire
Double Chance
Équipe marque
```

le moteur peut continuer à calculer tous les autres signaux en arrière-plan, mais il ne doit jamais lui recommander :

```text
BTTS
Over 2.5
Corners
```

Le pipeline devient :

```text
available signals
        ↓
user enabled markets
        ↓
eligible recommendations
```

Les métriques universelles ne doivent jamais cesser d’être calculées pour les marchés désactivés, car elles peuvent être utiles à d’autres marchés ou futures règles.

---

# 6. Q3 et Q4 ne doivent pas avoir le même rôle

Cette distinction est essentielle.

## Q3 — Ce que l’utilisateur regarde

Question :

> Quels éléments regardez-vous en priorité ?

Cela signifie :

**ce que l’utilisateur veut voir.**

Q3 doit principalement influencer :

- l’ordre des arguments ;
- les statistiques montrées ;
- les informations développées par défaut ;
- la profondeur de lecture de certaines données.

Exemple :

```text
Q3

1. Classement
2. Forme
3. H2H
4. Blessures
```

## Q4 — Ce qui influence réellement la décision

Question :

> Qu’est-ce qui influence réellement votre décision finale ?

Cela signifie :

**ce qui doit peser dans le moteur.**

Q4 influence directement les pondérations.

Exemple :

```text
Q4

1. Forme
2. Avantage domicile
3. Classement
```

Copilot peut donc comprendre :

> L’utilisateur aime regarder les H2H, mais ils ne gouvernent pas vraiment sa décision finale.

Cette nuance est particulièrement importante pour la personnalisation.

---

# 7. Q5 — Types de rencontres

Q5 devient une préférence portant sur les **signaux** produits par le moteur.

Exemple :

```text
Favori solide       1.00
Gros écart niveau   0.80
Match offensif      0.60
Match équilibré     disabled
```

Lorsque le moteur produit ses signaux :

```text
match_signals
```

le profil utilisateur donne davantage de valeur aux signaux correspondant aux types de rencontres prioritaires.

---

# 8. Q6 — Nombre de sélections

Q6 ne doit jamais intervenir dans le classement des rencontres.

Il agit uniquement **après** le ranking.

```text
Ranking
   ↓
Matches retenus
   ↓
Ticket Builder
   ↓
Q6
```

Exemple :

```text
2 sélections → priorité 1
3 sélections → priorité 2
4 sélections → disabled
5 sélections → disabled
```

Le moteur sait alors que, lorsqu’il doit proposer un ticket :

```text
préféré = 2
alternative = 3
```

---

# 9. Q7 — Plages de cote totale

Q7 appartient également au **Ticket Builder**, pas au moteur de classement.

Exemple :

```text
2.00 – 4.00       priority 1
1.20 – 2.00       priority 2
4.00 – 8.00       priority 3
8.00 – 15.00      disabled
15.00+            disabled
```

Le générateur tente alors de composer en priorité un ticket compatible avec la première plage.

---

# 10. Q8 — Seuil de cote par marché

Q8 intervient avant qu’un marché devienne éligible.

Exemple :

```text
Double chance

score moteur = excellent
cote = 1.18

seuil utilisateur = 1.30

→ marché non proposé
```

Attention :

cela ne signifie pas :

> mauvais pari

Cela signifie uniquement :

> incompatible avec la méthode déclarée de cet utilisateur

Cette distinction est centrale dans le produit.

---

# 11. Q9 à Q13

Ces questions ne doivent pas toutes alimenter une grande formule de scoring.

Certaines sont du **contexte utilisateur**.

## Q9 — Temps d’analyse

Cette donnée peut déterminer la profondeur de l’interface.

Exemple :

```text
< 10 minutes
→ arguments très synthétiques

> 1 heure
→ davantage de preuves et statistiques accessibles
```

Q9 influence donc surtout la présentation et la profondeur d’information.

## Q10 — Fréquence de pari

Pour la V1, cette donnée peut être stockée comme :

```text
behavioral metadata
```

Elle sera surtout utile plus tard au coach IA.

Elle n’a pas besoin d’intervenir dans le classement des matchs.

## Q11 — Quantité de matchs à mettre en avant

Q11 peut être directement exploitable pour l’accueil personnalisé.

Exemple de mapping à définir :

```text
1 → top 5
2 → top 8
3 → top 10
4 → top 15
5 → top 20 / davantage
```

Ces valeurs restent un mapping métier modifiable.

Q11 ne limite pas les rencontres disponibles dans l’application.

Elle détermine uniquement combien de matchs sont mis en avant.

## Q12 — Approches de pari

Q12 doit servir à construire un **profil stratégique**.

Exemple :

```text
Éliminer les risques
Rechercher favoris solides
Exploiter domicile / extérieur
```

Le Profile Compiler peut traduire cela en ajustements cohérents sur des dimensions métier existantes.

Il ne faut pas convertir mécaniquement chaque choix en un simple « +17 points » dans le ranking.

## Q13 — Importance des cotes

Q13 peut être compilée sous une forme normalisée.

Exemple :

```text
odds_importance = 0.25
```

ou :

```text
odds_importance = 0.75
```

Le moteur n’a jamais besoin de savoir que cette valeur provenait de « Q13 ».

Il reçoit simplement une propriété métier.

---

# 12. Exemple de profil décisionnel normalisé

Le moteur doit recevoir un contrat stable de ce type :

```yaml
profile_version: 1

competitions:
  premier_league:
    enabled: true
    weight: 1.00

  ligue_1:
    enabled: true
    weight: 0.80

  serie_a:
    enabled: false

markets:
  home_win:
    enabled: true
    weight: 1.00
    min_odds: 1.30

  double_chance:
    enabled: true
    weight: 0.80
    min_odds: 1.30

analysis_criteria:
  recent_form:
    weight: 1.00

  standings:
    weight: 0.80

  home_away:
    weight: 0.60

match_types:
  strong_favorite:
    weight: 1.00

  offensive_match:
    weight: 0.40

  balanced_match:
    enabled: false

ticket_preferences:
  sizes:
    2: 1.00
    3: 0.80

  odds_ranges:
    "2-4": 1.00
    "1.2-2": 0.80

presentation:
  information_priority:
    standings: 1
    recent_form: 2
    injuries: 3

  feed_depth: 10

behavior:
  analysis_duration: 30_60
  betting_frequency: two_three_days

odds_importance: 0.60
```

Ce profil est le **contrat du moteur**.

L’onboarding peut changer.

Le moteur ne doit pas changer tant que le contrat du profil reste compatible.

---

# 13. Évolutivité de l’onboarding

Supposons qu’en V2 une nouvelle question soit ajoutée :

> Q14 — Quelle importance accordez-vous aux absences de joueurs ?

Le moteur ne doit pas être modifié parce qu’une Q14 existe.

On ajoute simplement une question possédant un identifiant sémantique, par exemple :

```text
question = player_absence_importance
```

Puis le Profile Compiler traduit la réponse en :

```text
analysis_criteria.player_absences.weight
```

Si le moteur connaît déjà :

```text
player_absences
```

aucune autre modification n’est nécessaire.

## Suppression d’une question

Si Q13 disparaît dans une future version, le moteur ne doit pas perdre :

```text
odds_importance
```

Le Profile Compiler peut lui attribuer une valeur par défaut.

## Modification du wording

Si le texte de Q5 change entièrement, aucun problème.

Tant que son identifiant sémantique reste :

```text
preferred_match_types
```

le moteur reste inchangé.

Le moteur travaille sur des concepts métier, jamais sur des numéros de questions ou des libellés UI.

---

# 14. Trois versionnements distincts

Trois éléments doivent être versionnés indépendamment :

```text
onboarding_version
profile_schema_version
engine_version
```

## Onboarding version

Répond à la question :

> Quelles questions avons-nous posées ?

## Profile schema version

Répond à la question :

> Sous quelle forme avons-nous représenté la manière de décider de cet utilisateur ?

## Engine version

Répond à la question :

> Avec quelles règles avons-nous analysé les matchs ?

Ces trois concepts sont différents et ne doivent jamais être confondus.

Le profil compilé est la couche intermédiaire entre l’onboarding et le moteur.

---

# 15. Pipeline final du moteur

L’architecture complète devient :

```text
              DONNÉES SPORTIVES
                     │
                     ▼
              Métriques universelles
                     │
                     ▼
                 Signaux
                     │
                     │
ONBOARDING            │
    │                 │
    ▼                 │
Réponses              │
    │                 │
    ▼                 │
PROFILE COMPILER      │
    │                 │
    ▼                 ▼
PROFIL ───────────► PERSONNALISATION
                     │
                     ▼
             Marchés éligibles
                     │
                     ▼
              Score compatibilité
                     │
                     ▼
               Classement
                     │
              ┌──────┴───────┐
              ▼              ▼
         Accueil         Ticket Builder
                             │
                       Q6 + Q7 + Q8
```

Le moteur conserve ainsi une séparation stricte entre :

- les données sportives universelles ;
- les métriques ;
- les signaux ;
- le profil décisionnel ;
- la personnalisation ;
- l’éligibilité des marchés ;
- le ranking ;
- le Ticket Builder.

---

# 16. Principe de calcul

Le moteur fonctionne en deux grandes phases.

## Phase 1 — Calcul universel

Calculé une seule fois pour tous les utilisateurs :

```text
statistiques
↓
métriques
↓
signaux
```

## Phase 2 — Calcul personnalisé

Calculé selon le profil décisionnel :

```text
profil
↓
filtres d’éligibilité
↓
pondérations
↓
score de compatibilité
↓
classement
↓
présentation
↓
Ticket Builder
```

Le moteur ne doit jamais recalculer inutilement les mêmes données sportives pour chaque utilisateur.

---

# 17. Rôle exact du Profile Compiler

Le **Profile Compiler** est responsable de :

- lire les réponses d’onboarding ;
- interpréter les options activées ou désactivées ;
- convertir les priorités en poids ;
- appliquer les valeurs par défaut ;
- produire les seuils utilisateurs ;
- construire les préférences de présentation ;
- construire les préférences de tickets ;
- construire les métadonnées comportementales ;
- valider la cohérence du profil ;
- produire un profil conforme à une version précise de `profile_schema_version`.

Il n’est pas responsable de :

- calculer les statistiques sportives ;
- analyser les matchs ;
- produire les signaux ;
- classer les rencontres ;
- recommander un marché ;
- générer les tickets ;
- appeler une IA.

---

# 18. Rôle exact du moteur

Le moteur reçoit :

- les données normalisées ;
- les métriques universelles ;
- les signaux ;
- un profil décisionnel compilé.

Le moteur applique ensuite :

- les filtres d’éligibilité ;
- les pondérations ;
- les préférences utilisateur ;
- les règles métier ;
- le ranking ;
- les règles de recommandation.

Le moteur doit rester :

- déterministe ;
- reproductible ;
- explicable ;
- indépendant de Flutter ;
- indépendant de l’onboarding ;
- indépendant de l’IA.

---

# 19. Conséquence pour le développement

La prochaine étape ne doit pas être de coder immédiatement les règles football.

La priorité doit être :

1. définir le schéma du **Decision Profile** ;
2. définir `profile_schema_version` ;
3. implémenter le **Profile Compiler** ;
4. définir les valeurs par défaut ;
5. implémenter la gestion `enabled / disabled / priority` ;
6. rendre le profil recompilable après chaque modification de l’utilisateur ;
7. écrire les tests du compilateur ;
8. seulement ensuite commencer le moteur métier football.

Cette couche est ce qui permettra à l’onboarding et au moteur d’évoluer indépendamment pendant plusieurs années.

---

# 20. Règle d’or

> **Le moteur ne connaît jamais les questions de l’onboarding. Il connaît uniquement un profil décisionnel métier, normalisé, versionné et stable.**

C’est cette règle qui garantit l’évolutivité du produit.
