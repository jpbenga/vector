# Lectures, scenarios et highlights

Ce document cartographie l'etat actuel du moteur de lectures Lector.
Il sert de base de revue avant de creer la fonctionnalite `highlights`.

Objectif du futur systeme :

- expliquer pourquoi une lecture simple a ete detectee ;
- relier chaque lecture a une ou plusieurs statistiques sources ;
- afficher ces preuves visuellement dans le detail match, les lectures combinees et les tickets ;
- eviter toute interpretation de probabilite ou de confiance predictive.

Vocabulaire recommande :

- lecture simple ;
- lecture combinee ;
- scenario ;
- element declencheur ;
- preuve statistique ;
- point de vigilance ;
- contradiction.

Vocabulaire a eviter dans l'interface :

- confiance elevee ;
- score de confiance ;
- probabilite de victoire ;
- bon pari / mauvais pari.

## Sources moteur actuelles

Les lectures simples sont produites dans :

- `lib/features/matches/domain/football_analyzer.dart`
- `lib/features/matches/domain/football_reading_rules.dart`

Les lectures combinees sont assemblees dans :

- `lib/features/matches/domain/opportunity_engine_v2.dart`

Le passage vers l'UI se fait via :

- `FootballReading`
- `ReadingEvidence`
- `CopilotArgument`
- `MatchThesis`

## Points d'attention avant implementation

### Donnees de preuve trop peu structurees

`ReadingEvidence` contient aujourd'hui :

- `label`
- `kind`
- `sourcePath`
- `value`
- `isPostMatchOnly`

C'est suffisant pour afficher une ligne de texte, mais insuffisant pour des highlights precis.
Il manque notamment :

- la cible UI exacte a surligner ;
- le cote concerne : domicile, exterieur ou match ;
- une valeur principale formatee ;
- une valeur comparee ;
- un libelle court ;
- un niveau de traitement visuel ;
- une distinction preuve favorable / vigilance / contexte.

### Asymetrie domicile / exterieur

Le moteur detecte actuellement :

- `strong_home_team`
- `weak_away_team`
- `home_away_mismatch`

Mais certains scenarios attendent aussi :

- `strong_away_team`
- `weak_home_team`

Ces ids existent cote presentation, mais ne semblent pas produits par `FootballAnalyzer`.
Ce point doit etre corrige si l'on veut que les scenarios fonctionnent proprement pour les deux equipes.

### Ancien vocabulaire encore present

Le catalogue profil contient encore des ids historiques :

- `solid_favorite`
- `cautious_double_chance`
- `open_match`
- `closed_match`
- `level_gap`

Le moteur V2 produit plutot :

- `expected_domination`
- `favorite_with_protection`
- `controlled_favorite`
- `convergent_open_match`
- `convergent_closed_match`
- `one_sided_scoring`

Il faudra clarifier ce qui est :

- une famille produit ;
- une lecture simple ;
- un scenario ;
- un id legacy de compatibilite.

## Lectures simples

### `balanced_hierarchy` - Hierarchie proche

Ce que la lecture met en evidence :

- les deux equipes sont proches au classement ;
- l'ecart de points ne cree pas de superiorite nette ;
- le match peut etre plus difficile a lire via la seule hierarchie.

Statistiques utilisees :

- rang domicile : `standings[].rank`
- rang exterieur : `standings[].rank`
- points domicile : `standings[].points`
- points exterieur : `standings[].points`

Condition actuelle :

- ecart de rang `<= 2`
- ecart de points `<= 4`

Highlight attendu :

- bloc classement ;
- rangs des deux equipes ;
- ecart de places ;
- ecart de points ;
- traitement neutre / contexte.

### `ranking_superiority` - Avantage au classement

Ce que la lecture met en evidence :

- une equipe possede un avantage visible au classement ;
- l'avantage peut venir des places, des points, ou des deux.

Statistiques utilisees :

- rang des deux equipes : `standings[].rank`
- points des deux equipes : `standings[].points`
- matchs joues : `standings[].all.played`

Condition actuelle :

- ecart de rang `>= 3`
- ou ecart de points `>= 5`

Highlight attendu :

