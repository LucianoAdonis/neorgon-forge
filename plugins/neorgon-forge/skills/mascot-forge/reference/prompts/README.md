# Worked prompt examples

Real prompts from a shipped mascot, kept because the *shape* transfers even though
the character does not. Four shapes, each solving a different failure.

| Shape | Files | What it is doing |
|-------|-------|------------------|
| **Base design** | `base-*.txt` | Establishing a character from scratch across several directions. Each pins proportions and wardrobe hard, because "adult proportions, not chibi" had to be a requirement rather than a hint. |
| **Expression variant** | `var-*.txt` | Changing exactly one facial feature while pinning pose, hair, clothing, scale and canvas position. These produced frames that aligned at **zero pixels of drift**. |
| **Style change** | `style-*.txt` | Replacing the rendering while keeping the character. Note `style-vector.txt` demotes the reference to "use this only for WHO she is" — the earlier version said "exact character sheet" and got back near-copies. |
| **Outfit** | `outfit-*.txt` | Swapping clothing only. `outfit-christmas` and `outfit-halloween` show the hat constraint; `outfit-chibi` shows a redraw that deliberately breaks alignment. |

`restyle-*.txt` are a worked example of changing two things at once (hair and
palette) while holding everything else — useful as a template for "make it match our
brand" requests.

## The lines that do the work

Every one of these prompts ends with the same closing constraints, and they matter
more than the creative part:

```
Flat pure white background. No drop shadow, no text, no watermark, no border.
```

A drop shadow defeats background keying. A textured or off-white ground defeats it
completely — two otherwise good style experiments (`style-ukiyoe`, `style-riso`) were
rejected purely because they rendered on cream paper.

And the identity block, repeated verbatim in every prompt in the set:

```
same wavy hair in a high side ponytail tied with a black ribbon, same rectangular
black-framed glasses, same amber-brown irises with a white sclera and a highlight,
same gold hoop earrings
```

Drop the eye clause once and the eyes come back solid black.
