# Theme de l'application Lector Sport

Ce document formalise la charte visuelle actuelle de l'application mobile Lector Sport.
Il sert de reference pour les futures iterations UI, les maquettes, les revues de coherence et l'integration Flutter.

Pour les refontes UX/UI assistees par IA, utiliser le workflow dedie :

- `docs/ai-design-workflow/README.md`

Ce workflow separe l'exploration ImageGen, la formalisation visuelle validee et l'implementation Flutter.

La refonte validee est documentee ici :

- `docs/ai-design-workflow/07-validated-visual-redesign.md`

## Apparence Lector Sport Validee

Lector Sport assume une interface sombre, premium, compacte et orientee lecture de match.
L'objectif est de garder la simplicite d'une app de scores tout en ajoutant les indices Lector qui rendent une rencontre plus lisible.

Decisions structurantes :

- arrivee dans l'app sans authentification forcee ni paywall ;
- fond d'arrivee type stade premium, pas fond noir uni ni halo sous le logo ;
- accueil par defaut sur `Pour moi` ;
- onglets principaux de l'accueil : `Pour moi`, `Tous`, `Generateur` ;
- calendrier horizontal compact avec jour et date ;
- listes de championnats replies par defaut dans `Pour moi` et `Tous` ;
- `Tous` affiche toutes les ligues, pas la selection courte `Pour moi` ;
- Quick Dock flottant en bas a gauche, contextuel et limite a quelques actions ;
- detail de match avant-match avec card stade premium et blocs factuels ;
- header operationnel sans lockup complet lorsque le logo n'apporte pas de valeur.

Regles d'identite :

- utiliser uniquement les assets de logo transparents valides ;
- ne pas ajouter de fond sombre, glow ou plaque derriere le logo ;
- reserver les assets photo aux moments qui gagnent en atmosphere : arrivee, card rencontre ;
- garder les cards data simples lorsque l'image nuirait a la lisibilite.

## Objectif visuel

L'application repose sur une interface mobile sombre, dense et lisible. Elle doit donner une impression de produit d'aide a la decision : calme, technique, precis, mais jamais froid ou surcharge.

Les choix graphiques doivent soutenir trois objectifs :

- permettre de comparer rapidement des rencontres, lectures, marches et tickets ;
- rendre les signaux Copilot identifiables sans promettre une prediction ;
- conserver une forte identite visuelle autour du turquoise, sans transformer toute l'interface en palette monochrome.

## Sources de verite

Les tokens de theme sont centralises dans :

- `lib/core/theme/app_colors.dart`
- `lib/core/theme/app_spacing.dart`
- `lib/core/theme/app_radius.dart`
- `lib/core/theme/app_typography.dart`
- `lib/core/theme/app_shadows.dart`
- `lib/core/theme/app_theme.dart`
- `lib/core/theme/app_theme_controller.dart`
- `lib/core/theme/app_components.dart`
- `lib/core/theme/app_icons.dart`

L'application expose ensuite ces tokens via :

- `lib/app/theme/app_theme.dart`

Regle importante : les widgets de production ne doivent pas declarer de nouvelles couleurs hexadecimales directement. Toute couleur doit passer par les tokens centraux (`AppColors`, `AppLightColors`, `AppComponentColors`, `AppOpportunityPalette`) ou les ThemeExtensions exposees par `Theme.of(context)`.

## Architecture De Theming

Le theme est construit a partir de `VectorThemeTokens`.

Variantes actuellement supportees :

- `VectorThemeTokens.vectorDark`
- `VectorThemeTokens.vectorLight`
- `VectorThemeTokens.gold`
- `VectorThemeTokens.aurora`

Chaque variante fournit les memes familles de tokens :

- `AppBrandPalette` : accent de marque, hover, accent fonce, couleur sur accent ;
- `AppSurfacePalette` : fonds, surfaces, bordures, surfaces desactivees, ombres ;
- `AppTextPalette` : texte principal, secondaire, faible, desactive ;
- `AppSemanticPalette` : success, warning, error, live, info ;
- `AppComponentColors` : cotes, badges et composants specifiques ;
- `AppOpportunityPalette` : familles metier des lectures/opportunites et styles complets de badges.

Le builder generique `CopilotTheme._buildTheme(VectorThemeTokens tokens)` produit le `ThemeData` Flutter complet.

Les composants doivent privilegier :

- `Theme.of(context).colorScheme` pour les couleurs Flutter standard ;
- `context.brand`, `context.surfaces`, `context.textColors`, `context.semantic`, `context.components`, `context.opportunities` pour les tokens produit.

Le basculement manuel temporaire est centralise dans `appThemeController`.
Il demarre volontairement en `Vector Dark` et permet de tester `Vector Light`, `Vector Gold` et `Vector Aurora` sans suivre le theme systeme.

## Strategie De Lisibilite Multi-Theme

Chaque nouveau theme doit etre valide par familles de composants, pas seulement par palette globale.

Regles minimales :

- le texte principal sur surface doit viser un contraste `>= 4.5:1` ;
- le texte secondaire sur surface doit viser un contraste `>= 4.5:1` lorsqu'il porte une information utile ;
- les accents, cotes, badges et couleurs metier doivent viser au minimum `>= 3:1` avec leur fond ;
- une couleur metier ne doit jamais etre employee comme fond large sans verifier son texte associe ;
- les fonds d'alerte doivent etre des surfaces legeres teintees, pas des blocs satures ;
- les cotes doivent toujours utiliser `AppComponentColors.oddsBackground`, `oddsText`, `oddsBorder` ;
- les switches, chips, inputs et boutons doivent passer par `ThemeData`, pas par des couleurs locales.