- bloc classement ;
- equipe avantagee ;
- rang equipe avantagee vs rang adversaire ;
- ecart de places ;
- ecart de points.

### `structural_level_gap` - Ecart de niveau structurel

Ce que la lecture met en evidence :

- l'avantage au classement devient suffisamment marque pour parler d'ecart structurel ;
- la lecture renforce les scenarios de domination ou de pression a sens unique.

Statistiques utilisees :

- rang des deux equipes : `standings[].rank`
- points des deux equipes : `standings[].points`

Condition actuelle :

- ecart de rang `>= 5`
- ou ecart de points `>= 8`

Highlight attendu :

- bloc classement ;
- ecart de places fortement visible ;
- ecart de points fortement visible ;
- equipe structurellement superieure.

### `positive_streak` - Dynamique positive

Ce que la lecture met en evidence :

- une equipe reste sur une serie recente favorable ;
- la forme recente soutient une lecture d'equipe solide ou en progression.

Statistiques utilisees :

- forme classement : `standings[].form`
- fallback forme statistiques equipe : `teams/statistics.form`

Condition actuelle :

- echantillon de 5 matchs ;
- score forme `>= 10` sur 15 points.

Highlight attendu :

- bloc forme recente ;
- sequence W/D/L ;
- nombre de victoires, nuls, defaites ;
- points pris sur les 5 derniers matchs.

### `negative_streak` - Dynamique negative

Ce que la lecture met en evidence :

- une equipe traverse une mauvaise serie recente ;
- cette lecture peut soutenir un scenario d'equipe en difficulte.

Statistiques utilisees :

- forme classement : `standings[].form`
- fallback forme statistiques equipe : `teams/statistics.form`

Condition actuelle :

- echantillon de 5 matchs ;
- score forme `<= 4` sur 15 points.

Highlight attendu :

- bloc forme recente ;
- sequence W/D/L ;
- faible nombre de points pris ;
- defaites recentes visibles.

### `improving_form` - Dynamique en hausse

Ce que la lecture met en evidence :

- les 3 derniers matchs sont meilleurs que les 2 matchs precedents ;
- l'equipe montre une tendance recente positive.

Statistiques utilisees :

- forme classement : `standings[].form`
- fallback forme statistiques equipe : `teams/statistics.form`

Condition actuelle :

- echantillon de 5 matchs ;
- score des 3 derniers matchs `>=` score des 2 matchs precedents + 4.

Highlight attendu :

- bloc forme recente ;
- separation visuelle entre anciens et derniers matchs ;
- progression de points.

### `declining_form` - Dynamique en baisse

Ce que la lecture met en evidence :

- les 3 derniers matchs sont moins bons que les 2 matchs precedents ;
- la dynamique recente se degrade.

Statistiques utilisees :

- forme classement : `standings[].form`
- fallback forme statistiques equipe : `teams/statistics.form`

Condition actuelle :

- echantillon de 5 matchs ;
- score des 3 derniers matchs + 4 `<=` score des 2 matchs precedents.

Highlight attendu :

- bloc forme recente ;
- degradation visible de la sequence ;
- baisse des points pris.

### `strong_home_team` - Solide a domicile

Ce que la lecture met en evidence :

- l'equipe a domicile gagne souvent chez elle ;
- le contexte domicile renforce une lecture favorable.

Statistiques utilisees :

- matchs joues a domicile : `teams/statistics.fixtures.played.home`
- victoires a domicile : `teams/statistics.fixtures.wins.home`

Condition actuelle :

- au moins 5 matchs a domicile ;
- taux de victoires domicile `>= 60%`.

Highlight attendu :

- bloc domicile / exterieur ;
- pourcentage de victoires a domicile ;
- nombre de matchs joues ;
- comparaison avec l'adversaire si disponible.

### `weak_away_team` - Fragile a l'exterieur

Ce que la lecture met en evidence :

- l'equipe exterieure perd souvent en deplacement ;
- le contexte exterieur peut fragiliser sa lecture.

Statistiques utilisees :

- matchs joues a l'exterieur : `teams/statistics.fixtures.played.away`
- defaites a l'exterieur : `teams/statistics.fixtures.loses.away`

