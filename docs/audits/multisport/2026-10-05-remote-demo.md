# Démonstration multisport distante

## Parité du détail et résultats — 5 octobre, 17:24 UTC

La démo corrigée est publiée sous `dpl_ZfBmBAXTuZHcY5kLTU5fLrGBFBeq`
(Vercel `READY`), avec les composants communs Contexte/Forme/analyse des lectures
et une nouvelle collecte réelle des sept ligues (491 rencontres, collecte
`2026-10-05T17:08:08.900Z`). L'adresse stable reste :

https://lector-sports-demo-lector1.vercel.app/sports/hockey

Le résultat Magnitogorsk 2–5 Vladivostok / `FT` est présent. Le collecteur distant
hockey est développé et testé, mais son installation/activation Supabase attend
l'accord explicite demandé après refus de la revue automatique. Cette publication
ne doit donc pas être décrite comme un live automatique hockey déjà actif.
Détails : `2026-10-05-detail-parity-hockey-live.md`.

## Retour de connexion distant — 5 octobre

Le dashboard Supabase confirme que l'origine du nouveau déploiement manque
dans les retours autorisés. Le `Site URL` est encore
`http://192.168.0.46:8099/` : il devient la destination de repli lorsque le retour
demandé n'est pas autorisé. Cela explique le retour Google vers le réseau local.
Le code compilé demande bien l'origine courante ; le problème identifié est
la configuration d'authentification, pas une adresse LAN embarquée dans le build.

Vercel a confirmé l'attribution de l'adresse stable suivante au déploiement
`dpl_29dtTeakBDnqU3z4AZz6VAyY6FhC` :

https://lector-sports-demo-lector1.vercel.app/sports/hockey

Après accord explicite de l'utilisateur, les deux retours suivants ont été
enregistrés dans Supabase :

- `https://lector-sports-demo-lector1.vercel.app/**`
- `https://lector-sports-fbc1ucpk4-lector1.vercel.app/**`

Après rechargement du dashboard, les deux adresses sont présentes et le total
passe de 12 à 14. Les 12 anciennes adresses sont conservées. Le `Site URL`
reste l'adresse LAN : son remplacement n'a pas été autorisé dans cette étape.
Le parcours Google complet doit être recommencé depuis l'adresse stable par
l'utilisateur ; un ancien code de retour n'est pas réutilisable pour ce test.
La configuration a été vérifiée, pas une connexion Google de bout en bout.

## Actualisation des lectures hockey — 5 octobre, 13:40 UTC

Publication autorisée par l'utilisateur : « Oui actualise la demo que je puisse explorer ».
Le véritable build de `codex/multisport-hockey` contient maintenant les trois
lectures fonctionnelles, la sélection des compétitions/lectures et les préférences
isolées par identité et sport. Compilation release réussie en 69,9 secondes.
Le compact intégré est toujours la collecte du 4 octobre à 19:58:28 UTC
(475 rencontres, sept ligues). Aucun nouvel appel fournisseur n'a été effectué.
Les valeurs privées du `.env` ont été recherchées dans l'artefact avant envoi :
aucune n'y figure ; seul le compact et la configuration publique sont embarqués.

Nouvelle adresse :

https://lector-sports-fbc1ucpk4-lector1.vercel.app/sports/hockey

Vercel a confirmé `READY` pour `dpl_29dtTeakBDnqU3z4AZz6VAyY6FhC`.
Commande : `vercel deploy build/multisport-demo --target preview --yes`.
La protection existante `vercel_authentication` est conservée. Aucune promotion
en production, aucun push main et aucune opération Supabase n'ont été effectués.
Le site distant n'a pas été interrogé après publication, conformément au skill
de déploiement ; la confirmation vient du résultat Vercel.

Pour explorer : Hockey → Configurer mon hockey → choisir KHL et les lectures,
puis enregistrer. Exemple : Vladivostok → Magnitogorsk le 5 octobre.
Cette configuration est possible en invité Lector. Les préférences restent locales
au navigateur et à cette nouvelle origine, donc les choix de l'ancien aperçu
ne sont pas automatiquement repris. Le retour Google sur cette nouvelle origine
n'a pas été configuré ni testé dans cette publication.

Les sections suivantes conservent l'historique de la première publication.

Branche : `codex/multisport-hockey`. Aucun changement de cette étape n’a été
publié sur main et aucun collecteur hockey n’a été installé sur Supabase.

## Artefact prêt

`python3 tool/build_multisport_demo.py` compile le véritable `lib/main.dart`
en mode staging dans `build/multisport-demo`, avec les deux disciplines et
la configuration publique Supabase du football. Le dossier de sortie contient
uniquement le site compilé et le compact public hockey, sans `.env`, brut
fournisseur ni clé serveur. Les clés privées du `.env` ont été recherchées dans
l’artefact : aucune n’y figure.

La publication hockey est celle du 4 octobre 2026 à 19:58:28 UTC : 475 rencontres,
7 ligues, 815 profils joueurs, fenêtre du 27 septembre au 17 octobre. Il s’agit
d’une copie de collecte consultable sans le Mac ; elle n’est pas un collecteur
automatique distant. Les timestamps d’origine sont conservés.

`SPORT_FEED_DEMO=true` fait lire `/sports/hockey/feed` sur l’origine du site.
Ce mode est refusé en production. Le transport HTTP local précédent reste
inchangé. La réécriture Vercel sert le compact avant la route SPA.
La connexion construit son retour à partir de l’adresse courante du navigateur ;
aucune ancienne adresse LAN ou localhost n’est compilée dans cette version.
L’adresse de prévisualisation est autorisée dans les retours OAuth Supabase ;
les adresses existantes et l’URL par défaut ont été conservées et vérifiées.

## Vérifications

- 15 tests ciblés réussis : configuration staging, isolation production,
  publication multi-ligues et radar joueurs.
- `flutter analyze` : aucune anomalie.
- Compilation release réussie en 70,4 secondes.
- Compact sans clé d’authentification ; environ 637 Ko compressés.

## Publication effectuée

La connexion CLI a été validée par l’utilisateur. Vercel a confirmé le statut
`READY` du déploiement de prévisualisation `dpl_CaMZQ1TW7Lxqd2rtNgyHSpC2nYaS` :

https://lector-sports-lqtfp8323-lector1.vercel.app/sports/hockey

La protection Vercel existante exige une connexion au compte Vercel pour
consulter cet aperçu. Aucun réglage de protection du projet n’a été modifié.
La publication n’a pas été promue en production. Le checkout football main
reste propre au commit `2a08e04690b84beb4c9894fa342914c122bd3e52`.
La disponibilité est confirmée par le statut Vercel ; le parcours navigateur
sur cette adresse n’a pas été testé après publication.
