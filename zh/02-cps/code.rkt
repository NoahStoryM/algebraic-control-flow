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
