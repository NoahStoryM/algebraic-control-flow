#lang acf/scribble

@title[#:tag "05:appendix"]{附录：库代码}

@margin-note{这里把 @racket[run*] 定义为 @racket[run] 的语法糖。@tt{_.0} 是沿用惯例的显示记号，若项里本来就含有符号 @racket['_.0]，读出后会撞名。}

这里把这一章造出的两块核心代码收在一起：第一部分是@tech{不确定运算符} @racket[amb]，第二部分是建在它之上的 @racket[miniKanren] 核心。直角三角形、@racket[appendᵒ] 以及过渡用的宿主包装函数都不收在这里。

第一部分是 @racket[amb]（保存为 @tt{amb.rkt}）：

@codeblock|{
#lang typed/racket/no-check

(require racket/control)
(provide (all-defined-out))

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

(: list->amb (∀ (p) (→ (Listof p) p)))
(define (list->amb v*) (for/amb ([v (in-list v*)]) v))
}|

第二部分是建在它之上的 @racket[miniKanren] 核心（引入上面的 @tt{amb.rkt}）：

@codeblock|{
#lang typed/racket/no-check

(require "amb.rkt")
(provide (all-defined-out))

(define-type (Dictionary k v) (Listof (Pair k v)))
(struct var ([name : Symbol]) #:type-name Var #:transparent)
(: var=? (→ Var Var Boolean))
(define (var=? u v) (eq? u v))
(define-type Literal (∪ Boolean Number Char Bytes String Keyword Null Symbol))
(define-type Data (∪ Literal (Pair Data Data)))
(define-type Term (∪ Literal Var (Pair Term Term)))
(define-type Substitution (Dictionary Var Term))
(define-type Goal (→ Substitution Substitution))

(: empty-s Substitution)
(define empty-s '())

(: size-s (→ Substitution Natural))
(define (size-s s) (length s))

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
    (cond
      [(var? t) (var=? x t)]
      [(pair? t) (or (occurs? x (car t) s) (occurs? x (cdr t) s))]
      [else #f])))

(: ext-s (→ Var Term Substitution Substitution))
(define (ext-s x t s)
  (when (occurs? x t s) (amb))
  (cons (cons x t) s))

(: unify (→ Term Term Substitution Substitution))
(define (unify u v s)
  (let ([u (walk u s)] [v (walk v s)])
    (cond
      [(and (var? u) (var? v) (var=? u v)) s]
      [(var? u) (ext-s u v s)]
      [(var? v) (ext-s v u s)]
      [(and (pair? u) (pair? v))
       (unify (cdr u) (cdr v) (unify (car u) (car v) s))]
      [(equal? u v) s]
      [else (amb)])))

(: reify-name (→ Natural Symbol))
(define (reify-name n)
  (string->symbol (format "_.~a" n)))

(: reify-s (→ Term Substitution Substitution))
(define (reify-s v r)
  (let ([v (walk v r)])
    (cond
      [(var? v) (ext-s v (reify-name (size-s r)) r)]
      [(pair? v) (reify-s (cdr v) (reify-s (car v) r))]
      [else r])))

(: reify (→ Term (→ Substitution Term)))
(define ((reify v) s)
  (let* ([v (walk* v s)]
         [r (reify-s v empty-s)])
    (walk* v r)))

;; 核心组合子

(: ⊤ Goal)
(: ⊥ Goal)
(define (⊤ s) s)
(define (⊥ s) (amb))

(: ≡ (→ Term Term Goal))
(define ((≡ u v) s) (unify u v s))

(: ∧ (→ Goal ... Goal))
(: ∨ (→ Goal ... Goal))
(define (∧ . g*) (apply compose (reverse g*)))
(define ((∨ . g*) s) ((list->amb g*) s))

(define-syntax-rule (∃ (x ...) g)
  (λ (s) (let ([x (var 'x)] ...) (g s))))

;; 表面语法

(define-syntax-rule (run n (x ...) g ...)
  (let ([limit n])
    (let ([x (var 'x)] ...)
      (define ans*
        (in-amb ((reify (list x ...)) ((∧ g ...) empty-s))))
      (if limit (take ans* (min limit (length ans*))) ans*))))

(define-syntax-rule (run* (x ...) g ...)
  (run #f (x ...) g ...))

(define-syntax-rule (fresh (x ...) g ...)
  (∃ (x ...) (∧ g ...)))

(define-syntax-rule (condᵉ [g ...] ...)
  (∨ (∧ g ...) ...))

(: succeed Goal)
(: fail Goal)
(define succeed ⊤)
(define fail ⊥)
}|

本章的 @racket[in-amb] 一次算完并交出整张列表，只处理有限搜索；如果想在 Racket 里使用带@tech{惰性}序列与公平搜索的完整实现，可以参考 @hyperlink["https://github.com/NoahStoryM/amb"]{amb}（提供@tech{惰性}的 @racket[in-amb] 与可暂停的搜索）以及建在它之上的 @hyperlink["https://github.com/NoahStoryM/ambKanren"]{ambKanren}。
