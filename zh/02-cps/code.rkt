#lang typed/racket/no-check

(provide (all-defined-out))

(define ∘ compose)
(define (list->values v*) (apply values v*))


;;; 类型别名

(define-type ⊥ (∪))
(define-type (¬  a) (→ a ⊥))
(define-type (¬¬ a) (¬ (¬ a)))
(define-type (← q p) (→ p q))


;;; 答案类型（通过 raise 实现初始延续）

(struct (r) ans ([a* : (Listof r)]) #:type-name Ans)
(: a->⊥ (∀ (a) (¬ a)))
(define (a->⊥ . a*) (raise (ans a*)))
(define-syntax-rule (⊥->a exp)
  (with-handlers ([ans? (∘ list->values ans-a*)]) exp))


;;; 宿主世界

(define-type (→𝒟 p q) (→ p q))
(define-type (→𝒞 p q) (→ p q))

(: inj (∀ (p q) (→ (→𝒟 p q) (→𝒞 p q))))
(define (inj f) f)

;;; 逆否世界

(define-type (→𝒰 p q) (← (¬ p) (¬ q)))
(define-type (¬𝒰 p)   (→𝒰 p ⊥))

(: neg (∀ (p q) (→ (→𝒞 p q) (→𝒰 p q))))
(: neg¹ (∀ (p q) (→ (→𝒰 p q) (→𝒟 (¬¬ p) (¬¬ q)))))
(define ((neg f) kq) (∘ kq f))
(define neg¹ neg)

(: ∘𝒰 (∀ (p ...) (→ (→𝒰 pn-1 pn) ... (→𝒰 p1 p2) (→𝒰 p1 pn))))
(define (∘𝒰 . neg:f*) (apply ∘ (reverse neg:f*)))


;;; CPS 世界

(define-type (→𝒦 p q) (→ p (¬¬ q)))
(define-type (¬𝒦 p)   (→𝒦 p ⊥))

(: flip  (∀ (p q) (→ (→𝒰 p q) (→𝒦 p q))))
(: flip¹ (∀ (p q) (→ (→𝒦 p q) (→𝒰 p q))))
(define (((flip f) . y*) . x*) (apply (apply f x*) y*))
(define flip¹ flip)

(: cps   (∀ (p q) (→ (→𝒞 p q) (→𝒦 p q))))
(: uncps (∀ (p q) (→ (→𝒦 p q) (→𝒞 p q))))
(define cps (∘ flip neg))
(define (uncps cps:f) (∘ call/cc cps:f))

(: ∘𝒦 (∀ (p ...) (→ (→𝒦 pn-1 pn) ... (→𝒦 p1 p2) (→𝒦 p1 pn))))
(define (∘𝒦 . cps:f*) (flip (apply ∘𝒰 (map flip¹ cps:f*))))


;;; Clavius 律

(: neg:call/cc  (∀ (p) (→𝒰 (→𝒰 (¬𝒰 p) p) p)))
(: cps:call/cc  (∀ (p) (→𝒦 (→𝒦 (¬𝒦 p) p) p)))

(define ((neg:call/cc kp) neg:proc) ((neg:proc kp) (neg kp)))
(define ((cps:call/cc cps:proc) kp) ((cps:proc (cps kp)) kp))


;;; 否定翻译

(: neg² (∀ (p q) (→ (→𝒞 p q) (→𝒟 (¬¬ p) (¬¬ q)))))
(define neg² (∘ neg¹ neg))

(: cps->neg² (∀ (p q) (→ (→𝒦 p q) (→𝒟 (¬¬ p) (¬¬ q)))))
(define cps->neg² (∘ neg¹ flip¹))


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

(define-syntax-rule (anf:let/cc cps:k b* ...)
  (cps:call/cc (λ (cps:k) b* ...)))


;;; 解释器

(: anf:eval (∀ (a) (→ (¬¬ a) a)))
(define (anf:eval kka) (⊥->a (kka a->⊥)))


;;; CPS 提升的基本操作

(define cps:id        (cps values))
(define cps:+         (cps +))
(define cps:*         (cps *))
(define cps:zero?     (cps zero?))
(define cps:car       (cps car))
(define cps:cdr       (cps cdr))
(define cps:null?     (cps null?))
(define cps:display   (cps display))
(define cps:displayln (cps displayln))

(module+ test
  (require rackunit "../../tools/check-output-prefix.rkt")
  ;; 普通箭头经 CPS 提升后交给答案通道；组合不应改变结果。
  (check-equal? (anf:eval ((cps +) 2 3)) 5)
  (check-equal? (anf:eval ((∘𝒦 (cps add1) (cps (λ (x) (* 2 x)))) 3)) 7)
  (check-equal? (anf:eval
                 (cps:call/cc
                  (λ (return) (return 42))))
                42)
  (check-equal? (⊥->a ((λ () (a->⊥ 9)))) 9)
  (check-equal?
   (anf:eval
    (anf:let/cc cps:return
      (anf:let* ([r (cps:id 0)])
        (cps:return r))))
   0)
  (define (cps:label) (cps:call/cc cps:id))
  (check-true
   (output-starts-with?
    (λ ()
      (anf:eval
       (anf:let* ([cps:yin (cps:label)])
         (cps:display #\@)
         (anf:let* ([cps:yang (cps:label)])
           (cps:display #\*)
           (cps:yin cps:yang)))))
    "@*@**@***@")))


;; 正文推导中的独立版本，同名定义各有自己的作用域。

(module stage-1 typed/racket/no-check

  (: fact (→ Natural Natural))

  (define (fact n)
    (if (= n 0)
        1
        (* n (fact (- n 1)))))

  (: fib (→ Natural Natural))

  (define (fib n)
    (if (< n 2)
        n
        (+ (fib (- n 1))
           (fib (- n 2)))))
  (provide (all-defined-out))
)

(module stage-2 typed/racket/no-check

  (: fact (→ Natural Natural))

  (define (fact n)
    (if (= n 0) 1
        (let* ([n-1 (- n 1)]
               [v   (fact n-1)])
          (* n v))))

  (: fib (→ Natural Natural))

  (define (fib n)
    (if (< n 2) n
        (let* ([n-1 (- n 1)]
               [v   (fib n-1)]
               [n-2 (- n 2)]
               [w   (fib n-2)])
          (+ v w))))
  (provide (all-defined-out))
)

(module stage-5 typed/racket/no-check
  (define-type ⊥ (∪))
  (define-type (¬ p) (→ p ⊥))
  (define-type (¬¬ p) (¬ (¬ p)))
  (: fact/k (→ Natural (¬ Natural) ⊥))

  (define (fact/k n k)
    (if (= n 0)
        (k 1)
        (fact/k (- n 1)
                (λ (v) (k (* n v))))))

  (: fib/k (→ Natural (¬ Natural) ⊥))

  (define (fib/k n k)
    (if (< n 2)
        (k n)
        (fib/k (- n 1)
               (λ (v)
                 (fib/k (- n 2)
                        (λ (w)
                          (k (+ v w))))))))
  (provide (all-defined-out))
)

(module stage-6 typed/racket/no-check

  (: fact (→ Natural Natural))

  (define (fact n)
    (let loop ([n n] [acc 1])
      (if (= n 0)
          acc
          (loop (- n 1) (* n acc)))))
  (provide (all-defined-out))
)

(module stage-7 typed/racket/no-check
  (define-type ⊥ (∪))
  (define-type (¬ p) (→ p ⊥))
  (define-type (¬¬ p) (¬ (¬ p)))
  (: fact/k (→ Natural (¬ Natural) ⊥))

  (define (fact/k n k)
    (let loop/k ([n n] [acc 1] [k k])
      (if (= n 0)
          (k acc)
          (loop/k (- n 1) (* n acc) k))))
  (provide (all-defined-out))
)

(module stage-9 typed/racket/no-check
  (provide ans? ans-a* a->⊥ list->values ⊥->a)
  (struct (r) ans ([a* : (Listof r)]) #:type-name Ans)
  (define (list->values v*) (apply values v*))
  (define (a->⊥ . a*) (raise (ans a*)))
  (define-syntax-rule (⊥->a exp)
    (with-handlers ([ans? (compose list->values ans-a*)]) exp))
  (provide (all-defined-out))
)

(module stage-11 typed/racket/no-check
  (define-type ⊥ (∪))
  (define-type (¬ p) (→ p ⊥))
  (define-type (¬¬ p) (¬ (¬ p)))
  (require (submod ".." stage-9))
  (: mul (→ Real * Real))

  (define (mul . r*)
    (: loop/k (→ (Listof Real) (→ Real ⊥) ⊥))
    (define (loop/k r* k)
      (if (null? r*)
          (k (*))
          (let ([r (car r*)])
            (if (zero? r)
                (a->⊥ r)
                (loop/k (cdr r*) (λ (v) (k (* v r))))))))
    (⊥->a (loop/k r* a->⊥)))
  (provide (all-defined-out))
)

(module stage-12 typed/racket/no-check

  (define (zero?/k x k) (k (zero? x)))
  (provide (all-defined-out))
)

(module stage-14 typed/racket/no-check

  (define (((neg f) kq) . p*) (kq (apply f p*)))

  (define (((cps f) . p*) kq) (kq (apply f p*)))
  (provide (all-defined-out))
)

(module stage-15 typed/racket/no-check
  (define-type ⊥ (∪))
  (define-type (¬ p) (→ p ⊥))
  (define-type (¬¬ p) (¬ (¬ p)))
  (define (((neg f) kq) . p*) (kq (apply f p*)))
  (define (((cps f) . p*) kq) (kq (apply f p*)))
  (: neg (∀ (p q) (→ (→ p q) (→ (¬ q) (¬ p)))))

  (: cps (∀ (p q) (→ (→ p q) (→    p (¬¬ q)))))
  (provide (all-defined-out))
)

(module stage-16 typed/racket/no-check
  (define (((flip f) . y*) . x*) (apply (apply f x*) y*))
  (: flip (∀ (x y z) (→ (→ x (→ y z)) (→ y (→ x z)))))
  (provide (all-defined-out))
)

(module stage-17 typed/racket/no-check
  (define-type ⊥ (∪))
  (define-type (¬ p) (→ p ⊥))
  (define-type (¬¬ p) (¬ (¬ p)))
  (define (((flip f) . y*) . x*) (apply (apply f x*) y*))
  (define flip¹ flip)
  (: flip  (∀ (p q) (→ (→ (¬ q) (¬ p)) (→ p (¬¬ q)))))

  (: flip¹ (∀ (p q) (→ (→ p (¬¬ q)) (→ (¬ q) (¬ p)))))
  (provide (all-defined-out))
)

(module stage-22 typed/racket/no-check
  (define-type ⊥ (∪))
  (define-type (¬ p) (→ p ⊥))
  (define-type (¬¬ p) (¬ (¬ p)))
  (define-type (→𝒰 p q) (→ (¬ q) (¬ p)))
  (provide (all-defined-out))
)

(module stage-29 typed/racket/no-check
  (define-type ⊥ (∪))
  (define-type (¬ p) (→ p ⊥))
  (define-type (¬¬ p) (¬ (¬ p)))
  (define-type (→𝒞 p q) (→ p q))
  (define-type (→𝒰 p q) (→ (¬ q) (¬ p)))
  (define ∘ compose)
  (define (((flip f) . y*) . x*) (apply (apply f x*) y*))
  (define (uncps cps:f) (∘ call/cc cps:f))
  (: unneg (∀ (p q) (→ (→𝒰 p q) (→𝒞 p q))))

  (define unneg (∘ uncps flip))
  (provide (all-defined-out))
)

(module+ test
  (require (prefix-in direct: (submod ".." stage-1))
           (prefix-in named: (submod ".." stage-2))
           (prefix-in recursive: (submod ".." stage-5))
           (prefix-in tail: (submod ".." stage-6))
           (prefix-in tail/k: (submod ".." stage-7))
           (prefix-in answer: (submod ".." stage-11))
           (prefix-in lift: (submod ".." stage-14))
           (prefix-in reverse: (submod ".." stage-29)))
  (for ([fact (list direct:fact named:fact tail:fact)])
    (check-equal? (fact 6) 720))
  (for ([fib (list direct:fib named:fib)])
    (check-equal? (fib 10) 55))
  (check-equal? (recursive:fact/k 6 values) 720)
  (check-equal? (recursive:fib/k 10 values) 55)
  (check-equal? (tail/k:fact/k 6 values) 720)
  (check-equal? (answer:mul 2 3 4) 24)
  (check-equal? (answer:mul 2 0 4) 0)
  (check-equal? (((lift:cps add1) 7) values) 8)
  (check-equal? ((reverse:unneg (reverse:flip (λ (x) (λ (k) (k (add1 x)))))) 7) 8))