Condition actuelle :

- au moins 5 matchs a l'exterieur ;
- taux de defaites exterieur `>= 45%`.

Highlight attendu :

- bloc domicile / exterieur ;
- pourcentage de defaites a l'exterieur ;
- nombre de matchs joues ;
- contexte de deplacement.

### `strong_away_team` - Solide a l'exterieur

Etat actuel :

- attendu par certains scenarios ;
- reference cote presentation ;
- non identifie comme produit par `FootballAnalyzer` actuellement.

Ce que la lecture devrait mettre en evidence :

- l'equipe exterieure gagne ou performe fortement hors de chez elle.

Statistiques attendues :

- matchs joues a l'exterieur : `teams/statistics.fixtures.played.away`
- victoires a l'exterieur : `teams/statistics.fixtures.wins.away`

Highlight attendu :

- bloc domicile / exterieur ;
- taux de victoires exterieur ;
- volume de matchs.

### `weak_home_team` - Fragile a domicile

Etat actuel :

- attendu par certains scenarios ;
- reference cote presentation ;
- non identifie comme produit par `FootballAnalyzer` actuellement.

Ce que la lecture devrait mettre en evidence :

- l'equipe a domicile perd ou performe mal chez elle.

Statistiques attendues :

- matchs joues a domicile : `teams/statistics.fixtures.played.home`
- defaites a domicile : `teams/statistics.fixtures.loses.home`

Highlight attendu :

- bloc domicile / exterieur ;
- taux de defaites domicile ;
- volume de matchs.

### `home_away_mismatch` - Avantage domicile / exterieur

Ce que la lecture met en evidence :

- le split domicile/exterieur renforce la lecture globale ;
- actuellement detecte quand l'equipe domicile est forte chez elle et l'equipe exterieure fragile dehors.

Statistiques utilisees :

- `teams/statistics.fixtures.wins.home`
- `teams/statistics.fixtures.loses.away`
- `teams/statistics.fixtures.played.home`
- `teams/statistics.fixtures.played.away`

Condition actuelle :

- `strong_home_team` detectee ;
- `weak_away_team` detectee.

Highlight attendu :

- bloc domicile / exterieur ;
- comparaison directe des deux taux ;
- libelle de contexte, pas de probabilite.

### `prolific_attack` - Attaque prolifique

Ce que la lecture met en evidence :

- une equipe marque beaucoup en moyenne ;
- la production offensive soutient les scenarios ouverts ou offensifs.

Statistiques utilisees :

- buts marques par match : `teams/statistics.goals.for.average.total`
- matchs joues : `teams/statistics.fixtures.played.total`

Condition actuelle :

- au moins 8 matchs ;
- moyenne de buts marques `>= 1.70`.

Highlight attendu :

- bloc stats equipe ;
- moyenne buts marques / match ;
- echantillon ;
- comparaison avec l'adversaire si utile.

### `scoring_difficulty` - Production offensive faible

Ce que la lecture met en evidence :

- une equipe marque peu ;
- cette faiblesse peut soutenir un match ferme, une equipe en difficulte ou une pression adverse.

Statistiques utilisees :

- buts marques par match : `teams/statistics.goals.for.average.total`
- matchs joues : `teams/statistics.fixtures.played.total`

Condition actuelle :

- au moins 8 matchs ;
- moyenne de buts marques `<= 0.90`.

Highlight attendu :

- bloc stats equipe ;
- moyenne buts marques / match ;
- faible production visible ;
- echantillon.

### `solid_defense` - Defense solide

Ce que la lecture met en evidence :

- une equipe encaisse peu ;
- la solidite defensive peut soutenir un favori en controle ou un match ferme.

Statistiques utilisees :

- buts encaisses par match : `teams/statistics.goals.against.average.total`
- matchs joues : `teams/statistics.fixtures.played.total`

Condition actuelle :

- au moins 8 matchs ;
- moyenne de buts encaisses `<= 1.00`.

Highlight attendu :

- bloc stats equipe ;
- moyenne buts encaisses / match ;
- echantillon ;
- comparaison avec attaque adverse si utile.

