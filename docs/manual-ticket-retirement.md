# Retrait de la préparation manuelle sur la démo

11 octobre 2026. Première étape du chantier Shortlist demandée par l’utilisateur.

## Changements

- Le football ouvre directement le Générateur conversationnel. Aucun repli vers `TicketGeneratorPage`, aucune action « Mes tickets et stratégies ».
- Suppression de `ticket_generator_page.dart`, `ticket_builder_panel.dart` et `lector_strategies_page.dart`.
- Suppression de l’éditeur de stratégies de `lector_preferences_sheet.dart`, de la carte Mes stratégies dans Mon espace et du compteur de stratégies.
- Le démarrage ne charge et ne sauvegarde plus les stratégies. Le build du football ne lance plus l’ancien `TicketGenerator().generate`.
- Les détails de rencontres n’ajoutent plus une sélection dans un panneau manuel. Le menu du détail ouvre les lectures et le Générateur.
- Le chat n’affiche plus Ajuster le contexte, plafond de mise, mode Découverte, Mes préférences ou Utiliser mon profil. La mise et les contraintes sont demandées dans la conversation.
- Les préférences de consultation (compétitions, lectures, scénarios et marchés affichés) restent disponibles dans l’espace personnel. Sur la démo, `configurationPolicy=request` conserve leur rôle informatif pour les compositions ; elles ne créent pas de verrou de mise ou de marché pour le Générateur.

## Conservation

Les tickets déjà sauvegardés et leur règlement restent consultables via Tickets enregistrés. Les décisions du Générateur restent dans Bilan → Mes suivis. Aucune donnée utilisateur ou table Supabase n’est supprimée.

Les formats historiques des tickets et les outils d’audit qui les lisent restent compatibles. Les types historiques ne donnent plus accès à un parcours de création manuelle dans l’application.

La Shortlist n’est pas encore installée : son contrat reste décrit dans `shortlist-preparation.md`. Cette étape retire la préparation obsolète pour permettre son remplacement.

## Livraison

Publication sur l’alias public de la démo multisport uniquement, avec le serveur Générateur existant. Aucun collecteur hockey ni appel OpenAI requis pour cette livraison d’interface.

Publication effectuée le 11 octobre 2026 : `dpl_DSqoSn8yXfPnRiGmXuALq4byFUdQ`, état `READY`, à `https://lector-sports-kai3a4h9n-lector1.vercel.app`. L’alias `https://lector-sports-demo-lector1.vercel.app` pointe vers cette livraison.

Vérifications : analyse Flutter sans erreur ; 55 tests ciblés (Générateur, navigation, responsive, tickets enregistrés) et 57 tests de MatchesHomePage réussis ; compilation web release réussie. Le navigateur confirme que le menu du Générateur ne contient plus les réglages de préparation ni les anciens tickets et stratégies, et que Mon espace présente les cinq cartes de consultation sans Mes stratégies.

Capture de la démo publiée : `/private/tmp/lector-demo-manual-retired-2026-10-11.png`. Aucun test de génération payante n’a été exécuté pour cette livraison.
