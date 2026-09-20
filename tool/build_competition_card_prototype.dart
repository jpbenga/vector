import 'dart:io';

/// Generates a production-scale visual prototype of a compact championship
/// match card. It is isolated design work and does not change Flutter code.
void main() {
  const htmlOutput = 'docs/competition-card-prototype.html';
  const svgOutput = 'docs/competition-card-prototype.svg';
  const markdownOutput = 'docs/competition-card-prototype.md';
  File(htmlOutput).writeAsStringSync(_html());
  File(svgOutput).writeAsStringSync(_svg());
  File(markdownOutput).writeAsStringSync(_markdown());
  stdout.writeln('HTML=$htmlOutput');
  stdout.writeln('SVG=$svgOutput');
  stdout.writeln('MARKDOWN=$markdownOutput');
}

String _markdown() => '''# Prototype réel — carte de championnat

Prototype à l’échelle mobile de la carte de liste. Il rassemble les décisions validées :

- bandeau horizontal avec couleur propriétaire de Championship `#3C77A8` ;
- motif topographique discret dans le seul bandeau ;
- double bordure lumineuse, comme la carte « Championnat » de la planche de référence ;
- aucun cartouche forcé sur une rencontre de championnat standard ;
- logo de compétition et logos d’équipes via les mêmes URLs API-Football que l’application ;
- lectures, résumé et action conservés dans une hauteur de carte mobile réaliste.

![Prototype de carte Championship](competition-card-prototype.png)

Référence visuelle contractuelle : `competition-card-language-reference.png`.

Le prototype HTML charge les logos depuis `media.api-sports.io`, comme le composant Flutter existant. Les initiales restent visibles si un logo ne peut pas être chargé dans un navigateur local.
''';

String _html() => _doubleBorderHtml().replaceFirst('</style></head>', '''<style>
/* Matière froide : facette brillante, grain lumineux et microtrame technique. */
.banner{background:radial-gradient(ellipse at 64% -24%,rgba(203,246,255,.88),transparent 44%),linear-gradient(105deg,#052551 0%,#075ca5 42%,#042c62 100%)}.texture{display:none}.banner::before{content:"";position:absolute;inset:0;background:linear-gradient(120deg,transparent 42%,rgba(170,229,255,.38) 43%,rgba(225,250,255,.09) 54%,transparent 55%),radial-gradient(circle at 86% 39%,rgba(221,250,255,.24) 0 1px,transparent 1.6px);background-size:auto,8px 8px;opacity:.95}.banner::after{content:"";position:absolute;inset:0;background:linear-gradient(90deg,transparent 68%,rgba(191,240,255,.12) 68%,transparent 100%);mix-blend-mode:screen}.banner-row{z-index:2}.body{background-image:radial-gradient(circle at 1px 1px,rgba(117,197,238,.12) 1px,transparent 1.25px);background-size:8px 8px}.body>*{position:relative}
</style></head>''');

String _svg() => _doubleBorderSvg()
    .replaceFirst(
      '<clipPath id="banner">',
      '<radialGradient id="ice" cx="64%" cy="-24%" r="90%"><stop stop-color="#CBEFFF" stop-opacity=".9"/><stop offset=".38" stop-color="#0A6CB9"/><stop offset="1" stop-color="#042959"/></radialGradient><pattern id="micro" width="8" height="8" patternUnits="userSpaceOnUse"><circle cx="1" cy="1" r=".8" fill="#D5F6FF" opacity=".48"/></pattern><pattern id="bodyMicro" width="8" height="8" patternUnits="userSpaceOnUse"><circle cx="1" cy="1" r=".7" fill="#71C7F0" opacity=".16"/></pattern><clipPath id="banner">',
    )
    .replaceFirst(
      'fill="#07598D"/>',
      'fill="url(#ice)"/><path d="M235 0H282L244 48H196Z" fill="#C6F1FF" opacity=".28"/><rect x="302" y="0" width="104" height="48" fill="url(#micro)" opacity=".7"/>',
    )
    .replaceFirst('opacity=".26"', 'opacity="0"')
    .replaceFirst(
      '</g><path d="M16 0H390',
      '</g><rect x="0" y="48" width="406" height="166" fill="url(#bodyMicro)"/><path d="M16 0H390',
    );

