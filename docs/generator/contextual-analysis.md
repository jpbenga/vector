# Hector : analyse contextuelle (démo multisport)

## Parcours

1. Interpréter la demande et conserver les contraintes de la conversation :
   journée, sport, écran (`Pour moi`, `Radar`, `Tous`), nombre demandé.
   Une analyse ou un top de rencontres ne nécessite pas de mise.
2. Charger les publications filtrées du serveur. `Pour moi` exclut les
   compétitions non suivies ; la demande ne modifie pas les préférences.
3. Donner à l'IA une vue compacte de **toutes** les rencontres admissibles de ce
   périmètre, avec les observations et marchés autorisés disponibles.
4. Laisser l'IA consulter `get_match_details` sur les rencontres envisagées :
   soutien au marché précis, Radar, échantillons, contradictions, fraîcheur et
   sources. Les identifiants sont contrôlés côté serveur. Aucun accès libre à
   Supabase, à un autre compte ou à une URL fournie par le modèle.
5. Produire une comparaison naturelle et des sélections structurées. Chaque
   sélection doit être une cote réelle du catalogue, sur une rencontre distincte,
   dont les détails ont été consultés. Les références doivent inclure un soutien
   direct au marché. Les noms, cotes et sources des cartes viennent du serveur.
6. Conserver le résultat et son contexte pour les questions suivantes, sans
   créer de ticket ni modifier les compositions précédentes.

La construction des tickets conserve son moteur de variantes et ses contraintes.
L'IA dispose maintenant aussi des sélections et de leurs données pour expliquer
naturellement les compromis, plutôt que de choisir uniquement des phrases fixes.

## Expérience

L'interface montre les étapes **exécutées** sur le serveur, le périmètre et le
nombre de rencontres. Elle reçoit, lorsqu'il existe, le résumé d'analyse fourni
par l'API OpenAI. Le raisonnement privé n'est ni demandé pour affichage ni exposé.
Le texte final et les cartes apparaissent après contrôle du contrat.
Les cartes utilisent les composants et la fiche de sélection Lector existants.

## Appels et mesures

- Modèle de démo : modèle validé dans la paire autorisée, Sol prioritaire.
- Interprétation : effort `low` ; analyse et comparaison : effort `medium`.
- Analyse : boucle Responses avec streaming, un outil contrôlé, trois réponses
  au maximum et échéance globale de 80 secondes. Ce sont des limites techniques,
  pas un plafond commercial de dépenses. Aucune relance payante automatique.
- Chaque appel conserve son usage, ses tokens de raisonnement, durée et estimation
  de coût (plage si les écritures du cache ne sont pas détaillées).
- Comparaison Sol/Luna sur données synthétiques dans GitHub Actions ; pas de
  deuxième modèle invisible dans chaque requête utilisateur.

## Limites explicites

Une rencontre sans marchés/cotes collectés peut être commentée, mais ne devient
pas un pari inventé. Cela concerne notamment les publications hockey actuelles.
Les publications absentes ou périmées ne sont pas remplacées par la mémoire du
modèle. Le Bilan reste descriptif. Forme, séries et Radar peuvent réutiliser les
mêmes résultats : le nombre de signaux n'est pas un nombre de preuves indépendantes.
Aucune probabilité indépendante de succès n'est annoncée.

## Vérifications

- Tests de périmètre, doublons, outils hors périmètre, références inventées,
  consultation des détails obligatoire, données absentes, annulation et SSE.
- Affichage des étapes et cartes sur écran de 320 pixels.
- Évaluation API du cas « top 5 de vendredi dans Pour moi » : six rencontres
  suivies, une avec échantillon insuffisant, une rencontre hors profil exclue ;
  puis relance demandant les cinq rencontres avec une autre date courante dans
  l'interface, pour vérifier la conservation du contexte.
- Endpoint dédié `lector-generator-workshop`, alias Vercel de démo uniquement.
  Aucune fusion multisport sur `main` ni modification de l'endpoint football.
