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
