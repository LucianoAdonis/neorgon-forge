# Shape vocabulary

The classifier's shapes, with a synthetic-substitute recipe per shape. The recipe matters
as much as the pattern: a fixture must satisfy the shape *and* read as obviously fake, so
that a reviewer never has to wonder whether it is live. "Reads as fake" is achieved by
hex-speak words and all-zero runs, never by truncation — a truncated real value is a
partial disclosure, not a sample.

| Shape | Detection | Synthetic substitute |
|---|---|---|
| `hex-32` | `[0-9a-f]{32}` case-insensitive, word-bounded | `00000000feed0000face0000cafe0000` |
| `hex-40` | `[0-9a-f]{40}` | `0000000000000000deadbeef0000000000000000` |
| `hex-64` | `[0-9a-f]{64}` | zero-pad `cafefeedfacedead` to 64 |
| `jwt` | `eyJ` + base64url `.` base64url `.` base64url | header/payload encoding `{"fake":true}`, signature `AAAA…` |
| `pem-private-key` | `-----BEGIN (RSA \|EC \|OPENSSH )?PRIVATE KEY-----` | generate a throwaway key pair for the test and label it |
| `credentials-in-url` | `://user:pass@host` — any scheme | `mongodb://fakeuser:fakepass@db.invalid:27017` (`.invalid` TLD cannot resolve) |
| `aws-access-key` | `AKIA[0-9A-Z]{16}` | `AKIAFAKEFAKEFAKEFAKE` |
| `github-token` | `gh[pousr]_[A-Za-z0-9]{36,}` | `ghp_` + 36 `x` |
| `slack-token` | `xox[baprs]-[A-Za-z0-9-]+` | `xoxb-0000000000-fake` |
| `openai-style` | `sk-[A-Za-z0-9_-]{20,}` | `sk-fake` + 20 `0` |
| `opaque-long` | ≥20 chars, mixed classes, entropy high for its length, key name suggests secret | `FAKE_` + repeated `0000` to length |

Provider prefixes (AWS `AKIA`, GitHub `ghp_`, Slack `xox`) are the strongest signals in
the table: they are deny-by-name at the value level, and no family exclusion may outrank
them (see Step 2 of the skill).

Entropy heuristics earn their keep on `opaque-long` only. Everything above it is a fixed
pattern; prefer the fixed pattern wherever one exists, because an entropy check has a
false-positive rate and a pattern does not.

**Keep the `jwt` pattern anchored.** Unanchoring it to catch tokens embedded mid-string looks
like a safe widening and is not: `eyJ` is simply base64 for `{"`, so any base64-encoded JSON —
config blobs, serialized state — starts with it. A field probe of real production data showed
the unanchored version would have started redacting ordinary configuration. Probe before
widening any pattern; a confident theoretical improvement is still theoretical.

## PII vocabulary, for the analytics/error-reporting domains

Same architecture, different table: email (`@` + TLD shape), phone (E.164 and local
digit-runs), government-ID formats for the jurisdictions the product serves, street
addresses (number + street-word), IP addresses when policy treats them as PII. Synthetic
substitutes: RFC 2606 domains (`user@example.com`), `+1 555` numbers, and the
jurisdiction's published test IDs where they exist.
