#lang typed/racket/no-check

(provide (all-defined-out))

(define ∘ compose)


;;; 类型
;; a、x 是答案类型参数；类型标注只作设计说明，不经类型检查

(define-type (→𝒟 p q) (→ p q))              ; 构造性宿主世界
(define-type (←𝒟 q p) (→𝒟 p q))

(define-type ⊥ (∪))
(define-type ⊥ᵃ a)                          ; 局部空：平凡表示
(define-type ⊥ˣ x)
(define-type (¬ₐ p) (→𝒟 p ⊥ᵃ))
(define-type (¬ₐ¬ₐ p) (¬ₐ (¬ₐ p)))
(define-type (¬ₐ¬ₐ¬ₐ p) (¬ₐ (¬ₐ¬ₐ p)))

;; 局部否定：左下标是否定的基，右下标是世界的基

(define-type (→𝒰ₐ p q) (←𝒟 (¬ₐ p) (¬ₐ q)))  ; 局部逆否世界
(define-type (¬ₓ𝒰ₐ p)  (→𝒰ₐ p ⊥ˣ))
(define-type (¬𝒰ₐ p)   (→𝒰ₐ p ⊥))

(define-type (→𝒦ₐ p q) (→𝒟 p (¬ₐ¬ₐ q)))    ; 局部 CPS 世界
(define-type (¬ₓ𝒦ₐ p)  (→𝒦ₐ p ⊥ˣ))
(define-type (¬𝒦ₐ p)   (→𝒦ₐ p ⊥))


;;; 预复合、交换参数、恒等、丢弃

(: neg  (∀ (p q) (→ (→𝒟 p q) (←𝒟 (¬ₐ p) (¬ₐ q)))))
(: neg¹ (∀ (p q) (→ (←𝒟 q p) (→𝒟 (¬ₐ q) (¬ₐ p)))))
(define ((neg f) kₐq) (∘ kₐq f))
(define neg¹ neg)

(: flip  (∀ (p q) (→ (←𝒟 (¬ₐ p) q) (→𝒟 p (¬ₐ q)))))
(: flip¹ (∀ (p q) (→ (→𝒟 p (¬ₐ q)) (←𝒟 (¬ₐ p) q))))
(define (((flip f) . y*) . x*) (apply (apply f x*) y*))
(define flip¹ flip)

(: a->⊥ᵃ (∀ (a) (¬ₐ a)))
(define a->⊥ᵃ values)

(: neg* (∀ (p a) (→ (¬ₐ p) (¬𝒰ₐ p))))
(define ((neg* kₐp) _k) kₐp)


;;; 以下由上面四个运算与宿主的基本函数组合而成

;;; 复合

(: ∘𝒰 (∀ (p ...) (→ (→𝒰ₐ pn-1 pn) ... (→𝒰ₐ p1 p2) (→𝒰ₐ p1 pn))))
(define (∘𝒰 . neg:f*) (apply ∘ (reverse neg:f*)))

(: cps  (∀ (p q) (→ (→𝒟 p q) (→𝒦ₐ p q))))
(: cps* (∀ (p a) (→ (¬ₐ p) (¬𝒦ₐ p))))
(define cps  (∘ flip neg))
(define cps* (∘ flip neg*))

(: cps¹ (∀ (q p) (→ (←𝒟 q p) (←𝒟 (¬ₐ¬ₐ q) p))))
(define cps¹ cps)

(: ∘𝒦 (∀ (p ...) (→ (→𝒦ₐ pn-1 pn) ... (→𝒦ₐ p1 p2) (→𝒦ₐ p1 pn))))
(define (∘𝒦 . cps:f*) (flip (apply ∘𝒰 (map flip¹ cps:f*))))

(: neg² (∀ (p q) (→ (→𝒟 p q) (→𝒟 (¬ₐ¬ₐ p) (¬ₐ¬ₐ q)))))
(define neg² (∘ neg¹ neg))

(: cps->neg² (∀ (p q) (→ (→𝒦ₐ p q) (→𝒟 (¬ₐ¬ₐ p) (¬ₐ¬ₐ q)))))
(define cps->neg² (∘ neg¹ flip¹))


