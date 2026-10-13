"""Join the unchanged pilot artifacts with explicit, non-final review notes."""
import hashlib
import json
from collections import Counter
from pathlib import Path

base = Path("output/generator-exploration-run-38462876424/files")
out = Path("output/generator-exploration-review-38462876424")
report_bytes = (base / "checkpoint.json").read_bytes()
report = json.loads(report_bytes)
notes = json.loads((out / "notes-revue.json").read_text())
checks = json.loads((out / "offline-checks.json").read_text())
sheets = {s["key"]: s for s in report["snapshot"]["sheets"]}
annotations = {f"football:{n['id']}": n for n in notes["matches"]}
assert len(annotations) == 20 and set(annotations) == {r["key"] for r in report["rows"]}
ranks = {k: i + 1 for i, k in enumerate(report["exploration"]["rankedKeys"])}
reviewed = []
for index, row in enumerate(report["rows"], 1):
    sheet = sheets[row["key"]]
    facts = {f["id"]: f for f in sheet["facts"]}
    assert all(k in facts for k in row["references"] + row["vigilanceReferences"])
    assert all(facts[k]["source"] == "reading" for k in row["references"])
    assert sheet["form"]["home"]["state"] == sheet["form"]["away"]["state"] == "unverified"
    reviewed.append({
        "reviewId": f"M{index:02}",
        "match": sheet["match"],
        "criterion": report["criteria"],
        "modelEvaluation": row,
        "rankWithinEvaluatedTwenty": ranks[row["key"]],
        "retained": row["key"] in report["exploration"]["selectedKeys"],
        "publishedReadings": [f for f in sheet["facts"] if f["source"] == "reading"],
        "usedReadings": [facts[k] for k in row["references"]],
        "uncitedReadings": [f for f in sheet["facts"] if f["source"] == "reading" and f["id"] not in row["references"]],
        "vigilanceReadings": [facts[k] for k in row["vigilanceReferences"]],
        "domesticForm": {"home": "unverified", "away": "unverified", "certifiedResults": 0},
        "validity": {"publicationText": "conforme", "underlyingSportingData": "non vérifiable", "humanApproved": None},
        "review": annotations[row["key"]],
    })

summary = {
    "status": "human-review-pending",
    "reviewer": notes["reviewer"],
    "humanApproval": None,
    "sourceRunId": 38462876424,
    "sourceCheckpointSha256": hashlib.sha256(report_bytes).hexdigest(),
    "realModelCallsDuringReview": 0,
    "algorithmsModified": False,
    "coverage": {"reviewed": 20, "manifest": 119, "notEvaluated": 99},
    "dimensions": {d: dict(Counter(str(r["review"][d]) for r in reviewed)) for d in ["pertinence", "construction", "explication"]},
    "matches": reviewed,
}
(out / "evaluations-revues.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")

