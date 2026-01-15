#bearbeta säkerhetsdata, exempelvis:
#processlistor
#loggfiler
#nätverksdata
#API-anrop mot en central säkerhetsplattform
#producera en analys, t.ex.:
#identifiering av anomalier
#sammanställning av risker
#generering av en rapport
#följa strukturerad kodstandard med funktioner och tydlig dokumentation


#!/usr/bin/env python3
import csv
import sys
from collections import Counter, defaultdict
from pathlib import Path

CSV_PATH = Path("SecurityReport.csv")
LOG_PATH = Path("logs.log")

# ===== FÄRGER =====
RED     = "\033[31m"
GREEN   = "\033[32m"
YELLOW  = "\033[33m"
CYAN    = "\033[36m"
MAGENTA = "\033[35m"
RESET   = "\033[0m"

def section(title):
    print(f"\n{CYAN}{'='*50}{RESET}")
    print(f"{CYAN}{title}{RESET}")
    print(f"{CYAN}{'='*50}{RESET}")

def ok(msg):    print(f"{GREEN}[OK]{RESET} {msg}")
def warn(msg):  print(f"{YELLOW}[VARNING]{RESET} {msg}")
def fail(msg):  print(f"{RED}[FEL]{RESET} {msg}")
def info(msg):  print(f"{MAGENTA}[INFO]{RESET} {msg}")

# =========================
# Läs CSV
# =========================
def read_csv():
    if not CSV_PATH.exists():
        fail(f"CSV-filen saknas: {CSV_PATH}")
        sys.exit(1)

    rows = []
    with open(CSV_PATH, encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        rows.extend(reader)

    ok(f"CSV inläst ({len(rows)} rader)")
    return rows

# =========================
# Läs logg
# =========================
def read_log():
    if not LOG_PATH.exists():
        warn("Loggfil saknas hoppar över logganalys")
        return []

    with open(LOG_PATH, encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()

    ok(f"Logg inläst ({len(lines)} rader)")
    return lines

# =========================
# CSV-analys
# =========================
def analyze_csv(rows):
    section("Analys av CSV-data")

    categories = Counter(row["Category"] for row in rows)
    risks = [r for r in rows if "Saknade" in r["SubCategory"] or "Brandvägg" in r["Category"]]

    for cat, count in categories.items():
        info(f"{cat}: {count} poster")

    if risks:
        warn(f"{len(risks)} potentiellt kritiska fynd hittades")
    else:
        ok("Inga uppenbara kritiska fynd hittades")

    return risks

# =========================
# Logg-analys
# =========================
def analyze_logs(lines):
    section("Analys av loggdata")

    errors = [l for l in lines if "FEL" in l]
    warnings = [l for l in lines if "VARNING" in l]

    if errors:
        fail(f"{len(errors)} fel hittades i loggfilen")
    else:
        ok("Inga fel i loggfilen")

    if warnings:
        warn(f"{len(warnings)} varningar hittades i loggfilen")
    else:
        ok("Inga varningar i loggfilen")

    return errors, warnings

# =========================
# Sammanfattning
# =========================
def summary(risks, errors, warnings):
    section("Samlad bedömning")

    score = 100
    score -= len(risks) * 10
    score -= len(errors) * 15
    score -= len(warnings) * 5

    score = max(score, 0)

    if score >= 80:
        ok(f"Säkerhetsnivå: GOD ({score}/100)")
    elif score >= 50:
        warn(f"Säkerhetsnivå: MEDEL ({score}/100)")
    else:
        fail(f"Säkerhetsnivå: LÅG ({score}/100)")

# =========================
# MAIN
# =========================
def main():
    section("SAMMANSLAGEN SÄKERHETSRAPPORT")

    csv_rows = read_csv()
    log_lines = read_log()

    risks = analyze_csv(csv_rows)
    errors, warnings = analyze_logs(log_lines)

    summary(risks, errors, warnings)

    section("Rapport klar")

if __name__ == "__main__":
    main()
