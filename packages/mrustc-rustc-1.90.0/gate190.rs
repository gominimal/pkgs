// gate190.rs — GATE-3.  THE functional gate for the mrustc-built rustc 1.90.0.
//
// ── WHY THIS SHAPE ───────────────────────────────────────────────────────────────────────────
// Upstream's own checks cannot do this job:
//   * samples/no_core-1_90.rs is COMPILE-ONLY, and its lang_start returns a LITERAL 0 —
//     vacuous even if executed.
//   * run_rustc/Makefile:259-263's hello_world is `fn main() { println!("Hello, world!"); }`
//     with an unchecked `./$@`.  stdout is neither captured nor compared, and main returns ()
//     so the exit status is 0 unless the process dies.  Its real content is "does not crash".
//
// output-1.90.0/rustc is itself compiled from UNOPTIMISED C emitted by mrustc.  The whole
// ladder rests on that lowering being correct.  A subtly wrong rustc reliably still compiles
// println! (one monomorphic formatting path) while getting vtable layout, unwind tables, or
// TLS/atomics wrong — precisely where mrustc's C backend has historically been weakest, and
// precisely what hello.rs cannot reach.
//
// ── NON-VACUITY ──────────────────────────────────────────────────────────────────────────────
// The pass value 42 is NEVER written in the success path.  It is only ever the SUM of ten
// independently computed quantities.  A compiler that miscompiled `!=` or `==` into a constant
// cannot manufacture it — it would have to compute ten specific wrong values that happen to sum
// to 42.  Each check ALSO exits with its own code (111-120) so a red gate NAMES the miscompiled
// construct instead of just saying "not 42".
//
// Edition 2015 (no --edition is passed), so `extern crate` is required.

extern crate gatelib;

use std::collections::{BTreeMap, HashMap};
use std::sync::{Arc, Mutex};

use gatelib::{Shape, Sq};

fn c6_inner(s: &str) -> Result<i64, std::num::ParseIntError> {
    let n: i64 = s.parse()?;
    let doubled = Some(n).map(|v| v + 3).unwrap_or(0);
    Ok(doubled)
}

fn main() {
    // --- 111: Vec + iterator adaptors (map/filter/sum), heap allocation, monomorphisation ---
    let squares: Vec<i64> = (1..=10i64).filter(|n| n % 2 == 1).map(|n| n * n).collect();
    let s: i64 = squares.iter().sum(); // 1+9+25+49+81
    if s != 165 {
        std::process::exit(111);
    }
    let c1 = s / 33; // 5

    // --- 112: core::fmt + String + str::parse round-trip ---
    let hex = format!("{:04x}", 29); // "001d"
    let back: i64 = format!("{}", s).parse().unwrap_or(-1);
    if hex != "001d" || back != 165 {
        std::process::exit(112);
    }
    let c2 = hex.len() as i64; // 4

    // --- 113: BTreeMap ordering + HashMap hashing (RandomState -> OS entropy) ---
    let mut bt: BTreeMap<i64, &str> = BTreeMap::new();
    bt.insert(30, "c");
    bt.insert(10, "a");
    bt.insert(20, "b");
    let ordered: Vec<i64> = bt.keys().cloned().collect();
    let mut hm: HashMap<&str, i64> = HashMap::new();
    hm.insert("a", 1);
    hm.insert("b", 2);
    hm.insert("c", 3);
    if ordered != vec![10, 20, 30] || hm.get("b") != Some(&2) || hm.len() != 3 {
        std::process::exit(113);
    }
    let c3 = bt.len() as i64; // 3

    // --- 114: CROSS-CRATE Box<dyn Trait> vtable dispatch into the rlib from GATE-2 ---
    // This is the check that proves the archive was read back, not just written.
    let shapes: Vec<Box<dyn Shape>> = vec![Box::new(Sq(5)), Box::new(Sq(2))];
    let area: i64 = shapes.iter().map(|sh| sh.area()).sum(); // 25 + 4
    let ck = gatelib::checksum(&[1, 2, 3]); // ((7*31+1)*31+2)*31+3 == 209563
    if area != 29 || ck != 209_563 {
        std::process::exit(114);
    }
    let c4 = shapes[0].area() / 5; // 5

    // --- 115: generics + FnMut closure capture ---
    fn apply<F: FnMut(i64)>(times: i64, mut f: F) {
        for i in 0..times {
            f(i);
        }
    }
    let mut counter: i64 = 0;
    apply(4, |_| counter += 2);
    if counter != 8 {
        std::process::exit(115);
    }
    let c5 = counter / 2; // 4

    // --- 116: Result + `?` + Option combinators ---
    let r = c6_inner("14");
    let bad = c6_inner("not-a-number"); // hoisted out of the guard, see the note at 120
    if r != Ok(17) || bad.is_ok() {
        std::process::exit(116);
    }
    let c6 = r.unwrap() % 14; // 3

    // --- 117: catch_unwind — UNWINDING through panic_unwind ---
    // The single most likely thing to be broken in an mrustc-built rustc, and completely
    // invisible to hello.rs.
    let prev = std::panic::take_hook();
    std::panic::set_hook(Box::new(|_| {})); // keep the build log clean
    let caught = std::panic::catch_unwind(|| {
        panic!("boomba");
    });
    std::panic::set_hook(prev);
    let plen = match caught {
        Ok(_) => {
            // The panic did not unwind at all.
            std::process::exit(117);
        }
        Err(e) => match e.downcast_ref::<&str>() {
            Some(msg) => msg.len() as i64, // 6
            None => std::process::exit(117),
        },
    };
    if plen != 6 {
        std::process::exit(117);
    }
    let c7 = plen; // 6

    // --- 118: checked_add / wrapping_add — overflow semantics ---
    if i64::max_value().checked_add(1).is_some() {
        std::process::exit(118);
    }
    let w: u8 = 250u8.wrapping_add(10); // 4
    if w != 4 {
        std::process::exit(118);
    }
    let c8 = w as i64; // 4

    // --- 119: f64 format + parse round-trip ---
    let f: f64 = "2.5".parse().unwrap_or(0.0);
    let prod = f * 1.6; // 4.0
    if format!("{:.1}", prod) != "4.0" {
        std::process::exit(119);
    }
    let c9 = prod as i64; // 4

    // --- 120: thread::spawn + join + Arc<Mutex<_>> — pthreads, TLS, atomics ---
    let shared = Arc::new(Mutex::new(0i64));
    let mut handles = Vec::new();
    for _ in 0..4 {
        let h = Arc::clone(&shared);
        handles.push(std::thread::spawn(move || {
            let mut g = h.lock().unwrap();
            *g += 1;
        }));
    }
    for h in handles {
        // join() is called UNCONDITIONALLY and its result bound before being tested.  Putting a
        // side-effecting call inside the guard condition would make the accumulated value depend
        // on the guard executing, which defeats the whole non-vacuity argument: a compiler that
        // miscompiled the comparison away would also skip the join and race.  (Measured — the
        // first draft of this file had exactly that bug and scored 40 instead of 42 under a
        // guards-neutered build.)
        let joined = h.join();
        if joined.is_err() {
            std::process::exit(120);
        }
    }
    let threaded = *shared.lock().unwrap();
    if threaded != 4 {
        std::process::exit(120);
    }
    let c10 = threaded; // 4

    // 5 + 4 + 3 + 5 + 4 + 3 + 6 + 4 + 4 + 4 == 42, computed, never a literal.
    let total = c1 + c2 + c3 + c4 + c5 + c6 + c7 + c8 + c9 + c10;
    std::process::exit(total as i32);
}
