# Mise en service contrôlée — Football, Hockey et Générateur

## Paquet local et périmètre

Une seule révision Git doit alimenter les fonctions, les trois migrations et le build Flutter. `tool/prepare_controlled_release.py --output build/controlled-release --build` compile uniquement en local, produit `release.json` et les empreintes des sources/assets. Il refuse un working tree applicatif modifié. Aucun secret serveur, compte autorisé ou corps de publication privée n'entre dans le build.

La branche locale `codex/lector-main-promotion-20261014` réconcilie les historiques de la livraison `52a0fb6` et de l'ancien `main` `712873e`, conservé par `restore/main-before-lector-promotion-20261014`. La promotion ne réécrit pas l'historique. Le build principal et le paquet local utilisent la même recette `tool/build_web_staging.sh`, en environnement production et sans copie statique hockey. Les deux adresses doivent ensuite désigner ce même artifact du projet Vercel `lector-sports` ; aucun second projet ni transfert de comptes Supabase n'est nécessaire.

Pendant la transition, `vercel.json` contient `git.deploymentEnabled=false` : un push/merge n'autorise pas une publication. Les écritures des installateurs GitHub restent bloquées tant que la variable de dépôt `LECTOR_REMOTE_WRITES_ENABLED` n'est pas explicitement mise à `true` après sauvegarde/restauration, quotas et confirmation. La collecte hockey planifiée exige en plus `LECTOR_HOCKEY_SCHEDULE_ENABLED=true`. Les workflows sont conservés. Le contrôle horaire hockey est en lecture seule. Une exécution manuelle de diagnostic ne déverrouille pas les écritures.

Le build lit les publications serveur existantes : aucune copie statique périmée n'est embarquée. Les routes `/sports/:sport` et `/admin` conservent le repli SPA ; un fichier JSON inexistant doit retourner 404.

Le destinataire du test est configuré côté serveur par `LECTOR_GENERATOR_CANARY_EMAILS` ou `LECTOR_GENERATOR_CANARY_USER_IDS`. L'identité est vérifiée via Supabase Auth ; un identifiant envoyé dans la demande n'accorde aucun accès. Le nom du compte reste dans le dossier de livraison privé et la conversation de validation.

## Conditions avant toute mutation distante

1. Confirmation explicite de publication du propriétaire.
2. CI verte pour le SHA exact du manifeste ; comparaison du journal des migrations installé avec les prérequis ci-dessous.
3. Sauvegarde de la base et restauration vérifiée dans une instance Supabase isolée et compatible. Conserver aussi les fonctions effectivement installées, leurs ACL, la configuration des flags, l'alias Vercel précédent et les anciennes têtes de diffusion. Les objets de diffusion sont immuables et doivent être conservés.
4. Contrôle ciblé du volume, des quotas et de la capacité d'écriture. Les dépassements constatés dans l'audit ne prouvent pas une panne ; aucune purge ni changement payant de plan n'est automatique.

### Sauvegarde et répétition de restauration

La sauvegarde/restauration n'a pas été exécutée localement : les données de production et leurs identifiants de connexion restent inaccessibles aux tests locaux. Les tests PGlite vérifient les contrats SQL et ne sont pas une sauvegarde de production.

Utiliser un opérateur et un client PostgreSQL compatibles avec la version serveur, avec deux services de connexion **privés** : `lector-production` et `lector-restore-isolated`. La seconde instance doit être isolée et compatible avec les schémas/extensions Supabase. Ne jamais diriger `pg_restore` vers la production.

```sh
# À exécuter uniquement après confirmation ; identifiants dans un service privé.
pg_dump --dbname=service=lector-production --format=custom --file=lector-before-release.dump
pg_restore --list lector-before-release.dump > lector-before-release.inventory
pg_restore --dbname=service=lector-restore-isolated --no-owner --no-acl --exit-on-error lector-before-release.dump
```

Vérifier les nombres de conversations, tours, messages, tickets archivés et décisions conservées, les publications sportives et le journal des migrations. Exécuter les trois migrations sur cette restauration avant la base réelle ; relire les mêmes objets, leurs références et les contrôles d'ownership. Une archive lisible par `pg_restore --list` seule ne suffit pas. Garder le dump, son SHA-256 et le reçu de restauration hors Git, dans un stockage privé ; supprimer les copies de restauration après la validation et conserver la sauvegarde de cette livraison 30 jours.

Capturer également `pg_get_functiondef` et les ACL des RPC remplacées : `lector_generator_day_page(date,text,jsonb,jsonb)` et `lector_generator_cleanup()`. Le rollback utilisera les définitions réellement installées, pas une version supposée du dépôt.

## Ordre de publication, après confirmation

1. Publier la révision revue et attendre sa CI. Conserver les flags canary désactivés pendant toutes les opérations suivantes.
2. Vérifier les prérequis déjà installés : lecteurs de journées `20261010090000`, archives de travail `20261011200000`, décisions `20261009120000`, publications partagées `20261009170000` et diffusion hockey atomique `20261011050000`. Arrêter sur toute divergence ; les anciens scripts d'update ne livrent pas le lot A–D entier.
3. Appliquer dans une transaction contrôlée, avec inscription au journal des migrations :
   - `20261013210000_generator_domestic_form_projection.sql` ;
   - `20261013220000_generator_exploration_archive_reader.sql` ;
   - `20261014090000_generator_request_audit.sql`.
