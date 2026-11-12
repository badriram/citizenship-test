#!/usr/bin/env python3
"""Flag governors who took office after data/governors.json was last updated.

Wikidata is not trusted as a source (it still lists governors who left office in 2025),
only as a tripwire: a state is reported when Wikidata records a governor whose term
started after our file's `updated` date and who is not the person we list. A human
then verifies and edits data/governors.json by hand.

Prints a Markdown report and exits 1 when something needs a look, 0 otherwise.
"""
import datetime
import json
import sys
import unicodedata
import urllib.parse
import urllib.request
from pathlib import Path

GOVERNORS_FILE = Path(__file__).resolve().parents[2] / "data" / "governors.json"

# People holding each state's "office held by head of government" (P1313, e.g. Governor of
# New Jersey) via their own "position held" (P39) statements, which are far better maintained
# than the state's head-of-government (P6) field.
QUERY = """
SELECT ?code ?govLabel ?start WHERE {
  ?state wdt:P31 wd:Q35657; wdt:P300 ?iso; wdt:P1313 ?office.
  BIND(STRAFTER(?iso, "US-") AS ?code)
  ?gov p:P39 ?st. ?st ps:P39 ?office; pq:P580 ?start.
  FILTER NOT EXISTS { ?st pq:P582 ?end }
  FILTER NOT EXISTS { ?st wikibase:rank wikibase:DeprecatedRank }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
}
"""


def last_name(name: str) -> str:
    folded = unicodedata.normalize("NFD", name).encode("ascii", "ignore").decode().lower()
    parts = [p for p in folded.replace(",", " ").split() if p.rstrip(".") not in ("jr", "sr", "ii", "iii", "iv")]
    return parts[-1] if parts else ""


def main() -> int:
    ours = json.loads(GOVERNORS_FILE.read_text())
    updated = ours["updated"]
    url = "https://query.wikidata.org/sparql?" + urllib.parse.urlencode({"query": QUERY})
    request = urllib.request.Request(url, headers={
        "Accept": "application/sparql-results+json",
        "User-Agent": "citizenship-test-governors-check/1.0 (https://github.com/badriram/citizenship-test)",
    })
    with urllib.request.urlopen(request, timeout=60) as response:
        rows = json.load(response)["results"]["bindings"]

    today = datetime.date.today().isoformat()
    findings = []
    for row in rows:
        code = row["code"]["value"]
        theirs = row["govLabel"]["value"]
        start = row["start"]["value"][:10]
        listed = ours["governors"].get(code)
        if start > updated and (listed is None or last_name(listed) != last_name(theirs)):
            # Governors-elect appear with their inauguration date; the answer stays the sitting
            # governor until then, so they are flagged as upcoming rather than as a correction.
            when = "upcoming" if start > today else "in office"
            findings.append(f"| {code} | {listed or '(missing)'} | {theirs} | {start} ({when}) |")

    if not findings:
        print(f"No governor changes on Wikidata since {updated}.")
        return 0
    print(f"Wikidata records governors who took office after `data/governors.json` was updated ({updated}).")
    print("Verify each against the state's official site. Change the file for an upcoming")
    print("governor only once they are sworn in.\n")
    print("| State | We list | Wikidata | Took office |\n|---|---|---|---|")
    print("\n".join(sorted(findings)))
    return 1


if __name__ == "__main__":
    sys.exit(main())
