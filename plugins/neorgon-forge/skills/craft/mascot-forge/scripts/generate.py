#!/usr/bin/env python3
"""Generate mascot art through the Gemini image API.

    # a fresh design, four candidates
    python3 generate.py --prompt-file brief.txt --out tmp/base --count 4

    # a variation edited from an existing frame
    python3 generate.py --prompt "..." --ref images/mascot/idle.png \
        --out tmp/blink.png

Run from the target project's root: --out and --ref are resolved against the
cwd, not against this script.

Reads GEMINI_API_KEY from the environment, falling back to .env. The key is
never printed. Pass --ref to send reference images along with the prompt, which
is what keeps a character on-model across frames.
"""

import argparse
import base64
import json
import mimetypes
import sys
import urllib.error
import urllib.request
from pathlib import Path

from keys import read_key

ENDPOINT ="https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
DEFAULT_MODEL = "gemini-3-pro-image"


def api_key():
    return read_key("GEMINI_API_KEY", "SEKILIST_GEMINI_API_KEY")


def part_for(path):
    mime = mimetypes.guess_type(path)[0] or "image/png"
    data = base64.b64encode(Path(path).read_bytes()).decode()
    return {"inline_data": {"mime_type": mime, "data": data}}


def generate(model, prompt, refs, aspect):
    parts = [part_for(ref) for ref in refs] + [{"text": prompt}]
    body = {
        "contents": [{"role": "user", "parts": parts}],
        "generationConfig": {
            "responseModalities": ["IMAGE"],
            "imageConfig": {"aspectRatio": aspect},
        },
    }

    request = urllib.request.Request(
        ENDPOINT.format(model=model) + f"?key={api_key()}",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=300) as response:
            payload = json.load(response)
    except urllib.error.HTTPError as error:
        detail = error.read().decode()[:600]
        sys.exit(f"HTTP {error.code} from {model}: {detail}")

    candidates = payload.get("candidates") or []
    if not candidates:
        sys.exit(f"no candidates returned: {json.dumps(payload)[:400]}")

    images, notes = [], []
    for part in candidates[0].get("content", {}).get("parts", []):
        blob = part.get("inlineData") or part.get("inline_data")
        if blob:
            images.append(base64.b64decode(blob["data"]))
        elif part.get("text"):
            notes.append(part["text"])

    if not images:
        reason = candidates[0].get("finishReason", "unknown")
        sys.exit(f"no image in response (finishReason={reason}) {' '.join(notes)[:300]}")
    return images, notes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--prompt")
    group.add_argument("--prompt-file", type=Path)
    parser.add_argument("--ref", action="append", default=[], help="reference image, repeatable")
    parser.add_argument("--out", required=True, help="output file, or directory when --count > 1")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--aspect", default="1:1")
    parser.add_argument("--count", type=int, default=1)
    args = parser.parse_args()

    prompt = args.prompt if args.prompt else args.prompt_file.read_text()
    out = Path(args.out)

    for index in range(args.count):
        images, notes = generate(args.model, prompt, args.ref, args.aspect)
        for offset, blob in enumerate(images):
            if args.count > 1 or len(images) > 1:
                out.mkdir(parents=True, exist_ok=True)
                suffix = f"{index + 1:02d}" + (f"-{offset}" if offset else "")
                path = out / f"{out.name}-{suffix}.png"
            else:
                out.parent.mkdir(parents=True, exist_ok=True)
                path = out
            path.write_bytes(blob)
            print(f"{path}  {len(blob) / 1024:.0f} KB")
        for note in notes:
            print(f"  note: {note.strip()[:200]}")


if __name__ == "__main__":
    main()
