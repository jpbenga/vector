import 'dart:io';

/// Produces a visual review board for competition-banner motifs.
/// It is design documentation only and does not modify Flutter runtime code.
void main() {
  const svgOutput = 'docs/banner-motif-exploration.svg';
  const htmlOutput = 'docs/banner-motif-exploration.html';
  const markdownOutput = 'docs/banner-motif-exploration.md';

  final cards = <_BannerVariant>[
    _BannerVariant(
      'A',
      'Courbes topographiques',
      '#7A3FAC',
      'Championnat · direction organique et premium',
      'topographic',
    ),
    _BannerVariant(
      'B',
      'Faisceaux diagonaux',
      '#2975D9',
      'Championnat · énergie et progression',
      'diagonal',
    ),
    _BannerVariant(
      'C',
      'Grille tactique',
      '#E87924',
      'Championnat · lecture plus technique',
      'tactical',
    ),
    _BannerVariant(
      'D',
      'Orbites européennes',
      '#071A4D',
      'Europe des clubs · nuit européenne',
      'orbital',
    ),
    _BannerVariant(
      'E',
      'Rayonnement de finale',
      '#C7A02C',
      'Coupe · rendez-vous à enjeu',
      'radiant',
    ),
    _BannerVariant(
      'F',
      'Trame drapeau',
      '#269A85',
      'Sélections · compétition internationale',
      'weave',
    ),
  ];

  File(svgOutput).writeAsStringSync(_toSvg(cards));
  File(htmlOutput).writeAsStringSync(_toHtml());
  File(markdownOutput).writeAsStringSync(_toMarkdown(cards));
  stdout.writeln('SVG=$svgOutput');
  stdout.writeln('HTML=$htmlOutput');
  stdout.writeln('MARKDOWN=$markdownOutput');
}

String _toMarkdown(List<_BannerVariant> cards) {
  final rows = cards
      .map(
        (card) =>
            '| ${card.code} | ${card.name} | `${card.color}` | ${card.useCase} |',
      )
      .join('\n');
  return '''# Exploration des motifs de bandeau

Le logo de la compétition, son nom et l’heure restent au premier plan. La texture est placée sous un voile sombre : elle enrichit le bandeau sans devenir une image de fond ni dégrader la lisibilité.

![Planches de bandeau](banner-motif-exploration.png)

| Variante | Motif | Couleur d’exemple | Usage de démonstration |
| --- | --- | --- | --- |
$rows

## Règles communes

- La couleur propriétaire vient du registre de compétition.
- Le motif est vectoriel, sans requête réseau ni asset spécifique à une rencontre.
- Son opacité est plafonnée afin que le logo et les informations restent lisibles.
- Le cadre et la cartouche conservent leur rôle propre ; le bandeau ne les remplace pas.
''';
}

String _toHtml() =>
    '''<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Exploration des bandeaux</title><style>body{margin:0;background:#071018;color:#f4f8fc;font-family:Inter,system-ui,sans-serif}main{max-width:1320px;margin:auto;padding:42px 24px 64px}h1{font-size:38px;margin:8px 0}.eyebrow{font-size:12px;letter-spacing:.12em;color:#31e4d2;font-weight:800}p{color:#aab8c7;max-width:760px;line-height:1.5}.board{margin-top:28px;padding:12px;border:1px solid #2b3c4b;border-radius:18px;background:#0b141c}.board img{display:block;width:100%;height:auto;border-radius:10px}</style></head><body><main><div class="eyebrow">VECTOR · EXPLORATION VISUELLE</div><h1>Motifs de bandeau</h1><p>Six directions pour faire vivre la couleur de la compétition sans concurrencer le logo ni les lectures du match.</p><div class="board"><img src="banner-motif-exploration.svg" alt="Six variantes de bandeaux de compétition"></div></main></body></html>''';

String _toSvg(List<_BannerVariant> variants) {
  final cards = <String>[];
  for (var index = 0; index < variants.length; index++) {
    cards.add(
      _card(variants[index], 48 + (index % 2) * 630, 220 + (index ~/ 2) * 190),
    );
  }
  return '''<svg xmlns="http://www.w3.org/2000/svg" width="1308" height="835" viewBox="0 0 1308 835">
<defs><linearGradient id="page" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#11293c"/><stop offset=".55" stop-color="#071018"/><stop offset="1" stop-color="#071018"/></linearGradient><clipPath id="banner"><path d="M18 0H564Q582 0 582 18V50H0V18Q0 0 18 0"/></clipPath></defs>
<rect width="1308" height="835" fill="url(#page)"/>
<text x="48" y="57" fill="#31E4D2" font-family="Arial, sans-serif" font-size="15" font-weight="700" letter-spacing="2">VECTOR · EXPLORATION VISUELLE</text>
<text x="48" y="110" fill="#F4F8FC" font-family="Arial, sans-serif" font-size="44" font-weight="800">Donner une matière au bandeau.</text>
<text x="48" y="146" fill="#AAB8C7" font-family="Arial, sans-serif" font-size="18">Le motif est un relief discret de la couleur propriétaire. Le logo et l’information restent dominants.</text>
<rect x="1056" y="58" width="204" height="62" rx="14" fill="#101E29" stroke="#31E4D2"/><text x="1158" y="85" text-anchor="middle" fill="#72FFF2" font-family="Arial, sans-serif" font-size="12" font-weight="700">6 DIRECTIONS</text><text x="1158" y="106" text-anchor="middle" fill="#72FFF2" font-family="Arial, sans-serif" font-size="12" font-weight="700">À COMPARER</text>
${cards.join()}
</svg>''';
}

