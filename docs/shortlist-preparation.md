# Shortlist Lector — session de préparation

## Statut et périmètre

V1 implémentée et publiée en démo le 11 octobre 2026 à partir de la demande et des deux maquettes de l’utilisateur. La session serveur, le nettoyage, l’interface football/hockey, la comparaison factuelle et le raccord au Générateur sont installés. Les points ci-dessous décrivent le contrat produit et les limites conservées de cette première version.

La Shortlist rassemble des **rencontres**, de football et de hockey, éventuellement sur plusieurs journées. Les tickets sont des compositions produites à partir de tout ou partie de ces rencontres. Ajouter une rencontre ne sélectionne aucun marché, aucune cote et aucune mise.

Les cinq destinations principales restent Pour moi, Radar, Tous, Générateur et Bilan. L’accès à « Ma Shortlist · N » est partagé entre les sports et visible depuis les listes, les détails et le Générateur. Il ouvre un espace secondaire de préparation, avec retour à l’écran et au défilement d’origine.

## Parcours

1. Ajouter ou retirer une rencontre depuis Pour moi, Radar, Tous ou son détail. Utiliser un bouton dédié avec libellé accessible, état rempli après ajout et confirmation discrète. Ne pas transformer l’étoile des favoris en Shortlist.
2. Ouvrir Ma Shortlist : retrouvailles de la session, skeleton si aucune valeur n’est disponible, données présentes conservées pendant une actualisation et restauration de la position de défilement.
3. Choisir les rencontres à travailler avec des cases à cocher, indépendamment de leur présence dans la Shortlist. Retirer une case ne retire pas le match de la session.
4. « Comparer » ouvre une comparaison de deux rencontres choisies. Deux rencontres représentent quatre équipes ; ce n’est pas une nouvelle opposition entre deux équipes de matchs différents.
5. « Préparer avec Lector » ouvre le Générateur avec une référence à la session et au sous-ensemble choisi. Le contexte est affiché explicitement : par exemple « Shortlist · 6 rencontres · samedi + dimanche · football et hockey ».
6. Le dialogue permet d’ajuster marchés, mises, nombre de matchs, choix des rencontres et variantes. Ces contraintes appartiennent à la préparation courante. Aucun questionnaire ou stratégie persistante n’est requis avant de commencer.
7. Les propositions restent des brouillons de la conversation. Enregistrer un ticket utilise les objets persistants et snapshots déjà prévus dans Mes suivis.

## Cycle de vie

- Une session active par compte. Le calcul d’expiration et les transitions sont autoritaires côté serveur, en UTC.
- Durée normale : 24 heures après le dernier ajout ou retrait **effectif**. Un doublon ou une répétition de la même requête ne prolonge pas la session.
- Lire, scroller, comparer, générer, cocher un sous-ensemble ou actualiser les données ne renouvelle pas cette durée.
- Un ajout/retrait ne raccourcit pas une prolongation déjà choisie : nouvelle échéance = maximum de l’échéance prolongée et de maintenant + 24 h.
- Prolonger propose jusqu’à ce soir, demain soir ou pendant sept jours. « Ce soir » et « demain soir » se calculent dans le fuseau affiché, et non comme 12 h ou 24 h fixes. Un choix qui raccourcit l’échéance actuelle n’est pas proposé comme prolongation.
- Affichage discret « Session temporaire » et échéance accessible dans le détail. Afficher « Expire dans 2 h » seulement près de l’expiration. Aucune jauge animée permanente.
- À expiration, la session devient inactive même si le traitement de nettoyage n’a pas encore tourné. Elle n’alimente plus les nouvelles générations.
- Récupération possible pendant 24 h à partir de l’échéance. Restaurer ouvre une nouvelle période de préparation avec les rencontres conservées, actualisées et leurs statuts réels.
- Commencer une nouvelle session ne supprime pas immédiatement la session récupérable. Si une nouvelle session active existe lors d’une restauration, proposer explicitement une fusion sans doublon ou conserver la session courante.
- Après la récupération, supprimer la session et ses entrées. Les tickets enregistrés ne sont reliés par aucune suppression en cascade.
- « Vider la liste » ne signifie pas effacer un historique de tickets. Permettre d’annuler cette action avec une opération serveur atomique, sans réintroduire silencieusement des entrées ajoutées depuis un autre appareil.

