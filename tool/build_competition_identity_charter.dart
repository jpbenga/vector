import 'dart:io';

/// Generates the reviewable identity charter from the approved competition
/// perimeter. The output is documentation only: it does not alter runtime
/// competitions, scheduled jobs, or the application UI.
void main() {
  const input = 'docs/competition-scope-approved.csv';
  const markdownOutput = 'docs/competition-identity-charter.md';
  const csvOutput = 'docs/competition-identity-registry-proposal.csv';
  const htmlOutput = 'docs/competition-identity-preview.html';
  const svgOutput = 'docs/competition-identity-preview.svg';

  final competitions = _readScope(File(input));
  final entries = competitions.map(_identityFor).toList(growable: false);
  if (entries.length != 74) {
    throw StateError(
      'Expected 74 approved competitions, got ${entries.length}.',
    );
  }

  File(markdownOutput).writeAsStringSync(_toMarkdown(entries));
  File(csvOutput).writeAsStringSync(_toCsv(entries));
  File(htmlOutput).writeAsStringSync(_toHtml(entries));
  File(svgOutput).writeAsStringSync(_toSvg(entries));
  stdout.writeln('TOTAL=${entries.length}');
  stdout.writeln('MARKDOWN=$markdownOutput');
  stdout.writeln('CSV=$csvOutput');
  stdout.writeln('HTML=$htmlOutput');
  stdout.writeln('SVG=$svgOutput');
}

List<_Competition> _readScope(File file) {
  return file
      .readAsLinesSync()
      .skip(1)
      .map(_parseCsvRow)
      .where((cells) => cells.length >= 6)
      .map(
        (cells) => _Competition(
          id: int.parse(cells[0]),
          name: cells[1],
          country: cells[2],
          type: cells[3],
          season: cells[4],
        ),
      )
      .toList(growable: false);
}

List<String> _parseCsvRow(String line) {
  final cells = <String>[];
  final buffer = StringBuffer();
  var quoted = false;
  for (var index = 0; index < line.length; index++) {
    final character = line[index];
    if (character == '"') {
      if (quoted && index + 1 < line.length && line[index + 1] == '"') {
        buffer.write('"');
        index++;
      } else {
        quoted = !quoted;
      }
    } else if (character == ',' && !quoted) {
      cells.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(character);
    }
  }
  cells.add(buffer.toString());
  return cells;
}

_Identity _identityFor(_Competition competition) {
  const colors = <int, String>{
    2: '#071A4D',
    3: '#E87924',
    848: '#159B7D',
    531: '#B9C4D0',
    39: '#7A3FAC',
    61: '#2975D9',
    140: '#E95757',
    78: '#D83245',
    135: '#276BC4',
    94: '#16835B',
    95: '#5AABDD',
    88: '#F17B38',
    144: '#E8B933',
    179: '#7546AD',
    203: '#E65378',
    197: '#2F73B8',
    119: '#DC3E42',
    207: '#D14C58',
    218: '#A83242',
    40: '#3C77A8',
    62: '#83B9EF',
    136: '#2B66AD',
    79: '#D54550',
    141: '#E49E2E',
    106: '#E13E43',
    210: '#D74B55',
    209: '#E0BB63',
    283: '#2E578E',
    253: '#39A9DF',
    71: '#1DA96B',
    128: '#3B72D6',
    262: '#E87845',
    307: '#0F9991',
    98: '#D4415D',
    188: '#EEA15A',
    103: '#3B9A7B',
    113: '#E9B231',
    164: '#3865A2',
    169: '#C23D57',
    244: '#3C7D96',
    292: '#E85C59',
    45: '#E84B3D',
    48: '#699BCB',
    528: '#C99C3F',
    66: '#C7A02C',
    526: '#2B427E',
    81: '#D43843',
    529: '#D73747',
    96: '#2A9D71',
    550: '#3BAE83',
    143: '#E54F3F',
    556: '#D85B45',
    137: '#189676',
    547: '#1B997B',
    90: '#DF7830',
    543: '#EB7D3C',
    147: '#E44850',
    519: '#E64C51',
    181: '#714EAC',
    185: '#C56F46',
    551: '#E65478',
    1: '#B72C46',
    32: '#427DBE',
    4: '#269A85',
    5: '#273D86',
    9: '#4281A4',
    6: '#CE8A2C',
    7: '#B4404A',
    22: '#D29E26',
    536: '#3D638E',
    64: '#D04592',
    525: '#533DB9',
    1191: '#BD5BA7',
    8: '#7C4A95',
  };

  final family = _familyFor(competition.id);
  return _Identity(
    competition: competition,
    color: colors[competition.id]!,
    family: family,
    frame: _frameFor(family),
    cartouche: _cartoucheFor(family),
    label: _labelFor(family),
  );
}

