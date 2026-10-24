#!/usr/bin/env python3
"""
import_codalab.py
=================
Recovers trained multi-class Tsetlin Machine models from the data-memory images
(Tests/<dataset>/<clauses>/memoryd.mem) of the CoDALab BTP25_RISCVTsetlinMachine project,
and checks each recovered model against the real test set.

memoryd.mem layout (from DataMemory/create_memory_standard.cpp), one 32-bit hex word per line,
bytes little-endian within a word:
  byte 0   result            byte 4  num_classes
  byte 8   clauses/2         byte 12 clauses per class      byte 16 num_literals
  byte 20  literal values (one byte each)  ...  then:
           class pointer table  -> clause pointer table -> clause include bytes (num_literals each)
Literal order (TMU tm.py): [x_0 .. x_{F-1}, ~x_0 .. ~x_{F-1}]   (concatenated, not interleaved)
Clauses 0..C/2-1 of each class vote +1, clauses C/2..C-1 vote -1.
Inference (TM/standard.cpp): votes[i] = C + pos - neg; result = first class with the strictly
largest vote, starting from max 0 (ties -> lowest index).

Usage:
    python3 import_codalab.py <codalab_repo_root> <out_models_dir> [dataset/clauses ...]
    (no dataset list -> import every Tests/<dataset>/<clauses> that is not an *_opt variant)
"""
import json
import os
import sys

import numpy as np

MAX_TEST_VECTORS = 200   # test rows carried in each model file for the RISC-V run


def read_mem_bytes(path):
    data = bytearray()
    for line in open(path):
        line = line.strip()
        if line:
            data += int(line, 16).to_bytes(4, "little")
    return bytes(data)


def word(mem, addr):
    return int.from_bytes(mem[addr:addr + 4], "little")


def decode_model(mem_path):
    mem = read_mem_bytes(mem_path)
    n_classes, half, n_clauses, n_literals = (word(mem, a) for a in (4, 8, 12, 16))
    assert half == n_clauses // 2, "header inconsistent"
    lit_bytes = (n_literals + 3) // 4 * 4
    class_tbl = 20 + lit_bytes
    classes = []
    for i in range(n_classes):
        clause_tbl = word(mem, class_tbl + 4 * i)
        clauses = []
        for j in range(n_clauses):
            p = word(mem, clause_tbl + 4 * j)
            inc = mem[p:p + n_literals]
            assert len(inc) == n_literals and set(inc) <= {0, 1}, f"bad clause bytes at {p:#x}"
            clauses.append([k for k, b in enumerate(inc) if b])
        classes.append(clauses)
    return n_classes, n_clauses, n_literals, classes


def predict(classes, n_clauses, x):
    """Bit-exact Python port of predict() in TM/standard.cpp (literals concatenated)."""
    F = len(x)
    lit = np.concatenate([x, 1 - x])
    result, max_votes = 0, 0
    for i, clauses in enumerate(classes):
        v = n_clauses
        for j, inc in enumerate(clauses):
            if inc and all(lit[k] for k in inc):
                v += 1 if j < n_clauses // 2 else -1
        if v > max_votes:
            result, max_votes = i, v
    return result