String _card(_BannerVariant variant, int x, int y) {
  return '''<g transform="translate($x $y)">
<text x="0" y="-23" fill="#F4F8FC" font-family="Arial, sans-serif" font-size="16" font-weight="700">${variant.code}. ${variant.name}</text><text x="0" y="-3" fill="#AAB8C7" font-family="Arial, sans-serif" font-size="12">${variant.useCase}</text>
<rect width="582" height="150" rx="18" fill="#111B24" stroke="${variant.color}" opacity=".92"/>
<g clip-path="url(#banner)"><rect width="582" height="50" fill="${variant.color}"/>${_motif(variant)}</g>
<path d="M18 0H564Q582 0 582 18V50H0V18Q0 0 18 0" fill="none" stroke="${variant.color}"/><line x1="0" y1="50" x2="582" y2="50" stroke="${variant.color}" opacity=".8"/>
<rect x="14" y="12" width="27" height="27" rx="8" fill="#0B141C" stroke="#F8FBFF" stroke-width="1.5"/><text x="27" y="30" text-anchor="middle" fill="#F8FBFF" font-family="Arial, sans-serif" font-size="9" font-weight="700">L</text>
<text x="53" y="31" fill="#F8FBFF" font-family="Arial, sans-serif" font-size="15" font-weight="700">Compétition</text><text x="550" y="31" text-anchor="end" fill="#E5FFFC" font-family="Arial, sans-serif" font-size="13" font-weight="700">20:45</text>
<text x="18" y="84" fill="#F4F8FC" font-family="Arial, sans-serif" font-size="16" font-weight="700">Équipe domicile</text><text x="291" y="84" text-anchor="middle" fill="#AAB8C7" font-family="Arial, sans-serif" font-size="13">—</text><text x="564" y="84" text-anchor="end" fill="#F4F8FC" font-family="Arial, sans-serif" font-size="16" font-weight="700">Équipe extérieure</text>
<circle cx="21" cy="118" r="4" fill="${variant.color}"/><text x="33" y="123" fill="#DDE7EF" font-family="Arial, sans-serif" font-size="12">4 lectures convergent</text><text x="564" y="123" text-anchor="end" fill="#AAB8C7" font-family="Arial, sans-serif" font-size="12">motif ${variant.code}</text>
</g>''';
}

String _motif(_BannerVariant variant) => switch (variant.kind) {
  'topographic' =>
    '''<g fill="none" stroke="#FFFFFF" stroke-width="1.2" opacity=".20"><path d="M-30 43C65-6 117 74 217 25S356-2 454 37 587 68 644 10"/><path d="M-25 30C64-18 132 57 214 15S359-18 462 24 576 59 643-2"/><path d="M8 60C81 14 148 81 238 43S367 8 448 50 565 78 620 34"/></g>''',
  'diagonal' =>
    '''<g opacity=".19" fill="#FFFFFF"><path d="M-18 50L45 0H94L31 50Z"/><path d="M75 50L138 0H187L124 50Z"/><path d="M168 50L231 0H280L217 50Z"/><path d="M261 50L324 0H373L310 50Z"/><path d="M354 50L417 0H466L403 50Z"/><path d="M447 50L510 0H559L496 50Z"/></g>''',
  'tactical' =>
    '''<g stroke="#FFFFFF" stroke-width="1" opacity=".18" fill="none"><path d="M42 0V50M116 0V50M190 0V50M264 0V50M338 0V50M412 0V50M486 0V50M560 0V50"/><path d="M0 16H582M0 34H582"/><circle cx="291" cy="25" r="16"/></g>''',
  'orbital' =>
    '''<g fill="none" stroke="#BFD0FF" opacity=".26"><ellipse cx="392" cy="24" rx="156" ry="40"/><ellipse cx="392" cy="24" rx="92" ry="27" transform="rotate(-17 392 24)"/><circle cx="392" cy="24" r="4" fill="#BFD0FF"/><circle cx="522" cy="15" r="3" fill="#BFD0FF"/></g>''',
  'radiant' =>
    '''<g stroke="#FFF4C7" stroke-width="1.2" opacity=".26"><path d="M291 25L291 -12M291 25L345 -5M291 25L393 4M291 25L455 25M291 25L393 46M291 25L345 58M291 25L237 58M291 25L189 46M291 25L127 25M291 25L189 4M291 25L237 -5"/><circle cx="291" cy="25" r="12" fill="none"/></g>''',
  'weave' =>
    '''<g opacity=".20" stroke="#FFFFFF" stroke-width="4"><path d="M-25 7H607M-25 25H607M-25 43H607"/><path d="M34 -8V58M82 -8V58M130 -8V58M178 -8V58M226 -8V58M274 -8V58M322 -8V58M370 -8V58M418 -8V58M466 -8V58M514 -8V58M562 -8V58"/></g>''',
  _ => '',
};

final class _BannerVariant {
  const _BannerVariant(
    this.code,
    this.name,
    this.color,
    this.useCase,
    this.kind,
  );
  final String code;
  final String name;
  final String color;
  final String useCase;
  final String kind;
}
