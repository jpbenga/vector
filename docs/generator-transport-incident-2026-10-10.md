# Réponse perdue dans le Générateur — 10 octobre 2026

## Exception visible

La capture de l’utilisateur affiche `ClientException: Load failed` pour l’URL
de `lector-generator-workshop`. Le client HTTP web transmet ainsi un échec de
`fetch` du navigateur. Cette exception ne contient aucun statut HTTP : elle ne
permet pas, seule, de conclure à un timeout du serveur, à une perte de réseau ou
à un problème de CORS.

## Éléments vérifiés

- Une requête du compte concerné démarre à 19:37:10, heure de Paris.
- Son traitement échoue après environ 131 secondes. L’invocation se termine
  à 19:39:21 avec HTTP 504 et `EDGE_FUNCTION_ERROR`.
- L’enregistrement serveur indique `TimeoutError: Signal timed out`.
- Le texte original de cette requête échouée n’est pas enregistré. Le lien
  avec la demande figurant dans la capture reste donc temporel, sans preuve
  permettant de confondre les deux exceptions.
- Le contrôle actuel de prévol CORS retourne HTTP 200 et autorise l’origine,
  POST et les en-têtes nécessaires. Il ne prouve pas que la réponse reçue au
  moment de l’incident avait ces mêmes en-têtes.

La cause précise de l’échec de réception sur l’iPhone n’est pas établie.

## Correction

Après une exception de connexion ou l’expiration de l’attente cliente, le
client recherche automatiquement le résultat de la même requête : jusqu’à
dix lectures, avec espacement progressif et une durée maximale de deux
minutes. Il ne renvoie jamais automatiquement le message ni une nouvelle
génération payante.

La réponse est celle enregistrée pour les mêmes identifiants d’utilisateur,
de conversation et de requête. Une réponse plus récente ne peut pas la
remplacer. L’expiration ou la suppression de la conversation empêche sa
récupération. Les contrôles ordinaires d’avancement ne téléchargent pas la
réponse complète.

Si le serveur a confirmé un échec, ce dernier reste affiché comme tel. Si la
connexion ne permet toujours pas de récupérer le résultat, le texte explique
l’interruption sans exposer l’exception technique ni l’URL Supabase.

Cette correction ne transforme pas un traitement serveur échoué en succès.
Les corrections de volume de contexte et de réserve de temps sont décrites
séparément dans `generator-incident-2026-10-10.md`.

## Vérification

Les tests simulent une réponse perdue, des erreurs réseau intermittentes,
un échec serveur, l’épuisement des tentatives, un ancien backend, les actions
à ne pas rejouer, le contrôle des identifiants et l’expiration de session.
Ils ne lancent aucun appel OpenAI. L’incident physique sur iPhone n’a pas été
reproduit pendant ces tests.