### `fragile_defense` - Defense fragile

Ce que la lecture met en evidence :

- une equipe encaisse beaucoup ;
- cette fragilite soutient les scenarios ouverts, BTTS, equipe en difficulte ou pression offensive adverse.

Statistiques utilisees :

- buts encaisses par match : `teams/statistics.goals.against.average.total`
- matchs joues : `teams/statistics.fixtures.played.total`

Condition actuelle :

- au moins 8 matchs ;
- moyenne de buts encaisses `>= 1.60`.

Highlight attendu :

- bloc stats equipe ;
- moyenne buts encaisses / match ;
- echantillon ;
- signal de vigilance, sans signifier "mauvaise opportunite".

### `frequent_clean_sheet` - Clean sheets frequents

Ce que la lecture met en evidence :

- une equipe garde souvent sa cage inviolee ;
- cette lecture renforce une defense solide ou un match ferme.

Statistiques utilisees :

- clean sheets : `teams/statistics.clean_sheet.total`
- matchs joues : `teams/statistics.fixtures.played.total`

Condition actuelle :

- taux de clean sheets `>= 35%`.

Highlight attendu :

- bloc stats defensive ;
- pourcentage de clean sheets ;
- nombre brut de clean sheets ;
- echantillon.

### `open_match_profile` - Profil de match ouvert

Ce que la lecture met en evidence :

- les moyennes de buts des deux equipes creent un climat offensif ;
- la rencontre peut produire un volume de buts plus eleve.

Statistiques utilisees :

- buts marques domicile : `teams/statistics.goals.for.average.total`
- buts marques exterieur : `teams/statistics.goals.for.average.total`
- buts encaisses domicile : `teams/statistics.goals.against.average.total`
- buts encaisses exterieur : `teams/statistics.goals.against.average.total`

Condition actuelle :

- au moins 8 matchs pour chaque equipe ;
- climat buts agrege `>= 2.80`.

Highlight attendu :

- bloc attaque / defense ;
- indice buts combine ;
- detail des moyennes qui composent l'indice.

### `frequent_over_25` - Tendance over 2,5 buts

Ce que la lecture met en evidence :

- le profil global soutient un scenario au-dessus de 2,5 buts ;
- actuellement cette lecture est derivee du meme climat que `open_match_profile`.

Statistiques utilisees :

- memes donnees que `open_match_profile`.

Condition actuelle :

- produite en meme temps que `open_match_profile`.

Highlight attendu :

- bloc attaque / defense ;
- indice buts combine ;
- mention explicite "profil over", sans en faire une prediction.

### `closed_match_profile` - Profil de match ferme

Ce que la lecture met en evidence :

- les moyennes de buts des deux equipes creent un climat bas ;
- la rencontre peut avoir un volume offensif limite.

Statistiques utilisees :

- buts marques domicile : `teams/statistics.goals.for.average.total`
- buts marques exterieur : `teams/statistics.goals.for.average.total`
- buts encaisses domicile : `teams/statistics.goals.against.average.total`
- buts encaisses exterieur : `teams/statistics.goals.against.average.total`

Condition actuelle :

- au moins 8 matchs pour chaque equipe ;
- climat buts agrege `<= 2.10`.

Highlight attendu :

- bloc attaque / defense ;
- indice buts combine bas ;
- detail des moyennes qui composent l'indice.

### `frequent_under_25` - Tendance under 2,5 buts

Ce que la lecture met en evidence :

- le profil global soutient un scenario sous 2,5 buts ;
- actuellement cette lecture est derivee du meme climat que `closed_match_profile`.

Statistiques utilisees :

- memes donnees que `closed_match_profile`.

Condition actuelle :

- produite en meme temps que `closed_match_profile`.

Highlight attendu :

- bloc attaque / defense ;
- indice buts combine ;
- mention explicite "profil under", sans en faire une prediction.

### `high_xg_creation` - Creation xG elevee

Ce que la lecture met en evidence :

- une equipe cree beaucoup d'occasions selon les xG historiques ;
- cette lecture peut renforcer attaque, match ouvert ou equipe meilleure que ses resultats.

