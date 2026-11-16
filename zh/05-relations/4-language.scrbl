#lang acf/scribble

@title[#:tag "05:4-language"]{描述关系的语言}

到这里，关系都是用函数模拟的：交出列表的函数，或者带 @racket[amb] 的函数。函数分输入和输出，关系不分。

@section[#:tag "05:wanted"]{想要的写法}

在 @racket[amb] 版的搜索里，两个关系的用法就不一样：

@racketblock[
(let* ([a (between l h)]
       [b (between a h)]
       [c (between b h)])
  (check (pyth? a b c))
  (list a b c))]

@racket[between] 是交出结果的函数，写在绑定的右边，取出一个数来；@racket[pyth?] 是谓词，只回答是或否，要靠 @racket[check] 才用得上。一个取，一个查。它们描述的却是同一类东西：@racket[between] 是边界与其间的数之间的关系，@racket[pyth?] 是三条边之间的关系。取与查的分别来自函数，不来自关系。

设想有一门语言，直接写关系。@racket[between] 和 @racket[pyth?] 在其中各有对应的关系，名字后面添一个上标 ᵒ：

@racketblock[
(define betweenᵒ (function->relation  between))
(define pythᵒ    (predicate->relation pyth?))]

@racket[(pythᵒ a b c)] 说的是 @racket[a]、@racket[b]、@racket[c] 满足勾股定理。@racket[between] 收两个数交出一个，@racket[betweenᵒ] 就有三个位置，结果排在最后：@racket[(betweenᵒ l h a)] 说的是 @racket[a] 在 @racket[l] 与 @racket[h] 之间。两个关系的写法一样，不再分取与查。搜索写成：

@racketblock[
(define (right-triangles l h)
  (run* (a b c)
    (betweenᵒ l h a)     (code:comment "l ≤ a ≤ h")
    (betweenᵒ a h b)     (code:comment "a ≤ b ≤ h")
    (betweenᵒ b h c)     (code:comment "b ≤ c ≤ h")
    (pythᵒ a b c)))      (code:comment "a² + b² = c²")]

与 @racket[amb] 版一行对一行：三个绑定成了三行 @racket[betweenᵒ]，@racket[check] 的一行成了 @racket[pythᵒ]，最后交出的 @racket[(list a b c)] 挪到了 @racket[run*] 后面，@racket[in-amb] 那一层也收进了 @racket[run*]。它读起来更像集合的写法：@racket[run*] 是花括号，@racket[(a b c)] 是竖线左边的形状，下面四行是竖线右边的条件，要同时成立。

这还只是想要的写法，@racket[function->relation]、@racket[predicate->relation]、@racket[run*] 都还没有。改写里有一处不只是换名字：@racket[a]、@racket[b]、@racket[c] 原来由 @racket[let*] 绑定，每一行右边算出一个值，交给左边的名字；现在它们列在 @racket[run*] 后面，是三个还不知道的数，四行条件各说了一件关于它们的事。没有了绑定，这三个名字是什么？一行 @racket[(betweenᵒ l h a)] 写在那里，又交出了什么？

@section[#:tag "05:goals"]{未知项、代换与目标}

@racket[a] 不是哪个数的名字，它代表一个还不知道的数；可三行条件里写的 @racket[a] 必须是同一个。没有值可以比，那就为它新造一个东西，带上一个名字：

@(define ev-goals (make-acf-eval))
@examples[#:eval ev-goals #:hidden
(require racket/control)
(define ∘ compose)
(define-type (Dict k v) (Listof (Pair k v)))
(define (pyth? a b c) (= (+ (* a a) (* b b)) (* c c)))
(define (choose p*) (shift k (append-map k p*)))
(define-syntax-rule (amb e ...) ((choose (list (λ () e) ...))))
(define-syntax-rule (for/amb clauses body ...) ((choose (for/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))
(define (between lo hi) (for/amb ([n (inclusive-range lo hi)]) n))
(define (check ok?) (unless ok? (amb)))
(define-type (→ℬ p q) (→ p q))
(define ∘ℬ ∘)
(define (list->amb v*) (for/amb ([v (in-list v*)]) v))]
@examples[#:eval ev-goals #:no-result
(struct var ([name : Symbol]) #:transparent)]

@examples[#:eval ev-goals #:label #f
(var 'a)
(eq? (var 'a) (var 'a))
(let ([a (var 'a)]) (eq? a a))]

造两次，打印出来一模一样，@racket[eq?] 却说它们是两个；同一次造出的才是同一个。名字只用来打印，分辨靠的是身份。这样的东西叫@defterm[#:en "logic variable"]{未知项}。数、符号这些值是@defterm[#:en "term"]{项}，未知项也是项，由项组成的序对还是项：

@examples[#:eval ev-goals #:no-result
(define-type Term (∪ Var Boolean Number Symbol Null (Pair Term Term)))]

四行条件读下来，我们对这三个未知项知道得越来越多。读完 @racket[(betweenᵒ l h a)]，就知道 @racket[a] 等于范围里的某个数。知道的事要记下来，记在一张表里：键是未知项，值是它等于的那个项。键不重复，这正是@xref["05:search"]{「遍历搜索」}里缓存用的那种字典：

@examples[#:eval ev-goals #:no-result
(define-type Subst (Dict Var Term))]

值可以是数，也可以是另一个未知项。比如 @racket[x] 对着 @racket[y]，@racket[y] 对着 @racket[5]：头一行只说两者相等，没有说 @racket[x] 是几。要问一个项现在等于什么，就顺着表一路查下去，查到一个不在表里的项为止：

@examples[#:eval ev-goals #:no-result
(: walk (→ Term Subst Term))
(define (walk t s)
  (define p (and (var? t) (assq t s)))
  (if p (walk (cdr p) s) t))]

@examples[#:eval ev-goals #:label #f
(let* ([x (var 'x)] [y (var 'y)])
  (walk x (list (cons x y) (cons y 5))))]

@racket[x] 查到 @racket[y]，@racket[y] 查到 @racket[5]。表里的每一行是一条等式，照着它，可以把未知项换成它等于的项，所以这样一张表叫@defterm[#:en "substitution"]{代换}。@racket[assq] 按身份找键：两次造出的 @racket[(var 'a)]，在表里是两个键。

一行 @racket[(betweenᵒ l h a)] 写在那里，要做的是收到一张代换，从中读出 @racket[l]、@racket[h]，再添上一条 @racket[a] 等于某个数的等式。范围里有几个数，就交出几张添了等式的代换；条件不成立时一张也不交。收一个，交零个或多个，这是带 @racket[amb] 的函数，@xref["05:two-ways"]{「关系的两种写法」}里 ℬ 的箭头：

@examples[#:eval ev-goals #:no-result
(define-type Goal (→ℬ Subst Subst))]

一行关系交出的这种函数叫@defterm[#:en "goal"]{目标}。目标也是二元关系，表的两列是收到的代换和交出的代换。为免混淆，下文的「@tech{关系}」只说 @racket[betweenᵒ]、@racket[pythᵒ] 这一种，说的是数与数之间的事；代换之间的那一种就叫目标。

@margin-note{目标也可以写成 ℒ 的箭头 @racket[(→ℒ Subst Subst)]，交出一张代换的列表，用不着 @racket[amb]：接起来用的换成 @racket[∘ℒ]。两种写法之间，就是 @racket[gather] 与 @racket[scatter]。}

所有的目标都是从代换到代换，所以任意两个都接得上。四行条件要同时成立，就是四个目标一个接一个：前一个交出的代换，交给后一个。@xref["05:compose"]{「二元关系的复合」}说过，有了 @racket[amb]，函数的复合就是二元关系的复合，所以这里用的就是 @racket[∘ℬ]。几个条件同时成立，叫@tech{合取}：

@examples[#:eval ev-goals #:no-result
(: conj (→ Goal ... Goal))
(define (conj . g*) (apply ∘ℬ (reverse g*)))]

@racket[conj] 照写的顺序接：先写的先运行，和 @racket[let*] 一样，所以交给 @racket[∘ℬ] 之前要倒过来。

一个目标也不给，接起来是什么？拿一张记着 @racket[a] 等于 @racket[1] 的代换来试：

@examples[#:eval ev-goals #:label #f
(let ([a (var 'a)])
  ((conj) (list (cons a 1))))]

代换原样交了回来，一行也没有添：@racket[(∘ℬ)] 是恒等函数。作为代换之间的二元关系，它是@defterm[#:en "identity relation"]{恒等关系}；作为条件，它什么也没有要求，总是成立。给它一个名字：

@examples[#:eval ev-goals #:no-result
(: succeed Goal)
(define (succeed s) s)]

@racket[succeed] 接在哪个目标的前面或后面，都不改变那个目标：它是合取的@defterm[#:en "unit"]{单位}。

@section[#:tag "05:run"]{跑起来}

@racket[(betweenᵒ l h a)] 交出的目标，要往代换里添一条等式：@racket[a] 等于 @racket[between] 交出的数。添之前要先看看 @racket[a] 现在等于什么。等式的两边都顺着代换查到底，再比：有一边是未知项，就添上一行；两边都是序对，逐项去对；否则相等才走得通：

@(define ev-run (make-acf-eval))
@examples[#:eval ev-run #:hidden
(require racket/control)
(define ∘ compose)
(define-type (Dict k v) (Listof (Pair k v)))
(define (pyth? a b c) (= (+ (* a a) (* b b)) (* c c)))
(define (choose p*) (shift k (append-map k p*)))
(define-syntax-rule (amb e ...) ((choose (list (λ () e) ...))))
(define-syntax-rule (for/amb clauses body ...) ((choose (for/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))
(define (between lo hi) (for/amb ([n (inclusive-range lo hi)]) n))
(define (check ok?) (unless ok? (amb)))
(define-type (→ℬ p q) (→ p q))
(define ∘ℬ ∘)
(define (list->amb v*) (for/amb ([v (in-list v*)]) v))
(struct var ([name : Symbol]) #:transparent)
(define (walk t s)
  (define p (and (var? t) (assq t s)))
  (if p (walk (cdr p) s) t))
(define (conj . g*) (apply ∘ℬ (reverse g*)))]
@examples[#:eval ev-run #:no-result
(: unify (→ Term Term Subst Subst))
(define (unify u v s)
  (let ([u (walk u s)] [v (walk v s)])
    (cond [(and (var? u) (eq? u v)) s]
          [(var? u) (cons (cons u v) s)]
          [(var? v) (cons (cons v u) s)]
          [(and (pair? u) (pair? v))
           (unify (cdr u) (cdr v) (unify (car u) (car v) s))]
          [(equal? u v) s]
          [else (amb)])))]

拿两张各缺一项的列表来试，从空的代换开始，用 @racket[in-amb] 收下交出的代换：

@examples[#:eval ev-run #:label #f
(let ([a (var 'a)] [b (var 'b)])
  (in-amb (unify (list a 2) (list 1 b) '())))
(let ([a (var 'a)])
  (in-amb (unify (list a 2) (list 1 3) '())))]

头一例里 @racket[a] 对上 @racket[1]，@racket[b] 对上 @racket[2]，各添一行：两边都从对面得到了自己缺的那一项。后一例里 @racket[2] 对不上 @racket[3]，这条时间线走不通，@racket[in-amb] 一张代换也没有收到。

让两个项相等，必要时往代换里添等式，这件事叫@defterm[#:en "unification"]{合一}。添的总是一个还没在表里的未知项，所以键不会重复。

@racket[between] 要的是数，不是未知项。从代换里读出一个项的值，也是顺着查下去；序对就逐项读；查到底还是未知项，说明这个值还不知道：

@examples[#:eval ev-run #:no-result
(: value-of (→ Term Subst Term))
(define (value-of t s)
  (let ([t (walk t s)])
    (cond [(var? t) (error 'value-of "~a 的值还不知道" (var-name t))]
          [(pair? t) (cons (value-of (car t) s) (value-of (cdr t) s))]
          [else t])))]

@racket[(betweenᵒ l h a)] 的前两个位置是给 @racket[between] 的，要先读出值；最后一个位置与 @racket[between] 交出的数合一。@racket[(pythᵒ a b c)] 的三个位置都是给 @racket[pyth?] 的，全要读出值；不成立就走不通，成立就原样交回代换：

@examples[#:eval ev-run #:no-result
(define (((function->relation f) . t*) s)
  (define-values (in* out*) (split-at-right t* 1))
  (unify (car out*) (apply f (for/list ([t in*]) (value-of t s))) s))

(define (((predicate->relation p?) . t*) s)
  (check (apply p? (for/list ([t t*]) (value-of t s))))
  s)]

@racket[run*] 造出那几个未知项，把各行条件交出的目标用 @racket[conj] 接起来，从一张空的代换开始运行，最后读出它们的值。走通的每条时间线交出一组，由 @racket[in-amb] 收齐：

@examples[#:eval ev-run #:no-result
(define-syntax-rule (run* (x ...) g ...)
  (let ([x (var 'x)] ...)
    (in-amb (value-of (list x ...) ((conj g ...) '())))))]

想要的写法里缺的东西都有了。伪代码原样运行：

@examples[#:eval ev-run #:no-result
(define betweenᵒ (function->relation  between))
(define pythᵒ    (predicate->relation pyth?))

(define (right-triangles l h)
  (run* (a b c)
    (betweenᵒ l h a)     (code:comment "l ≤ a ≤ h")
    (betweenᵒ a h b)     (code:comment "a ≤ b ≤ h")
    (betweenᵒ b h c)     (code:comment "b ≤ c ≤ h")
    (pythᵒ a b c)))      (code:comment "a² + b² = c²")]

@examples[#:eval ev-run #:label #f
(right-triangles 1 20)]

还是那六组。一行关系交出了什么，也可以单独看：从空的代换开始，@racket[(betweenᵒ 1 3 a)] 交出三张代换，各记着 @racket[a] 等于其中一个数：

@examples[#:eval ev-run #:label #f
(let ([a (var 'a)])
  (in-amb ((betweenᵒ 1 3 a) '())))]

三张代换就是这个目标的表里，以空代换开头的三行。

把 @racket[pythᵒ] 挪到最前面：

@examples[#:eval ev-run #:label #f
(eval:error
 (run* (a b c)
   (pythᵒ a b c)
   (betweenᵒ 1 20 a)
   (betweenᵒ a 20 b)
   (betweenᵒ b 20 c)))]

@racket[pythᵒ] 要读 @racket[a] 的值，可这时候还没有哪一行给过 @racket[a] 一个值。四行条件要同时成立，谁先谁后本不该有分别；分别来自两个包装：函数与谓词只能算已经知道的值。合一并不要求这样，两边都可以是未知项；@racket[function->relation] 只在最后一个位置用到了它。直接写一条等式，让两边都可以不知道，会怎样？