String _doubleBorderHtml() => '''<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Prototype · Carte Championship</title>
<style>
:root{--bg:#071018;--panel:#07131c;--ink:#f5f9fc;--muted:#9eb0c0;--blue:#00a9f4;--blue-dim:#12638e;--teal:#39ead5}*{box-sizing:border-box}body{margin:0;min-height:100vh;background:radial-gradient(circle at 50% 0,#143449,transparent 31rem),var(--bg);color:var(--ink);font-family:Inter,system-ui,sans-serif}.phone{width:min(100%,430px);min-height:820px;margin:auto;padding:28px 14px;background:linear-gradient(180deg,rgba(6,16,24,.15),#071018 42%)}.top{display:flex;justify-content:space-between;align-items:center}.brand{font-size:19px;font-weight:950;color:var(--teal)}.user{width:34px;height:34px;border:1px solid var(--teal);border-radius:50%;display:grid;place-items:center;font-size:11px;font-weight:800}.dates{display:flex;justify-content:space-between;margin:25px 5px 27px;color:#95a7b6;font-size:10px;font-weight:800;text-align:center}.dates b{display:block;margin-top:3px;font-size:14px}.dates .active{padding:8px 10px;margin-top:-8px;border-radius:19px;background:#10373c;color:var(--teal)}.section{display:flex;justify-content:space-between;margin:0 4px 13px}.section strong{font-size:16px}.section span{font-size:11px;color:var(--teal);font-weight:850}.card{position:relative;overflow:hidden;border:2px solid var(--blue);border-radius:17px;background:var(--panel);box-shadow:0 0 20px rgba(0,169,244,.12),0 18px 28px rgba(0,0,0,.25)}.card::before{content:"";position:absolute;z-index:4;inset:4px;border:1px solid #4ec8fb;border-radius:12px;pointer-events:none;opacity:.9}.banner{height:48px;position:relative;overflow:hidden;border-bottom:1px solid var(--blue);background:linear-gradient(102deg,#083a68,#07598d 52%,#062f52)}.texture{position:absolute;inset:0;width:100%;height:100%;opacity:.24}.banner-row{position:relative;height:100%;display:flex;align-items:center;padding:0 12px;gap:8px}.league-logo{width:25px;height:25px;border-radius:6px;object-fit:contain;background:#f5f8fb;padding:2px}.comp{font-size:13px;font-weight:900}.comp small{color:#b8dbec;margin:0 5px}.reads{margin-left:auto;display:flex;align-items:center;gap:6px;color:#e8fffb;font-size:11px;font-weight:850}.bars{color:var(--teal);font-size:18px;letter-spacing:-5px;margin-right:3px}.body{position:relative;padding:13px 13px 12px}.fixture{display:grid;grid-template-columns:1fr 37px;gap:8px;align-items:center}.teams{display:grid;gap:7px}.team{display:flex;align-items:center;gap:9px}.team-logo{width:25px;height:25px;border-radius:50%;object-fit:contain;background:#f6f8fc;padding:2px}.team b{font-size:15px}.open{width:34px;height:34px;border:0;color:#bdeaff;font-size:31px;line-height:1;display:grid;place-items:center}.signals{display:flex;gap:6px;flex-wrap:wrap;margin-top:12px}.signal{padding:5px 9px;border-radius:999px;font-size:10px;font-weight:850;border:1px solid #15d8bf;background:#053b38;color:#25ebd7}.negative{border-color:#ff4456;background:#3a1019;color:#ff6e79}.summary{margin:10px 0 0;color:#c6d7e3;font-size:12px;font-weight:650}.summary b{color:white}.note{margin:18px 7px;color:#93a8b9;font-size:11px;line-height:1.45}.note b{color:var(--teal)}@media(min-width:720px){.phone{margin-top:30px;border:1px solid #203341;border-radius:28px;box-shadow:0 24px 60px rgba(0,0,0,.42)}}
</style></head><body><main class="phone"><header class="top"><b class="brand">LS</b><span class="user">JB</span></header><nav class="dates"><span>JE<b>18.09</b></span><span class="active">AUJ<b>19.09</b></span><span>SA<b>20.09</b></span><span>DI<b>21.09</b></span><span>LU<b>22.09</b></span></nav><div class="section"><strong>À suivre aujourd’hui</strong><span>1 CARTE PROTOTYPE</span></div><article class="card"><header class="banner"><svg class="texture" viewBox="0 0 400 48" preserveAspectRatio="none"><g fill="none" stroke="#8bdcff" stroke-width="1.1"><path d="M-28 42C45-5 98 61 168 20S283-4 352 30 420 65 444 8"/><path d="M-18 30C39-15 102 48 170 12S286-18 359 20 426 56 448-4"/><path d="M-6 54C54 11 117 74 184 40S292 6 350 45 410 76 448 31"/></g></svg><div class="banner-row"><img class="league-logo" src="https://media.api-sports.io/football/leagues/40.png" alt="Championship"><span class="comp">Championship<small>•</small>13:30</span><span class="reads"><i class="bars">▮▮▮</i>15 lectures</span></div></header><div class="body"><div class="fixture"><div class="teams"><div class="team"><img class="team-logo" src="https://media.api-sports.io/football/teams/81.png" alt="Millwall"><b>Millwall</b></div><div class="team"><img class="team-logo" src="https://media.api-sports.io/football/teams/48.png" alt="West Ham"><b>West Ham</b></div></div><span class="open">›</span></div><div class="signals"><span class="signal negative">⌁ Dynamique négative</span><span class="signal">↗ Équipe en forme</span></div><p class="summary"><b>Millwall reste sur deux défaites consécutives.</b></p></div></article><p class="note"><b>Référence Championnat.</b> Double bordure lumineuse, bandeau texturé discret, aucun cartouche imposé pour un match de journée.</p></main></body></html>''';

