#!/usr/bin/env python3
"""
exec_time_sweep.py -- execution time vs #clauses (the paper's Fig. 5), from cycle-accurate RTL runs
=================================================================================================
For every dataset x clauses-per-class x T1/T2 x core (R1, R2):
  * MLIR flow : generate the memory images (same model, same input sample as the paper's Tests/
                image), run them on the lab's R1/R2 Verilog, read cycles, class and votes[]
  * paper flow: run the paper's own Tests/ images on the same Verilog (optional, --no-paper skips)
  * time      = cycles x clock period, with the paper's periods: R1 14 ns, R2 12 ns
                (post-synthesis timing in the ISVLSI'26 paper; the Vivado testbench prints
                 Execution Time = cycles x CLK_PERIOD the same way)
Every run's class (and votes) is checked against the golden model computed from the clauses.

Usage:
    python3 exec_time_sweep.py <codalab_repo_root> [--datasets statlog,gesture,gas,emg]
           [--clauses 50,100,150,200,250,300] [--jobs N] [--no-paper]
Writes out/exectime/{results.csv, results.json, TABLE.md, fig5_exec_time.png, .pdf}
"""
import argparse
import concurrent.futures as cf
import csv
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TRACK = os.path.dirname(HERE)
sys.path.insert(0, TRACK)
sys.path.insert(0, HERE)
from import_codalab import decode_model  # noqa: E402
from compare_with_paper import (paper_t1_layout, paper_t2_layout, golden, run_rtl,  # noqa: E402
                                symbol, sh)

PERIOD_NS = {"r1": 14.0, "r2": 12.0}
DATASET_TITLE = {"statlog": "Statlog", "gesture": "Gesture", "gas": "Gas", "emg": "EMG",
                 "har": "HAR", "sports": "Sports", "iris": "Iris", "mammography": "Mammography"}


def ensure_model(root, ds, C):
    path = os.path.join(TRACK, "models", "codalab", f"{ds}_{C}.json")
    if not os.path.isfile(path):
        r = sh(f'python3 "{TRACK}/import_codalab.py" "{root}" "{TRACK}/models/codalab" {ds}/{C}')
        if r.returncode:
            raise SystemExit(r.stdout + r.stderr)
    return path


