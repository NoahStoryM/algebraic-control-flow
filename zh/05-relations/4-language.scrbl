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

原来的写法里，名字的事不用我们操心。@racket[let*] 的每一行造出一个新的变量，把右边算出的值交给它；哪个名字对着哪个值，Racket 替我们记着，后面的行写下 @racket[a]，读到的就是那个值。这份记录从没露过面，可每一行都在用它。

换成 @racket[run*] 的写法，@racket[(betweenᵒ l h a)] 是一次普通的调用，参数要先有。可 @racket[a] 的值正要靠这一行来定，所以交进去的不能是那个数，只能是一个代表「还不知道的数」的东西。哪个这样的东西对着哪个值，Racket 不再替我们记，得自己记一张表。

表要有键。为每个还不知道的数造一个键，带上名字：

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

造两次，打印出来一模一样，@racket[eq?] 却说它们是两个；同一次造出的才是同一个。名字只用来打印，分辨靠的是身份。这样的东西叫@defterm[#:en "logic variable"]{未知项}。关系的参数可以是数、符号这些值，也可以是未知项，合起来叫@defterm[#:en "term"]{项}；由项组成的序对也是项：

@examples[#:eval ev-goals #:no-result
(define-type Term (∪ Var Boolean Number Symbol Null (Pair Term Term)))]

表的键是未知项，值是它等于的那个项，眼下记的都是数。键不重复，这正是@xref["05:search"]{「遍历搜索」}里缓存用的那种字典：

@examples[#:eval ev-goals #:no-result
(define-type Subst (Dict Var Term))]

要问一个项的值：本来就是值的，就是它自己；未知项去表里查，查不到，说明它的值还不知道。

@examples[#:eval ev-goals #:no-result
(: value-of (→ Term Subst Term))
(define (value-of t s)
  (cond [(not (var? t)) t]
        [(assq t s) => cdr]
        [else (error 'value-of "~a 的值还不知道" (var-name t))]))]

@examples[#:eval ev-goals #:label #f
(let* ([a (var 'a)] [s (list (cons a 3))])
  (list (value-of 5 s) (value-of a s)))
(eval:error
 (let* ([a (var 'a)] [b (var 'b)] [s (list (cons a 3))])
   (value-of b s)))]

照着这张表，可以把未知项换成它的值，所以这样一张表叫@defterm[#:en "substitution"]{代换}。@racket[assq] 按身份找键：两次造出的 @racket[(var 'a)]，在表里是两个键。

@racket[let*] 的一行 @racket[[a (between 1 3)]]，往 Racket 的那份记录里添了一个名字。@racket[(betweenᵒ 1 3 a)] 这一行要做的是同一件事，只是记录在我们手里：收到一张代换，交出添了一行的代换。先手写一个，从空的代换开始运行：

@examples[#:eval ev-goals #:label #f
(let* ([a (var 'a)]
       [g (λ (s) (cons (cons a (between 1 3)) s))])
  (in-amb (g '())))]

@racket[g] 写出来是个普通的函数，收一张代换，交出一张。可 @racket[between] 返回了三次，@racket[g] 也就交出了三张，各记着 @racket[a] 等于其中一个数；范围要是空的，就一张也不交。收一个，交零个或多个，这是带 @racket[amb] 的函数，@xref["05:two-ways"]{「关系的两种写法」}里 ℬ 的箭头：

@examples[#:eval ev-goals #:no-result
(define-type Goal (→ℬ Subst Subst))]

一行条件交出的这种函数叫@defterm[#:en "goal"]{目标}。ℬ 的箭头写的是二元关系，目标也是：表的两列是收到的代换和交出的代换，上面那三张就是 @racket[g] 的表里以空代换开头的三行。为免混淆，下文的「@tech{关系}」只说 @racket[betweenᵒ]、@racket[pythᵒ] 这一种，说的是数与数之间的事；代换之间的那一种就叫目标。

@margin-note{目标也可以写成 ℒ 的箭头 @racket[(→ℒ Subst Subst)]，交出一张代换的列表，用不着 @racket[amb]：接起来用的换成 @racket[∘ℒ]。两种写法之间，就是 @racket[gather] 与 @racket[scatter]。}

第二行 @racket[(betweenᵒ a h b)] 要读 @racket[a] 的值，它收到的得是第一行交出的代换。所有的目标都是从代换到代换，所以任意两个都接得上：前一个交出的，交给后一个。@racket[let*] 把绑定一行一行接起来，@xref["05:two-ways"]{「关系的两种写法」}认出那是 @racket[∘ℬ]；把目标一行一行接起来的，还是 @racket[∘ℬ]。几个条件同时成立，叫@tech{合取}：

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

手写的 @racket[g] 里，1 和 3 是现成的数，@racket[a] 也还没有值。一般的 @racket[(betweenᵒ l h a)] 要多做两件事。@racket[l]、@racket[h] 可能是未知项，要先用 @racket[value-of] 读出值。最后一个位置也可能已经有值：它本来就是个数，或者是代换里已有记录的未知项。这时不能再添一行，只能核对它与算出的数是否相等：

@examples[#:eval ev-goals #:no-result
(: record (→ Term Term Subst Subst))
(define (record t v s)
  (cond [(not (var? t)) (check (equal? t v)) s]
        [(assq t s) => (λ (p) (check (equal? (cdr p) v)) s)]
        [else (cons (cons t v) s)]))]

@examples[#:eval ev-goals #:label #f
(let ([a (var 'a)])
  (in-amb (record a 2 '())))
(let ([a (var 'a)])
  (in-amb (record a 2 (list (cons a 3)))))]

@racket[a] 还没有记录，就添上一行；已经记着 3，与 2 对不上，这条时间线走不通，@racket[in-amb] 一张代换也没有收到。添的总是一个还没在表里的未知项，所以键不会重复。

@racket[(betweenᵒ l h a)] 的前两个位置是给 @racket[between] 的，读出值；@racket[between] 交出的数记在最后一个位置上。@racket[(pythᵒ a b c)] 的三个位置都是给 @racket[pyth?] 的，全要读出值；不成立就走不通，成立就原样交回代换：

@examples[#:eval ev-goals #:no-result
(define (((function->relation f) . t*) s)
  (define-values (in* out*) (split-at-right t* 1))
  (record (car out*) (apply f (for/list ([t in*]) (value-of t s))) s))

(define (((predicate->relation p?) . t*) s)
  (check (apply p? (for/list ([t t*]) (value-of t s))))
  s)]

@racket[run*] 做的是 @racket[let*] 开头的那件事：造出几个未知项。然后把各行条件交出的目标用 @racket[conj] 接起来，从一张空的代换开始运行，最后读出那几个未知项的值。走通的每条时间线交出一组，由 @racket[in-amb] 收齐：

@examples[#:eval ev-goals #:no-result
(define-syntax-rule (run* (x ...) g ...)
  (let ([x (var 'x)] ...)
    (in-amb
     (let ([s ((conj g ...) '())])
       (list (value-of x s) ...)))))]

想要的写法里缺的东西都有了。伪代码原样运行：

@examples[#:eval ev-goals #:no-result
(define betweenᵒ (function->relation  between))
(define pythᵒ    (predicate->relation pyth?))

(define (right-triangles l h)
  (run* (a b c)
    (betweenᵒ l h a)     (code:comment "l ≤ a ≤ h")
    (betweenᵒ a h b)     (code:comment "a ≤ b ≤ h")
    (betweenᵒ b h c)     (code:comment "b ≤ c ≤ h")
    (pythᵒ a b c)))      (code:comment "a² + b² = c²")]

@examples[#:eval ev-goals #:label #f
(right-triangles 1 20)]

还是那六组。单独看一行，@racket[(betweenᵒ 1 3 a)] 交出的目标和手写的 @racket[g] 一样：

@examples[#:eval ev-goals #:label #f
(let ([a (var 'a)])
  (in-amb ((betweenᵒ 1 3 a) '())))]

把 @racket[pythᵒ] 挪到最前面：

@examples[#:eval ev-goals #:label #f
(eval:error
 (run* (a b c)
   (pythᵒ a b c)
   (betweenᵒ 1 20 a)
   (betweenᵒ a 20 b)
   (betweenᵒ b 20 c)))]

@racket[pythᵒ] 要读 @racket[a] 的值，可这时候还没有哪一行给过 @racket[a] 一个值。四行条件要同时成立，谁先谁后本不该有分别；分别来自两个包装：函数与谓词只能算已经知道的值。代换里记得下的也只有这样的事：某个未知项等于某个值。要是一行条件说的是两个未知项相等，两边都还不知道，这张表记得下吗？