;;; 控制运算符

(: neg:call/lc (∀ (p a) (→𝒰ₐ (→𝒰ₐ (¬ₐ𝒰ₐ p) p) p)))
(: neg:call/cc (∀ (p a) (→𝒰ₐ (→𝒰ₐ (¬𝒰ₐ  p) p) p)))
(define ((neg:call/lc kₐp) neg:proc) ((neg:proc kₐp) (neg  kₐp)))
(define ((neg:call/cc kₐp) neg:proc) ((neg:proc kₐp) (neg* kₐp)))

(: cps:call/lc (∀ (p a) (→𝒦ₐ (→𝒦ₐ (¬ₐ𝒦ₐ p) p) p)))
(: cps:call/cc (∀ (p a) (→𝒦ₐ (→𝒦ₐ (¬𝒦ₐ  p) p) p)))
(define ((cps:call/lc cps:proc) kₐp) ((cps:proc (cps  kₐp)) kₐp))
(define ((cps:call/cc cps:proc) kₐp) ((cps:proc (cps* kₐp)) kₐp))


;;; 求值与定界

(: cps:id (∀ (p a) (→𝒦ₐ p p)))
(define cps:id (cps values))

(: anf:eval (∀ (a) (¬ₐ¬ₐ¬ₐ a)))
(define anf:eval (cps:id a->⊥ᵃ))

(: anf:reset (∀ (a) (→ (¬ₐ¬ₐ a) (∀ (x) (¬ₓ¬ₓ a)))))
(define anf:reset (cps anf:eval))

(: cps:abort (∀ (a) (¬𝒦ₐ a)))
(define cps:abort (cps* a->⊥ᵃ))
(define neg²:abort (cps->neg² cps:abort))


;;; anf: 宏

(define-syntax anf:let*-values
  (syntax-rules ()
    [(_ () b* ...)
     (anf:begin b* ...)]
    [(_ ([v* e]) b* ...)
     (let ([kkv e])
       (define (cps:kv . v*) (anf:begin b* ...))
       (define neg²:kv (cps->neg² cps:kv))
       (neg²:kv kkv))]
    [(_ ([v* e] [v** e*] ...) b* ...)
     (anf:let*-values ([v* e])
       (anf:let*-values ([v** e*] ...)
         b* ...))]))

(define-syntax anf:begin
  (syntax-rules ()
    [(_ b) b]
    [(_ b b* ...) (anf:let*-values ([_ b]) b* ...)]))

(define-syntax-rule (anf:let* ([v e] ...) b* ...)
  (anf:let*-values ([(v) e] ...) b* ...))

