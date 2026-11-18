#lang acf/scribble

@title[#:tag "05:5-unify"]{合一}

照手写 @racket[g] 的办法，把这样两行条件记进表里：@racket[x] 等于 @racket[y]，@racket[y] 等于 5。然后问 @racket[x] 的值：

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
(struct var ([name : Symbol]) #:type-name Var #:transparent)
(define (value-of t s)
  (cond [(not (var? t)) t]
        [(assq t s) => cdr]
        [else (error 'value-of "~a 的值还不知道" (var-name t))]))
(define (conj . g*) (apply ∘ℬ (reverse g*)))
(define-syntax-rule (run* (x ...) g ...)
  (let ([x (var 'x)] ...)
    (in-amb
     (let ([s ((conj g ...) '())])
       (list (value-of x s) ...)))))]
@examples[#:eval ev-unify #:label #f
(let* ([x (var 'x)] [y (var 'y)]
       [s (list (cons x y) (cons y 5))])
  (value-of x s))]

表记下来了，值却读不对。@racket[x] 对着 @racket[y]，@racket[value-of] 只查了一次，交出的是一个未知项；可 @racket[y] 的值，表里明明有。值可以是另一个未知项的时候，查表要顺着查下去，查到一个不在表里的项为止：

@examples[#:eval ev-unify #:no-result
(: walk (→ Term Substitution Term))
(define (walk t s)
  (define p (and (var? t) (assq t s)))
  (if p (walk (cdr p) s) t))]

@examples[#:eval ev-unify #:label #f
(let* ([x (var 'x)] [y (var 'y)]
       [s (list (cons x y) (cons y 5))])
  (walk x s))]

添一行也不能照旧了。比如表里已经记着 @racket[x] 等于 5，再来一行条件说 @racket[x] 等于 6，直接添上，@racket[x] 就占了两行；条件要是写成 6 等于 @racket[x]，键还成了一个数。添之前，两边都要先顺着表查到底，再比：有一边是未知项，就添上一行；两边都是序对，逐项去对；否则相等才走得通：

@examples[#:eval ev-unify #:no-result
(: unify (→ Term Term Substitution Substitution))
(define (unify u v s)
  (let ([u (walk u s)] [v (walk v s)])
    (cond [(and (var? u) (eq? u v)) s]
          [(var? u) (cons (cons u v) s)]
          [(var? v) (cons (cons v u) s)]
          [(and (pair? u) (pair? v))
           (unify (cdr u) (cdr v) (unify (car u) (car v) s))]
          [(equal? u v) s]
          [else (amb)])))]

@examples[#:eval ev-unify #:label #f
(let ([x (var 'x)] [y (var 'y)])
  (in-amb (unify x y '())))
(let ([a (var 'a)] [b (var 'b)])
  (in-amb (unify (list a 2) (list 1 b) '())))
(let ([x (var 'x)])
  (in-amb (unify 6 x (list (cons x 5)))))]

头一例两边都不知道，添的一行记着 @racket[x] 等于 @racket[y]。第二例是两张各缺一项的列表，逐项去对，@racket[a] 对上 1，@racket[b] 对上 2：两边都从对面得到了自己缺的那一项。第三例里 @racket[x] 查到 5，与 6 对不上，这条时间线走不通，@racket[in-amb] 一张代换也没有收到。

让两个项相等，必要时往代换里添一行，这件事叫@defterm[#:en "unification"]{合一}。添的总是一个还没在表里的未知项，所以键不会重复。代换也跟着变了样：一行记的不再是某个未知项的值，而是一条等式。

把合一本身做成一个关系：@racket[(== u v)] 说的是两个项相等，交出的目标让它们合一。

@examples[#:eval ev-unify #:no-result
(: == (→ Term Term Goal))
(define ((== u v) s) (unify u v s))]

@racket[value-of] 也改成顺着查；项是序对，就逐项读：

@examples[#:eval ev-unify #:no-result
(: value-of (→ Term Substitution Term))
(define (value-of t s)
  (let ([t (walk t s)])
    (cond [(var? t) (error 'value-of "~a 的值还不知道" (var-name t))]
          [(pair? t) (cons (value-of (car t) s) (value-of (cdr t) s))]
          [else t])))]

@examples[#:eval ev-unify #:label #f
(run* (x y) (== x y) (== y 5))
(run* (x y) (== x 1) (== 2 y))
(run* (x) (== x 5) (== 6 x))]

未知项写在等式的哪一边都可以，两边都是未知项也可以。

@racket[function->relation] 原先默认最后一个位置是还没有值的未知项，直接添一行。现在让它与函数交出的值合一：没有值就添一行，有值就成了核对。

@examples[#:eval ev-unify #:no-result
(define (((function->relation f) . t*) s)
  (define-values (in* out*) (split-at-right t* 1))
  (unify (car out*) (apply f (for/list ([t in*]) (value-of t s))) s))]

@section[#:tag "05:equation"]{直接写等式}

@racket[append] 把两张列表接成一张。它是函数，只能从左边两张算出右边一张。照它的定义写一个三个位置的关系 @racket[(appendᵒ l t out)]：@racket[l] 是空的，@racket[out] 就等于 @racket[t]；或者 @racket[l] 有头一项 @racket[a] 和剩下的 @racket[d]，@racket[out] 的头一项也是 @racket[a]，剩下的部分 @racket[res] 是 @racket[d] 接上 @racket[t]。

这句话里有两样东西还写不出来。一样是「或者」：两种情形里成立一种就行。目标是带 @racket[amb] 的函数，从几个目标里挑一个来用，挑哪个都算，正是 @racket[amb]。几个条件里只要有一个成立，叫@tech{析取}：

@examples[#:eval ev-unify #:no-result
(: disj (→ Goal ... Goal))
(define ((disj . g*) s) ((list->amb g*) s))]

@examples[#:eval ev-unify #:label #f
(run* (x) (disj (== x 1) (== x 2)))]

@margin-note{目标写成 ℒ 的箭头时，析取是把几张代换的列表接起来。}

两个目标都是从代换到代换的二元关系，表的两列对得上，析取就是把两张表并起来。

@racket[conj] 与 @racket[disj] 都不限目标的个数。一个也不给呢？拿一张记着 @racket[a] 等于 1 的代换，各试一次：

@examples[#:eval ev-unify #:label #f
(let ([a (var 'a)])
  (in-amb ((conj) (list (cons a 1)))))
(let ([a (var 'a)])
  (in-amb ((disj) (list (cons a 1)))))]

零个目标的合取把代换原样交了回来，一行也没有添：@racket[(∘ℬ)] 是恒等函数。零个目标的析取一张也不交：从零个备选里挑，就是 @racket[(amb)]。作为代换之间的二元关系，一个是@defterm[#:en "identity relation"]{恒等关系}，一个是一行也没有的@defterm[#:en "empty relation"]{空关系}；作为条件，一个总成立，一个总不成立。给它们各起一个名字：

@examples[#:eval ev-unify #:no-result
(: succeed Goal)
(: fail Goal)
(define (succeed s) s)
(define (fail s) (amb))]

@racket[succeed] 接在哪个目标的前面或后面，都不改变那个目标；@racket[fail] 和哪个目标并起来，也不改变那个目标。一个是合取的@defterm[#:en "unit"]{单位}，一个是析取的单位。

另一样是 @racket[a]、@racket[d]、@racket[res]：三个只在定义里用到的未知项。@racket[run*] 的未知项列在它后面，关系的定义里也要能造自己的：

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

四种拆法都找到了。定义 @racket[appendᵒ] 的时候，没有哪一行写过「拆」：每一行都是等式，没有哪个位置是输入，哪个是输出。这是关系不分输入输出的样子。

@section[#:tag "05:reify"]{读出还不知道的项}

等式两边都可以不知道，答案里也就可能有不知道的项：

@examples[#:eval ev-unify #:label #f
(eval:error (run* (x y) (== x y)))]

@racket[(== x y)] 成立，代换里只有一条等式：@racket[x] 等于 @racket[y]。两个都没有值，@racket[value-of] 读不出来。可这组答案并不是空的，它说的是：@racket[x] 与 @racket[y] 是同一个数，至于是几，都可以。

答案里要写得出「同一个，是几都行」，就给换不动的未知项起名字，@tt{_.0}、@tt{_.1}，依次排下去；同一个未知项用同一个名字。把还不知道的项写成看得见的名字，这一步叫 @racket[reify]：

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
(struct var ([name : Symbol]) #:type-name Var #:transparent)
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
(: walk* (→ Term Substitution Term))
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

@racket[walk*] 顺着代换把项里能换的都换掉，换不动的未知项留在原处。@racket[reify] 里起名用的也是一张代换，把留下来的未知项换成名字。@racket[run*] 改成这样读出答案。要读的几个未知项放在一张列表里一起读，共用一套名字：

@examples[#:eval ev-reify #:no-result
(define-syntax-rule (run* (x ...) g ...)
  (let ([x (var 'x)] ...)
    (in-amb (reify (walk* (list x ...) ((conj g ...) '()))))))]

@examples[#:eval ev-reify #:label #f
(run* (x y) (== x y))
(run* (x y) succeed)
(run* (x y) (appendᵒ '(1) x y))]

第一组是 @tt{(_.0 _.0)}：两个位置相等，都可以是任何项。第二组是 @tt{(_.0 _.1)}：什么条件也没有，两个位置各自任取。两组答案里都没有一个具体的数，差别全在名字是否相同上。第三组说，@racket[y] 是 @racket[1] 接上 @racket[x]，@racket[x] 是什么都行。

代换里 @racket[x] 对着 @racket[y] 的那一行，现在读得出来了。它没有说 @racket[x] 是几，所以一张代换不是一组答案：它说的是未知项之间要满足的关系，凡是满足这些等式的取值都算数。一组带名字的答案也就不是表里的一行，它代表许多行：@tt{(_.0 _.0)} 代表所有两个位置相等的行，在项上有无穷多。用到 @racket[value-of] 的那一版里，答案都是具体的值，一组就是一行，那只是未知项都有了值的特例。

@margin-note{等式 @racket[(== x (cons 1 x))] 说 @racket[x] 是一张以 @racket[1] 开头、剩下部分又是它自己的列表。这样的项只能无穷无尽地写下去。这里的项都是有限的树，这种等式应当没有解；完整的实现在添等式之前，会先检查这个未知项是否出现在另一边。附录里的代码带着这一步，正文的例子用不到。}
