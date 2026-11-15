"""Build the bundled Quote-of-the-Day collection shared by iOS and Android.

Sources (attribution shown in-app under Settings → About → Quote sources):
  - vinitshahdeo/inspirational-quotes (MIT)        data/data.json
  - AtaGowani/daily-motivation (Apache-2.0)         src/data/quotes.json
  - Abirate/english_quotes on Hugging Face (CC BY 4.0) quotes.jsonl — motivational tags only

Usage:
  python Scripts/build_quotes.py <vinit.json> <ata.json> <hf.jsonl> <out.json>

Output: [{"t": text, "a": author}, ...] in a stable order (both apps shuffle it with the same seed).
"""

import json
import re
import sys
import unicodedata

vinit_path, ata_path, hf_path, out_path = sys.argv[1:5]

KEEP_TAGS = {
    "inspirational", "inspiration", "inspirational-quotes", "inspire", "inspiring", "inspirational-life",
    "inspirational-attitude", "motivational", "motivation", "motivational-quotes", "success", "courage",
    "strength", "optimism", "optimistic", "positive", "positive-thinking", "positive-life", "positive-affirmation",
    "hope", "dreams", "change", "life-lessons", "wisdom", "perseverance", "determination", "persistence",
    "effort", "work", "hard-work", "discipline", "goals", "achievement", "self-improvement", "growth",
    "confidence", "self-confidence", "attitude", "action", "failure", "fear", "challenge", "habits",
    "excellence", "purpose", "potential", "health", "fitness", "patience", "resilience", "focus",
}
SKIP_TAGS = {
    "love", "romance", "death", "religion", "god", "faith", "christianity", "bible", "sex", "humor", "funny",
    "books", "reading", "writing", "poetry", "politics", "war", "suicide", "drugs", "alcohol", "women", "men",
    "marriage", "relationships", "loneliness", "sadness", "pain", "depression", "heartbreak",
}
BANNED_WORDS = re.compile(r"\b(damn|hell|shit|fuck|sex|kill|suicide|god|jesus|bitch)\b", re.I)


def clean(text: str) -> str:
    text = unicodedata.normalize("NFKC", text)
    text = text.replace("â€™", "'").replace("�", "'")
    text = re.sub(r"\s+", " ", text).strip()
    text = text.strip("“”\"' ")
    text = text.replace("’", "'").replace("‘", "'").replace("“", '"').replace("”", '"').replace("―", "—")
    return text


def author_of(a: str) -> str:
    a = clean(a or "").split(",")[0].strip()
    return a or "Unknown"


def acceptable(text: str) -> bool:
    return 20 <= len(text) <= 200 and not BANNED_WORDS.search(text) and text.count('"') % 2 == 0


quotes, seen = [], set()


def add(text, author):
    t = clean(text)
    key = re.sub(r"[^a-z0-9]", "", t.lower())
    if not acceptable(t) or key in seen:
        return
    seen.add(key)
    quotes.append({"t": t, "a": author_of(author)})


for row in json.load(open(vinit_path, encoding="utf-8-sig")):
    add(row.get("text", ""), row.get("from", ""))
for row in json.load(open(ata_path, encoding="utf-8-sig")):
    add(row.get("quote", ""), row.get("author", ""))
for line in open(hf_path, encoding="utf-8"):
    if not line.strip():
        continue
    row = json.loads(line)
    tags = set(row.get("tags") or [])
    if tags & KEEP_TAGS and not tags & SKIP_TAGS:
        add(row.get("quote", ""), row.get("author", ""))

with open(out_path, "w", encoding="utf-8", newline="\n") as f:
    json.dump(quotes, f, ensure_ascii=False, separators=(",", ":"))
    f.write("\n")
print(f"{len(quotes)} quotes -> {out_path}")
