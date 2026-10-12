# Forme domestique des cartes européennes — 12 octobre 2026

## Cause vérifiée

La carte utilisait `homeRecentLeagueMatches` et `awayRecentLeagueMatches` de la compétition européenne lorsque les deux anciens contextes domestiques n’étaient pas présents. La liste allégée omettait le dossier de parcours, et le regroupement des snapshots du transport de secours écartait également ce dossier. Liverpool apparaissait ainsi avec une seule rencontre de Champions League malgré cinq résultats de Premier League disponibles dans le dossier de LASK–Liverpool (fixture 1635674, 14 octobre).

## Correction

- Les cartes des compétitions 2, 3 et 848 utilisent les résultats domestiques du même dossier que la fiche détaillée.
- Les listes reçoivent une projection `european_card_forms` limitée aux cinq résultats réels par club, à son championnat et aux identifiants de la rencontre.
- Les parcours européens, classements et bilans complets restent dans la fiche individuelle.
- Les deux clubs restent sur le périmètre championnat même si un côté a des données partielles ou absentes. Un échantillon européen ne remplace plus une forme domestique absente.
- Les dates, identifiants, compétitions et saisons sont contrôlés ; les observations restent chronologiques, antérieures au coup d’envoi et sans remplissage fictif.
- La date de la source domestique est utilisée lorsque le dossier a été enrichi après la capture initiale du calendrier. Les résultats collectés dans cet enrichissement ne sont plus éliminés par une date de calendrier plus ancienne.
- Les contextes sont indexés par fixture pour éviter de redécoder tous les dossiers pour chaque carte.
- Le transport de secours conserve les dossiers et leur identité de compétition.

## Projection de la démo

108 rencontres européennes sur six journées (13, 14, 15, 20, 21, 22 octobre) ; 840 résultats domestiques réels transportés. La différence totale est de 234 470 octets, soit environ 2,2 ko par rencontre. Les nouveaux chemins journaliers sont dérivés du contenu et préservent les fichiers précédents.

84 clubs distincts disposent de leur forme domestique ; 24 autres ont encore un championnat domestique non résolu dans les publications existantes. Cette limite de données concerne notamment Slavia, Sparta, Plzen, Shakhtar et certains clubs de championnats moins couverts. Ils affichent une forme indisponible, jamais leur unique résultat européen présenté comme une forme de championnat. La correction du raccordement ne certifie pas la couverture de ces clubs.

## Validation

40 tests Flutter ciblés réussis, dont un contrat extrait des données publiques réelles de LASK–Liverpool ; 7 tests Deno du flux réussis. Les contrôles couvrent la parité carte/fiche, les cinq résultats de Liverpool, l’absence d’un côté, les données partielles, les mauvaises identités, les dates futures, les saisons incorrectes, le dédoublonnage et les largeurs 320/375/390/430/768 px.

Aucun appel IA ou collecte fournisseur lancé pour cette correction. Les observations hockey existantes et leurs dates restent distinctes de ce chantier football ; leur expiration connue n’est pas masquée.

## Livraison vérifiée

- CI complète verte : https://github.com/jpbenga/vector/actions/runs/38282536644 (source `1dfcec4`).
- Déploiement `dpl_CNjqBfLDJFZnB5gPVrFhnzz1CE3v` prêt, alias démo habituel mis à jour. Le premier refus Vercel « Not authorized » ne s’est pas reproduit après vérification du compte et du projet puis nouvel essai.
- Carte réelle contrôlée sur le lien public, 14 octobre : LASK **V V D N D**, Liverpool **N V N V D**, cinq cellules pour chaque club et libellé « Forme (championnat) ».
- Capture : `lask-liverpool-five-domestic-results.png` dans le dossier de visualisations de cette conversation.
