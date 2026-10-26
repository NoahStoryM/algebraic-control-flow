#lang scribble/manual
@(require "../../lib/acf.rkt")

@title[#:tag "01:2-logic"]{类型里的逻辑}

@section{深层的逻辑}

三种风格的差别，最后都落在了类型上。@xref["01:compare"]{比较表}的第一行里有联合类型，也有高阶类型；单是
@racket[call/cc]
一个操作符，就写出了三种签名，而且每一种都成立。这些操作符的实现用到了
@racket[label]、@racket[goto] 和
@racket[set!]，签名里却一样也看不到，只用到 @m{→}、@m{⊥}、@m{∪}
三样东西。写 @racket[absurd]
时我们还顺口说了一句「从空类型可以推出任何东西」，这已经是逻辑里的说法了。把这些签名放在一起：

@racketblock[
(: cc      (∀ (p)   (→ (∪ p (→ p ⊥)))))
(: call/cc (∀ (p)   (→ (→ (→ p ⊥) p) p)))
(: call/cc (∀ (p q) (→ (→ (→ p q) p) p)))
(: call/cc (∀ (p)   (→ (→ (→ p ⊥) ⊥) p)))
(: absurd  (∀ (q)   (→ ⊥ q)))]

如果把 @m{⊥} 读作假，@m{→} 读作@tech{蕴含}，@m{∪} 读作@tech{析取}：

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list @elem{类型} @elem{像什么})
   (list @elem{@m{p ∪ (p → ⊥)}} @elem{@tech{排中律}})
   (list @elem{@m{((p → ⊥) → p) → p}} @elem{Clavius 律})
   (list @elem{@m{((p → q) → p) → p}} @elem{Peirce 律})
   (list @elem{@m{((p → ⊥) → ⊥) → p}} @elem{@tech{双重否定消除}})
   (list @elem{@m{⊥ → q}} @elem{爆炸原理}))]

五个签名，对上了五条有名字的定律。这只是字面上的相像，还是经得起检验？

@subsection{从 @m{⊥} 出发}

在这个类比中，没有值的空类型 @m{⊥}
应该对应假：不存在该类型的表达式。如果这个类比成立，那么 @m{p → ⊥}
就对应逻辑中的@tech{否定}：给定 @m{p}
的证明，推出假。而@tech{延续}的类型正是 @m{p → ⊥}。

验证一下。@m{⊥} 的@tech{否定}是
@m{⊥ → ⊥}。恒等函数就具有这个类型。更一般地，@racket[absurd] 为任意
@m{q} 提供了 @m{⊥ → q}。所以假的@tech{否定}是非空的：它是真的，逻辑中
@m{¬⊥} 也确实为真。这个类比目前站得住脚。

那么非空类型的@tech{否定}呢？类型 @m{@ty{Real} → ⊥}
是一个接受实数且永不返回的函数。我们能构造出具有该类型的表达式吗？只用普通的
@racket[λ]
和函数调用，并且暂不考虑永不终止的程序，写不出来：函数体最终要交出一个值，而
@m{⊥} 没有值可交。前面见到的@tech{延续}，都是
@racket[cc]、@racket[call/cc]
这样的控制操作符在运行时捕获出来的，不是用 λ 写出来的。

所以对于任何非空的类型 @m{p}，只用纯函数，类型 @m{p → ⊥}
是空的：真命题的@tech{否定}是假。这个类型就是@defterm{否定}
@defsym["¬p" "p 的否定：p → ⊥，延续的类型"]@m{¬p}，每个@tech{延续}都是一个@tech{否定}：

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define-type ⊥ (∪))
(define primitive-call/cc call/cc)
(define (goto l) (l l))
(define (label) (primitive-call/cc goto))]
@examples[#:eval ev #:label #f #:no-prompt
(define-type (¬ p) (→ p ⊥))]

非空意味着为真，空意味着为假。为一个类型写出表达式，就是证明对应的命题。

@subsection{从类型到逻辑}

「非空即真」的读法能推广到我们用过的其他类型构造子吗？假设有两个表达式
@m{x} 和 @m{y}，类型分别是 @m{p} 和
@m{q}。从这个设定出发，我们可以构造出：

