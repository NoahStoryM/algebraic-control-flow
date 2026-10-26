#lang scribble/manual
@(require "../../lib/acf.rkt")

@title[#:tag "01:1-labels"]{从标签到 call/cc}

@section{引言}

@c{call/cc}（全称 @italic{call-with-current-continuation}，「以当前延续调用」）是 Scheme 传统中最强大、也最令人畏惧的控制操作符之一。人们常说它是「美化的 goto」，这个说法可以照字面检验。C 的 @c{goto} 只能跳到写死在代码里的标签。如果标签本身是一个值，可以存进变量、作为返回值，就成了@defterm[#:en "first-class labels"]{一等标签}。从一等标签出发，离 @c{call/cc} 还有多远？

@section{一等标签}

设想我们有一等标签：

@code-block|{
(define-type ⊥ (∪))  ; 空类型：没有构造子，没有值
(: goto  (→ Label ⊥))
(: label (→ Label))
}|

@c{(label)} 捕获程序中的当前位置，返回一个 @c{Label} 值。@c{(goto l)} 跳回 @c{l} 被创建的位置。返回类型 @defsym["⊥" "空类型，没有值；读作假"]@m{⊥}（bottom）表示 @c{goto} 永远不会返回到调用者：它把控制转移到了别处。

@notice{代码在 @c{#lang typed/racket/no-check} 下运行：类型标注使用 Typed Racket 语法，但不会被类型检查器验证。这些标注是描述预期契约的设计文档，并非机器检查的断言。}

@subsection{循环}

@repl-block|{
> (let ([x 0])
    (define loop (label))
    (set! x (add1 x))
    (when (< x 7) (goto loop))
    (displayln x))
7
}|

我们在循环体顶部捕获一个标签。每次 @c{(goto loop)}，执行就从 @c{(label)} 调用之后恢复。可变变量 @c{x} 记录我们已经执行了多少次迭代。

@subsection{提前返回}

@code-block|{
(define (mul . r*)
  (define first? #t)
  (define result (*))       ; 乘法单位元 = 1
  (define ret (label))
  (when first?
    (set! first? #f)
    (for ([r (in-list r*)])
      (when (zero? r)
        (set! result r)
        (goto ret))
      (set! result (* result r))))
  result)
}|

这里的 @c{ret} 就是一个「返回标签」。如果在列表 @c{r*} 中遇到零，直接短路跳到末尾。布尔标志 @c{first?} 用来区分初始进入和通过 @c{goto} 跳回来的情况。

@subsection{标签的问题}

注意两个例子都依赖@bold{修改可变状态}（@c{set!}）来在跳转之间传递信息。@c{(goto loop)} 时，标签本身不携带任何数据，所以我们不得不通过副作用来进入正确的状态。第二个例子中的标志 @c{first?} 与乘法无关：它存在的唯一目的就是区分「我们是第一次运行，还是刚刚跳回来？」

@section{从标签到延续：@c{cc} 操作符}

一等标签的根本限制在于：@c{goto} 是一张单程票，不带任何载荷。要避免修改状态，我们需要向跳转目标发送一个值。这就是@defterm[#:en "continuation"]{延续}的核心思想。

@c{(label)} 第一次被求值时，我们希望它返回一个「回调」：一个以后可以调用的函数，带着一个值跳回去。当调用那个回调时，@c{(label)} 应该「再次返回」，这次返回的就是传入的那个值。

于是这个操作符的返回值有两种可能：

@itemlist[
  @item{类型为 @m{p → ⊥} 的延续：接受类型为 @m{p} 的值且永不返回的函数（它跳回捕获点）。}
  @item{类型为 @m{p} 的值，在延续被调用时收到。}]
我们把这个操作符叫做 @c{cc}（@italic{current-continuation} 的缩写）：

@code-block|{
(: cc (∀ (p) (→ (∪ p (→ p ⊥)))))
(define (cc)
  (define v* #f)
  (define l (label))
  (if v*
      (apply values v*)
      (λ vs (set! v* vs) (goto l))))
}|

从代码看，@c{v*} 标志控制分支：首次进入时 @c{v*} 为 @c{#f}，@c{(label)} 先捕获当前位置，随后 @c{(if v* ...)} 走入 else 分支，返回一个函数（也就是延续）。日后调用它时，它把参数存入 @c{v*} 并跳回捕获点；控制回到 @c{(if v* ...)}，此时 @c{v*} 不再是 @c{#f}，走 then 分支，@c{(cc)} 返回之前存入的那个值。

@notice{@c{cc} 的内部实现仍然使用了 @c{label}、@c{goto} 和 @c{set!}，但这些机制现在被封装起来了。@c{cc} 的使用者永远不需要触碰可变状态。该实现对多值做了处理（@c{v*}、@c{apply values}）；本文所有类型标注均省略多值情形以求清晰。}

@subsection{再写 @c{mul}}

@code-block|{
(define (mul . r*)
  (define result (cc))
  (if (real? result)
      result
      (for/fold ([res (*)] #:result (result res))
                ([r (in-list r*)])
        (if (zero? r)
            (result r)
            (* res r)))))
}|

第一次求值 @c{(cc)} 时，@c{result} 绑定到一个延续（一个函数）。因为延续不是 @c{real?}，我们进入 @c{else} 分支并开始折叠。如果遇到零，调用 @c{(result r)}，触发延续：控制跳回求值 @c{(cc)} 的位置，现在 @c{result} 绑定到 @c{r}（一个实数）。进入 @c{then} 分支，立即返回。如果没有遇到零，@c{for/fold} 的 @c{#:result} 子句在折叠结束后调用 @c{(result res)}，同样触发延续，@c{result} 绑定到累积乘积 @c{res}，从 @c{then} 分支返回。两条路径都通过延续 @c{result} 汇合，不需要可变状态，也不需要标志。

@section{消除分支：@c{call/cc}}

@c{cc} 消除了可变状态，但带来了新的要求：@bold{分支}。每次调用 @c{(cc)} 的返回值都有两种可能，程序员必须区分收到的是哪种情况。在提前返回的例子中，我们用 @c{(real? result)} 来分离值和延续。这能工作，但又多了一件需要操心的事。能不能把分支也一并消除？

不再返回联合类型让调用者去分支，而是让调用者传入一个函数 @c{proc}，直接把延续作为参数交给它。分支发生在操作符内部，对用户不可见：

@code-block|{
(: call/cc (∀ (p) (→ (→ (→ p ⊥) p) p)))
(define (call/cc proc)
  (define v* (cc))
  (if (list? v*)
      (apply values v*)
      (proc (λ vs (v* vs)))))
}|

用户传入一个函数 @c{proc}，它接收一个类型为 @m{p → ⊥} 的延续作为参数。在 @c{proc} 内部调用这个延续，会中止 @c{proc} 并向 @c{call/cc} 的调用者传递一个类型为 @m{p} 的值；如果 @c{proc} 正常返回而不调用延续，就直接使用它的返回值。@c{list?} 负责区分这两种情况：首次调用 @c{(cc)} 时，@c{v*} 绑定到延续（一个函数），不是列表，走 else 分支把它封装后交给 @c{proc}。交给 @c{proc} 的包裹 @c{(λ vs (v* vs))} 用 rest 形式的 @c{vs} 将参数收集成列表，再以列表调用 @c{cc} 的延续。@c{cc}「再次返回」时带着这个列表，此时 @c{v*} 绑定到列表，所以 @c{(list? v*)} 为真，@c{(apply values v*)} 解包返回。

很多时候传给 @c{call/cc} 的 @c{proc} 就是个用来命名当前延续的 lambda。定义一个语法糖来省去这层包装：

@code-block|{
(define-syntax-rule (let/cc k body ...)
  (call/cc (λ (k) body ...)))
}|

@exercise{用 @c{let/cc} 定义 @c{call/cc}。}

@subsection{更一般的延续类型}

传给 @c{proc} 的逃逸延续类型为 @m{p → ⊥}。但考虑这个函数：

@code-block|{
(: absurd (∀ (q) (→ ⊥ q)))
(define absurd (case-λ))
}|

@c{absurd} 的类型为 @m{⊥ → q}，对任意 @m{q} 成立：从空类型可以推出任何东西。因为 @c{case-λ} 没有任何子句，它是一个永远不可能被调用的函数（没有可匹配的情况），这一定义完全合法。

现在，给定一个类型为 @m{p → ⊥} 的延续 @c{k}，复合函数 @c{(compose absurd k)} 的类型为 @m{p → q}，对任意 @m{q} 成立。操作上，这个复合的行为与 @c{k} 本身@bold{完全一样}：用一个类型为 @m{p} 的值调用它会触发 @c{k}，控制跳走，永远到不了 @c{absurd}。但从类型系统的角度看，返回类型现在是任意的 @m{q} 而不是 @m{⊥}。

这意味着我们可以把逃逸延续视为具有更一般的类型 @m{p → q} 而非 @m{p → ⊥}。在这个视角下，@c{proc} 的类型为 @m{(p → q) → p}，@c{call/cc} 的类型变成：

@mm{((p → q) → p) → p}

这比原来的类型更一般：令 @m{q = ⊥} 就恢复原来的版本。在有类型的语言里，这个更一般的类型很常见，例如 Haskell 的 @c{callCC :: ((a -> m b) -> m a) -> m a}，延续的返回类型可以是任意的 @c{m b}。但对于本文来说，@m{p → ⊥} 的版本更具揭示性：它直接展示了延续@italic{是}什么（一个接受 @m{p} 且永不返回的函数），不需要通过 @c{absurd} 的额外泛化步骤。

@subsection{那条看不见的延续}

还有另一种方式来解读 @c{call/cc} 的类型。回忆一下，@c{k} 和 @c{(compose absurd k)} 在操作上完全一样，因为 @c{k} 永不返回，所以 @c{absurd} 永远不会被执行到。@c{call/cc} 本身也有一个类似的等价关系：

@code-block[#:skip "这是程序转换的并列写法，proc 尚未给出"]|{
(call/cc proc)
(call/cc (λ (k) (k (proc k))))
}|

两者是一样的：第二个版本中，@c{proc} 的结果显式地通过 @c{k} 路由；第一个版本中，同样的事情也在发生。@c{cc} 在 @c{(define v* (cc))} 处捕获延续，这个延续接收一个值后做什么？执行 @c{if}，返回 @c{call/cc} 的结果，然后继续 @c{call/cc} 调用之后的代码。@c{cc} 捕获的延续就是 @c{call/cc} 的延续。而 @c{proc} 在 else 分支的尾位置，所以它的延续也是同一个 @c{k}。包裹不改变任何东西：无论 @c{proc} 的返回值走哪条路，都通过同一个 @c{k} 传递，显式调用 @c{(k (proc k))} 和正常返回 @c{(proc k)} 汇入同一个出口。因此 @c{proc} 可以读作 @m{(p → ⊥) → ⊥}：它接受一个延续，结果总是经由这个延续交出去。严格说，有这个类型的是包了一层的 @c{(λ (k) (k (proc k)))}；@c{proc} 自己正常返回一个 @m{p}，只是这个返回值反正也流向 @c{k}。于是 @c{call/cc} 也可以读作：

@mm{((p → ⊥) → ⊥) → p}

输入一个借延续来交付结果的计算，从中把结果取出来。

@section{从 @c{call/cc} 定义标签}

令 @m{p = \text{Label}}，@c{call/cc} 交给 @c{proc} 的延续类型就是 @m{\text{Label} → ⊥}，恰好是一个标签。标签因此可以直接由 @c{call/cc} 定义：

@code-block[#:reset #t]|{
(define-type Label (→ Label ⊥))
(define (goto l) (l l))
(define (label) (call/cc goto))
}|

@defsym["\\text{Label}" "标签的类型：Label = Label → ⊥"]@m{\text{Label} = \text{Label} → ⊥} 是一个递归类型：标签是一个接受标签且永不返回的函数。@c{(label)} 捕获当前延续，把它当作标签立即跳转过去：一次到自身的原地跳转，所以延续收到的就是它自身。后续的 @c{(goto l)} 调用 @c{l} 并传入 @c{l}，跳回 @c{(label)} 被求值的位置，再次返回 @c{l}。

三者也可以按另一个顺序互相定义，先从标签得到 @c{call/cc}，再由它得到 @c{cc}：

@code-block[#:reset #t]|{
(define (call/cc proc)
  (define v* #f)
  (define l (label))
  (if v*
      (apply values v*)
      (proc (λ vs (set! v* vs) (goto l)))))

(define (cc) (call/cc values))

(define (label) (cc))
(define (goto l) (l l))
}|

无论按哪个顺序，三种表述都能互相定义，在@bold{表达能力上等价}。

@section[#:tag "01:compare"]{比较}

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list "" @elem{一等标签 (@c{goto} + @c{label})} @elem{值与延续的联合 (@c{cc})} @elem{高阶回调 (@c{call/cc})})
   (list @elem{@bold{涉及的类型}} @elem{只有 @c{Label}} @elem{联合类型 @m{p ∪ (p → ⊥)}} @elem{高阶：@m{((p → ⊥) → p) → p} 或 @m{((p → ⊥) → ⊥) → p}})
   (list @elem{@bold{需要可变状态？}} @elem{是：必须用 @c{set!} 在跳转间传递信息} @elem{否} @elem{否})
   (list @elem{@bold{需要手动分支？}} @elem{否} @elem{是：必须区分 @m{p} 和 @m{p → ⊥}} @elem{否}))]

三种风格能做到的事没有区别，力量的来源也是同一个：跳转目标成为了值。在 C 中，label 是代码中的固定位置，不能存入变量、不能传给函数、不能作为返回值。label 成为值的那一刻，@c{goto} 就获得了 @c{call/cc} 的全部力量。这一步之后的一切都是易用性方面的取舍：每种风格为更方便地管理同一种能力付出不同的代价（可变状态、分支、高阶类型）。