def predict_batch(classes, n_clauses, X):
    """Vectorized form of predict(); identical semantics. Votes are always >= C/2 > 0, so the
    C++ 'first strictly larger than running max (start 0)' rule equals argmax (ties -> lowest)."""
    lit = np.concatenate([X, 1 - X], axis=1).astype(bool)
    votes = np.full((X.shape[0], len(classes)), n_clauses, dtype=np.int32)
    for i, clauses in enumerate(classes):
        for j, inc in enumerate(clauses):
            if inc:
                out = lit[:, inc].all(axis=1)
                votes[:, i] += np.where(out, 1 if j < n_clauses // 2 else -1, 0)
    return votes.argmax(axis=1)


def stored_literals(mem_path, n_literals):
    mem = read_mem_bytes(mem_path)
    return list(mem[20:20 + n_literals])


def main():
    root, out_dir = sys.argv[1], sys.argv[2]
    wanted = sys.argv[3:]
    if not wanted:
        for ds in sorted(os.listdir(f"{root}/Tests")):
            if ds.endswith("_opt") or not os.path.isdir(f"{root}/Tests/{ds}"):
                continue
            for c in sorted(os.listdir(f"{root}/Tests/{ds}"), key=lambda s: (len(s), s)):
                if os.path.isfile(f"{root}/Tests/{ds}/{c}/memoryd.mem"):
                    wanted.append(f"{ds}/{c}")
    os.makedirs(out_dir, exist_ok=True)

    print(f"{'model':<18}{'classes':>8}{'clauses':>8}{'features':>9}{'nonempty':>9}"
          f"{'avg lits':>9}{'test acc %':>11}")
    summary = []
    for item in wanted:
        ds, c = item.split("/")
        n_cls, n_cl, n_lit, classes = decode_model(f"{root}/Tests/{ds}/{c}/memoryd.mem")
        F = n_lit // 2
        X = np.load(f"{root}/Datasets/{ds}/X_test.npy", allow_pickle=False).astype(np.uint8)
        Y = np.load(f"{root}/Datasets/{ds}/Y_test.npy", allow_pickle=False)
        assert X.shape[1] == F, f"{item}: model has {F} features, dataset {X.shape[1]}"
        pred = predict_batch(classes, n_cl, X)
        # Cross-checks:
        #  1. vectorized evaluation == bit-exact C++ port on the first samples
        #  2. the literal vector stored in memoryd.mem is one of the real test rows
        #     (confirms literal order and that the file pairs with this dataset)
        #  3. if the CoDALab RTL simulation result is recorded (Tests/<ds>/expected_output.txt),
        #     our prediction on the stored sample equals it
        for t in range(min(20, len(X))):
            assert pred[t] == predict(classes, n_cl, X[t]), f"{item}: batch/port mismatch"
        stored = np.array(stored_literals(f"{root}/Tests/{ds}/{c}/memoryd.mem", n_lit))
        rows = np.where((np.concatenate([X, 1 - X], axis=1) == stored).all(axis=1))[0]
        assert len(rows), f"{item}: stored literals are not a test row (literal order?)"
        exp_file = next((f"{root}/Tests/{d}/expected_output.txt" for d in (ds, ds + "_opt")
                         if os.path.isfile(f"{root}/Tests/{d}/expected_output.txt")), None)
        if exp_file:
            expected = int(open(exp_file).read().split()[0])
            got = predict(classes, n_cl, stored[:F])
            assert got == expected, f"{item}: predicts {got} on stored sample, RTL gave {expected}"
        acc = 100.0 * float((pred == Y).mean())
        nonempty = [len(inc) for cl in classes for inc in cl if inc]
        avg = sum(nonempty) / max(1, len(nonempty))
        print(f"{item:<18}{n_cls:>8}{n_cl:>8}{F:>9}{len(nonempty):>9}{avg:>9.1f}{acc:>11.2f}")

        name = f"{ds}_{c}"
        model = {
            "format": "tm_multiclass_v1",
            "benchmark_name": name,
            "source": f"CoDALab BTP25_RISCVTsetlinMachine Tests/{ds}/{c}/memoryd.mem",
            "num_features": F,
            "num_classes": n_cls,
            "clauses_per_class": n_cl,
            "literal_order": "concat",          # literal k<F: x_k ; k>=F: ~x_{k-F}
            "polarity_rule": "first half +1, second half -1",
            "classes": classes,                 # classes[i][j] = included literal indices
            "test_accuracy_percent": round(acc, 2),
            # first test rows + this decoder's predictions, used as RISC-V test vectors;
            # emit_mlir.py recomputes them independently and checks the two agree
            "test_inputs": ["".join(map(str, r)) for r in X[:MAX_TEST_VECTORS]],
            "reference_predictions": [int(p) for p in pred[:MAX_TEST_VECTORS]],
        }
        with open(f"{out_dir}/{name}.json", "w") as f:
            json.dump(model, f)
        summary.append({"model": name, "classes": n_cls, "clauses_per_class": n_cl,
                        "features": F, "nonempty_clauses": len(nonempty),
                        "avg_literals_per_clause": round(avg, 2), "test_accuracy_percent": round(acc, 2)})
    with open(f"{out_dir}/codalab_summary.json", "w") as f:
        json.dump(summary, f, indent=2)


if __name__ == "__main__":
    main()
