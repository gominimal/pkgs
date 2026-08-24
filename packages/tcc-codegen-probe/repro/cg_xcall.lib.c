/* companion object for cg_xcall.c — libfn is NON-LEAF (calls helper) and DEFINED GLOBAL.
   The exact bug-shape of fix C: a static-linked call to such a symbol routed through an unfilled
   PLT/GOT slot → SIGSEGV. If this case CRASHES, fix C has regressed in tcc-0.9.27's tccelf.c. */
int helper(int x){ return x * 2; }
int libfn(int x){ return helper(x) + 2; }
