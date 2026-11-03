#lang acf/scribble

@title[#:tag "03:appendix"]{附录：库代码}

这里收的是这一章定义的局部否定、两种以 @math{a} 为@tech{基}的箭头、控制运算符和 @racket[anf:] 宏，取的是@tech{平凡表示}；@racket[mul]、四个例子、阴阳谜题这些例子，结构体表示下的版本，以及用 @racket[call/cc] 造的定界延续都不在其中。@racket[anf:] 宏和@xref["02:appendix"]{「附录：库代码」}里的一样；@racket[anf:eval] 交进去的@tech{终结延续}换成了 @racket[id]。

@codeblock|{
#lang typed/racket/no-check

(provide (all-defined-out))

(: ∘ (∀ (p ...) (→ (→ pn-1 pn) ... (→ p1 p2) (→ p1 pn))))
(define ∘ compose)
(define id (∘))

(define-type (← q p) (→ p q))
(: ⨾ (∀ (p ...) (→ (← p2 p1) ... (← pn pn-1) (← pn p1))))
(define (⨾ . f*) (apply ∘ (reverse f*)))


;;; 局部否定（平凡表示）
;; a、x 是答案类型参数；类型标注只作设计说明，不经类型检查

(define-type ⊥ (∪))
(define-type ⊥ᵃ a)                            ; 局部空：平凡表示下就是 a
(define-type (¬ₐ p ...) (→ p ... ⊥ᵃ))
(define-type (¬ₐ¬ₐ p) (¬ₐ (¬ₐ p)))
(define-type (¬ₐ¬ₐ¬ₐ p) (¬ₐ (¬ₐ¬ₐ p)))
;; 下标换成 x（¬ₓ、¬ₓ¬ₓ、→𝒰ₓ……），就是以 x 为基的同一组类型

(: a->⊥ᵃ (∀ (a) (¬ₐ a)))
(define a->⊥ᵃ id)


;;; 宿主的箭头

(define-type (→𝒟 p ... q) (→ p ... q))


;;; 以 a 为基的两种箭头
;; ¬ 的下标是落点，箭头的下标是基；¬ 后面没有下标就落在全局的 ⊥ 上

(define-type (→𝒰ₐ p ... q) (← (¬ₐ p ...) (¬ₐ q)))
(define-type (→𝒦ₐ p ... q) (→ p ... (¬ₐ¬ₐ q)))

(define-type (¬ₐ𝒰ₓ p ...) (→𝒰ₓ p ... ⊥ᵃ))
(define-type (¬ₐ𝒦ₓ p ...) (→𝒦ₓ p ... ⊥ᵃ))
(define-type (¬𝒰ₐ  p ...) (→𝒰ₐ p ... ⊥))
(define-type (¬𝒦ₐ  p ...) (→𝒦ₐ p ... ⊥))

(: neg (∀ (p q a x) (case→ (→ (→𝒟 p q) (→𝒰ₓ  p q))
                           (→ (¬ₐ  p)  (¬ₐ𝒰ₓ p)))))
(define ((neg f) kq) (∘ kq f))

(: neg* (∀ (p a) (→ (¬ₐ p) (¬𝒰ₐ p))))
(define ((neg* kₐp) k) kₐp)

(: flip (∀ (p q a) (case→ (→ (→𝒰ₐ p q) (→𝒦ₐ p q))
                        (→ (→𝒦ₐ p q) (→𝒰ₐ p q)))))
(define (((flip f) . y*) . x*) (apply (apply f x*) y*))

(: cps  (∀ (p q a x) (case→ (→ (→𝒟 p q) (→𝒦ₓ  p q))
                            (→ (¬ₐ  p)  (¬ₐ𝒦ₓ p)))))
(: cps* (∀ (p a) (→ (¬ₐ p) (¬𝒦ₐ p))))
(define cps  (∘ flip neg))
(define cps* (∘ flip neg*))


;;; 控制运算符

(: neg:call/lc (∀ (p a) (→𝒰ₐ (→𝒰ₐ (¬ₐ𝒰ₐ p) p) p)))
(define ((neg:call/lc kₐp) neg:proc) ((neg:proc kₐp) (neg kₐp)))

(: neg:call/cc (∀ (p a) (→𝒰ₐ (→𝒰ₐ (¬𝒰ₐ p) p) p)))
(define ((neg:call/cc kₐp) neg:proc) ((neg:proc kₐp) (neg* kₐp)))

(: cps:call/lc (∀ (p a) (→𝒦ₐ (→𝒦ₐ (¬ₐ𝒦ₐ p) p) p)))
(: cps:call/cc (∀ (p a) (→𝒦ₐ (→𝒦ₐ (¬𝒦ₐ  p) p) p)))

(define ((cps:call/lc cps:proc) kₐp) ((cps:proc (cps  kₐp)) kₐp))
(define ((cps:call/cc cps:proc) kₐp) ((cps:proc (cps* kₐp)) kₐp))


;;; 求值与边界

(: cps:id (∀ (p a) (→𝒦ₐ p p)))
(define cps:id (cps id))

(: anf:eval (∀ (a) (¬ₐ¬ₐ¬ₐ a)))
(define anf:eval (cps:id a->⊥ᵃ))

(: anf:reset (∀ (a x) (→ (¬ₐ¬ₐ a) (¬ₓ¬ₓ a))))
(define anf:reset (cps anf:eval))

(define cps:abort (cps* a->⊥ᵃ))


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

(define-syntax-rule (anf:let/lc cps:k b* ...)
  (cps:call/lc (λ (cps:k) b* ...)))

(define-syntax-rule (anf:shift cps:k e)
  (anf:let/lc cps:k
    (anf:let* ([v e])
      (cps:abort v))))


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