@itemlist[#:style 'ordered
  @item{@m{p → q} 类型的表达式 @racket[(λ (x) y)]：给定一个
  @m{p}，就能产出一个 @m{q}。也就是说：如果 @m{p} 成立，那么 @m{q}
  成立。这是@defterm{蕴含}，写作
  @defsym["p → q" "蕴含；函数类型"]@m{→}。}
  @item{@m{p × q} 类型的表达式 @racket[(values x y)]：把 @m{x} 和
  @m{y} 打包在一起。也就是说：@m{p} 和 @m{q}
  同时成立。这是@defterm{合取}，写作
  @defsym["p ∧ q" "合取；多个结果 p × q"]@m{∧}。}
  @item{@m{p ∪ q} 类型的表达式：@m{x} 本身就可以视为这个类型（@m{y}
  也一样）。也就是说：@m{p} 或 @m{q} 成立。这是@defterm{析取}，写作
  @defsym["p ∨ q" "析取；联合类型 p ∪ q"]@m{∨}。（Typed Racket 的
  @racket[∪] 是普通的并集，并非真正的不相交联合；程序员必须自行用
  @racket[real?] 这样的谓词来保证不相交性。）}]
@tech{合取}和@tech{析取}各有一个单位元。@tech{合取}的单位元是
@defsym["⊤" "真，合取的单位元；Typed Racket 的 (Values)"]@m{⊤}，对应
Typed Racket 中的 @racket[(Values)] 类型：它只有一个值
@racket[(values)]，而且对任意类型 @m{p}，@racket[(Values p (Values))]
和 @racket[(Values (Values) p)] 都等价于
@m{p}（@m{p ∧ ⊤ = ⊤ ∧ p = p}）。这里的嵌套只是示意，Racket
的多个结果其实不能嵌套。@tech{析取}的单位元是 @m{⊥}，也就是
@racket[(∪)] 类型：它没有任何值，而且对任意类型
@m{p}，@racket[(∪ p (∪))] 和 @racket[(∪ (∪) p)] 都等价于
@m{p}（@m{p ∨ ⊥ = ⊥ ∨ p = p}）。

每个类型构造子都对应一个逻辑连接词。类型是命题，表达式是证明，构造程序就是构造证明。这个对应关系有一个名字：@defterm{Curry-Howard
对应}。

有了 @m{¬} 和 @m{∨}，上面的类型签名变成：

@mm{@racket[cc] : p ∨ ¬p @hspace[8] @racket[absurd] : ⊥ → q}

@mm{@racket[call/cc] : (¬p → p) → p @ty{ 或 } ((p → q) → p) → p @ty{ 或 } ¬¬p → p}

而 @m{@ty{Label} = @ty{Label} → ⊥} 变成
@m{@ty{Label} = ¬@ty{Label}}：一个自身@tech{否定}的类型。

前面表格的第二列不必再说「像」：@m{p ∨ ¬p}
是@tech{排中律}，@m{(¬p → p) → p} 是 Clavius 律，@m{((p → q) → p) → p}
是 Peirce 律，@m{¬¬p → p} 是@tech{双重否定消除}（@italic{Double
Negation Elimination}，DNE），@m{⊥ → q}
是爆炸原理。我们写的类型签名，每一项都对应着一条逻辑定律；除了爆炸原理，其余几条都只在经典逻辑中成立。

@subsection{对应关系在哪里失效}

@tech{Curry-Howard 对应}在纯粹的全函数语言（如 Agda 和
Coq）中是精确的：对任意非空的 @m{p}，@m{¬p}
确实是空的。真实的编程语言打破了这一点。

考虑 @racket[(define (loop) (loop))]。它的类型是 @m{→ ⊥}，即
@m{⊤ → ⊥ = ¬⊤}：真的@tech{否定}。在纯粹理论中，@m{¬⊤}
应该是空的，因为真不可反驳。但 @racket[(loop)]
是这个类型下合法的表达式，只不过永不终止。在非全函数语言中，合法的表达式不一定终止，因此并非每个表达式都是证明。

类似地，内置的 @racket[exit] 的类型是
@m{@ty{Byte} → ⊥ = ¬@ty{Byte}}。借助 @racket[exit]，我们可以为任意
@m{p} 构造
@m{¬p}：@racket[(λ (_) (exit 0))]。任何真命题的@tech{否定}都变成了非空。

