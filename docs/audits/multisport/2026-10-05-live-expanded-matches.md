# Toutes les rencontres Live visibles

## Comportement

Les sections En direct affichent toutes les rencontres admissibles de la date
choisie dans Pour moi et Tous, pour le football et le hockey. Cette règle
s'applique également à la section En direct visible sous le filtre temporel
Tous. Elle ne modifie pas la sélection personnalisée ni les lectures.

- Tous : pays et ligues sont forcés ouverts, sans commande de repli.
- Pour moi football : toutes les cartes de chaque ligue sont visibles, sans
  bouton Afficher les autres matchs/Réduire.
- Pour moi hockey : conserve ses cartes déjà toutes visibles.
- Les autres phases gardent leur comportement de dépliage habituel.
- Radar n'est pas modifié.

Le composant commun `LectorCompetitionGroup` reçoit `forceExpanded`. Ce mode
ne remplace pas l'état d'ouverture manuel utilisé hors Live. Les adaptateurs
football et hockey transmettent cette propriété pour la phase Live fournie
par `LectorTemporalFeed`.

## Vérification

Six tests ciblés réussis : quatre parcours avec plusieurs matchs et ligues,
le dépliage manuel habituel du football hors Live et la transition du dernier
match Live vers les rencontres terminées. Les tests hockey utilisent une
publication d'avant-match avec une surcouche de scores Live, conservant la
sélection par lectures et compétitions.

Travail local sur `codex/multisport-hockey`, sans push ni déploiement.
