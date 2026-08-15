# Backend Lot 5 - Cycle de vie des tickets

Ce lot finalise le cycle de vie MVP des tickets sauvegardes sans changer le contrat produit deja stabilise cote front.

## Objectif

Permettre a un ticket de passer proprement par les etats suivants :

- `saved` : ticket enregistre mais non joue ;
- `played` : ticket declare joue par l'utilisateur ;
- `won` : ticket regle comme gagne ;
- `lost` : ticket regle comme perdu ;
- `cancelled` : ticket annule manuellement.

Le backend Supabase du lot 1A sait deja persister ces statuts dans `public.saved_tickets`.
Le lot 5 ajoute donc surtout le moteur deterministe de reglement et son branchement avec la persistance locale/distante.

## Source de verite

Le ticket courant reste local au composant `Mon ticket`.
Une fois sauvegarde, un ticket devient un `SavedTicket` persiste :

- localement pour le mode invite/offline ;
- dans Supabase quand une session existe ;
- avec fusion local/distant via `mergeSavedTickets`.

La sauvegarde distante continue d'utiliser :

- `public.saved_tickets` ;
- `public.saved_ticket_selections`.

## Reglement automatique MVP

Le moteur `TicketSettlementEngine` regle uniquement les tickets en statut `played`.

Un ticket peut devenir :

- `lost` des qu'une selection evaluee est perdante ;
- `won` uniquement lorsque toutes les selections sont evaluees et gagnantes ;
- rester `played` si au moins une selection est encore en attente ou non supportee.

Cette approche evite de forcer un mauvais statut quand la donnee sportive n'est pas suffisante.

## Marches supportes

Le reglement automatique MVP supporte :

- resultat du match / 1N2 ;
- double chance ;
- les deux equipes marquent / BTTS ;
- total de buts ;
- total buts equipe domicile ;
- total buts equipe exterieure.

Les marches non supportes, par exemple buteur, restent en attente.

## Donnees necessaires

Pour regler une selection, le snapshot doit fournir :

- l'identifiant du match, soit via l'id interne `api-fixture-...`, soit via
  l'id fixture API-Football historique ;
- le statut `finished` ;
- le score final domicile/exterieur.

Si le match est live, programme, reporte, annule ou sans score final, la selection reste en attente.

## Persistance

Apres chargement du snapshot, `MatchesHomePage` demande au moteur de regler les tickets joues.
Si un statut change :

- l'etat local de l'interface est mis a jour ;
- `SavedTicketStore.saveAll` persiste le nouvel historique ;
- si une session Supabase existe, la synchronisation distante est effectuee par le store.

## Limites assumees

- Aucun detail de reglement par selection n'est encore persiste en base.
- Le reglement est effectue cote application a partir du read model actuel.
- Les statuts `won` et `lost` peuvent encore etre ajustes manuellement dans l'historique.
- Le reglement serveur automatique reste un futur lot si l'on veut executer ce cycle sans ouverture de l'application.

## Tests

Les tests du lot verifient :

- ticket gagne lorsque toutes les selections evaluees sont correctes ;
- ticket perdu des qu'une selection terminee est fausse ;
- maintien en attente si le match n'est pas termine ;
- maintien en attente si le marche n'est pas supporte ;
- absence de modification des tickets non joues ou deja terminaux ;
- reglement possible depuis l'id fixture API-Football expose par les snapshots.
