#lang acf

@title[#:tag "01:1-labels"]{从标签到 call/cc}

C 的@tech{标签}钉死在代码里。要是能把它拔下来，拿在手里，传来传去呢？

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define-type ⊥ (∪))
(define primitive-call/cc call/cc)
(define (goto l) (l l))
(define (label) (primitive-call/cc goto))]

@section{一等标签}

设想我们有一等的@tech{标签}：

@examples[#:eval ev #:label #f #:no-prompt
(define-type ⊥ (∪))  (code:comment "空类型：没有构造子，没有值")
(: goto  (→ Label ⊥))
(: label (→ Label))]

@racket[(label)] 捕获程序中的当前位置，返回一个 @racket[Label] 值
。@racket[(goto l)] 跳回 @racket[l] 被创建的地方，让当初那次
@racket[(label)] 调用再返回一次，交出的仍是这个
@racket[l]。@racket[goto] 的返回类型是
@defsym["⊥" "空类型，没有值；读作假"]@m{⊥}（bottom），一个没有值的类型
：@racket[goto] 永远不会回到调用它的地方，控制转移到了别处。

「一等」说的是两件事。@tech{标签}和数、字符串一样是值，可以存进变量，
传给函数，作为返回值。而且创建它的函数返回以后，它仍然有效
，@racket[goto] 还能跳回那个函数里面去。C 的@tech{标签}两件都做不到。

@subsection{循环}

@examples[#:eval ev #:label #f
(let ([x 0])
  (define loop (label))
  (set! x (add1 x))
  (when (< x 7) (goto loop))
  (displayln x))]

我们在循环体顶部捕获一个@tech{标签}。每次 @racket[(goto loop)]，执行回
到 @racket[(label)]，它再次返回同一个@tech{标签}，@racket[loop] 重新绑
定到它，循环体从头再走一遍。可变变量 @racket[x] 记下已经走了几遍。

@subsection{提前返回}