String _familyFor(int id) {
  if (id == 2 || id == 3 || id == 848 || id == 525 || id == 1191) {
    return 'Europe des clubs';
  }
  if (id == 531 ||
      <int>{528, 526, 529, 550, 556, 547, 543, 519, 551}.contains(id)) {
    return 'Supercoupe';
  }
  if (<int>{
    45,
    48,
    66,
    81,
    96,
    143,
    137,
    90,
    147,
    181,
    185,
    209,
  }.contains(id)) {
    return 'Coupe nationale';
  }
  if (id == 32) return 'Qualifications internationales';
  if (<int>{1, 4, 5, 6, 7, 9, 22, 536, 8}.contains(id)) {
    return 'Sélections internationales';
  }
  if (id == 64) return 'Championnat féminin';
  return 'Championnat';
}

String _frameFor(String family) => switch (family) {
  'Championnat' => '#1 Fil continu',
  'Championnat féminin' => '#2 Cadre intérieur',
  'Coupe nationale' => '#4 Rails ouverts',
  'Supercoupe' => '#5 Pont central',
  'Europe des clubs' => '#12 Cadre galerie',
  'Qualifications internationales' => '#11 Cadre segmenté',
  'Sélections internationales' => '#3 Coins verrouillés',
  _ => throw ArgumentError.value(family),
};

String _cartoucheFor(String family) => switch (family) {
  'Championnat' => '#7 Biseauté',
  'Championnat féminin' => '#6 Onglet affleurant',
  'Coupe nationale' => '#8 Capsule',
  'Supercoupe' => '#9 Double cartouche',
  'Europe des clubs' => '#12 Capsule galerie',
  'Qualifications internationales' => 'Passeport',
  'Sélections internationales' => '#7 Biseauté',
  _ => throw ArgumentError.value(family),
};

String _labelFor(String family) => switch (family) {
  'Championnat' => 'JOURNÉE 5',
  'Championnat féminin' => 'JOURNÉE 5',
  'Coupe nationale' => 'HUITIÈME DE FINALE',
  'Supercoupe' => 'FINALE',
  'Europe des clubs' => 'NUIT EUROPÉENNE',
  'Qualifications internationales' => 'QUALIFICATIONS',
  'Sélections internationales' => 'PHASE DE GROUPES',
  _ => throw ArgumentError.value(family),
};