(define-syntax-rule (anf:if test conseq alt)
  (let ([kkb test])
    (define (cps:kb . b*) (if (equal? b* '(#f)) alt conseq))
    (define neg²:kb (cps->neg² cps:kb))
    (neg²:kb kkb)))

(define-syntax-rule (anf:let/lc cps:k b* ...)
  (cps:call/lc (λ (cps:k) b* ...)))

(define-syntax-rule (anf:let/cc cps:k b* ...)
  (cps:call/cc (λ (cps:k) b* ...)))

(define-syntax-rule (anf:shift cps:k e)
  (anf:let/lc cps:k (neg²:abort e)))


;;; CPS 提升的基本操作

(define cps:+         (cps +))
(define cps:*         (cps *))
(define cps:zero?     (cps zero?))
(define cps:car       (cps car))
(define cps:cdr       (cps cdr))
(define cps:null?     (cps null?))
(define cps:display   (cps display))
(define cps:displayln (cps displayln))

(module+ test
  (require rackunit racket/control "../../tools/check-output-prefix.rkt")
  ;; 同一条局部延续：不用、调用一次、调用两次。
  (define (example step)
    (anf:eval
     (anf:let* ([v (anf:reset
                    (anf:let* ([x (step)]
                               [y (cps:+ 2 x)])
                      (cps:abort y)))])
       (cps:+ 10 v))))
  (check-equal? (example (λ () (cps:id 3))) 15)
  (check-equal? (example (λ () (anf:shift cps:k (cps:id 3)))) 13)
  (check-equal? (example (λ () (anf:shift cps:k (cps:k 3)))) 15)
  (check-equal?
   (example (λ () (anf:shift cps:k
                  (anf:let* ([r (cps:k 3)]) (cps:k r)))))
   17)
  (define-syntax-rule (let/lc k body) (shift k (k body)))
  (check-true
   (output-starts-with?
    (λ ()
      (reset
       (let ([kn (let/lc k0 k0)])
         (display #\@)
         (let ([k (let/lc kn+1 kn+1)])
           (display #\*)
           (kn k)))))
    "@*@**@***@")))


;; 正文推导中的独立版本，同名定义各有自己的作用域。

(module stage-1 racket
  (define (goto l) (l l))
  (define (label) (call/cc goto))
  (define (mul . r*)
    (define first? #t)
    (define result (*))
    (define ret (label))
    (when first?
      (set! first? #f)
      (for ([r (in-list r*)])
        (when (zero? r)
          (set! result r)
          (goto ret))
        (set! result (* result r))))
    result)
  (provide (all-defined-out))
)

(module stage-2 racket
  ;; 正文假设的宿主 return：测试时用当前函数的退出延续实现。
  (define current-return (make-parameter values))
  (define (return v) ((current-return) v))
  (define (mul . r*)
    (define result (*))
    (for ([r (in-list r*)])
      (when (zero? r) (return 0))
      (set! result (* result r)))
    (return result))
  (provide (all-defined-out))
)

(module stage-3 typed/racket/no-check

  (struct (r) ans ([a : r]) #:type-name Ans)
  (provide (all-defined-out))
)

(module stage-4 typed/racket/no-check
  (require (submod ".." stage-3))
  (: mul (→ Real * Real))

  (define (mul . r*)
    (: real* (→ Real Real (∪ Real (Ans Real))))
    (define (real* a b)
      (if (or (zero? a) (zero? b))
          (ans 0)
          (* a b)))
    (: loop (→ (Listof Real) (∪ Real (Ans Real)) (Ans Real)))
    (define (loop r* result)
      (cond
        [(ans? result) result]
        [(null? r*) (ans result)]
        [else (loop (cdr r*) (real* (car r*) result))]))
    (ans-a (loop r* (*))))
  (provide (all-defined-out))
)

(module stage-6 typed/racket/no-check
  (require (submod ".." stage-3))
  (define-type ⊥ᵃ (Ans Real))

  (define ⊥ᵃ?   ans?)

  (define a->⊥ᵃ ans)

  (define ⊥ᵃ->a ans-a)
  (provide (all-defined-out))
)

(module stage-7 typed/racket/no-check
  (require (submod ".." stage-6))
  (define-type Realᵃ (∪ Real ⊥ᵃ))
  (provide (all-defined-out))
)

(module stage-8 typed/racket/no-check
  (require (submod ".." stage-6))
  (define-type (¬ₐ p) (→ p ⊥ᵃ))
  (provide (all-defined-out))
)

(module stage-9 typed/racket/no-check
  (require (submod ".." stage-6))
  (define-type (¬ₐ p) (→ p ⊥ᵃ))
  (: mul (→ Real * Real))

  (define (mul . r*)
    (: loop/kₐ (→ (Listof Real) (¬ₐ Real) ⊥ᵃ))
    (define (loop/kₐ r* kₐ)
      (if (null? r*)
          (kₐ (*))
          (let ([r (car r*)])
            (if (zero? r)
                (a->⊥ᵃ r)
                (loop/kₐ (cdr r*) (λ (v) (kₐ (* v r))))))))
    (⊥ᵃ->a (loop/kₐ r* a->⊥ᵃ)))
  (provide (all-defined-out))
)

(module stage-11 typed/racket/no-check
  (require (submod ".." stage-6))
  (define (((cps f) . p*) kₐq) (kₐq (apply f p*)))

  (define ((cps:call/cc cps:proc) kₐp) ((cps:proc (cps kₐp)) kₐp))

  (define (anf:eval kₐkₐa) (⊥ᵃ->a (kₐkₐa a->⊥ᵃ)))
  (provide (all-defined-out))
)

(module stage-15 typed/racket/no-check

  (define (((cps* kₐp) . p*) _kₐq) (apply kₐp p*))
  (provide (all-defined-out))
)

(module stage-17 typed/racket/no-check

  (define-type ⊥ᵃ Real)

  (define-type (¬ₐ p) (→ p ⊥ᵃ))

  (define ⊥ᵃ->a values)
  (provide (all-defined-out))
)

(module stage-21 typed/racket/no-check
  (define ⊥ᵃ->a values)
  (define (((cps f) . p*) kₐq) (kₐq (apply f p*)))
  (define ((cps:call/lc cps:proc) kₐp)
    (define (kp p) (⊥ᵃ->a (kₐp p)))
    ((cps:proc (cps kp)) kₐp))
  (provide (all-defined-out))
)

(module stage-22 typed/racket/no-check
  (define ⊥ᵃ->a values)
  (define a->⊥ᵃ values)
  (define (anf:eval kₐkₐa) (⊥ᵃ->a (kₐkₐa a->⊥ᵃ)))
  (provide (all-defined-out))
)

(module stage-27 racket
  (require racket/control)
  (define (abort . v*) (shift _ (apply values v*)))
  (provide (all-defined-out))
)

(module stage-40 racket
  (require (rename-in (except-in racket/control abort) [shift primitive-shift]) (only-in (submod ".." stage-27) abort))
  (define (call/lc proc) (primitive-shift k (proc k)))
  (define-syntax-rule (let/lc k body ...)
    (call/lc (λ (k) body ...)))

  (define-syntax-rule (shift k expr)
    (let/lc k (let ([v expr]) (abort v))))
  (provide (all-defined-out))
)

(module stage-41 racket
  (require (submod ".." stage-40) (only-in (submod ".." stage-27) abort))
  (define ∘ compose)
  (define (call/cc proc)
    (let/lc k (proc (∘ abort k))))
  (provide (all-defined-out))
)

(module stage-47 typed/racket/no-check
  (define-type ⊥ᵃ Real)
  (define-type (¬ₐ p) (→ p ⊥ᵃ))
  (define-type (¬ₐ¬ₐ p) (¬ₐ (¬ₐ p)))
  (define-type (→𝒟 p q) (→ p q))
  (define-type (←𝒟 q p) (→𝒟 p q))
  (define-type (→𝒰ₐ p q) (←𝒟 (¬ₐ p) (¬ₐ q)))
  (define-type (→𝒦ₐ p q) (→𝒟 p (¬ₐ¬ₐ q)))
  (define-type (¬ₐ𝒰ₓ p) (→𝒰ₐ p ⊥ᵃ))
  (define-type (¬ₐ𝒦ₓ p) (→𝒦ₐ p ⊥ᵃ))
  (define ((neg f) kₐq) (compose kₐq f))
  (: neg (∀ (p q) (→ (→𝒟 p q) (∀ (a) (→𝒰ₐ p q)))))
  (provide (all-defined-out))
)

(module stage-48 typed/racket/no-check
  (define-type ⊥ᵃ Real)
  (define-type (¬ₐ p) (→ p ⊥ᵃ))
  (define-type (¬ₐ¬ₐ p) (¬ₐ (¬ₐ p)))
  (define-type (→𝒟 p q) (→ p q))
  (define-type (←𝒟 q p) (→𝒟 p q))
  (define-type (→𝒰ₐ p q) (←𝒟 (¬ₐ p) (¬ₐ q)))
  (define-type (→𝒦ₐ p q) (→𝒟 p (¬ₐ¬ₐ q)))
  (define-type (¬ₐ𝒰ₓ p) (→𝒰ₐ p ⊥ᵃ))
  (define-type (¬ₐ𝒦ₓ p) (→𝒦ₐ p ⊥ᵃ))
  (define ((neg f) kₐq) (compose kₐq f))
  (: neg (∀ (p a) (→ (¬ₐ p) (∀ (x) (¬ₐ𝒰ₓ p)))))
  (provide (all-defined-out))
)

(module stage-53 typed/racket/no-check
  (define-type ⊥ᵃ Real)
  (define-type (¬ₐ p) (→ p ⊥ᵃ))
  (define-type (¬ₐ¬ₐ p) (¬ₐ (¬ₐ p)))
  (define-type (→𝒟 p q) (→ p q))
  (define-type (←𝒟 q p) (→𝒟 p q))
  (define-type (→𝒰ₐ p q) (←𝒟 (¬ₐ p) (¬ₐ q)))
  (define-type (→𝒦ₐ p q) (→𝒟 p (¬ₐ¬ₐ q)))
  (define-type (¬ₐ𝒰ₓ p) (→𝒰ₐ p ⊥ᵃ))
  (define-type (¬ₐ𝒦ₓ p) (→𝒦ₐ p ⊥ᵃ))
  (define (((flip f) . y*) . x*) (apply (apply f x*) y*))
  (define flip¹ flip)
  (: flip  (∀ (p q) (→ (→𝒰ₐ p q) (→𝒦ₐ p q))))

  (: flip¹ (∀ (p q) (→ (→𝒦ₐ p q) (→𝒰ₐ p q))))
  (provide (all-defined-out))
)

(module stage-54 typed/racket/no-check
  (define-type ⊥ᵃ Real)
  (define-type (¬ₐ p) (→ p ⊥ᵃ))
  (define-type (¬ₐ¬ₐ p) (¬ₐ (¬ₐ p)))
  (define-type (→𝒟 p q) (→ p q))
  (define-type (←𝒟 q p) (→𝒟 p q))
  (define-type (→𝒰ₐ p q) (←𝒟 (¬ₐ p) (¬ₐ q)))
  (define-type (→𝒦ₐ p q) (→𝒟 p (¬ₐ¬ₐ q)))
  (define-type (¬ₐ𝒰ₓ p) (→𝒰ₐ p ⊥ᵃ))
  (define-type (¬ₐ𝒦ₓ p) (→𝒦ₐ p ⊥ᵃ))
  (define cps (compose (λ (f) (λ (v) (λ (k) (k (f v))))) values))
  (: cps  (∀ (p a) (→ (¬ₐ p) (∀ (x) (¬ₐ𝒦ₓ p)))))
  (provide (all-defined-out))
)

(module stage-56 typed/racket/no-check
  (define-type ⊥ᵃ Real)
  (define-type (¬ₐ p) (→ p ⊥ᵃ))
  (define-type (¬ₐ¬ₐ p) (¬ₐ (¬ₐ p)))
  (define-type (→𝒟 p q) (→ p q))
  (define-type (←𝒟 q p) (→𝒟 p q))
  (define-type (→𝒰ₐ p q) (←𝒟 (¬ₐ p) (¬ₐ q)))
  (define-type (→𝒦ₐ p q) (→𝒟 p (¬ₐ¬ₐ q)))
  (define-type (¬ₐ𝒰ₓ p) (→𝒰ₐ p ⊥ᵃ))
  (define-type (¬ₐ𝒦ₓ p) (→𝒦ₐ p ⊥ᵃ))
  (define a->⊥ᵃ values)
  (: anf:eval (∀ (a) (→ (¬ₐ¬ₐ a) a)))

  (define (anf:eval kₐkₐa) (kₐkₐa a->⊥ᵃ))
  (provide (all-defined-out))
)

(module stage-57 typed/racket/no-check
  (define-type ⊥ᵃ Real)
  (define-type (¬ₐ p) (→ p ⊥ᵃ))
  (define-type (¬ₐ¬ₐ p) (¬ₐ (¬ₐ p)))
  (define-type (→𝒟 p q) (→ p q))
  (define-type (←𝒟 q p) (→𝒟 p q))
  (define-type (→𝒰ₐ p q) (←𝒟 (¬ₐ p) (¬ₐ q)))
  (define-type (→𝒦ₐ p q) (→𝒟 p (¬ₐ¬ₐ q)))
  (define-type (¬ₐ𝒰ₓ p) (→𝒰ₐ p ⊥ᵃ))
  (define-type (¬ₐ𝒦ₓ p) (→𝒦ₐ p ⊥ᵃ))
  (define cps:id (λ (p) (λ (k) (k p))))
  (: cps:id (∀ (p a) (→ p (¬ₐ¬ₐ p))))
  (provide (all-defined-out))
)

(module stage-59 typed/racket/no-check
  (define ⊥ᵃ->a values)
  (define a->⊥ᵃ values)
  (define (anf:eval kₐkₐa) (kₐkₐa a->⊥ᵃ))
  (define ((anf:reset kₐkₐa) kₓa)
    (kₓa (anf:eval kₐkₐa)))
  (provide (all-defined-out))
)

(module stage-60 typed/racket/no-check
  (define-type ⊥ᵃ Real)
  (define-type (¬ₐ p) (→ p ⊥ᵃ))
  (define a->⊥ᵃ values)
  (: mul (→ Real * Real))

  (define (mul . r*)
    (: loop/ki (→ (Listof Real) (¬ₐ Real) (¬ₐ Real) ⊥ᵃ))
    (define (loop/ki r* kₐ iₐ)
      (if (null? r*)
          (kₐ (*))
          (let ([r (car r*)])
            (if (zero? r)
                (iₐ r)
                (loop/ki (cdr r*) (λ (v) (kₐ (* v r))) iₐ)))))
    (loop/ki r* a->⊥ᵃ a->⊥ᵃ))
  (provide (all-defined-out))
)

(module stage-62 typed/racket/no-check
  (define-type ⊥ᵃ Real)
  (define-type (¬ₐ p) (→ p ⊥ᵃ))
  (define-type (¬ₐ¬ₐ p) (¬ₐ (¬ₐ p)))
  (define-type (→𝒟 p q) (→ p q))
  (define-type (←𝒟 q p) (→𝒟 p q))
  (define-type (→𝒰ₐ p q) (←𝒟 (¬ₐ p) (¬ₐ q)))
  (define-type (→𝒦ₐ p q) (→𝒟 p (¬ₐ¬ₐ q)))
  (define-type (¬ₐ𝒰ₓ p) (→𝒰ₐ p ⊥ᵃ))
  (define-type (¬ₐ𝒦ₓ p) (→𝒦ₐ p ⊥ᵃ))
  (define ((neg¹ f) kₐq) (compose kₐq f))
  (define (((cps f) . p*) kₐq) (kₐq (apply f p*)))
  (: neg¹  (∀ (q p) (→ (←𝒟 q p) (→𝒟 (¬ₐ q) (¬ₐ p)))))

  (: cps   (∀ (p q) (→ (→𝒟 p q) (→𝒟 p (¬ₐ¬ₐ q)))))
  (provide (all-defined-out))
)

(module+ test
  (require racket/control
           (prefix-in label: (submod ".." stage-1))
           (prefix-in hypothetical: (submod ".." stage-2))
           (prefix-in tagged: (submod ".." stage-4))
           (prefix-in local: (submod ".." stage-9))
           (prefix-in simple: (submod ".." stage-11))
           (prefix-in corrected: (submod ".." stage-15))
           (prefix-in ordinary: (submod ".." stage-22))
           (prefix-in return: (submod ".." stage-40))
           (prefix-in call: (submod ".." stage-41))
           (prefix-in reset: (submod ".." stage-59))
           (prefix-in early: (submod ".." stage-60)))
  (for ([mul (list label:mul tagged:mul local:mul early:mul)])
    (check-equal? (mul 2 3 4) 24)
    (check-equal? (mul 2 0 4) 0))
  (check-equal?
   (call/cc (λ (k)
              (parameterize ([hypothetical:current-return k])
                (hypothetical:mul 2 0 4))))
   0)
  (check-equal? (simple:anf:eval ((simple:cps add1) 3)) 4)
  (check-equal? (((corrected:cps* values) 9) (λ (_) (error 'discard "should not run"))) 9)
  (check-equal? (ordinary:anf:eval (λ (k) (k 12))) 12)
  (check-equal? (reset (return:shift k (k 3))) 3)
  (check-equal? (reset (call:call/cc (λ (k) (k 4)))) 4)
  (check-equal? ((reset:anf:reset (λ (k) (k 5))) values) 5))
