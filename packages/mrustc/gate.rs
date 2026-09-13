// ============================================================================
// mrustc GATE — a self-contained #![no_core] Rust program.
//
// WHY no_core AND WHY IT WORKS WITHOUT ANY -L:
//   mrustc's "Expand HIR Static Borrow Mark" pass (src/hir_expand/
//   static_borrow_constants.cpp:55-66, and again :634-645) starts with
//     m_lang_RangeFull = m_resolve.m_crate.get_lang_item_path_opt("range_full");
//   and ONLY falls into its "EVIL hack" branch — which does
//   get_typeitem_by_path(::<core>::ops::RangeFull) and BUGs out when no core
//   crate is loaded — if that lookup returned an empty path.  Declaring
//   #[lang="RangeFull"] here makes the lookup succeed, so the fallback is never
//   entered and NO core crate is needed.  (expand/lang_item.cpp:135 maps the
//   attribute spelling "RangeFull" onto the internal name "range_full" when
//   MRUSTC_TARGET_VER >= 1.54.)
//
// Everything below is compiled, linked by $CC, and RUN; the process exit status
// is the computed answer.  42 == pass.  101..104 == a specific wrong sub-result.
// ============================================================================
#![allow(internal_features)]
#![feature(no_core,lang_items)]
#![no_core]

// --- the marker/lang-item floor mrustc's trait resolution probes -------------
#[lang="sized"]           trait Sized: MetaSized {}
#[lang="meta_sized"]      pub trait MetaSized: PointeeSized {}
#[lang="pointee_sized"]   pub trait PointeeSized {}
#[lang="copy"]            pub trait Copy {}
#[lang="drop"]            pub trait Drop { fn drop(&mut self); }
#[lang="RangeFull"]       pub struct RangeFull;
#[lang="unsize"]          pub trait Unsize<T: PointeeSized>: PointeeSized {}
#[lang="coerce_unsized"]  pub trait CoerceUnsized<T> {}
#[lang="fn_ptr_trait"]    pub trait FnPtr { fn addr(self) -> *const (); }
#[lang="discriminant_kind"] pub trait DiscriminantKind { type Discriminant; }
#[lang="pointee_trait"]   pub trait Pointee { type Metadata; }
#[lang="freeze"]          pub unsafe trait Freeze {}
#[lang="structural_peq"]  pub trait StructuralPartialEq {}
#[lang="structural_teq"]  pub trait StructuralEq {}
#[lang="tuple_trait"]     pub trait Tuple {}
#[lang="clone"]           pub trait Clone { fn clone(&self) -> Self; }
#[lang="fn_once"]         pub trait FnOnce<A> { type Output; }
#[lang="fn_mut"]          pub trait FnMut<A>: FnOnce<A> {}
#[lang="fn"]              pub trait Fn<A>: FnMut<A> {}

// --- operators, defined here so real arithmetic codegen is exercised ---------
#[lang="add"] pub trait Add<R=Self> { type Output; fn add(self, r: R) -> Self::Output; }
#[lang="sub"] pub trait Sub<R=Self> { type Output; fn sub(self, r: R) -> Self::Output; }
#[lang="mul"] pub trait Mul<R=Self> { type Output; fn mul(self, r: R) -> Self::Output; }
#[lang="eq"]  pub trait PartialEq<R=Self> { fn eq(&self, o: &R) -> bool; }

impl Copy for isize {}
impl Add for isize { type Output = isize; fn add(self, r: isize) -> isize { self + r } }
impl Sub for isize { type Output = isize; fn sub(self, r: isize) -> isize { self - r } }
impl Mul for isize { type Output = isize; fn mul(self, r: isize) -> isize { self * r } }
impl PartialEq for isize { fn eq(&self, o: &isize) -> bool { *self == *o } }

// --- struct with fields + an inherent method --------------------------------
struct Pair { a: isize, b: isize }
impl Pair { fn sum(&self) -> isize { self.a + self.b } }

// --- a trait, an impl, and a GENERIC function over it (monomorphisation) ----
trait Score { fn score(&self) -> isize; }
impl Score for Pair { fn score(&self) -> isize { self.sum() * 2 } }
fn total<T: Score>(t: &T) -> isize { t.score() }

// --- enum construction + match ----------------------------------------------
enum Sel { A, B, C }
fn pick(s: Sel) -> isize { match s { Sel::A => 1, Sel::B => 2, Sel::C => 3 } }

// --- loop, mutation, comparison, accumulation -------------------------------
fn accum(n: isize) -> isize {
    let mut i: isize = 0;
    let mut acc: isize = 0;
    loop {
        if i == n { break; }
        acc = acc + i;
        i = i + 1;
    }
    acc
}

// --- take-address / raw-pointer round trip + subtraction --------------------
fn via_ptr(v: isize) -> isize {
    let x = v;
    let p: *const isize = &x;
    unsafe { *p - 4 }
}

fn compute() -> isize {
    let p = Pair { a: 3, b: 4 };
    let t = total(&p);      // (3+4)*2      = 14
    let a = accum(5);       // 0+1+2+3+4    = 10
    let m = pick(Sel::B);   //              =  2
    let v = via_ptr(20);    // 20-4         = 16
    // Distinct codes so a red gate says WHICH construct miscompiled.
    if t != 14 { return 101; }
    if a != 10 { return 102; }
    if m !=  2 { return 103; }
    if v != 16 { return 104; }
    // ...and the answer is still the COMPUTED sum, never a literal, so even a
    // compiler that miscompiles `!=` into always-false cannot pass vacuously.
    t + a + m + v           // = 42
}

#[lang="start"]
fn lang_start<T>(main: fn() -> T, argc: isize, argv: *const *const u8, sigpipe: u8) -> isize {
    compute()
}

fn main() {}

#[panic_handler]
fn mrustc_panic(_payload: usize) -> u32 { 0 }
