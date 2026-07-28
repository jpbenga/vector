import React, { useState, useMemo } from "react";
import {
  ChevronUp,
  ChevronDown,
  GripVertical,
  Target,
  LayoutList,
  ChevronRight,
  Check,
  Plus,
  Sparkles,
  X,
  ArrowRight,
} from "lucide-react";

/* ---------------------------------------------------------------
   DESIGN TOKENS
   bg graphite-950 #0A0E13 / surface graphite-900 #12181F
   raised graphite-800 #1C242D / hairline #232C36
   text #E7ECEF / text-dim #8A96A3
   signal (confidence) teal #3FD8C4 / ember (ambition) #E39A3D
   display: Space Grotesk · body: Inter · data: IBM Plex Mono
----------------------------------------------------------------*/

const FONT_IMPORT = `
@import url('https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&family=Inter:wght@400;500;600&family=IBM+Plex+Mono:wght@500;600&display=swap');
`;

const ONBOARDING_QUESTIONS = [
  {
    id: "markets",
    n: "1",
    title: "Quels marchés jouez-vous le plus ?",
    sub: "Glissez ou utilisez les flèches pour classer par ordre d'importance",
    items: ["Double chance", "BTTS", "Victoire", "Plus de 2.5 buts", "Moins de 2.5 buts"],
  },
  {
    id: "competitions",
    n: "2",
    title: "Quelles compétitions suivez-vous ?",
    sub: "Classez du plus important au moins important",
    items: ["Premier League", "Ligue 1", "Liga", "Champions League", "Serie A"],
  },
  {
    id: "criteria",
    n: "3",
    title: "Quels critères influencent le plus votre décision ?",
    sub: "Classez vos critères de lecture d'un match",
    items: ["Forme récente", "Écart de niveau", "Cote", "Blessures", "Avantage domicile"],
  },
];

const MATCHES = [
  {
    id: "ars-eve",
    home: "Arsenal",
    away: "Everton",
    market: "Double Chance 1",
    cote: 1.42,
    compat: 94,
    args: [
      { t: "Everton voyage mal", ev: "4 défaites sur les 5 derniers déplacements", detail: "11 buts encaissés à l'extérieur sur cette série" },
      { t: "Arsenal intraitable à domicile", ev: "5 victoires sur 5 matchs", detail: "0 défaite à domicile depuis 14 matchs de championnat" },
      { t: "Écart de classement", ev: "2e contre 15e", detail: "16 points d'écart, +18 de différence de buts" },
      { t: "Dynamique offensive", ev: "Arsenal : 12 buts sur 5 matchs", detail: "Everton : 3 buts encaissés lors des 2 derniers déplacements" },
    ],
  },
  {
    id: "ben-bra",
    home: "Benfica",
    away: "Braga",
    market: "Victoire Benfica",
    cote: 1.85,
    compat: 91,
    args: [
      { t: "Braga fébrile en déplacement", ev: "1 victoire sur les 6 derniers extérieurs", detail: "Moyenne de 1.8 but encaissé par match à l'extérieur" },
      { t: "Série à domicile", ev: "Benfica invaincu depuis 9 matchs", detail: "7 victoires, 2 nuls sur la série" },
      { t: "Confrontations directes", ev: "3 victoires Benfica sur les 4 derniers duels", detail: "Seul le nul concédé l'était à Braga" },
    ],
  },
  {
    id: "lil-nan",
    home: "Lille",
    away: "Nantes",
    market: "Double chance 1",
    cote: 1.55,
    compat: 88,
    args: [
      { t: "Nantes en méforme", ev: "1 victoire lors des 6 derniers matchs", detail: "Défense la plus perméable des 10 derniers journées" },
      { t: "Lille solide", ev: "3 clean sheets sur 5 matchs", detail: "Meilleure défense à domicile de la période" },
    ],
  },
  {
    id: "psv-two",
    home: "PSV",
    away: "Twente",
    market: "Plus de 2.5 buts",
    cote: 1.68,
    compat: 83,
    args: [
      { t: "Confrontations offensives", ev: "Over 2.5 atteint lors des 4 derniers duels", detail: "Moyenne de 3.6 buts par match sur la série" },
      { t: "Deux attaques productives", ev: "PSV 2.4 buts/match, Twente 1.9 but/match", detail: "Sur les 6 dernières journées de championnat" },
    ],
  },
  {
    id: "nap-tor",
    home: "Napoli",
    away: "Torino",
    market: "Victoire Napoli",
    cote: 1.52,
    compat: 79,
    args: [
      { t: "Torino friable à l'extérieur", ev: "1 seul point pris hors de ses bases", detail: "Sur les 5 derniers déplacements en championnat" },
      { t: "Napoli en confiance", ev: "4 victoires sur les 5 derniers matchs", detail: "Toutes obtenues avec au moins 2 buts d'écart" },
    ],
  },
];