@examples[#:eval ev #:label #f #:no-prompt
(define (mul . r*)
  (define first? #t)
  (define result (*))       (code:comment "乘法单位元 = 1")
  (define ret (label))
  (when first?
    (set! first? #f)
    (for ([r (in-list r*)])
      (when (zero? r)
        (set! result r)
        (goto ret))
      (set! result (* result r))))
  result)]

这里的 @racket[ret] 是一个「返回@tech{标签}」。遇到零时
，@racket[(goto ret)] 并不直接跳到函数末尾。@racket[ret] 是在
@racket[when] 之前创建的，控制回到
@racket[(define ret (label))]，@racket[(label)] 再次返回。这时
@racket[first?] 已经是 @racket[#f]，整个 @racket[when] 被跳过，函数交
出 @racket[result]，也就是刚存进去的零。布尔标志 @racket[first?] 就是
用来分辨这是第一次进入，还是经 @racket[goto] 跳回来的。

@subsection{标签的问题}

注意两个例子都依赖@bold{修改可变状态}（@racket[set!]）来在跳转之间传递
信息。@racket[(goto loop)] 时，@tech{标签}本身不携带任何数据，所以我们
不得不通过副作用来进入正确的状态。第二个例子中的标志 @racket[first?]
与乘法无关：它存在的唯一目的就是区分「我们是第一次运行，还是刚刚跳回来
？」

@section{从标签到延续：@racket[cc] 操作符}

一等@tech{标签}的根本限制在于：@racket[goto] 是一张单程票，不带任何载
荷。要避免修改状态，我们需要向跳转目标发送一个值。这就
是@defterm[#:en "continuation"]{延续}的核心思想。

@racket[(label)] 第一次被求值时，我们希望它返回一个「回调」：一个以后
可以调用的函数，带着一个值跳回去。当调用那个回调时，@racket[(label)]
应该「再次返回」，这次返回的就是传入的那个值。

于是这个操作符的返回值有两种可能：

@itemlist[
  @item{类型为 @m{p → ⊥} 的@tech{延续}：接受类型为 @m{p} 的值且永不返
  回的函数（它跳回捕获点）。}
  @item{类型为 @m{p} 的值，在@tech{延续}被调用时收到。}]
我们把这个操作符叫做 @racket[cc]（@italic{current-continuation} 的缩写
）：

@examples[#:eval ev #:label #f #:no-prompt
(: cc (∀ (p) (→ (∪ p (→ p ⊥)))))
(define (cc)
  (define saved #f)
  (define l (label))
  (if saved
      (apply values saved)
      (λ args (set! saved args) (goto l))))]

@margin-note{@racket[cc] 的内部仍然使用了
@racket[label]、@racket[goto] 和 @racket[set!]，但它们被封装起来了
，@racket[cc] 的使用者不必再碰可变状态。实现顺带处理了多值
：@racket[args] 收下全部参数，@c{apply values} 全部交出。本文的类型标
注都省略多值的情形。}

@racket[saved] 一身兼两职。它是一个标志，@racket[#f] 表示还没有人调用
过@tech{延续}；它也是载荷，@tech{延续}被调用时，收到的参数存在这里。两
种职责不会混淆：@racket[(λ args …)] 总是把收到的参数收成一张列表
@racket[args]，哪怕参数本身是 @racket[#f]，哪怕一个参数也没有，存进去
的列表都不是 @racket[#f]。

按时间顺序看。第一次调用 @racket[(cc)] 时，@racket[saved] 是
@racket[#f]，@racket[(label)] 捕获当前位置，@racket[if] 走 else 分支，
交出一个函数，这就是@tech{延续}。@racket[(cc)] 就此返回。

后来某处调用这个@tech{延续}，它把参数存进 @racket[saved]，再
@racket[(goto l)] 跳回 @racket[cc] 里面。此时 @racket[cc] 早已返回过
，@tech{标签}仍然能跳回去，用的正是一等@tech{标签}的第二项能力
。@racket[(label)] 再次返回，控制又来到 @racket[if]。这一回
@racket[saved] 不再是 @racket[#f]，走 then 分支，@racket[(cc)] 第二次
返回，交出存进去的值。

@subsection{再写 @racket[mul]}

@examples[#:eval ev #:label #f #:no-prompt
(define (mul . r*)
  (define result (cc))
  (if (real? result)
      result
      (for/fold ([res (*)] #:result (result res))
                ([r (in-list r*)])
        (if (zero? r)
            (result r)
            (* res r)))))]

@racket[for/fold] 一边遍历 @racket[r*]，一边累积
@racket[res]；@racket[#:result] 指定遍历结束后交出什么。

第一次求值 @racket[(cc)] 时，@racket[result] 绑定到一个@tech{延续}（一
个函数）。因为@tech{延续}不是 @racket[real?]，我们进入 else 分支并开始
折叠。如果遇到零，调用 @racket[(result r)]，触发@tech{延续}：控制跳回
求值 @racket[(cc)] 的位置，现在 @racket[result] 绑定到 @racket[r]（一
个实数）。进入 then 分支，立即返回。如果没有遇到零，@racket[for/fold]
的 @racket[#:result] 子句在折叠结束后调用 @racket[(result res)]，同样
触发@tech{延续}，@racket[result] 绑定到累积乘积 @racket[res]，从 then
分支返回。两条路径都通过@tech{延续} @racket[result] 汇合，不需要可变状
态，也不需要标志。

@section{消除分支：@racket[call/cc]}

@racket[cc] 消除了可变状态，但带来了新的要求：@bold{分支}。每次调用
@racket[(cc)] 的返回值都有两种可能，程序员必须区分收到的是哪种情况。在
提前返回的例子中，我们用 @racket[(real? result)] 来分离值和@tech{延
续}。这行得通，只是程序员又多了一件要操心的事。能不能把分支也一并消除
？

不再返回联合类型让调用者去分支，而是让调用者传入一个函数
@racket[proc]，直接把@tech{延续}作为参数交给它。分支挪进操作符内部，对
用户不可见。

挪进去的分支仍然要做。操作符自己调用 @racket[(cc)]，同样会拿到两种东西
：第一次是@tech{延续}，以后是传回来的结果。@racket[mul] 能用
@racket[real?] 分辨它们，是因为结果恰好是实数；操作符不知道结果会是什
么，结果也可能是一个函数，和@tech{延续}分不开。办法是把传回来的结果一
律收进一张列表。@tech{延续}是函数，永远不是列表，两者就分得开了：

@examples[#:eval ev #:label #f #:no-prompt
(: call/cc (∀ (p) (→ (→ (→ p ⊥) p) p)))
(define (call/cc proc)
  (define x (cc))
  (if (list? x)
      (apply values x)
      (proc (λ args (x args)))))]

@racket[x] 是 @racket[(cc)] 交出来的东西，和 @racket[cc] 里的
@racket[saved] 不是一回事。第一次，@racket[x] 是 @racket[cc]
的@tech{延续}，不是列表，走 else 分支。@racket[call/cc] 不把它原样交给
@racket[proc]，而是包上一层：@racket[(λ args (x args))] 把收到的参数收
成列表 @racket[args]，再交给 @racket[x]。

@racket[proc] 拿到这个包装好的@tech{延续}。它若在某处调用@tech{延
续}，@racket[cc] 的@tech{延续}收到那张列表，@racket[(cc)] 再次返回
，@racket[x] 绑定到列表，@racket[(list? x)] 为真
，@racket[(apply values x)] 把列表拆开交回。@racket[call/cc] 的调用者
收到了传给@tech{延续}的值，@racket[proc] 里剩下的工作被跳过
。@racket[proc] 若不调用@tech{延续}而正常返回，它的返回值就是
@racket[call/cc] 的结果。

有了 @racket[call/cc]，@racket[mul] 可以再写一次：

@examples[#:eval ev #:label #f #:no-prompt
(define (mul . r*)
  (call/cc
   (λ (return)
     (for/fold ([res (*)])
               ([r (in-list r*)])
       (if (zero? r)
           (return r)
           (* res r))))))]

@examples[#:eval ev #:label #f
(mul 2 3 4)
(mul 2 0 3)]

标志、可变状态、@racket[real?] 的分支都不见了。没有遇到零
，@racket[for/fold] 正常结束，乘积作为 @racket[proc] 的返回值交出；遇
到零，@racket[(return r)] 把零直接交给 @racket[mul] 的调用者。@tech{延
续}有了一个名字，叫 @racket[return]。许多语言里内建的那个
@racket[return]，在这里是一个普通的值，由 @racket[call/cc] 交到我们手
上。

@racket[proc] 常常只是这样一个给当前@tech{延续}起名字的 @racket[λ]。定
义一个宏，省去这层包装：

@examples[#:eval ev #:label #f #:no-prompt
(define-syntax-rule (let/cc k body ...)
  (call/cc (λ (k) body ...)))]

@racket[define-syntax-rule] 定义一个宏：@racket[(let/cc k body ...)]
在展开时改写成 @racket[(call/cc (λ (k) body ...))]。@racket[mul] 的主
体于是可以写成 @racket[(let/cc return …)]。

@bold{练习}：用 @racket[let/cc] 定义 @racket[call/cc]。

@subsection{更一般的延续类型}

交给 @racket[proc] 的@tech{延续}，类型是 @m{p → ⊥}。这个类型还可以放宽
。先看一个奇怪的函数：

@examples[#:eval ev #:label #f #:no-prompt
(: absurd (∀ (q) (→ ⊥ q)))
(define absurd (case-λ))]

@racket[case-λ] 按参数的个数分情形定义函数，每个子句对应一种调用方式。
一个子句也没有的 @racket[(case-λ)]，没有任何调用方式能与它匹配，这样的
函数永远不会被调用。这正合 @m{⊥} 的情形：@m{⊥} 没有值，谁也交不出一个
来给它。既然永远不会被调用，说它交出什么类型都不会错，所以
@racket[absurd] 的类型是 @m{⊥ → q}，@m{q} 任意。从空类型可以推出任何东
西。

把 @racket[absurd] 接在@tech{延续} @racket[k] 后面
，@racket[(compose absurd k)] 的类型就是 @m{p → q}。它的行为和
@racket[k] 完全一样：一调用，@racket[k] 就跳走，永远到不了
@racket[absurd]。所以交给 @racket[proc] 的@tech{延续}也可以看作
@m{p → q}，@racket[call/cc] 的类型随之变成：

@mm{((p → q) → p) → p}

令 @m{q = ⊥}，就回到原来的类型。原来的版本更直接地说出了@tech{延续}是
什么：一个接收 @m{p}、永不返回的函数。

@subsection{那条看不见的延续}

@racket[k] 和 @racket[(compose absurd k)] 行为一样，因为 @racket[k] 不
会返回，后面接了什么都不会执行。@racket[call/cc] 里也有一处类似的等价
，下面两个表达式行为相同：

@racketblock[
(call/cc proc)
(call/cc (λ (k) (k (proc k))))]

这里要分清三样东西：@racket[proc] 自己；第二行里包了一层的函数
@racket[(λ (k) (k (proc k)))]；还有 @racket[proc] 正常返回时，返回值要
去的地方。

先看运行路线。@racket[call/cc] 的第一行 @racket[(define x (cc))] 捕获
了一个@tech{延续}。这个@tech{延续}收到值以后做什么？走完 @racket[if]，
从 @racket[call/cc] 返回，接着做 @racket[call/cc] 调用之后的事。所以它
就是 @racket[call/cc] 自己的@tech{延续}，交给 @racket[proc] 的
@racket[k] 通向的也是这里。再看 @racket[(proc (λ args (x args)))]：它
处在 @racket[call/cc] 的尾位置，@racket[proc] 正常返回时，返回值同样直
接交给 @racket[call/cc] 的@tech{延续}。

于是两条路汇入同一个出口。第二行里，@racket[proc] 的结果经 @racket[k]
显式地交出去；第一行里，它经正常返回走到同一个地方。正常返回时隐含经过
的，就是这条看不见的@tech{延续}。

再看类型。@racket[proc] 自己的类型是 @m{(p → ⊥) → p}，它可以正常返回一
个 @m{p}，@racket[call/cc] 的类型就照这个读法写成。包了一层的
@racket[(λ (k) (k (proc k)))] 则从不正常返回，结果总是经 @racket[k] 交
出，它的类型是 @m{(p → ⊥) → ⊥}。两者交给 @racket[call/cc]，行为相同。
也可以干脆要求 @racket[proc] 本身就从不正常返回，它的类型便是
@m{(p → ⊥) → ⊥}。照这个读法，@racket[call/cc] 的类型是：

@mm{((p → ⊥) → ⊥) → p}

输入一个借@tech{延续}来交付结果的计算，从中把结果取出来。

@section{从 @racket[call/cc] 定义标签}

令 @m{p = @ty{Label}}，@racket[call/cc] 交给 @racket[proc] 的@tech{延
续}类型就是 @m{@ty{Label} → ⊥}，恰好是一个@tech{标签}。@tech{标签}因此
可以直接由 @racket[call/cc] 定义：

@(define ev1 (make-acf-eval))
@examples[#:eval ev1 #:label #f #:no-prompt
(define-type Label (→ Label ⊥))
(define (goto l) (l l))
(define (label) (call/cc goto))]

@defsym[@ty{Label} "标签的类型：Label = Label → ⊥"]
@m{@ty{Label} = @ty{Label} → ⊥} 是一个递归类型：@tech{标签}是一个接受@tech{标签}且永不返回的函数
。@racket[(label)] 做了什么，一步步展开来看。把 @racket[call/cc] 交给
@racket[goto] 的@tech{延续}记作 @racket[k]，它通向 @racket[(label)] 被
调用的地方：

@racketblock[
  (label)
= (call/cc goto)
= (goto k)
= (k k)]

@racket[goto] 把 @racket[k] 交给 @racket[k] 自己，于是
@racket[(label)] 返回的就是 @racket[k]：这个@tech{标签}就是它被创建处
的@tech{延续}。以后 @racket[(goto l)] 再调用 @racket[(l l)]，跳回同一
处，@racket[(label)] 又一次返回 @racket[l]。这正是开头为一等@tech{标
签}描述的行为。

这里的 @racket[call/cc] 要当作现成的原语，比如 Racket 自带的那一个。若
接上前面那个由@tech{标签}造出来的 @racket[call/cc]，就绕成了一个圈
：@racket[label] 调用 @racket[call/cc]，@racket[call/cc] 调用
@racket[cc]，@racket[cc] 又调用 @racket[label]，永远转下去。互相定义的
意思是，每一个都能以另一个为原语写出来，而不是把这些定义放进同一个程序
。

顺序也可以反过来。以@tech{标签}为原语，先得到 @racket[call/cc]，再由它
得到 @racket[cc]：

@(define ev2 (make-acf-eval))
@examples[#:eval ev2 #:hidden
(define primitive-call/cc call/cc)
(define (goto l) (l l))
(define (label) (primitive-call/cc goto))]
@examples[#:eval ev2 #:label #f #:no-prompt
(define (call/cc proc)
  (define saved #f)
  (define l (label))
  (if saved
      (apply values saved)
      (proc (λ args (set! saved args) (goto l)))))

(define (cc) (call/cc values))]

这个 @racket[call/cc] 手边没有 @racket[cc]，就直接用@tech{标签}和
@racket[set!]，写法和 @racket[cc] 一样，只是把@tech{延续}交给
@racket[proc]，而不是交给调用者。以 @racket[cc] 为原语，@tech{标签}就
是 @racket[(cc)] 第一次交出的那个@tech{延续}：

@examples[#:eval ev2 #:label #f #:no-prompt
(define (label) (cc))
(define (goto l) (l l))]

以后 @racket[(goto l)] 把 @racket[l] 交给它自己，@racket[(cc)] 再次返
回，交出的还是 @racket[l]。无论从哪一个出发，另外两个都写得出来：三种
表述在@bold{表达能力上等价}。

@section[#:tag "01:compare"]{比较}

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list ""
         @elem{一等@tech{标签} (@racket[goto] + @racket[label])}
         @elem{值与@tech{延续}的联合 (@racket[cc])}
         @elem{高阶回调 (@racket[call/cc])})
   (list @elem{@bold{涉及的类型}}
         @elem{只有 @racket[Label]}
         @elem{联合类型 @m{p ∪ (p → ⊥)}}
         @elem{高阶：@m{((p → ⊥) → p) → p} 或
               @m{((p → ⊥) → ⊥) → p}})
   (list @elem{@bold{需要可变状态？}}
         @elem{是：必须用 @racket[set!] 在跳转间传递信息}
         @elem{否}
         @elem{否})
   (list @elem{@bold{需要手动分支？}}
         @elem{否}
         @elem{是：必须区分 @m{p} 和 @m{p → ⊥}}
         @elem{否}))]

三种风格能做到的事没有区别，力量的来源也是同一个：跳转目标成为了值。在
C 中，label 是代码中的固定位置，不能存入变量、不能传给函数、不能作为返
回值。label 成为值的那一刻，@racket[goto] 就获得了 @racket[call/cc] 的
全部力量。这一步之后的一切都是易用性方面的取舍：每种风格为更方便地管理
同一种能力付出不同的代价（可变状态、分支、高阶类型）。
