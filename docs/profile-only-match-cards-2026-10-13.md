# Cartes : lectures retenues par le profil — 13 octobre 2026

## Audit et règle de présentation

Les cartes football pouvaient utiliser des lectures serveur sans personnalisation lorsque l’adaptateur était appelé directement. Le composant commun ajoutait aussi les arguments de la thèse aux signaux sélectionnés, et comptait ces arguments comme des lectures. Une donnée d’appui pouvait ainsi devenir un badge distinct alors qu’elle n’était pas choisie dans les préférences.

Les badges de lecture et de scénario des cartes utilisent désormais exclusivement les signaux retenus par la personnalisation. Les résultats de détection serveur, arguments de thèse et résumés de thèse ne servent plus de secours. Les rencontres hors profil ne présentent pas de lecture. Une lecture sélectionnée et détectée reste visible ; il n’existe pas de liste noire générale de l’avantage au classement.

Le compteur vient des lectures personnalisées, jamais du nombre d’arguments bruts. Les scénarios sélectionnés gardent leurs badges sans promouvoir leurs preuves en lectures autonomes.

## Autres cartes et panneaux

- Football : les panneaux de joueurs des cartes exigent une lecture joueur retenue par le profil courant.
- Hockey : les évaluations restent filtrées par les préférences existantes. Les panneaux de joueurs sans lien avec une préférence de lecture ne sont plus ajoutés automatiquement aux cartes.
- Shortlist : le compteur hydraté contient toutes les lectures publiées, sans périmètre utilisateur. Son badge et le message « Lectures à actualiser » sont retirés des tuiles.
- Le composant partagé utilise un `Wrap` sans `Expanded` autour des badges. Leur largeur suit le texte, l’icône et les marges ; les badges passent à la ligne lorsque nécessaire.

Les horaires, scores, équipes, formes, cotes, filtres et actions de navigation ne sont pas modifiés. Les données d’analyse serveur et les règles de détection restent disponibles pour les autres fonctionnalités.

## Vérification ciblée

Contrôles dédiés : source publiée sans profil, sélection de lectures réelles via le repository, arguments non sélectionnés, scénario sélectionné sans lectures autonomes, retrait de profil, panneaux joueurs, largeur des badges à 320/375/390/430/768 px et conservation des interactions live. Les tests de Shortlist et de connexion/déconnexion du Radar sont adaptés à la nouvelle règle.