/* ---------------------------------------------------------------
   Instrument-style compatibility gauge (signature element)
----------------------------------------------------------------*/
function Gauge({ value, size = 56 }) {
  const stroke = 5;
  const r = (size - stroke) / 2;
  const cx = size / 2;
  const cy = size / 2;
  const startAngle = -215;
  const sweep = 250;
  const angle = startAngle + (sweep * value) / 100;

  const toXY = (deg) => {
    const rad = (deg * Math.PI) / 180;
    return [cx + r * Math.cos(rad), cy + r * Math.sin(rad)];
  };
  const arcPath = (a0, a1) => {
    const [x0, y0] = toXY(a0);
    const [x1, y1] = toXY(a1);
    const large = a1 - a0 > 180 ? 1 : 0;
    return `M ${x0} ${y0} A ${r} ${r} 0 ${large} 1 ${x1} ${y1}`;
  };
  const color = value >= 90 ? "#3FD8C4" : value >= 80 ? "#5FCBBE" : "#E39A3D";

  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      <path d={arcPath(startAngle, startAngle + sweep)} stroke="#232C36" strokeWidth={stroke} fill="none" strokeLinecap="round" />
      <path d={arcPath(startAngle, angle)} stroke={color} strokeWidth={stroke} fill="none" strokeLinecap="round" />
      <text x={cx} y={cy + 1} textAnchor="middle" dominantBaseline="middle" fill="#E7ECEF" style={{ font: "600 13px 'IBM Plex Mono', monospace" }}>
        {value}
      </text>
      <text x={cx} y={cy + 13} textAnchor="middle" dominantBaseline="middle" fill="#8A96A3" style={{ font: "500 6px 'Inter', sans-serif", letterSpacing: "0.05em" }}>
        %
      </text>
    </svg>
  );
}

