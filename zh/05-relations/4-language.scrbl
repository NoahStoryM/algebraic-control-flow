#lang acf/scribble

@title[#:tag "05:4-language"]{关系式编程}

到这里，@tech{关系}都是用函数模拟的：交出列表的函数，或者带 @racket[amb] 的函数。可函数总分输入和输出，表里的列本来不分。能不能直接把表里的条件写下来？

@section[#:tag "05:wanted"]{想要的写法}

在 @racket[amb] 版的搜索里，两个@tech{关系}的用法就不一样：

@racketblock[
(let* ([a (between l h)]
       [b (between a h)]
       [c (between b h)])
  (check (pyth? a b c))
  (list a b c))]

@racket[between] 是交出结果的函数，写在绑定的右边，取出一个数来；@racket[pyth?] 是@tech{谓词}，只回答是或否，要靠 @racket[check] 才用得上。一个取，一个查。它们描述的却是同一类东西：@racket[between] 是边界与其间的数之间的@tech{关系}，@racket[pyth?] 是三条边之间的@tech{关系}。取与查的分别来自函数，不来自@tech{关系}。

@xref["05:relation"]{「关系」}用集合的语言写过直角三角形。借着边界与边之间的@tech{关系}，同一件事可以写成：

@mm{{(a, b, c) | between(l, h, a) ∧ between(a, h, b) ∧ between(b, h, c) ∧ pyth(a, b, c)}}

集合语言里没有「取」和「查」，四条都是@tech{关系}，用 @math{∧} 连在一起，要求同时成立。能不能把这套集合语言逐字翻译成能运行的程序？设想有一门直接写@tech{关系}的语言，@racket[between] 和 @racket[pyth?] 在其中各有对应的@tech{关系}，名字后面添一个上标 ᵒ：

@racketblock[
(define betweenᵒ (function->relation  between))
(define pythᵒ    (predicate->relation pyth?))]

@racket[(pythᵒ a b c)] 说的是 @racket[a]、@racket[b]、@racket[c] 满足勾股定理。@racket[between] 收两个数交出一个，@racket[betweenᵒ] 就有三个位置，结果排在最后：@racket[(betweenᵒ l h a)] 说的是 @racket[a] 在 @racket[l] 与 @racket[h] 之间。两个@tech{关系}的写法一样，不再分取与查。把上面的集合逐字翻成程序：

@racketblock[
(define (right-triangles l h)
  (run* (a b c)
    (∧ (betweenᵒ l h a)     (code:comment "l ≤ a ≤ h")
       (betweenᵒ a h b)     (code:comment "a ≤ b ≤ h")
       (betweenᵒ b h c)     (code:comment "b ≤ c ≤ h")
       (pythᵒ a b c))))     (code:comment "a² + b² = c²")]

@racket[run*] 对应集合的花括号，@racket[(a b c)] 是竖线左边的形状，里面的 @racket[∧] 逐字照抄了竖线右边用 @math{∧} 连起来的四条条件。与 @racket[amb] 版也是一行对一行：三个绑定成了三行 @racket[betweenᵒ]，@racket[check] 的一行成了 @racket[pythᵒ]，最后交出的 @racket[(list a b c)] 挪到了 @racket[run*] 后面，@racket[in-amb] 那一层也收进了 @racket[run*]。

这还只是想要的写法，@racket[function->relation]、@racket[predicate->relation]、@racket[run*] 都还没有。改写里有一处不只是换名字：@racket[a]、@racket[b]、@racket[c] 原来由 @racket[let*] 绑定，每一行右边算出一个值，交给左边的名字；现在它们列在 @racket[run*] 后面，是三个还不知道的数，四行条件各说了一件关于它们的事。没有了绑定，这三个名字是什么？一行 @racket[(betweenᵒ l h a)] 写在那里，又交出了什么？

@section[#:tag "05:goals"]{未知项、代换与目标}

原来的写法里，名字的事不用我们操心。Racket 有一份记录表，记着每个变量的值：@racket[let*] 的每一行造出一个新的变量，把右边算出的值记进去；后面的行引用 @racket[a]，就是从这份表里查出它的值。

@racket[run*] 也造出新的变量，可它们的值要靠下面几行条件来定。@racket[(betweenᵒ l h a)] 是一次普通的调用，参数要先有，所以 @racket[run*] 造出的变量得是一种数据，可以当参数交进去。为了和 Racket 的变量分开，这种变量叫@defterm{未知项}：

@(define ev-goals (make-acf-eval))
@examples[#:eval ev-goals #:hidden
(require racket/control)
(define ∘ compose)
(define-type (Dictionary k v) (Listof (Pair k v)))
(define (pyth? a b c) (= (+ (* a a) (* b b)) (* c c)))
(define (choose p*) (shift k (append-map k p*)))
(define-syntax-rule (amb e ...) ((choose (list (λ () e) ...))))
(define-syntax-rule (for/amb clauses body ...) ((choose (for/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))
(define (between lo hi) (for/amb ([n (inclusive-range lo hi)]) n))
(define (check ok?) (unless ok? (amb)))
(define-type (→ℬ p ... q) (→ p ... q))
(define ∘ℬ ∘)]
@examples[#:eval ev-goals #:no-result
(struct var ([name : Symbol]) #:type-name Var #:transparent)

(: var=? (→ Var Var Boolean))
(define (var=? u v) (eq? u v))]

@racket[var] 里的符号只用来打印，分辨@tech{未知项}靠的是身份（@racket[var=?]）。两次调用 @racket[(var 'a)] 印出来一模一样，却是两个不同的@tech{未知项}；只有同一次造出的才是同一个：

@examples[#:eval ev-goals #:label #f
(define a (var 'a))
(var=? (var 'a) (var 'a))
(var=? a a)]

不含@tech{未知项}的值由数这样的字面量和序对组成，记作 @racket[Data]；一个@defterm[#:en "term"]{项}眼下要么是已经完整的值 @racket[Data]，要么是一个@tech{未知项} @racket[Var]。@tech{未知项}的值，Racket 不再替我们记，得自己记一张字典：键是@tech{未知项}，值是它对应的@tech{项}。照着这张字典可以把@tech{未知项}换成它的值，所以叫@defterm[#:en "substitution"]{代换}：

@examples[#:eval ev-goals #:no-result
(define-type Literal (∪ Boolean Number Char Bytes String Keyword Null Symbol))
(define-type Data (∪ Literal (Pair Data Data)))
(define-type Term (∪ Data Var))
(define-type Substitution (Dictionary Var Term))]

什么都还不知道时，手里是一张空的@tech{代换} @racket[empty-s]；数清@tech{代换}里记了多少条记录用 @racket[size-s]；给@tech{代换}添一条记录用 @racket[ext-s]，它只负责往表头添上一项，前提是键 @racket[x] 是尚未绑定的@tech{未知项}。读值用 @racket[value-of]：不是@tech{未知项}就原样交回；是@tech{未知项}，就用按身份比较的 @racket[assq] 去表里查，查不到就报错。

@examples[#:eval ev-goals #:no-result
(: empty-s Substitution)
(define empty-s '())

(: size-s (→ Substitution Natural))
(define (size-s s) (length s))

(: ext-s (→ Var Term Substitution Substitution))
(define (ext-s x t s) (cons (cons x t) s))

(: value-of (→ Term Substitution Term))
(define (value-of t s)
  (cond [(not (var? t)) t]
        [(assq t s) => cdr]
        [else (error 'value-of "~a 的值还不知道" (var-name t))]))]

试一试查得到和查不到的情形：

@examples[#:eval ev-goals #:label #f
(define b (var 'b))
(define s (ext-s a 3 empty-s))
(value-of 5 s)
(value-of a s)
(eval:error (value-of b s))]

有了@tech{代换}，@racket[run*] 要做的事可以从两头说起。开头，它造出几个@tech{未知项}，什么都还不知道，手里是一张空的@tech{代换}。结尾，它交出一张列表，每个元素是这几个@tech{未知项}的一组取值；取值记在@tech{代换}里，所以每一组都是从某一张@tech{代换}里读出来的，有几组答案，就有几张@tech{代换}。

夹在中间的是那几条条件。它们合起来要做的事也就定了：收下那张空的@tech{代换}，交出一张装满@tech{代换}的列表，每张记着一组走得通的取值；一组也没有，就交出空列表。收一个、交一张列表，这正是@xref["05:two-ways"]{「关系的两种写法」}里 ℒ 的箭头 @racket[(→ℒ Substitution Substitution)]，也就是@tech{代换}与@tech{代换}之间的@tech{二元关系}：左边一列是收到的@tech{代换}，右边一列是交出的@tech{代换}。

@margin-note{不用 @racket[amb]、直接按 @racket[(→ℒ Substitution Substitution)] 写成纯函数也可以，接起来用的换成 @racket[∘ℒ]；两种写法之间，正是 @racket[gather] 与 @racket[scatter]。}

既然是@tech{二元关系}，还可以换用@tech{同构}的 ℬ 箭头来写：用 @racket[amb] 省去处处拆列表、接列表的麻烦，留到 @racket[run*] 出口再用 @racket[in-amb] 一次收齐。这样的函数叫@defterm[#:en "goal"]{目标}：

@examples[#:eval ev-goals #:no-result
(define-type Goal (→ℬ Substitution Substitution))]

两头和中间都看清了，外层的 @racket[run*] 立刻可以写下来：造出@tech{未知项}，从一张空的@tech{代换}开始运行@tech{目标} @racket[g]，再读出那几个@tech{未知项}的值。走通的每条时间线交出一组取值，由 @racket[in-amb] 收齐：

@examples[#:eval ev-goals #:no-result
(define-syntax-rule (run* (x ...) g)
  (let ([x (var 'x)] ...)
    (in-amb
     (let ([s (g empty-s)])
       (list (value-of x s) ...)))))]

在 @racket[(run* (x ...) g)] 里，@racket[g] 是 @racket[Goal] 类型的表达式。开头的伪代码里，填在这个位置的是 @racket[∧]，所以@tech{合取} @racket[∧] 的返回类型就是 @racket[Goal]；它把几条同类的条件合成一条，参数类型与返回类型一致，因此每个参数也都是 @racket[Goal]，类型是 @racket[(→ Goal ... Goal)]。

@racket[∧] 的参数都是 @racket[Goal]，传给它的 @racket[(betweenᵒ l h a)] 和 @racket[(pythᵒ a b c)] 也就都得交出 @racket[Goal]；而它们收下的参数可以含有@tech{未知项}，类型是 @racket[Term]。带 ᵒ 后缀的@tech{关系}，类型于是顺势逼了出来：参数是 @racket[Term]，返回值是 @racket[Goal]。拿 @racket[pyth?] 与 @racket[pythᵒ] 并排对照：

@racketblock[
(: pyth? (→ ℕ⁺   ℕ⁺   ℕ⁺   Boolean))
(: pythᵒ (→ Term Term Term Goal))]

一般地，@tech{谓词}（也就是@tech{特征函数}）的类型是 @racket[(→ Data ... Boolean)]，等一行的值都给齐了才检查；这门语言里的@tech{关系}类型是 @racket[(→ Term ... Goal)]，可以先收下含@tech{未知项}的@tech{项}，交出的@tech{目标}再从已有@tech{代换}出发，把求得的信息交给下一步。为免混淆，下文的「关系」专指 @racket[betweenᵒ]、@racket[pythᵒ] 这一种，说的是数据之间的事；@tech{代换}之间的那一种就叫@tech{目标}。

@section[#:tag "05:run"]{跑起来}

@racket[run*] 写好了，先照类型手写 @racket[betweenᵒ] 和 @racket[pythᵒ]。在 @racket[(betweenᵒ l h a)] 里，@racket[l]、@racket[h] 可能是@tech{未知项}，先用 @racket[value-of] 读出值，交给 @racket[between]；交出的数记在最后一个位置上（前三条条件里，最后一个位置都是还没有值的@tech{未知项}，往@tech{代换}里添一条记录就够了）。@racket[(pythᵒ a b c)] 的三个位置全要读出值；@tech{谓词}的是与否，成了@tech{目标}的两种回答：成立就原样交回@tech{代换}，不成立就一张也不交。

@examples[#:eval ev-goals #:no-result
(define ((betweenᵒ l h a) s)
  (ext-s a (between (value-of l s) (value-of h s)) s))

(define ((pythᵒ a b c) s)
  (check (pyth? (value-of a s) (value-of b s) (value-of c s)))
  s)]

先单独试一试 @racket[betweenᵒ]，从空的@tech{代换}开始运行：

@examples[#:eval ev-goals #:label #f
(in-amb ((betweenᵒ 1 3 a) empty-s))]

@racket[(betweenᵒ 1 3 a)] 交出的是个普通的函数，收一张@tech{代换}，交出一张。可 @racket[between] 返回了三次，它也就交出了三张，各记着 @racket[a] 等于其中一个数。把它交给 @racket[run*]：

@examples[#:eval ev-goals #:label #f
(run* (a) (betweenᵒ 1 3 a))]

三张@tech{代换}，读出来是三组答案。

单个@tech{目标}跑通了，几个@tech{目标}怎样用 @racket[∧] 接起来？@racket[(betweenᵒ a h b)] 要读 @racket[a] 的值，收到的得是前一个@tech{目标} @racket[(betweenᵒ l h a)] 交出的@tech{代换}；它给@tech{代换}添上 @racket[b] 的值，再交给下一个@tech{目标} @racket[(betweenᵒ b h c)]。前一个@tech{目标}交出的@tech{代换}交给后一个：@xref["05:compose-l"]{「列表箭头的复合」}里，@racket[let*] 中先后两次调用写成了 @racket[∘ℬ]；这里接起前后两个@tech{目标}，用的也是 @racket[∘ℬ]：

@examples[#:eval ev-goals #:no-result
(: ∧ (→ Goal ... Goal))
(define (∧ . g*) (apply ∘ℬ (reverse g*)))]

@racket[∧] 照写的顺序接：先写的先运行，和 @racket[let*] 一样，所以交给 @racket[∘ℬ] 之前要倒过来。

现在开头的 @racket[right-triangles] 已经能直接跑起来了：

@examples[#:eval ev-goals #:no-result
(define (right-triangles l h)
  (run* (a b c)
    (∧ (betweenᵒ l h a)
       (betweenᵒ a h b)
       (betweenᵒ b h c)
       (pythᵒ a b c))))]

上下界仍取 1 和 20：

@examples[#:eval ev-goals #:label #f
(right-triangles 1 20)]

还是那六组。回头看刚才手写的 @racket[betweenᵒ] 与 @racket[pythᵒ]，做的都是同一套活：把前面的参数用 @racket[value-of] 读出来，交给原函数或原@tech{谓词}，函数版把结果添进@tech{代换}，@tech{谓词}版用 @racket[check] 拦下不成立的分支。把这两套模板抽出来，就得到开头想要的 @racket[function->relation] 与 @racket[predicate->relation]：

@margin-note{这里的 @racket[a ...] 与 @racket[b] 是 @racket[Data] 的子类型（如 @racket[ℕ⁺]）；@racket[function->relation] 在原有参数之后添一个结果位置，@racket[predicate->relation] 保留原@tech{谓词}的参数个数，两种包装读出的参数都须落在原函数或@tech{谓词}的定义域里。}

@examples[#:eval ev-goals #:no-result
(: function->relation (∀ (a ... b) (→ (→ℬ a ... b) (→ Term ... Term Goal))))
(define (((function->relation f) . t*) s)
  (define-values (in* out*) (split-at-right t* 1))
  (ext-s (car out*) (apply f (for/list ([t in*]) (value-of t s))) s))

(: predicate->relation (∀ (a ...) (→ (→ a ... Boolean) (→ Term ... Goal))))
(define (((predicate->relation p?) . t*) s)
  (check (apply p? (for/list ([t t*]) (value-of t s))))
  s)]

于是开头那两行伪代码也原样成立了：

@examples[#:eval ev-goals #:no-result
(define betweenᵒ (function->relation  between))
(define pythᵒ    (predicate->relation pyth?))]