Le nettoyage planifié est installé à la minute 17 de chaque heure. Il ne remplace pas les vérifications de date à chaque lecture et génération.

## Disponibilité sportive

La conservation d’un match et son éligibilité à une composition sont deux propriétés distinctes.

- À étudier : rencontres à venir, avec horaire connu et pas encore commencé.
- En direct : rencontres commencées, consultables et comparables ; exclues de la génération prématch actuelle.
- Terminés : conservées jusqu’à expiration pour relire les raisons du choix ; exclues de la génération prématch.
- Reporté, annulé ou statut inconnu : état explicite, consultation possible, exclusion de la génération tant qu’aucune disponibilité fiable n’est publiée.
- Une cote absente ou trop ancienne empêche de proposer ce marché, sans empêcher l’analyse du match.

Le Générateur explique les exclusions (« 4 rencontres utilisables, 1 terminée, 1 sans cote disponible »). Il ne complète pas le ticket avec des rencontres extérieures à la Shortlist sans demande explicite. Si une rencontre commence pendant l’analyse, revérifier son éligibilité avant de retourner ou appliquer une composition.

## Comparaison

Réutiliser les composants de données et de lectures de Lector. Pour deux rencontres, afficher les quatre équipes, leurs rôles domicile/extérieur, les formes récentes, lectures, Radar, marchés disponibles et contradictions. La comparaison peut conclure qu’aucune rencontre ne se détache.

Ne pas comparer directement les rangs de championnats différents. Les métriques de forme doivent indiquer le sport, le système de points et l’échantillon ; un total sur cinq matchs en NHL et en football n’a pas le même maximum. Les indicateurs normalisés restent descriptifs. Le marché examiné doit avoir des arguments propres : bonne forme d’une équipe ne justifie pas automatiquement « les deux équipes marquent ».

Les variantes portent des descriptions de construction (moins de rencontres, autres marchés, plus proche de l’objectif). Ne pas reprendre « sécurisé » de la maquette comme estimation d’une probabilité. Les chiffres et rencontres des maquettes sont illustratifs.

## Données et synchronisation

Modèle proposé :

```text
shortlist_sessions
  id, user_id, revision
  status: active | extended | expired
  created_at, last_modified_at, expires_at, recoverable_until
  timezone, extension_until

shortlist_items
  session_id, sport, fixture_id, added_at
  primary key (session_id, sport, fixture_id)
```

L’état expired est vérifié depuis l’échéance serveur, pas uniquement depuis la colonne status. Un index partiel assure une seule session active/extended par compte, avec transition d’expiration dans la même transaction avant une création.

Identités stables `sport:fixture_id` ; football normalisé depuis `api-fixture-ID`, hockey depuis son identifiant fournisseur. Aucun nom d’équipe comme identifiant. Aucune collision entre football et hockey ayant le même ID numérique.

Les intitulés et logos du cache peuvent servir à un affichage immédiat, mais la session stocke les références des rencontres. Résoudre lectures, marchés, cotes et scores depuis les dernières publications vérifiées. Une rencontre dont la publication est devenue indisponible reste listée comme telle, avec une action de retrait ; ne pas simuler sa disponibilité.

Mutations par opérations atomiques et idempotentes (ajout, retrait, prolongation, restauration, vider), jamais suppression/réinsertion complète de la liste. Révision et réponse serveur permettent de résoudre les actions simultanées sur deux appareils sans perdre les autres ajouts. RLS par propriétaire et fonctions authentifiées : aucun user_id choisi par le client.

Le cache local est isolé par compte. À déconnexion ou changement de compte, effacer immédiatement le contexte affiché et ignorer les réponses en retard. La synchronisation distante est nécessaire pour tenir la promesse entre appareils. L’accès sans compte et une éventuelle liste invitée constituent un choix produit ultérieur ; ne pas promettre de synchronisation anonyme.

## Raccord au Générateur

```text
Pour moi / Radar / Tous / détail
            → actions utilisateur → session Shortlist
                                      ↓
                         sélection de rencontres
                                      ↓
                contexte de travail du Générateur
                                      ↓
                 lecture des données actualisées
                                      ↓
           IA : comparaison et intention de composition
                                      ↓
            calcul Lector : marchés, cotes, variantes
                                      ↓
            propositions → choix utilisateur → Mes suivis
```