还有第三种失效。我们的类型 @m{@ty{Label} = ¬@ty{Label}}
是一个自身@tech{否定}的类型。把它读作命题：如果它为真（非空），它的@tech{否定}就为真，所以它为假。如果它为假（空），它的@tech{否定}就平凡地非空（正如
@racket[absurd] 填充了 @m{⊥ → p}），但
@m{¬@ty{Label} = @ty{Label}}，所以它又变成了真。

这就是@defterm{说谎者悖论}：「这句话是假的。」它无法被一致地赋予真假值。在
Agda 和 Coq
这样的一致类型论中，@defterm{正性}条件禁止这类定义：一个类型不能出现在自身定义中的否定位置（@m{→}
的左侧），从而排除了自指式的@tech{否定}。（更强的@italic{严格}@tech{正性}条件进一步禁止嵌套否定位置的出现，如
@m{(T → A) → A}；我们的 @m{@ty{Label} = @ty{Label} → ⊥}
在第一层就已违反。）Racket 没有这个限制。悖论是合法的，我们可以构造
Label
类型的值。同样的结构也出现在硬件中：环形振荡器（奇数个反相器首尾相连，最简单的情形是三个）永远振荡；理想化的单反相器版本
@m{Q = ¬Q} 是同一个不动点方程。

每种情况下，严格的 Curry-Howard
解读都失效了：本应为空的@tech{否定}类型有了值，本应非法的自指类型变得合法。我们把这个对应关系当作结构性的指引：类型的结构映射到逻辑连接词的结构，即便严格的逻辑解读不再精确。

@subsection[#:tag "01:watershed"]{分水岭}

在引入 @racket[cc] 和 @racket[call/cc]
之前，我们拥有的一切（函数、积、联合、@m{⊤}、@m{⊥}）都属于@defterm{直觉主义逻辑}：构造性类型系统所自然栖居的逻辑。那么
@racket[cc] 和 @racket[call/cc] 到底添加了什么？

我们有四种与@tech{否定}交互的方式。其中两种只需要普通函数：

@defterm{矛盾律}：把一个 @m{¬p} 和一个 @m{p} 放在一起，得到 @m{⊥}。

@examples[#:eval ev #:label #f #:no-prompt
(: apply-cont (∀ (p) (→ (¬ p) p ⊥)))
(define (apply-cont k . v*) (apply k v*))]

这就是函数调用。我们给它起了个名字
@racket[apply-cont]，因为在当前的设定中@tech{延续}恰好是函数。但「向@tech{延续}传递一个值」本身是一个独立的概念：@tech{延续}换一种表示，它就不再只是函数调用。

@defterm[#:en "Double Negation Introduction" #:abbr "DNI"]{双重否定引入}是同一个操作，只是参数顺序不同。@racket[apply-cont]
接收@tech{延续}和值，而 DNI 先接收值，返回一个等待@tech{延续}的
@m{¬¬p}：@racket[(curryr apply-cont)]。这是一个纯粹的
lambda，不需要任何控制操作符。

两者都是@bold{构造性有效的}。另外两种则需要捕获当前@tech{延续}：

@defterm{排中律}：产出一个 @m{p ∨ ¬p}。这是 @racket[cc]。

@defterm{双重否定消除}：从一个 @m{¬¬p} 中提取一个 @m{p}。这是
@racket[call/cc]。

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list "" @elem{构造性} @elem{经典})
   (list @elem{@m{¬p} 遇上 @m{p}}
         @elem{@bold{@tech{矛盾律}}：@racket[apply-cont]（函数调用）}
         @elem{@bold{@tech{排中律}}：@racket[cc]（捕获@tech{延续}）})
   (list @elem{@m{¬¬p} 遇上 @m{p}}
         @elem{@bold{@tech{双重否定引入}}：柯里化的
               @racket[apply-cont]}
         @elem{@bold{@tech{双重否定消除}}：@racket[call/cc]@;
               （捕获@tech{延续}）}))]

@italic{消耗}一个@tech{否定}（把 @m{¬p} 和 @m{p} 放在一起，或者把
@m{p} 包进 @m{¬¬p}，等着别人交来
@m{¬p}）是构造性的。@italic{凭空造出}一个非空 @m{p}
的@tech{否定}是经典的：@racket[cc] 交出的 @m{p ∨ ¬p} 可能就是一个
@m{¬p}；@racket[call/cc] 从 @m{¬¬p} 中提取 @m{p}，也得先造出一个
@m{¬p} 交给它。分界线就在消耗与凭空造出之间。

