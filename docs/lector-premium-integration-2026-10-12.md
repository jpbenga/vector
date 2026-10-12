# Lector — intégration du design validé, 12 octobre 2026

## Périmètre

La validation utilisateur de la composition corrigée autorise son intégration dans les écrans réels et la publication sur la démo habituelle. La référence reste la maquette Pour moi, avec les instructions écrites prioritaires : navigation en haut, sans halos ni métriques fictives.

## Composants

| Élément | Travail réalisé |
| --- | --- |
| Header multisport | Une ligne : logo, sport, Shortlist, compte, réglages. Le menu des réglages conserve l’accès au thème. |
| Navigation | Cinq onglets géométriques égaux ; une seule sélection ; identités Radar/Générateur permanentes. |
| Cards football et hockey | Même LectorCompactMatchCard ; adaptateurs de présentation propres au sport. |
| Forme | RecentFormStrip partagé ; au plus cinq résultats réels, ancien → récent ; périmètre explicite. |
| Lectures et scénarios | Sélection personnelle existante conservée ; badges compacts et panneaux dépliables pour les détails. |
| Joueurs Radar | Historique et cellules existants conservés. Une contribution confirmée reste visible lorsque le panneau est fermé. |
| Live et terminé | Scores réels et badges existants ; synthèse du résultat directement visible. Les anciennes cotes sont retirées des rencontres terminées. |
| Shortlist | Pictogramme de collection partagé ; mêmes contrôleurs et opérations serveur ; pas de message de succès ajouté. |
| Briefing européen | Module conditionnel dans Tous ; nombre réel de rencontres Champions League ; compteurs fondés sur les lectures existantes ; vue dédiée avec retour. |

Nouveaux éléments d’intégration : LectorSportHeaderScope, LectorMatchSupplement, compact_hockey_match_adapter.dart et EuropeanEveningBriefing. Les composants de la première validation — tokens, header compact, navigation, card, forme et adaptateur football — sont réutilisés.

Le wrapper SportFixtureCard conserve son fallback pour les consommateurs génériques non adaptés. Les workspaces football et hockey utilisent la nouvelle card. Aucun autre sport n’est inventé.

## Assets intégrés

Seulement trois fonds européens originaux :

- assets/backgrounds/competition-champions-original-v1.png
- assets/backgrounds/competition-europa-original-v1.png
- assets/backgrounds/competition-conference-original-v1.png

Les autres compétitions utilisent leur logo fourni et un fond générique. Inter est auto-hébergée avec sa licence OFL. Les photos de trophées et visuels officiels fournis comme inspiration ne sont pas copiés. La provenance est documentée dans lector-european-assets-2026-10-12.json.

## Données et comportements conservés

Les adaptateurs reçoivent les faits déjà disponibles. Ils ne calculent pas de nouvelles lectures ni de nouveaux classements. Le périmètre football reste conservateur : compétition par défaut, championnat seulement lorsqu’il est explicitement disponible. Un match européen sans deux contextes domestiques publiés affiche sa forme de compétition, même si elle est incomplète.

Au hockey, l’ordre extérieur/domicile est conservé et les libellés le précisent. Les cellules 1/N/2 restent associées au domicile/nul/extérieur. Elles utilisent le sélecteur de marchés existant, la même cohérence de bookmaker et les mêmes règles de fraîcheur. Le marché trois issues est précisé « 60 min ». L’absence de cote ou de forme vérifiée est affichée sans remplacement inventé.

## Validation locale

- 71 tests ciblés réussis : navigation, calendrier, profils, Radar, cotes hockey, briefing et captures intégrées.
- 23 tests du design system réussis après remplacement de la transparence directe par le token central identique.
- flutter analyze : No issues found ; formatage, analyse et suite complète Flutter confirmés par CI sur le commit final.
- Rendus des vrais workspaces à 320, 375, 390, 430 et 768 px ; configuration supplémentaire 320 px, thème clair, texte 1,5×. Aucun débordement signalé.
- Navigateur réel à 390 et 320 px : vrais logos, cards Champions League, ouverture de fiche, retour, changement de sport, scores finaux et état hockey sans cotes.
- Le Générateur reste accessible depuis la navigation et conserve le contexte de sport. Aucun prompt payant n’est envoyé pour ce chantier visuel.