/* ---------------------------------------------------------------
   Ranking / prioritisation list
----------------------------------------------------------------*/
function RankList({ items, onChange }) {
  const [dragIdx, setDragIdx] = useState(null);

  const move = (idx, dir) => {
    const next = [...items];
    const swap = idx + dir;
    if (swap < 0 || swap >= next.length) return;
    [next[idx], next[swap]] = [next[swap], next[idx]];
    onChange(next);
  };

  const handleDrop = (idx) => {
    if (dragIdx === null || dragIdx === idx) return;
    const next = [...items];
    const [moved] = next.splice(dragIdx, 1);
    next.splice(idx, 0, moved);
    onChange(next);
    setDragIdx(null);
  };

  return (
    <div style={{ position: "relative", paddingLeft: 18 }}>
      <div style={{ position: "absolute", left: 8, top: 14, bottom: 14, width: 1, background: "#232C36" }} />
      {items.map((item, idx) => (
        <div
          key={item}
          draggable
          onDragStart={() => setDragIdx(idx)}
          onDragOver={(e) => e.preventDefault()}
          onDrop={() => handleDrop(idx)}
          style={{
            position: "relative",
            display: "flex",
            alignItems: "center",
            gap: 10,
            background: "#1C242D",
            border: "1px solid #232C36",
            borderRadius: 10,
            padding: "10px 12px",
            marginBottom: 8,
            opacity: dragIdx === idx ? 0.4 : 1,
          }}
        >
          <div
            style={{
              position: "absolute",
              left: -18,
              width: 17,
              height: 17,
              borderRadius: "50%",
              background: idx === 0 ? "#3FD8C4" : "#12181F",
              border: `1px solid ${idx === 0 ? "#3FD8C4" : "#232C36"}`,
              color: idx === 0 ? "#0A0E13" : "#8A96A3",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              fontFamily: "'IBM Plex Mono', monospace",
              fontSize: 9,
              fontWeight: 600,
            }}
          >
            {idx + 1}
          </div>
          <GripVertical size={15} color="#4A5560" style={{ cursor: "grab", flexShrink: 0 }} />
          <span style={{ flex: 1, fontFamily: "'Inter', sans-serif", fontSize: 14, color: "#E7ECEF" }}>{item}</span>
          <div style={{ display: "flex", flexDirection: "column", gap: 1 }}>
            <button onClick={() => move(idx, -1)} disabled={idx === 0} style={btnGhost(idx === 0)}>
              <ChevronUp size={13} />
            </button>
            <button onClick={() => move(idx, 1)} disabled={idx === items.length - 1} style={btnGhost(idx === items.length - 1)}>
              <ChevronDown size={13} />
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}

const btnGhost = (disabled) => ({
  background: "transparent",
  border: "none",
  color: disabled ? "#2E3841" : "#8A96A3",
  cursor: disabled ? "default" : "pointer",
  padding: 0,
  lineHeight: 0,
});

/* ---------------------------------------------------------------
   Onboarding flow
----------------------------------------------------------------*/
function Onboarding({ onDone }) {
  const [qIdx, setQIdx] = useState(0);
  const [answers, setAnswers] = useState(() =>
    Object.fromEntries(ONBOARDING_QUESTIONS.map((q) => [q.id, q.items]))
  );
  const q = ONBOARDING_QUESTIONS[qIdx];
  const isLast = qIdx === ONBOARDING_QUESTIONS.length - 1;

  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
      <div style={{ padding: "28px 20px 18px" }}>
        <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, color: "#3FD8C4", letterSpacing: "0.08em" }}>
          COPILOT — MISE EN ROUTE
        </div>
        <h1 style={{ fontFamily: "'Space Grotesk', sans-serif", fontSize: 22, fontWeight: 700, color: "#E7ECEF", margin: "10px 0 4px" }}>
          Construisons votre profil de décision
        </h1>
        <p style={{ fontFamily: "'Inter', sans-serif", fontSize: 13, color: "#8A96A3", margin: 0, lineHeight: 1.5 }}>
          Pas un profil marketing. Une carte de votre façon de réfléchir.
        </p>
      </div>

      <div style={{ padding: "0 20px 8px", display: "flex", gap: 4 }}>
        {ONBOARDING_QUESTIONS.map((_, i) => (
          <div key={i} style={{ flex: 1, height: 3, borderRadius: 2, background: i <= qIdx ? "#3FD8C4" : "#232C36" }} />
        ))}
      </div>

      <div style={{ flex: 1, overflowY: "auto", padding: "18px 20px" }}>
        <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, color: "#8A96A3", marginBottom: 6 }}>
          QUESTION {q.n} / {ONBOARDING_QUESTIONS.length}
        </div>
        <h2 style={{ fontFamily: "'Space Grotesk', sans-serif", fontSize: 17, fontWeight: 600, color: "#E7ECEF", margin: "0 0 4px" }}>
          {q.title}
        </h2>
        <p style={{ fontFamily: "'Inter', sans-serif", fontSize: 12.5, color: "#8A96A3", margin: "0 0 16px" }}>{q.sub}</p>
        <RankList items={answers[q.id]} onChange={(next) => setAnswers((a) => ({ ...a, [q.id]: next }))} />
      </div>

      <div style={{ padding: 20, borderTop: "1px solid #1C242D" }}>
        <button
          onClick={() => (isLast ? onDone(answers) : setQIdx((i) => i + 1))}
          style={{
            width: "100%",
            background: "#3FD8C4",
            color: "#0A0E13",
            border: "none",
            borderRadius: 10,
            padding: "13px 0",
            fontFamily: "'Space Grotesk', sans-serif",
            fontWeight: 700,
            fontSize: 14.5,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: 6,
            cursor: "pointer",
          }}
        >
          {isLast ? "Voir mes recommandations" : "Suivant"}
          <ArrowRight size={16} />
        </button>
      </div>
    </div>
  );
}