main = """# Lector — revue du premier pilote IA réelle

**Statut : `human-review-pending`. Revue préparatoire par Codex ; décision humaine requise.**

Les vingt évaluations sont fidèles aux chiffres et aux lectures archivés. Leur classement et leur restitution ne suffisent pas encore à valider la qualité sportive du Générateur. Aucun nouvel appel IA, changement d'algorithme ou déploiement n'a été exécuté.

## Résultats principaux

| Contrôle | Résultat |
| --- | --- |
| Observations revues | 20/20 acceptées dans le run `38462876424` |
| Références citées | 38/38 rattachées à des lectures configurées de leur rencontre |
| Faits numériques des motifs | Aucune invention détectée en comparaison avec les textes publiés |
| Forme domestique certifiée | 0 ; aucune évaluation ne prétend explicitement l'avoir vérifiée |
| Limite de provenance rappelée localement | 14/20 ; les six autres héritent seulement du garde-fou global |
| Lectures / doublons Radar transmis | 40 lectures et 21 reprises Radar des mêmes données ; aucun Radar cité comme preuve supplémentaire |
| Contrôle arithmétique des séquences publiées | 18 séquences de cinq symboles cohérentes avec leurs points ; résultats sources toujours non certifiés |

Il s'agit de validité **vis-à-vis des publications**. Les matchs, adversaires, dates et statuts des cinq résultats sous-jacents ne sont pas vérifiables dans ce corpus. L'absence de cote n'a pas bloqué les observations ; aucun marché, prix ou pourcentage de réussite n'a été inventé.

## Quatre dimensions, évaluées séparément

| Dimension | Appréciation préparatoire |
| --- | --- |
| Validité | Fidélité aux textes satisfaisante sur les vingt motifs ; données sportives sous-jacentes non vérifiables. |
| Pertinence | Arguments individuels liés au critère. La préférence entre alternatives et la signification d'un score « net » restent peu expliquées. |
| Construction | Réserves utiles, mais dépendance des lectures rarement explicitée et signaux bilatéraux parfois assimilés à des contradictions. |
| Explication | Motifs courts et chiffrés. Limites de provenance et de temporalité inégales dans les observations prises isolément. |

Dans le tableau, **V = conforme au texte publié**, P/C/E = pertinence, construction de l'argument et explication. Les niveaux 0–3 suivent le référentiel Lector ; ils sont proposés à la revue humaine, sans moyenne ni score de pari. La construction est ici examinée au niveau des preuves et réserves d'une observation ; celle de la liste entière est traitée ensuite. Aucun niveau 3 n'est attribué : les alternatives ne sont pas explicitement comparées par le modèle.

## Résultats par rencontre

Les compétitions, motifs exacts, lectures utilisées et identifiants complets des preuves sont dans l'[annexe des vingt observations](ANNEXE-20-RENCONTRES.md). Les rangs ci-dessous portent sur les **vingt évaluations seulement**.

| Repère | Rencontre | Rang | Fit IA | V | P/C/E | Réserve principale |
| --- | --- | ---: | ---: | --- | --- | --- |
"""
for r in reviewed:
    m, n = r["match"], r["review"]
    main += f"| [{r['reviewId']}](ANNEXE-20-RENCONTRES.md#{r['reviewId'].lower()}) | {m['home']} – {m['away']} | {r['rankWithinEvaluatedTwenty']} | {r['modelEvaluation']['fit']} | conforme | {n['pertinence']}/{n['construction']}/{n['explication']} | {n['note']} |\n"

