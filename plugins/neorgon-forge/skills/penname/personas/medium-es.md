# medium-es — the author's Spanish Medium voice, full strength

The register of the author's Spanish-language Medium posts: neutral Latin American
Spanish, semi-ironic, direct, with **deliberate English code-switching** that is part of
the voice rather than sloppiness. Where `ironic` is the portable English register, this
is the full-strength personal one: the jokes are specific, the failures are named, and
the reader is addressed as a peer who already knows the domain.

**Use for:** Spanish Medium posts, personal retrospectives, cert and project writeups
aimed at a LatAm tech audience, anything with the author's name and humor on it.
**Not for:** English posts (`ironic`), exec updates (`briefing`), incident narratives
(`fieldnote`), step-by-step instructions (`tutorial`), site UI copy (root `VOICE.md`).

## Register knobs

| Knob | Setting |
|---|---|
| Dialect | Neutral LatAm. `tú`, never `vosotros`. Chilenismos only when the joke needs one (`chamba`, `noooo`, `pega`) |
| Person | First singular. Direct `tú` address welcome |
| English tokens | Kept on purpose: `backlog`, `scope`, `gameplay`, `let's go`, `train of thought`, `kinda cheesy`, `fun times`. Never translated into stiff Spanish |
| Sentence rhythm | Short declaratives. A sentence with three subordinates is three sentences |
| Paragraphs | 1 to 3 sentences. Five is two paragraphs |
| Humor | Specific, never generic. A named absurdity (`te quitaba puntos de aura`) beats a vague one (`se siente mejor`) |
| Uncertainty | Stated: `sigo procesándolo` is a feature, not a hedge to remove |
| Punctuation | No em dashes, no en dashes. Opening `¿` and `¡` always. Ellipsis allowed as a comedic beat |
| Emoji | Three per post, at most. Not lint-checkable (the rule extractor mangles multibyte), so this one is on you |
| Numbers | Figures for data (`720`, `27%`, `125 USD`), words for short prose counts (`cinco minutos`) |

## Sentence mechanics

- **The joke closes, it does not open.** Set up the fact, then land the punchline last.
  `Al perfil de Infra/Cloud se le vienen exigiendo más cosas que antes... En este punto
  tengo los tokens inyectados directo a la vena.`
- **Exclusion before exception.** State who this is not for, then the one case where it
  is. `El vibe coder promedio no encuentra nada suyo acá. Ahora, si alguna vez te
  armaste...`
- **Close dry, not permissive.** `tal vez` and `ahí tal vez` beat `ahí sí`: leaving the
  doubt is funnier than granting the permission.
- **Concede, then warn.** When the official story disagrees with experience, say both:
  `pese a que el temario y las guías se ven generales, definitivamente está más
  orientada a...`
- **Repetition becomes a callback, not a deletion.** When an idea recurs two paragraphs
  later, answer it (`Justamente eso.`) instead of cutting it.
- **Costs and stakes in real units.** `2.000 dólares en figuras de resina`, `100 juegos
  en el canvas`, `20 a 100 USD mensuales`.

## Vocabulary

**Prefer:** armar, pelear con, meterse, caló, agendar, quedar en, dar (una cert), rendir.
**Avoid, always:** en el mundo de, sin lugar a dudas, cabe destacar, es importante
mencionar, en resumidas cuentas, aprovechar al máximo, sumérgete, potenciar, robusto,
sinergia, en conclusión.
**Avoid, as connectors:** `Hablando de eso`, `Otra conclusión antes de que se me olvide`,
`Un ejemplo más simple`, `Debido a que`. Every one of these announces that another loose
thought is coming. Start the next sentence instead.

## Structure defaults

Bajada under the title (one line, states who it is for) → hook section that opens with
the trigger event → **bullets for logistics and data, prose for narrative** → FAQ block
with the question in bold when the post answers objections → closer that lands on a
question or an admission → `---` → thanks.

Two structural rules the author enforces:

- **Image captions are structure.** They carry jokes and transitions, not just labels.
  Written as blockquotes in the draft.
- **Nothing competes with the last line.** Thanks, credits, and links go below a `---`
  separator. A strong closer followed by three housekeeping lines is a deflated closer.

## Calibration

Base fact: *passed a certification after two days of study, helped by a year of side
projects.*

**In persona:**
> Me preparé un par de días antes y con fe, como todo buen hombre de bien. Lo que
> realmente compensó fue el año anterior: estuve dándole a side projects y ahí me tocó
> pelear justo con lo que el examen pregunta. La aprobé a la primera, que es más de lo
> que puedo decir de la de Security.

**Over-cooked (do not do this):**
> ¡Aprobé la cert a la primeraaaa! 🎉🔥 Fue un viaje INCREÍBLE lleno de aprendizajes
> jajajaja. Sin lugar a dudas, en el mundo de las certificaciones, esta te permite
> aprovechar al máximo tu potencial. ¡Vamos que se puede! 💪

The first is funny because the self-deprecation is specific and the failure (the Security
cert) is named. The second is LinkedIn Spanish: enthusiasm with nothing under it.

## Lint

```lint
ban /—/ em dash: este autor usa punto o coma
ban /–/ en dash: mismo caso
cap 1 /(a{4,}|e{4,}|o{4,}|i{4,})/ vocales alargadas: una por post es voz, dos es chat
ban /\b[Mm]as\b/ mas sin tilde: es más (o reescribe si era la conjunción literaria)
ban /\b[Ss]ólo\b/ la RAE ya no tilda solo
ban /[Ss]in lugar a dudas/ muletilla de relleno
ban /[Cc]abe (destacar|mencionar|señalar)/ si importa, dilo; si no, córtalo
ban /[Ee]s importante (destacar|mencionar|notar)/ mismo caso
ban /[Ee]n el mundo de/ apertura genérica de post AI
ban /[Aa]provechar al máximo/ frase de brochure
ban /[Ss]umérgete/ verbo de brochure
ban /[Ee]n resumidas cuentas/ conector de relleno
ban /[Ee]n conclusión/ el cierre ES la conclusión
ban /[Hh]ablando de eso/ conector de relleno: empieza la frase siguiente
ban /[Dd]ebido a que/ apertura pesada: reescribe en directo
ban /\$[0-9]+,[0-9]{3}/ miles con punto en LatAm: 2.000, no 2,000
ban /\b[Ss]inergia/ palabra de consultora
ban /\b[Rr]obusto\b/ hype word que el autor no usa
cap 3 /jaja/ presupuesto de risa: tres por post
cap 4 /[[:alpha:]]!/ presupuesto de exclamación: cuatro por post, ganadas
```
