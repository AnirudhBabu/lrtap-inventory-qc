"""Draws the figures in docs/figures from the results of the DuckDB run.

Run after scripts/crosscheck_duckdb.py, which leaves its tables in
data/results/crosscheck.duckdb:

    uv run scripts/make_figures.py

Figures:
  docs/figures/qc05_tolerance.png  how far each national total is from the sum
                                   of its sectors, and what a guessed tolerance
                                   would have hidden (docs/FINDINGS.md, QC05)
  data/results/qc05_tolerance_post.png
                                   the same, titled in the first person for a
                                   personal post; not part of the repository
"""

import random
import sys
from pathlib import Path

import duckdb
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.ticker import FixedLocator, NullLocator  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
RESULTS = ROOT / "data/results/crosscheck.duckdb"
OUT = ROOT / "docs/figures"

GUESS = 1e-3       # the first, guessed tolerance: 0.1 %
CALIBRATED = 1e-5  # the tolerance set from the data: 0.001 % (db/02_config.sql)

# Colours: the validated default palette of the dataviz method (slots 1 and 2,
# checked for colour-vision deficiency), with its light-mode text and surface.
SURFACE = "#fcfcfb"
TEXT = "#0b0b0b"
TEXT_2 = "#52514e"
TEXT_3 = "#8a8984"
BAND = "#e9e8e4"
FOUND = "#2a78d6"
HIDDEN = "#eb6834"


def relative_gaps(con):
    """|sum of sectors - national total| / |total|, for every non-zero total."""
    return [r for (r,) in con.execute("""
        with total as (
            select country_code, pollutant_code, year, value as total
              from emission
             where sector_code = 'NATIONAL TOTAL' and value is not null and value <> 0),
        sector_sum as (
            select e.country_code, e.pollutant_code, e.year, sum(e.value) as s
              from emission e join ref_sector r using (sector_code)
             where r.role = 'SECTOR'
             group by all)
        select abs(coalesce(s, 0) - total) / abs(total)
          from total left join sector_sum using (country_code, pollutant_code, year)
    """).fetchall()]


def pct(x):
    return f"{x * 100:g} %"


def qc05_tolerance(gaps, path, title, guess_label):
    rounding = [g for g in gaps if g <= CALIBRATED]
    real = sorted(g for g in gaps if g > CALIBRATED)
    hidden = [g for g in real if g <= GUESS]
    found = [g for g in real if g > GUESS]

    plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 11})
    fig = plt.figure(figsize=(6, 6), dpi=200, facecolor=SURFACE)
    ax = fig.add_axes([0.07, 0.24, 0.89, 0.40], facecolor=SURFACE)

    lo, hi = 1e-7, 1e-1
    ax.set_xscale("log")
    ax.set_xlim(lo, hi)
    ax.set_ylim(-1, 1)

    # Rounding: far too many totals to draw one by one, so one labelled band.
    ax.axvspan(lo, CALIBRATED, color=BAND, lw=0, zorder=0)
    ax.text(10 ** ((-7 + -5) / 2), 0, f"{len(rounding):,}\ntotals\nmatch to\nrounding",
            ha="center", va="center", color=TEXT_2, fontsize=10.5, linespacing=1.3)

    # Each total that does not match: one dot, spread vertically so none hide.
    rng = random.Random(7)
    for xs, colour in ((hidden, HIDDEN), (found, FOUND)):
        ax.scatter(xs, [rng.uniform(-0.75, 0.75) for _ in xs], s=22, color=colour,
                   edgecolors=SURFACE, linewidths=0.8, zorder=3)

    # The two tolerances.
    ax.axvline(CALIBRATED, color=TEXT, lw=1.4, zorder=2)
    ax.axvline(GUESS, color=TEXT, lw=1.4, ls=(0, (4, 3)), zorder=2)
    ax.text(CALIBRATED, 1.06, "set from the data\n0.001 %", transform=ax.get_xaxis_transform(),
            ha="center", va="bottom", color=TEXT, fontsize=9.5, linespacing=1.25)
    ax.text(GUESS, 1.06, f"{guess_label}\n0.1 %", transform=ax.get_xaxis_transform(),
            ha="center", va="bottom", color=TEXT, fontsize=9.5, linespacing=1.25)

    ax.xaxis.set_major_locator(FixedLocator([1e-6, 1e-5, 1e-4, 1e-3, 1e-2, 1e-1]))
    ax.xaxis.set_minor_locator(NullLocator())
    ax.set_xticklabels([pct(x) for x in (1e-6, 1e-5, 1e-4, 1e-3, 1e-2, 1e-1)])
    ax.tick_params(axis="x", colors=TEXT_2, labelsize=9, length=0, pad=6)
    ax.set_yticks([])
    for side in ("top", "left", "right"):
        ax.spines[side].set_visible(False)
    ax.spines["bottom"].set_color(TEXT_3)
    ax.set_xlabel("Gap between a national total and the sum of its sectors (log scale)",
                  color=TEXT_2, fontsize=9.5, labelpad=8)

    fig.text(0.07, 0.95, title,
             ha="left", va="top", color=TEXT, fontsize=17, fontweight="bold", linespacing=1.2)
    fig.text(0.07, 0.825,
             "National emission totals vs. the sum of their sectors,\n"
             f"{len(gaps):,} non-zero totals, 32 European countries, 1990–2024",
             ha="left", va="top", color=TEXT_2, fontsize=10.5, linespacing=1.35)

    # Legend as sentences, each led by its dot, so colour is never the only cue.
    for y, colour, label in (
        (0.135, FOUND, f"{len(found)} totals off by more than 0.1 %: caught either way"),
        (0.095, HIDDEN, f"{len(hidden)} totals off by 0.001–0.1 %: missed by the guess"),
    ):
        fig.text(0.07, y, "●", color=colour, fontsize=13, va="center")
        fig.text(0.11, y, label, color=TEXT, fontsize=10, va="center")
    fig.text(0.07, 0.05,
             f"All {len(real)} are PM10, in six countries, total always above its sectors.",
             color=TEXT_2, fontsize=9.5, va="center")
    fig.text(0.07, 0.018, "Data: EEA, LRTAP Convention emissions 2026 (CC BY 4.0) · "
             "github.com/AnirudhBabu/lrtap-inventory-qc",
             color=TEXT_3, fontsize=7.5, va="center")

    fig.savefig(path, facecolor=SURFACE)
    plt.close(fig)
    return len(rounding), len(hidden), len(found)


def main():
    if not RESULTS.exists():
        sys.exit(f"{RESULTS.relative_to(ROOT)} not found: run scripts/crosscheck_duckdb.py first")
    con = duckdb.connect(str(RESULTS), read_only=True)
    OUT.mkdir(parents=True, exist_ok=True)
    gaps = relative_gaps(con)
    for path, title, guess_label in (
        (OUT / "qc05_tolerance.png",
         "A guessed tolerance would have\nhidden part of a real pattern", "first guess"),
        (ROOT / "data/results/qc05_tolerance_post.png",
         "My first guess would have\nhidden part of a real pattern", "my first guess"),
    ):
        rounding, hidden, found = qc05_tolerance(gaps, path, title, guess_label)
        print(f"wrote {path.relative_to(ROOT)}: {rounding:,} rounding, {hidden} hidden, {found} found")


if __name__ == "__main__":
    main()