Checklist de composants a verifier pour chaque theme :

- navigation principale et onglets ;
- calendrier ;
- bannieres d'alerte ou d'etat, notamment snapshot obsolète ;
- listes de competitions et ligues ;
- cartes de match ;
- cartes d'opportunite ;
- bloc "Marche propose" / "Marche recommande" ;
- blocs de cotes ;
- filtres, chips et segmented controls ;
- tickets et "Mon ticket" ;
- historique : periode, KPI, filtres, timeline, cartes ticket, etats vides ;
- onboarding : cartes, inputs, switches, strategie ;
- bottom sheets et panels.

Toute creation de composant visuel doit indiquer explicitement la famille de tokens utilisee :

- `surfaces` pour le contenant ;
- `textColors` ou `ColorScheme.onSurface*` pour le texte ;
- `semantic` pour success/warning/error/live/info ;
- `components` pour odds, badges et composants specifiques ;
- `opportunities` pour les lectures metier.

## Palette Principale Sombre

| Usage | Token | Hex | Role |
| --- | --- | --- | --- |
| Fond principal | `AppColors.background` | `#0B1015` | Fond global des ecrans |
| Fond secondaire | `AppColors.backgroundSecondary` | `#11181F` | Navigation, inputs, zones secondaires |
| Surface | `AppColors.surface` | `#161F26` | Cards et panneaux |
| Surface hover/haute | `AppColors.surfaceHover` | `#1B262E` | Etats hover desktop, surfaces accentuees |
| Bordures | `AppColors.border` | `#2B3944` | Separateurs et contours discrets |
| Ombres | `AppColors.shadow` | `#000000` | Ombres et scrims |
| Transparent | `AppColors.transparent` | `#00000000` | Transparence explicite |

## Accent

| Usage | Token | Hex |
| --- | --- | --- |
| Accent principal | `AppColors.accent` | `#2FE6D3` |
| Accent hover | `AppColors.accentHover` | `#52F2E0` |
| Accent fonce | `AppColors.accentDark` | `#18C9B8` |
| Texte bouton primaire | `AppColors.primaryButtonText` | `#071215` |

L'accent est reserve aux elements actifs ou fortement actionnables :

- boutons primaires ;
- onglets actifs ;
- liens et actions principales ;
- focus d'input ;
- switchs et checkboxes actifs ;
- icones structurantes ;
- valeurs importantes comme les cotes.

Eviter de l'utiliser pour du texte decoratif ou des surfaces trop larges.

## Texte

| Usage | Token | Hex |
| --- | --- | --- |
| Texte principal | `AppColors.textPrimary` | `#F5F7FA` |
| Texte secondaire | `AppColors.textSecondary` | `#B8C3CC` |
| Texte faible | `AppColors.textWeak` | `#7D8C99` |
| Texte desactive | `AppColors.textDisabled` | `#5B6873` |

Regles :

- `textPrimary` pour titres, noms d'equipes, libelles critiques.
- `textSecondary` pour descriptions, metadonnees utiles, textes d'aide.
- `textWeak` pour informations de moindre priorite, placeholders, labels secondaires.
- `textDisabled` uniquement pour etats indisponibles.

## Etats Semantiques

| Usage | Token | Hex |
| --- | --- | --- |
| Succes | `AppColors.success` | `#38D97A` |
| Succes hover | `AppColors.successHover` | `#4CE38A` |
| Warning | `AppColors.warning` | `#F5B84B` |
| Erreur | `AppColors.error` | `#F05A67` |
| Live | `AppColors.live` | `#FF4E42` |
| Info | `AppColors.info` | `#53B5FF` |

Regles :

- Ne pas utiliser `success` pour signifier "pari gagnant probable".
- `warning` sert aux vigilances, attentes et lectures moins nettes.
- `error` sert aux erreurs, suppressions, contradictions fortes ou etats perdus.
- `live` est reserve aux matchs en direct.
- `info` sert aux donnees informatives ou aux lectures froides.

## Cotes

Les cotes ont une palette dediee afin de rester identiques partout.

| Usage | Token | Hex |
| --- | --- | --- |
| Fond cote | `AppColors.oddsBackground` | `#112B2D` |
| Texte cote | `AppColors.oddsText` | `#4EF2D8` |
| Bordure cote | `AppColors.oddsBorder` | `#235D61` |

Regles :

- Les cotes doivent toujours utiliser la meme couleur de texte.
- Ne pas colorer une cote en vert/rouge pour suggerer qu'elle est bonne ou mauvaise.
- Une cote indisponible doit afficher `-` ou `Cotes indisponibles`, avec `textWeak`.
- Le rayon recommande des blocs de cote est `AppRadius.odds`.

## Badges

| Badge | Fond | Texte |
| --- | --- | --- |
| LIVE | `AppColors.liveBadgeBackground` `#3B1114` | `AppColors.liveBadgeText` `#FF5C5C` |
| A analyser | `AppColors.analyzeBadgeBackground` `#173138` | `AppColors.accent` `#2FE6D3` |
| Resultat | `AppColors.resultBadgeBackground` `#12301E` | `AppColors.resultBadgeText` `#4EE48C` |
| Reporte | `AppColors.postponedBadgeBackground` `#3A3116` | `AppColors.postponedBadgeText` `#F7C95E` |

Les badges doivent rester compacts, avec une bordure discrete si necessaire.

## Couleurs Des Lectures Et Opportunites

Les profils d'opportunite ont une couleur propre, exposee via `AppOpportunityPalette`.

