# Connexion Google de l’aperçu multisport local

## Diagnostic confirmé

L’aperçu compilé est servi sur `http://localhost:8191/` et envoie ce même port dans `redirectTo`.
La configuration Auth Supabase lue via l’API de gestion indiquait :

- Google activé ;
- Site URL : `http://192.168.0.46:8099/` ;
- ports locaux autorisés : 8099 et 8100 ;
- port 8191 absent.

Le retour signalé par l’utilisateur sur l’ancienne adresse LAN est cohérent avec le repli de Supabase vers Site URL lorsqu’une adresse demandée n’est pas autorisée. Le fournisseur Google lui-même était accessible : la route authorize renvoyait HTTP 302 vers accounts.google.com avec le callback Supabase du projet.

## Réparation de la configuration distante

Après autorisations explicites de l’utilisateur pour la lecture puis la modification : ajout de `http://localhost:8191/**` et `http://127.0.0.1:8191/**`. PATCH HTTP 200, puis nouvelle lecture de contrôle réussie.
Toutes les adresses précédentes et les autres réglages ont été conservés.
Le jeton de gestion a été utilisé en mémoire uniquement auprès de l’API officielle Supabase ; aucune clé ni code OAuth ne figure dans ce rapport.

## Parcours commun

Le bouton du hockey ouvrait un message demandant de se connecter ailleurs. Le formulaire de compte existant du football a été extrait dans `lib/app/auth/lector_account_sheet.dart`, puis branché au bouton hockey. Les deux disciplines utilisent maintenant ce même formulaire, les mêmes contrôleurs de compte et les mêmes méthodes de connexion Google / e-mail.

## Vérifications

- Deux tests hockey : ouverture du vrai formulaire partagé, déclenchement Google, connexion e-mail.
- Deux tests football existants : formulaire invité et compte connecté.
- Tests de construction des adresses OAuth, dont le chemin hockey sur le port 8191.
- Huit tests ciblés réussis au total (connexion hockey, compte football, adresses OAuth).
- Flutter analyze : aucune anomalie.
- Formatage des fichiers modifiés et git diff --check propres.

La connexion personnelle complète chez Google doit être retestée par l’utilisateur depuis l’aperçu à jour ; aucun mot de passe ni session personnelle Google n’a été utilisé pendant les tests.

- Compilation web réussie en 104,9 secondes ; formulaire hockey vérifié visuellement sur localhost:8191 (bouton Google et champs e-mail / mot de passe).

## Retester

Ouvrir `http://localhost:8191/sports/hockey`, actualiser après compilation, puis ouvrir le compte et choisir Continuer avec Google. Démarrer une nouvelle connexion pour obtenir un nouveau code. Ne pas réutiliser le lien de retour d’une ancienne tentative.