Statistiques utilisees :

- xG crees recents : `fixtures/statistics[].statistics[].type=expected_goals`
- moyenne glissante : `rollingXgFor5`

Condition actuelle :

- echantillon xG `>= 3`
- xG crees moyens `>= 1.50`
- donnees non posterieures au match.

Highlight attendu :

- bloc stats equipe ou xG ;
- xG crees moyens ;
- echantillon ;
- mention "historique", jamais "xG futur".

### `low_xg_creation` - Creation xG faible

Ce que la lecture met en evidence :

- une equipe cree peu d'occasions selon les xG historiques ;
- cette lecture peut soutenir un match ferme ou une equipe en difficulte.

Statistiques utilisees :

- xG crees recents : `fixtures/statistics[].statistics[].type=expected_goals`
- moyenne glissante : `rollingXgFor5`

Condition actuelle :

- echantillon xG `>= 3`
- xG crees moyens `<= 0.90`
- donnees non posterieures au match.

Highlight attendu :

- bloc stats equipe ou xG ;
- xG crees moyens ;
- echantillon.

### `high_xg_conceded` - xG concedés eleves

Ce que la lecture met en evidence :

- une equipe concède beaucoup d'occasions selon les xG historiques ;
- cette lecture renforce defense fragile, match ouvert ou pression adverse.

Statistiques utilisees :

- xG concédés recents : `fixtures/statistics[].statistics[].type=expected_goals`
- moyenne glissante : `rollingXgAgainst5`

Condition actuelle :

- echantillon xG `>= 3`
- xG concédés moyens `>= 1.50`
- donnees non posterieures au match.

Highlight attendu :

- bloc stats equipe ou xG ;
- xG concédés moyens ;
- echantillon ;
- signal de vigilance statistique.

### `offensive_underperformance` - Sous-performance offensive

Ce que la lecture met en evidence :

- une equipe marque moins que sa production xG recente ;
- ses resultats offensifs peuvent sous-representer sa creation.

Statistiques utilisees :

- buts marques recents ;
- xG crees recents ;
- ecart `goalsMinusXgFor5`.

Condition actuelle :

- ecart buts - xG `<= -1.50`

Highlight attendu :

- bloc xG / buts ;
- buts marques vs xG crees ;
- ecart negatif.

### `offensive_overperformance` - Surperformance offensive

Ce que la lecture met en evidence :

- une equipe marque davantage que sa production xG recente ;
- ses resultats offensifs peuvent etre a nuancer.

Statistiques utilisees :

- buts marques recents ;
- xG crees recents ;
- ecart `goalsMinusXgFor5`.

Condition actuelle :

- ecart buts - xG `>= 1.50`

Highlight attendu :

- bloc xG / buts ;
- buts marques vs xG crees ;
- ecart positif ;
- traitement de vigilance, pas de jugement de valeur.

### `defensive_overperformance` - Surperformance defensive

Ce que la lecture met en evidence :

- une equipe encaisse moins que les xG concédés ne le suggerent ;
- sa solidite recente peut etre a nuancer.

Statistiques utilisees :

- buts encaisses recents ;
- xG concédés recents ;
- ecart `goalsConcededMinusXgAgainst5`.

Condition actuelle :

- ecart buts encaisses - xGA `<= -1.50`

Highlight attendu :

- bloc xG / defense ;
- buts encaisses vs xG concédés ;
- ecart negatif.

### `defensive_underperformance` - Sous-performance defensive

Ce que la lecture met en evidence :

- une equipe encaisse plus que les xG concédés ne le suggerent ;
- sa defense subit ou traverse une phase defavorable.

Statistiques utilisees :

- buts encaisses recents ;
- xG concédés recents ;
- ecart `goalsConcededMinusXgAgainst5`.

Condition actuelle :

- ecart buts encaisses - xGA `>= 1.50`

Highlight attendu :

- bloc xG / defense ;
- buts encaisses vs xG concédés ;
- ecart positif.

### `misleading_result` - Resultats a nuancer

Ce que la lecture met en evidence :

- une equipe a des resultats positifs, mais des signaux xG invitent a nuancer ;
- c'est une contradiction, pas une lecture favorable.

