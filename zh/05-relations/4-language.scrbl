#lang acf/scribble

@title[#:tag "05:4-language"]{关系式编程}

到这里，关系都是用函数模拟的：交出列表的函数，或者带 @racket[amb] 的函数。可函数总分输入和输出，表里的列本来不分。能不能直接把表里的条件写下来？

@section[#:tag "05:wanted"]{想要的写法}

在 @racket[amb] 版的搜索里，两个关系的用法就不一样：

@racketblock[
(let* ([a (between l h)]
       [b (between a h)]
       [c (between b h)])
  (check (pyth? a b c))
  (list a b c))]

@racket[between] 是交出结果的函数，写在绑定的右边，取出一个数来；@racket[pyth?] 是谓词，只回答是或否，要靠 @racket[check] 才用得上。一个取，一个查。它们描述的却是同一类东西：@racket[between] 是边界与其间的数之间的关系，@racket[pyth?] 是三条边之间的关系。取与查的分别来自函数，不来自关系。

@xref["05:relation"]{「关系」}用集合的语言写过直角三角形。借着边界与边之间的关系，同一件事可以写成：

@mm{{(a, b, c) | between(l, h, a) ∧ between(a, h, b) ∧ between(b, h, c) ∧ pyth(a, b, c)}}

集合语言里没有「取」和「查」，四项都是关系，用 @math{∧} 连在一起，要求同时成立。能不能把这套集合语言逐字翻译成能运行的程序？设想有一门直接写关系的语言，@racket[between] 和 @racket[pyth?] 在其中各有对应的关系，名字后面添一个上标 ᵒ：

@racketblock[
(define betweenᵒ (function->relation  between))
(define pythᵒ    (predicate->relation pyth?))]

@racket[(pythᵒ a b c)] 说的是 @racket[a]、@racket[b]、@racket[c] 满足勾股定理。@racket[between] 收两个数交出一个，@racket[betweenᵒ] 就有三个位置，结果排在最后：@racket[(betweenᵒ l h a)] 说的是 @racket[a] 在 @racket[l] 与 @racket[h] 之间。两个关系的写法一样，不再分取与查。把上面的集合逐字翻成程序：

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

@racket[run*] 也造出新的变量，可它们的值要靠下面几行条件来定。@racket[(betweenᵒ l h a)] 是一次普通的调用，参数要先有，所以 @racket[run*] 造出的变量得是一种数据，可以当参数交进去。为了和 Racket 的变量分开，这种变量叫@defterm{未知项}。不含未知项的值由数这样的字面量和序对组成，记作 @racket[Data]；添上未知项 @racket[Var]，合起来叫@defterm[#:en "term"]{项}。未知项的值，Racket 不再替我们记，得自己记一张字典：键是未知项，值是它等于的那个项，眼下记的都是数。

@(define ev-goals (make-acf-eval))
@examples[#:eval ev-goals #:hidden
(require racket/control)
(define ∘ compose)
(define id (∘))
(define-type (Dictionary k v) (Listof (Pair k v)))
(define (pyth? a b c) (= (+ (* a a) (* b b)) (* c c)))
(define (choose p*) (shift k (append-map k p*)))
(define-syntax-rule (amb e ...) ((choose (list (λ () e) ...))))
(define-syntax-rule (for/amb clauses body ...) ((choose (for/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))
(define (between lo hi) (for/amb ([n (inclusive-range lo hi)]) n))
(define (check ok?) (unless ok? (amb)))
(define-type (→ℬ p ... q) (→ p ... q))
(define ∘ℬ ∘)
(define (list->amb v*) (for/amb ([v (in-list v*)]) v))]
@examples[#:eval ev-goals #:no-result
(struct var ([name : Symbol]) #:type-name Var #:transparent)
(define-type Literal (∪ Boolean Number Char Bytes String Keyword Null Symbol))
(define-type Data (∪ Literal (Pair Data Data)))
(define-type Term (∪ Literal Var (Pair Term Term)))
(define-type Substitution (Dictionary Var Term))]

键不重复，这正是@xref["05:search"]{「遍历搜索」}里缓存用的那种字典。

要问一个项的值：本来就是值的，就是它自己；未知项去表里查，查不到，说明它的值还不知道。

@examples[#:eval ev-goals #:no-result
(: value-of (→ Term Substitution Term))
(define (value-of t s)
  (cond [(not (var? t)) t]
        [(assq t s) => cdr]
        [else (error 'value-of "~a 的值还不知道" (var-name t))]))]

试一试查得到和查不到的情形：

@examples[#:eval ev-goals #:label #f
(define a (var 'a))
(define b (var 'b))
(define s (list (cons a 3)))
(value-of 5 s)
(value-of a s)
(eval:error (value-of b s))]

照着这张表，可以把未知项换成它的值，所以这样一张表叫@defterm[#:en "substitution"]{代换}。

@racket[assq] 按身份找键。未知项的名字只用来打印，分辨靠的是身份：

@examples[#:eval ev-goals #:label #f
(var 'a)
(eq? (var 'a) (var 'a))
(eq? a a)]

造两次，打印出来一模一样，在表里却是两个键；同一次造出的才是同一个。

有了代换，@racket[run*] 要做的事可以从两头说起。开头，它造出几个未知项，什么都还不知道，手里是一张空的代换。结尾，它交出一张列表，每一项是这几个未知项的一组取值；取值记在代换里，所以每一项都是从某一张代换里读出来的，有几组答案，就有几张代换。

夹在中间的是那几条条件。它们合起来要做的事也就定了：收下那张空的代换，交出若干张代换，每张记着一组走得通的取值；一组也没有，就一张也不交。收一个，交零个或多个，这是带 @racket[amb] 的函数，@xref["05:two-ways"]{「关系的两种写法」}里 ℬ 的箭头：

@examples[#:eval ev-goals #:no-result
(define-type Goal (→ℬ Substitution Substitution))]

这样的函数叫@defterm[#:en "goal"]{目标}。ℬ 的箭头写的是二元关系，目标也是：它的两列是收到的代换和交出的代换。这里因此有两层：目标收一张代换、交出若干张代换（@racket[(→ℬ Substitution Substitution)]）；关系则收几个项，调用后交出一个目标（@racket[(→ Term ... Goal)]）。比如 @racket[(betweenᵒ 1 3 a)] 交出的是一个目标，把空代换交给这个目标，才会走出三条分支、得到三张分别记着 @racket[a] 等于 1、2、3 的代换。

@margin-note{目标也可以写成 ℒ 的箭头 @racket[(→ℒ Substitution Substitution)]，交出一张代换的列表，用不着 @racket[amb]：接起来用的换成 @racket[∘ℒ]。两种写法之间，就是 @racket[gather] 与 @racket[scatter]。}

四条条件合起来是一个目标，拆开来，每一条呢？先看最后的 @racket[(pythᵒ a b c)]。@racket[pyth?] 是谓词，收下三个数，回答是或否。@racket[pythᵒ] 收下的是项，里面可能有未知项，是或否就答不出来了：成立不成立，要看未知项取什么值。@racket[pythᵒ] 答得出的是「在哪些取值下成立」，也就是从收到的代换出发，哪些代换走得通。所以它交出的是一个目标：

@racketblock[
(: pyth? (→ ℕ⁺   ℕ⁺   ℕ⁺   Boolean))
(: pythᵒ (→ Term Term Term Goal))]

一般地，@tech{谓词}（也就是@tech{特征函数}）与这门语言里的@tech{关系}，类型正好并排对照：谓词是 @racket[(→ Data ... Boolean)]，收下数据，回答是或否；关系是 @racket[(→ Term ... Goal)]，收下可以含有未知项的项，交出目标。@racket[betweenᵒ] 也一样，@racket[run*] 里的每一条条件都是一次关系调用，交出一个目标。为免混淆，下文的「关系」只说 @racket[betweenᵒ]、@racket[pythᵒ] 这一种，说的是数与数之间的事；代换之间的那一种就叫目标。

谓词写的条件用 @racket[and] 连起来，集合语言里写成 @math{∧}。几个目标怎样连？@racket[(betweenᵒ a h b)] 要读 @racket[a] 的值，收到的得是前一个目标 @racket[(betweenᵒ l h a)] 交出的代换；它给代换添上 @racket[b] 的值，再交给下一个目标 @racket[(betweenᵒ b h c)]。前一个目标交出的代换交给后一个：@xref["05:two-ways"]{「关系的两种写法」}里，@racket[let*] 中先后两次调用写成了 @racket[∘ℬ]；这里接起前后两个目标，用的也是 @racket[∘ℬ]。几个目标同时成立，叫@tech{合取}，照集合语言里的记号写成 @racket[∧]：

@examples[#:eval ev-goals #:no-result
(: ∧ (→ Goal ... Goal))
(define (∧ . g*) (apply ∘ℬ (reverse g*)))]

@racket[∧] 照写的顺序接：先写的先运行，和 @racket[let*] 一样，所以交给 @racket[∘ℬ] 之前要倒过来。

@racket[∧] 不限目标的个数。一个也不给呢？拿一张记着 @racket[a] 等于 1 的代换试一次：

@examples[#:eval ev-goals #:label #f
(in-amb ((∧) (list (cons a 1))))]

零个目标的合取把代换原样交了回来，什么也没有做：@racket[(∘ℬ)] 就是带 @racket[amb] 时的恒等函数 @racket[id]。作为代换之间的二元关系，它是@defterm[#:en "identity relation"]{恒等关系}；作为条件，它总成立，总是成功。给它起名 @racket[⊤]：

@examples[#:eval ev-goals #:no-result
(: ⊤ Goal)
(define (⊤ s) s)]

@racket[⊤] 接在哪个目标的前面或后面，都不改变那个目标，是合取的@defterm[#:en "unit"]{单位}。

@racket[⊤] 收到哪张代换都原样交回。要让一个条件总是失败，它收到代换后该交出什么？一张代换也不交，就是 @racket[(amb)]。作为代换之间的二元关系，它是一行也没有的@defterm[#:en "empty relation"]{空关系}；作为条件，它总不成立，总是失败。给它起名 @racket[⊥]：

@margin-note{前四章用 @racket[⊤] 与 @racket[⊥] 记单元类型与空类型；这里借用同一对逻辑真假记号表示 @racket[Goal] 类型的值，一个是恒等目标，一个是失败目标。}

@examples[#:eval ev-goals #:no-result
(: ⊥ Goal)
(define (⊥ s) (amb))]

有了「并且」@racket[∧]，自然还有「或者」。两个目标都是从代换到代换的二元关系，也就是同一个笛卡尔积的子集，只看哪些代换能出现，它们的并集依然是这个笛卡尔积的子集。带 @racket[amb] 时，把几个目标并起来就是从其中挑一个来用，挑哪个都算，正是 @racket[amb]。几个条件里只要有一个成立，叫@tech{析取}，照集合语言里的记号写成 @racket[∨]：

@examples[#:eval ev-goals #:no-result
(: ∨ (→ Goal ... Goal))
(define ((∨ . g*) s) ((list->amb g*) s))]

@margin-note{目标写成 ℒ 的箭头时，析取是把几张代换的列表接起来。}

一个目标也不给 @racket[∨]，就是从零个备选里挑，结果正好是失败：

@examples[#:eval ev-goals #:label #f
(in-amb ((∨) (list (cons a 1))))]

@racket[⊥] 和哪个目标并起来，都不改变那个目标；@racket[⊥] 正是析取的单位。

两头和中间都有了，@racket[run*] 可以写下来：造出未知项，从一张空的代换开始运行目标 @racket[g]，再读出那几个未知项的值。走通的每条时间线交出一组取值，由 @racket[in-amb] 收齐。

@examples[#:eval ev-goals #:no-result
(define-syntax-rule (run* (x ...) g)
  (let ([x (var 'x)] ...)
    (in-amb
     (let ([s (g '())])
       (list (value-of x s) ...)))))]

@section[#:tag "05:run"]{跑起来}

@racket[run*] 写好了，还缺一个会给 @racket[a] 添值的目标。@racket[let*] 的一行 @racket[[a (between 1 3)]]，往 Racket 的记录表里添了一个名字；@racket[(betweenᵒ 1 3 a)] 该交出的目标，就往代换里添一条记录。先手写一个，从空的代换开始运行：

@examples[#:eval ev-goals #:label #f
(define g (λ (s) (cons (cons a (between 1 3)) s)))
(in-amb (g '()))]

@racket[g] 写出来是个普通的函数，收一张代换，交出一张。可 @racket[between] 返回了三次，@racket[g] 也就交出了三张，各记着 @racket[a] 等于其中一个数。把它交给 @racket[run*]：

@examples[#:eval ev-goals #:label #f
(run* (a)
  (λ (s) (cons (cons a (between 1 3)) s)))]

三张代换，读出来是三组答案。

一般的 @racket[(betweenᵒ l h a)] 里，@racket[l]、@racket[h] 可能是未知项，要先用 @racket[value-of] 读出值，再交给 @racket[between]；@racket[between] 交出的数，照 @racket[g] 的样子记在最后一个位置上。前三条条件里，最后一个位置都是还没有值的未知项，往代换里添一条记录就够了。@racket[(pythᵒ a b c)] 的三个位置都是给 @racket[pyth?] 的，全要读出值。谓词的是与否，成了目标的两种回答：成立就原样交回代换，不成立就一张也不交。

@examples[#:eval ev-goals #:no-result
(: function->relation (∀ (a ... b) (→ (→ℬ a ... b) (→ Term ... Term Goal))))
(define (((function->relation f) . t*) s)
  (define-values (in* out*) (split-at-right t* 1))
  (cons (cons (car out*) (apply f (for/list ([t in*]) (value-of t s)))) s))

(: predicate->relation (∀ (a ...) (→ (→ a ... Boolean) (→ Term ... Goal))))
(define (((predicate->relation p?) . t*) s)
  (check (apply p? (for/list ([t t*]) (value-of t s))))
  s)]

@margin-note{这里的 @racket[a ...] 与 @racket[b] 是 @racket[Data] 的子类型（如 @racket[ℕ⁺]）；包装后的关系多出一个结果位置，调用时读出的已知参数仍需落在原函数或谓词的定义域里。}

@xref["05:relation"]{「关系」}数过，零元关系只有两个，@math{{()}} 与 @math{{}}，对应两个零参谓词 @racket[(λ () #t)] 与 @racket[(λ () #f)]。把它们交给 @racket[predicate->relation]，再把这个零元关系无参调用一次，就得到目标：

@examples[#:eval ev-goals #:label #f
(run* () ((predicate->relation (λ () #t))))
(run* () ((predicate->relation (λ () #f))))]

就算一个未知项也不问，成功一次和一次也没成功，交出的列表仍然不同：第一行有一个答案，因为没有未知项要读，那个答案就是空元组 @racket['()]；第二行一个答案也没有。两个谓词都没有参数要查，真时把收到的代换原样交回，假时一张也不交，对任意代换都正好是刚才的 @racket[⊤] 和 @racket[⊥]。

想要的写法里缺的东西都有了。伪代码原样运行：

@examples[#:eval ev-goals #:no-result
(define betweenᵒ (function->relation  between))
(define pythᵒ    (predicate->relation pyth?))

(define (right-triangles l h)
  (run* (a b c)
    (∧ (betweenᵒ l h a)     (code:comment "l ≤ a ≤ h")
       (betweenᵒ a h b)     (code:comment "a ≤ b ≤ h")
       (betweenᵒ b h c)     (code:comment "b ≤ c ≤ h")
       (pythᵒ a b c))))     (code:comment "a² + b² = c²")]

上下界仍取 1 和 20：

@examples[#:eval ev-goals #:label #f
(right-triangles 1 20)]

还是那六组。同样的四条条件，接成一个目标后不读出，直接看它交出的代换：

@examples[#:eval ev-goals #:label #f
(define c (var 'c))
(in-amb
 ((∧ (betweenᵒ 1 20 a)
     (betweenᵒ a 20 b)
     (betweenᵒ b 20 c)
     (pythᵒ a b c))
  '()))]

六张代换，一张对着一组答案。@racket[right-triangles] 是边界与三角形之间的二元关系，四条条件接成的目标是代换与代换之间的二元关系。给定一组边界，从这个目标交出的每张代换里用 @racket[value-of] 读出 @racket[a]、@racket[b]、@racket[c]，就得到 @racket[right-triangles] 表里对应的三角形。