Le premier passage CI de l’intégration a validé 913 tests et échoué uniquement sur le garde-fou des tokens de transparence. Les sept usages concernés sont remplacés par AppColors.transparent, dont la valeur est identique. Le passage [CI #210](https://github.com/jpbenga/vector/actions/runs/38219228156) est ensuite réussi sur `fe0d33aab0152bd1e5a58402e1ac7d81054262f2` : Flutter et supabase-functions sont tous deux verts.

## Captures

### Pour moi — écran réel, préférences locales de validation

Snapshot public archivé Hull City–Everton, 11 octobre. Le compte de test sélectionne Forme en baisse et Dynamique positive : deux lectures personnelles réellement présentes. Les initiales remplacent les logos réseau dans le rendu Flutter de test ; les logos réels sont vérifiés séparément dans le navigateur. Aucune session personnelle distante n’est modifiée.

![Pour moi intégré](/Users/chloe/.codex/visualizations/2026/09/16/01a0aaf1-05e5-7562-8f19-7332ea8701f5/lector-integrated-for-me-390.png)

### Tous — écran réel, snapshot public archivé

Une rencontre Champions League dans ce jeu de contrôle. Les groupes pays et compétition sont ouverts par leurs interactions normales. Le comportement de repli initial est conservé dans l’application.

![Tous intégré](/Users/chloe/.codex/visualizations/2026/09/16/01a0aaf1-05e5-7562-8f19-7332ea8701f5/lector-integrated-all-390.png)

### Card Champions League — navigateur et données publiées

![Champions League](/Users/chloe/.codex/visualizations/2026/09/16/01a0aaf1-05e5-7562-8f19-7332ea8701f5/lector-integrated-champions-390.png)

### Card de championnat — navigateur et scores finaux

![Premier League](/Users/chloe/.codex/visualizations/2026/09/16/01a0aaf1-05e5-7562-8f19-7332ea8701f5/lector-integrated-league-390.png)

### Hockey — même composant et disponibilité explicite

![Hockey](/Users/chloe/.codex/visualizations/2026/09/16/01a0aaf1-05e5-7562-8f19-7332ea8701f5/lector-integrated-hockey-390.png)

## Éléments non modifiés

- Algorithmes de lecture, de classement, de forme et d’évaluation.
- Règles de paris, calculs de tickets, gains et mises.
- Architecture, outils, modèles, mémoire et cache du Générateur.
- Collecteurs, cadence de publication, tables, migrations, sécurité et fonctions Supabase.
- Personnalisation Pour moi, stockage des préférences et séparation des comptes.
- Stockage et expiration Shortlist, suppression individuelle, comparaison et préparation de tickets.
- Routes de fiche match, données des onglets, historique des joueurs et attribution des événements.
- Calendrier, filtres, rafraîchissement et panneaux métier existants.
- Contenu du Bilan et de la conversation.

## Limites

Les vérifications mobiles sont effectuées dans le navigateur et par rendus Flutter, pas sur un iPhone physique. Les captures archivées sont clairement distinguées des données publiées lues dans le navigateur. La fidélité vise la composition approuvée, sans reproduire les halos ni la barre inférieure interdits. La disponibilité des cotes, des résultats de forme et des lectures dépend des publications existantes ; cette refonte ne comble pas les données manquantes.

## Publication

Le paquet release est reconstruit à partir de `fe0d33a` après réussite de CI. Compilation finale réussie en 396,9 secondes ; le paquet et ses assets sont contrôlés par le script de livraison existant, sans collecte fournisseur.

Vercel confirme **READY** pour `dpl_AFsUT25xeAJSZzUgvo2etkB4WzkB`. L’alias [démo habituelle](https://lector-sports-demo-lector1.vercel.app/) pointe vers [ce déploiement](https://lector-sports-iuc35x0o8-lector1.vercel.app/). L’ouverture neuve du lien habituel atteint Lector en mode invité sans écran Vercel. Le 13 octobre affiche 19 rencontres dans trois compétitions, dont neuf Champions League ; les nouvelles cards, logos, cotes publiées et formes incomplètes sont visibles. La connexion Lector reste nécessaire pour les fonctions personnelles.

Le premier essai CLI a retourné « Not authorized ». La connexion au compte et l’accès au projet ont été confirmés ; la nouvelle tentative a réussi. Aucun changement de protection ni de droits d’accès n’a été appliqué dans ce chantier.

![Tous — démo publiée](/Users/chloe/.codex/visualizations/2026/09/16/01a0aaf1-05e5-7562-8f19-7332ea8701f5/lector-premium-demo-tous-390.png)

![Cards — démo publiée](/Users/chloe/.codex/visualizations/2026/09/16/01a0aaf1-05e5-7562-8f19-7332ea8701f5/lector-premium-demo-cards-390.png)

Le reçu technique est conservé dans `lector-premium-integration-delivery-2026-10-12.json`. Les onglets et le serveur de vérification sont fermés et la taille du navigateur est restaurée.