4. Déployer depuis ce même SHA : `lector-generator`, `lector-generator-workshop`, `api-football-sync`, `build-match-feed-snapshot`, `daily-football-sync`, `ops-worker`, `build-feed-delivery`. Contrôler version active, JWT/CORS et ACL ; l'accès anonyme au Générateur reste refusé.
5. Promouvoir la branche réconciliée vers `main` uniquement après confirmation et CI du contenu exact. Garder l'auto-déploiement Vercel désactivé ; aucune recette Démo distincte ne devient une seconde version principale. Configurer `LECTOR_RELEASE_REF` au SHA effectivement publié sur `main` et conserver les variables d'écriture/planification à `false` jusqu'à l'approbation de leur activation. Les deux fichiers hockey sont intégrés à cette branche, sans publication partielle de fichiers sur un `main` divergent. Après activation, le workflow conserve deux collectes quotidiennes des sept ligues ; le contrôle horaire en lecture seule échoue dès 24 h, avant le rejet à 36 h.
6. Renouveler la publication hockey complète, ses lectures et ses têtes atomiques. Renouveler les publications/diffusions football avec la réserve de deux dates. Cette réserve exige l'autorisation des appels fournisseur supplémentaires ; la fenêtre produit reste J à J+13. Vérifier les 14 dates courantes par sport, y compris les journées réellement vides. L'absence de cotes/lectures ne doit pas masquer les fixtures dans Tous.
7. Publier une seule fois l'artifact Flutter de `release.json` dans le projet `lector-sports`, puis associer les adresses principale et Démo à ce même déploiement après leurs contrôles. Conserver l'alias Démo et les anciens déploiements pendant la transition. Contrôler le fichier réellement servi, l'absence de HTML 200 sur un JSON manquant, les en-têtes de révision et `action=capabilities`. La réactivation des déploiements automatiques nécessite une décision distincte après validation ; aucune redirection ou suppression d'adresse n'est automatique.
8. Configurer `LECTOR_RELEASE_REVISION` au même SHA, l'allowlist du seul compte confirmé, puis `LECTOR_GENERATOR_CANARY_ENABLED=true`. Conserver les limites IA quotidiennes, le budget de test et les délais existants ; vérifier leur disponibilité. `LECTOR_WORKSHOP_ENABLED` et la clé IA restent nécessaires aux appels réels. Aucun pilote ni appel IA automatique n'accompagne l'activation.
9. Vérifier connecté : compte autorisé, compte hors allowlist, reprise d'une conversation/ticket existant, sources Tous/Pour moi/Radar/Shortlist sur les deux sports. Les tests libres du propriétaire servent ensuite à mesurer pertinence, couverture, latence et coûts estimés.

## Traçabilité et durée

- Les demandes de conversation conservent leur UUID, révision, intention, contraintes, couvertures, références d'évaluation/publication, exclusions et reçus IA.
- Les lectures/comparaisons d'archives ont aussi un UUID, exposé par `x-lector-request-id`, et un reçu sans appel IA. Les sondages de progression réutilisent l'identifiant de la demande initiale et n'écrivent pas un événement à chaque sondage.
- `action=audit` lit uniquement la requête du propriétaire authentifié. Les RPC d'audit sont réservées au service serveur ; aucune lecture publique ou interutilisateurs.
- Le résumé d'audit survit à l'expiration de la session pendant `lector_generator_retention.audit_days` (30 jours par défaut). Il exclut audio, tokens et dossiers sportifs volumineux. Les décisions enregistrées et leurs preuves gardent leur cycle de conservation existant.
- Les coûts sont estimés à partir des reçus de tokens ; ce ne sont pas des montants facturés.

## Désactivation et retour arrière

1. Mettre `LECTOR_GENERATOR_CANARY_ENABLED=false` : les nouvelles demandes sont routées vers `lector-generator`. Ne pas supprimer les conversations, préparations ou tickets. Une demande IA déjà réservée peut terminer ; utiliser son annulation existante si nécessaire.
2. Restaurer l'alias du précédent build Flutter. Conserver l'artifact et la révision backend précédents pour redéployer un couple compatible.
3. Garder les lecteurs d'archives tant que des objets A–D peuvent exister. Si une RPC remplacée doit être restaurée, utiliser sa définition et ses ACL capturées avant migration, dans une migration compensatrice enregistrée. Ne pas effacer le journal ni lancer de `db reset` en production.
4. Conserver les audits/décisions et les objets de diffusion immuables. Une collecte hockey ratée ne doit pas renouveler artificiellement `capturedAt` : la publication précédente reste vérifiable et le garde de 36 h reste actif. Le contrôle horaire doit rester en service pendant le retour arrière.

## Limites explicites du premier accès

Football et hockey possèdent des parcours locaux vérifiés. La validation connectée sur une publication hockey fraîche attend son renouvellement autorisé. Les marchés hockey pris en charge restent ceux existants à 60 minutes ; prolongation/tirs au but ne sont pas assimilés à ce règlement. Totaux/joueurs et règlement automatique hockey ne sont pas ajoutés par cette livraison. Les mesures sur téléphone réel restent à effectuer ; un benchmark VM ou une capture Flutter ne mesure pas une latence réseau mobile.
