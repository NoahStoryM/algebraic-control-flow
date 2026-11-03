(
((define (mul . r*)
  (: real* (→ Real Real Realᵃ))
  (define (real* a b) ...)
  (: loop (→ (Listof Real) Realᵃ ⊥ᵃ))
  (define (loop r* result) ...)
  (⊥ᵃ->a (loop r* (*))))
"「边界的两侧」用省略号回指上一段的 real* 与 loop，只为显示换名以后的类型")
)
