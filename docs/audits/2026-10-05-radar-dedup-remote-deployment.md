# Radar des joueurs et déploiement à distance — 5 octobre 2026

## Constat de production

Lecture des snapshots publics `match_feed_analysis_snapshots` avec la clé
anonyme de l’application ; aucun appel API-Football ni lancement de batch.
Le snapshot de Ligue des Nations du 5 octobre à 05:49:12 UTC prévoit
France–Belgique et Italie–Türkiye le 5 octobre à 20:45 (heure de Paris).

Les profils du Radar étaient distincts par compétition, équipe et joueur.
Olise (19617, France 2) était présent en Ligue des Nations (5), avec un dernier
match au 2 octobre, et en Coupe du monde (1), avec un dernier match au 18 juillet.
De Ketelaere présentait le même doublon côté Belgique. Les anciennes fenêtres
pouvaient également réintroduire des joueurs absents des candidats actuels.
La carte déroulait toutes les lignes sans aperçu limité.

## Correction

- Choisir le dernier échantillon connu pour chaque équipe, à partir des matchs
  récents et des activités ; ne pas réintroduire les fenêtres plus anciennes.
- Retenir un profil par paire équipe/joueur, avant de détecter la forme. Cela
  évite de conserver un ancien profil chaud quand la fenêtre actuelle est froide.
- Conserver les contextes club et sélection séparés et identifier par ID.
- Présentation commune `LectorFormRadarSignalPanel` : quatre lignes initiales,
  nombre total, bouton pour développer et réduire toute la liste.
- Appliquer la correction au checkout football et à `codex/multisport-hockey`.

Un extrait public France–Belgique est conservé dans
`test/fixtures/france_belgium_radar_snapshot.json` : le test adaptateur → Radar
attend cinq joueurs actuels, une occurrence d’Olise et aucune fenêtre de juillet.
Les tests couvrent aussi la fenêtre froide, le joueur absent du nouvel
échantillon, les homonymes, l’ordre des sources, le développement de la liste
et les lectures du profil connecté.

## Vérifications

Tests domaine, composant, page Radar et adaptateur réussis dans les deux
checkouts. `flutter analyze` : aucune anomalie dans les deux checkouts.
Quatre tests du déploiement distant réussis (main obligatoire, fonction autorisée,
CI du commit exact et refus immédiat sans secret).
Build web release réussi ; déploiement Vercel `dpl_CuVSQxfNLV65uiZ72QaXUj8xBH4w`
confirmé `READY` en prévisualisation :

https://lector-sports-hycmo2i32-lector1.vercel.app/

Protection Vercel existante conservée. Ce nouvel aperçu peut être consulté
sans compte Lector. Son origine n’a pas encore été ajoutée aux retours Google
Supabase. L’ancienne adresse autorisée reste disponible sur l’ancienne version.
Aucun fetch du site distant n’a été effectué après publication.
L’utilisateur a approuvé le 5 octobre la publication sur main du correctif
et du workflow distant. Le chantier hockey reste dans son checkout séparé.
Le correctif Radar ne nécessite aucune migration ni modification de fonction.

## Travail distant

L’accès au jeton Supabase a été essayé avec les fenêtres du trousseau
explicitement désactivées : refus sans boîte de dialogue. Le secret GitHub Actions `SUPABASE_ACCESS_TOKEN` a ensuite été ajouté par
l’utilisateur, et sa présence a été confirmée sans lecture de sa valeur.

Le workflow `Deploy Supabase football` et son script font partie du correctif
autorisé pour publication sur main.
Il est lancé manuellement depuis main, exige une CI réussie sur le même commit,
et reçoit `SUPABASE_ACCESS_TOKEN` uniquement depuis les secrets GitHub.
Il ne cherche jamais de jeton dans le trousseau. Les fonctions disponibles
sont limitées au football. La configuration des points d’entrée utilisant
l’identité ou le secret de synchronisation est conservée (`--no-verify-jwt`).
Les migrations SQL ne sont pas appliquées par ce workflow.

Configuration initiale du secret (effectuée par l’utilisateur) :

1. Créer un jeton dédié au projet Lector (`ednvvxxvlawaagjyshkj`) dans
   https://supabase.com/dashboard/account/tokens avec les permissions
   Edge Functions en lecture/écriture et Project Settings en lecture.
2. Dans https://github.com/jpbenga/vector/settings/secrets/actions/new,
   ajouter le secret `SUPABASE_ACCESS_TOKEN` avec ce jeton comme valeur.
3. Après validation et publication du workflow sur main, lancer le workflow
   depuis GitHub Actions. Aucun mot de passe du Mac n’est nécessaire.

Pour connecter Google au nouvel aperçu, ajouter uniquement
`https://lector-sports-hycmo2i32-lector1.vercel.app/**` aux Redirect URLs dans
https://supabase.com/dashboard/project/ednvvxxvlawaagjyshkj/auth/url-configuration,
en conservant les autres adresses et la Site URL.

Références officielles :
- https://supabase.com/docs/guides/functions/examples/github-actions
- https://supabase.com/docs/guides/platform/personal-access-tokens
