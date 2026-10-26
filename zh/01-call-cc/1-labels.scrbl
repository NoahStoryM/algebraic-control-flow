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

@c{(label)} 捕获程序中的当前位置，返回一个 @c{Label} 值。@c{(goto l)} 跳回 @c{l} 被创建的地方，让当初那次 @c{(label)} 调用再返回一次，交出的仍是这个 @c{l}。@c{goto} 的返回类型是 @defsym["⊥" "空类型，没有值；读作假"]@m{⊥}（bottom），一个没有值的类型：@c{goto} 永远不会回到调用它的地方，控制转移到了别处。

「一等」说的是两件事。标签和数、字符串一样是值，可以存进变量，传给函数，作为返回值。而且创建它的函数返回以后，它仍然有效，@c{goto} 还能跳回那个函数里面去。C 的标签两件都做不到。

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

我们在循环体顶部捕获一个标签。每次 @c{(goto loop)}，执行回到 @c{(label)}，它再次返回同一个标签，@c{loop} 重新绑定到它，循环体从头再走一遍。可变变量 @c{x} 记下已经走了几遍。

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

这里的 @c{ret} 是一个「返回标签」。遇到零时，@c{(goto ret)} 并不直接跳到函数末尾。@c{ret} 是在 @c{when} 之前创建的，控制回到 @c{(define ret (label))}，@c{(label)} 再次返回。这时 @c{first?} 已经是 @c{#f}，整个 @c{when} 被跳过，函数交出 @c{result}，也就是刚存进去的零。布尔标志 @c{first?} 就是用来分辨这是第一次进入，还是经 @c{goto} 跳回来的。

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
  (define saved #f)
  (define l (label))
  (if saved
      (apply values saved)
      (λ args (set! saved args) (goto l))))
}|

