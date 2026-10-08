# Livraison progressive des flux publics

## Contrat

- L'accueil lit un manifeste léger puis un JSON préconstruit de la journée.
- Le radar charge sa publication complète uniquement lorsque cet onglet est ouvert.
- Le détail charge un contexte de compétition et les faits complets du match en parallèle.
- Préférences, personnalisation et état live restent séparés des objets publics.
- Les lectures football calculées côté serveur et les faits des lectures hockey sont conservés. Aucun nouveau calcul sportif n'est introduit dans le transport.
- Les objets sont immuables, les références relatives sont validées, aucun jeton de compte n'est nécessaire pour les lire.
- En cas d'erreur temporaire, les dernières données valides sont conservées ; une réponse réellement absente demeure distincte.

## Préparation serveur (non activée par défaut)

1. Installer `20261007213000_feed_delivery.sql` et déployer `build-feed-delivery` avec le contrôle du secret serveur intégré.
2. Déployer les producteurs de publications modifiés. Activer le secret serveur `FEED_DELIVERY_ENABLED=true` seulement après installation du stockage et de la migration.
3. Les prochaines analyses football, y compris celles réutilisant une publication déjà calculée, enregistrent leurs fichiers et références. La collecte hockey enregistre sa publication atomique.
4. Après vérification des sources attendues, activer le sport dans `sport_feed_delivery_jobs`. Le cron reconstruit les journées -7 à +13 toutes les cinq minutes seulement si la révision a changé. Il ne contacte jamais API-Sports.
5. Vérifier les manifestes et leurs objets avant de publier le frontend. Jusqu'à installation des références, le frontend garde le lecteur existant.

Une nouvelle source invalide une reconstruction en cours. Une erreur d'upload ne remplace jamais les références précédentes. L'activation SQL seule ne remplit pas un historique absent : la disponibilité des journées dépend des publications déjà enregistrées.

## Démo statique

`tool/fetch_public_delivery_sources.py` exporte uniquement des publications publiques, sans clé fournisseur ni secret serveur. `tool/build_multisport_demo.py` produit le frontend et les objets du CDN de démonstration.

La démo optimise les journées -7 à +13 dès que leurs publications sources existent. Pour les archives football, chaque journée utilise les sources disponibles à la fin de cette journée en heure de Paris : aucune lecture calculée ultérieurement n'est injectée. L'export pagine les métadonnées et produit un index ; le constructeur lit les archives individuellement. Seuls les détails correspondant aux journées sélectionnées, leurs contextes et le radar sont publiés, sans duplication des fichiers complets football. Un historique hockey sans publication archivée conserve le lecteur existant. Le football reste sur sa branche distincte, et le hockey reste sur la branche multisport.

Les publications quotidiennes sont actuellement découpées selon le calendrier Europe/Paris du batch. Les autres décalages horaires conservent automatiquement le lecteur complet existant pour ne perdre aucune rencontre autour de minuit. Leur optimisation nécessitera de prévoir les journées voisines.

## Vérifications

- Tests Flutter du cache, manifeste, erreurs, chargement différé et parité des cartes.
- Tests des sélections de publications, de la frontière de journée avec changement d'heure, et du catalogue des marchés consommés.
- Test SQL des permissions et du rejet d'un travailleur devenu obsolète.
- Mesures de volume sur des données réelles ; elles ne constituent pas une mesure de temps réseau sur le téléphone de l'utilisateur.

## Navigation après le premier affichage

Un cache commun aux deux sports conserve les flux publics décodés (24 entrées maximum). Les retours utilisent immédiatement la version déjà chargée ; la vérification de fraîcheur se fait en arrière-plan. Les jours proches sont préchargés dans les deux directions (J+1, J-1, J+2, J-2, J+3, J-3), puis le reste de la fenêtre, puis le radar plus volumineux. Une ancienne requête qui se termine après un nouveau choix de date ne réordonne pas cette file. Le radar football actuel est partagé entre les dates futures ; les archives conservent leur sélection historique.

La file est séquentielle, limitée aux dates disponibles et annulée lorsque l'écran quitte le sport. Une journée non encore préchargée peut toujours nécessiter une attente lors de sa première ouverture. Les préférences sont appliquées à chaque affichage et ne font pas partie du cache public. Les scores live gardent leur contrôleur indépendant.

Pour republier seulement le frontend de démo sans exporter les publications ni lancer une collecte : `python3 tool/build_multisport_demo.py --reuse-delivery`.
