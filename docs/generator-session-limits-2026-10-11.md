# Générateur : fonctionnement et limites de la session

Audit du code le 11 octobre 2026. Ces valeurs décrivent le code ; aucune mesure de la session personnelle ni recherche d’incident n’a été effectuée dans cet audit.

**Mise à jour :** les plafonds cumulatifs décrits ci-dessous sont l’état avant correction. Le parcours démo dispose maintenant d’un [stockage de travail indépendant](generator-work-storage-2026-10-11.md) ; analyses et tickets sont archivés hors du document compact de session. Les limites par appel et les durées de conservation restent distinctes.

## Trois volumes distincts

1. **Session Lector persistante.** Supabase conserve messages, contraintes de travail, références des rencontres, analyses récentes, brouillons et versions. Le client conserve seulement la référence de la conversation dans un cache isolé par compte. Ce n’est pas une conversation hébergée chez OpenAI : les appels Responses utilisent `store: false`.
2. **Données consultées.** Les outils récupèrent des publications par pages et construisent les fiches et catalogues. Ce travail n’est pas intégralement ajouté à l’historique du chat. Le lecteur de journée accepte jusqu’à 32 Mio de transport cumulé ; les pages dépassant 1,5 Mo sont subdivisées. Une lecture incomplète ne doit pas être annoncée comme exhaustive.
3. **Contexte d’un appel au modèle.** Instructions, état de travail compact, messages utiles, appels d’outils et leurs résultats. Le code applique une limite de 1 200 000 octets UTF-8 avant chaque appel conversationnel. Ce n’est ni un nombre de tokens ni la capacité de contexte publiée par OpenAI.

## Limites relevées

| Niveau | Limite actuelle | Unité et effet |
| --- | ---: | --- |
| Mémoire de travail conversationnelle | 50 000 | Caractères JSON ; retire les anciens tours du registre compact, en gardant les contraintes courantes. |
| État complet après un tour conversationnel | 210 000 | Longueur JavaScript du JSON compact ; peut refuser un nouveau résultat après réduction des anciens objets. |
| Parcours d’analyse antérieur | 180 000 | Longueur JavaScript du JSON compact ; garde une marge avant la validation SQL. |
| Validation d’enregistrement SQL | 250 000 | Caractères du texte JSONB PostgreSQL, dont le format diffère du JSON compact JavaScript. |
| Appel conversationnel OpenAI | 1 200 000 | Octets du corps JSON en UTF-8. |
| Requête client normale | 75 000 | Caractères du corps reçu ; le client envoie un message et des références, pas un snapshot complet. |

Un caractère français, une unité de longueur JavaScript, un octet UTF-8 et un token ne sont pas interchangeables. Il n’existe pas de nombre fiable de messages ou de rencontres correspondant à ces plafonds : vingt sélections richement documentées peuvent prendre davantage de place qu’une longue conversation en texte seul.

La session démo expire par défaut 24 h après la dernière activité reconnue, au plus tard sept jours après sa création. Lire ou scroller ne prolonge pas cette durée. Les paramètres serveur sont `lector_generator_retention`. Les tickets explicitement conservés survivent à la suppression de la conversation.

## Pourquoi « trop de données » peut arriver

Le même fait peut se retrouver dans un candidat d’analyse, une sélection de ticket, plusieurs variantes et un ancien brouillon. Une seule réponse avec plusieurs tickets peut donc être volumineuse. La réduction actuelle retire certaines analyses anciennes, versions, brouillons et messages ; elle ne suffit pas si les derniers objets eux-mêmes dépassent la limite.

Cette erreur est une limite de représentation et de conservation de Lector. Elle ne prouve pas que le modèle ne peut pas examiner la journée. Inversement, une erreur du contexte d’appel porte sur les données d’un appel, pas sur la durée de la session. Les messages exacts et les reçus serveur doivent être utilisés pour attribuer un incident à la bonne limite.

## Correction engagée avec la Shortlist

- Le contexte persistant contient `sessionId`, `revision`, `keys`, et l’échéance ; les lignes hydratées des rencontres ne sont pas recopiées dans chaque ticket et tour.
- Le serveur vérifie le propriétaire, les dates et l’appartenance, puis relit les publications.
- Le manifeste est vérifié, mais seules les références choisies sont transportées par pages. Les données d’autres rencontres n’encombrent pas une préparation Shortlist.
- Les objets déjà enregistrés gardent leurs snapshots et justifications.

Cela réduit l’encombrement introduit par la Shortlist. Cela ne supprime pas les limites existantes des tickets et analyses riches.

## Architecture à poursuivre pour les grandes conversations

Conserver les tickets, versions et évaluations détaillés dans leurs objets persistants, puis garder dans la session les identifiants, les contraintes exactes et un registre compact des décisions. La consultation d’un ancien ticket doit résoudre sa référence, sans perdre son état d’origine. Les traces d’outils répétées doivent aussi être compactées dans le contexte d’appel, en préservant les obligations de rejeu de Responses et la provenance des faits.

Mesurer à chaque tour la taille par composant (messages, analyses, tickets, versions, contexte), les octets envoyés et les tokens facturés. Tester les grandes préparations et leurs modifications successives. Augmenter un plafond seul augmente transport, latence et coût potentiel sans résoudre les répétitions.
