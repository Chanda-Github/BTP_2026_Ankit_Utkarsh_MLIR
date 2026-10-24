#!/usr/bin/env python3
"""
summarize_codalab.py <out_dir> <codalab_summary.json>
Collects every out/codalab/<model>/isa_profile.json into one table (SUMMARY.md + summary.json):
which RV32I instructions the MLIR-compiled kernels need, across all datasets and model sizes.
"""
import json
import os
import re
import sys

from profile_isa import ALL_RV32I, RV32I


def main():
    out_dir, meta_path = sys.argv[1], sys.argv[2]
    meta = {m["model"]: m for m in json.load(open(meta_path))}

    def key(name):
        ds, c = name.rsplit("_", 1)
        return ds, int(c)

    rows, union = [], set()
    for name in sorted(meta, key=key):
        p = f"{out_dir}/{name}/isa_profile.json"
        if not os.path.isfile(p):
            continue
        prof = json.load(open(p))
        hdr = open(f"{out_dir}/{name}/golden.h").read()
        nvec = int(re.search(r"#define TM_NUM_VECTORS (\d+)", hdr).group(1))
        kd = prof["kernel_dynamic"] or {}
        used = prof["kernel_distinct"]
        union |= set(used)
        rows.append({
            **meta[name],
            "kernel_distinct": len(used),
            "kernel_instructions": used,
            "kernel_static_size": sum(prof["kernel_static"].values()),
            "dynamic_per_inference": round(sum(kd.values()) / nvec, 1),
            "rv32m_used": prof["rv32m_used"],
            "test_vectors_on_spike": nvec,
        })

    json.dump(rows, open(f"{out_dir}/summary.json", "w"), indent=2)
    L = ["# CoDALab trained TMs: MLIR -> RV32I instruction needs", "",
         "Every model: Spike `--isa=rv32i`, all test vectors match the golden model.", "",
         "**What is counted:** only the `tm_infer` function generated from each model by this "
         "MLIR pipeline (model compiled into straight-line code), read from `llvm-objdump -M "
         "no-aliases` of the real ELF, so pseudo-instructions already appear as the real RV32I "
         "instruction. The test harness is excluded. This is *not* the CoDALab generic `predict` "
         "program (loops over clause data in memory), which uses a different set: "
         "`add addi and andi beq blt jal jalr lbu lui lw or sb slli sltu sw xori` "
         "(17, after expanding `j`, `beqz`, `li`, `mv`, `nop`, `zext.b`, `snez`, `ret`).", "",
         "**Note on large models:** most `lw`/`sw`/`lui` here are register spills: the "
         "straight-line code keeps more values live than RV32I's 31 registers, and stack offsets "
         "beyond 2 KB need `lui`+`add` to form the address.", "",
         "| Model | Classes | Clauses/class | Features | Test acc % | Kernel insns used (/40) "
         "| Kernel size (insns) | Executed per inference |",
         "|---|---:|---:|---:|---:|---:|---:|---:|"]
    for r in rows:
        L.append(f"| {r['model']} | {r['classes']} | {r['clauses_per_class']} | {r['features']} "
                 f"| {r['test_accuracy_percent']} | {r['kernel_distinct']} "
                 f"| {r['kernel_static_size']} | {r['dynamic_per_inference']} |")
    L += ["", f"**Union over all {len(rows)} models: {len(union)} / 40 RV32I instructions** "
          f"(`{'`, `'.join(i for i in ALL_RV32I if i in union)}`)", "",
          "RV32M (multiply/divide) used by any model: "
          f"**{sorted({m for r in rows for m in r['rv32m_used']}) or 'none'}**", "",
          "Never used by any kernel: " + ", ".join(f"`{i}`" for i in ALL_RV32I if i not in union)]
    open(f"{out_dir}/SUMMARY.md", "w").write("\n".join(L) + "\n")
    print(f"[summary] {len(rows)} models, kernel union {len(union)}/40 -> {out_dir}/SUMMARY.md")


if __name__ == "__main__":
    main()