| Profil | Token | Hex |
| --- | --- | --- |
| Favori solide | `solidFavorite` | `#38D97A` |
| Match ouvert | `openMatch` | `#FF8F3D` |
| Match ferme | `closedMatch` | `#53B5FF` |
| Ecart de niveau | `levelGap` | `#9C7CFF` |
| Outsider credible | `credibleOutsider` | `#F5B84B` |
| Defense fragile | `fragileDefense` | `#FF6B7A` |
| Attaque prolifique | `prolificAttack` | `#2FE6D3` |
| Serie positive | `positiveStreak` | `#6EDC6A` |
| Serie negative | `negativeStreak` | `#FF6464` |
| Equipe en difficulte | `strugglingTeam` | `#D67C4B` |

Mapping actuel par ids :

- `solid_favorite` -> Favori solide
- `open_match`, `offensive_match` -> Match ouvert
- `closed_match` -> Match ferme
- `level_gap`, `ranking_gap` -> Ecart de niveau
- `credible_outsider` -> Outsider credible
- `fragile_defense`, `defensive_weakness` -> Defense fragile
- `prolific_attack`, `strong_attack` -> Attaque prolifique
- `positive_streak`, `strong_recent_form` -> Serie positive
- `negative_streak`, `weak_recent_form` -> Serie negative
- `team_in_difficulty`, `poor_overall_performance` -> Equipe en difficulte

Regles :

- La couleur de lecture aide a identifier une famille, pas a exprimer une probabilite.
- Les lectures ne doivent pas afficher de pourcentage de confiance.
- Le vocabulaire produit recommande est : lecture simple, lecture combinee, marche recommande.

### Badges De Lectures

Les lectures simples et lectures combinees ne doivent pas fabriquer localement leur rendu visuel.
`AppOpportunityPalette` expose des styles complets de badge via :

```dart
context.opportunities.badgeFor(
  thesisId,
  variant: AppReadingBadgeVariant.simple,
)
```

Variantes disponibles :

- `simple` : lecture elementaire, rendu discret / outline ;
- `combined` : lecture combinee, rendu plus affirme ;
- `soft` : chips secondaires, pedagogie, filtres et contextes moins prioritaires.

Chaque style de badge fournit :

- `foreground` : couleur du texte ;
- `background` : fond du badge ;
- `border` : couleur de contour ;
- `iconColor` : couleur de l'icone.

Regles :

- les widgets ne doivent pas calculer eux-memes `background`, `border` ou `foreground` avec `withOpacity` / `withValues(alpha)` a partir d'une couleur metier ;
- `byThesisId()` reste disponible uniquement pour compatibilite ou pour les rares usages ou une couleur brute est réellement necessaire ;
- une couleur de lecture represente une famille metier, jamais une probabilite, une confiance ou une qualite de pari ;
- `simple`, `combined` et `soft` doivent rester visuellement distincts dans chaque theme ;
- chaque theme doit fournir un contraste suffisant entre `foreground` et `background`.

Exemple de responsabilites :

- `FootballAnalyzer` ou le domaine fournit un `readingId` / `thesisId` ;
- `AppOpportunityPalette` resout la famille et le style visuel ;
- le widget compose le badge sans connaitre la variante de theme active.

## Palette Claire

Le theme clair conserve l'identite Vector, mais avec des surfaces et textes adaptes au contraste clair.

| Usage | Token | Hex |
| --- | --- | --- |
| Fond principal | `AppLightColors.background` | `#F6F9FB` |
| Fond secondaire | `AppLightColors.backgroundSecondary` | `#EEF4F6` |
| Surface | `AppLightColors.surface` | `#FFFFFF` |
| Surface hover/haute | `AppLightColors.surfaceHover` | `#EAF2F4` |
| Bordures | `AppLightColors.border` | `#D4E0E5` |
| Texte principal | `AppLightColors.textPrimary` | `#071215` |
| Texte secondaire | `AppLightColors.textSecondary` | `#44535E` |
| Texte faible | `AppLightColors.textWeak` | `#6E7D87` |
| Accent | `AppLightColors.accent` | `#0D8179` |
| Cote fond | `AppLightColors.oddsBackground` | `#E6FAF7` |
| Cote texte | `AppLightColors.oddsText` | `#087F75` |
| Cote bordure | `AppLightColors.oddsBorder` | `#A8E7DF` |

Les couleurs metier ont aussi une version claire via `AppLightOpportunityColors`, plus sombre et plus lisible sur fond clair.

## Variante Vector Gold

`Vector Gold` remplace l'ancienne piste `Stadium Night`.
Elle conserve l'ergonomie Vector, mais deplace l'atmosphere vers un rendu premium plus chaud : bleu encre, graphite petrol, ivoire doux et accent or/cuivre.

Intention :

- analyse premium ;
- rapport d'avant-match haut de gamme ;
- chaleur controlee ;
- forte difference avec le dark turquoise historique ;
- aucune esthetique bookmaker, casino ou gaming.

### Gold Brand

| Usage | Token | Hex | Role |
| --- | --- | --- | --- |
| Accent principal | `AppGoldColors.accent` | `#E8B66A` | Accent or/cuivre reserve aux interactions et etats actifs |
| Accent hover | `AppGoldColors.accentHover` | `#F3C987` | Hover/focus plus lumineux |
| Accent fonce | `AppGoldColors.accentDark` | `#B98035` | Accent compact pour surfaces actives |
| Texte sur accent | `AppGoldColors.primaryButtonText` | `#140E08` | Texte/icones sur CTA primaire |

### Gold Surfaces