Ajouter une référence structurée de travail au contexte : sessionId, revision et clés choisies. Le serveur vérifie le propriétaire, l’expiration et l’appartenance des clés. Il renvoie les rencontres réellement résolues, les absentes, les exclusions et la couverture complète.

Un outil **read_shortlist** lit seulement la session du compte authentifié, ses dates et ses références. Les outils existants de détails, d’évaluation et de compositions sont adaptés pour travailler sur ces références. Ni SQL libre, ni URL libre, ni identifiant d’un autre utilisateur, ni méthode de mutation n’est exposé au modèle.

Les écritures de Shortlist restent des actions de l’application décidées par l’utilisateur. Si le chat suggère un retrait, ajout ou prolongation, il peut afficher une proposition à confirmer ; le modèle ne l’applique pas.

La référence Shortlist reste liée à la conversation de travail même lorsque l’utilisateur change d’écran, de sport ou de date du calendrier. Conserver les contraintes naturelles de la conversation et les tickets référencés. Un changement de la liste est rendu visible avant la requête suivante, avec sa nouvelle révision. Les tickets déjà générés gardent leur état d’origine.

Le contexte Shortlist ne réutilise pas le filtre du profil pour éliminer un match explicitement ajouté depuis Tous ou Radar. Les préférences de consultation restent informatives ; les marchés/mises demandés dans cet échange guident la composition. Vérifier cependant la présence réelle du marché, la cote, le bookmaker et les règles sportives.

Une Shortlist sur plusieurs dates est lue par groupes date/sport, puis réunie en un ensemble vérifié. Ne pas utiliser une date unique comme filtre final de composition. Afficher la couverture et les exclusions ; aucune troncature silencieuse à la première page ou à vingt rencontres.

## Décommissionnement constaté dans le code

Chemins encore présents au moment de l’audit :

- `matches_home_page.dart` lance `TicketGenerator().generate` dans le build, y compris lorsque le Générateur conversationnel est choisi. Supprimer ce calcul du parcours moderne.
- Le même écran raccorde `TicketGeneratorPage`, `TicketBuilderPanel` et l’action « Mes tickets et stratégies ». Remplacer les entrées de préparation par la Shortlist et supprimer le repli actif vers le générateur historique.
- `lector_generator_page.dart` expose « Ajuster le contexte », un plafond de mise et le mode Découverte. Retirer ces réglages de préparation persistants et leur message de marchés interdits. Les contraintes viennent de l’échange utilisateur.
- `lector_space_page.dart` expose « Mes stratégies », et `lector_preferences_sheet.dart` contient leur éditeur. Retirer ces écrans, cartes et callbacks du parcours actif.
- `copilot_flow_page.dart` charge encore les stratégies au démarrage. Retirer cette dépendance dès qu’aucun parcours actif ne l’utilise.

Ne pas supprimer les tickets déjà enregistrés ni leur règlement/historique. Les tables et types historiques qui sont encore nécessaires pour lire ces objets restent compatibles. La suppression physique des tables anciennes se fait ultérieurement après audit des consommateurs et reprise des références.

Les réglages de compétition et de lectures qui alimentent Pour moi restent des filtres de consultation. Leur rôle ne doit pas devenir une configuration obligatoire de la Shortlist. Le profil, la Shortlist et la conversation ont des cycles de vie séparés.

## Contraintes techniques actuelles à adapter

- `contracts.ts` accepte une date principale par intention et limite la génération à quatre tickets par demande. Adapter ce contrat aux journées de la Shortlist et aux demandes collectives, avec exécution par lots quand nécessaire.
- `conversation_memory.ts` limite les clés d’un focus explicite à vingt. Le focus d’une composition et la taille de l’espace de préparation ne doivent pas être confondus.
- `conversation_tools.ts` sait déjà rechercher, lire les détails, évaluer les rencontres, consulter la session et calculer des variantes en mémoire. Réutiliser ce socle et sa séparation lecture/écriture.
- L’état du chat est actuellement rechargé/changé avec la date du calendrier. Une préparation Shortlist doit survivre à ces changements sans perdre la conversation qui lui est rattachée.
- Le contexte de la démo utilise déjà `configurationPolicy=request`. Le raccord doit garder cette règle et retirer l’interface historique contradictoire, pas créer un nouveau verrou de configuration.

## Ordre d’implémentation