String _toMarkdown(List<_Identity> entries) {
  final grouped = <String, List<_Identity>>{};
  for (final entry in entries) {
    grouped.putIfAbsent(entry.family, () => []).add(entry);
  }
  final buffer = StringBuffer()
    ..writeln('# Charte d’identité des compétitions')
    ..writeln()
    ..writeln(
      'Document de validation visuelle. Le canvas de référence associé est la source de vérité des silhouettes ; aucune variation libre de cadre ou de cartouche n’est admise.',
    )
    ..writeln()
    ..writeln('## Règle de composition')
    ..writeln()
    ..writeln('| Élément | Rôle | Source |')
    ..writeln('| --- | --- | --- |')
    ..writeln(
      '| Couleur propriétaire | Rend immédiatement la compétition reconnaissable dans le bandeau horizontal. | Registre par ID API |',
    )
    ..writeln(
      '| Cadre | Exprime le format de la rencontre : championnat, coupe, Europe, sélection. | Famille de compétition |',
    )
    ..writeln(
      '| Cartouche | Affiche le statut réel de l’épreuve : journée, tour, finale, qualifications, nuit européenne. | Données de la rencontre |',
    )
    ..writeln()
    ..writeln(
      'La couleur ne remplace jamais le logo officiel ni le nom de compétition. Le bleu nuit `#071A4D` reste exclusif à l’UEFA Champions League masculine.',
    )
    ..writeln()
    ..writeln('## Canvas de référence contractuel')
    ..writeln()
    ..writeln(
      '![Atlas des cadres et cartouches](competition-identity-canvas-reference.png)',
    )
    ..writeln()
    ..writeln(
      'Les numéros de cet atlas sont la convention de cette charte. Les cadres et cartouches du registre doivent reprendre ces silhouettes, sans variante graphique implicite.',
    )
    ..writeln()
    ..writeln('## Familles de cadre et cartouche')
    ..writeln()
    ..writeln('| Famille | Cadre | Cartouche | Exemple de contenu réel |')
    ..writeln('| --- | --- | --- | --- |')
    ..writeln(
      '| Championnat | #1 Fil continu | #7 Biseauté | JOURNÉE 5, PLAY-OFFS, JOURNÉE FINALE |',
    )
    ..writeln(
      '| Championnat féminin | #2 Cadre intérieur | #6 Onglet affleurant | JOURNÉE 5 |',
    )
    ..writeln(
      '| Coupe nationale | #4 Rails ouverts | #8 Capsule | 32es DE FINALE, QUART DE FINALE |',
    )
    ..writeln('| Supercoupe | #5 Pont central | #9 Double cartouche | FINALE |')
    ..writeln(
      '| Europe des clubs | #12 Cadre galerie | #12 Capsule galerie | NUIT EUROPÉENNE, HUITIÈME DE FINALE |',
    )
    ..writeln(
      '| Qualifications internationales | #11 Cadre segmenté | Passeport | QUALIFICATIONS |',
    )
    ..writeln(
      '| Sélections internationales | #3 Coins verrouillés | #7 Biseauté | PHASE DE GROUPES, DEMI-FINALE |',
    )
    ..writeln()
    ..writeln('## Registre approuvé à valider')
    ..writeln();

  const order = <String>[
    'Championnat',
    'Championnat féminin',
    'Coupe nationale',
    'Supercoupe',
    'Europe des clubs',
    'Qualifications internationales',
    'Sélections internationales',
  ];
  for (final family in order) {
    final group = grouped[family];
    if (group == null) continue;
    buffer
      ..writeln('### $family')
      ..writeln()
      ..writeln('| ID API | Compétition | Couleur | Cadre | Cartouche |')
      ..writeln('| ---: | --- | --- | --- | --- |');
    for (final entry in group) {
      buffer.writeln(
        '| ${entry.competition.id} | ${entry.competition.name} | `${entry.color}` | ${entry.frame} | ${entry.cartouche} |',
      );
    }
    buffer.writeln();
  }
  return buffer.toString();
}

String _toCsv(List<_Identity> entries) {
  String quote(String value) => '"${value.replaceAll('"', '""')}"';
  final buffer = StringBuffer(
    'api_league_id,competition,country,type,family,brand_color,frame_template,cartouche_template,example_label\n',
  );
  for (final entry in entries) {
    final item = entry.competition;
    buffer.writeln(
      [
        item.id,
        item.name,
        item.country,
        item.type,
        entry.family,
        entry.color,
        entry.frame,
        entry.cartouche,
        entry.label,
      ].map((value) => quote(value.toString())).join(','),
    );
  }
  return buffer.toString();
}

