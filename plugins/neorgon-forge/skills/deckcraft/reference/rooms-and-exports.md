# Rooms, legibility, and what each export path loses

Detail `SKILL.md` points at but does not carry. Read this when a deck has to survive a specific
room, or when the user is about to hand the file to someone rather than present it themselves.

## The room decides the minimum size

Two independent standards agree within about 7%: ISO 9241-303 sets a floor of 16 arcminutes of
cap height, and AVIXA's DISCAS acuity factor of 200 works out to 17.2 arcminutes. The practical
form, derived from AVIXA's published %EH table rather than quoted from the standard:

> element height ≥ farthest viewer distance ÷ 200

Applied to the 960×540 canvas, the ceiling on viewing distance expressed as a multiple of screen
height:

| Rendered px | Where it is used | Readable to about |
|---|---|---|
| 11 | slide number, code language tag, checklist state | 4× screen height |
| 12–13 | section progress, captions, table caption, person role, agenda sub-line | 4–5× |
| 15 | code, grid item heading, media bullets | 5.5× |
| 18 | body bullets, title subtitle | 6.5× |
| 26 | slide heading | 9.5× |
| 52 | stat value | 19× |

**What to do with that.** In a meeting room (about 4× screen height) everything works. In a
lecture hall (8×) nothing under 18px is legible, which means captions, table captions and the
footer rail are decoration, not content. Never put a fact only in a caption for a large room.

This is why "the number goes in the heading, not the caption" is a legibility rule and not only a
rhetorical one.

## Dark or light, by room rather than taste

Positive polarity (dark text on light) measurably beats the reverse for reading speed and
accuracy, and the advantage holds regardless of ambient light. Projection inverts the economics
though: a light theme in a darkened room is a glare source, and a dark theme under a weak
projector in a lit room washes out to grey.

| Situation | Theme |
|---|---|
| Lit room, projector | light (`minimal`, `azure`, `meadow`, `dawn`) |
| Darkened room, good projector | dark (`neorgon`, `royal`, `midnight`, `forest`, `ember`, `graphite`) |
| Screen share, viewers on laptops | either; follow the audience's habit |
| Printed or PDF handout | light, always |

## What each export path silently drops

The player is not the artifact. Anyone handed a file gets less than what you saw.

| Path | Loses |
|---|---|
| **PPTX** | speaker notes, gradients, patterns. Text stays real and editable |
| **Marp PDF / HTML** | speaker notes, gradients, patterns |
| **Standalone HTML** | speaker notes. Keeps gradients and patterns |
| **Reveal** | notes are written into the markup but no plugin is registered, so nobody can open them |
| **Marp PPTX** | everything editable: each slide becomes one flat image |

Two consequences worth stating to the user every time:

- **A presenter working from an exported file has no notes.** If the notes matter, either present
  from the app, or move the content onto the slide or into the appendix.
- **A deck that leans on gradients looks plainer in PowerPoint.** That is expected, not a bug, and
  it is a reason to keep the gradient count low anyway.

## Assets travel differently than you expect

A path starting with `/` means the site root in a browser and the filesystem root under Node. The
CLI rewrites these against `--base`, but a deck moved to another machine and built there needs
either a full URL, a `data:` URI, or a matching `--base`. The self-contained option is the logo
button, which embeds the image directly in the YAML.

## Sources

- ISO 9241-303:2011, ergonomic requirements for electronic visual displays (cap-height floor)
- AVIXA ANSI/V202.01:2016 DISCAS, and AVIXA's published %EH table
- EBU R 95 for safe areas: 3.5% action-safe, 5% graphics-safe, transferred from broadcast
- Piepenbrock, Mayr & Buchner on contrast polarity; Buchner & Baumgartner on ambient light

The viewing-ratio arithmetic is derived from AVIXA's table, not quoted from the standard text,
which is paywalled. It reproduces the classic 4/6/8 rules of thumb exactly, which is reasonable
corroboration but not a citation.