Statistiques utilisees :

- presence de `positive_streak`
- presence de `offensive_overperformance` ou `defensive_overperformance`

Condition actuelle :

- resultats recents positifs ;
- surperformance offensive ou defensive detectee.

Highlight attendu :

- bloc vigilance ;
- lien vers forme recente ;
- lien vers xG ;
- affichage comme point de contradiction.

### `conflicting_signals` - Signal contradictoire

Ce que la lecture met en evidence :

- une equipe gagne recemment, mais sa defense reste fragile ;
- la lecture invite a verifier la coherence globale.

Statistiques utilisees :

- presence de `positive_streak`
- presence de `fragile_defense`

Condition actuelle :

- dynamique positive ;
- defense fragile detectee.

Highlight attendu :

- bloc vigilance ;
- lien vers forme recente ;
- lien vers stats defensives ;
- affichage comme point de contradiction.

### `insufficient_data` - Donnee non exploitable

Ce que la lecture met en evidence :

- les donnees disponibles ne permettent pas de soutenir une lecture ;
- peut aussi signaler des xG posterieurs au match et donc refuses pour le pre-match.

Statistiques utilisees :

- absence d'echantillon exploitable ;
- ou xG avec `asOf` posterieur au kickoff.

Condition actuelle :

- aucune lecture detectee ;
- ou xG post-match rejetes.

Highlight attendu :

- bloc etat de donnees ;
- raison de non-utilisation ;
- source concernee.

## Lectures combinees et scenarios

### `expected_domination` - Domination attendue

Ce que le scenario met en evidence :

- une equipe cumule superiorite structurelle, dynamique favorable et contexte domicile/exterieur coherent.

Lectures utilisees :

- `structural_level_gap`
- `ranking_superiority`
- `positive_streak`
- `strong_home_team` ou `strong_away_team`
- `weak_away_team` ou `weak_home_team`
- `home_away_mismatch`

Condition actuelle :

- au moins 3 lectures de support ;
- `structural_level_gap` obligatoire.

Marches compatibles actuels :

- resultat du match ;
- double chance.

Highlights scenario attendus :

- classement ;
- forme recente ;
- domicile / exterieur ;
- points de vigilance eventuels.

Point a corriger :

- `strong_away_team` et `weak_home_team` ne semblent pas produits actuellement.

### `favorite_with_protection` - Favori avec protection

Ce que le scenario met en evidence :

- le marche identifie un favori ;
- ce favori a des arguments, mais au moins un point de vigilance invite a couvrir.

Lectures utilisees :

- `ranking_superiority`
- `solid_defense`
- contradictions de l'equipe favorite.

Condition actuelle :

- favori du marche detecte ;
- au moins 2 lectures de support ;
- au moins 1 contradiction.

Marches compatibles actuels :

- double chance.

Highlights scenario attendus :

- classement ;
- defense ;
- bloc vigilance.

### `convergent_open_match` - Match ouvert

Ce que le scenario met en evidence :

- plusieurs familles de lectures convergent vers un rythme de buts plus eleve.

Lectures utilisees :

- `open_match_profile`
- `frequent_over_25`
- `high_xg_creation`
- `fragile_defense`
- `high_xg_conceded`

Condition actuelle :

- au moins 3 lectures de support.

Marches compatibles actuels :

- over 2,5 buts ;
- les deux equipes marquent.

Highlights scenario attendus :

- attaque ;
- defense fragile ;
- climat buts ;
- xG creation/concession si disponible.

### `convergent_closed_match` - Match ferme

Ce que le scenario met en evidence :

- plusieurs lectures convergent vers un rythme offensif limite.

Lectures utilisees :

- `closed_match_profile`
- `frequent_under_25`
- `solid_defense`
- `frequent_clean_sheet`
- `scoring_difficulty`

Condition actuelle :

- au moins 3 lectures de support.

Marches compatibles actuels :

- under 2,5 buts.

Highlights scenario attendus :

- defense solide ;
- clean sheets ;
- faible production offensive ;
- climat buts bas.

### `credible_outsider` - Outsider credible