| Usage | Token | Hex | Role |
| --- | --- | --- | --- |
| Fond principal | `AppGoldColors.background` | `#08111A` | Bleu encre profond |
| Fond secondaire | `AppGoldColors.backgroundSecondary` | `#0E1A25` | Navigation, inputs, zones secondaires |
| Surface | `AppGoldColors.surface` | `#15222D` | Cards et panneaux |
| Surface hover/haute | `AppGoldColors.surfaceHover` | `#1D2D3A` | Niveau eleve, hover et surfaces accentuees |
| Bordures | `AppGoldColors.border` | `#405264` | Separateurs bleu-gris plus visibles |
| Desactive | `AppGoldColors.disabledButtonBackground` | `#202C37` | Fonds d'etats desactives |
| Ombre/scrim | `AppGoldColors.shadow` | `#01070B` | Ombres legeres et overlays |

### Gold Texte

| Usage | Token | Hex |
| --- | --- | --- |
| Texte principal | `AppGoldColors.textPrimary` | `#F8F1E6` |
| Texte secondaire | `AppGoldColors.textSecondary` | `#C9CED4` |
| Texte faible | `AppGoldColors.textWeak` | `#91A0AD` |
| Texte desactive | `AppGoldColors.textDisabled` | `#657584` |

### Gold Semantique

| Usage | Token | Hex |
| --- | --- | --- |
| Succes | `AppGoldColors.success` | `#58D385` |
| Succes hover | `AppGoldColors.successHover` | `#73E39B` |
| Warning | `AppGoldColors.warning` | `#E8B66A` |
| Erreur | `AppGoldColors.error` | `#FF6E75` |
| Live | `AppGoldColors.live` | `#FF5F4A` |
| Info | `AppGoldColors.info` | `#6CB9F0` |

### Gold Cotes Et Badges

| Usage | Token | Hex |
| --- | --- | --- |
| Fond cote | `AppGoldColors.oddsBackground` | `#202A29` |
| Texte cote | `AppGoldColors.oddsText` | `#F0BE69` |
| Bordure cote | `AppGoldColors.oddsBorder` | `#735B39` |
| Badge LIVE fond | `AppGoldColors.liveBadgeBackground` | `#3D1718` |
| Badge LIVE texte | `AppGoldColors.liveBadgeText` | `#FF7668` |
| Badge a analyser fond | `AppGoldColors.analyzeBadgeBackground` | `#243029` |
| Badge resultat fond | `AppGoldColors.resultBadgeBackground` | `#173623` |
| Badge resultat texte | `AppGoldColors.resultBadgeText` | `#73E69C` |
| Badge reporte fond | `AppGoldColors.postponedBadgeBackground` | `#3C2F17` |
| Badge reporte texte | `AppGoldColors.postponedBadgeText` | `#F2CA78` |

### Gold Lectures

| Profil | Token | Hex |
| --- | --- | --- |
| Favori solide | `AppGoldOpportunityColors.solidFavorite` | `#69D88E` |
| Match ouvert | `AppGoldOpportunityColors.openMatch` | `#FFA15B` |
| Match ferme | `AppGoldOpportunityColors.closedMatch` | `#73BDF2` |
| Ecart de niveau | `AppGoldOpportunityColors.levelGap` | `#C0A2FF` |
| Outsider credible | `AppGoldOpportunityColors.credibleOutsider` | `#E8B66A` |
| Defense fragile | `AppGoldOpportunityColors.fragileDefense` | `#FF7C88` |
| Attaque prolifique | `AppGoldOpportunityColors.prolificAttack` | `#55DCCC` |
| Serie positive | `AppGoldOpportunityColors.positiveStreak` | `#89D978` |
| Serie negative | `AppGoldOpportunityColors.negativeStreak` | `#FF7373` |
| Equipe en difficulte | `AppGoldOpportunityColors.strugglingTeam` | `#D9915A` |

Note : `prolificAttack` reste volontairement separe de l'accent de marque. Les cotes prennent une teinte or data, mais elles conservent leur role de valeur neutre et ne deviennent pas un signal de probabilite.

## Variante Vector Aurora

`Vector Aurora` remplace l'ancienne piste `Vector Clubhouse`.
Elle conserve la densite et la structure du produit, mais assume une personnalite plus differenciante : violet nuit, surfaces indigo, accent aurora et cotes turquoise data.

Intention :

- tres differenciante ;
- plus expressive sans basculer dans le gaming ;
- ambiance analytique nocturne ;
- interaction plus lumineuse ;
- aucun changement de composants pour obtenir l'effet.

### Aurora Brand

| Usage | Token | Hex | Role |
| --- | --- | --- | --- |
| Accent principal | `AppAuroraColors.accent` | `#A970FF` | Accent violet aurora reserve aux interactions et etats actifs |
| Accent hover | `AppAuroraColors.accentHover` | `#C08BFF` | Hover/focus plus lumineux |
| Accent fonce | `AppAuroraColors.accentDark` | `#7D4CE0` | Accent compact pour surfaces actives |
| Texte sur accent | `AppAuroraColors.primaryButtonText` | `#10051F` | Texte/icones sur CTA primaire, choisi pour le contraste |

### Aurora Surfaces

| Usage | Token | Hex | Role |
| --- | --- | --- | --- |
| Fond principal | `AppAuroraColors.background` | `#08051E` | Violet nuit profond |
| Fond secondaire | `AppAuroraColors.backgroundSecondary` | `#100A2E` | Navigation, inputs, zones secondaires |
| Surface | `AppAuroraColors.surface` | `#171039` | Cards et panneaux indigo |
| Surface hover/haute | `AppAuroraColors.surfaceHover` | `#221752` | Niveau eleve, hover et surfaces accentuees |
| Bordures | `AppAuroraColors.border` | `#3D2B73` | Separateurs violets lisibles |
| Desactive | `AppAuroraColors.disabledButtonBackground` | `#231B43` | Fonds d'etats desactives |
| Ombre/scrim | `AppAuroraColors.shadow` | `#030111` | Ombres legeres et overlays |

