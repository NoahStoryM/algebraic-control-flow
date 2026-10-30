#lang acf/scribble

@title[#:tag "02:appendix"]{附录：完整代码}

这里的 @racket[anf:] 宏处理多值和多个表达式组成的函数体；正文给的是单值、单个函数体的写法。

@codeblock|{
#lang typed/racket/no-check

(provide (all-defined-out))

(: ∘ (∀ (p ...) (→ (→ pn-1 pn) ... (→ p1 p2) (→ p1 pn))))
(define ∘ compose)
(define id (∘))
(define (list->values v*) (apply values v*))

(define-type (← q p) (→ p q))
(: ⨾ (∀ (p ...) (→ (← pn-1 pn) ... (← p1 p2) (← p1 pn))))
(define (⨾ . f*) (apply ∘ (reverse f*)))


;;; 类型别名

(define-type ⊥ (∪))
(define-type (¬  a) (→ a ⊥))
(define-type (¬¬ a) (¬ (¬ a)))


;;; 答案类型（通过 raise 实现终结延续）

(struct (r) ans ([a* : (Listof r)]) #:type-name Ans)
(: a->⊥ (∀ (a) (¬ a)))
(define (a->⊥ . a*) (raise (ans a*)))
(define-syntax-rule (⊥->a exp)
  (with-handlers ([ans? (∘ list->values ans-a*)]) exp))


;;; 宿主的箭头

(define-type (→𝒟 p q) (→ p q))
(define-type (→𝒞 p q) (→ p q))

(: inj (∀ (p q) (→ (→𝒟 p q) (→𝒞 p q))))
(define (inj f) f)

;;; 逆否箭头

(define-type (→𝒰 p q) (← (¬ p) (¬ q)))
(define-type (¬𝒰 p)   (→𝒰 p ⊥))

(: neg
   (∀ (p q)
      (case→ (→ (→𝒞 p q) (→𝒰     p      q))
             (→ (→𝒰 p q) (→𝒟 (¬¬ p) (¬¬ q))))))
(define ((neg f) kq) (∘ kq f))


;;; CPS 箭头

(define-type (→𝒦 p q) (→ p (¬¬ q)))
(define-type (¬𝒦 p)   (→𝒦 p ⊥))

(: flip
   (∀ (p q)
      (case→ (→ (→𝒰 p q) (→𝒦 p q))
             (→ (→𝒦 p q) (→𝒰 p q)))))
(define (((flip f) . y*) . x*) (apply (apply f x*) y*))

(: cps (∀ (p q) (→ (→𝒞 p q) (→𝒦 p q))))
(define cps (∘ flip neg))

(: cps:id (∀ (q) (→𝒦 q q)))
(define cps:id (cps id))


;;; anf: 宏

(define-syntax anf:let*-values
  (syntax-rules ()
    [(_ () b* ...)
     (anf:begin b* ...)]
    [(_ ([v* e]) b* ...)
     (λ (k) (e (λ v* ((anf:begin b* ...) k))))]
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

(define-syntax-rule (anf:let ([v e]) b* ...)
  (anf:let* ([v e]) b* ...))

(define-syntax-rule (anf:if test conseq alt)
  (λ (k) (test (λ b* ((if (equal? b* '(#f)) alt conseq) k)))))

(define-syntax-rule (anf:let/cc cps:k b* ...)
  (cps:call/cc (λ (cps:k) b* ...)))


;;; 两种箭头的复合

(: ∘𝒰 (∀ (p1 p2 p3) (→ (→𝒰 p2 p3) (→𝒰 p1 p2) (→𝒰 p1 p3))))
(define ∘𝒰 ⨾)

;; 借 ∘𝒰 定义 ∘𝒦，可以接任意多支；正文用 anf:let 给的是两支的写法。
(: ∘𝒦 (∀ (p1 p2 p3) (→ (→𝒦 p2 p3) (→𝒦 p1 p2) (→𝒦 p1 p3))))
(define (∘𝒦 . cps:f*) (flip (apply ∘𝒰 (map flip cps:f*))))

(: neg:id (∀ (q) (→𝒰 q q)))
(define neg:id id)


;;; Clavius 律

(: neg:call/cc  (∀ (p) (→𝒰 (→𝒰 (¬𝒰 p) p) p)))
(: cps:call/cc  (∀ (p) (→𝒦 (→𝒦 (¬𝒦 p) p) p)))

(define ((neg:call/cc kp) neg:proc) ((neg:proc kp) (neg kp)))
(define ((cps:call/cc cps:proc) kp) ((cps:proc (cps kp)) kp))



;;; 回到宿主

(: anf:eval (∀ (a) (→ (¬¬ a) a)))
(define (anf:eval kka) (⊥->a (kka a->⊥)))

(: uncps (∀ (p q) (→ (→𝒦 p q) (→𝒞 p q))))
(define (uncps cps:f) (∘ call/cc cps:f))

(: unneg (∀ (p q) (→ (→𝒰 p q) (→𝒞 p q))))
(define unneg (∘ uncps flip))


;;; 再用一次 neg

(: neg² (∀ (p q) (→ (→𝒞 p q) (→𝒟 (¬¬ p) (¬¬ q)))))
(define neg² (∘ neg neg))


;;; 翻译 call/cc

(: neg²:id (∀ (p) (→𝒦 (¬¬ p) p)))
(define (neg²:id kkp) kkp)

(: join (∀ (p q) (→ (→𝒟 p q) (→𝒟 (¬¬ (¬¬ p)) (¬¬ q)))))
(define join (∘ neg cps neg))

(: join:id (∀ (p) (→𝒟 (¬¬ (¬¬ p)) (¬¬ p))))
(define join:id (join id))


;;; CPS 提升的基本操作

(define cps:+         (cps +))
(define cps:*         (cps *))
(define cps:zero?     (cps zero?))
(define cps:car       (cps car))
(define cps:cdr       (cps cdr))
(define cps:null?     (cps null?))
(define cps:display   (cps display))
(define cps:displayln (cps displayln))
}|