/* ---------------------------------------------------------------
   Match card + drill-down analysis
----------------------------------------------------------------*/
function MatchCard({ m, retained, onToggleRetain }) {
  const [open, setOpen] = useState(false);
  const [openArg, setOpenArg] = useState(null);
  const [showFullStats, setShowFullStats] = useState(false);

  return (
    <div style={{ background: "#12181F", border: "1px solid #1C242D", borderRadius: 14, marginBottom: 12, overflow: "hidden" }}>
      <div style={{ display: "flex", padding: "14px 16px", gap: 12, alignItems: "center" }}>
        <Gauge value={m.compat} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontFamily: "'Space Grotesk', sans-serif", fontWeight: 600, fontSize: 15, color: "#E7ECEF" }}>
            {m.home} – {m.away}
          </div>
          <div style={{ fontFamily: "'Inter', sans-serif", fontSize: 12.5, color: "#8A96A3", marginTop: 2 }}>{m.market}</div>
        </div>
        <div style={{ textAlign: "right" }}>
          <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 15, fontWeight: 600, color: "#E7ECEF" }}>{m.cote.toFixed(2)}</div>
          <div style={{ fontFamily: "'Inter', sans-serif", fontSize: 10.5, color: "#4A5560" }}>cote</div>
        </div>
      </div>

      <div style={{ display: "flex", gap: 8, padding: "0 16px 14px" }}>
        <button onClick={() => setOpen((o) => !o)} style={btnSecondary()}>
          {m.args.length} argument{m.args.length > 1 ? "s" : ""} {open ? <ChevronUp size={13} /> : <ChevronDown size={13} />}
        </button>
        <button onClick={() => onToggleRetain(m.id)} style={btnPrimary(retained)}>
          {retained ? <Check size={13} /> : <Plus size={13} />}
          {retained ? "Retenu" : "Retenir"}
        </button>
      </div>

      {open && (
        <div style={{ borderTop: "1px solid #1C242D" }}>
          {m.args.map((a, i) => (
            <div key={i} style={{ borderBottom: i < m.args.length - 1 ? "1px solid #1C242D" : "none" }}>
              <button
                onClick={() => setOpenArg(openArg === i ? null : i)}
                style={{
                  width: "100%",
                  background: "transparent",
                  border: "none",
                  padding: "12px 16px",
                  display: "flex",
                  alignItems: "center",
                  gap: 8,
                  cursor: "pointer",
                  textAlign: "left",
                }}
              >
                <ChevronRight
                  size={13}
                  color="#3FD8C4"
                  style={{ transform: openArg === i ? "rotate(90deg)" : "none", transition: "transform .15s", flexShrink: 0 }}
                />
                <span style={{ fontFamily: "'Inter', sans-serif", fontSize: 13.5, color: "#E7ECEF", fontWeight: 500 }}>{a.t}</span>
              </button>
              {openArg === i && (
                <div style={{ padding: "0 16px 14px 37px", fontFamily: "'Inter', sans-serif", fontSize: 12.5, color: "#8A96A3", lineHeight: 1.5 }}>
                  {a.ev}
                  {showFullStats && <div style={{ marginTop: 6, color: "#5FCBBE", fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5 }}>{a.detail}</div>}
                </div>
              )}
            </div>
          ))}
          <div style={{ padding: "12px 16px", borderTop: "1px solid #1C242D" }}>
            <button onClick={() => setShowFullStats((s) => !s)} style={{ background: "none", border: "none", color: "#8A96A3", fontFamily: "'Inter', sans-serif", fontSize: 12, cursor: "pointer", padding: 0 }}>
              {showFullStats ? "Masquer les statistiques complètes" : "Voir les statistiques complètes"}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

const btnSecondary = () => ({
  flex: 1,
  background: "#1C242D",
  border: "1px solid #232C36",
  color: "#E7ECEF",
  borderRadius: 8,
  padding: "9px 10px",
  fontFamily: "'Inter', sans-serif",
  fontSize: 12.5,
  fontWeight: 500,
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  gap: 6,
  cursor: "pointer",
});

const btnPrimary = (active) => ({
  flex: 1,
  background: active ? "#3FD8C4" : "transparent",
  border: `1px solid ${active ? "#3FD8C4" : "#3FD8C4"}`,
  color: active ? "#0A0E13" : "#3FD8C4",
  borderRadius: 8,
  padding: "9px 10px",
  fontFamily: "'Inter', sans-serif",
  fontSize: 12.5,
  fontWeight: 600,
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  gap: 6,
  cursor: "pointer",
});

/* ---------------------------------------------------------------
   Screen: Matches
----------------------------------------------------------------*/
function MatchesScreen({ selection, toggleSelect, goWorkshop }) {
  const worthy = MATCHES.filter((m) => m.compat >= 75).length;
  return (
    <div style={{ height: "100%", overflowY: "auto", padding: "22px 16px 100px" }}>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, color: "#3FD8C4", letterSpacing: "0.08em" }}>SAMEDI 14 NOVEMBRE</div>
      <h1 style={{ fontFamily: "'Space Grotesk', sans-serif", fontSize: 20, fontWeight: 700, color: "#E7ECEF", margin: "8px 0 2px" }}>
        {MATCHES.length} rencontres à examiner
      </h1>
      <p style={{ fontFamily: "'Inter', sans-serif", fontSize: 13, color: "#8A96A3", margin: "0 0 18px" }}>
        <span style={{ color: "#3FD8C4", fontWeight: 600 }}>{worthy} méritent</span> votre attention aujourd'hui
      </p>

      {MATCHES.map((m) => (
        <MatchCard key={m.id} m={m} retained={selection.includes(m.id)} onToggleRetain={toggleSelect} />
      ))}

      {selection.length > 0 && (
        <div
          style={{
            position: "fixed",
            bottom: 76,
            left: "50%",
            transform: "translateX(-50%)",
            width: 358,
            maxWidth: "calc(100% - 32px)",
            background: "#1C242D",
            border: "1px solid #3FD8C4",
            borderRadius: 12,
            padding: "12px 14px",
            display: "flex",
            alignItems: "center",
            gap: 10,
          }}
        >
          <div style={{ flex: 1, fontFamily: "'Inter', sans-serif", fontSize: 13, color: "#E7ECEF" }}>
            Ma sélection <span style={{ color: "#3FD8C4", fontWeight: 700 }}>({selection.length})</span>
          </div>
          <button onClick={goWorkshop} style={{ background: "#3FD8C4", border: "none", color: "#0A0E13", borderRadius: 8, padding: "8px 12px", fontFamily: "'Space Grotesk', sans-serif", fontWeight: 700, fontSize: 12.5, cursor: "pointer", display: "flex", alignItems: "center", gap: 5 }}>
            Construire mon combiné <ArrowRight size={13} />
          </button>
        </div>
      )}
    </div>
  );
}