### Aurora Texte

| Usage | Token | Hex |
| --- | --- | --- |
| Texte principal | `AppAuroraColors.textPrimary` | `#F7F1FF` |
| Texte secondaire | `AppAuroraColors.textSecondary` | `#D1C4EC` |
| Texte faible | `AppAuroraColors.textWeak` | `#9888C1` |
| Texte desactive | `AppAuroraColors.textDisabled` | `#70618F` |

### Aurora Semantique

| Usage | Token | Hex |
| --- | --- | --- |
| Succes | `AppAuroraColors.success` | `#61DB8A` |
| Succes hover | `AppAuroraColors.successHover` | `#7CEC9F` |
| Warning | `AppAuroraColors.warning` | `#E9BF76` |
| Erreur | `AppAuroraColors.error` | `#FF6F86` |
| Live | `AppAuroraColors.live` | `#FF5D6A` |
| Info | `AppAuroraColors.info` | `#6DBAFF` |

### Aurora Cotes Et Badges

| Usage | Token | Hex |
| --- | --- | --- |
| Fond cote | `AppAuroraColors.oddsBackground` | `#102B3A` |
| Texte cote | `AppAuroraColors.oddsText` | `#65F2E4` |
| Bordure cote | `AppAuroraColors.oddsBorder` | `#2B6670` |
| Badge LIVE fond | `AppAuroraColors.liveBadgeBackground` | `#3B1324` |
| Badge LIVE texte | `AppAuroraColors.liveBadgeText` | `#FF7887` |
| Badge a analyser fond | `AppAuroraColors.analyzeBadgeBackground` | `#1A204D` |
| Badge resultat fond | `AppAuroraColors.resultBadgeBackground` | `#16352C` |
| Badge resultat texte | `AppAuroraColors.resultBadgeText` | `#78EBA0` |
| Badge reporte fond | `AppAuroraColors.postponedBadgeBackground` | `#3A2B1C` |
| Badge reporte texte | `AppAuroraColors.postponedBadgeText` | `#EFD083` |

### Aurora Lectures

| Profil | Token | Hex |
| --- | --- | --- |
| Favori solide | `AppAuroraOpportunityColors.solidFavorite` | `#6FE092` |
| Match ouvert | `AppAuroraOpportunityColors.openMatch` | `#FF9A59` |
| Match ferme | `AppAuroraOpportunityColors.closedMatch` | `#78BEFF` |
| Ecart de niveau | `AppAuroraOpportunityColors.levelGap` | `#B986FF` |
| Outsider credible | `AppAuroraOpportunityColors.credibleOutsider` | `#E9C574` |
| Defense fragile | `AppAuroraOpportunityColors.fragileDefense` | `#FF7D96` |
| Attaque prolifique | `AppAuroraOpportunityColors.prolificAttack` | `#57E4D5` |
| Serie positive | `AppAuroraOpportunityColors.positiveStreak` | `#89E17B` |
| Serie negative | `AppAuroraOpportunityColors.negativeStreak` | `#FF747D` |
| Equipe en difficulte | `AppAuroraOpportunityColors.strugglingTeam` | `#D68B62` |

Note : `prolificAttack` est separe de l'accent aurora. Les cotes gardent volontairement une teinte turquoise pour rester immediatement reconnues comme donnees de marche.

## Typographie

Police principale : `Inter`.

Poids utilises :

- 400 : texte courant ;
- 500 : metadonnees importantes ;
- 600 : labels et sections ;
- 700 : sous-titres ou accents ;
- 800 : boutons, chips importants ;
- 900 : titres, valeurs fortes.

Echelle actuelle :

| Style Flutter | Taille | Hauteur |
| --- | ---: | ---: |
| `displayLarge` | 57 | 1.12 |
| `displayMedium` | 45 | 1.16 |
| `displaySmall` | 36 | 1.22 |
| `headlineLarge` | 32 | 1.25 |
| `headlineMedium` | 28 | 1.28 |
| `headlineSmall` | 24 | 1.32 |
| `titleLarge` | 22 | 1.28 |
| `titleMedium` | 16 | 1.35 |
| `titleSmall` | 14 | 1.35 |
| `bodyLarge` | 16 | 1.45 |
| `bodyMedium` | 14 | 1.45 |
| `bodySmall` | 12 | 1.42 |
| `labelLarge` | 14 | 1.25 |
| `labelMedium` | 12 | 1.25 |
| `labelSmall` | 11 | 1.20 |

Regles :

- Ne pas scaler la police selon la largeur du viewport.
- Garder `letterSpacing` a `0`, sauf exigence locale justifiee.
- Les titres de sections denses doivent utiliser `titleMedium` ou `titleSmall`, pas des styles hero.
- Les valeurs numeriques importantes peuvent utiliser `headlineSmall` ou `titleLarge` avec `FontWeight.w900`.

## Espacements

Les espacements suivent une grille de 4 px.

| Token | Valeur |
| --- | ---: |
| `AppSpacing.xxs` | 4 |
| `AppSpacing.xs` | 8 |
| `AppSpacing.sm` | 12 |
| `AppSpacing.md` | 16 |
| `AppSpacing.lg` | 20 |
| `AppSpacing.xl` | 24 |
| `AppSpacing.xxl` | 32 |