1. Session serveur : transactions, ownership, expiration/récupération, opérations idempotentes et nettoyage.
2. Store/controller partagé entre football et hockey ; cache isolé, synchronisation, état de chargement et retour à l’application.
3. Ajout/retrait dans les cartes et détails, entrée Ma Shortlist, groupes d’état, sous-sélection et prolongation selon les maquettes.
4. Outil de lecture Shortlist, contexte multi-date, comparaison de deux rencontres et conversation continue pour la composition de variantes.
5. Retrait des chemins manuels et des paramètres persistants de préparation ; conservation de la lecture des tickets sauvegardés.
6. Vérifications de bout en bout, puis déploiement de la migration, du Générateur et de l’application de démo.

## Critères de validation

- Ajout depuis les trois listes et un détail ; football et hockey ; mêmes identifiants numériques dans deux sports ; doublon idempotent.
- Fermer/revenir, passer du football au hockey et changer de journée sans perdre la session ou son sous-ensemble sélectionné ; synchronisation sur un deuxième appareil.
- Deux ajouts/retraits concurrents n’effacent pas les autres entrées. Le compte B ne lit ni ne modifie la liste du compte A.
- Consultation ne renouvelle pas l’expiration ; un vrai ajout/retrait oui ; une prolongation plus longue n’est pas raccourcie ; horaires locaux corrects aux changements d’heure.
- Expiration sans attendre le cron ; récupération dans le délai, puis suppression ; restauration avec une autre session active explicite.
- Match commencé ou terminé pendant l’analyse exclu des nouvelles compositions ; absence de cote expliquée ; aucun match ajouté extérieurement en silence.
- Comparaison de deux rencontres ; génération multi-sport et multi-date ; demande de variantes et changement de mise sans formulaire préalable.
- Expiration de la Shortlist ne supprime aucun ticket enregistré. Les anciennes configurations n’imposent plus de plafond ou de marché caché.
- Couverture intégrale annoncée uniquement si toutes les références ont été résolues et évaluées selon l’action demandée.
- Squelettes au chargement initial, conservation du contenu lors de l’actualisation et défilement préservé.

## Reçu de publication du 11 octobre 2026

- Code validé et installé : `4fe512fa98ea664ee3577dd819f9390611b12d62`, sur `codex/multisport-hockey`.
- [CI complète réussie](https://github.com/jpbenga/vector/actions/runs/38145804052) : Flutter et fonctions Supabase.
- [Installation serveur réussie](https://github.com/jpbenga/vector/actions/runs/38146106607/job/114489690313) : migration `20261011160000_lector_shortlist.sql`, SHA-256 `6c43cabdb685d6feb1a382bca3d06119aeaba6fefb60ef91e1ba7ad2e2c68f74` ; fonction `lector-generator-workshop` active ; requête anonyme rejetée avec HTTP 401.
- Contrôles d’accès : mutations anonymes interdites, action authentifiée disponible, lecture arbitraire d’un autre propriétaire interdite, écritures directes aux tables interdites.
- Nettoyage `lector-shortlist-cleanup` actif, horaire `17 * * * *`.
- Déploiement Vercel `dpl_5uo7Rt9QcTfeoFA6xusuktWLWSA4`, état READY, alias public [démo](https://lector-sports-demo-lector1.vercel.app/).
- Vérification navigateur anonyme : entrée Ma Shortlist dans les deux sports, invitation à se connecter pour sa préparation, boutons d’ajout sur les cartes football et hockey ; largeur 320 px. Aucun test IA payant ni collecte fournisseur.
- Tests locaux : 118 tests Deno Générateur, SQL réel via PGlite, neuf tests Shortlist Flutter, tests de parcours et transitions corrigés, 24 contrôles Python de déploiement ; analyse Flutter propre. Les tests SQL vérifient expiration/récupération, fusion, concurrence, isolation par compte et conservation des tickets enregistrés.

### Limites de cette V1

200 rencontres par session ; préparation multi-date et multi-sport par références. Les contraintes existantes de quatre tickets par demande et vingt clés de focus explicite sont conservées. La comparaison initiale est factuelle et ne consomme pas d’IA ; approfondir ouvre le dialogue. Le contrôle réel de plusieurs appareils connectés et la génération avec OpenAI restent à effectuer par les testeurs. La suppression physique des anciens types/tables de stratégie et l’externalisation de tous les objets riches du chat ne font pas partie de cette publication.
