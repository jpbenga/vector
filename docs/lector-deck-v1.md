# Lector Deck V1

Ce document fige le contrat produit et UX de la V1 du Deck Lector.

Il ne decrit pas encore une implementation applicative. Il sert de reference
avant de coder le composant global, le resolver et les points d'integration.

## Philosophie

Le Deck n'essaie pas de predire ce que veut faire l'utilisateur.

Il expose les actions les plus utiles permises par le contexte courant et
raccourcit les parcours existants.

L'intelligence V1 vient de :

- l'ecran courant ;
- l'etat reel disponible dans le code ;
- les actions fonctionnelles de bout en bout.

Elle ne vient pas de :

- un score opaque ;
- une estimation d'intention ;
- une interpretation automatique du premier match d'une liste ;
- une action placeholder ajoutee pour remplir le Deck.

Principe structurant :

> Le Deck accelere une intention. Il ne doit pas inventer l'intention.

## Perimetre V1

La V1 couvre uniquement quatre contextes :

- Accueil scores, mode `Pour moi` ;
- Accueil scores, mode `Tous` ;
- Accueil scores, mode `Generateur` ;
- Detail d'un match.

Les contextes suivants sont exclus du premier lot :

- `Mon espace` ;
- `Mes competitions` ;
- `Mes scenarios` ;
- `Mes strategies`, sauf comme destination depuis le generateur ;
- onboarding ;
- auth ;
- admin.

Ces ecrans pourront etre integres plus tard si le comportement des quatre
premiers contextes est valide.

## Regles Globales

- Une seule implementation visuelle du Deck doit exister.
- Le bouton ferme utilise le logo officiel via `LectorBrandMark`.
- Le Deck reste en bas a gauche, au-dessus du contenu, avec gestion safe area.
- Le Deck ouvert est une capsule horizontale compacte, jamais un bottom sheet.
- Aucun backdrop opaque n'est utilise pour la navigation Deck.
- Maximum 3 actions dans la plupart des contextes.
- Maximum 4 actions hors logo uniquement si elles sont toutes justifiees.
- Une seule action principale maximum.
- La destination actuelle n'apparait jamais sauf si le bouton declenche une
  vraie action differente.
- Aucun bouton disabled : une action indisponible disparait.
- Aucune action placeholder : si le flux n'est pas branche de bout en bout,
  l'action est interdite.
- Le Deck se replie apres action, tap exterieur ou changement de contexte.
- Les actions ne changent que lorsque le contexte change reellement.
- Le Deck evite de repeter un controle immediatement visible et proche de
  l'utilisateur, sauf si le Deck economise un vrai parcours depuis une position
  scrollee.

## Actions Interdites En V1

Les actions suivantes ne doivent pas entrer dans le Deck V1 :

- `Favori` sur la fiche match tant que l'action affiche seulement un snackbar
  de type "a brancher".
- `Filtres` dans l'accueil compact tant que le callback actuel est vide.
- `Ajouter la competition au profil` tant que l'action n'est pas fonctionnelle
  de bout en bout.
- `Recherche`, car aucune destination ou capacite fonctionnelle n'est branchee
  pour cette entree dans le Deck actuel.
- Toute entree generique ajoutee uniquement pour atteindre un nombre fixe de
  boutons.

## Contexte Pour Moi

Etat actuel utile :

- mode courant `Pour moi` ;
- date selectionnee ;
- liste personnalisee visible ;
- matchs affiches dans `A suivre aujourd'hui`.

Regle importante :

Le premier match classe dans `A suivre aujourd'hui` ne devient pas
automatiquement "le meilleur match" ni l'action principale du Deck. Le code peut
ordonner des matchs pour l'affichage, mais cette information ne suffit pas a
deduire une intention utilisateur.

Actions autorisees :

| Action | Type | Condition | Parcours actuel | Parcours Deck | Gain |
| --- | --- | --- | --- | --- | --- |
| `Tous` | Navigation | Toujours, si mode courant `Pour moi` | Remonter au segmented control, toucher `Tous` | Ouvrir Deck, toucher `Tous` | Evite le retour au haut de page |
| `Generateur` | Navigation | Toujours, si mode courant `Pour moi` | Remonter au segmented control, toucher `Generateur` | Ouvrir Deck, toucher `Generateur` | Evite le retour au haut de page |