String _toHtml(List<_Identity> entries) {
  final samples = <int>[39, 66, 2, 3, 531, 1, 32, 4, 64, 525, 8]
      .map((id) => entries.firstWhere((entry) => entry.competition.id == id))
      .toList(growable: false);
  final sampleCards = samples.map(_sampleCard).join();
  final registryRows = entries
      .map(
        (entry) => '''
    <tr><td>${entry.competition.id}</td><td><span class="dot" style="background:${entry.color}"></span>${_escape(entry.competition.name)}</td><td>${_escape(entry.family)}</td><td><code>${entry.color}</code></td><td>${_escape(entry.frame)}</td><td>${_escape(entry.cartouche)}</td></tr>''',
      )
      .join();
  return '''<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Charte d’identité des compétitions</title>
<style>
:root { color-scheme: dark; --ink:#f3f7fb; --muted:#a7b3c0; --panel:#121c25; --page:#071018; --line:#2b3c4b; }
*{box-sizing:border-box} body{margin:0;background:radial-gradient(circle at 5% 0%,#11293c 0,transparent 26rem),var(--page);color:var(--ink);font-family:Inter,ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
main{max-width:1280px;margin:auto;padding:48px 28px 72px}.eyebrow{color:#30e5d2;font-size:12px;font-weight:850;letter-spacing:.1em;text-transform:uppercase}.hero{display:flex;justify-content:space-between;gap:24px;align-items:end;border-bottom:1px solid var(--line);padding-bottom:28px}.hero h1{font-size:42px;line-height:1.02;margin:8px 0 12px;letter-spacing:-.04em}.hero p{margin:0;max-width:660px;color:var(--muted);font-size:17px;line-height:1.5}.stamp{border:1px solid #2fe3d0;border-radius:14px;padding:12px 16px;color:#66fff1;font-size:13px;font-weight:800;text-align:center;white-space:nowrap}.section-title{margin:44px 0 8px;font-size:22px}.section-copy{margin:0 0 22px;color:var(--muted)}.showcase{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px;max-width:900px}.match{--accent:#2fe3d0;position:relative;overflow:hidden;min-height:166px;border:1px solid color-mix(in srgb,var(--accent) 52%,#344452);border-radius:18px;background:#111b24}.match::after{content:"";position:absolute;inset:7px;border-radius:12px;pointer-events:none;opacity:.72}.banner{height:47px;background:linear-gradient(100deg,color-mix(in srgb,var(--accent) 73%,#0c1720),color-mix(in srgb,var(--accent) 32%,#0c1720));display:flex;align-items:center;padding:0 13px;gap:9px;border-bottom:1px solid color-mix(in srgb,var(--accent) 55%,#27404a)}.mark{width:25px;height:25px;border:2px solid #f8fbff;background:#111923;border-radius:8px;display:grid;place-items:center;font-size:9px;font-weight:1000;color:var(--accent);box-shadow:0 0 0 2px color-mix(in srgb,var(--accent) 25%,transparent)}.comp{font-size:13px;font-weight:850;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.time{margin-left:auto;color:#d9fdfa;font-size:12px;font-weight:750}.body{position:relative;padding:46px 15px 14px;z-index:2}.teams{display:flex;align-items:center;justify-content:space-between;font-weight:780;font-size:15px}.teams span:nth-child(2){color:var(--muted);font-size:12px}.reading{margin-top:8px;display:flex;align-items:center;gap:7px;color:#e5ebf0;font-size:12px}.reading i{width:7px;height:7px;border-radius:50%;background:var(--accent);display:inline-block;box-shadow:0 0 10px var(--accent)}.chip{position:absolute;right:12px;top:56px;z-index:3;border:1px solid color-mix(in srgb,var(--accent) 75%,#fff);background:#101a23;color:#f4ffff;font-size:9px;letter-spacing:.06em;font-weight:900;padding:5px 8px;text-transform:uppercase;clip-path:polygon(8px 0,100% 0,100% calc(100% - 6px),calc(100% - 8px) 100%,0 100%,0 7px)}.league::after{border:1px solid color-mix(in srgb,var(--accent) 20%,transparent)}.cup{border-color:color-mix(in srgb,var(--accent) 76%,#fff)}.cup::before{content:"";position:absolute;left:13px;right:13px;top:52px;bottom:10px;border-left:2px solid var(--accent);border-right:2px solid var(--accent);opacity:.8}.cup::after{border-top:1px solid var(--accent);border-bottom:1px solid var(--accent);border-radius:9px;inset:58px 21px 10px}.super::after{border:1px solid var(--accent);outline:1px solid color-mix(in srgb,var(--accent) 24%,transparent);outline-offset:-5px;border-radius:14px}.europe{border-width:2px}.europe::after{border:1px solid var(--accent);outline:1px solid color-mix(in srgb,var(--accent) 40%,#fff);outline-offset:-5px;border-radius:13px}.europe .banner{background:linear-gradient(100deg,#0d1728,color-mix(in srgb,var(--accent) 50%,#101828))}.national::after{border:1px solid color-mix(in srgb,var(--accent) 66%,#fff);border-radius:16px;clip-path:polygon(0 16px,16px 0,calc(100% - 16px) 0,100% 16px,100% calc(100% - 16px),calc(100% - 16px) 100%,16px 100%,0 calc(100% - 16px))}.qualif::after{border:1px dashed color-mix(in srgb,var(--accent) 75%,#fff);border-radius:11px}.women::after{border:1px solid color-mix(in srgb,var(--accent) 42%,transparent);border-radius:16px}.legend{display:flex;gap:10px;flex-wrap:wrap;margin:18px 0 35px}.legend span{border:1px solid var(--line);padding:7px 10px;border-radius:999px;color:var(--muted);font-size:12px}.legend b{color:var(--ink)}.registry{overflow:auto;border:1px solid var(--line);border-radius:16px;background:#0d161e}table{border-collapse:collapse;width:100%;font-size:13px}th{text-align:left;color:#8fa1b0;font-size:11px;letter-spacing:.04em;text-transform:uppercase;background:#121d27}td,th{padding:12px;border-bottom:1px solid #21303d;white-space:nowrap}tr:last-child td{border:0}.dot{display:inline-block;width:10px;height:10px;border-radius:50%;margin-right:8px;box-shadow:0 0 0 2px #0b1219,0 0 0 3px currentColor}code{color:#9ff8ef;font:inherit;font-size:12px}@media(max-width:720px){main{padding:28px 16px 48px}.hero{display:block}.hero h1{font-size:34px}.stamp{display:inline-block;margin-top:18px}.showcase{grid-template-columns:1fr}.section-title{margin-top:34px}}
</style><style>
/* Each family changes the outer silhouette, not merely its colour. */
.reference-frame{margin:22px 0 38px;padding:12px;border:1px solid var(--line);border-radius:18px;background:#0b141c}.reference-frame img{display:block;max-width:100%;height:auto;border-radius:11px}.reference-frame figcaption{padding:12px 4px 0;color:var(--muted);font-size:13px}.reference-frame strong{color:var(--ink)}
.cup{border-color:transparent;border-radius:0}.cup::before{left:0;right:0;top:0;bottom:0;border-left:2px solid var(--accent);border-right:2px solid var(--accent);opacity:1}.cup::after{inset:0 14px;border-radius:0;border-top:2px solid var(--accent);border-bottom:2px solid var(--accent)}
.super{border-color:transparent}.super::before{content:"";position:absolute;z-index:4;top:-1px;left:50%;width:136px;height:17px;transform:translateX(-50%);background:#111b24;border:2px solid var(--accent);border-bottom:0;border-radius:0 0 8px 8px}.super::after{inset:0;border:2px solid var(--accent);outline:0;border-radius:18px}
.national{border-color:transparent}.national::after{inset:0;border:3px solid var(--accent);border-radius:18px;clip-path:polygon(0 20px,20px 0,calc(100% - 20px) 0,100% 20px,100% calc(100% - 20px),calc(100% - 20px) 100%,20px 100%,0 calc(100% - 20px))}.qualif{border-color:transparent}.qualif::after{inset:0;border:2px dashed var(--accent);border-radius:18px}.women{border-color:var(--accent)}.women::after{inset:7px;border:1px solid var(--accent);opacity:.7}.europe .chip{clip-path:polygon(0 0,100% 0,100% 100%,18px 100%,0 calc(100% - 10px))}
</style></head><body><main>
<header class="hero"><div><div class="eyebrow">Vector · identité de compétition</div><h1>Une couleur exclusive.<br>Un format lisible.</h1><p>La couleur identifie chaque épreuve. Le cadre et la cartouche racontent le type de match, sans alourdir la liste mobile.</p></div><div class="stamp">74 COMPÉTITIONS<br>À VALIDER</div></header>
<h2 class="section-title">Canvas contractuel</h2><p class="section-copy">Les 12 silhouettes ci-dessous sont la référence exacte des cadres et cartouches. Les identifiants sont repris dans le registre.</p>
<figure class="reference-frame"><img src="competition-identity-canvas-reference.png" alt="Atlas de référence des cadres et cartouches"><figcaption><strong>Source de vérité.</strong> Les cartes de la planche suivante utilisent ces silhouettes, avec les couleurs propriétaires des compétitions.</figcaption></figure>
<h2 class="section-title">Planches de validation</h2><p class="section-copy">Les proportions restent compactes ; les silhouettes reproduisent le canvas de référence au lieu de l’interpréter.</p>
<figure class="reference-frame"><img src="competition-identity-preview.svg" alt="Planches de cartes de compétition"><figcaption><strong>Application de la charte.</strong> Le bandeau porte la couleur de la compétition, tandis que le cadre et la cartouche reprennent une silhouette référencée.</figcaption></figure>
<div class="legend"><span><b>Fil continu</b> · championnat</span><span><b>Cadre intérieur</b> · championnat féminin</span><span><b>Rails ouverts</b> · coupe nationale</span><span><b>Pont central</b> · supercoupe</span><span><b>Cadre galerie</b> · Europe des clubs</span><span><b>Coins verrouillés</b> · sélections</span><span><b>Cadre segmenté</b> · qualifications</span></div>
<h2 class="section-title">Registre complet</h2><p class="section-copy">Ce registre est la future source de vérité : l’ID API décide de la couleur, tandis que la famille décide du cadre et de la cartouche.</p>
<div class="registry"><table><thead><tr><th>ID</th><th>Compétition</th><th>Famille</th><th>Couleur</th><th>Cadre</th><th>Cartouche</th></tr></thead><tbody>$registryRows</tbody></table></div>
</main></body></html>''';
}

