# When the evidence contradicts itself

Read this when two observations cannot both be true. That situation always means an assumption is
wrong, and the assumption is almost never the interesting one. It is one of five boring ones.

Each case below has the same three parts: what was observed, why it looked impossible, and **the
shape of the mistake**. The last part is the transferable bit. The specific bugs never recur; the
shape recurs constantly.

---

## Not the same code

**Observed.** The fix works locally. Deployed, the old behaviour is still there. The file on the
server has the new line in it: someone checked.

**Why it looked impossible.** The code is right there. Reading it is proof.

**What it was.** The process had been running since before the deploy. The file on disk and the
code in memory were different things.

**The shape of the mistake:** *treating the source as the running system.* Reading a file tells
you what would run if it started now. Every layer between the file and the CPU can hold a stale
copy: a warm process, a bytecode cache, a bundler cache, a CDN edge, a Docker layer, a lockfile
pinning an old version of the thing you just patched.

**The discriminating test:** make the running system state its own identity. Log the commit SHA at
boot, print the resolved version, add a line that could only come from the new code. Not "is the
new code there": "is the new code the code that ran".

---

## Not the same input

**Observed.** The function is correct for `{locale: "es"}`. It was tested directly and it passes.
In production it returns the English string.

**Why it looked impossible.** The caller passes the locale. It is in the request.

**What it was.** A middleware upstream normalised the object and dropped the key. The function was
never wrong; it never saw `es`.

**The shape of the mistake:** *inferring the input from the code that produces it, instead of
observing it at the boundary.* Reading the caller tells you what it intends to pass. Between
intent and arrival there is serialisation, defaulting, validation, a schema that strips unknown
fields, a proxy that rewrites a header.

**The discriminating test:** log the actual value at the point of use, with its type. Half the time
the surprise is not the value but that it is a string `"undefined"`, or an array of one, or
`"0"`.

---

## Not the same environment

**Observed.** The test suite passes on every developer machine and fails in CI. Same commit, same
container image, same command.

**Why it looked impossible.** Identical inputs cannot produce different outputs.

**What it was.** Two tests wrote the same fixture file. On macOS the filesystem is
case-insensitive, so they collided into one file and the ordering hid it. CI ran on Linux, where
they were two files and the assertion about "the" fixture failed.

**The shape of the mistake:** *counting the environment as constant because it is invisible.* The
usual culprits, roughly in order of how often they are the answer: filesystem case sensitivity,
timezone (`UTC` in CI, local on the laptop), locale and collation order, an env var set in one
shell profile, CPU count changing a concurrency limit, DNS resolving differently inside a network,
a clock that is slightly wrong.

**The discriminating test:** dump the difference rather than reasoning about it. `env` on both
sides, diff it. It is faster than any theory and it usually ends the investigation.

---

## Not one bug

**Observed.** Uploads fail. A fix is found and verified. Uploads still fail, at the same rate,
with the same error message.

**Why it looked impossible.** The cause was confirmed. The fix was confirmed.

**What it was.** Two independent failures shared one user-visible symptom: a size limit at the
proxy, and an unrelated timeout in the thumbnailer. Fixing either left the symptom at roughly the
same frequency.

**The shape of the mistake:** *assuming one symptom means one cause.* This is the hypothesis space
collapsing early. It is most likely when the symptom is generic. A 500, "failed to save", a blank
screen. A generic symptom is the union of many paths.

**The discriminating test:** partition the population and check whether the *rate* moved, not
whether the symptom is gone. If a real fix does not change the rate, there is a second cause. Also
suspect this whenever the observed behaviour is intermittent at a suspiciously stable frequency.

---

## Not the layer you think

**Observed.** The query is slow. The query plan is fine, the indexes are used, the database
reports 4ms. The endpoint takes 900ms.

**Why it looked impossible.** The slow part was measured and it is not slow.

**What it was.** Connection pool exhaustion. The query took 4ms and waited 890ms for a connection.
Every measurement inside the database was accurate and none of them contained the problem.

**The shape of the mistake:** *theorising about a layer while only instrumenting the one above it.*
Time spent waiting to enter a layer is invisible from inside it. The same shape covers DNS
resolution, TLS handshakes, cold starts, a lock held elsewhere, and garbage collection pauses,
all of them are gaps between spans rather than long spans.

**The discriminating test:** measure end to end, then subtract the parts you can account for. The
unexplained remainder is where the bug is. If timings do not add up, the missing time *is* the
finding: stop explaining it away.

---

## Using these

Do not pattern-match a symptom to a case here and call it diagnosed. The value is in the
discriminating tests: each one is cheap, and each one splits the field rather than confirming a
favourite. Run the cheapest one first.

Register whichever you are testing as a real hypothesis, with its refutation:

```bash
bash "$FORGE/skills/untangle/scripts/evidence.sh" hypothesis "the running process predates the deploy" \
  "then a boot-time SHA log would show the new commit, add one and restart"
```

And when one of these turns out to be the answer, the last question is worth asking out loud:
**what made the wrong assumption invisible?** A stale cache that nothing announces, a boundary
with no logging, an env difference nobody documents. That answer is usually a smaller and more
durable fix than the bug itself, and it belongs under `## Open` in the brief if you are not
fixing it now.
