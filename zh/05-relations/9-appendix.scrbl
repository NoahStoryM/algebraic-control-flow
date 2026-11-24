#lang acf/scribble

@title[#:tag "05:appendix"]{附录：库代码}

这里收的是这一章造出的东西：@tech{不确定运算符}、@tech{关系}的两种写法，以及关系语言。直角三角形、@racket[appendᵒ] 这些例子不在其中。关系语言的完整实现在正文的基础上补上了添等式前检查循环的 @racket[occurs?] 与 @racket[ext-s]（见@xref["05:reify"]{「开放世界与未定下来的答案」}的旁注），并把 @racket[run*] 定义为 @racket[run] 的语法糖（@tt{_.0} 是沿用惯例的显示记号，若项里本来就含有符号 @racket['_.0]，读出后会撞名）。

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
(define-syntax-rule (for/amb clauses body ...)
  ((choose (for/list clauses (λ () body ...)))))
(define-syntax-rule (for*/amb clauses body ...)
  ((choose (for*/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))

(: check (→ Boolean Void))
(define (check ok?) (unless ok? (amb)))

;; 关系的两种写法

(define-type (→𝒞 p ... q) (→ p ... q))
(define-type (→ℬ p ... q) (→ p ... q))
(define-type (→ℒ p ... q) (→ p ... (Listof q)))

(: inj (∀ (p ... q) (→ (→𝒞 p ... q) (→ℬ p ... q))))
(define (inj f) f)

(: ∘ℬ (∀ (p ...) (→ (→ℬ pn-1 pn) ... (→ℬ p1 p2) (→ℬ p1 pn))))
(define ∘ℬ ∘)

(: list->amb (∀ (p) (→ (Listof p) p)))
(define (list->amb v*) (for/amb ([v (in-list v*)]) v))

(: scatter (∀ (p ... q) (→ (→ℒ p ... q) (→ℬ p ... q))))
(define (scatter f) (∘ list->amb f))

(: gather (∀ (p ... q) (→ (→ℬ p ... q) (→ℒ p ... q))))
(define ((gather g) . x*) (in-amb (apply g x*)))

(: ∘ℒ (∀ (p ...) (→ (→ℒ pn-1 pn) ... (→ℒ p1 p2) (→ℒ p1 pn))))
(define ∘ℒ
  (case-λ
    [() (λ (x) (list x))]
    [f* (define-values (g* f) (split-at-right f* 1))
        (λ x* (foldr append-map (apply (car f) x*) g*))]))

(: flat-map (∀ (p q) (→ (→ℒ p q) (→𝒞 (Listof p) (Listof q)))))
(define ((flat-map g) p*) (append-map g p*))

;; 关系语言

(define-type (Dictionary k v) (Listof (Pair k v)))
(struct var ([name : Symbol]) #:type-name Var #:transparent)
(define-type Literal (∪ Boolean Number Char Bytes String Keyword Null Symbol))
(define-type Data (∪ Literal (Pair Data Data)))
(define-type Term (∪ Literal Var (Pair Term Term)))
(define-type Substitution (Dictionary Var Term))
(define-type Goal (→ℬ Substitution Substitution))

(: walk (→ Term Substitution Term))
(define (walk t s)
  (define p (and (var? t) (assq t s)))
  (if p (walk (cdr p) s) t))

(: walk* (→ Term Substitution Term))
(define (walk* t s)
  (let ([t (walk t s)])
    (if (pair? t) (cons (walk* (car t) s) (walk* (cdr t) s)) t)))

(: occurs? (→ Var Term Substitution Boolean))
(define (occurs? x t s)
  (let ([t (walk t s)])
    (cond [(var? t) (eq? x t)]
          [(pair? t) (or (occurs? x (car t) s) (occurs? x (cdr t) s))]
          [else #f])))

(: ext-s (→ Var Term Substitution Substitution))
(define (ext-s x t s)
  (when (occurs? x t s) (amb))
  (cons (cons x t) s))

(: unify (→ Term Term Substitution Substitution))
(define (unify u v s)
  (let ([u (walk u s)] [v (walk v s)])
    (cond [(and (var? u) (eq? u v)) s]
          [(var? u) (ext-s u v s)]
          [(var? v) (ext-s v u s)]
          [(and (pair? u) (pair? v))
           (unify (cdr u) (cdr v) (unify (car u) (car v) s))]
          [(equal? u v) s]
          [else (amb)])))

(: value-of (→ Term Substitution Data))
(define (value-of t s)
  (let ([t (walk t s)])
    (cond [(var? t) (error 'value-of "~a 的值还不知道" (var-name t))]
          [(pair? t) (cons (value-of (car t) s) (value-of (cdr t) s))]
          [else t])))

(: reify (→ Term Data))
(define (reify t)
  (define (name-unknowns t s)
    (let ([t (walk t s)])
      (cond [(var? t)
             (cons (cons t (string->symbol (format "_.~a" (length s)))) s)]
            [(pair? t) (name-unknowns (cdr t) (name-unknowns (car t) s))]
            [else s])))
  (walk* t (name-unknowns t '())))

(: ⊤ Goal)
(: ⊥ Goal)
(define (⊤ s) s)
(define (⊥ s) (amb))

(: ≡ (→ Term Term Goal))
(define ((≡ u v) s) (unify u v s))

(: ∧ (→ Goal ... Goal))
(: ∨ (→ Goal ... Goal))
(define (∧ . g*) (apply ∘ℬ (reverse g*)))
(define ((∨ . g*) s) ((list->amb g*) s))

(define-syntax-rule (∃ (x ...) g)
  (λ (s) (let ([x (var 'x)] ...) (g s))))

(define-syntax-rule (run n (x ...) g ...)
  (let ([limit n])
    (let ([x (var 'x)] ...)
      (define ans*
        (in-amb (reify (walk* (list x ...) ((∧ g ...) '())))))
      (if limit (take ans* (min limit (length ans*))) ans*))))

(define-syntax-rule (run* (x ...) g ...)
  (run #f (x ...) g ...))

(define-syntax-rule (fresh (x ...) g ...)
  (∃ (x ...) (∧ g ...)))

(define-syntax-rule (condᵉ [g ...] ...)
  (∨ (∧ g ...) ...))

(: function->relation (∀ (a ... b) (→ (→ℬ a ... b) (→ Term ... Term Goal))))
(define (((function->relation f) . t*) s)
  (define-values (in* out*) (split-at-right t* 1))
  (unify (car out*) (apply f (for/list ([t in*]) (value-of t s))) s))

(: predicate->relation (∀ (a ...) (→ (→ a ... Boolean) (→ Term ... Goal))))
(define (((predicate->relation p?) . t*) s)
  (check (apply p? (for/list ([t t*]) (value-of t s))))
  s)

;; 关系的复合与单位

(: idᵒ (→ Term Term Goal))
(define idᵒ ≡)

(: ∘ᵒ (→ (→ Term Term Goal) ... (→ Term Term Goal)))
(define ∘ᵒ
  (case-λ
    [() idᵒ]
    [(Pᵒ) Pᵒ]
    [(Qᵒ . Pᵒ*)
     (define Pᵒ (apply ∘ᵒ Pᵒ*))
     (λ (x z) (∃ (y) (∧ (Pᵒ x y) (Qᵒ y z))))]))
}|

本章的 @racket[in-amb] 一次算完并交出整张列表，只处理有限搜索；如果想在 Racket 里使用带@tech{惰性}序列与公平搜索的完整实现，可以参考 @hyperlink["https://github.com/NoahStoryM/amb"]{amb}（提供@tech{惰性}的 @racket[in-amb] 与可暂停的搜索）以及建在它之上的 @hyperlink["https://github.com/NoahStoryM/ambKanren"]{ambKanren}。