String _doubleBorderSvg() =>
    '''<svg xmlns="http://www.w3.org/2000/svg" width="430" height="660" viewBox="0 0 430 660"><defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#143449"/><stop offset=".45" stop-color="#071018"/></linearGradient><clipPath id="banner"><path d="M16 0H390Q406 0 406 16V48H0V16Q0 0 16 0"/></clipPath></defs><rect width="430" height="660" fill="url(#bg)"/><text x="22" y="39" fill="#39EAD5" font-family="Arial" font-size="20" font-weight="800">LS</text><circle cx="397" cy="29" r="17" fill="none" stroke="#39EAD5"/><text x="397" y="33" text-anchor="middle" fill="#F5F9FC" font-family="Arial" font-size="11" font-weight="700">JB</text><text x="18" y="133" fill="#F5F9FC" font-family="Arial" font-size="16" font-weight="700">À suivre aujourd’hui</text><text x="412" y="133" text-anchor="end" fill="#39EAD5" font-family="Arial" font-size="11" font-weight="700">1 CARTE PROTOTYPE</text><g transform="translate(12 150)"><rect width="406" height="214" rx="17" fill="#07131C" stroke="#00A9F4" stroke-width="2"/><rect x="5" y="5" width="396" height="204" rx="12" fill="none" stroke="#4EC8FB" opacity=".9"/><g clip-path="url(#banner)"><rect width="406" height="48" fill="#07598D"/><g fill="none" stroke="#8BDCFF" stroke-width="1.1" opacity=".26"><path d="M-28 42C45-5 98 61 168 20S283-4 352 30 420 65 444 8"/><path d="M-18 30C39-15 102 48 170 12S286-18 359 20 426 56 448-4"/><path d="M-6 54C54 11 117 74 184 40S292 6 350 45 410 76 448 31"/></g></g><path d="M16 0H390Q406 0 406 16V48H0V16Q0 0 16 0" fill="none" stroke="#00A9F4"/><rect x="13" y="11" width="25" height="25" rx="6" fill="#F5F8FB"/><text x="26" y="28" text-anchor="middle" fill="#07598D" font-family="Arial" font-size="8" font-weight="800">CH</text><text x="50" y="29" fill="#F5F9FC" font-family="Arial" font-size="13" font-weight="800">Championship</text><text x="142" y="29" fill="#B8DBEC" font-family="Arial" font-size="13">•</text><text x="154" y="29" fill="#F5F9FC" font-family="Arial" font-size="13">13:30</text><text x="392" y="29" text-anchor="end" fill="#E8FFFB" font-family="Arial" font-size="11" font-weight="800">▮▮▮ 15 lectures</text><line x1="0" y1="48" x2="406" y2="48" stroke="#00A9F4"/><circle cx="27" cy="77" r="13" fill="#EDF2F7"/><text x="27" y="81" text-anchor="middle" fill="#34536A" font-family="Arial" font-size="8" font-weight="800">MFC</text><text x="50" y="82" fill="#F5F9FC" font-family="Arial" font-size="16" font-weight="800">Millwall</text><circle cx="27" cy="109" r="13" fill="#F3EFF0"/><text x="27" y="113" text-anchor="middle" fill="#7D1730" font-family="Arial" font-size="8" font-weight="800">WH</text><text x="50" y="114" fill="#F5F9FC" font-family="Arial" font-size="16" font-weight="800">West Ham</text><text x="374" y="101" text-anchor="middle" fill="#BDEAFF" font-family="Arial" font-size="30">›</text><rect x="14" y="134" width="138" height="27" rx="14" fill="#3A1019" stroke="#FF4456"/><text x="83" y="151" text-anchor="middle" fill="#FF6E79" font-family="Arial" font-size="10" font-weight="800">⌁ DYNAMIQUE NÉGATIVE</text><rect x="159" y="134" width="137" height="27" rx="14" fill="#053B38" stroke="#15D8BF"/><text x="227" y="151" text-anchor="middle" fill="#25EBD7" font-family="Arial" font-size="10" font-weight="800">↗ ÉQUIPE EN FORME</text><text x="14" y="186" fill="#C6D7E3" font-family="Arial" font-size="12" font-weight="600">Millwall reste sur deux défaites consécutives.</text></g><text x="22" y="389" fill="#93A8B9" font-family="Arial" font-size="11">DOUBLE BORDURE · BANDEAU TEXTURÉ · FORMAT CHAMPIONNAT</text></svg>''';
