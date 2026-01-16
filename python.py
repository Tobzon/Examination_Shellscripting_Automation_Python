#!/usr/bin/env python3
import csv
import sys
from collections import Counter, defaultdict
from pathlib import Path
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from datetime import datetime

# Förväntad CSV-rapport från Windows-scriptet
CSV_PATH = Path("SecurityReport.csv")

# Loggfil från Linux-scriptet
LOG_PATH = Path("logs.log")

# ===== FÄRGER =====
RED     = "\033[31m"
GREEN   = "\033[32m"
YELLOW  = "\033[33m"
CYAN    = "\033[36m"
MAGENTA = "\033[35m"
RESET   = "\033[0m"

# Skriver ut en tydlig sektionsrubrik
def section(title):
    print(f"\n{CYAN}{'='*50}{RESET}")
    print(f"{CYAN}{title}{RESET}")
    print(f"{CYAN}{'='*50}{RESET}")

def ok(msg):    print(f"{GREEN}[OK]{RESET} {msg}")
def warn(msg):  print(f"{YELLOW}[VARNING]{RESET} {msg}")
def fail(msg):  print(f"{RED}[FEL]{RESET} {msg}")
def info(msg):  print(f"{MAGENTA}[INFO]{RESET} {msg}")


# Läser in CSV, avslutar programmet om CSV saknas
def read_csv():
    if not CSV_PATH.exists():
        fail(f"CSV-filen saknas: {CSV_PATH}")
        sys.exit(1)

    rows = []
    with open(CSV_PATH, encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        rows.extend(reader)

    ok(f"Windows logg inläst ({len(rows)} rader)")
    return rows


# Läser Linux-loggfilen
def read_log():
    if not LOG_PATH.exists():
        warn("Loggfil saknas hoppar över logganalys")
        return []

    with open(LOG_PATH, encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()

    ok(f"Linux logg inläst ({len(lines)} rader)")
    return lines

# Analyserar Windows-resultat
def analyze_csv(rows):
    section("Analys av Windows")

    categories = Counter(row["Category"] for row in rows)
    risks = [r for r in rows if "Saknade" in r["SubCategory"] or "Brandvägg" in r["Category"]]

    for cat, count in categories.items():
        info(f"{cat}: {count} poster")

    if risks:
        warn(f"{len(risks)} potentiellt kritiska fynd hittades")
    else:
        ok("Inga uppenbara kritiska fynd hittades")

    return risks


# Analyserar Linux-loggen
def analyze_logs(lines):
    section("Analys av Linux")

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


# Skapar ett säkerhetsbetyg baserat på:
# - Windows-risker
# - Linux-fel
# - Linux-varningar
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

    return score


# Skapar en PDF-rapport med sammanfattning och statistik
def generate_pdf(csv_rows, risks, errors, warnings, score):
    pdf_path = Path("Security_Report.pdf")

    doc = SimpleDocTemplate(
        str(pdf_path),
        pagesize=A4,
        rightMargin=2*cm,
        leftMargin=2*cm,
        topMargin=2*cm,
        bottomMargin=2*cm
    )

    styles = getSampleStyleSheet()
    content = []

    # Titel
    content.append(Paragraph("<b>Säkerhetsrapport</b>", styles["Title"]))
    content.append(Spacer(1, 12))

    content.append(
        Paragraph(
            f"Genererad: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            styles["Normal"]
        )
    )
    content.append(Spacer(1, 12))

    # Sammanfattning
    content.append(Paragraph("<b>Sammanfattning</b>", styles["Heading2"]))
    content.append(Paragraph(f"Säkerhetspoäng: {score}/100", styles["Normal"]))
    content.append(Paragraph(f"Kritiska fynd (Windows): {len(risks)}", styles["Normal"]))
    content.append(Paragraph(f"Fel i Linux: {len(errors)}", styles["Normal"]))
    content.append(Paragraph(f"Varningar i Linux: {len(warnings)}", styles["Normal"]))
    content.append(Spacer(1, 12))

    # CSV-statistik
    content.append(Paragraph("<b>Windows – kategorier</b>", styles["Heading2"]))
    categories = Counter(row["Category"] for row in csv_rows)
    for cat, count in categories.items():
        content.append(Paragraph(f"- {cat}: {count}", styles["Normal"]))

    content.append(Spacer(1, 12))

    # Lista kritiska fynd
    if risks:
        content.append(Paragraph("<b>Kritiska fynd</b>", styles["Heading2"]))
        for r in risks:
            content.append(
                Paragraph(
                    f"{r['Category']} | {r['SubCategory']} | {r['Detail']}",
                    styles["Normal"]
                )
            )

     # Skapar PDF-filen
    doc.build(content)

    print(f"\n[OK] PDF genererad: {pdf_path.resolve()}")


# Programstart
def main():
    section("SAMMANSLAGEN SÄKERHETSRAPPORT")

    csv_rows = read_csv()
    log_lines = read_log()

    risks = analyze_csv(csv_rows)
    errors, warnings = analyze_logs(log_lines)

    score = summary(risks, errors, warnings)

    generate_pdf(csv_rows, risks, errors, warnings, score)

    section("Rapport klar")

# Startpunkt för scriptet
if __name__ == "__main__":
    main()