Ce que le scenario met en evidence :

- une equipe moins attendue par le marche possede des signaux qui reduisent l'ecart theorique.

Lectures utilisees :

- `balanced_hierarchy`
- pour l'outsider : `positive_streak`, `strong_home_team`, `high_xg_creation`
- pour l'adversaire : `negative_streak`, `declining_form`, `fragile_defense`

Condition actuelle :

- outsider detecte par le marche ;
- favori detecte par le marche ;
- cote outsider `<= 4.50` ;
- au moins 3 lectures de support.

Marches compatibles actuels :

- double chance ;
- resultat du match.

Highlights scenario attendus :

- marche 1N2 ;
- hierarchie proche ;
- forme outsider ;
- fragilite adverse ;
- xG creation si disponible.

Point a surveiller :

- `strong_home_team` est utilise pour l'outsider quel que soit son cote. Cela peut etre incoherent si l'outsider joue a l'exterieur.

### `team_in_serious_difficulty` - Equipe en difficulte

Ce que le scenario met en evidence :

- une equipe cumule mauvaise dynamique, faible production offensive et fragilite defensive.

Lectures utilisees :

- `negative_streak`
- `scoring_difficulty`
- `fragile_defense`
- `weak_away_team` ou `weak_home_team`

Condition actuelle :

- au moins 3 lectures de support.

Marches compatibles actuels :

- double chance adverse ;
- resultat du match adverse.

Highlights scenario attendus :

- forme recente ;
- attaque faible ;
- defense fragile ;
- split domicile/exterieur.

Point a corriger :

- `weak_home_team` ne semble pas produit actuellement.

### `controlled_favorite` - Favori en controle

Ce que le scenario met en evidence :

- le favori peut controler le match sans necessairement ouvrir fortement la rencontre.

Lectures utilisees :

- pour le favori : `ranking_superiority`, `solid_defense`
- pour l'adversaire : `scoring_difficulty`
- match : `closed_match_profile`

Condition actuelle :

- favori du marche detecte ;
- au moins 3 lectures de support.

Marches compatibles actuels :

- resultat du match ;
- double chance.

Highlights scenario attendus :

- marche 1N2 ;
- classement ;
- defense du favori ;
- attaque faible adverse ;
- climat ferme.

### `both_sides_can_score` - Les deux equipes peuvent marquer

Ce que le scenario met en evidence :

- les deux equipes ont des arguments offensifs ;
- au moins une defense donne un signal de fragilite.

Lectures utilisees :

- pour chaque equipe : `high_xg_creation` ou `prolific_attack`
- cote defense : `fragile_defense` ou `high_xg_conceded`

Condition actuelle :

- creation offensive detectee pour les deux equipes ;
- fragilite defensive detectee sur au moins une equipe.

Marches compatibles actuels :

- les deux equipes marquent.

Highlights scenario attendus :

- attaque des deux equipes ;
- defense fragile ;
- xG creation/concession si disponible.

### `one_sided_scoring` - Pression offensive a sens unique

Ce que le scenario met en evidence :

- une equipe combine production offensive et opposition defensive/offensive fragilisee.

Lectures utilisees :

- equipe cible : `prolific_attack`, `high_xg_creation`, `solid_defense`
- adversaire : `fragile_defense`, `high_xg_conceded`, `scoring_difficulty`

Condition actuelle :

- au moins 3 lectures de support.

Marches compatibles actuels :

- total buts equipe over 0,5 ;
- resultat du match.

Highlights scenario attendus :

- attaque equipe cible ;
- xG creation ;
- fragilite defensive adverse ;
- faible production adverse.

### `team_better_than_results` - Meilleur que les resultats

Ce que le scenario met en evidence :

- une equipe a de mauvais resultats, mais sa production d'occasions reste interessante ;
- la lecture cherche une divergence entre resultats et contenu.

Lectures utilisees :

- `negative_streak`
- `offensive_underperformance`
- `high_xg_creation`

Condition actuelle :

- au moins 3 lectures de support.

Marches compatibles actuels :

- double chance.

Highlights scenario attendus :

- forme recente negative ;
- xG creation ;
- ecart buts - xG.

