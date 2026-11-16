#lang acf/scribble

@title[#:tag "05:appendix"]{附录：库代码}

这里收的是这一章造出的东西：不确定运算符、关系的两种写法，以及关系语言。直角三角形、@racket[appendᵒ] 这些例子不在其中。关系语言的 @racket[run*] 是读出还不知道的项的那一版；@racket[ext-s] 在添等式之前检查未知项是否出现在另一边，正文从略。

@codeblock|{
#lang typed/racket/no-check

(require racket/control)
(provide (all-defined-out))

(: ∘ (∀ (p ...) (→ (→ pn-1 pn) ... (→ p1 p2) (→ p1 pn))))
(define ∘ compose)

;; 不确定运算符

(: choose (∀ (p) (→ (Listof p) p)))
(define (choose p*) (shift k (append-map k p*)))

(define-syntax-rule (amb e ...) ((choose (list (λ () e) ...))))
(define-syntax-rule (for/amb  clauses body ...) ((choose (for/list  clauses (λ () body ...)))))
(define-syntax-rule (for*/amb clauses body ...) ((choose (for*/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))

(: check (→ Boolean Void))
(define (check ok?) (unless ok? (amb)))

;; 关系的两种写法

(define-type (→𝒞 p q) (→ p q))
(define-type (→ℬ p q) (→ p q))
(define-type (→ℒ p q) (→ p (Listof q)))

(: inj (∀ (p q) (→ (→𝒞 p q) (→ℬ p q))))
(define (inj f) f)

(: ∘ℬ (∀ (p ...) (→ (→ℬ pn-1 pn) ... (→ℬ p1 p2) (→ℬ p1 pn))))
(define ∘ℬ ∘)

(: list->amb (∀ (p) (→ (Listof p) p)))
(define (list->amb v*) (for/amb ([v (in-list v*)]) v))

(: scatter (∀ (p q) (→ (→ℒ p q) (→ℬ p q))))
(define (scatter f) (∘ list->amb f))

(: gather (∀ (p q) (→ (→ℬ p q) (→ℒ p q))))
(define ((gather g) . x*) (in-amb (apply g x*)))

(: ∘ℒ (∀ (p ...) (→ (→ℒ pn-1 pn) ... (→ℒ p1 p2) (→ℒ p1 pn))))
(define (∘ℒ . f*)
  (define-values (g* f) (split-at-right f* 1))
  (λ x* (foldr append-map (apply (car f) x*) g*)))

;; 关系语言

(struct var ([name : Symbol]) #:transparent)
(define-type Term (∪ Var Boolean Number Symbol Null (Pair Term Term)))
(define-type Subst (Listof (Pair Var Term)))
(define-type Goal (→ℬ Subst Subst))

(: walk (→ Term Subst Term))
(define (walk t s)
  (define p (and (var? t) (assq t s)))
  (if p (walk (cdr p) s) t))

(: walk* (→ Term Subst Term))
(define (walk* t s)
  (let ([t (walk t s)])
    (if (pair? t) (cons (walk* (car t) s) (walk* (cdr t) s)) t)))

(: occurs? (→ Var Term Subst Boolean))
(define (occurs? x t s)
  (let ([t (walk t s)])
    (cond [(var? t) (eq? x t)]
          [(pair? t) (or (occurs? x (car t) s) (occurs? x (cdr t) s))]
          [else #f])))

(: ext-s (→ Var Term Subst Subst))
(define (ext-s x t s)
  (when (occurs? x t s) (amb))
  (cons (cons x t) s))

(: unify (→ Term Term Subst Subst))
(define (unify u v s)
  (let ([u (walk u s)] [v (walk v s)])
    (cond [(and (var? u) (eq? u v)) s]
          [(var? u) (ext-s u v s)]
          [(var? v) (ext-s v u s)]
          [(and (pair? u) (pair? v))
           (unify (cdr u) (cdr v) (unify (car u) (car v) s))]
          [(equal? u v) s]
          [else (amb)])))

(: value-of (→ Term Subst Term))
(define (value-of t s)
  (let ([t (walk t s)])
    (cond [(var? t) (error 'value-of "~a 的值还不知道" (var-name t))]
          [(pair? t) (cons (value-of (car t) s) (value-of (cdr t) s))]
          [else t])))

(: reify (→ Term Term))
(define (reify t)
  (define (name-unknowns t s)
    (let ([t (walk t s)])
      (cond [(var? t) (cons (cons t (string->symbol (format "_.~a" (length s)))) s)]
            [(pair? t) (name-unknowns (cdr t) (name-unknowns (car t) s))]
            [else s])))
  (walk* t (name-unknowns t '())))

(: succeed Goal)
(: fail Goal)
(define (succeed s) s)
(define (fail s) (amb))

(: == (→ Term Term Goal))
(define ((== u v) s) (unify u v s))

(: conj (→ Goal ... Goal))
(: disj (→ Goal ... Goal))
(define (conj . g*) (apply ∘ℬ (reverse g*)))
(define ((disj . g*) s) ((list->amb g*) s))

(define-syntax-rule (fresh (x ...) g ...)
  (λ (s) (let ([x (var 'x)] ...) ((conj g ...) s))))

(define-syntax-rule (run* (x ...) g ...)
  (let ([x (var 'x)] ...)
    (in-amb (reify (walk* (list x ...) ((conj g ...) '()))))))

(define (((function->relation f) . t*) s)
  (define-values (in* out*) (split-at-right t* 1))
  (unify (car out*) (apply f (for/list ([t in*]) (value-of t s))) s))

(define (((predicate->relation p?) . t*) s)
  (check (apply p? (for/list ([t t*]) (value-of t s))))
  s)

;; 关系的世界

(define (idᵒ x y) (== x y))

(define (∘ᵒ . r*)
  (if (null? r*)
      idᵒ
      (λ (x z)
        (fresh (y)
          ((apply ∘ᵒ (cdr r*)) x y)
          ((car r*) y z)))))
}|
