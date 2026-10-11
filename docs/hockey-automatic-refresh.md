# Publication automatique du hockey

## Parcours

1. Le workflow `refresh-hockey.yml` récupère la branche `codex/multisport-hockey` et exige une CI réussie sur le commit exact.
2. Le collecteur interroge les sept ligues via `hockey-collection-provider`. La clé du fournisseur reste dans Supabase. Chaque appel réserve le quota hockey partagé.
3. Le cache GitHub conserve les enrichissements suivant leur durée de validité. Les résultats des rencontres et le calendrier sont actualisés.
4. Le moteur Dart calcule les lectures avant publication.
5. La publication canonique est relue anonymement et ses rencontres, lectures et cotes sont vérifiées.
6. Les fichiers de journée, de Radar et de détail sont déposés sous des chemins immuables dans `lector-feed-delivery`.
7. `hockey_delivery_publish` bascule les pointeurs de toutes les journées dans une transaction, uniquement si la collection correspond encore à la source canonique actuelle.
8. Le workflow vérifie le pointeur public et la liste complète des rencontres du jour. Un reçu conserve couverture, durée et nombre d'appels fournisseur.

La démo utilise ces pointeurs serveur. Actualiser les données ne nécessite donc pas de reconstruire l'interface sur Vercel ni de laisser le Mac allumé.

## Opérations

- `install` : migration et service privé, une seule fois. Vérifie que les visiteurs ne peuvent pas collecter ni publier.
- `delivery-only` : prépare la diffusion depuis la publication canonique déjà vérifiée, sans appel fournisseur.
- `refresh` : collecte, enrichissement, lectures, publication et diffusion complète.

Le workflow existant `deploy-supabase.yml`, lancé sur la branche hockey, expose ces opérations sous les noms `hockey-refresh-install`, `hockey-refresh-delivery` et `hockey-refresh-run`.

GitHub exécute les tâches planifiées depuis sa branche par défaut. L'activation à heures fixes exige donc que **le seul fichier** `refresh-hockey.yml` soit aussi présent sur `main`. Ce fichier récupère ensuite la branche hockey ; il ne fusionne pas l'application multisport dans l'application principale.

## Fréquence et limites

Le programme prévu est `00:35 UTC` et `12:35 UTC`, soit deux exécutions par jour. GitHub peut retarder le démarrage d'une tâche planifiée.

- Sept ligues : IDs 57, 58, 35, 10, 18, 16 et 47.
- Quota partagé : 7 500 appels fournisseur par jour ; le plafond du live reste distinct.
- Les tâches complètes sont sérialisées. Une exécution échouée ne remplace pas la dernière diffusion valide.
- Les erreurs fournisseur temporaires ont un nombre borné de tentatives ; le collecteur ne poursuit pas avec une réponse d'erreur déguisée en collection vide.
- La validité de 36 heures reste appliquée. L'horodatage d'une ancienne collection n'est jamais modifié pour masquer son âge.
- Aucun appel OpenAI dans ce parcours.
- Le live et les cotes conservent leurs collecteurs existants.

## Sécurité

Les identifiants Supabase existants sont récupérés seulement dans le runner GitHub. Le fichier d'environnement temporaire est protégé et supprimé en fin d'exécution ; il n'entre ni dans le cache ni dans les artefacts.

Le pont fournisseur exige le secret de synchronisation serveur, valide strictement les routes, paramètres et ligues, et ne permet ni SQL libre ni écriture utilisateur. Le RPC de publication est réservé à `service_role`. Le contenu public est le flux sportif déjà prévu pour l'application.

## Validation du déploiement

Consulter `hockey-refresh-receipt.json` dans les artefacts GitHub : il contient le commit, la collection, les sept compétitions, les rencontres couvertes, la durée et les appels fournisseur. Le succès du workflow confirme aussi la correspondance entre la publication canonique et les fichiers diffusés.

### Installation du 11 octobre 2026

- CI du commit `67674e1` : [succès](https://github.com/jpbenga/vector/actions/runs/38108015431).
- Migration, service privé et contrôles des permissions : [installation réussie](https://github.com/jpbenga/vector/actions/runs/38108362639).
- Première diffusion serveur : [succès](https://github.com/jpbenga/vector/actions/runs/38108493585), 503 rencontres, sept ligues, 42 rencontres le 11 octobre. Job de 1 min 37 s, sans appel fournisseur ni OpenAI.
- Interface connectée à la diffusion serveur : déploiement Vercel `dpl_6YoeBZpmt6LGiEXdB9kvdLYzLLFg`, alias public `lector-sports-demo-lector1.vercel.app`. Contrôles visuels : journée du 11 octobre, Radar et journée du 12 octobre (11 rencontres).
- Test complet avec collecte cloud : [succès](https://github.com/jpbenga/vector/actions/runs/38108765847). 503 rencontres, sept ligues, 42 rencontres le 11 octobre, 14 journées et 362 fichiers diffusés. Premier remplissage sans cache : 3 476 appels fournisseur, 38 min 58 s pour le job (2 308,5 s de traitement), zéro appel OpenAI. Collection `8b55ce2d-fe19-4a7c-a958-2a25f909d036`, capturée le 11 octobre à 03:34:18 UTC.
- Cache enregistré : `hockey-enrichment-v1-Linux-38108765847`. Le workflow suivant dispose d'une marge de 60 minutes et sauvegarde les réponses validées même si une vérification de publication échoue. La durée d'un passage avec cache reste à mesurer ; le premier test ne la prouve pas.

L'installation et ces lancements manuels ne prouvent pas l'activation à heures fixes. Celle-ci dépend de la présence du fichier de planification sur `main`, soumise à l'accord spécifique demandé après refus de la revue automatique.