Regles :

- Utiliser des multiples de 4.
- Les ecrans mobiles doivent rester denses : eviter les marges verticales gratuites.
- Les listes de matchs et de tickets doivent permettre de voir plusieurs items sans scroller excessivement.
- Les panneaux bas peuvent etre plus aeres, mais doivent rester exploitables a une main.

## Echelle Mobile Lector

Les nouveaux ecrans de refonte doivent s'aligner sur une densite mobile proche de l'ecran scores valide : l'information doit rester lisible sans devenir massive.

Regles d'echelle :

- largeur de contenu mobile : padding lateral `12` a `14` px selon le contexte ;
- espacement vertical courant : `AppSpacing.xxs` ou `AppSpacing.xs`, `AppSpacing.sm` uniquement pour separer des sections ;
- titre de panneau ou sous-ecran dense : `titleMedium`, pas `titleLarge` ;
- titre de ligne ou carte compacte : `labelLarge` ou `titleSmall` maximum ;
- texte secondaire : `labelSmall` ou `bodySmall`, avec preference pour `11` a `12` px sur les surfaces denses ;
- hauteur cible d'une ligne de selection : environ `48` a `56` px ;
- logo de championnat dans une liste dense : `28` px ;
- icone standard dans une ligne dense : `20` px ;
- bouton principal en panneau bas : hauteur `40` a `44` px ;
- bouton d'action dans une carte dense : hauteur `38` a `42` px, jamais disproportionne par rapport au contenu ;
- calendrier horizontal : hauteur minimale, jour/date seulement, sans gros conteneur vertical ;
- switch dans une liste dense : reduit visuellement, tout en gardant la ligne cliquable ;
- rayon des lignes compactes : `AppRadius.odds` ou `AppRadius.control`, pas `AppRadius.card`.

Anti-patterns :

- utiliser `ListTile` ou `SwitchListTile` brut dans un panneau mobile dense ;
- utiliser `titleLarge` pour des titres de reglage ou de liste ;
- empiler des paddings de `18` a `24` px dans un sous-ecran mobile ;
- creer des tuiles qui affichent moins de 6 lignes utiles sur un ecran mobile courant.
- grossir un composant pour donner une impression premium : la qualite vient de la hierarchie, pas de la taille.

## Rayons

| Usage | Token | Valeur |
| --- | --- | ---: |
| Cards | `AppRadius.card` | 18 |
| Inputs | `AppRadius.input` | 14 |
| Odds | `AppRadius.odds` | 10 |
| Chips | `AppRadius.chip` | 999 |
| Boutons | `AppRadius.button` | 14 |
| Controles compacts | `AppRadius.control` | 8 |
| Elements serres | `AppRadius.tight` | 6 |
| Indicateurs | `AppRadius.indicator` | 4 |

Regles :

- Les cartes principales utilisent `18`.
- Les cards imbriquees ou tableaux denses peuvent utiliser `8` ou `10` via les tokens adaptes.
- Les chips sont en pilule complete.
- Ne pas declarer de `BorderRadius.circular(18)` directement dans les widgets : passer par `AppRadius`.

## Ombres

| Usage | Token | Valeur |
| --- | --- | --- |
| Card | `AppShadows.card` | blur 30, offset `(0, 8)`, alpha equivalent `0x47` |
| Bottom panel | `AppShadows.bottomPanel` | blur 26, offset `(0, -8)`, alpha `0.34` |

Regles :

- Les ombres doivent rester discretes.
- La profondeur vient surtout du contraste surface/bordure, pas d'ombres lourdes.
- Les panneaux bas peuvent avoir une ombre superieure pour se detacher du contenu.

## Theme Flutter

`CopilotTheme.dark`, `CopilotTheme.light`, `CopilotTheme.gold` et `CopilotTheme.aurora` sont des themes distincts construits par le meme builder generique.

Mapping principal :

- `ColorScheme.primary` -> `tokens.brand.accent`
- `ColorScheme.onPrimary` -> `tokens.brand.onAccent`
- `ColorScheme.secondary` -> `tokens.semantic.info`
- `ColorScheme.error` -> `tokens.semantic.error`
- `ColorScheme.surface` -> `tokens.surfaces.background`
- `ColorScheme.surfaceContainer` -> `tokens.surfaces.surface`
- `ColorScheme.surfaceContainerHigh` -> `tokens.surfaces.surfaceHover`
- `ColorScheme.onSurface` -> `tokens.text.primary`
- `ColorScheme.onSurfaceVariant` -> `tokens.text.secondary`
- `ColorScheme.outline` et `outlineVariant` -> `tokens.surfaces.border`

## Composants Standards

### Scaffold

- Fond : `AppColors.background`.
- Les ecrans principaux doivent etre concus mobile-first.
- Le contenu doit eviter les largeurs desktop/tablette sauf contraintes de test ou web.

### AppBar et headers

- Fond : `AppColors.background`.
- Texte : `AppColors.textPrimary`.
- Elevation : `0`.
- Les actions importantes utilisent l'accent.
- Les icones secondaires utilisent `textSecondary`.

### Cards

Style standard :

- fond : `AppColors.surface` ;
- bordure : `AppColors.border` ;
- rayon : `AppRadius.card` ;
- ombre : `AppShadows.card` si la carte doit se detacher.

Regles :

- Ne pas empiler des cards dans des cards sauf cas fonctionnel clair.
- Les cards de match et ticket doivent rester compactes.
- Les sections pleine page doivent etre des bandes ou layouts non encadres, pas des cards decoratives.