Action principale :

- Aucune action principale metier par defaut.
- `Aujourd'hui` est volontairement absent du contexte `Pour moi`. Le Deck peut
  n'afficher que `Tous` et `Generateur` si ce sont les deux seules actions
  vraiment utiles.
- Une future action `Ouvrir le match` ne sera autorisee que si le match a ete
  explicitement selectionne, suivi ou ouvert par l'utilisateur dans une regle
  produit validee.

## Contexte Tous

Etat actuel utile :

- mode courant `Tous` ;
- date selectionnee ;
- liste de matchs par competition ;
- competitions repliees/depliees localement.

Actions autorisees :

| Action | Type | Condition | Parcours actuel | Parcours Deck | Gain |
| --- | --- | --- | --- | --- | --- |
| `Pour moi` | Navigation | Toujours, si mode courant `Tous` | Remonter au segmented control, toucher `Pour moi` | Ouvrir Deck, toucher `Pour moi` | Evite le retour au haut de page |
| `Aujourd'hui` | Action | Seulement si la date selectionnee n'est pas aujourd'hui | Remonter au calendrier, choisir aujourd'hui | Ouvrir Deck, toucher `Aujourd'hui` | Raccourci date direct |
| `Generateur` | Navigation | Toujours, si mode courant `Tous` | Remonter au segmented control, toucher `Generateur` | Ouvrir Deck, toucher `Generateur` | Acces rapide depuis une liste longue |

Action principale :

- `Pour moi`, car c'est le retour au filtre personnalise depuis la liste globale.

Actions interdites :

- `Filtres` tant que le callback du mode compact n'est pas reellement branche.
- Une action de competition favorite globale, car elle depend d'un element local
  de liste et non du contexte ecran.

## Contexte Generateur

Etat actuel utile :

- mode courant `Generateur` ;
- resultats produits par `TicketGenerator` ;
- tickets sauvegardes ;
- strategies disponibles et actives ;
- action `Recalculer` deja fonctionnelle par `setState` ;
- action `Historique` deja fonctionnelle via bottom sheet ;
- action `Parametres` deja fonctionnelle vers les strategies ;
- action `Creer un ticket personnalise` deja fonctionnelle via retour au mode
  `Tous` et snackbar d'instruction.

### Generateur Sans Resultat

Actions autorisees :

| Action | Type | Condition | Parcours actuel | Parcours Deck | Gain |
| --- | --- | --- | --- | --- | --- |
| `Recalculer` | Action | Si l'action force vraiment le recalcul courant | Toucher le bouton header `Recalculer`, parfois apres scroll haut | Ouvrir Deck, toucher `Recalculer` | Raccourci depuis le bas du generateur |
| `Strategies` | Navigation | Toujours si l'ecran de strategies est accessible | Toucher le bouton header `Parametres` | Ouvrir Deck, toucher `Strategies` | Rend le libelle plus explicite |
| `Tous` | Navigation | Toujours, si mode courant `Generateur` | Remonter au segmented control, toucher `Tous` | Ouvrir Deck, toucher `Tous` | Retour rapide aux matchs |

Action principale :

- `Strategies` si aucune strategie active ne permet de generer un resultat.
- `Recalculer` seulement si des entrees suffisantes existent et que le manque de
  resultat peut etre resolu par recalcul.

Action interdite :

- `Generer`, car le generateur actuel calcule deja ses resultats au build. Une
  action `Generer` serait fictive sans commande metier dediee.

### Generateur Avec Resultats

Actions autorisees :

| Action | Type | Condition | Parcours actuel | Parcours Deck | Gain |
| --- | --- | --- | --- | --- | --- |
| `Historique` | Navigation | Si l'historique est accessible | Toucher l'icone historique dans le header, souvent apres scroll haut | Ouvrir Deck, toucher `Historique` | Acces depuis la position courante |
| `Recalculer` | Action | Toujours si les propositions peuvent etre recalculees | Toucher l'icone refresh dans le header | Ouvrir Deck, toucher `Recalculer` | Acces rapide |
| `Strategies` | Navigation | Toujours si l'ecran de strategies est accessible | Toucher l'icone parametres du header | Ouvrir Deck, toucher `Strategies` | Raccourci vers la configuration |

Action principale :

- `Historique` si des tickets sauvegardes existent.
- Sinon `Recalculer`, si aucun historique utile n'est disponible.

## Contexte Detail Match

Ce contexte est le plus important pour prouver la valeur du Deck V1.

Etat actuel utile :

- match courant ;
- opportunite eventuelle ;
- marche recommande eventuel ;
- `ticketDraftListenable` ;
- `onToggleTicket` ;
- `onViewSavedTickets` ;
- `onRemoveTicketSelection` ;
- etat "ce match est deja dans Mon ticket" ;
- etat "une autre selection du meme match bloque l'ajout".

Le Deck peut reagir a une action explicite de l'utilisateur, car le ticket draft
est un etat reel et observable.

### Match Non Selectionne

Actions autorisees :

| Action | Type | Condition | Parcours actuel | Parcours Deck | Gain |
| --- | --- | --- | --- | --- | --- |
| `Ajouter au ticket` | Action | Selection recommandee disponible, `onToggleTicket` disponible, pas d'autre selection bloquante pour ce match | Ouvrir ou atteindre la section marche, toucher le bouton d'ajout | Ouvrir Deck, toucher `Ajouter au ticket` | Evite navigation interne et scroll |
| `Lectures` | Navigation locale | Toujours si le sheet de lectures existant peut etre ouvert | Toucher la carte scenario ou scroller vers les lectures | Ouvrir Deck, toucher `Lectures` | Ouvre directement le detail des lectures |
| `Generateur` | Navigation | Toujours si retour vers le mode generateur est disponible depuis la fiche | Revenir, puis toucher `Generateur` | Ouvrir Deck, toucher `Generateur` | Evite retour manuel puis changement de mode |

Action principale :

- `Ajouter au ticket`.

### Match Deja Selectionne

Actions autorisees :

| Action | Type | Condition | Parcours actuel | Parcours Deck | Gain |
| --- | --- | --- | --- | --- | --- |
| `Voir mon ticket` | Action locale | `TicketBuilderPanel` disponible pour le ticket draft courant | Revenir ou manipuler le panneau inferieur, puis ouvrir le ticket | Ouvrir Deck, toucher `Voir mon ticket` | Deploie le ticket courant sans quitter la fiche |
| `Lectures` | Navigation locale | Toujours si le sheet de lectures existant peut etre ouvert | Toucher la carte scenario ou scroller vers les lectures | Ouvrir Deck, toucher `Lectures` | Ouvre directement le detail des lectures |
| `Retirer` | Action | `onToggleTicket` ou `onRemoveTicketSelection` disponible pour cette selection | Retrouver le bouton ajoute ou passer par le panneau ticket | Ouvrir Deck, toucher `Retirer` | Retrait direct |

Action principale :

- `Voir mon ticket`.

### Match Bloque Par Une Autre Selection

Actions autorisees :

| Action | Type | Condition | Parcours actuel | Parcours Deck | Gain |
| --- | --- | --- | --- | --- | --- |
| `Voir mon ticket` | Action locale | Une autre selection du meme match existe et `TicketBuilderPanel` disponible | Ouvrir le panneau ticket puis identifier la selection bloquante | Ouvrir Deck, toucher `Voir mon ticket` | Deploie le ticket courant sans quitter la fiche |
| `Lectures` | Navigation locale | Sheet de lectures existant disponible | Toucher la carte scenario ou scroller vers les lectures | Ouvrir Deck, toucher `Lectures` | Ouvre directement le detail des lectures |
| `Generateur` | Navigation | Disponible depuis la fiche | Revenir puis changer de mode | Ouvrir Deck, toucher `Generateur` | Raccourci de sortie |

Action principale :

- `Voir mon ticket`.

Action interdite :

- Bouton `Ajouter au ticket` disabled. Il doit disparaitre si l'ajout n'est pas
  possible.

## Etats Du Composant

### Ferme

- Capsule compacte avec logo `LS`.
- Taille coherente avec le dock valide existant, environ `52 x 48`.
- Hit target confortable.
- Aucun texte visible.

### Ouvert

- Expansion horizontale depuis le logo.
- Actions iconiques avec tooltip.
- Action principale visuellement identifiable, mais pas disproportionnee.
- Pas de modalisation de l'ecran.

### Action En Cours

- Etat leger reserve aux actions qui ont une latence visible.
- Le Deck peut afficher une courte transition de feedback sur l'action touchee.
- Pas de spinner global si l'action est instantanee.

### Indisponible

- Pas de bouton disabled.
- L'action est absente du resolver.

### Changement De Contexte

- Le Deck se replie.
- Les actions sont resolues a nouveau uniquement apres changement de contexte
  significatif : mode, route/page, match courant, etat ticket pertinent.

## Transitions

- Ouverture : morph horizontal de la capsule depuis le logo.
- Fermeture : morph inverse.
- Duree cible : 200 a 260 ms.
- Courbe cible : `easeOutCubic` ou equivalente.
- Apparition des actions : fade, scale leger et translation horizontale courte.
- Stagger discret autorise.
- Pas de rebond fort.
- Pas de mouvement vertical important.
- Pas de bottom sheet.
- Pas de backdrop sombre.

## Architecture Cible

Noms indicatifs, a ajuster aux conventions finales :

- `LectorDeck` : unique implementation visuelle.
- `DeckAction` : id, label, icon, type, priorite, callback.
- `DeckContext` : ecran, mode, date, match, ticket draft, strategies, resultats.
- `DeckActionResolver` : regles deterministes de selection des actions.
- `LectorDeckHost` : placement global et fermeture sur changement de contexte.
- `DeckCapabilities` : callbacks fournis par les ecrans sans exposer le design.

Les ecrans peuvent fournir :

- le contexte courant ;
- les callbacks fonctionnels ;
- les references d'etat deja existantes.

Les ecrans ne doivent pas fournir :

- dimensions ;
- couleurs ;
- animation ;
- layout du Deck ;
- ordre arbitraire des boutons ;
- duplication locale du composant.

## Criteres D'Acceptation V1

- Une seule implementation visuelle du Deck est utilisee sur l'accueil et la
  fiche match.
- L'ancienne fiche match n'ouvre plus de bottom sheet pour le Deck.
- Le Deck ferme a le meme rendu partout.
- Le Deck ouvert garde les memes dimensions, le meme morphing et les memes
  regles tactiles partout.
- Le Deck ne propose jamais la destination courante sans action differente.
- Le Deck ne contient aucune action placeholder.
- Le Deck ne contient aucun bouton disabled.
- `Pour moi` ne propose pas automatiquement d'ouvrir le premier match classe.
- `Tous` propose un retour rapide vers `Pour moi`.
- `Generateur` expose seulement des actions deja fonctionnelles.
- `Detail match` bascule deterministiquement entre `Ajouter au ticket`,
  `Voir mon ticket` et `Retirer` selon `ticketDraft`.
- Le Deck se replie apres action, tap exterieur et changement de contexte.
- Les tests couvrent au minimum le resolver pour les quatre contextes V1.
- Les tests widget couvrent l'ouverture, la fermeture et la disparition des
  actions interdites.

## Points A Verifier Avant Implementation

- Identifier le meilleur emplacement de `LectorDeckHost` sans perturber
  `TicketBuilderPanel`.
- Exposer proprement les callbacks du generateur actuellement internes :
  historique, recalcul, strategies.
- Exposer proprement les callbacks de fiche match pour `Lectures`, `Generateur`,
  `Ajouter`, `Retirer` et `Voir mon ticket`. En V1, `Lectures` ouvre le sheet
  de lectures existant.
- `Voir mon ticket` ouvre ou deploie le `TicketBuilderPanel` correspondant au
  ticket draft courant. Il ne navigue pas vers le generateur.
- Conserver les tests existants bases sur les keys `lector-floating-dock-*` ou
  les migrer vers des keys stables du nouveau composant.