main += """
## Classement partiel : ce que l'ordre signifie réellement

```text
Appréciation IA : fit 0–4 + supported / mixed / insufficient
                         |
                         v
Tri serveur : fit décroissant → supported avant mixed → identifiant croissant
                         |
                         v
Dix premières observations du sous-ensemble évalué
```

- Une rencontre est notée 4 ; huit sont notées 3 ; onze sont notées 2, dont une `mixed`.
- Les rangs **2 à 9** sont huit égalités `3/supported`, départagées par identifiant.
- Les rangs **10 à 19** sont dix égalités `2/supported`. Une seule place est disponible dans la liste : **Cerezo–Yokohama est dixième à cause de son identifiant**.
- Kyoto–Machida, Blackburn–Cardiff, Preston–Millwall, Sheffield–Lincoln et West Brom–Birmingham sont les cinq alternatives archivées proches de la frontière. Leur exclusion est `stable_tie_break`, sans preuve d'infériorité sportive.
- Instituto–Boca est vingtième : même fit 2, mais `mixed`, donc placé après les dix autres fit 2. Les signaux favorables aux deux équipes ne constituent pas en eux-mêmes une contradiction logique ; cette notion reste à clarifier selon l'objectif.

Le moteur respecte son contrat de tri. **Un ordre reproductible ne fournit pas une justification sportive pour chaque rang.** Le score ordinal est très peu discriminant à la frontière. Le dossier cite correctement les arguments, mais ne produit pas d'arbitrage explicite entre Cerezo–Yokohama et les alternatives.

Watford–Burnley est retenu pour deux méformes, alors que d'autres rencontres montrent un avantage d'équipe. Ces deux profils peuvent intéresser une exploration des lectures. Le critère actuel n'impose pas de préférer systématiquement un avantage clair ; la liste ne doit pas être présentée comme les « meilleures équipes » ou les « meilleurs paris ».

## Temporalité et origine des défauts

Cinq rencontres ont commencé à l'heure de capture : Cerezo–Yokohama (`1H`), Tokyo–Urawa et Avispa–Okayama (`NS` malgré l'heure passée), Instituto–Boca et Union–Defensa (`FT`). **Quatre figurent dans les dix retenues**, dont Union–Defensa au deuxième rang.

La campagne examine toutes les lectures publiées du jour, y compris les observations historiques : ces rencontres restent valides dans son manifeste. Leur usage pour une préparation prématch est exclu ; la disponibilité ne doit pas être déduite du rang. Les agrégats capturés après leur coup d'envoi ne sont pas certifiés comme connus avant la rencontre. Les deux statuts `NS` en retard sont un défaut de publication, pas une invention du modèle.

| Origine | Défaut ou limite constaté |
| --- | --- |
| Modèle | Deux lectures de Darmstadt non discutées ; méforme de Cardiff citée sans être expliquée ; omissions locales de provenance et de temporalité ; ambiguïté sur le `sample=4` de Tokyo. |
| Publications / projection | Séries domestiques non certifiables ; statuts en retard ; métriques parfois rendues `[object Object]` ; séries de trois victoires avec un `sample=4` dont le texte dit « quatrième en jeu » ; Radar reprenant les mêmes données. |
| Contrat et tri | Critère large, scores ordinaux concentrés, égalités départagées par identifiant, préférences entre alternatives non expliquées. |

« Lectures concordantes » n'affirme pas à elle seule deux confirmations indépendantes. Nous ne pouvons pas démontrer que les doublons Radar ont gonflé les notes : aucun essai contrefactuel n'a été exécuté. Swansea est l'exemple satisfaisant qui explicite le partage d'échantillon ; les autres assemblages corrélés méritent la même précision.

## Effet de l'ordre d'entrée

Les vingt rencontres évaluées sont les **vingt premières fiches** de l'ordre source, couvrant quatre compétitions : 2. Bundesliga (4), Championship (10), J1 League (4), Liga Profesional Argentina (2). L'arrêt au plafond produit un biais de **couverture**, pas la preuve d'un biais de notation du modèle.

Trois permutations hors ligne des résultats déjà notés donnent exactement le même classement : ordre inversé, rotation de sept lignes et inversion simultanée des fiches et des résultats. Cela confirme la stabilité du tri serveur. L'influence de l'ordre dans les prompts, l'étalonnage entre lots et la stabilité du modèle demanderaient des appels distincts autorisés ; ils restent non testés.

## Corrections recommandées, par priorité

1. **P1 — Expliciter le mandat et la temporalité.** Séparer observation de lectures, comparaison des dynamiques et éligibilité prématch dans la restitution. Conserver le manifeste et son horodatage. Ne pas présenter les résultats de cette archive comme des choix disponibles aujourd'hui.
2. **P1 — Afficher les égalités honnêtement.** Présenter la frontière comme un groupe d'observations équivalentes pour le score actuel ; afficher le départage par identifiant. La sélection des alternatives doit rester justifiée par les preuves disponibles.
3. **P1 — Uniformiser les limites de provenance.** Rendre le garde-fou « lectures publiées, résultats domestiques non certifiés » visible pour toute observation, y compris isolée.
4. **P2 — Nommer les relations entre preuves.** Distinguer dépendance d'échantillon, signaux favorables aux deux équipes, réserve et contradiction. Examiner les lectures non retenues dans le motif sans transformer leur absence en performance négative.
5. **P2 — Nettoyer la projection.** Clarifier `sample=4` avec trois victoires acquises, les objets de métriques et les horodatages/statuts. Ne pas corriger silencieusement l'archive de référence.
6. **P2 — Mesurer la notation sur un échantillon plus large.** Le pilote ne suffit pas à modifier les pondérations ou l'algorithme ; un test d'ordre du modèle sera une campagne séparée.

Ces corrections sont des recommandations. Les algorithmes, instructions du moteur et artefacts originaux restent inchangés dans cette mission.

## Recommandation sur le second pilote

**Je recommande une décision humaine sur ces limites avant tout nouveau lancement payant.** La reprise technique est prête à être planifiée, mais la sélection sportive reste insuffisamment justifiée à la frontière. Un second pilote pourra être utile comme validation de couverture complète et de continuité, avec les règles actuelles conservées et leurs limites affichées. Il ne vaudra pas validation automatique de la qualité sportive.

Le [plan de reprise proposé](PLAN-SECOND-PILOTE.md) conserve les vingt évaluations, prévoit dix appels supplémentaires au maximum et un plafond additionnel de 0,10 USD à autoriser. Aucun lanceur de reprise payante n'a été créé ou activé.

## Pièces de vérification

- [Vingt évaluations, preuves et notes de revue](evaluations-revues.json).
- [Contrôles hors ligne, permutations et plan de lots](offline-checks.json).
- [Notes d'appréciation soumises à décision humaine](notes-revue.json).

**Statut maintenu : `human-review-pending`. Nouveaux appels IA : 0.**
"""
(out / "REVUE.md").write_text(main)

