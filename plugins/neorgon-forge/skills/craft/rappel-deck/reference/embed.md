# Embedding a deck

Contract version `neo-rappel-embed/1`. Published at
`https://rappel.neorgon.com/llms.txt`, which is the source of truth if this page
and the site ever disagree.

A deck is delivered three ways, and which one to hand over depends on where the
file lives rather than on preference.

| The deck is | Deliver |
|---|---|
| Served by Rappel already | `?deck=<id>` |
| Hosted anywhere with CORS | `?src=<encoded https url>` |
| Small, and hosted nowhere | `#d=<base64url of the json>`, which rides in the fragment and reaches no server |

Exactly one of the three. Zero is an error the frame reports as `no-deck`, and
more than one takes them in that order and says on the console which it ignored.

## The snippet

```html
<iframe src="https://rappel.neorgon.com/?embed=1&mode=review&limit=20&src=https%3A%2F%2Fexample.com%2Fdeck.json"
  width="100%" height="640" loading="lazy" style="border:0"
  title="Spanish core verbs, Rappel"></iframe>
```

| Param | Values | Meaning |
|---|---|---|
| `embed` | `1` | Strips the chrome to a slim bar with an "Open in Rappel" link that keeps the other parameters |
| `deck`, `src`, `#d=` | see above | The deck itself |
| `mode` | `review`, `cram`, `browse` | `review` runs due cards and writes scheduling. `cram` runs everything and **writes nothing**. `browse` lists without a session |
| `limit` | integer | Caps the session |
| `ledger` | `engine`, `host` | `engine` persists on Rappel. `host` keeps everything in memory and posts it to you |
| `lang` | `en`, `es` | UI language |
| `theme` | a theme name | Applied to the document element |

## Reading the answers back

The engine posts to the parent, targeted at the referrer's origin, never `*`.
Every message carries `v: 1`.

The one worth wiring first is **`rappel:answer`**
(`{ deckId, sessionId, cardId, itemId, skill, grade, correct, ms }`). It is how
a review inside a host page becomes evidence there, and it carries the template's
`skill` string, which is why a deck meant for embedding gives every template one.

`rappel:ready`, `rappel:due` and `rappel:session-end` carry the counts a host
needs to show a badge. `rappel:progress` is the escape hatch that hands the whole
ledger back. `rappel:error` carries `no-deck`, `deck-fetch-failed`,
`deck-invalid`, `storage-unavailable` or `origin-refused`.

**Send `rappel:hello` on the iframe's load event.** The engine can become ready
before the host attaches its listener, and a host that skips this gets an
intermittently blank panel that works on every machine you test it on.

## Where progress lives, honestly

By default the ledger is stored by the engine, on Rappel's own origin, and that
is a best effort rather than a guarantee: a browser partitioning third party
storage can leave an embedded frame with nothing to write to. Where a host
cannot afford to lose progress, pass `ledger=host`, listen for
`rappel:progress`, store it yourself, and hand it back with `rappel:restore`.

Say which of the two an embed uses. A learner losing a month of reviews to a
storage policy nobody mentioned is the worst outcome this format has.
