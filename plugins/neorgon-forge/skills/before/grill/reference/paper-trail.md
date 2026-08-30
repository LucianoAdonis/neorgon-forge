# The paper trail a grilling leaves

Two files, two different lifetimes. Loaded on demand, because most grillings run stateless and
never need either.

## `.forge/context.md`: the vocabulary

One glossary per repo. It answers "what do we call this, and what do we not call it". It is not
documentation of the system; it is documentation of the *language*, and it is short.

```markdown
# <Project> domain

## Language

**<Term>** · agreed <YYYY-MM-DD>:
What it is, in one or two sentences, in the words a person would use out loud.
_Avoid_: <the words this must not be called>, <and this one>

## Relationships

- A **<Term>** holds many **<Other term>**
- A **<Term>** carries one **<Third term>** at a time

## Flagged ambiguities

- "<word>" was used for both <X> and <Y>. Resolved: <X> is **<Term>**; <Y> is **<Other term>**.
```

The date is one field, not two, and it is re-stamped **in place** when a definition is
corrected. `atlas` uses it to say which of a disagreeing pair is older, and a term carrying
both an original and a revision date would let it order the code against the wrong event.

Three rules that decide whether it stays useful:

- **The `_Avoid_` line is the load-bearing part.** A definition tells you what a word means; the
  avoid list is what stops the next person inventing a synonym. A term with no rejected
  synonyms usually was not contested and probably does not need an entry.
- **Write the entry when the term is contested, not at the end.** A glossary reconstructed after
  the interview records the words you happened to remember, which are the uncontested ones.
- **Flagged ambiguities carry the resolution, not just the confusion.** An entry saying two
  words were muddled, without saying which one won, leaves the reader exactly where they
  started.

## `.forge/decisions/NNNN-<slug>.md`: one hard-to-reverse choice

```markdown
# NNNN. <The decision, as a statement, not a question>

Date: YYYY-MM-DD
Status: accepted | superseded by NNNN

## Context

What was true that forced a choice. The constraint, not the wish.

## Decision

What was chosen, in one paragraph, in the present tense.

## Rejected

The alternative that lost, and the specific thing that lost it. An alternative
recorded without its losing reason will be re-proposed within the month.

## Consequences

What is now harder, and what is now impossible. The good consequences write
themselves; these are the ones worth the file.
```

**Write one only when undoing the decision would be expensive.** The number of decision records
a repo can support is small, and the failure mode is not too few, it is a directory of forty
where the three that mattered are invisible. A decision that is cheap to reverse belongs in the
conversation, or in `.forge/brief.md` under Decisions, which is where `task` keeps the ordinary
running record.

**Superseding, never deleting.** A decision that turned out wrong gets a new record and a
`Status: superseded by NNNN` on the old one. The wrong turn is the most useful thing in the
directory: it is the only record of an idea that looks good and is not.

## How this relates to the rest of `.forge/`

| File | Written by | Lifetime |
|---|---|---|
| `context.md` | `grill` | Standing. Grows with the project, worth committing |
| `decisions/` | `grill` | Standing. Append-only, superseded rather than edited |
| `map.md` | `wayfind` | Standing. A description of where things live |
| `brief.md` | `task` | One piece of work. Closed when the work ships |
| `evidence.md` | `untangle` | One investigation |
| `handoff-*.md` | `handoff` | One session boundary. Disposable once read |

`atlas` reads `context.md` when it is present, and reports where the extracted model's names
have drifted from the language the glossary says the project speaks.
