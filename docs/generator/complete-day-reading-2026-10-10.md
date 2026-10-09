# Lecture complète des journées — étape 1

## Contrat

Le backend démo `lector-generator-workshop` recense les rencontres de la journée
avant de lire leurs données. Il utilise deux RPC serveur, disponibles uniquement
au rôle `service_role` : `lector_generator_day_manifest` et
`lector_generator_day_page`. Les lecteurs du Générateur principal sont conservés.

Le manifeste fixe les publications et les identités `sport:id`, déduplique les
scopes football qui se recouvrent et conserve le fuseau utilisateur. Pour moi
conserve les compétitions et lectures configurées ; Radar conserve ses membres
et publications exactes ; Tous recense les rencontres publiées sans activer de
préférence supplémentaire. Les cotes et marchés restent soumis aux règles
d'admissibilité existantes.

Les pages contiennent au plus 50 rencontres. Le serveur conserve leurs données
projetées, tandis que le modèle reçoit les pages compactes de `search_matches`,
leurs totaux et `nextOffset`. Il ne reçoit ni les enveloppes des collecteurs ni
les joueurs/classements sans rapport avec les équipes de la page.

Une publication nouvelle ne remplace jamais celle fixée au début de la lecture.
Une version supprimée, une rencontre absente, dupliquée ou extérieure au périmètre
fait échouer la lecture entière. Le manifeste peut contenir jusqu'à 3 000 matchs ;
une limite atteinte déclenche une erreur explicite, aucune troncature silencieuse.
Les pages dépassant 1,5 Mo sont divisées, avec un plafond total de transport de
32 Mio. Ces bornes sont techniques, elles ne sont pas des crédits commerciaux.

## Couverture et avancement

La progression distingue les rencontres **récupérées** des rencontres
**examinées par l'IA**. Les recherches et le registre de consultation conservent
les compteurs `expected`, `loaded`, `pages`, `bytes` et `complete`. Une lecture
complète ne met aucune rencontre dans `detailsRead` et ne permet donc pas au
modèle d'affirmer qu'il a effectué une comparaison exhaustive.

Les fiches d'évaluation de chaque rencontre, leur analyse parallèle et la
comparaison globale appartiennent aux étapes suivantes. Les plafonds de dialogue
(32 consultations, 10 tours et 110 secondes) sont encore présents à cette étape.

## Vérification

Un test PostgreSQL local utilise plus de 5 Mo de publications synthétiques avec
1 100 rencontres sur deux journées : 500 football et 50 hockey par journée.
Le lecteur a récupéré **550/550**, en **11 pages**, avec **295 681 octets**
transférés et environ **1,2 seconde** de lecture locale dans le premier rejeu.
Ces chiffres excluent le réseau de production, les appels IA et la création des
fixtures de test. Ils ne préjugent pas du délai de réponse du Générateur.

Le test compare les candidats et arguments au catalogue construit à partir des
publications originales, vérifie le changement de jour à minuit dans le fuseau
Paris, les préférences, le Radar vide et la conservation des versions lors d'une
publication concurrente. Des tests supplémentaires vérifient les pages
incomplètes, la réduction automatique de taille et l'absence de confusion entre
récupération et analyse.

La publication `lector-generator-day-sources` exige la CI du commit exact sur
`codex/multisport-hockey`, installe uniquement cette migration additive, relit une
journée publique réelle et déploie le seul backend démo. Aucun appel au modèle ou
fournisseur sportif, changement de secret, cron ou profil utilisateur n'est
nécessaire à cette étape.
