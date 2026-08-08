# Voice baseline

The standard every project meets unless its own `VOICE.md` says otherwise. Written as rules
that can be checked, because a voice guide nobody can grade against is a mood board.

**Scope: user-facing copy.** Marketing text, UI strings, meta tags, READMEs — anything a
person using the product sees. Internal engineering prose, code comments and design docs are
out of scope; flagging an em dash in an architecture note is a false positive, not a finding.

## Voice

Professional but casual, like a smart friend explaining their own tool. Confident, plain,
never salesy. Lead with what the user gets, not how it is built.

## Blocker rules (never ship a violation)

- **No em dashes (—) or en dashes (–).** Use a comma, or restructure. This is the single
  loudest AI tell in shipped copy.
- **Banned words:** powerful, seamless, seamlessly, leverage(s), leveraging, robust,
  utilize, utilise, unlock, unleash, elevate, supercharge, revolutionize, game-changing,
  cutting-edge, effortless(ly), delve, tapestry, testament, realm, landscape (figurative),
  foster.
- **Chrome invariants** — the strings that must read identically across every project in a
  suite: site name, footer attribution, `<title>` format. A local overlay declares them;
  with no overlay there are none. Where they exist, a project's own `VOICE.md` cannot
  override them, because their whole value is being identical everywhere.

## Warning rules

- **Meta description:** under 155 characters, no trailing period. Formula:
  `[active verb] + [what it does] + [key differentiator]. [constraint or benefit].`
- **Header subtitle:** one tight line, under 60 characters.
- **Lead with the benefit**, not the implementation. "Map your pain in 3D", not "Built with
  Three.js".

## Nit rules

- **Prefer active verbs:** map, spin, convert, export, browse, build, track, scan, plan,
  rank.
- Avoid hedging: "simply", "just", "basically".
- No rule-of-three padding, no "it's not just X, it's Y", no "in today's fast-paced world".

## Calibration

- On-voice: "Spin the wheel, get a decision. Share the config with one link."
- On-voice: "Map head pain in 3D, tag intensity and depth, export a shareable diary."
- Off-voice: "Leverage our powerful, seamless platform to unlock effortless decision-making."
- Off-voice: "A robust tool that revolutionizes how you utilize your time — it's not just a
  wheel."

The off-voice lines fail on every axis at once, which is what makes them easy. Real
violations usually fail on one axis and can be argued away, so grade against the rules
above rather than against how far the copy is from these examples.

## Bilingual projects

Translations carry the same voice, not the same words. Spanish stays plain and direct too;
formal-register bloat ("proceda a utilizar") is a violation even though it is grammatical.
Match the tú/usted register the project's `VOICE.md` declares. With none declared, default
to neutral-professional tú.