### Boutons primaires

Style :

- fond : `AppColors.accent` ;
- texte : `AppColors.primaryButtonText` ;
- rayon : `AppRadius.button` ;
- elevation : `0` ;
- poids typographique : `800`.

Usage :

- action de validation ;
- action principale d'un panel ;
- navigation finale importante.

### Boutons secondaires

Style :

- fond transparent ;
- bordure : `AppColors.border` ;
- texte : `AppColors.textPrimary` ;
- rayon : `AppRadius.button`.

Usage :

- actions alternatives ;
- ouverture de filtres ;
- edition ou navigation secondaire.

### TextButton

Style :

- texte : `AppColors.accent` ;
- disabled : `AppColors.textDisabled` ;
- poids : `800`.

Usage :

- liens ;
- actions legeres ;
- annulation ou retour selon contexte.

### IconButton

Style :

- couleur : `AppColors.textSecondary` ;
- disabled : `AppColors.textDisabled`.

Regles :

- Les icones doivent etre preferentiellement issues de Material Icons actuellement.
- Les icones importantes peuvent prendre `AppColors.accent`.
- Les boutons d'action doivent avoir un tooltip quand l'action n'est pas evidente.

### Inputs

Style :

- fond : `AppColors.backgroundSecondary` ;
- bordure : `AppColors.border` ;
- focus : `AppColors.accent`, largeur `1.4` ;
- rayon : `AppRadius.input` ;
- hint : `AppColors.textWeak` ;
- label : `AppColors.textSecondary`.

Regles :

- Les placeholders peuvent contenir les valeurs par defaut.
- Les inputs numeriques doivent rester compacts.
- Les bornes ouvertes doivent etre representees explicitement par un champ max vide ou un hint `Ouverte`.

### Chips

Style :

- fond : `AppColors.backgroundSecondary` ;
- selection : `AppColors.accent` avec alpha faible ;
- bordure : `AppColors.border` ;
- rayon : `AppRadius.chip`.

Usage :

- filtres temporaires ;
- categories de lectures ;
- statuts courts ;
- valeurs resumees.

Regles :

- Les chips ne doivent pas devenir des cartes.
- Les chips selectionnees doivent rester lisibles sans sur-utiliser l'accent.

### Switchs et checkboxes

Etat actif :

- track/fill : `AppColors.accent` ;
- check/thumb : `AppColors.primaryButtonText`.

Etat inactif :

- track/fond : `AppColors.backgroundSecondary` ;
- contour : `AppColors.border`.

Etat desactive :

- `AppColors.disabledButtonBackground` ;
- `AppColors.textDisabled`.

## Navigation

Bottom navigation :

- fond : `AppColors.backgroundSecondary` ;
- item actif : `AppColors.accent` ;
- item inactif : `AppColors.textWeak` ;
- type : fixed.

Onglets :

- actif : `AppColors.accent` ;
- inactif : `AppColors.textSecondary` ;
- indicateur : `AppColors.accent` ;
- separateur : `AppColors.border`.

Regles :

- Les libelles de navigation doivent rester stables.
- La navigation mobile doit conserver les memes positions entre les ecrans principaux.
- Les panels temporaires ne doivent pas ajouter une seconde navigation inferieure.

### Selecteur De Theme

Le selecteur manuel temporaire de theme est affiche dans le header principal.

Comportement :

- bouton iconique minimaliste ;
- ouverture dans un petit overlay circulaire radial, pas dans une ligne horizontale ;
- fermeture par tap exterieur ou selection d'un theme ;
- animation discrete d'apparition/disparition par fondu et scale circulaire ;
- changement effectif du theme apres l'animation de disparition.

Regles :

- le selecteur utilise uniquement `appThemeController` ;
- les ecrans ne connaissent pas le nom de la variante active ;
- aucun widget ne doit contenir de condition liee a `Vector Gold` ou `Vector Aurora` ;
- les couleurs du menu doivent provenir des ThemeExtensions du theme courant.

## Panels Et Bottom Sheets

Les panels bas sont utilises pour :

- Mon ticket ;
- Comment ca fonctionne ;
- Historique et performances ;
- filtres d'affichage ;
- edition ponctuelle.

Style recommande :

- fond : `AppColors.surface` ou `AppColors.backgroundSecondary` selon profondeur ;
- bordure : `AppColors.border` ;
- ombre : `AppShadows.bottomPanel` ;
- rayon superieur : `AppRadius.card` ;
- drag handle discret ;
- fermeture par croix en haut a droite quand le panel est explicatif ou plein ecran.

Regles :

- Un panel doit repondre a une intention claire.
- Eviter les gros blocs de texte : preferer sections, chips, lignes compactes.
- Les actions critiques restent en bas du panel.

## Ecrans Principaux

### Pour moi

Role : afficher les opportunites selectionnees selon le profil.

Principes :

- affiche des lectures combinees et marches recommandes ;
- ne doit pas ressembler a "Toutes les rencontres" ;
- filtres centres sur la lecture : profils, opportunites avec/sans marche, competitions si necessaire ;
- ne doit pas afficher de scores de confiance arbitraires.

Vocabulaire :

- lecture Copilot ;
- lecture combinee ;
- marche recommande ;
- arguments ;
- points de vigilance.

### Toutes les rencontres

Role : explorer toutes les rencontres disponibles.

Principes :

- aucune rencontre ne doit etre masquee par le profil ;
- navigation calendrier centree sur le jour J ;
- toutes les competitions et ligues sont repliees par defaut ;
- comparaison homogene via un marche affiche global ;
- bookmaker actif global ;
- les cotes indisponibles restent visibles comme indisponibles.

