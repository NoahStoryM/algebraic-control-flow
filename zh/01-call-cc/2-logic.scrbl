#lang acf/scribble

@title[#:tag "01:2-logic"]{Curry-Howard 对应}

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define-type ⊥ (∪))
(define primitive-call/cc call/cc)
(define (goto l) (l l))
(define (label) (primitive-call/cc goto))]

上一小篇里，@racket[goto] 和@tech{延续}交出的类型都是 @racket[⊥]。交出
@racket[⊥]，说的是这段计算不会有结果交回来：一调用，
控制流就切换到了别处。

这样的调用可以出现在任何位置。最后那版 @racket[mul] 里，
@racket[(return r)] 和 @racket[(* res r)] 是 @racket[if] 的两个分支，
一个交出 @racket[⊥]，一个交出实数，类型对不上；@racket[for/fold]
要的是实数，@racket[(return r)] 交不出实数，程序却照样运行。
这是为什么？

@section[#:tag "01:call-cc-types"]{@racket[call/cc] 的几种类型}

答案在 @racket[⊥] 本身。先造一个奇怪的函数：

@examples[#:eval ev #:label #f #:no-prompt
(: absurd (∀ (q) (→ ⊥ q)))
(define absurd (case-λ))]

@racket[case-λ] 按参数的个数分情形定义函数，每个子句对应一种调用方式。
一个子句也没有的 @racket[(case-λ)]，没有任何调用方式能与它匹配，
一调用就报错。这正合 @racket[⊥] 的情形：@racket[⊥] 类型没有元素，
谁也交不出一个来给它，类型正确的程序里根本调用不到它。既然调用不到，
说它交出什么类型都不会错，所以 @racket[absurd] 的类型是
@math{⊥ → q}，@math{q} 任意。

有了它，前面的疑问就解开了。@racket[(return r)] 交出 @racket[⊥]，接上
@racket[absurd]，@racket[(absurd (return r))] 就能当作实数用；
@racket[absurd] 其实从来不会被调用，因为 @racket[(return r)]
根本不会交回来。交出 @racket[⊥] 的表达式，放在要什么类型的位置都行。

同样的道理，也能重新看 @racket[call/cc] 的类型。它原来的类型是：

@racketblock[
(: call/cc (∀ (p) (→ (→ (→ p ⊥) p) p)))]

先放宽。交给 @racket[proc] 的@tech{延续} @racket[k] 永不返回，后面接上
@racket[absurd]，@racket[(compose absurd k)] 的行为和 @racket[k]
一样，类型却是 @racket[(→ p q)]，@math{q} 任意。所以 @racket[call/cc]
也有这样的类型：

@racketblock[
(: call/cc (∀ (p q) (→ (→ (→ p q) p) p)))]

令 @math{q = ⊥}，就回到原来那一种。

再看另一头。假如 @racket[proc] 总会调用交给它的@tech{延续}
@racket[k]，它自己就从不正常返回，返回类型是 @racket[⊥]，类型也就成了
@racket[(→ (→ p ⊥) ⊥)]。用同样的办法，后面接上 @racket[absurd]，
@racket[(compose absurd proc)] 的类型就回到了 @racket[(→ (→ p ⊥) p)]，
正好交得给 @racket[call/cc]。所以 @racket[call/cc] 也有这样的类型：

@racketblock[
(: call/cc (∀ (p) (→ (→ (→ p ⊥) ⊥) p)))]

交给它一个只等@tech{延续}的计算，它从中把结果取出来。

这样收紧，其实没有少掉什么。原来的类型允许 @racket[proc] 正常返回一个
@math{p}，最后那版 @racket[mul] 里的 @racket[λ] 就是这样，没遇到零，
乘积是正常返回的。可通过 @racket[(call/cc proc)] 调用 @racket[proc]
时，交给 @racket[proc] 的@tech{延续} @racket[k]，和调用 @racket[proc]
这一处的@tech{延续}，都是调用 @racket[call/cc] 时的当前@tech{延续}：
调用 @racket[proc] 是 @racket[call/cc] 做的最后一件事，@racket[proc]
正常返回，返回值也直接交到那里。所以下面两个表达式行为相同：

@racketblock[
(call/cc proc)
(call/cc (λ (k) (k (proc k))))]

@racket[proc] 的结果不论经 @racket[k] 显式交出，还是正常返回，
都走到同一个出口；正常返回时隐含经过的，就是一条看不见的@tech{延续}。
第二行交给 @racket[call/cc] 的那整个 @racket[λ] 总会调用 @racket[k]，
正是上面那种只等@tech{延续}的函数。

于是手里有了四个类型，@racket[absurd] 的一个，@racket[call/cc]
的三个，都只用 @math{→} 和 @math{⊥}。它们像在说些什么？

@section[#:tag "01:from-bottom"]{读成命题}

一个类型为 @racket[(→ Real Byte)] 的函数，向用它的人担保：
只要交给它一个实数，就能拿回一个字节。写出这样一个函数，
就是兑现了这句担保。这很像逻辑里的一句「如果……那么……」：如果有实数，
那么有字节。

照这个样子，把类型看作命题，不依赖额外的假设写出一个这种类型的表达式，
就像给出了这个命题的证明。一般地，设 @math{p}、@math{q} 是两个类型，
也就是两个命题。函数 @racket[(λ (x) body)] 的形参 @racket[x] 是一个
@math{p}，函数体 @racket[body] 用到 @racket[x]，算出一个 @math{q}，
这个函数的类型就是 @math{p → q}：有了 @math{p} 的证明，就造得出
@math{q} 的证明。这是@defterm{蕴含}，写作
@defsym["p → q" "蕴含；函数类型"]@math{→}。

这样读，一个命题为真，就是写得出这个类型的表达式。
@racket[(→ Real Byte)] 为真，随手就能写一个，比如 @racket[(λ (r) 0)]。

那假呢？最典型的是 @racket[⊥]：@tech{空类型}没有元素，
写不出这个类型的表达式，正像假命题没有证明。一个命题为假，
就是从它能推出假，写得出一个 @math{p → ⊥}：有了 @math{p}，就推出
@math{⊥}。这和「写不出 @math{p}」不是一回事：有的命题自己写不出，
它的否定也写不出。@math{p → ⊥} 就是@defterm{否定}
@defsym["¬p" "p 的否定：p → ⊥，延续的类型"]@math{¬p}，与 @math{p}
正好相反。@tech{延续}的类型正是 @math{p → ⊥}，
每个@tech{延续}都是一个@tech{否定}：

@examples[#:eval ev #:label #f #:no-prompt
(define-type (¬ p) (→ p ⊥))]

假的否定该是真的。确实写得出 @math{⊥ → ⊥} 类型的表达式，恒等函数就是。

用 @math{¬} 改写，四个类型读出来，是四句话。@racket[absurd] 的
@math{⊥ → q}：从假推出任何东西。@racket[call/cc] 原来的
@math{(¬p → p) → p}：如果从「@math{p} 不成立」能推出 @math{p}，那么
@math{p} 成立。放宽的 @math{((p → q) → p) → p}：如果从「@math{p}
推出随便什么」能推出 @math{p}，那么 @math{p} 成立。收紧的
@math{¬¬p → p}：如果 @math{p} 的否定不成立，那么 @math{p} 成立。
逻辑课本里，这四句都有名字：

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list @elem{程序} @elem{命题} @elem{定律})
   (list @elem{@racket[absurd]} @elem{@math{⊥ → q}}
         @elem{@defterm[#:en "principle of explosion"]{爆炸原理}})
   (list @elem{@racket[call/cc]} @elem{@math{(¬p → p) → p}}
         @elem{@defterm{Clavius 律}})
   (list @elem{@racket[call/cc]} @elem{@math{((p → q) → p) → p}}
         @elem{@defterm{Peirce 律}})
   (list @elem{@racket[call/cc]} @elem{@math{¬¬p → p}}
         @elem{@defterm[#:en "Double Negation Elimination" #:abbr "DNE"]{双重否定消除}}))]

这不是巧合。每个类型构造子都对应一个逻辑连接词：类型是命题，
表达式是证明，构造程序就是构造证明。这个对应关系有一个名字：
@defterm{Curry-Howard 对应}。

倒回一步，看 @racket[cc]。

@section[#:tag "01:types-to-logic"]{合取与析取}

@racket[cc] 的类型是

@racketblock[
(: cc (∀ (p) (→ (∪ p (→ p ⊥)))))]

这回读不下去了：它不收参数，交出的又是一个 @math{∪}，
这两样还不知道该怎么读。先说不收参数。否定 @math{p → ⊥} 与 @math{p}
正好相反。把 @math{⊥} 换成恰好有一个元素的类型
@defsym["⊤" "真，恰好有一个元素的类型"]@math{⊤}，再把箭头反过来，
得到的 @math{⊤ → p} 却和 @math{p} 一样。它就是不收参数的函数
@racket[(→ p)]，我们熟悉的 thunk：拿到一个 thunk，调用它就拿到一个
@math{p}；拿到一个 @math{p}，也总能包成 @racket[(λ () a)]。
两边能来回换，从真推出 @math{p}，就是 @math{p} 成立。@racket[cc]
是一个 thunk，读它的类型，只看它交出什么就行。

调用 thunk 时，什么也不交给它。Racket 里「什么也不交」也有写法：
@racket[(values)] 交出零个结果。这样的交法只有一种，正合 @math{⊤}
只有一个元素：把一次交出的结果整体来看，@racket[(values)] 对应
@math{⊤}。这里的「零」说的是一次交出几个结果，不是类型有几个元素；
一种交法也没有的，才是 @math{⊥}。照这样看，@racket[(values x y)]
交出两个结果，整体对应积 @math{p × q}：两样都在手里，@math{p} 与
@math{q} 同时成立。这是@defterm{合取}，写作
@defsym["p ∧ q" "合取；多个结果 p × q"]@math{∧}。@racket[(values)]
是它的单位元：零个结果并上去，什么也没多出来，就像「真且 @math{p}」
就是 @math{p}。函数的两个参数，也可以这样合起来，看成一个
@math{p × q}。

@margin-note{@racket[∪] 有一个容易误读的地方。集合 @math{X = {a, b}}、
@math{Y = {b, c}} 的并集里，@math{b} 说不清来自哪一边。
打上标签再并起来，@math{X + Y = X × {0} ∪ Y × {1}}，两边就不相交了，
检查标签就是一个谓词；@math{X + Y} 叫@defterm[#:en "tagged union"]{带
标签的联合}。丢掉标签，总有一个从 @math{X + Y} 到 @math{X ∪ Y}
的映射；@math{X ∩ Y = {}} 时它是一一对应，用不着标签。}

再说 @math{∪}。@racket[(cc)] 交出的 @math{p ∪ ¬p}，
用的人必须分得清拿到的是哪一支。那版 @racket[mul] 用谓词
@racket[real?] 一问就知道，实数和函数本来就不相交。@racket[call/cc]
不知道结果会是什么，结果也可能是函数，就把传回的结果包进列表，用
@racket[list?] 区分，这就是打标签。@racket[cc] 自己要决定交出哪一支，
看的是 @racket[saved] 是不是 @racket[#f]，最早那版 @racket[mul]
看的是标志 @racket[first?]：这两处靠另记一个状态来分辨，
不是在交给调用者的结果上添标记。

读作「@math{p} 或 @math{q}」，也得这样分得清：用类型表示「@math{p} 或
@math{q}」时，我们用两支分得开的联合，拿到一个值，能判断它属于哪一支，
再按那一支使用它。对应的是@defterm[#:en "disjoint union"]{不相交的联
合}：两边的元素分得开，拿到一个元素，就知道它来自哪一边；
打标签是做到不相交的一种办法。Typed Racket 的 @racket[∪]
却是普通的并集，两边分不分得开，要看 @math{p} 和 @math{q} 本身。下面把
@racket[∪] 读作「或」，说的都是这样分得开两边的联合。
这是@defterm{析取}，写作
@defsym["p ∨ q" "析取；联合类型 p ∪ q"]@math{∨}。

现在 @racket[cc] 也读得下去了：@math{p ∨ ¬p}，@math{p} 成立，或者
@math{p} 不成立。这条也有名字，
叫@defterm[#:en "law of excluded middle"]{排中律}。@racket[call/cc]
把这个分支挪进了操作符内部，它的类型里也就没有 @math{∪}，只用 @math{→}
和 @math{⊥} 就写得下。

@section[#:tag "01:watershed"]{分水岭}

@racket[cc] 对上的@tech{排中律}，@racket[call/cc] 对上的 DNE，
逻辑课本说都只在@defterm{经典逻辑}中成立。不承认它们，
只承认构造出来的证明，就是@defterm{直觉主义逻辑}。在引入 @racket[cc]
和 @racket[call/cc] 之前，我们用到的函数、积、
联合、@math{⊤}、@math{⊥}，都没有越出它的范围。

这两条经典定律，各有一条与之相对的定律，在直觉主义逻辑里照样成立。
@tech{排中律}说 @math{p} 与 @math{¬p} 至少有一个成立；
说两者不能同时成立，就是@defterm{矛盾律} @math{¬(¬p ∧ p)}。DNE 从
@math{¬¬p} 推出 @math{p}；箭头反过来，从 @math{p} 推出 @math{¬¬p}，
就是@defterm[#:en "Double Negation Introduction" #:abbr "DNI"]{双重否
定引入}。

成立的命题，照 @tech{Curry-Howard 对应}应该写得出程序。
前面是从程序读出命题，这回反过来，从命题出发找程序。

先看@tech{矛盾律}。@math{¬p ∧ p} 是一个 @math{¬p} 和一个 @math{p}
放在一起，对应函数的两个参数；整体取否定，结果是 @math{⊥}。
所以要写的是这样一个函数：收下一个@tech{延续} @racket[kv] 和一个值
@racket[v]，得到 @math{⊥}。手里能产生 @math{⊥} 的只有 @racket[kv]，
能交给它的只有 @racket[v]，写法几乎是被类型逼出来的：

@examples[#:eval ev #:label #f #:no-prompt
(: apply-cont (∀ (p) (→ (¬ p) p ⊥)))
(define (apply-cont kv v) (kv v))]

这就是调用@tech{延续}。最后那版 @racket[mul] 里的
@racket[(return r)]，就是一次 @racket[apply-cont]。

再看 DNI。给一个值 @racket[v]，要交出一个 @math{¬¬p}，也就是一个收下
@math{¬p}、结果为 @math{⊥} 的函数。理由和刚才一样，只能写成
@racket[(λ (kv) (kv v))]。做的还是调用，只是值先到，@tech{延续}后到。
从 @racket[v] 得到这个函数，就是 @racket[(curryr apply-cont)]：先给定
@racket[apply-cont] 的第二个参数。

两个程序用到的@tech{延续}都是交进来的。这不是巧合。试着只用 @racket[λ]
凭空写一个 @math{@ty{Real} → ⊥}：一个总会交出结果的函数，
函数体最终要交出一个值，可 @racket[⊥] 类型没有元素，交不出来。
前面见到的@tech{延续}，都是 @racket[cc]、@racket[call/cc]
这样的控制操作符在运行时捕获出来的，不是用 @racket[λ] 写出来的。
结论里的每样东西都由交到手里的东西做成，这样的程序
是@defterm[#:en "constructive"]{构造性}的。

@margin-note{这条定理可用直觉主义逻辑的 Kripke 语义证明，这里不展开。}

用同样的办法试经典的两条。DNE 给一个等@tech{延续}的函数 @racket[kkp]，
要交出一个 @math{p}。能对 @racket[kkp] 做的只有调用它，调用它却要一个
@math{¬p} 类型的 @racket[kp]：有了 @racket[kp]，调用 @racket[kkp] 得到
@math{⊥}，再交给 @racket[absurd] 就能当作 @math{p}。可是没有人交来
@racket[kp]，自己又构造不出，也就无法调用 @racket[kkp]。
这不只是试不出来：在上述纯函数的类型规则下，不借助额外假设，
就不存在对任意 @math{p} 都适用的 @math{¬¬p → p} 实现，
这是一条不可定义性定理。@tech{排中律}更彻底：什么也没给，要交出一个
@math{p} 或一个 @math{¬p}，两样都写不出。

@racket[call/cc] 和 @racket[cc] 补上的，正是这个缺口：
它们凭空提供了一个@tech{延续}，就是当前@tech{延续}。@racket[call/cc]
把它交给等着的函数，从 @math{¬¬p} 得到 @math{p}。@racket[cc]
干脆把它交到我们手里；以后可能经由它跳回来，让 @racket[(cc)]
再返回一次，所以交出的东西得容得下两种情况：第一次是@tech{延续}，
跳回来时是值，于是成了 @math{p ∨ ¬p}。凭空提供一个@tech{延续}，
这是经典的。

@margin-note{@racket[∪] 不记来源。为了分得清两支，不妨让 @math{q} 取
@racket[Real] 这样能用谓词分辨的类型。}

@bold{练习}：@italic{实质条件} @math{¬p ∨ q} 说「@math{p} 不成立，或者
@math{q} 成立」，是经典逻辑中 @math{p → q} 的另一种编码。试着实现
@c{material->procedure : (¬p ∨ q) → p → q} 和
@c{procedure->material : (p → q) → ¬p ∨ q}。你会发现其中一个方向需要
@racket[cc]，是哪一个？

排成一张表，每一行是一对相对的定律，每一列上下两格互相推得出：

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list "" @elem{构造性} @elem{经典})
   (list @elem{@math{p} 与 @math{¬p}}
         @elem{@bold{@tech{矛盾律}}：@racket[apply-cont]}
         @elem{@bold{@tech{排中律}}：@racket[cc]})
   (list @elem{@math{p} 与 @math{¬¬p}}
         @elem{@bold{DNI}：@racket[(curryr apply-cont)]}
         @elem{@bold{DNE}：@racket[call/cc]}))]

左边一列只差参数次序，@tech{矛盾律}和 DNI 互相推得出。
右边一列都是提供当前@tech{延续}：@racket[cc] 就是
@racket[(call/cc values)]；反过来，@xref["01:call-cc"]{用 @racket[cc]
写出的 @racket[call/cc]} 先调用 @racket[(cc)]，
拿到包在列表里的结果就拆开交出，拿到@tech{延续}就交给 @racket[proc]，
这正是由@tech{排中律}推出 DNE。作为对任意类型都成立的原则，
两者互相推得出。

可是，从 @math{¬¬p} 取出 @math{p}，非得凭空拿到一个@tech{延续}不可吗？

@section[#:tag "01:substitute"]{代入不同的类型}

@xref["01:watershed"]{「分水岭」}从定律出发找程序。
这一节接着从定律出发，换一个办法：代入。

逻辑里，一条定律对任何命题都成立；把一个具体的命题代进去，
就得到它的一个实例。在程序里，就是给类型参数 @math{p}
填上一个具体的类型。直觉主义定律的实例，本来就能用 @racket[λ] 写出。
经典定律不同：@racket[call/cc] 要对每一个 @math{p} 都管用，
只好去捕获当前@tech{延续}。可要是 @math{p} 只是某一个具体的类型，
手里也许就有别的办法。把几个具体的类型代进 DNE @math{¬¬p → p}，
看看哪些要捕获，哪些不用。

@subsection[#:tag "01:program-type"]{代入 @racket[Byte]}

这一节要看的是：@tech{延续}不一定靠捕获，也可以由运行环境交来。
先代入最朴素的一个：退出码的类型 @racket[Byte]，得到
@math{¬¬@ty{Byte} → @ty{Byte}}。选它，是因为程序最后交出的就是退出码。
这一回既看类型能不能填上，也看能不能留住交进来的计算的行为。
光看类型，@racket[(λ (kk) 0)] 就填上了，什么也不捕获。
逻辑上也不奇怪：@racket[Byte] 类型有元素，是真命题，
从任何前提推出它都成立，丢掉前提、直接拿出一个 @racket[Byte]
就是证明。

可逻辑只问命题真不真，不问拿出的是哪一个 @racket[Byte]；@racket[0]
和程序算出来的退出码，在它眼里没有分别。我们却在乎。

@racket[(λ (kk) 0)] 根本不理会交给它的那个 @math{¬¬@ty{Byte}}；
我们要的实例，得真把那个 @math{¬¬@ty{Byte}} 跑起来，交出它给出的那个
@racket[Byte]。这是运行的行为，类型里看不出来。

要找这样的实例，先得知道一个 @math{¬¬@ty{Byte}} 长什么样。最常见的，
就是一个程序：它算出一个退出码，交给 @racket[exit]，然后结束。要看清
@racket[exit] 从哪里来，假设我们的语言有 @racket[call/cc] 但没有内置的
@racket[exit]，把整个程序包在 @racket[call/cc] 里：

@racketblock[
(call/cc (λ (exit) (exit ...程序体...)))]

@racket[call/cc] 交给 @racket[λ] 的，是它被调用处的当前@tech{延续}。
这个 @racket[call/cc] 包着整个程序，它返回以后什么也不剩，
所以这条@tech{延续}通向的就是计算终结的地方：交给它一个退出码，
整个计算到此结束。这就是 @racket[exit]，计算终结时的当前@tech{延续}。
程序体里任何地方调用 @racket[(exit 0)]，都直接跳到终点；
程序体正常算完，结果也经外层的 @racket[exit] 交过去。

@racket[exit] 等一个退出码，类型是
@math{¬@ty{Byte}}。@racket[(λ (exit) (exit ...))] 等一个
@racket[exit]，无论走哪条路，结果都经 @racket[exit] 交出，
自己从不正常返回，类型是 @math{¬¬@ty{Byte}}。外层那个
@racket[(exit …)] 不能省。少了它，程序体正常结束时，
这个函数会把结果正常返回，它的类型就成了
@math{¬@ty{Byte} → @ty{Byte}}，而不是 @math{¬@ty{Byte} → ⊥}，
也就不再是 @math{¬¬@ty{Byte}}。

把等着出口的计算记作 @racket[program]，上面的做法就是
@racket[(λ (program) (call/cc program))]：它把当前@tech{延续}作为
@racket[exit] 交给 @racket[program]，并在这里接到退出码。

所以程序是一个 @math{¬¬@ty{Byte}}：它等着计算终结处的那条@tech{延续}。
真实的操作系统也是这样运行程序的：启动一个程序时，
退出通道已经在那里了，就是 @racket[exit]。程序交回退出码有两种方式：
显式地调用 @racket[exit]，或者从 @racket[main] 返回；C
语言规定后者等于拿返回值调用 @racket[exit]，正是上面外层那个
@racket[(exit …)]。对程序内部，调用 @racket[exit] 不再返回；对外部，OS
接到了退出码。OS 承担的是外部运行环境的角色：提供出口，
接收结果。@racket[exit] 在程序体里是交来的假设，在
@racket[(λ (exit) …)] 里则被绑定。把计算运行起来、
在出口接收结果的整个过程，对应@xref["01:watershed"]{「分水岭」}里的
DNE。和 @racket[call/cc] 的区别，在谁来提供这条@tech{延续}：
多数语言本身只提供 @racket[exit]，由 OS 从外面交来，
语言里什么也不用捕获；有了 @racket[call/cc]，没有 @racket[exit]
也能像上面那样自己捕获出来。

@subsection[#:tag "01:neg-q"]{代入 @math{¬q}}

再换一个类型，看看否定叠起来时会怎样。不代入一个光秃秃的类型，
而是代入一个本身就是否定的类型 @math{¬q}：

@mm{¬¬¬q → ¬q}

手里是一个 @math{¬¬¬q}，叫它 @racket[kkkq]，要交出一个
@math{¬q}。@math{¬q} 是一个函数，等一个 @racket[q]，
那就先把这个函数交出去：

@examples[#:eval ev #:label #f #:no-prompt
(define-type (¬¬  q) (¬ (¬  q)))
(define-type (¬¬¬ q) (¬ (¬¬ q)))

(: triple-negation (∀ (q) (→ (¬¬¬ q) (¬ q))))
(define (triple-negation kkkq)
  (define (kq q)
    (define (kkq kq) (kq q))
    (kkkq kkq))
  kq)]

交出去的 @racket[kq] 等一个 @racket[q]。等 @racket[q] 交来，手里就有了
@racket[q] 和 @racket[kkkq]。@racket[kkkq] 等的是一个
@math{¬¬q}，@racket[q] 还差两个否定；照 DNI 的写法包一层，@racket[kkq]
等一个 @racket[kq]，正是 @math{¬¬q}，交给 @racket[kkkq]。只有
@racket[λ] 和函数调用，什么也没有捕获。

@margin-note{@racket[let/cc] 是 @racket[call/cc]
的简写：@racket[(let/cc k body ...)] 就是
@racket[(call/cc (λ (k) body ...))]，给当前@tech{延续}起个名字
@racket[k]。}

试一试。用 @racket[let/cc] 拿到一条真正的@tech{延续} @racket[k]，照
DNI 的写法包成一个 @racket[kkkq]，交给 @racket[triple-negation]
取回一个 @math{¬q}，再把 @racket[q] 交给它：

@examples[#:eval ev #:label #f
(define q 'hello)
(let/cc k
  (define (kkkq kkq) (kkq k))
  (let ([kq (triple-negation kkkq)])
    (kq q)))]

@racket[q] 经取回的 @racket[kq] 交到了 @racket[let/cc] 返回的地方，
一路是
@racket[(kq q)]、@racket[(kkkq kkq)]、@racket[(kkq k)]、@racket[(k q)]。
取回的 @racket[kq] 和 @racket[k] 不是同一个值，行为却一样：先用 DNI
包一层，再用三重否定律取回，回到了原样。定义里 @racket[kkq] 的形参
@racket[kq]，这次收到的也正是 @racket[k]。

@math{¬¬¬q → ¬q} 这条定律叫@defterm[#:en "law of triple negation"]{三
重否定律}，是一条直觉主义定理。

@section[#:tag "01:layers"]{否定塔}

@racket[triple-negation] 里的几个名
字，@racket[q]、@racket[kq]、@racket[kkq]、@racket[kkkq]，
差的只是外面叠了几个否定。数一数，刚才的做法能说得更清楚。

固定一个类型 @math{A}，把 @math{A} 本身算作第 0 层，@math{¬A} 算作第 1
层，@math{¬¬A} 算作第 2 层，依此类推：多一层的类型，
正是「接收少一层的值、结果为 @math{⊥}」的函数类型。
谈论同一座否定塔的时候，@math{A} 要固定下来，只数它外面包了几层，
不去拆它的内部。名字也替我们数：一个值叫 @racket[v]，
等它的@tech{延续}就叫 @racket[kv]，等 @racket[kv] 的就叫
@racket[kkv]，名字里有几个 @racket[k]，就比 @racket[v] 多几层。

@xref["01:watershed"]{「分水岭」}里的四条定律，用层数说就是：

@itemlist[
  @item{@tech{矛盾律}：第 @math{n+1} 层与第 @math{n} 层相遇，得到
  @math{⊥}。}
  @item{DNI：加两层，从第 @math{n} 层升到第 @math{n+2} 层。}
  @item{DNE：减两层，从第 @math{n+2} 层落到第 @math{n} 层。}
  @item{@tech{排中律}：交出相邻两层之一，第 @math{n} 层或第 @math{n+1}
  层。}]
以 @math{q} 为底，@racket[triple-negation] 从第 3 层减到第 1 层：第 0
层的 @racket[q] 用 DNI 升到第 2 层，正好与第 3 层的 @racket[kkkq]
相邻。

接下来要比较的是，哪些层能互相推出，哪些不能。
层数先带出一个规律。DNI、DNE 一次加减两层，不改变奇偶，@tech{矛盾律}却
要一奇一偶。奇偶不同的两个值，把低的那个反复做 DNI，
总能升到与另一个相邻，再调用，@racket[triple-negation] 就是这样做的。
例如第 0 层与第 5 层：把第 0 层升到第 4 层，就能交给第 5 层。从
@math{p ∨ ¬p} 出发，左支做一次 DNI，就得到 @math{¬¬p ∨ ¬p}，第 2
层或第 1 层；两支各做几次 DNI，也就得到任意的「偶数层 ∨ 奇数层」，
用不着 DNE。奇偶相同的两个，只靠 DNI、DNE 凑不成相邻。

回到@xref["01:watershed"]{「分水岭」}留下的问题：从 @math{¬¬p} 取出
@math{p}，非得凭空拿到一个@tech{延续}不可吗？
不一定。@xref["01:program-type"]{「代入 Byte」}里，那条@tech{延续}由
OS 交来；@racket[triple-negation] 更省事，不需要另外交来一条
@math{¬q}，它交出的 @math{¬q}，用交进来的 @racket[kkkq] 就做成了。

用层数说，区别在要交出的东西落在哪一层。落在第 1 层或更高，
要交出的是一个函数，可以先交出去，等下一层的值来了再算。落到第 0 层，
就得当场交出一个值，这时就没有对任何类型都适用的纯 λ 写法了；
要把计算真的跑起来，又不捕获，就得像运行程序那样，
由外面交来一条@tech{延续}。

层数也照出了两种逻辑的分别。把能互相推出的层归为一类：

@itemlist[
  @item{经典逻辑里，DNI 加两层，DNE 减两层，相差两层的都能互推，
  一座塔只剩两类：偶数层，奇数层。}
  @item{直觉主义逻辑里，DNE 一般不成立，但三重否定律能从第 3 层回到第
  1 层；把其中的 @math{q} 换成 @math{¬A}，就从第 4 层回到第 2 层；
  依此类推，只有第 0 层一般回不去。塔分成三类：第 0 层，奇数层，第 2
  层起的偶数层。}]
这里按对任意底类型 @math{A} 都成立的互推来归类，不利用 @math{A}
的额外性质。最低的五层排出来：

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list @elem{层} @elem{经典逻辑} @elem{直觉主义逻辑})
   (list @elem{0} @elem{偶数层：与 2、4 层经 DNI、DNE 互推}
         @elem{单独一类：DNI 升到第 2 层，一般不能落回})
   (list @elem{1} @elem{奇数层} @elem{奇数层：DNI 升到第 3 层，三重否定律落回})
   (list @elem{2} @elem{偶数层} @elem{第 2 层起的偶数层：与第 4 层互推})
   (list @elem{3} @elem{奇数层} @elem{奇数层})
   (list @elem{4} @elem{偶数层} @elem{第 2 层起的偶数层：三重否定律落回第 2 层}))]

在这座否定塔上，两种逻辑的区别，就在第 0 层是否与其余的偶数层合并。