@bold{练习}：@italic{实质条件} @m{¬p ∨ q} 是经典逻辑中 @m{p → q}
的另一种编码。试着实现 @c{material->procedure : (¬p ∨ q) → p → q} 和
@c{procedure->material : (p → q) → ¬p ∨ q}。你会发现其中一个方向需要
@racket[cc]，是哪一个？


@section{代入排中律}

到目前为止，对应关系一直是从程序读向逻辑：先写出操作符，再认出它的类型是哪条定律。它也可以反过来用。

逻辑里，一条定律对任何命题都成立，把一个具体的命题代进去，就得到一条新的定理。在程序里，这一步就是给操作符的类型参数指定一个具体的类型。

代入哪条定律？直觉主义定律只涉及引入 @racket[cc]
之前就有的函数、多值和联合，它们的实例用 @racket[λ]
本来就写得出来。经典定律不同，它们的实例一般要靠 @racket[cc] 或
@racket[call/cc] 才能给出。代入经典定律，就可能得到 @racket[λ]
写不出的操作符，而它会做什么，可以先从命题的形状读出来。其中最直接的一条是@tech{排中律}，它就是
@racket[cc] 的类型 @m{p ∨ ¬p}。

@subsection{代入 @m{¬q}}

@m{@ty{Label}}
是一个极端的例子。它是自身的@tech{否定}，@tech{排中律}二者择一的结构在它身上坍缩成了一个类型；一致的类型论甚至不允许定义它。退一步，不要求类型@tech{否定}自己，只要求它是另一个类型的@tech{否定}。代入
@m{¬q}：

@mm{¬q ∨ ¬¬q}

两个分支还在。@m{¬q} 是@tech{延续}，我们已经很熟悉了。@m{¬¬q}
呢？逻辑上它是双重否定，@racket[call/cc] 的类型可以视为
@m{¬¬q → q}。一个类型为 @m{¬¬q} 的值，意味着什么？

@subsubsection{程序的类型}

假设我们的语言有 @racket[call/cc] 但没有内置的
@racket[exit]。我们可以模拟一个：把整个程序包在 @racket[call/cc]
里，捕获的@tech{延续}就成为退出通道。

@racketblock[
(call/cc (λ (exit) (exit ...程序体...)))]

在程序体内，调用 @racket[(exit 0)]
就跳出整个计算；程序体正常结束时，它的结果交给外层的
@racket[exit]。参数 @racket[exit] 的类型是 @m{@ty{Byte} → ⊥}，即
@m{¬@ty{Byte}}：一个接受退出码且永不返回的函数。传给 @racket[call/cc]
的函数 @racket[(λ (exit) ...)] 接收这个 @m{¬@ty{Byte}}
并运行。它的类型是什么？它接受一个
@m{¬@ty{Byte}}，然后……它返回吗？如果程序体调用了
@racket[(exit 0)]，控制跳走，这个函数永不返回。如果程序体正常结束，结果交给外层的
@racket[exit]，控制同样跳走。无论哪条路，结果都通过 @racket[exit]
传递，这个函数从不返回。它的类型是 @m{¬@ty{Byte} → ⊥}，即
@m{¬¬@ty{Byte}}。

外层那个 @racket[(exit …)]
不能省。少了它，程序体正常结束时，这个函数就把结果正常返回，返回类型是
@m{@ty{Byte}} 而不是 @m{⊥}。

真实的操作系统也是这样运行程序的。启动一个程序时，OS
提供一个退出通道，进程通过它交回状态码，然后 OS
接管。交回的方式有两种：显式地调用 @racket[exit]，或者从 @racket[main]
返回。C 语言规定后者等于拿返回值调用 @racket[exit]，正是上面外层那个
@racket[(exit …)]。这就是 @m{¬¬@ty{Byte} → @ty{Byte}}：OS
提供一个@tech{延续}，程序体通过它传递一个字节，OS
拿回一个值。运行一个程序，就是一次 DNE。

消除的对象，那个 @m{¬¬@ty{Byte}}，正是程序本身。程序是一个
@m{¬¬q}：它期望得到一个退出通道，一个来自未来的@tech{延续}。OS
运行它的时候满足这个期望，消除双重否定，提取出结果。