### Detail rencontre

Role : expliquer une rencontre et verifier les donnees.

Principes :

- la page doit montrer pourquoi une lecture est retenue ;
- le composant "Verification des donnees" doit etre lisible et pliable ;
- classement complet visible quand necessaire ;
- forme sur 5 matchs sous forme de tableau clair ;
- marches recommandes et cotes disponibles doivent etre sous la meme banniere.

### Generateur de tickets

Role : proposer des tickets conformes aux strategies.

Principes :

- ne jamais parler de gains ;
- ne pas afficher de probabilite de victoire ;
- expliquer que les tickets respectent les strategies ;
- ne pas melanger les jours dans un meme ticket ;
- onglets : Copilot, modifies, manuels ;
- les cartes doivent afficher strategie, selections, cote totale et lectures cles.

### Mon ticket

Role : source de verite du ticket en cours.

Principes :

- un seul ticket courant partage entre les ecrans ;
- affichage uniquement s'il contient au moins une selection ;
- cote totale calculee en temps reel ;
- suppression par selection ;
- panel replie et deplie ;
- validation, sauvegarde et declaration "joue" se font depuis ce composant.

### Historique et performances

Role : memoire locale produit.

Principes :

- panel coherent avec les autres panels ;
- pas d'export tant que la fonctionnalite n'existe pas ;
- tickets groupes chronologiquement ;
- distinction Copilot, Copilot modifie, manuel ;
- KPI calcules depuis les tickets locaux ;
- structure prete pour analyses IA futures.

### Onboarding

Role : creer un profil et des strategies sans sauvegarde partielle silencieuse.

Principes :

- parcours principal V2/V3 uniquement ;
- validation finale seule persistante ;
- strategies optionnelles ;
- edition de strategie compacte ;
- pour les strategies, l'utilisateur saisit les bornes reelles plutot que de manipuler des labels abstraits.

## Logos, Drapeaux Et Assets Sportifs

Les logos et drapeaux sont des elements d'identification, pas des decorations.

Regles :

- eviter les fonds blancs disgracieux autour des logos ;
- utiliser les composants de badge sportif existants quand possible ;
- prevoir un fallback propre quand un asset distant est indisponible ;
- ne jamais laisser une erreur 404 visible degrader l'interface ;
- les drapeaux doivent rester compacts et alignes avec les textes.

Composant notable :

- `lib/features/matches/presentation/widgets/sports_asset_badge.dart`

## Regles De Densite Mobile

L'application cible un smartphone moderne.

Regles :

- plusieurs items doivent etre visibles sans scroll excessif ;
- eviter les cards trop hautes pour les listes principales ;
- les controles repetes doivent etre compacts ;
- les titres sont forts mais pas surdimensionnes hors premier niveau d'ecran ;
- les tableaux doivent privilegier la lisibilite a la decoration.

## Etats Vides Et Erreurs

Les etats vides doivent expliquer l'etape suivante, sans masquer le role de l'ecran.

Exemples :

- profil incomplet : pas de personnalisation, invitation a completer le profil ;
- profil complet sans strategie : picks disponibles, tickets automatiques indisponibles ;
- aucune opportunite sur la date : proposer de changer de date ou de verifier les filtres ;
- aucune cote : afficher `Cotes indisponibles`, ne pas substituer silencieusement un bookmaker ;
- aucune combinaison de ticket : expliquer que les contraintes ne peuvent pas etre satisfaites.

## Accessibilite Et Lisibilite

Regles :

- ne pas coder l'information uniquement par couleur ;
- accompagner les couleurs critiques par texte, icone ou label ;
- conserver des contrastes forts sur fond sombre ;
- eviter les textes trop petits dans les zones interactives ;
- les zones tactiles doivent rester confortables ;
- tout bouton iconique non evident doit avoir un tooltip.

## Contraintes De Qualite

Les tests du design system verifient actuellement :

- stabilite des couleurs principales ;
- stabilite des rayons ;
- absence de nouvelles couleurs hexadecimales directes dans les widgets de production ;
- usage de `AppColors` pour les couleurs transparentes et ombres ;
- usage de `AppRadius` pour les rayons canoniques.

Tests concernes :

- `test/core/theme/design_system_test.dart`

Avant toute modification visuelle globale, executer :

```sh
flutter analyze
flutter test
```

## Regles D'evolution

Pour ajouter une nouvelle couleur :

1. verifier qu'un token existant ne couvre pas deja l'usage ;
2. ajouter le token dans `AppColors` ou une extension de theme ;
3. documenter son role dans ce fichier ;
4. mettre a jour les tests du design system si la couleur devient canonique.

Pour ajouter un nouveau composant :

1. utiliser les tokens existants ;
2. definir ses etats : normal, actif, hover, disabled, erreur si necessaire ;
3. verifier le rendu mobile compact ;
4. eviter les valeurs magiques non justifiees.

Pour ajouter une variante visuelle future :

- creer un nouveau `VectorThemeTokens` complet ;
- reutiliser le builder generique ;
- ne pas ajouter de condition `if dark/light` dans les widgets ;
- brancher les composants sur `Theme.of(context)` ou les extensions.

## Dette Et Points A Surveiller

- Certains composants historiques utilisent encore directement `AppColors` au lieu des ThemeExtensions.
- Certains composants historiques peuvent encore utiliser des tailles locales non tokenisees.
- `AppSpacing` existe mais tous les widgets ne l'utilisent pas encore systematiquement.
- La documentation devra etre mise a jour si la terminologie produit evolue encore autour des lectures, opportunites et tickets.