String _sampleCard(_Identity entry) {
  final cssClass = switch (entry.family) {
    'Championnat' => 'league',
    'Championnat féminin' => 'women',
    'Coupe nationale' => 'cup',
    'Supercoupe' => 'super',
    'Europe des clubs' => 'europe',
    'Qualifications internationales' => 'qualif',
    'Sélections internationales' => 'national',
    _ => 'league',
  };
  final initials = entry.competition.name
      .split(RegExp(r'\\s+'))
      .where((word) => word.isNotEmpty)
      .take(2)
      .map((word) => word[0])
      .join();
  return '''<article class="match $cssClass" style="--accent:${entry.color}">
  <div class="banner"><div class="mark">$initials</div><div class="comp">${_escape(entry.competition.name)}</div><div class="time">20:45</div></div>
  <div class="chip">${entry.label}</div><div class="body"><div class="teams"><span>Équipe domicile</span><span>—</span><span>Équipe extérieure</span></div><div class="reading"><i></i> 4 lectures convergent · ${entry.frame}</div></div>
</article>''';
}

String _toSvg(List<_Identity> entries) {
  final samples = <int>[39, 66, 2, 3, 531, 1, 32, 4, 64, 525, 8]
      .map((id) => entries.firstWhere((entry) => entry.competition.id == id))
      .toList(growable: false);
  final cards = <String>[];
  for (var index = 0; index < samples.length; index++) {
    cards.add(
      _svgCard(
        samples[index],
        48 + (index % 2) * 630,
        205 + (index ~/ 2) * 174,
      ),
    );
  }
  return '''<svg xmlns="http://www.w3.org/2000/svg" width="1308" height="1275" viewBox="0 0 1308 1275">
<defs><linearGradient id="page" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#102537"/><stop offset=".45" stop-color="#071018"/><stop offset="1" stop-color="#071018"/></linearGradient></defs>
<rect width="1308" height="1275" fill="url(#page)"/>
<text x="48" y="58" fill="#31e4d2" font-family="Arial, sans-serif" font-size="15" font-weight="700" letter-spacing="2">VECTOR · IDENTITÉ DE COMPÉTITION</text>
<text x="48" y="111" fill="#F4F8FC" font-family="Arial, sans-serif" font-size="44" font-weight="800">Une couleur exclusive. Un format lisible.</text>
<text x="48" y="148" fill="#AAB8C7" font-family="Arial, sans-serif" font-size="18">Bandeau propriétaire · cadre par format sportif · cartouche porteuse de sens</text>
<rect x="1086" y="56" width="174" height="67" rx="14" fill="#101E29" stroke="#31e4d2"/><text x="1173" y="84" text-anchor="middle" fill="#70FFF2" font-family="Arial, sans-serif" font-size="13" font-weight="700">74 COMPÉTITIONS</text><text x="1173" y="105" text-anchor="middle" fill="#70FFF2" font-family="Arial, sans-serif" font-size="13" font-weight="700">À VALIDER</text>
<text x="48" y="188" fill="#F4F8FC" font-family="Arial, sans-serif" font-size="22" font-weight="700">Planches de validation</text>
${cards.join()}
</svg>''';
}

