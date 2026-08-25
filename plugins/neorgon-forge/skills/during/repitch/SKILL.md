---
name: repitch
description: Stop. That last answer did not land. Re-pitch it with the context that was missing, in plain language, using the project's own vocabulary.
user-invocable: true
disable-model-invocation: true
license: MIT
---

# repitch

That did not land. Say it again, differently.

Assume the gap is missing **context**, not missing intelligence: give me the one or two facts
you were standing on that I was not, before you restate the point.

Then re-pitch:

- **Plain language.** Short sentences, one idea each, active voice, no clause stacking. Where a
  term has a common word and a technical word, use the common one.
- **The project's vocabulary, not yours.** If `.forge/context.md` exists, use the terms it
  defines and none of the ones its `_Avoid_` lines rule out. Where the point needs a word that
  glossary does not have, say so: an undefined term is often the whole reason the message
  missed.
- **No new jargon**, and no acronym that has not been expanded once in this conversation.
- **Lead with the conclusion**, then the reasoning. The first version probably did the reverse.

Do not apologise, do not restate that you were unclear, and do not simply say the same thing
more slowly. A re-pitch that repeats the original with softer wording has not diagnosed
anything. If you genuinely cannot find another angle, say which part you think is the sticking
point and ask.