@c{saved} 一身兼两职。它是一个标志，@c{#f} 表示还没有人调用过延续；它也是载荷，延续被调用时，收到的参数存在这里。两种职责不会混淆：@c{(λ args …)} 总是把收到的参数收成一张列表 @c{args}，哪怕参数本身是 @c{#f}，哪怕一个参数也没有，存进去的列表都不是 @c{#f}。

按时间顺序看。第一次调用 @c{(cc)} 时，@c{saved} 是 @c{#f}，@c{(label)} 捕获当前位置，@c{if} 走 else 分支，交出一个函数，这就是延续。@c{(cc)} 就此返回。

后来某处调用这个延续，它把参数存进 @c{saved}，再 @c{(goto l)} 跳回 @c{cc} 里面。此时 @c{cc} 早已返回过，标签仍然能跳回去，用的正是一等标签的第二项能力。@c{(label)} 再次返回，控制又来到 @c{if}。这一回 @c{saved} 不再是 @c{#f}，走 then 分支，@c{(cc)} 第二次返回，交出存进去的值。

@notice{@c{cc} 的内部仍然使用了 @c{label}、@c{goto} 和 @c{set!}，但它们被封装起来了，@c{cc} 的使用者不必再碰可变状态。实现顺带处理了多值：@c{args} 收下全部参数，@c{apply values} 全部交出。本文的类型标注都省略多值的情形。}

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

@c{for/fold} 一边遍历 @c{r*}，一边累积 @c{res}；@c{#:result} 指定遍历结束后交出什么。

第一次求值 @c{(cc)} 时，@c{result} 绑定到一个延续（一个函数）。因为延续不是 @c{real?}，我们进入 @c{else} 分支并开始折叠。如果遇到零，调用 @c{(result r)}，触发延续：控制跳回求值 @c{(cc)} 的位置，现在 @c{result} 绑定到 @c{r}（一个实数）。进入 @c{then} 分支，立即返回。如果没有遇到零，@c{for/fold} 的 @c{#:result} 子句在折叠结束后调用 @c{(result res)}，同样触发延续，@c{result} 绑定到累积乘积 @c{res}，从 @c{then} 分支返回。两条路径都通过延续 @c{result} 汇合，不需要可变状态，也不需要标志。

@section{消除分支：@c{call/cc}}

@c{cc} 消除了可变状态，但带来了新的要求：@bold{分支}。每次调用 @c{(cc)} 的返回值都有两种可能，程序员必须区分收到的是哪种情况。在提前返回的例子中，我们用 @c{(real? result)} 来分离值和延续。这行得通，只是程序员又多了一件要操心的事。能不能把分支也一并消除？

不再返回联合类型让调用者去分支，而是让调用者传入一个函数 @c{proc}，直接把延续作为参数交给它。分支挪进操作符内部，对用户不可见。

挪进去的分支仍然要做。操作符自己调用 @c{(cc)}，同样会拿到两种东西：第一次是延续，以后是传回来的结果。@c{mul} 能用 @c{real?} 分辨它们，是因为结果恰好是实数；操作符不知道结果会是什么，结果也可能是一个函数，和延续分不开。办法是把传回来的结果一律收进一张列表。延续是函数，永远不是列表，两者就分得开了：

@code-block|{
(: call/cc (∀ (p) (→ (→ (→ p ⊥) p) p)))
(define (call/cc proc)
  (define x (cc))
  (if (list? x)
      (apply values x)
      (proc (λ args (x args)))))
}|

@c{x} 是 @c{(cc)} 交出来的东西，和 @c{cc} 里的 @c{saved} 不是一回事。第一次，@c{x} 是 @c{cc} 的延续，不是列表，走 else 分支。@c{call/cc} 不把它原样交给 @c{proc}，而是包上一层：@c{(λ args (x args))} 把收到的参数收成列表 @c{args}，再交给 @c{x}。

@c{proc} 拿到这个包装好的延续。它若在某处调用延续，@c{cc} 的延续收到那张列表，@c{(cc)} 再次返回，@c{x} 绑定到列表，@c{(list? x)} 为真，@c{(apply values x)} 把列表拆开交回。@c{call/cc} 的调用者收到了传给延续的值，@c{proc} 里剩下的工作被跳过。@c{proc} 若不调用延续而正常返回，它的返回值就是 @c{call/cc} 的结果。

有了 @c{call/cc}，@c{mul} 可以再写一次：

@code-block|{
(define (mul . r*)
  (call/cc
   (λ (return)
     (for/fold ([res (*)])
               ([r (in-list r*)])
       (if (zero? r)
           (return r)
           (* res r))))))
}|

@repl-block|{
> (mul 2 3 4)
24
> (mul 2 0 3)
0
}|

标志、可变状态、@c{real?} 的分支都不见了。没有遇到零，@c{for/fold} 正常结束，乘积作为 @c{proc} 的返回值交出；遇到零，@c{(return r)} 把零直接交给 @c{mul} 的调用者。延续有了一个名字，叫 @c{return}。许多语言里内建的那个 @c{return}，在这里是一个普通的值，由 @c{call/cc} 交到我们手上。

@c{proc} 常常只是这样一个给当前延续起名字的 λ。定义一个宏，省去这层包装：

@code-block|{
(define-syntax-rule (let/cc k body ...)
  (call/cc (λ (k) body ...)))
}|

@c{define-syntax-rule} 定义一个宏：@c{(let/cc k body ...)} 在展开时改写成 @c{(call/cc (λ (k) body ...))}。@c{mul} 的主体于是可以写成 @c{(let/cc return …)}。

@exercise{用 @c{let/cc} 定义 @c{call/cc}。}

@subsection{更一般的延续类型}

交给 @c{proc} 的延续，类型是 @m{p → ⊥}。这个类型还可以放宽。先看一个奇怪的函数：

@code-block|{
(: absurd (∀ (q) (→ ⊥ q)))
(define absurd (case-λ))
}|

@c{case-λ} 按参数的个数分情形定义函数，每个子句对应一种调用方式。一个子句也没有的 @c{(case-λ)}，没有任何调用方式能与它匹配，这样的函数永远不会被调用。这正合 @m{⊥} 的情形：@m{⊥} 没有值，谁也交不出一个来给它。既然永远不会被调用，说它交出什么类型都不会错，所以 @c{absurd} 的类型是 @m{⊥ → q}，@m{q} 任意。从空类型可以推出任何东西。

把 @c{absurd} 接在延续 @c{k} 后面，@c{(compose absurd k)} 的类型就是 @m{p → q}。它的行为和 @c{k} 完全一样：一调用，@c{k} 就跳走，永远到不了 @c{absurd}。所以交给 @c{proc} 的延续也可以看作 @m{p → q}，@c{call/cc} 的类型随之变成：

@mm{((p → q) → p) → p}

令 @m{q = ⊥}，就回到原来的类型。原来的版本更直接地说出了延续是什么：一个接收 @m{p}、永不返回的函数。

@subsection{那条看不见的延续}

@c{k} 和 @c{(compose absurd k)} 行为一样，因为 @c{k} 不会返回，后面接了什么都不会执行。@c{call/cc} 里也有一处类似的等价，下面两个表达式行为相同：

@code-block[#:skip "这是程序转换的并列写法，proc 尚未给出"]|{
(call/cc proc)
(call/cc (λ (k) (k (proc k))))
}|

这里要分清三样东西：@c{proc} 自己；第二行里包了一层的函数 @c{(λ (k) (k (proc k)))}；还有 @c{proc} 正常返回时，返回值要去的地方。

先看运行路线。@c{call/cc} 的第一行 @c{(define x (cc))} 捕获了一个延续。这个延续收到值以后做什么？走完 @c{if}，从 @c{call/cc} 返回，接着做 @c{call/cc} 调用之后的事。所以它就是 @c{call/cc} 自己的延续，交给 @c{proc} 的 @c{k} 通向的也是这里。再看 @c{(proc (λ args (x args)))}：它处在 @c{call/cc} 的尾位置，@c{proc} 正常返回时，返回值同样直接交给 @c{call/cc} 的延续。

于是两条路汇入同一个出口。第二行里，@c{proc} 的结果经 @c{k} 显式地交出去；第一行里，它经正常返回走到同一个地方。正常返回时隐含经过的，就是这条看不见的延续。

再看类型。@c{proc} 自己的类型是 @m{(p → ⊥) → p}，它可以正常返回一个 @m{p}，@c{call/cc} 的类型就照这个读法写成。包了一层的 @c{(λ (k) (k (proc k)))} 则从不正常返回，结果总是经 @c{k} 交出，它的类型是 @m{(p → ⊥) → ⊥}。两者交给 @c{call/cc}，行为相同。也可以干脆要求 @c{proc} 本身就从不正常返回，它的类型便是 @m{(p → ⊥) → ⊥}。照这个读法，@c{call/cc} 的类型是：

@mm{((p → ⊥) → ⊥) → p}

输入一个借延续来交付结果的计算，从中把结果取出来。

@section{从 @c{call/cc} 定义标签}

令 @m{p = \text{Label}}，@c{call/cc} 交给 @c{proc} 的延续类型就是 @m{\text{Label} → ⊥}，恰好是一个标签。标签因此可以直接由 @c{call/cc} 定义：

@code-block[#:reset #t]|{
(define-type Label (→ Label ⊥))
(define (goto l) (l l))
(define (label) (call/cc goto))
}|

@defsym["\\text{Label}" "标签的类型：Label = Label → ⊥"]@m{\text{Label} = \text{Label} → ⊥} 是一个递归类型：标签是一个接受标签且永不返回的函数。@c{(label)} 做了什么，一步步展开来看。把 @c{call/cc} 交给 @c{goto} 的延续记作 @c{k}，它通向 @c{(label)} 被调用的地方：

@eq-block|{
  (label)
= (call/cc goto)
= (goto k)
= (k k)
}|

@c{goto} 把 @c{k} 交给 @c{k} 自己，于是 @c{(label)} 返回的就是 @c{k}：这个标签就是它被创建处的延续。以后 @c{(goto l)} 再调用 @c{(l l)}，跳回同一处，@c{(label)} 又一次返回 @c{l}。这正是开头为一等标签描述的行为。

这里的 @c{call/cc} 要当作现成的原语，比如 Racket 自带的那一个。若接上前面那个由标签造出来的 @c{call/cc}，就绕成了一个圈：@c{label} 调用 @c{call/cc}，@c{call/cc} 调用 @c{cc}，@c{cc} 又调用 @c{label}，永远转下去。互相定义的意思是，每一个都能以另一个为原语写出来，而不是把这些定义放进同一个程序。

顺序也可以反过来。以标签为原语，先得到 @c{call/cc}，再由它得到 @c{cc}：

@code-block[#:reset #t]|{
(define (call/cc proc)
  (define saved #f)
  (define l (label))
  (if saved
      (apply values saved)
      (proc (λ args (set! saved args) (goto l)))))

(define (cc) (call/cc values))
}|

这个 @c{call/cc} 手边没有 @c{cc}，就直接用标签和 @c{set!}，写法和 @c{cc} 一样，只是把延续交给 @c{proc}，而不是交给调用者。以 @c{cc} 为原语，标签就是 @c{(cc)} 第一次交出的那个延续：

@code-block|{
(define (label) (cc))
(define (goto l) (l l))
}|

以后 @c{(goto l)} 把 @c{l} 交给它自己，@c{(cc)} 再次返回，交出的还是 @c{l}。无论从哪一个出发，另外两个都写得出来：三种表述在@bold{表达能力上等价}。

@section[#:tag "01:compare"]{比较}

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list "" @elem{一等标签 (@c{goto} + @c{label})} @elem{值与延续的联合 (@c{cc})} @elem{高阶回调 (@c{call/cc})})
   (list @elem{@bold{涉及的类型}} @elem{只有 @c{Label}} @elem{联合类型 @m{p ∪ (p → ⊥)}} @elem{高阶：@m{((p → ⊥) → p) → p} 或 @m{((p → ⊥) → ⊥) → p}})
   (list @elem{@bold{需要可变状态？}} @elem{是：必须用 @c{set!} 在跳转间传递信息} @elem{否} @elem{否})
   (list @elem{@bold{需要手动分支？}} @elem{否} @elem{是：必须区分 @m{p} 和 @m{p → ⊥}} @elem{否}))]

三种风格能做到的事没有区别，力量的来源也是同一个：跳转目标成为了值。在 C 中，label 是代码中的固定位置，不能存入变量、不能传给函数、不能作为返回值。label 成为值的那一刻，@c{goto} 就获得了 @c{call/cc} 的全部力量。这一步之后的一切都是易用性方面的取舍：每种风格为更方便地管理同一种能力付出不同的代价（可变状态、分支、高阶类型）。
