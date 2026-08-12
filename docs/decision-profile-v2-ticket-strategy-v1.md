# Decision Profile V2 et Ticket Strategy V1

> Note 2026-08-02 : le contrat courant recentre le produit sur
> `Opportunity`. `CompiledDecisionProfile` ne contient plus de `pickType`
> global ni de donnees de construction de ticket. Voir
> [Opportunity Architecture](opportunity-architecture.md) pour le contrat actif.

## Objectif

Cette itération corrige l'écart identifié par l'audit entre onboarding,
personnalisation réelle et moteur. Le moteur ne lit jamais les réponses brutes
de l'onboarding. Il reçoit un `CompiledDecisionProfile` compilé, tandis que le
futur générateur de tickets lira uniquement des `TicketStrategy` persistées.

## Pick type

`pickType` est une contrainte de cote individuelle. Il ne modifie jamais la
confiance sportive d'une thèse.

Les bornes sont inclusives. Les cotes sont normalisées à deux décimales avant
classification.

| Pick type | Borne |
|---|---|
| `prudent` | `1.20 <= odds <= 1.49` |
| `normal` | `1.50 <= odds <= 2.19` |
| `audacious` | `odds >= 2.20` |

Pipeline pick :

```text
these sportivement valide
  -> marche active
  -> cote normalisee compatible avec pickType
  = pick eligible
```

## CompiledDecisionProfile V2

```ts
type ProfileConfigurationState = 'notStarted' | 'inProgress' | 'completed';

type PickType = 'prudent' | 'normal' | 'audacious';

type PickTypeOddsBand = {
  id: PickType;
  minimumOdds: number;
  maximumOdds: number | null;
};

type CompiledDecisionProfileV2 = {
  profileSchemaVersion: 2;
  onboardingVersion: string;
  userId: string | null;

  configurationState: ProfileConfigurationState;

  competitions: Record<string, {
    id: string;
    apiFootballLeagueId: number;
    name: string;
    enabled: boolean;
    legacyIds?: string[];
  }>;

  markets: Record<string, {
    id: string;
    enabled: boolean;
    sourceOptionId?: string;
  }>;

  pickType: PickTypeOddsBand | null;

  matchTypes: Record<string, {
    id: string;
    enabled: boolean;
  }>;

  compatibility: {
    migratedFromSchemaVersion?: number;
    ignoredLegacyQuestionIds: string[];
  };
};
```

Invariants :

- `completed` implique au moins une competition activee ;
- `completed` implique au moins un marche active ;
- `completed` implique `pickType != null` ;
- `completed` implique au moins un type de rencontre active ;
- un profil V1 sans `pickType` reste `inProgress`.

## TicketStrategy V1

```ts
type TicketStrategyV1 = {
  schemaVersion: 1;

  id: string;
  userId: string;

  name: string;
  isActive: boolean;

  pickTypes: PickType[];

  minimumSelections: number;
  maximumSelections: number;

  minimumTotalOdds: number;
  maximumTotalOdds: number | null;

  priority: number;

  createdAt: string;
  updatedAt: string;
};
```

Une strategie avec plusieurs `pickTypes` autorise chaque pick a appartenir a
l'une des categories. Elle n'impose pas que toutes les categories soient
representees dans le ticket.

## Regles du Ticket Generator

- aucune strategie active implique zero ticket automatique ;
- un match ne peut apparaitre qu'une fois dans un meme ticket ;
- toutes les contraintes de la strategie doivent etre respectees ;
- aucune contrainte ne peut etre assouplie silencieusement ;
- si aucune combinaison valide n'existe, aucun ticket n'est genere ;
- plusieurs propositions d'une meme strategie doivent differer par au moins un
  pick ;
- les bornes de selections, cotes individuelles et cotes totales sont
  inclusives ;
- le generateur depend uniquement des `TicketStrategy` persistees, jamais des
  reponses brutes d'onboarding.

## Etats de configuration

| Etat | Effet picks | Effet tickets |
|---|---|---|
| `notStarted` | aucun pick personnalise | aucun ticket |
| `inProgress` | aucun pick personnalise | aucun ticket |
| `completed` sans strategie active | picks disponibles | aucun ticket |
| `completed` avec strategie active | picks disponibles | tickets possibles |

## Matrice onboarding

| Bloc onboarding | Sortie finale | Effet moteur | Effet UI |
|---|---|---|---|
| Competitions suivies | `competitions.enabled` | filtre `Pour moi` | profil, etat personnalise |
| Marches joues | `markets.enabled` | filtre marches eligibles | marches proposes ou absents |
| Type de picks | `pickType` | filtre cote individuelle | valeur initiale strategie |
| Types de tickets souhaites | etat transitoire onboarding | aucun effet direct | aide a preparer les strategies |
| Nombre de selections | brouillon strategie | aucun effet direct | pre-remplit la strategie |
| Types de rencontres | `matchTypes.enabled` | active ou desactive les theses associees | lecture personnalisee |
| Configuration strategies | `TicketStrategy[]` persistees | source unique du ticket generator | tickets ou invitation |

## Migration V1 vers V2

A compiler vers V2 :

- anciennes competitions selectionnees vers `competitions.enabled`, via
  `legacyIds` ;
- anciens marches selectionnes vers `markets.enabled` ;
- anciens types de rencontres vers `matchTypes.enabled` quand ils existent
  encore ;
- absence de `pickType` vers `configurationState = inProgress` ;
- profil vide vers `configurationState = notStarted`.

Champs V1 conserves uniquement pour compatibilite et ignores par le moteur V2
MVP :

- `analysisCriteria` ;
- `decisionInfluences` ;
- `bettingApproaches` ;
- `analysisTimeId` ;
- `bettingFrequencyId` ;
- `feedDepth` ;
- `oddsImportance` ;
- `ticketSelectionCounts` ;
- `ticketOddsRanges` ;
- anciens seuils `market_minimum_odds`.

## Plafonds actuels des theses

Ces plafonds ne sont pas modifies dans cette iteration. Ils doivent etre
classifies avant toute externalisation.

| Regle | Valeur | Justification actuelle | Type probable |
|---|---:|---|---|
| Favori solide ignore si favori 1N2 > | `2.05` | un favori trop haut ne soutient plus "favori solide" | limite sportive |
| Favori solide, marche 1N2 max | `2.40` | empeche une selection trop volatile pour cette these | a confirmer |
| Double chance prudente ignoree si favori > | `2.35` | le favori n'est plus assez lisible | limite sportive |
| Double chance prudente max | `2.10` | coherence avec une these prudente | limite sportive probable |
| Ecart de niveau, double chance max | `2.15` | couverture coherente avec hierarchie nette | limite sportive probable |
| Ecart de niveau, 1N2 max | `2.55` | evite que le marche contredise trop l'ecart | a confirmer |
| Match ouvert, over 2.5 max | `2.40` | scenario buts juge trop incertain au-dela | a confirmer |
| Match ferme, under 2.5 max | `2.30` | scenario bas juge trop incertain au-dela | a confirmer |
| Outsider credible ignore si outsider > | `4.50` | surprise trop faible sans preuves tres fortes | limite sportive |
| Outsider credible, double chance max | `2.70` | garde la couverture dans une zone credible | limite sportive probable |
| Outsider credible, 1N2 max | `4.50` | coherent avec la limite de these | limite sportive |
