# mascot-forge

An illustrated character, generated, cut out, aligned, and rigged to move on a page.

## What it does

`mascot-forge` creates character art through the Gemini image API, then handles the parts that
actually fail: keeping a character on-model across many frames, expression variants, seasonal
outfits, background removal that survives a dark page, frame alignment, and a click-reaction
rig.

The defining constraint is that **every prompt restates the character's identity**. The model
defends nothing you do not name, so anything left implicit drifts between frames.

## When to reach for it

Type `/mascot-forge`, or the agent reaches for it when asked to make a mascot, animate a
character, or add expressions and outfits.

Reach for it to draw the character. Once the art exists, resizing it into icon files is the
favicon skill's job. Not for photo editing, 3D, or video.

## Framing decides whether expressions are possible

A full-body figure at 7.5 heads tall has a face a third the size of a chibi's at the same
on-screen height. At a 300px hero that is a 30px head, and a blink will not read at all. If the
character needs expressions, frame waist-up. This is not a crop preference; it decides whether
half the work is visible.

Alignment needs something unchanged to match on, and the whole set must be re-prepped together,
because the shared canvas is the union of all the frames.

## It's working if

- `verify-frames.py` passes after every reprep, and you ran it rather than looking at a
  screenshot. The four things that break here all render fine.
- Every frame in a set shares one aspect ratio.
- The character is judged on the real background at the real size, never on white.
- A blink reads at the size it will actually be shown.
