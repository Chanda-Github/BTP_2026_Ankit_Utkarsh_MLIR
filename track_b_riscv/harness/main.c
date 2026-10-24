/*
 * Test harness: runs the MLIR-compiled TM kernel on every test vector and compares
 * with golden outputs computed independently in Python (emit_mlir.py).
 * Returns the number of mismatches; Spike's exit status is therefore 0 on success.
 *
 * Binary models (2 classes, few inputs): every possible input vector, passed as i1 arguments.
 * Multi-class models: real test samples, passed as a byte array in memory.
 *
 * Kept deliberately tiny so the kernel's instruction mix dominates the trace;
 * profile_isa.py also separates kernel instructions from harness instructions.
 */
#include "golden.h"

int main(void) {
    int errors = 0;
    for (unsigned v = 0; v < TM_NUM_VECTORS; v++) {
#ifdef TM_MULTICLASS
        if (tm_infer(tm_inputs[v]) != tm_expected[v])
            errors++;
#else
        _Bool b[TM_NUM_INPUTS];
        for (int i = 0; i < TM_NUM_INPUTS; i++)
            b[i] = (v >> i) & 1u;
        if ((unsigned char)TM_CALL(b) != tm_expected[v])
            errors++;
#endif
    }
    return errors;
}
