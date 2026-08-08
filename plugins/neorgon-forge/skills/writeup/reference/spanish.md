# Neutral Spanish for write-ups

Read when producing a `POST.es.md`. The target is prose that reads naturally to an engineer in
Mexico City, Bogotá, Buenos Aires and Santiago alike — no reader should be able to place the
author from the vocabulary.

## Pronouns

- **`tú`** throughout. Never `vos` (Río de la Plata, Central America) or `vosotros` (Spain).
- Impersonal constructions carry a lot of the load: *se llega ahí dedicándole años* rather than
  *llegas ahí dedicándole años* when the subject is generic.
- Verb forms follow: `tienes` / `puedes` / `haces`, never `tenés` / `podés` / `hacés`, never
  `tenéis` / `podéis`.

## Regionalism blacklist

These have actually shown up and been caught. The Chilean ones matter most here because the
author is Chilean and they slip in unnoticed.

| Avoid | Where it's from | Use instead |
|---|---|---|
| cachar / cachai | Chile, Peru | entender, detectar, darse cuenta |
| altiro | Chile | de inmediato, enseguida |
| po, weon, fome | Chile | (drop entirely) |
| arriendo | Southern Cone | alquiler |
| pololo / polola | Chile | pareja, novio/a |
| plata (money) | Southern Cone | dinero |
| chévere | Caribbean, Venezuela | genial, buenísimo |
| guay, vale, tío | Spain | genial, de acuerdo, tipo |
| coger (verb) | fine in Spain, vulgar in most of LatAm | tomar, agarrar |
| ordenador | Spain | computadora |
| móvil | Spain | celular |
| zumo | Spain | jugo |

`scripts/check-writeup.sh` greps for the worst of these.

## Loanwords: keep them

Spanish-speaking engineers use English tech vocabulary. Translating it produces prose that
reads like a badly localised manual. Keep:

*deploy, commit, branch, build, release, feature, bug, log, endpoint, framework, seniority,
speedrun, slop, cringe, hype, prompt, pipeline*

Inflect them naturally — *deployear* is real usage, *el deploy* / *los deploys* is fine.

Do translate the ones with settled Spanish equivalents: *archivo* (file), *carpeta* (folder),
*base de datos*, *red* (network), *servidor*, *pruebas* (tests), *rendimiento* (performance).

## Domain terms: use the published translation

Never invent a translation for a term that has an official or widely-used one. Look it up.

**Hunter x Hunter / Nen**, since it recurs in this monorepo:

| English | Spanish |
|---|---|
| Enhancement | Refuerzo / Reforzamiento |
| Transmutation | Transformación |
| Conjuration | Materialización |
| Specialization | Especialización |
| Manipulation | Manipulación |
| Emission | Emisión |
| Enhancer / Conjurer / Emitter | Reforzador / Materializador / Emisor |

## Translate the voice, not the words

A literal translation of an informal English post reads stiff in Spanish, which is the failure
mode to watch for. If the English is casual, the Spanish must be equally casual — even when
that means a different idiom entirely.

| English | Works in Spanish |
|---|---|
| let me cook | déjame cocinar (the calque is live internet usage) |
| hear me out | escúchame un momento |
| if the shoe fits | si el zapato calza |
| it's a bit cringe | suena un poco cringe |
| have a knack for it | tener mano para eso |
| you're paying rent | estás pagando alquiler |
| fair | y es justo / tiene razón |

`Honestly,` at the start of a sentence maps to `La verdad,` — both are the author thinking out
loud, and both should survive the detox pass.

## Length

Spanish runs roughly 10–15% longer than English for the same content. A 1,100-word English post
producing a 1,250-word Spanish one is normal, not bloat. Do not compress the Spanish to match
the English word count; compress both or neither.
