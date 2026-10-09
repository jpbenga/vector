# Sessions et décisions du Générateur

Cette fonctionnalité est activée sur l’atelier de la démo multisport (`lector-generator-workshop`). Le Générateur de production conserve son fonctionnement actuel.

## Trois informations distinctes

- **Pertinente** est un avis sur la proposition. Il ne déclenche pas un suivi sportif.
- **Suivre** conserve une sélection et vérifie son résultat. Aucun pari placé n’est supposé.
- **Enregistrer le ticket** conserve sa composition complète.
- **J’ai placé ce pari** est une déclaration explicite, confirmée par l’utilisateur. Lector ne place aucune mise. Cette déclaration peut être retirée.

Les résultats des marchés se trouvent dans **Bilan → Mes suivis**. Les confirmations des lectures restent dans **Bilan → Lectures**. Un résultat de marché n’est pas déduit du verdict d’une lecture.

## Snapshots et versions

Le serveur résout les identifiants dans les objets générés pour le compte authentifié. Il n’accepte pas de cote ou de justification fabriquée par le client. Chaque objet conserve les sélections, marchés, bookmaker, cotes et dates d’observation, mise prévue, contexte initial, lectures, Radar, contradictions et explications disponibles.

Une sauvegarde répétée du même objet est idempotente. Elle ne remplace pas ses valeurs initiales. Les tickets modifiés ont de nouveaux identifiants ; lors d’un remplacement, retrait ou restauration, la nouvelle sauvegarde référence la version enregistrée antérieure lorsqu’elle existe. Les anciennes versions restent consultables. Une alternative indépendante reste une composition indépendante.

## Vérification

Un traitement SQL toutes les cinq minutes utilise les résultats officiels déjà collectés ; ouvrir Mes suivis déclenche aussi une vérification du compte. Aucun appel fournisseur ni IA supplémentaire n’est nécessaire.

La V1 vérifie les marchés football collectés : résultat 1N2, double chance, plus/moins de 2,5 buts et les deux équipes marquent. Elle utilise le score réglementaire. Après prolongation ou tirs au but, l’absence du score à 90 minutes conduit à « Non vérifiable ». Un score live ne règle pas une sélection. Une annulation ou un résultat administratif requiert les conditions du bookmaker et reste non vérifiable automatiquement. Les marchés individuels, marchés hockey ou autres règles non prises en charge ne sont jamais devinés.

États : en attente, gagnante, perdante, annulée, remboursée, non vérifiable. La V1 n’attribue annulée/remboursée que lorsque les règles fournissent ce résultat ; elle ne suppose pas le remboursement d’un match annulé. Un ticket est perdant dès qu’une sélection perd ; sinon, en attente tant qu’une sélection attend son résultat, puis non vérifiable si un règlement manque. Les résultats peuvent être corrigés à partir d’un nouveau résultat officiel ; chaque observation différente est archivée.

La mise et le retour potentiel sont les valeurs théoriques initiales. Aucun gain réellement encaissé ni bilan financier réel n’est déduit.

## Rétention et suppression

- Session : expiration **24 h après la dernière activité**, avec un maximum par défaut de **7 jours**. Les délais sont configurables côté serveur dans `lector_generator_retention`.
- L’heure d’expiration affichée provient du serveur. Lire une session ou consulter le Bilan ne prolonge pas sa durée ; envoyer un message ou conserver une proposition la prolonge dans la limite maximale.
- À expiration, la session n’est plus accessible ; messages, réponses et brouillons non conservés sont supprimés par le traitement de nettoyage (au plus cinq minutes plus tard).
- Les tickets et sélections conservés, ainsi que leur historique de décision et de résultats, n’ont aucun lien de suppression en cascade avec la conversation. Ils restent jusqu’à suppression par l’utilisateur ou suppression du compte.
- Les propositions générées sont conservées séparément durant **30 jours**, sans les messages du chat, pour distinguer les propositions de ce que l’utilisateur a choisi. Les reçus de consommation technique sont aussi conservés 30 jours, sans réponses ni résumé de réflexion. Cette rétention est configurable.
- Les éléments enregistrés peuvent être supprimés depuis leur détail ; leur historique associé est alors supprimé. Le compte est propriétaire de toutes ces données. Aucun autre compte ni accès anonyme ne peut les lire ou les modifier.

La personnalisation prédictive, les crédits commerciaux et le bilan des gains réels ne sont pas activés. Le feedback n’ajuste pas automatiquement les scores du moteur et les suivis ne représentent pas un échantillon impartial de toutes les propositions.
