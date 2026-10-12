# Ajustements des fiches et briefings de coupes — 12 octobre 2026

## Organisation des fiches

La Champions League (API 2), l’Europa League (3) et la Conference League (848) utilisent la même composition.

- **Synthèse** : un seul bloc comparatif « Situation domestique et forme récente », puis « Parcours européen ». « Ce qu’il faut retenir » est masqué ; ses faits restent dans le dossier serveur et ne sont pas supprimés du Générateur.
- **Contexte** : restauration du composant Lector existant, avec les clés de contexte, lectures publiées et marchés associés. Aucun bloc domestique ou européen dupliqué dans cet onglet.
- **Classement** : table complète officielle de la compétition, sans répétition des deux blocs comparatifs. La garde de date antérieure au coup d’envoi est conservée. Un classement absent n’est pas remplacé par un classement actuel.
- **Forme, TAT, Marchés** : parcours détaillés, résultats, confrontations et marchés existants conservés.

## Classements et groupes

Le modèle conserve désormais la table complète de compétition et ses vues séparément du classement limité au groupe du match utilisé par les traitements existants. Ainsi, l’interface peut proposer tous les groupes sans modifier les lectures ou le calcul de classement.

Si plusieurs groupes officiels existent, le sélecteur offre « Général · tous les groupes » et chaque groupe. La vue générale juxtapose les groupes en préservant leurs rangs locaux ; elle ne crée pas un classement universel entre groupes. Les vues Domicile/Extérieur et autres vues existantes restent correctement filtrées par groupe.

La phase de ligue actuelle des trois compétitions européennes dispose d’un tableau unique. Aucun groupe fictif n’est ajouté. Le rendu commun des tables préserve également les groupes des autres compétitions ; l’activation d’un dossier de parcours pour une nouvelle coupe exige des données effectivement disponibles.

## Briefings

Les compétitions présentes dans le flux du jour sont ordonnées : Champions League, Europa League, Conference League. Plusieurs briefings se parcourent horizontalement ; des commandes précédent/suivant donnent une alternative au geste. La date ou le périmètre changeant réinitialise au premier briefing.

Suppression des catégories prédéfinies « Dynamique », « Profils de buts », « Équilibre », « Vigilances » et de leurs listes d’identifiants approximatives. La carte affiche uniquement le nombre réel de rencontres et le nombre de rencontres ayant des lectures publiées selon le composant existant. L’exploration ouvre uniquement les matchs de la compétition concernée.

Les textures existantes des trois compétitions sont réutilisées. Aucun asset ni chiffre fictif ajouté. Aucune modification des algorithmes, des accès, du modèle IA, de la Shortlist ou des règles de tickets. Aucun appel payant nécessaire aux validations.

## Validation prévue

Tests des onglets et actions à 320/375/390/430/768 px ; groupes officiels complets et filtrage ; ordre du balayage et réinitialisation ; texte agrandi ; adaptateur et garde du pipeline. Contrôle visuel de la démo après compilation et publication.
