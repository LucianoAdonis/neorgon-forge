# Embedding a set

Contract version `neo-quiz-embed/1`. Published at
`https://quiz.neorgon.com/llms.txt`, which is the source of truth if this page
and the site ever disagree.

## The snippet

```html
<iframe src="https://quiz.neorgon.com/?embed=1&game=beats&limit=10&set=jp-loanwords-beats"
  width="100%" height="560" loading="lazy" style="border:0"
  title="Loanword beats · Quiz"></iframe>
```

`set=` takes either form, and which one depends on where the file lives rather
than on preference:

| The set is | `set=` |
|---|---|
| In Quiz's own library | the plain id, `jp-loanwords-beats` |
| Anywhere else, over https with CORS | the encoded absolute URL, `https%3A%2F%2Fexample.com%2Fbeats.json` |

`http://localhost` is accepted only while the engine itself is on localhost,
which is what lets Runcible on `:8878` embed Quiz on `:8880` for real.

| Param | Values | Meaning |
|---|---|---|
| `embed` | `1` | Strips the chrome to a slim bar with an "Open in Quiz" link, and starts the round on load |
| `game` | `beats`, `sound`, `pairs`, `order` | Optional when `set` is given: the set's own game is used |
| `set` | id or encoded URL | The set. Absent in embed is `quiz:error { code: "no-set" }` |
| `limit` | integer | Items per round, default 10, capped at the set's length |
| `seed` | any string | Makes the shuffle, the numeral window and the sound direction deterministic, so a host can replay a round |
| `skill` | a dotted string | Overrides the set's own `skill` on every `quiz:answer` |
| `lang` | `en`, `es` | UI language |
| `theme` | a theme name | Read by the fleet's pre-paint theme script |

## Reading the answers back

Every message is `{ v: 1, type, ... }`, posted to the referrer's origin and never
to `*`. With no referrer the engine posts nothing at all.

```js
const QUIZ = 'https://quiz.neorgon.com';
window.addEventListener('message', (e) => {
  if (e.origin !== QUIZ || e.source !== frame.contentWindow) return;
  const m = e.data;
  if (!m || m.v !== 1) return;
  if (m.type === 'quiz:ready')  { if (m.store === 'ephemeral') warnNotSaved(); }
  if (m.type === 'quiz:answer') { record(m.itemId, m.skill, m.correct, m.ms); }
});
frame.addEventListener('load', () => {
  frame.contentWindow.postMessage({ v: 1, type: 'quiz:hello' }, QUIZ);
});
```

| Message | Payload | Why a host wants it |
|---|---|---|
| `quiz:ready` | `{ setId, setVersion, game, name, total, store }` | The round length after `limit`, and whether this frame persists at all |
| `quiz:answer` | `{ setId, game, itemId, skill, correct, ms, chosen, expected }` | One per item. **This is the evidence.** `itemId` is the set's own item id |
| `quiz:session-end` | `{ setId, game, answered, correct, wrong, ms, medianMs, bestStreak, total, complete }` | Once per round. `complete` is false when the learner left early |
| `quiz:error` | `{ code, message }` | `no-set`, `set-fetch-failed`, `set-invalid`, `game-unknown`, `game-mismatch` |
| `quiz:resize` | `{ height }` | Debounced 120ms. Clamp it; the frame does not |

Inbound, all three accepted from any origin because they are read-only or
round-scoped: `quiz:hello` (re-emits `quiz:ready`), `quiz:start { limit?, seed? }`,
`quiz:theme { theme }`.

**Send `quiz:hello` on the iframe's `load` event.** The engine can be ready before
the host's listener exists, and a host that skips this gets an intermittently
blank panel that works on every machine it is tested on.

**Silence after `quiz:ready` is a fault, and it does not look like one.** The frame
keeps showing a working game while the host quietly records nothing. That is why
every message carries a version, why a host drops a `v` it does not know rather
than guessing, and why a host that counts progress should time the silence.

## Where the round is stored, honestly

At boot the engine takes the referrer's origin and allows `https://neorgon.com`,
anything ending `.neorgon.com` over https at a label boundary, and localhost only
while the engine is itself local. An allowed host gets `store: "engine"` and the
round is written to Quiz's own storage; every other host, and any frame with no
referrer, gets `store: "ephemeral"` and nothing is written.

The invariant behind that: **an unlisted origin can never cause a write to
quiz.neorgon.com's persistent storage.** Nothing a host sends writes storage, so
the allowlist decides only whether an embedded frame persists.

Say which of the two an embed gets. Where it is `ephemeral`, the "Open in Quiz"
link is the path that always persists, and the frame prints one line saying so.

## The Runcible exercise

Inside a Runcible Book the iframe is not written by hand. The chapter declares
the exercise and the shell builds the URL, sends the handshake, times the
silence, and converts every `quiz:answer` into one attempt:

```json
{ "id": "e-beats", "type": "quiz", "game": "beats", "skill": "jp.mora.count",
  "src": "books/japanese/sets/jp-loanwords-beats.json", "limit": 10,
  "title": { "en": "Count the beats", "es": "Cuenta los pulsos" } }
```

- `game` and `src` are required, `skill` is required, `limit` is optional
- `src` is a `neo-quiz-set/1` document **on Runcible's own origin**, and it must
  appear in the manifest's `data[]`. An undeclared `src` is a load error naming
  `book.json`, exactly as it is for a deck
- the attempt is recorded under the **spec's** `skill`, not the set's. The set's
  is informational, and recording under it is how evidence lands nowhere
- the skill rule is the deck's, unchanged: a skill nothing else in the Book reads
  is an error, because the attempts would be recorded and never counted

`runcible-book` owns the chapter around it, including the `data[]` line and the
evidence gate the skill feeds.
