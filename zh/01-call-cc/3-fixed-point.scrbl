#lang scribble/manual
@(require "../../lib/acf.rkt")

@title[#:tag "01:3-fixed-point"]{否定的不动点}

@section{代入 @m{\text{Label}}}

排中律 @m{p ∨ ¬p} 的两个分支，一个是 @m{p}，一个是 @m{¬p}：一真一假。但如果代入的类型让真假变成同一个东西呢？更进一步：既然两个分支是同一个类型，我们何必再区分它们？

既真又假，这正是说谎者悖论，我们熟悉的 @m{\text{Label}}。放宽排中律对不相交的要求，把 @m{\text{Label}} 代入 @m{p}：

@mm{\text{Label} ∨ ¬\text{Label} = \text{Label} ∨ \text{Label} = \text{Label}}

一切坍缩为 @c{Label}。@m{\text{Label}} 是@defterm{否定的不动点}：它的反驳就是它自己。特别地，@bold{@c{goto} 本身就是一个 @c{Label}}：

@mm{\text{Label} → ⊥ = ¬\text{Label} = \text{Label}}

之前所有的例子中，我们都是 @c{goto} 配 @c{label} 使用：

@code-block[#:skip "goto (label) 故意无限跳转"]|{
(goto (label))
}|

但既然每个 @m{\text{Label}} 同时也是一个合法的 @m{¬\text{Label}}，没有什么能阻止我们把@italic{任意}标签传给任何其他标签：

@code-block[#:skip "同一无限跳转的展开"]|{
((label) (label))
}|

在类型层面上，「跳转目标」和「跳转指令」没有区别：它们是同一种东西。这种自指式的坍缩不是 bug，它是延续令人费解的那些行为的源头。

@subsection{阴阳谜题}

把标签直接交给标签，就得到 David Madore 的阴阳谜题：

@repl-block[#:skip "阴阳谜题无限输出，未加跟踪的对应谜题由 code.rkt 限时检查"]|{
> (let ([yin (label)])
    (displayln #\@)
    (let ([yang (label)])
      (display #\*)
      (yin yang)))
@
*@
**@
***@
****@
...
}|

程序里没有循环，没有计数器，也没有 @c{set!}：只有两次 @c{(label)}、两次打印和一次调用。输出却是一道无限增长的阶梯，每一轮都比上一轮多打印一个 @c{*}。多出来的那个 @c{*}，记在了哪里？

@subsubsection{追踪谜题}

给每个延续一个唯一的名字（@c{k0}、@c{k1}、@c{k2}……），让每次 @c{apply-cont} 都记录哪个延续被应用于哪个：

@code-block|{
(define n -1)
(define (cc)
  (set! n (+ n 1))
  (let/cc k
    (define l (cons k (string->symbol (string-append "k" (number->string n)))))
    (apply-cont l l)))
(define (apply-cont kl l)
  (display (list (cdr kl) (cdr l)))
  (display #\tab)
  ((car kl) l))
}|

这里的 @c{let/cc} 借的是 Racket 自带的那一个。前文的 @c{let/cc}、@c{call/cc}、@c{cc} 是互相定义的，插桩时需要一个现成的起点。

这里的延续是函数和名字的 @c{cons} 对，不能再直接调用。「向延续传递一个值」也就不再只是函数调用：@c{apply-cont} 先拆开这个对，记下名字，再调用里面的函数。@c{cc} 构造延续，@c{apply-cont} 消费延续。插桩版的 @c{cc} 在交回新延续时，先把它交给它自己，所以追踪里每个延续第一次出现都是 @c{(kn kn)} 这样的一行。谜题改用这两个函数来写：

@repl-block[#:skip "阴阳谜题带跟踪的无限输出，未加跟踪的对应谜题由 code.rkt 限时检查"]|{
> (let ([kn (cc)])
    (displayln #\@)
    (let ([kn+1 (cc)])
      (displayln #\*)
      (apply-cont kn kn+1)))
(k0 k0)	@
(k1 k1)	*
(k0 k1)	@
(k2 k2)	*
(k1 k2)	*
(k0 k2)	@
(k3 k3)	*
(k2 k3)	*
(k1 k3)	*
(k0 k3)	@
...
}|

@subsubsection{读矩阵}

把追踪排列成矩阵（行按参数标签索引，列按目标标签索引，越往左的列越新）：

@out-block|{
      ...  k3   k2   k1   k0
k0                        @
k1                   *    @
k2              *    *    @
k3         *    *    *    @
...
}|

矩阵的每一行对应追踪输出中的一段，到 @c{k0} 被调用为止。每行从左往右读，就是执行的先后：追踪里的 @c{(k3 k3)*}、@c{(k2 k3)*}、@c{(k1 k3)*}、@c|{(k0 k3)@}| 正是第 @c{k3} 行的 @c{*}、@c{*}、@c{*}、@c|{@}|。每一行正是原版谜题打印出的一行（插桩版为了配合追踪，每个字符各占一行）。每行 @m{n} 打印 @m{n} 个 @c{*} 和一个 @c|{@}|。这个模式来自：

@itemlist[#:style 'ordered
  @item{@bold{@c{k0} 打印 @c|{@}|} 并捕获一个新的延续 @c{kn+1}。}
  @item{@bold{@c{kn+1} 打印 @c{*}} 并跳向 @c{kn}。}
  @item{@bold{每个 @c{kn}} 被调用时，收到最近捕获的延续 @c{k} 作为参数。}]
之所以能级联，是因为每个延续都「记得」下一步要跳向哪个 @c{kn}，形成一条链，每经过一次 @c{k0} 就多一个链节。

@subsubsection{用函数重写}

这三条规律只涉及延续之间谁调用谁、传的是什么。照着它们，把每个延续直接写成一个函数：跳向一个延续，就是调用它；捕获一个新延续，就是定义一个新函数。

@code-block[#:skip "阴阳谜题函数展开无限输出，未加跟踪的对应谜题由 code.rkt 限时检查"]|{
(define (k0 kn)
  (displayln #\@)
  (define (kn+1 k)
    (display #\*)
    (kn k))
  (kn+1 kn+1))
(k0 k0)
}|

@c{k0} 打印 @c|{@}|，定义一个新函数 @c{kn+1} 打印 @c{*} 并委托给 @c{kn}，然后用自身调用 @c{kn+1}：

@itemlist[
  @item{第一次调用时，@c{kn = k0}。打印 @c|{@}| 后，创建一个新闭包 @c{kn+1}（我们叫它 @c{k1}），它打印 @c{*} 并委托给 @c{k0}。然后 @c{(kn+1 kn+1)} 用自身调用 @c{k1}：@c{k1} 打印 @c{*} 并调用 @c{(k0 k1)}。}
  @item{现在回到 @c{k0}，此时 @c{kn = k1}：打印 @c|{@}|，创建另一个新闭包 @c{k2}，它打印 @c{*} 并委托给 @c{k1}，然后调用 @c{(k2 k2)}。@c{k2} 打印 @c{*} 并调用 @c{(k1 k2)}；@c{k1} 打印 @c{*} 并调用 @c{(k0 k2)}。}
  @item{以此类推：每次经过 @c{k0} 都给委托链多加一环。}]
运行它，输出和前面一样。

这段代码里没有 @c{label}、@c{cc}，也没有 @c{set!}。原来由 @c{cc} 捕获的延续，现在都成了显式传递的参数：@c{k0} 收到 @c{kn}，@c{kn+1} 收到 @c{k}，每一次跳转都是把延续交给下一个函数的尾调用。这种把延续作为参数传递的写法，叫做@defterm[#:en "Continuation-Passing Style" #:abbr "CPS"]{延续传递风格}；把程序改写成这种写法，就是 @defterm{CPS 变换}。

反过来看，原来的谜题就是这组@bold{互递归调用}，只是其中的延续由 @c{(label)} 在运行时捕获，而不是作为参数传进来。回忆我们说过的 @m{\text{Label} = ¬\text{Label}}，它是说谎者悖论，一个既不能判真也不能判假的命题。阴阳谜题就是那个悖论作为程序运行起来的样子：永不终止地振荡，永远无法落定为真或为假。

@section{结论}

@xref["01:compare"]{比较一节}把三种风格的力量归于同一步：跳转目标成为值。这个值的类型是 @m{¬p}。只用 λ 和函数调用，写不出非空 @m{p} 的否定，@c{cc} 和 @c{call/cc} 交出的延续都是在运行时捕获的。@xref["01:watershed"]{分水岭一节}的表格沿着同一条线分成两列：@c{apply-cont} 和 DNI 只消耗交到手里的否定，只需要普通函数；@c{cc} 和 @c{call/cc} 要凭空造出一个非空 @m{p} 的否定，必须捕获。

程序在操作系统面前也处在这条线上。它是一个 @m{¬¬\text{Byte}}，等待的那条 @m{¬\text{Byte}} 不由它自己写出，而是在启动时由操作系统交给它。

@subsection{未解的线索}

但我们小心避开了一个问题。编程语言建立在@bold{构造性}的基础之上：Curry-Howard 对应把程序与直觉主义证明配对，而在直觉主义逻辑中，排中律不是定理。然而我们一直在愉快地使用排中律、Clavius 律和 DNE，仿佛它们是天经地义的。

这怎么可能？一个构造性语言如何支持经典推理？

阴阳谜题的 CPS 分解提供了一条线索。当我们只用纯 lambda 和函数调用（没有 @c{call/cc}、没有 @c{goto}、没有可变状态）重写谜题时，表达能力没有任何损失。经典的控制流仍然存在，只是被@bold{换了一种方式编码}：作为显式的延续传递。在证明论中，这种编码叫做@defterm[#:en "negative translation"]{否定翻译}；它在计算上的对应物，叫做@bold{延续单子}。

还有另一根线头。程序类型 @m{¬¬\text{Byte}} 中的 @m{⊥} 不是世界的终结：进程终止后，OS 继续运行。@m{⊥} 只是@italic{这个进程}的终结，不是所有计算的终结。它是一个@italic{相对的} bottom，不是绝对的。

如果我们能在程序@italic{内部}拥有相对的 @m{⊥} 呢？如果函数调用，而不仅仅是 OS，也能充当定界符呢？

但那些是@hyperlink["https://zhuanlan.zhihu.com/p/2024852076593694078"]{后续文章}的故事了。