### `team_worse_than_results` - Resultats a nuancer

Ce que le scenario met en evidence :

- une equipe obtient de bons resultats, mais ses xG fragilisent la lecture ;
- c'est une lecture de prudence, pas une opportunite offensive en soi.

Lectures utilisees :

- `positive_streak`
- `offensive_overperformance`
- `defensive_overperformance`

Condition actuelle :

- au moins 3 lectures de support.

Marches compatibles actuels :

- aucun marche recommande.

Highlights scenario attendus :

- forme recente positive ;
- ecart buts - xG ;
- ecart buts encaisses - xGA ;
- traitement de vigilance.

### `avoid_match` - Match a eviter

Ce que le scenario met en evidence :

- les signaux ne sont pas assez clairs ou se contredisent ;
- le moteur prefere ne pas proposer de marche automatiquement.

Lectures utilisees :

- `balanced_hierarchy`
- `conflicting_signals`
- `insufficient_data`

Condition actuelle :

- au moins 2 lectures de support.

Marches compatibles actuels :

- aucun marche recommande.

Highlights scenario attendus :

- hierarchie proche ;
- contradictions ;
- manque de donnees ;
- message de prudence.

## Mapping actuel des profils utilisateur

Le catalogue onboarding regroupe plusieurs scenarios sous des familles simples :

| Famille profil | Id profil | Thesis ids actuels |
| --- | --- | --- |
| Favoris solides | `solid_favorite` | `solid_favorite`, `cautious_double_chance`, `expected_domination`, `favorite_with_protection`, `controlled_favorite` |
| Equipes en difficulte | `struggling_team` | `team_in_serious_difficulty` |
| Matchs ouverts | `offensive_match` | `open_match`, `convergent_open_match`, `both_sides_can_score` |
| Matchs fermes | `defensive_match` | `closed_match`, `convergent_closed_match` |
| Ecarts de niveau | `ranking_gap` | `level_gap`, `expected_domination`, `one_sided_scoring` |
| Outsiders credibles | `credible_outsider` | `credible_outsider` |
| Defenses fragiles | `fragile_defense` | `convergent_open_match`, `one_sided_scoring`, `team_in_serious_difficulty` |
| Attaques prolifiques | `prolific_attack` | `both_sides_can_score`, `one_sided_scoring` |
| Series positives | `positive_series` | `team_worse_than_results`, `expected_domination` |
| Series negatives | `negative_series` | `team_better_than_results`, `team_in_serious_difficulty` |

## Proposition pour le chantier highlights

### Niveau 1 : lecture simple

Chaque `FootballReading` devrait pouvoir produire une liste de highlights :

- identifiant de lecture ;
- famille metier ;
- sujet ;
- type de preuve ;
- cible UI ;
- valeur principale ;
- valeur comparee optionnelle ;
- libelle court ;
- tonalite : preuve, contexte, vigilance, contradiction ;
- sourcePath.

### Niveau 2 : scenario

Chaque scenario devrait exposer :

- son id ;
- son titre produit ;
- les lectures simples requises ;
- les lectures simples optionnelles ;
- les contradictions a afficher ;
- les highlights prioritaires ;
- les sections UI a ouvrir/surligner dans le detail match.

### Niveau 3 : personnalisation

Deux modes peuvent coexister :

- Mode simple : l'utilisateur choisit des scenarios comprehensibles.
- Mode avance : l'utilisateur choisit les lectures simples qui comptent pour lui.

Les scenarios ne doivent pas etre une logique parallele.
Ils doivent rester des assemblages explicites de lectures simples.

## Decisions a prendre avant code

1. Valider les noms produit des lectures simples.
2. Valider les noms produit des scenarios.
3. Decider si `solid_favorite` reste une famille profil ou redevient un scenario explicite.
4. Corriger ou confirmer les lectures domicile/exterieur manquantes.
5. Decider si les seuils actuels restent acceptables pour le MVP.
6. Definir la structure `ReadingHighlight`.
7. Definir quels highlights apparaissent dans :
   - detail match ;
   - lectures combinees ;
   - ticket ;
   - onboarding / preferences.
