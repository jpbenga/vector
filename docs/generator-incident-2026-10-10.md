# Générateur démo — dépassement du délai du 10 octobre

## Incident observé

La requête commencée le 10 octobre 2026 à 19:37:10, heure de Paris, a échoué
après 131 118 ms avec `TimeoutError: Signal timed out.` La comparaison portait
sur le dimanche 11 octobre, Pour moi, football et hockey, selon un écart de
forme documenté, afin d’examiner dix rencontres.

Les traces enregistrées montrent 79 rencontres attendues, récupérées, préparées
et évaluées, sans lot manquant. L’évaluation parallèle a duré 16 888 ms.
L’échec est survenu dans la boucle conversationnelle suivante, avant sa réponse
finale. Le dernier appel IA a échoué sans reçu de tokens, après environ 16 s.

Le contexte des appels conversationnels est passé d’environ 11 000 à 119 000
tokens. La boucle ajoutait tous les retours d’outils : faits des tickets répétés
entre marchés et variantes, consultations répétées, puis nouvelles lectures.
Le cache de préfixe était actif, mais ne supprimait pas ces données du contexte.
Une consultation du samedi 10 apparaît aussi après l’évaluation du dimanche ;
le texte original du message échoué n’a pas été enregistré dans l’état final.
On ne peut donc pas déterminer à partir des traces seules si cette consultation
était demandée ou constituait un détour lié aux anciens tickets de la session.

Le champ `failure_stage` indiquait à tort le dernier RPC de pagination : une
variable globale conservait cette valeur pendant les appels OpenAI suivants.
Les pages étaient pourtant toutes revenues. Ce défaut rendait le message
« récupération des données trop longue » trompeur.

GPT-6 Luna a été utilisé. Les reçus disponibles totalisent une estimation de
0,081 à 0,097 USD ; ce n’est pas une facture et le dernier appel sans reçu n’est
pas inclus. Les évaluations terminées restent enregistrées et peuvent être
réutilisées si leur critère, modèle, sources et durée de validité correspondent.

## Correctif

- Les retours de composition utilisent un dictionnaire de faits, commun aux
  variantes. Chaque sélection conserve ses références et son rôle propre : un
  même fait peut soutenir un marché et constituer une vigilance pour un autre.
- Les détails de marché utilisent l’identité de la rencontre et ses faits déjà
  fournis, sans répéter logos, photos, noms et métadonnées de présentation.
  Les prix, horodatages, bookmaker, références, données sportives, limites et
  éléments de robustesse restent disponibles.
- Une consultation identique dans le même échange référence son premier
  `call_id`. La première réponse reste intégralement présente. Aucun élément
  de raisonnement, appel ou retour d’outil déjà transmis n’est réécrit/supprimé.
- La boucle garde son délai de 130 s et réserve ses 35 dernières secondes à
  la réponse finale. Elle indique les données manquantes au lieu de poursuivre
  indéfiniment les consultations ou d’inventer une composition.
- Les exceptions portent l’opération qui a effectivement échoué. Un délai
  OpenAI n’est plus présenté comme un délai de récupération Supabase.

Les tickets persistés et les composants de l’application conservent leurs faits
complets. L’évaluation individuelle de toutes les rencontres, la comparaison
globale et les validations de périmètre/marché ne sont pas réduites.

## Vérification

Tests avec réponses simulées, sans appels OpenAI payants : continuité football et
hockey, preuve propre à chaque marché, rôles contradictoires d’un même fait,
rejeu Responses inchangé, consultation répétée, fenêtre de réponse finale,
distinction des erreurs et comparaison de 500 rencontres incluant des candidats
en fin de liste.

Ce correctif doit encore être mesuré sur des demandes réelles : le test simulé
ne démontre pas une latence OpenAI réelle ni une garantie de réponse en 30 s.

La conservation des éléments Responses suit la
[documentation officielle OpenAI](https://developers.openai.com/api/docs/guides/reasoning).
