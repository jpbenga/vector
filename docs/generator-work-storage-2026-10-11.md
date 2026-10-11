# Générateur : stockage indépendant de la mémoire de travail

Correction du 11 octobre 2026, branche démo `codex/multisport-hockey`.

## Fonctionnement

- Les tickets et leurs versions sont des snapshots identifiés dans `lector_generator_ticket_drafts` ; une identité de ticket ne peut pas changer de sélections ou de mise.
- Les messages, analyses associées et décisions de chaque tour sont conservés dans `lector_generator_messages` et `lector_generator_work_turns`, indépendamment du document de travail.
- Le document de session conserve les contraintes actives, les références des objets, vingt références de messages et huit tours résumés. Les anciens messages et objets ne sont pas supprimés lorsqu’ils sortent de cette fenêtre.
- Le commit est atomique avec la révision et la réservation. Seuls les nouveaux objets sont transportés et enregistrés ; une petite demande ne retransmet pas les anciens tickets riches.
- Les sessions existantes sont adoptées au prochain commit, en archivant également les anciens objets et messages qui sortent de la fenêtre immédiate.
- L’interface ouvre les derniers messages. « Voir les échanges précédents » charge les pages antérieures sans effacer les échanges affichés ni ramener la lecture en bas.
- `read_session` retrouve les messages et tickets archivés. `read_analysis` relit une analyse, `read_work_evidence` parcourt ses preuves ou celles d’un ticket, avec pagination explicite des textes longs. Ces outils ne peuvent pas écrire.
- Les prix et arguments initiaux restent exacts. Consulter un ancien ticket n’actualise pas ses cotes et ne les rend pas admissibles pour une nouvelle composition.
- Les empreintes des compositions conservées sont relues depuis les objets archivés ; leur exclusion ne dépend pas seulement de la fenêtre récente.

## Durée et limites

Les 24 heures après activité et la durée maximale de sept jours restent des délais de conservation. Aucun nombre de demandes ne remplit un quota de stockage de conversation. Les tables de travail suivent la suppression de la session ; les décisions explicitement conservées dans Mes suivis ont leurs snapshots indépendants.

Le document compact garde la validation SQL de 250 000 caractères. Les objets détaillés ne font plus partie de ce document. Les anciens seuils de 180 000/210 000 caractères ne bloquent plus le parcours démo. Un transfert de nouveaux objets reste borné à 16 Mo par commit ; le corps d’un appel conversationnel OpenAI reste borné à 1,2 Mo. Il s’agit de limites par opération, pas d’une enveloppe qui se remplit au fil des demandes.

Les appels Responses gardent `store:false`. Le rejeu des éléments de réponse et d’outils dans un tour n’a pas été tronqué ; seule la mémoire préparée avant le tour est compacte. Référence : [documentation officielle OpenAI sur les modèles de raisonnement](https://developers.openai.com/api/docs/guides/reasoning).

## Vérification

- PostgreSQL réel embarqué : douze analyses avec des preuves de 364 000 caractères chacune, puis petite demande ; mémoire persistante inférieure à 15 000 caractères dans ce cas, preuves d’origine intactes, ancienne sélection conservable, contrôles de propriétaire, révision, expiration et nettoyage.
- Test conversationnel : un ticket avec une preuve de 700 000 caractères suivi de « Merci » ; corps du premier appel modèle inférieur à 30 000 octets, réponse acceptée. API simulée, sans facturation.
- Test de relecture : preuves de 9 000 caractères restituées exactement en trois pages, refus d’une référence étrangère.
- Interface : chargement initial, défilement, chargement des anciens échanges, saisie/vocal, récupération après interruption.
- Droits SQL : aucune lecture directe ou écriture de ces objets par `anon`/`authenticated`, lectures et commits via le serveur authentifié.

Les reçus de tours comprennent `usage.work_storage` avec taille du document compact et taille des nouveaux tickets/messages. Les reçus de modèle conservent leur suivi de tokens. Aucun test de cette correction ne nécessite d’appel OpenAI payant ni de collecte sportive.

La validation sur le compte utilisateur réel reste à effectuer après déploiement. Le format des réponses, les plafonds par demande de composition et la tarification ne sont pas modifiés par cette correction.

## Publication vérifiée

- Révision applicative : `68b719d692b7582583f38ce01b1d6faf850e3f09`.
- [CI Flutter et fonctions réussie](https://github.com/jpbenga/vector/actions/runs/38153176646) : 121 tests Deno, vérifications Flutter et analyse statique.
- [Installation serveur réussie](https://github.com/jpbenga/vector/actions/runs/38153770808/job/114512403705) le 11 octobre 2026 à 18 h 02 (Paris) : migration et fonction `lector-generator-workshop` actives, accès anonyme refusé avec HTTP 401, droits directs utilisateurs refusés, lecture serveur autorisée.
- Empreinte SQL : `b2876e741f1f52fa0504100359c2c4792df855332a6b94e912f779c721428584`.
- Reçu d'installation : zéro appel modèle payant, zéro appel fournisseur sportif, aucun changement de secret.
- Interface Flutter compilée en release ; données de livraison et configuration Vercel existantes conservées.
- Déploiement Vercel prêt : `dpl_ECFsmsjnGv1ejNu8L4dxUryxkKzz`, `https://lector-sports-2vp589vsh-lector1.vercel.app`.
- Alias public actualisé : [démo Lector](https://lector-sports-demo-lector1.vercel.app/).
- Vérification navigateur : l'alias public ouvre Lector et son Générateur sans écran d'authentification Vercel. La conversation d'un compte connecté n'a pas fait l'objet d'un nouvel appel modèle réel.