/* ---------------------------------------------------------------
   Screen: Workshop (Atelier de décision)
----------------------------------------------------------------*/
function tierLabel(n) {
  if (n <= 2) return { label: "Prudente", color: "#3FD8C4" };
  if (n === 3) return { label: "Équilibrée", color: "#5FCBBE" };
  return { label: "Ambitieuse", color: "#E39A3D" };
}

function WorkshopScreen({ selection, ticket, setTicket }) {
  const selMatches = useMemo(() => MATCHES.filter((m) => selection.includes(m.id)).sort((a, b) => a.cote - b.cote), [selection]);
  const [variants, setVariants] = useState([]);

  const propositions = useMemo(() => {
    if (selMatches.length < 2) return [];
    const sizes = Array.from(new Set([2, 3, selMatches.length].filter((n) => n <= selMatches.length && n >= 2)));
    return sizes.map((n) => {
      const set = selMatches.slice(0, n);
      const odds = set.reduce((acc, m) => acc * m.cote, 1);
      return { size: n, set, odds, ...tierLabel(n) };
    });
  }, [selMatches]);

  const ticketMatches = MATCHES.filter((m) => ticket.includes(m.id));
  const ticketOdds = ticketMatches.reduce((acc, m) => acc * m.cote, 1);

  const generateVariant = () => {
    if (selMatches.length < 2) return;
    const shuffled = [...selMatches].sort(() => Math.random() - 0.5);
    const n = Math.min(3, shuffled.length);
    const set = shuffled.slice(0, n);
    const odds = set.reduce((acc, m) => acc * m.cote, 1);
    setVariants((v) => [{ id: Date.now(), set, odds }, ...v].slice(0, 2));
  };

  const toggleTicketItem = (id) => {
    setTicket((t) => (t.includes(id) ? t.filter((x) => x !== id) : [...t, id]));
  };

  if (selection.length === 0) {
    return (
      <div style={{ height: "100%", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", padding: 30, textAlign: "center" }}>
        <LayoutList size={30} color="#3FD8C4" />
        <h2 style={{ fontFamily: "'Space Grotesk', sans-serif", color: "#E7ECEF", fontSize: 17, margin: "14px 0 6px" }}>Aucune sélection pour l'instant</h2>
        <p style={{ fontFamily: "'Inter', sans-serif", color: "#8A96A3", fontSize: 13, lineHeight: 1.5 }}>
          Retenez des rencontres depuis l'onglet Matchs pour que le copilote génère vos combinés.
        </p>
      </div>
    );
  }

  return (
    <div style={{ height: "100%", overflowY: "auto", padding: "22px 16px 100px" }}>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, color: "#3FD8C4", letterSpacing: "0.08em" }}>ATELIER DE DÉCISION</div>
      <h1 style={{ fontFamily: "'Space Grotesk', sans-serif", fontSize: 20, fontWeight: 700, color: "#E7ECEF", margin: "8px 0 18px" }}>
        Votre sélection ({selMatches.length})
      </h1>

      {selection.length < 2 ? (
        <div style={{ background: "#1C242D", border: "1px solid #232C36", borderRadius: 10, padding: 14, fontFamily: "'Inter', sans-serif", fontSize: 13, color: "#8A96A3", marginBottom: 18 }}>
          Retenez au moins 2 matchs pour que le copilote propose des combinés.
        </div>
      ) : (
        propositions.map((p) => (
          <div key={p.size} style={{ background: "#12181F", border: "1px solid #1C242D", borderRadius: 14, padding: 16, marginBottom: 12 }}>
            <div style={{ display: "flex", alignItems: "center", gap: 6, marginBottom: 10 }}>
              <Sparkles size={14} color={p.color} />
              <span style={{ fontFamily: "'Space Grotesk', sans-serif", fontWeight: 700, fontSize: 14, color: p.color }}>Proposition {p.label}</span>
            </div>
            {p.set.map((m) => (
              <div key={m.id} style={{ fontFamily: "'Inter', sans-serif", fontSize: 13.5, color: "#E7ECEF", padding: "3px 0" }}>{m.home} — {m.market}</div>
            ))}
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginTop: 12 }}>
              <span style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 17, fontWeight: 600, color: "#E7ECEF" }}>Cote {p.odds.toFixed(2)}</span>
              <button onClick={() => setTicket(p.set.map((m) => m.id))} style={{ background: p.color, border: "none", color: "#0A0E13", borderRadius: 8, padding: "8px 14px", fontFamily: "'Space Grotesk', sans-serif", fontWeight: 700, fontSize: 12.5, cursor: "pointer" }}>
                Utiliser
              </button>
            </div>
          </div>
        ))
      )}

      {variants.map((v) => (
        <div key={v.id} style={{ background: "#12181F", border: "1px dashed #232C36", borderRadius: 14, padding: 16, marginBottom: 12 }}>
          <div style={{ fontFamily: "'Space Grotesk', sans-serif", fontWeight: 700, fontSize: 13, color: "#8A96A3", marginBottom: 8 }}>Variante</div>
          {v.set.map((m) => (
            <div key={m.id} style={{ fontFamily: "'Inter', sans-serif", fontSize: 13.5, color: "#E7ECEF", padding: "3px 0" }}>{m.home} — {m.market}</div>
          ))}
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginTop: 12 }}>
            <span style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 17, fontWeight: 600, color: "#E7ECEF" }}>Cote {v.odds.toFixed(2)}</span>
            <button onClick={() => setTicket(v.set.map((m) => m.id))} style={{ background: "#1C242D", border: "1px solid #3FD8C4", color: "#3FD8C4", borderRadius: 8, padding: "8px 14px", fontFamily: "'Space Grotesk', sans-serif", fontWeight: 700, fontSize: 12.5, cursor: "pointer" }}>
              Utiliser
            </button>
          </div>
        </div>
      ))}

      {selection.length >= 2 && (
        <button onClick={generateVariant} style={{ width: "100%", background: "transparent", border: "1px dashed #3FD8C4", color: "#3FD8C4", borderRadius: 10, padding: "11px 0", fontFamily: "'Inter', sans-serif", fontWeight: 600, fontSize: 13, cursor: "pointer", marginBottom: 20 }}>
          Générer des variantes
        </button>
      )}

      <div style={{ background: "#12181F", border: "1px solid #1C242D", borderRadius: 14, padding: 16 }}>
        <div style={{ fontFamily: "'Space Grotesk', sans-serif", fontWeight: 700, fontSize: 14, color: "#E7ECEF", marginBottom: 10 }}>Mon ticket</div>
        {selMatches.map((m) => (
          <label key={m.id} style={{ display: "flex", alignItems: "center", gap: 10, padding: "7px 0", cursor: "pointer" }}>
            <input type="checkbox" checked={ticket.includes(m.id)} onChange={() => toggleTicketItem(m.id)} style={{ accentColor: "#3FD8C4", width: 15, height: 15 }} />
            <span style={{ fontFamily: "'Inter', sans-serif", fontSize: 13.5, color: ticket.includes(m.id) ? "#E7ECEF" : "#4A5560" }}>{m.home} — {m.market}</span>
          </label>
        ))}
        <div style={{ borderTop: "1px solid #1C242D", marginTop: 10, paddingTop: 12, display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
          <span style={{ fontFamily: "'Inter', sans-serif", fontSize: 12, color: "#8A96A3" }}>Cote actuelle</span>
          <span style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 20, fontWeight: 600, color: "#3FD8C4" }}>{ticketMatches.length ? ticketOdds.toFixed(2) : "—"}</span>
        </div>
        <div style={{ display: "flex", gap: 8, marginTop: 14 }}>
          <button style={{ flex: 1, background: "#1C242D", border: "1px solid #232C36", color: "#E7ECEF", borderRadius: 9, padding: "11px 0", fontFamily: "'Inter', sans-serif", fontWeight: 600, fontSize: 13, cursor: "pointer" }}>
            Enregistrer
          </button>
          <button style={{ flex: 1, background: "#3FD8C4", border: "none", color: "#0A0E13", borderRadius: 9, padding: "11px 0", fontFamily: "'Space Grotesk', sans-serif", fontWeight: 700, fontSize: 13, cursor: "pointer" }}>
            Jouer sur Betclic
          </button>
        </div>
      </div>
    </div>
  );
}