String _svgCard(_Identity entry, int x, int y) {
  final name = _escapeXml(entry.competition.name);
  final chip = _escapeXml(entry.label);
  final initials = entry.competition.name
      .split(RegExp(r'\\s+'))
      .where((word) => word.isNotEmpty)
      .take(2)
      .map((word) => word[0])
      .join();
  final frame = switch (entry.family) {
    'Coupe nationale' =>
      '<rect width="582" height="148" rx="18" fill="#111B24"/><path d="M24 0H211M371 0H558Q582 0 582 24V124Q582 148 558 148H371M211 148H24Q0 148 0 124V24Q0 0 24 0" fill="none" stroke="${entry.color}" stroke-width="2"/>',
    'Supercoupe' =>
      '<rect width="582" height="148" rx="18" fill="#111B24"/><path d="M18 0H218M364 0H564Q582 0 582 18V130Q582 148 564 148H18Q0 148 0 130V18Q0 0 18 0" fill="none" stroke="${entry.color}" stroke-width="2"/><path d="M218 0V-7H364V0" fill="#111B24" stroke="${entry.color}" stroke-width="2"/>',
    'Europe des clubs' =>
      '<rect width="582" height="148" rx="18" fill="#111B24" stroke="${entry.color}" stroke-width="2"/><rect x="7" y="7" width="568" height="134" rx="13" fill="none" stroke="${entry.color}" opacity=".85"/><rect x="12" y="12" width="558" height="124" rx="10" fill="none" stroke="${entry.color}" opacity=".3"/>',
    'Sélections internationales' =>
      '<rect width="582" height="148" rx="18" fill="#111B24"/><path d="M22 0H95M487 0H560Q582 0 582 22V45M582 103V126Q582 148 560 148H487M95 148H22Q0 148 0 126V103M0 45V22Q0 0 22 0" fill="none" stroke="${entry.color}" stroke-width="3"/>',
    'Qualifications internationales' =>
      '<rect width="582" height="148" rx="18" fill="#111B24"/><rect x="2" y="2" width="578" height="144" rx="16" fill="none" stroke="${entry.color}" stroke-width="2" stroke-dasharray="10 7"/>',
    'Championnat féminin' =>
      '<rect width="582" height="148" rx="18" fill="#111B24" stroke="${entry.color}"/><rect x="7" y="7" width="568" height="134" rx="13" fill="none" stroke="${entry.color}" opacity=".6"/>',
    _ =>
      '<rect width="582" height="148" rx="18" fill="#111B24" stroke="${entry.color}"/>',
  };
  return '''<g transform="translate($x $y)">
${frame}
<path d="M18 0H564Q582 0 582 18V46H0V18Q0 0 18 0" fill="${entry.color}" opacity=".72"/><line x1="0" y1="46" x2="582" y2="46" stroke="${entry.color}" opacity=".85"/>
<rect x="14" y="11" width="26" height="26" rx="8" fill="#0D1720" stroke="#F7FAFF" stroke-width="1.5"/><text x="27" y="29" text-anchor="middle" fill="#F7FAFF" font-family="Arial, sans-serif" font-size="9" font-weight="700">$initials</text><text x="51" y="30" fill="#F7FAFF" font-family="Arial, sans-serif" font-size="14" font-weight="700">$name</text><text x="551" y="30" text-anchor="end" fill="#D9FCF8" font-family="Arial, sans-serif" font-size="13" font-weight="700">20:45</text>
<path d="M437 56H566V78L558 86H429V64Z" fill="#101A23" stroke="${entry.color}"/><text x="497" y="75" text-anchor="middle" fill="#F7FAFF" font-family="Arial, sans-serif" font-size="9" font-weight="700">$chip</text><text x="18" y="109" fill="#F3F7FB" font-family="Arial, sans-serif" font-size="16" font-weight="700">Équipe domicile</text><text x="291" y="109" text-anchor="middle" fill="#A9B7C5" font-family="Arial, sans-serif" font-size="13">—</text><text x="564" y="109" text-anchor="end" fill="#F3F7FB" font-family="Arial, sans-serif" font-size="16" font-weight="700">Équipe extérieure</text><circle cx="21" cy="132" r="4" fill="${entry.color}"/><text x="33" y="137" fill="#DDE7EF" font-family="Arial, sans-serif" font-size="12">4 lectures convergent · ${entry.frame}</text></g>''';
}

String _escape(String input) => input
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _escapeXml(String input) =>
    _escape(input).replaceAll('"', '&quot;').replaceAll("'", '&apos;');

final class _Competition {
  const _Competition({
    required this.id,
    required this.name,
    required this.country,
    required this.type,
    required this.season,
  });
  final int id;
  final String name;
  final String country;
  final String type;
  final String season;
}

final class _Identity {
  const _Identity({
    required this.competition,
    required this.color,
    required this.family,
    required this.frame,
    required this.cartouche,
    required this.label,
  });
  final _Competition competition;
  final String color;
  final String family;
  final String frame;
  final String cartouche;
  final String label;
}
