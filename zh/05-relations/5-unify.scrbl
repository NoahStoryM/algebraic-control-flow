#lang acf/scribble

@title[#:tag "05:5-unify"]{合一}

@racket[function->relation] 把函数的结果与最后一个位置合一，可前面几个位置都要先读出值来。@racket[unify] 自己并不在乎哪一边知道、哪一边不知道。

@section[#:tag "05:equation"]{直接写等式}

把合一本身做成一个关系：@racket[(== u v)] 说的是两个项相等，交出的目标让它们合一：

@(define ev-unify (make-acf-eval))
@examples[#:eval ev-unify #:hidden
(require racket/control)
(define ∘ compose)
(define (choose p*) (shift k (append-map k p*)))
(define-syntax-rule (amb e ...) ((choose (list (λ () e) ...))))
(define-syntax-rule (for/amb clauses body ...) ((choose (for/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))
(define ∘ℬ ∘)
(define (list->amb v*) (for/amb ([v (in-list v*)]) v))
(struct var ([name : Symbol]) #:transparent)
(define (walk t s)
  (define p (and (var? t) (assq t s)))
  (if p (walk (cdr p) s) t))
(define (succeed s) s)
(define (fail s) (amb))
(define (conj . g*) (apply ∘ℬ (reverse g*)))
(define ((disj . g*) s) ((list->amb g*) s))
(define (unify u v s)
  (let ([u (walk u s)] [v (walk v s)])
    (cond [(and (var? u) (eq? u v)) s]
          [(var? u) (cons (cons u v) s)]
          [(var? v) (cons (cons v u) s)]
          [(and (pair? u) (pair? v))
           (unify (cdr u) (cdr v) (unify (car u) (car v) s))]
          [(equal? u v) s]
          [else (amb)])))
(define (value-of t s)
  (let ([t (walk t s)])
    (cond [(var? t) (error 'value-of "~a 的值还不知道" (var-name t))]
          [(pair? t) (cons (value-of (car t) s) (value-of (cdr t) s))]
          [else t])))
(define-syntax-rule (run* (x ...) g ...)
  (let ([x (var 'x)] ...)
    (in-amb (value-of (list x ...) ((conj g ...) '())))))]
@examples[#:eval ev-unify #:no-result
(: == (→ Term Term Goal))
(define ((== u v) s) (unify u v s))]

只靠等式，能写出什么样的关系？拿接两张列表来试。@racket[append] 收两张列表，交出接起来的那一张；把它写成三个位置的关系 @racket[(appendᵒ l t out)]：@racket[l] 是空的，@racket[out] 就等于 @racket[t]；或者 @racket[l] 有头一项 @racket[a] 和剩下的 @racket[d]，@racket[out] 的头一项也是 @racket[a]，剩下的部分 @racket[res] 是 @racket[d] 接上 @racket[t]。

这里出现了 @racket[a]、@racket[d]、@racket[res] 三个只在定义里用到的未知项。@racket[run*] 的未知项列在它后面，关系的定义里也要能造自己的：

@examples[#:eval ev-unify #:no-result
(define-syntax-rule (fresh (x ...) g ...)
  (λ (s) (let ([x (var 'x)] ...) ((conj g ...) s))))]

@racket[fresh] 交出的也是目标。它等收到代换时才造未知项，再运行里面的条件：每用一次，造出的都是新的。@racket[appendᵒ] 照上面那句话写下来：

@examples[#:eval ev-unify #:no-result
(define (appendᵒ l t out)
  (disj (conj (== l '()) (== t out))
        (fresh (a d res)
          (== l (cons a d))
          (== out (cons a res))
          (appendᵒ d t res))))]

@racket[appendᵒ] 在第二支里调用自己。要是 @racket[fresh] 一上来就运行里面的条件，构造目标时就会一层层调用下去，停不下来；等到收到代换才运行，递归走几层，看的是代换里的列表有多长。

正着问，它和 @racket[append] 一样：

@examples[#:eval ev-unify #:label #f
(run* (z) (appendᵒ '(1 2) '(3) z))]

反过来，给出接好的那一张，问前两个位置：

@examples[#:eval ev-unify #:label #f
(run* (x y) (appendᵒ x y '(1 2 3)))]

四种拆法都找到了。@racket[append] 只能从左边两张算出右边一张，@racket[appendᵒ] 里每一行都是等式，没有哪个位置是输入，哪个是输出，问哪几个位置都可以。这是关系不分输入输出的样子。这一例倒着问也能把四组找全；换了别的关系、别的问法，搜索不一定停得下来，能不能问是一回事，问了能不能答完是另一回事。由函数和谓词搬来的 @racket[betweenᵒ]、@racket[pythᵒ] 还是只能正着问，它们里面的 @racket[between] 和 @racket[pyth?] 只算已经知道的值。

@section[#:tag "05:reify"]{读出还不知道的项}

等式两边都可以不知道，答案里也就可能有不知道的项：

@examples[#:eval ev-unify #:label #f
(eval:error (run* (x y) (== x y)))]

@racket[(== x y)] 成立，代换里只有一条等式：@racket[x] 等于 @racket[y]。两个都没有值，@racket[value-of] 读不出来。可这组答案并不是空的，它说的是：@racket[x] 与 @racket[y] 是同一个数，至于是几，都可以。答案得能写出这样的意思。

先顺着代换把项里能换的都换掉，换不动的未知项留在原处；再给留下来的未知项依次起名 @tt{_.0}、@tt{_.1}……，同一个未知项用同一个名字：

@(define ev-reify (make-acf-eval))
@examples[#:eval ev-reify #:hidden
(require racket/control)
(define ∘ compose)
(define (choose p*) (shift k (append-map k p*)))
(define-syntax-rule (amb e ...) ((choose (list (λ () e) ...))))
(define-syntax-rule (for/amb clauses body ...) ((choose (for/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))
(define ∘ℬ ∘)
(define (list->amb v*) (for/amb ([v (in-list v*)]) v))
(struct var ([name : Symbol]) #:transparent)
(define (walk t s)
  (define p (and (var? t) (assq t s)))
  (if p (walk (cdr p) s) t))
(define (succeed s) s)
(define (fail s) (amb))
(define (conj . g*) (apply ∘ℬ (reverse g*)))
(define ((disj . g*) s) ((list->amb g*) s))
(define (unify u v s)
  (let ([u (walk u s)] [v (walk v s)])
    (cond [(and (var? u) (eq? u v)) s]
          [(var? u) (cons (cons u v) s)]
          [(var? v) (cons (cons v u) s)]
          [(and (pair? u) (pair? v))
           (unify (cdr u) (cdr v) (unify (car u) (car v) s))]
          [(equal? u v) s]
          [else (amb)])))
(define ((== u v) s) (unify u v s))
(define-syntax-rule (fresh (x ...) g ...)
  (λ (s) (let ([x (var 'x)] ...) ((conj g ...) s))))
(define (appendᵒ l t out)
  (disj (conj (== l '()) (== t out))
        (fresh (a d res)
          (== l (cons a d))
          (== out (cons a res))
          (appendᵒ d t res))))]
@examples[#:eval ev-reify #:no-result
(: walk* (→ Term Subst Term))
(define (walk* t s)
  (let ([t (walk t s)])
    (if (pair? t) (cons (walk* (car t) s) (walk* (cdr t) s)) t)))

(: reify (→ Term Term))
(define (reify t)
  (define (name-unknowns t s)
    (let ([t (walk t s)])
      (cond [(var? t) (cons (cons t (string->symbol (format "_.~a" (length s)))) s)]
            [(pair? t) (name-unknowns (cdr t) (name-unknowns (car t) s))]
            [else s])))
  (walk* t (name-unknowns t '())))]

@racket[reify] 里起名用的也是一张代换，把留下来的未知项换成名字。@racket[run*] 改成这样读出答案。要读的几个未知项放在一张列表里一起读，共用一套名字：

@examples[#:eval ev-reify #:no-result
(define-syntax-rule (run* (x ...) g ...)
  (let ([x (var 'x)] ...)
    (in-amb (reify (walk* (list x ...) ((conj g ...) '()))))))]

@examples[#:eval ev-reify #:label #f
(run* (x y) (== x y))
(run* (x y) succeed)
(run* (x y) (appendᵒ '(1) x y))]

第一组是 @tt{(_.0 _.0)}：两个位置相等，都可以是任何项。第二组是 @tt{(_.0 _.1)}：什么条件也没有，两个位置各自任取。两组答案里都没有一个具体的数，差别全在名字是否相同上。第三组说，@racket[y] 是 @racket[1] 接上 @racket[x]，@racket[x] 是什么都行。

这正是代换说的那种关系。一组带名字的答案不是表里的一行，它代表许多行：@tt{(_.0 _.0)} 代表所有两个位置相等的行，在项上有无穷多。用到 @racket[value-of] 的那一版里，答案都是具体的值，一组就是一行，那只是未知项都有了值的特例。

@margin-note{等式 @racket[(== x (cons 1 x))] 说 @racket[x] 是一张以 @racket[1] 开头、剩下部分又是它自己的列表。这样的项只能无穷无尽地写下去。这里的项都是有限的树，这种等式应当没有解；完整的实现在添等式之前，会先检查这个未知项是否出现在另一边。附录里的代码带着这一步，正文的例子用不到。}