/* ---------------------------------------------------------------
   Root
----------------------------------------------------------------*/
export default function CopilotPrototype() {
  const [stage, setStage] = useState("onboarding");
  const [tab, setTab] = useState("matches");
  const [selection, setSelection] = useState([]);
  const [ticket, setTicket] = useState([]);

  const toggleSelect = (id) => {
    setSelection((s) => {
      const next = s.includes(id) ? s.filter((x) => x !== id) : [...s, id];
      setTicket(next);
      return next;
    });
  };

  return (
    <div style={{ background: "#05070A", minHeight: "100vh", display: "flex", alignItems: "center", justifyContent: "center", padding: 20 }}>
      <style>{FONT_IMPORT}</style>
      <div
        style={{
          width: 390,
          height: 780,
          background: "#0A0E13",
          borderRadius: 36,
          border: "8px solid #1C242D",
          boxShadow: "0 30px 70px rgba(0,0,0,0.55)",
          overflow: "hidden",
          position: "relative",
          display: "flex",
          flexDirection: "column",
        }}
      >
        <div style={{ height: 30, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
          <div style={{ width: 90, height: 5, borderRadius: 3, background: "#232C36" }} />
        </div>

        <div style={{ flex: 1, position: "relative", minHeight: 0 }}>
          {stage === "onboarding" ? (
            <Onboarding onDone={() => setStage("app")} />
          ) : tab === "matches" ? (
            <MatchesScreen selection={selection} toggleSelect={toggleSelect} goWorkshop={() => setTab("workshop")} />
          ) : (
            <WorkshopScreen selection={selection} ticket={ticket} setTicket={setTicket} />
          )}
        </div>

        {stage === "app" && (
          <div style={{ height: 68, borderTop: "1px solid #1C242D", display: "flex", flexShrink: 0, background: "#0A0E13" }}>
            <button onClick={() => setTab("matches")} style={navBtn(tab === "matches")}>
              <Target size={19} color={tab === "matches" ? "#3FD8C4" : "#5A6773"} />
              <span style={navLabel(tab === "matches")}>Matchs</span>
            </button>
            <button onClick={() => setTab("workshop")} style={navBtn(tab === "workshop")}>
              <LayoutList size={19} color={tab === "workshop" ? "#3FD8C4" : "#5A6773"} />
              <span style={navLabel(tab === "workshop")}>Atelier{selection.length > 0 ? ` (${selection.length})` : ""}</span>
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

const navBtn = (active) => ({
  flex: 1,
  background: "transparent",
  border: "none",
  display: "flex",
  flexDirection: "column",
  alignItems: "center",
  justifyContent: "center",
  gap: 4,
  cursor: "pointer",
});

const navLabel = (active) => ({
  fontFamily: "'Inter', sans-serif",
  fontSize: 10.5,
  fontWeight: 600,
  color: active ? "#3FD8C4" : "#5A6773",
});