annex = """# Annexe — vingt évaluations du pilote

**Revue préparatoire, `human-review-pending`.** Chaque motif ci-dessous est la réponse exacte du modèle ; les remarques sont celles de Codex, soumises à décision humaine. L'identité, la compétition et les preuves proviennent du checkpoint, sans consultation d'API sportive. « Conforme » désigne la fidélité au texte publié ; les séries domestiques ne sont certifiées pour aucune de ces rencontres.

Critère commun : **lectures de forme publiées configurées ; séries domestiques non vérifiables, hors critère**. Profil figé : `form_advantage`, `improving_form`, `negative_streak`, `winning_streak` ; alias métier conservés. P/C/E utilisent le référentiel interne 0–3 sans moyenne.

"""
for r in reviewed:
    m, e, n = r["match"], r["modelEvaluation"], r["review"]
    annex += f"<a id=\"{r['reviewId'].lower()}\"></a>\n\n## {r['reviewId']} — {m['home']} – {m['away']}\n\n"
    annex += f"**{m['competition']} · `{m['key']}` · {m['kickoff']} · statut publié `{m['status']}`.** Capture : `{m['capturedAt']}`.\n\n"
    annex += f"Rang **{r['rankWithinEvaluatedTwenty']}/20** · {'retenue' if r['retained'] else 'non retenue'} · fit **{e['fit']}/4** · `{e['status']}` · candidat de marché : `null`.\n\n"
    annex += f"> {e['reason']}\n\n"
    annex += "**Lectures utilisées et preuves exactes :**\n\n"
    for fact in r["usedReadings"]:
        annex += f"- **{fact['label']}**, sujet `{fact['subject']}` : {fact['text']} Référence : `{fact['id']}` ; sample publié `{fact.get('sample')}`.\n"
    if r["uncitedReadings"]:
        annex += "\n**Lectures présentes mais non citées :**\n\n"
        for fact in r["uncitedReadings"]:
            annex += f"- {fact['text']} Référence : `{fact['id']}`.\n"
    annex += "\n**Réserves du modèle :** " + " · ".join(e["limitations"]) + "\n\n"
    annex += "**Références de vigilance :** " + (" ; ".join(f"`{v}`" for v in e["vigilanceReferences"]) if e["vigilanceReferences"] else "aucune ; cela ne certifie pas une absence de contradiction") + ".\n\n"
    annex += f"**Revue :** V conforme au texte publié ; P={n['pertinence']}, C={n['construction']}, E={n['explication']}. {n['note']}\n\n"
    annex += "**Frontière des données :** deux états de forme `unverified`, zéro résultat domestique certifié. Les agrégats de points et séquences sont des contenus de lectures publiées, pas une vérification des cinq matchs sources.\n\n"
(out / "ANNEXE-20-RENCONTRES.md").write_text(annex)
assert (base / "checkpoint.json").read_bytes() == report_bytes
assert len(reviewed) == 20 and len({r["match"]["key"] for r in reviewed}) == 20
print(json.dumps({"reviewed": 20, "realModelCalls": 0, "status": "human-review-pending", "dimensions": summary["dimensions"]}, ensure_ascii=False))
