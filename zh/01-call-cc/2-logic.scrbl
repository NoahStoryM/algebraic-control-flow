#lang acf/scribble

@title[#:tag "01:2-logic"]{类型里的逻辑}

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define-type ⊥ (∪))
(define primitive-call/cc call/cc)
(define (goto l) (l l))
(define (label) (primitive-call/cc goto))]

标签、@racket[cc]、@racket[call/cc] 能互相写出，签名却各不相同。
这些操作符的实现用到了 @racket[label]、@racket[goto] 和
@racket[set!]，签名里却一样也看不到，只用到
@math{→}、@math{⊥}、@math{∪} 三样东西：

@racketblock[
(: cc      (∀ (p) (→ (∪ p (→ p ⊥)))))
(: call/cc (∀ (p) (→ (→ (→ p ⊥) p) p)))]

如果把 @math{⊥} 读作假，@math{→} 读作「如果……那么……」，@math{∪}
读作「或」，这两个签名读起来就像两条命题。这只是字面上的相像，
还是经得起检验？

@section[#:tag "01:from-bottom"]{从 @math{⊥} 出发}

在这个类比中，没有值的@tech{空类型} @racket[⊥] 应该对应假：
假命题没有证明，@racket[⊥] 也没有值。如果这个类比成立，那么
@math{p → ⊥} 就对应逻辑中的否定：给定 @math{p} 的证明，推出假。
而@tech{延续}的类型正是 @math{p → ⊥}。

验证一下。@math{⊥} 的否定是 @math{⊥ → ⊥}。恒等函数就具有这个类型。
更一般地，从 @racket[⊥] 出发，推出什么都行。先看一个奇怪的函数：

@examples[#:eval ev #:label #f #:no-prompt
(: absurd (∀ (q) (→ ⊥ q)))
(define absurd (case-λ))]

@racket[case-λ] 按参数的个数分情形定义函数，每个子句对应一种调用方式。
一个子句也没有的 @racket[(case-λ)]，没有任何调用方式能与它匹配，
这样的函数永远不会被调用。这正合 @racket[⊥] 的情形：@racket[⊥]
没有值，谁也交不出一个来给它。既然永远不会被调用，
说它交出什么类型都不会错，所以 @racket[absurd] 的类型是
@math{⊥ → q}，@math{q} 任意。从@tech{空类型}可以推出任何东西。

所以假的否定是非空的：它是真的，逻辑中 @math{¬⊥} 也确实为真。
这个类比目前站得住脚。

那么非空类型的否定呢？类型 @math{@ty{Real} → ⊥}
是一个接受实数且永不返回的函数。我们能构造出具有该类型的表达式吗？
只用普通的 @racket[λ] 和函数调用，并且暂不考虑永不终止的程序，
写不出来：函数体最终要交出一个值，而 @racket[⊥] 没有值可交。
前面见到的@tech{延续}，都是 @racket[cc]、@racket[call/cc]
这样的控制操作符在运行时捕获出来的，不是用 λ 写出来的。

所以对于任何非空的类型 @math{p}，只用纯函数，类型 @math{p → ⊥}
是空的：真命题的否定是假。这个类型就是@defterm{否定}
@defsym["¬p" "p 的否定：p → ⊥，延续的类型"]@math{¬p}，
每个@tech{延续}都是一个@tech{否定}：

@examples[#:eval ev #:label #f #:no-prompt
(define-type (¬ p) (→ p ⊥))]

非空意味着为真，空意味着为假。为一个类型写出表达式，
就是证明对应的命题。

@section[#:tag "01:types-to-logic"]{从类型到逻辑}

「非空即真」的读法能推广到我们用过的其他类型构造子吗？假设有两个表达式
@math{x} 和 @math{y}，类型分别是 @math{p} 和 @math{q}。
从这个设定出发，我们可以构造出：

@itemlist[#:style 'ordered
  @item{@math{p → q} 类型的表达式 @racket[(λ (x) y)]：给定一个
  @math{p}，就能产出一个 @math{q}。也就是说：如果 @math{p} 成立，那么
  @math{q} 成立。这是@defterm{蕴含}，写作
  @defsym["p → q" "蕴含；函数类型"]@math{→}。}
  @item{@math{p × q} 类型的表达式 @racket[(values x y)]：把 @math{x}
  和 @math{y} 打包在一起。也就是说：@math{p} 和 @math{q} 同时成立。
  这是@defterm{合取}，写作
  @defsym["p ∧ q" "合取；多个结果 p × q"]@math{∧}。}
  @item{@math{p ∪ q} 类型的表达式：@math{x} 本身就可以视为这个类型
  （@math{y} 也一样）。也就是说：@math{p} 或 @math{q} 成立。
  这是@defterm{析取}，写作
  @defsym["p ∨ q" "析取；联合类型 p ∪ q"]@math{∨}。}]
有一点要单独说清：Typed Racket 的 @racket[∪] 是普通的并集，
不是不相交的联合。一个值属于 @math{p ∪ q}，并不记录它是从哪一边来的；
要分清两边，程序员得自己用 @racket[real?] 这样的谓词去问。
后面讨论@tech{析取}时，两个分支能不能分开，正取决于这一点。

@tech{合取}和@tech{析取}各有一个单位元。@tech{合取}的单位元是
@defsym["⊤" "真，合取的单位元；Typed Racket 的 (Values)"]@math{⊤}，
对应 Typed Racket 中的 @racket[(Values)] 类型：它只有一个元素，
就是什么也不交出的 @racket[(values)]。把它和别的结果放在一起，
等于什么也没加，所以 @math{p ∧ ⊤ = ⊤ ∧ p = p}。@tech{析取}的单位元是
@math{⊥}，也就是 @racket[(∪)] 类型：它没有任何值，并进去也什么都不多，
所以 @math{p ∨ ⊥ = ⊥ ∨ p = p}。

每个类型构造子都对应一个逻辑连接词。类型是命题，表达式是证明，
构造程序就是构造证明。这个对应关系有一个名字：@defterm{Curry-Howard
对应}。

逻辑课本里和这些签名长得像的定律，还有一条 Peirce 律，比
@racket[call/cc] 的签名多一个变量。借 @racket[absurd]，
签名正好可以放宽成那个样子。交给 @racket[proc] 的@tech{延续}，类型是
@math{p → ⊥}。把 @racket[absurd] 接在@tech{延续} @racket[k]
后面，@racket[(compose absurd k)] 的类型就是 @math{p → q}。它的行为和
@racket[k] 完全一样：一调用，@racket[k] 就跳走，永远到不了
@racket[absurd]。所以交给 @racket[proc] 的@tech{延续}也可以看作
@math{p → q}，@racket[call/cc] 的类型随之变成
@math{((p → q) → p) → p}；令 @math{q = ⊥}，就回到原来的类型。

用 @math{¬} 和 @math{∨} 改写，这些签名都成了命题，各自对上一条定律：
@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list @elem{操作符} @elem{命题} @elem{定律})
   (list @elem{@racket[cc]} @elem{@math{p ∨ ¬p}}
         @elem{@defterm[#:en "law of excluded middle"]{排中律}})
   (list @elem{@racket[call/cc]} @elem{@math{(¬p → p) → p}} @elem{Clavius 律})
   (list @elem{@racket[call/cc]} @elem{@math{((p → q) → p) → p}}
         @elem{Peirce 律})
   (list @elem{@racket[absurd]} @elem{@math{⊥ → q}} @elem{爆炸原理}))]

而 @math{@ty{Label} = @ty{Label} → ⊥} 变成
@math{@ty{Label} = ¬@ty{Label}}：一个自身@tech{否定}的类型。

表里的定律分两种。爆炸原理在直觉主义逻辑里也成立，@racket[absurd]
也确实只用一个空的 @racket[case-λ] 就写了出来。
其余三条只在经典逻辑中成立，只承认构造性证明的逻辑一般证不出它们；
我们的操作符也正是靠捕获@tech{延续}才实现它们的。

@section[#:tag "01:where-fails"]{对应关系在哪里失效}

@tech{Curry-Howard 对应}在纯粹的全函数语言（如 Agda 和 Coq）
中是精确的：对任意非空的 @math{p}，@math{¬p} 确实是空的。
真实的编程语言打破了这一点。

考虑 @racket[(define (loop) (loop))]。它的类型是 @math{→ ⊥}，即
@math{⊤ → ⊥ = ¬⊤}：真的@tech{否定}。在纯粹理论中，@math{¬⊤}
应该是空的，因为真不可反驳。但 @racket[loop]
是这个类型下合法的表达式，只不过一调用就永不终止。在非全函数语言中，
合法的表达式不一定终止，因此并非每个表达式都是证明。

类似地，内置的 @racket[exit] 的类型是
@math{@ty{Byte} → ⊥ = ¬@ty{Byte}}。借助 @racket[exit]，我们可以为任意
@math{p} 构造 @math{¬p}：@racket[(λ (_) (exit 0))]。
任何真命题的@tech{否定}都变成了非空。

还有第三种失效。我们的类型 @math{@ty{Label} = ¬@ty{Label}}
是一个自身@tech{否定}的类型，读作命题，就是一句「这句话是假的」。
推一推：如果它为真（非空），那么 @math{¬@ty{Label}} 也非空，
它的@tech{否定}为真，说的正是它为假。如果它为假（空），
它的@tech{否定}反倒有值：空类型出发的函数总写得出来，就像
@racket[absurd] 填充了 @math{⊥ → p}；可
@math{¬@ty{Label} = @ty{Label}}，于是它又有了值，变成了真。

这就是@defterm{说谎者悖论}，它无法被一致地赋予真假值。
一个类型在自己的定义里出现在否定的位置（@math{→} 的左侧），
这样的递归类型没法当作一致的命题来解读，所以 Agda 和 Coq
这样的一致类型论用@defterm{正性}条件禁止这类定义。Racket
没有这个限制。悖论是合法的，我们可以构造 @racket[Label] 类型的值。

每种情况下，严格的 Curry-Howard 解读都失效了：
本应为空的@tech{否定}类型有了值，本应非法的自指类型变得合法。
我们把这个对应关系当作结构性的指引：类型的结构映射到逻辑连接词的结构，
即便严格的逻辑解读不再精确。后文说一个类型「既真又假」，
或者由类型读出程序会做什么，都是这种意义上的指引，不是可靠的逻辑推导。

@section[#:tag "01:watershed"]{分水岭}

在引入 @racket[cc] 和 @racket[call/cc] 之前，我们拥有的一切（函数、
积、联合、@math{⊤}、@math{⊥}）都属于@defterm{直觉主义逻辑}：
构造性类型系统所自然栖居的逻辑。那么 @racket[cc] 和 @racket[call/cc]
到底添加了什么？

换个问法：只用函数，我们能拿@tech{延续}做什么？回到最后那版
@racket[mul]。里面有一个实数 @racket[r]，还有一个@tech{延续}
@racket[return]，它等一个实数，类型是 @math{¬@ty{Real}}。

最直接的是调用：@racket[(return r)]，把实数交给等着它的@tech{延续}。
给这个操作起个名字：

@examples[#:eval ev #:label #f #:no-prompt
(: apply-cont (∀ (p) (→ (¬ p) p ⊥)))
(define (apply-cont kv . v*) (apply kv v*))]

@tech{延续}是函数，所以它就是函数调用。

要是@tech{延续}还没来，手里只有 @racket[r] 呢？调用不了，
但可以先写一个函数等
着：@racket[(λ (return) (return r))]，@racket[return] 一来，就把
@racket[r] 交给它。它等的是一个 @math{¬@ty{Real}}，类型是
@math{¬¬@ty{Real}}。做的还是调用，只是值先到，@tech{延续}后到。

反过来，要是手里只有这样一个等@tech{延续}的函数，
想要的却是里面的实数呢？它在等一个 @racket[return]，可是没有人交给它。
只用函数，这一步做不到，要靠 @racket[call/cc]：
它把当前@tech{延续}交给这个函数当作 @racket[return]，实数交到
@racket[return] 手里，也就回到了调用 @racket[call/cc] 的地方。

可 @racket[call/cc] 的签名说，交给它的函数可以正常返回一个 @math{p}。
最后那版 @racket[mul] 里的 @racket[λ] 就是这样，没遇到零，
乘积是正常返回的。这和一个只等@tech{延续}、从不正常返回的函数是一回事
吗？是一回事。下面两个表达式行为相同：

@racketblock[
(call/cc proc)
(call/cc (λ (k) (k (proc k))))]

@racket[call/cc] 交给 @racket[proc] 的 @racket[k]，通向的是
@racket[call/cc] 返回之后的地方。而调用 @racket[proc] 是
@racket[call/cc] 做的最后一件事，@racket[proc] 正常返回时，
返回值也直接交到那里。所以 @racket[proc] 的结果不论经 @racket[k]
显式交出，还是正常返回，都走到同一个出口；正常返回时隐含经过的，
就是这条看不见的@tech{延续}。包了一层的 @racket[(λ (k) (k (proc k)))]
从不正常返回，类型是 @math{(p → ⊥) → ⊥}，即 @math{¬¬p}。
照这个读法，@racket[call/cc] 的类型是 @math{¬¬p → p}：
交给它一个等@tech{延续}的计算，它从中把结果取出来。

再进一步，连等@tech{延续}的函数也不要，直接把当前@tech{延续}拿到手里。
这就是 @racket[(cc)]：它先交出当前@tech{延续}，等有人把实数传回来，
再交出那个实数。手里原本什么也没有，它交出的却总是两者之一，一个实数，
或者一个等实数的@tech{延续}，事先不要求谁给出任何一支。

这四步，逻辑里各有一个名字。调用@tech{延续}，就是@defterm{矛盾律}：
一个 @math{¬p} 和一个 @math{p} 放在一起，得到 @math{⊥}。
先写一个函数等着@tech{延续}，就
是@defterm[#:en "Double Negation Introduction" #:abbr "DNI"]{双重否定
引入}：从 @math{p} 得到 @math{¬¬p}。

这两步只用函数就够了。回想@xref["01:from-bottom"]{「从 ⊥ 出发」}一节：
对非空的 @math{p}，只用 @racket[λ]，凭空写不出一个
@math{¬p}，@tech{延续}只能由别人交来。调用用的是手里现成的
@racket[return]；先写一个函数等着，是等别人把 @racket[return] 交进来。
两步都只用交到手里的东西，是@defterm[#:en "constructive"]{构造性}的：
结论里的每样东西，都由交到手里的东西做成。

后两步不一样。@racket[call/cc] 和 @racket[cc]
凭空提供了一个@tech{延续}，就是当前@tech{延续}。@racket[call/cc]
把它交给一个等着的函数，从 @math{¬¬p} 得到 @math{p}，
这是@defterm[#:en "Double Negation Elimination" #:abbr "DNE"]{双重否定
消除}。@racket[cc] 干脆把它交到我们手里；以后可能经由它跳回来，让
@racket[(cc)] 再返回一次，所以交出的东西得容得下两种情况：
第一次是@tech{延续}，跳回来时是值，于是成了 @math{p ∨ ¬p}，
这是@tech{排中律}。凭空提供一个@tech{延续}，这是经典的。

排成一张表：

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list "" @elem{构造性} @elem{经典})
   (list @elem{@math{p} 与 @math{¬p}}
         @elem{@bold{@tech{矛盾律}}：@racket[apply-cont]（函数调用）}
         @elem{@bold{@tech{排中律}}：@racket[cc]（捕获@tech{延续}）})
   (list @elem{@math{p} 与 @math{¬¬p}}
         @elem{@bold{DNI}：@racket[(λ (k) (k v))]}
         @elem{@bold{DNE}：@racket[call/cc]（捕获@tech{延续}）}))]

表里每一列的上下两格，其实是一回事。左边一列都是调用@tech{延续}，
只差值和@tech{延续}谁先到：@math{¬p → p → ⊥} 和 @math{p → ¬p → ⊥}
只差参数的次序，@tech{矛盾律}和 DNI 互相推得出。
右边一列都是提供当前@tech{延续}，只差交给一个函数还是交到手
里。@racket[cc] 能@xref["01:label-from-call-cc"]{用 @racket[call/cc]
写出}，就是 @racket[(call/cc values)]；@racket[call/cc]
也能@xref["01:call-cc"]{用 @racket[cc] 写出}，那段代码先调用
@racket[(cc)]，拿到传回的结果就交出，拿到@tech{延续}就交给
@racket[proc]。把 @racket[proc] 读成一个等@tech{延续}的函数，
它读起来正是由@tech{排中律}推出 DNE：@racket[(cc)] 交出 @math{p}
那一支，就直接交出；交出 @math{¬p} 那一支，就交给 @racket[proc]，
得到的 @math{⊥} 照爆炸原理（@racket[absurd]）
可以当作任何类型。@tech{排中律}和 DNE 作为对任意类型都成立的原则，
同样互相推得出，经典的成分只在提供当前@tech{延续}的那一步。

@bold{练习}：@italic{实质条件} @math{¬p ∨ q} 是经典逻辑中 @math{p → q}
的另一种编码。试着实现 @c{material->procedure : (¬p ∨ q) → p → q} 和
@c{procedure->material : (p → q) → ¬p ∨ q}。（@racket[∪] 不记来源，
为了分得清两支，不妨让 @math{q} 取 @racket[Real]
这样能用谓词分辨的类型。）你会发现其中一个方向需要 @racket[cc]，
是哪一个？

可是，从 @math{¬¬p} 取出 @math{p}，非得凭空拿到一个@tech{延续}不可吗？

@section[#:tag "01:substitute"]{代入不同的类型}

到目前为止，对应关系一直是从程序读向逻辑：先写出操作符，
再认出它的类型是哪条定律。现在反过来用。

逻辑里，一条定律对任何命题都成立；把一个具体的命题代进去，
就得到它的一个实例。在程序里，就是给类型参数 @math{p}
填上一个具体的类型。直觉主义定律的实例，本来就能用 @racket[λ] 写出。
经典定律不同：@racket[call/cc] 要对每一个 @math{p} 都管用，
只好去捕获当前@tech{延续}。可要是 @math{p} 只是某一个具体的类型，
手里也许就有别的办法。把几个具体的类型代进 DNE @math{¬¬p → p}，
看看哪些要捕获，哪些不用。

@subsection[#:tag "01:program-type"]{程序的类型}

先代入最朴素的一个：退出码的类型 @racket[Byte]，得到
@math{¬¬@ty{Byte} → @ty{Byte}}。光看类型，这个实例很容易
写：@racket[(λ (kk) 0)] 就是，什么也不捕获。
逻辑上也不奇怪：@racket[Byte] 有值，是真命题，从任何前提推出它都成立，
丢掉前提、直接拿出一个 @racket[Byte] 就是证明。

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

真实的操作系统也是这样运行程序的。启动一个程序时，OS
提供一个退出通道，进程通过它交回状态码，然后 OS 接管。
交回的方式有两种：显式地调用 @racket[exit]，或者从 @racket[main]
返回。C 语言规定后者等于拿返回值调用 @racket[exit]，正是上面外层那个
@racket[(exit …)]。

所以程序是一个 @math{¬¬@ty{Byte}}：它等着计算终结处的那条@tech{延续}。
站在 OS 这一边看，运行它，就是把这条@tech{延续}交给它，
再收下它交来的退出码，从 @math{¬¬@ty{Byte}} 得到 @racket[Byte]，
正是@xref["01:watershed"]{「分水岭」}里的 DNE。

在语言里模拟 @racket[exit]，得靠 @racket[call/cc]
捕获当前@tech{延续}；真实的程序却不用自己捕获。OS 启动程序时，
计算终结处的当前@tech{延续}已经在那里了，就是 @racket[exit]，
直接交给程序就行，不必再用 @racket[cc] 或 @racket[call/cc] 去捕获。
程序把退出码交给 @racket[exit]，这次调用不会回到程序里的当前位置，OS
接到的就是退出码本身。从 @math{¬¬@ty{Byte}} 到 @racket[Byte]
的这一步，在语言的边界上完成。

@subsection[#:tag "01:neg-q"]{代入 @math{¬q}}

再换一个类型。不代入一个光秃秃的类型，而是代入一个本身就是否定的类型
@math{¬q}：

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

试一试。用 @racket[call/cc] 拿到一条真正的@tech{延续} @racket[k]，
当作一个 @math{¬q}；照 DNI 的写法把它包成一个 @math{¬¬¬q}，再交给
@racket[triple-negation] 取回 @math{¬q}，把 @racket['hello] 交给它：

@examples[#:eval ev #:label #f
(call/cc
 (λ (k)
   ((triple-negation (λ (kkq) (kkq k))) 'hello)))]

@racket['hello] 经 @racket[k] 交到了 @racket[call/cc] 返回的地方。

为什么这一次不用捕获？要交出的结果本身也是一个函数，
就可以先把它交出去；等它收到 @racket[q]，再用 @racket[q]
构造出所需的双重否定。@racket[call/cc] 却要对任何类型都成立，
不知道结果是不是一个函数，只能当场把计算跑起来，取出一个结果。
这条定律叫@defterm[#:en "law of triple negation"]{三重否定律}，
是一条直觉主义定理。

@subsubsection[#:tag "01:layers"]{数一数层数}

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

@xref["01:watershed"]{「分水岭」}的四种情形，用层数说就是：

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

层数还带出一个规律。DNI、DNE 一次加减两层，不改变奇偶，@tech{矛盾律}却
要一奇一偶。奇偶不同的两个值，把低的那个反复做 DNI，
总能升到与另一个相邻，再调用，@racket[triple-negation] 就是这样做的。
从 @math{p ∨ ¬p} 出发，两支各做几次 DNI，也就得到任意的「偶数层 ∨
奇数层」，用不着 DNE。奇偶相同的两个，只靠 DNI、DNE 凑不成相邻。

回到@xref["01:watershed"]{「分水岭」}留下的问题：从 @math{¬¬p} 取出
@math{p}，非得凭空拿到一个@tech{延续}不可吗？
不一定。@xref["01:program-type"]{「程序的类型」}里，那条@tech{延续}由
OS 交来；@racket[triple-negation] 更省事，连交来的@tech{延续}也不需
要，它交出的 @math{¬q}，用交进来的 @racket[kkkq] 就做成了。

用层数说，区别在要交出的东西落在哪一层。落在第 1 层或更高，
要交出的是一个函数，可以先交出去，等下一层的值来了再算。落到第 0 层，
就得当场交出一个值，这时就没有对任何类型都适用的纯 λ 写法了；
要把计算真的跑起来，得像运行程序那样，由外面交来一条@tech{延续}。

层数也照出了两种逻辑的分别。把能互相推出的层归为一类：

@itemlist[
  @item{经典逻辑里，DNI 加两层，DNE 减两层，相差两层的都能互推，
  一座塔只剩两类：偶数层，奇数层。}
  @item{直觉主义逻辑里，DNE 一般不成立，但三重否定律能从第 3 层回到第
  1 层，从第 4 层回到第 2 层……只有第 0 层回不去。塔分成三类：第 0 层，
  奇数层，第 2 层起的偶数层。}]
在这座否定塔上，两种逻辑的区别，就在第 0 层是否与其余的偶数层合并。

