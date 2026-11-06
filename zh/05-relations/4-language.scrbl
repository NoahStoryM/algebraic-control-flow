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

先看第一个问题。@racket[a] 不是哪个数的名字，它代表一个还不知道的数；可三行条件里写的 @racket[a] 必须是同一个。没有值可以比，只能按身份区分：每个都是新造出来的东西，名字只用来打印。这样的东西叫@defterm[#:en "logic variable"]{未知项}。数、符号这些值是@defterm[#:en "term"]{项}，未知项也是项，由项组成的序对还是项：

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
(struct var ([name : Symbol]) #:transparent)
(define-type Term (∪ Var Boolean Number Symbol Null (Pair Term Term)))]

四行条件读下来，我们对这三个未知项知道得越来越多。读完 @racket[(betweenᵒ l h a)]，就知道 @racket[a] 等于范围里的某个数。知道的事要记下来，记在一张表里：键是未知项，值是它等于的那个项。键不重复，这正是@xref["05:search"]{「遍历搜索」}里缓存用的那种字典：

@examples[#:eval ev-goals #:no-result
(define-type Subst (Dict Var Term))]

这样一张表叫@defterm[#:en "substitution"]{代换}：照着它，可以把项里的未知项换成它等于的项。表里的每一行是一条等式。值可以是数，也可以是另一个未知项，比如 @racket[x] 对着 @racket[y]，说的只是两者相等，并没有说 @racket[x] 是几。所以一张代换不是一组答案，它说的是未知项之间要满足的关系，凡是满足这些等式的取值都算数。

要问一个项现在等于什么，就顺着等式一路查下去，查到一个不在表里的项为止：

@examples[#:eval ev-goals #:no-result
(: walk (→ Term Subst Term))
(define (walk t s)
  (define p (and (var? t) (assq t s)))
  (if p (walk (cdr p) s) t))]

@racket[assq] 按身份找键，和未知项按身份区分是一回事。

再看第二个问题。@racket[(betweenᵒ l h a)] 要做的，是收到一张代换，从中读出 @racket[l]、@racket[h]，再添上一条 @racket[a] 等于某个数的等式。范围里有几个数，就交出几张添了等式的代换；条件不成立时一张也不交。收一个，交零个或多个，这是带 @racket[amb] 的函数，@xref["05:two-ways"]{「关系的两种写法」}里 ℬ 的箭头：

@examples[#:eval ev-goals #:no-result
(define-type Goal (→ℬ Subst Subst))]

一行关系交出的这种函数叫@defterm[#:en "goal"]{目标}。目标也是二元关系，表的两列是收到的代换和交出的代换。所有的目标都在同一对集合之间：从代换到代换。

四行条件要同时成立，就是四个目标一个接一个：前一个交出的代换，交给后一个。@xref["05:compose"]{「二元关系的复合」}说过，有了 @racket[amb]，函数的复合就是二元关系的复合，所以这里用的就是 @racket[∘ℬ]。关系语言里的「并且」叫合取，写成 @racket[conj]。几个条件里只要有一个成立，叫析取，写成 @racket[disj]：从几个目标里挑一个来用，挑哪个都算，正是 @racket[amb]。两个目标都是从代换到代换的二元关系，表的两列对得上，析取就是把两张表并起来。

@examples[#:eval ev-goals #:no-result
(: succeed Goal)
(: fail Goal)
(define (succeed s) s)
(define (fail s) (amb))

(: conj (→ Goal ... Goal))
(: disj (→ Goal ... Goal))
(define (conj . g*) (apply ∘ℬ (reverse g*)))
(define ((disj . g*) s) ((list->amb g*) s))]

@racket[conj] 照写的顺序接：先写的先运行，和 @racket[let*] 一样，所以交给 @racket[∘ℬ] 之前要倒过来。@racket[disj] 用 @racket[list->amb] 挑出一个目标，再把代换交给它。

@racket[succeed] 原样交回代换，什么也不添，是恒等关系；@racket[fail] 一张也不交，是空关系。前者接在哪个目标前后都不改变它，后者和哪个目标并起来都不改变它：一个是合取的单位，一个是析取的单位。零个目标的合取就是 @racket[succeed]，因为 @racket[(∘ℬ)] 是恒等函数；零个目标的析取就是 @racket[fail]，因为从零个备选里挑，就是 @racket[(amb)]。

@margin-note{目标也可以写成 ℒ 的箭头 @racket[(→ℒ Subst Subst)]，交出一张代换的列表：合取换成 @racket[∘ℒ]，析取换成把几张列表接起来，用不着 @racket[amb]。两种写法之间，就是 @racket[gather] 与 @racket[scatter]。}

现在有两种关系，叫法要分开。@racket[betweenᵒ]、@racket[pythᵒ] 是关系语言里的@tech{关系}，说的是数与数之间的事；它们用到项上，交出目标。目标是代换与代换之间的二元关系，是实现前一种关系的办法。两种二元关系前后脚出现，下面说「关系」只指前一种。

@section[#:tag "05:run"]{跑起来}

@racket[(betweenᵒ l h a)] 交出的目标，要往代换里添一条等式：@racket[a] 等于 @racket[between] 交出的数。添等式之前要先看看，@racket[a] 现在等于什么。两边一般都是项，顺着代换查到底以后分几种情况：同一个未知项，什么也不用添；一边是未知项，添上一行；两边都是序对，逐项去对；都是值，相等就过，不等就是这条时间线走不通：

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

让两个项相等，必要时往代换里添等式，这件事叫@defterm[#:en "unification"]{合一}。添的总是一个还没在表里的未知项，所以键不会重复。

@racket[between] 要的是数，不是未知项。从代换里读出一个项的值，也是顺着查下去；序对就逐项读；查到底还是未知项，说明这个值还不知道：

@examples[#:eval ev-run #:no-result
(: value-of (→ Term Subst Term))
(define (value-of t s)
  (let ([t (walk t s)])
    (cond [(var? t) (error 'value-of "~a 的值还不知道" (var-name t))]
          [(pair? t) (cons (value-of (car t) s) (value-of (cdr t) s))]
          [else t])))]

两个包装各几行就写得出。函数搬成关系：读出前面几个位置的值，交给函数，让结果与最后一个位置合一。谓词搬成关系：读出所有位置的值，交给谓词，不成立就走不通，成立就原样交回代换：

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

四行条件的先后有讲究。把 @racket[pythᵒ] 挪到最前面，它要读 @racket[a] 的值，可这时候还没有哪一行给过 @racket[a] 一个值：

@examples[#:eval ev-run #:label #f
(eval:error
 (run* (a b c)
   (pythᵒ a b c)
   (betweenᵒ 1 20 a)
   (betweenᵒ a 20 b)
   (betweenᵒ b 20 c)))]

这是两个包装的限制：函数与谓词只能算已经知道的值。合一本身并不要求这样，两边都可以是未知项；@racket[function->relation] 只在最后一个位置用到了它。直接写一条等式，让两边都可以不知道，会怎样？