def prepare(root, ds, C, var, out):
    """Build the MLIR images for this point; returns everything the runs need."""
    std = os.path.join(root, "Tests", ds, str(C), "memoryd.mem")
    K, Cn, L, classes = decode_model(std)
    tests = os.path.join(root, "Tests", ds if var == "t1" else ds + "_opt", str(C))
    lay = paper_t1_layout(os.path.join(tests, "memoryd.mem")) if var == "t1" else \
        paper_t2_layout(os.path.join(tests, "memoryd.mem"), L)
    lit = lay["lit"]
    model_path = ensure_model(root, ds, C)
    rows = [[int(ch) for ch in r] for r in json.load(open(model_path))["test_inputs"]]
    sample = rows.index(lit[: L // 2])
    work = os.path.join(out, f"{ds}_{C}_{var}")
    r = sh(f'"{HERE}/run_core_flow.sh" "{model_path}" {var} "{work}"',
           {"SAMPLE": str(sample), "SKIP_SPIKE": "1"})
    if r.returncode:
        raise SystemExit(f"{ds}/{C}/{var}: build failed\n{r.stdout}{r.stderr}")
    g_votes, g_class = golden(classes, Cn, lit)
    s_votes, s_class = golden(classes, Cn, lit, paper_swap=True)
    return {"ds": ds, "C": C, "var": var, "K": K, "work": work, "tests": tests, "lay": lay,
            "sample": sample, "golden": (g_votes, g_class), "swap": (s_votes, s_class)}


def run_point(root, p, core, flow):
    if flow == "mlir":
        d = os.path.join(p["work"], core)
        vaddr = symbol(os.path.join(p["work"], f"core_{core}.elf"), "tm_votes")
        res = run_rtl(root, core, d, {"DUMP_ADDR": str(vaddr), "DUMP_WORDS": str(p["K"]),
                                      "MAX_CYCLES": "400000000"})
    else:
        d = os.path.join(p["work"], f"paper_{core}")
        os.makedirs(d, exist_ok=True)
        for f in ("memoryi.mem", "memoryd.mem"):
            with open(os.path.join(p["tests"], f)) as a, open(os.path.join(d, f), "w") as b:
                b.write(a.read())
        res = run_rtl(root, core, d, {"RESTART_STOP": "1", "DUMP_ADDR": str(p["lay"]["votes_addr"]),
                                      "DUMP_WORDS": str(p["K"]), "MAX_CYCLES": "400000000"})
    gv, gc = p["golden"]
    sv, sc = p["swap"]
    if res["result"] == gc and res["votes"] == gv:
        check = "golden"
    elif flow == "paper" and res["result"] == sc and res["votes"] == sv:
        check = "bge-swap"
    else:
        check = "MISMATCH"
    cyc = res["cycles"]
    return {"dataset": p["ds"], "clauses": p["C"], "tm": p["var"].upper(), "core": core.upper(),
            "flow": flow, "sample": p["sample"], "cycles": cyc,
            "time_ms": round(cyc * PERIOD_NS[core] * 1e-6, 6) if cyc else None,
            "class": res["result"], "golden_class": gc, "check": check}


def plot(rows, datasets, out):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.lines import Line2D

    # validated categorical palette (dataviz skill, light mode); markers carry identity too
    style = {("R1", "T1"): ("#2a78d6", "o"), ("R1", "T2"): ("#eb6834", "s"),
             ("R2", "T1"): ("#1baf7a", "^"), ("R2", "T2"): ("#eda100", "D")}
    flows = sorted({r["flow"] for r in rows}, key=lambda f: f != "mlir")
    n = len(datasets)
    cols = 2 if n == 4 else min(3, n)
    nrows = (n + cols - 1) // cols
    fig, axes = plt.subplots(nrows, cols, figsize=(4.2 * cols, 3.3 * nrows), squeeze=False)
    for ax, ds in zip(axes.flat, datasets):
        for (core, tm), (color, mk) in style.items():
            for flow in flows:
                pts = sorted((r["clauses"], r["time_ms"]) for r in rows
                             if r["dataset"] == ds and r["core"] == core and r["tm"] == tm
                             and r["flow"] == flow and r["time_ms"])
                if not pts:
                    continue
                xs, ys = zip(*pts)
                ax.plot(xs, ys, color=color, marker=mk, markersize=5, linewidth=2 if flow == "mlir" else 1.2,
                        linestyle="-" if flow == "mlir" else "--",
                        markerfacecolor=color if flow == "mlir" else "white", markeredgewidth=1.3)
        ax.set_yscale("log")
        ax.set_xticks(sorted({r["clauses"] for r in rows if r["dataset"] == ds}))
        ax.set_title(DATASET_TITLE.get(ds, ds), fontsize=11)
        ax.set_xlabel("#Clauses per class")
        ax.set_ylabel("Time (ms)")
        ax.grid(True, which="major", color="#d9d8d3", linewidth=0.6)
        ax.grid(True, which="minor", color="#ecebe7", linewidth=0.4)
        for s in ("top", "right"):
            ax.spines[s].set_visible(False)
    for ax in list(axes.flat)[n:]:
        ax.axis("off")
    handles = [Line2D([], [], color=c, marker=m, linewidth=2, label=f"Core:{k[0]}, TM:{k[1]}")
               for k, (c, m) in style.items()]
    if "paper" in flows:
        handles += [Line2D([], [], color="#555", linewidth=2, label="MLIR flow (solid)"),
                    Line2D([], [], color="#555", linewidth=1.2, linestyle="--", marker="o",
                           markerfacecolor="white", label="Paper flow (dashed)")]
    ncol = 3 if len(handles) > 4 else len(handles)
    fig.legend(handles=handles, loc="upper center", ncol=ncol, frameon=False,
               fontsize=9, bbox_to_anchor=(0.5, 1.0))
    fig.tight_layout(rect=(0, 0, 1, 0.90 if nrows > 1 else 0.82))
    for ext in ("png", "pdf"):
        fig.savefig(os.path.join(out, f"fig5_exec_time.{ext}"), dpi=200, bbox_inches="tight")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root")
    ap.add_argument("--datasets", default="statlog,gesture,gas,emg")
    ap.add_argument("--clauses", default="50,100,150,200,250,300")
    ap.add_argument("--variants", default="t1,t2")
    ap.add_argument("--cores", default="r1,r2")
    ap.add_argument("--no-paper", action="store_true")
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 2)
    ap.add_argument("--out", default=os.path.join(TRACK, "out", "exectime"))
    ap.add_argument("--replot", action="store_true", help="redraw the figure from results.json only")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    datasets = a.datasets.split(",")
    if a.replot:
        rows = json.load(open(os.path.join(a.out, "results.json")))
        plot(rows, [d for d in datasets if any(r["dataset"] == d for r in rows)], a.out)
        print(f"[sweep] redrew {a.out}/fig5_exec_time.png")
        return
    points = [(ds, int(c), v) for ds in datasets for c in a.clauses.split(",")
              for v in a.variants.split(",")]
    flows = ["mlir"] + ([] if a.no_paper else ["paper"])

    print(f"[sweep] building {len(points)} MLIR image sets ...", flush=True)
    with cf.ThreadPoolExecutor(a.jobs) as ex:
        prepared = list(ex.map(lambda t: prepare(a.root, *t, a.out), points))
    jobs = [(p, core, flow) for p in prepared for core in a.cores.split(",") for flow in flows]
    # longest first (T1, paper) so the pool stays busy
    jobs.sort(key=lambda j: (j[0]["var"] != "t1", j[2] != "paper", -j[0]["C"]))
    print(f"[sweep] {len(jobs)} RTL runs on {a.jobs} worker(s) ...", flush=True)
    rows = []
    with cf.ThreadPoolExecutor(a.jobs) as ex:
        for r in ex.map(lambda j: run_point(a.root, *j), jobs):
            rows.append(r)
            print(f"  {r['dataset']:<8}{r['clauses']:>4} {r['tm']} {r['core']} {r['flow']:<5} "
                  f"cycles {r['cycles']:>11,}  {r['time_ms']:>10.3f} ms  class {r['class']} [{r['check']}]",
                  flush=True)

    rows.sort(key=lambda r: (r["dataset"], r["tm"], r["core"], r["flow"], r["clauses"]))
    with open(os.path.join(a.out, "results.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    json.dump(rows, open(os.path.join(a.out, "results.json"), "w"), indent=2)

    # table: time in ms per point, MLIR vs paper
    idx = {(r["dataset"], r["clauses"], r["tm"], r["core"], r["flow"]): r for r in rows}
    T = ["# Execution time (ms) = RTL cycles x clock period (R1 14 ns, R2 12 ns)", "",
         "Each cell: MLIR flow / paper flow (speed-up). Same model, same input sample, same core.", ""]
    for ds in datasets:
        T += [f"## {DATASET_TITLE.get(ds, ds)}", "",
              "| Clauses | R1-T1 | R1-T2 | R2-T1 | R2-T2 |", "|---:|---|---|---|---|"]
        for c in sorted({r["clauses"] for r in rows if r["dataset"] == ds}):
            cells = []
            for core, tm in (("R1", "T1"), ("R1", "T2"), ("R2", "T1"), ("R2", "T2")):
                m = idx.get((ds, c, tm, core, "mlir"))
                p = idx.get((ds, c, tm, core, "paper"))
                if m and p and m["time_ms"] and p["time_ms"]:
                    cells.append(f"{m['time_ms']:.3f} / {p['time_ms']:.3f} ({p['time_ms'] / m['time_ms']:.1f}x)")
                elif m and m["time_ms"]:
                    cells.append(f"{m['time_ms']:.3f}")
                else:
                    cells.append("-")
            T.append(f"| {c} | " + " | ".join(cells) + " |")
        T.append("")
    bad = [r for r in rows if r["check"] == "MISMATCH"]
    from collections import Counter
    cnt = Counter((r["flow"], r["check"]) for r in rows)
    T.append("Result checks (class and every class vote read back from data memory): "
             + ", ".join(f"{f} runs = {c}: {n}" for (f, c), n in sorted(cnt.items()))
             + ". `bge-swap` = exactly what the hand-edited assembly computes after rewriting "
               "`bge x,y` as `blt y,x` (see compare_with_paper.py).")
    open(os.path.join(a.out, "TABLE.md"), "w").write("\n".join(T) + "\n")
    plot(rows, datasets, a.out)
    print(f"\n[sweep] {a.out}/fig5_exec_time.png, TABLE.md, results.csv"
          + (f"  -- {len(bad)} MISMATCH runs!" if bad else "  -- all results checked"))


if __name__ == "__main__":
    main()
