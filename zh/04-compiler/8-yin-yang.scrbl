#lang acf/scribble

@title[#:tag "04:8-yin-yang"]{再看阴阳谜题}

@music{史蒂夫·赖希《Clapping Music》}

每个源程序都包含 @racket[reset]；没有一个目标程序包含。没有标记，没有包装器，没有运行时支持。边界去了哪里？

@section[#:tag "04:reset-gone"]{@racket[reset] 去了哪里}

看例二的输出：@racket[((λ (v) (+ 10 v)) ((λ (k) 3) (λ (x) (+ 2 x))))]。@racket[reset] 的主体编译成了 @racket[((λ (k) 3) (λ (x) (+ 2 x)))]，它是外层@tech{延续} @racket[(λ (v) (+ 10 v))] 的参数。主体内部的调用都在尾位置，用户函数把@tech{延续}参数一路传下去，没有谁在等待；主体本身却处在参数位置，宿主要在自己的栈上留一帧，等它算完，再把结果交给加十。这一帧就是边界。

@xref["03:abort-shift"]{「从 return 到 shift」}的 @racket[anf:reset] 是同一个结构：@racket[(kₓa (anf:eval kₐkₐa))] 中，@racket[anf:eval] 不在尾位置，宿主的等待帧保存了外层的 @racket[kₓa]。编译器把这一步写进了目标代码：@racket[reset] 的主体编译到非尾位置，定界由宿主自己的调用与返回提供。主体从 @racket[id] 开始编译，@tech{局部终结延续}是恒等函数，所以输出里连它也看不见，只在用户定义函数没有剩余工作的调用处，以 @racket[values] 的样子出现。这正是@xref["03:local-k"]{「局部延续」}里@tech{平凡表示}下的分工：@tech{局部延续}是一路传下去的@tech{延续}参数，住在堆上的闭包里；@tech{元延续}是宿主的栈。

@section[#:tag "04:fixed"]{修复之后}

@xref["04:5-broken"]{「镜子破裂」}一节，函数形式的谜题只打印出一个 @c|{@}| 和一个 @racket[*]。修复之后再编译它：

@(define ev-yy (make-acf-eval))
@examples[#:eval ev-yy #:hidden
(require acf/zh/04-compiler/code)
(require racket/list racket/string)
(code:comment "无限输出只看前 n 行，后面印出 ...")
(define (show-lines n thunk)
  (define out (open-output-string))
  (define t (parameterize ([current-output-port out]) (thread thunk)))
  (let loop ()
    (define s (get-output-string out))
    (cond [(>= (length (regexp-match* #rx"\n" s)) n)
           (kill-thread t)
           (define lines (string-split s "\n" #:trim? #f))
           (for ([l (in-list (take lines n))])
             (displayln l))
           (display "...")]
          [(thread-dead? t) (display s)]
          [else (sleep 0.01) (loop)])))]

@examples[#:eval ev-yy #:label #f
(define label-puzzle
  '(reset
    (let* ([label (λ () (let/lc k k))]
           [yin   (label)]
           [_     (displayln #\@)]
           [yang  (label)]
           [_     (display #\*)])
      (yin yang))))
(cps label-puzzle)]

运行，阶梯回来了：

@examples[#:eval ev-yy #:label #f
(eval:alts (eval (cps label-puzzle))
           (show-lines 5 (λ () (eval (cps label-puzzle)))))]

但对照文法读一读输出。@racket[label] 编译成 @racket[(λ () (λ (k.0) ((λ (k) (k k)) k.0)))]，化简一步就是 @racket[(k.0 k.0)]：调用处的@tech{延续} @racket[k.0] 被当作值，交给了它自己。于是 @racket[yin] 和 @racket[yang] 拿到的都是@tech{延续}。而 @racket[(yin yang)] 编译成了 @racket[((yin yang) values)]：@racket[yin] 不在平凡集合里，编译器把它当作用户定义的函数，额外传了一个@tech{延续}参数 @racket[values]。文法说@tech{延续}通过 @racket[<apply-cont>] 调用，写作 @racket[(<cont> <val> ...)]，不带自己的@tech{延续}参数；这里却是 @racket[<apply-proc>]，一个@tech{延续}被用在了文法期望过程的位置。

程序照样能跑，只因为 @racket[(yin yang)] 永远不会返回，多传的那个 @racket[values] 从来没有机会被用上。换一个会返回的程序，问题就露出来了：

@examples[#:eval ev-yy #:label #f
(cps '(let ([id (reset (shift k k))]) (id (id 3))))]

@racket[id] 被绑定到恒等@tech{延续}，@racket[(id (id 3))] 把它当作一等值使用。化简后：@racket[(define id values)]，然后 @racket[((id 3) (λ (v.3) ((id v.3) values)))]。运行：

@examples[#:eval ev-yy #:label #f
(eval:error (eval (cps '(let ([id (reset (shift k k))]) (id (id 3))))))]

第一个 @racket[(id 3)] 返回 @racket[3]，而 @racket[3] 被当作过程调用了。

@section[#:tag "04:val-cont"]{值与延续的界线}

文法把 @racket[<val>] 和 @racket[<cont>] 分开：@tech{延续}可以被调用，却不能当作值传来传去，它不是一等的。谜题的类型恰恰要求相反。第一章的 @math{@ty{Label} = ¬@ty{Label}} 换到局部，是 @math{@ty{Label} = ¬ₐ@ty{Label}}：@racket[Label] 既是传来传去的值，又是被调用的@tech{延续}。

@xref["03:escape-discard"]{「逃逸与丢弃」}其实处理过这件事。@racket[call/lc] 交给程序的不是裸的 @racket[kₐp]，而是 @racket[(cps kₐp)]：@tech{局部延续}在宿主里是普通函数，要交给写成 @tech[#:key "延续传递风格"]{CPS} 箭头的程序，先得用 @racket[cps] 提升成 @math{→𝒦ₐ} 箭头。在源程序里做同样的事，就是把@tech{延续}包进一个 lambda：

@examples[#:eval ev-yy #:label #f
(cps '(let ([id (reset (shift k (λ (v) (k v))))]) (id (id 3))))
(eval (cps '(let ([id (reset (shift k (λ (v) (k v))))]) (id (id 3)))))]

包装 @racket[(λ (v) (k v))] 编译成了 @racket[(λ (v) (λ (k.0) (k.0 (k v))))]，正是 @racket[(cps k)] 的展开：先把 @racket[v] 交给 @racket[k]，再把结果交给调用处的@tech{延续}。它是一个合格的 @racket[<val>]。它同时也是一个 η-可归约式，归约后就是刚才出问题的裸 @racket[k]：前面一个接一个擦除包装器的 η 在这里不再成立，因为两侧不再是同一种东西。@racket[(λ (v) (k v))] 是 @racket[<val>]，@racket[k] 是 @racket[<cont>]。

这条界线在文法里是两条产生式：

@out-block|{
<val>  ::= <var> | <literal> | <proc>
<cont> ::= (λ <head> <cps>) | <trivial>
}|

@racket[shift] 命名的 @racket[k] 属于 @racket[<trivial>]，是 @racket[<cont>] 的一种，@racket[<val>] 里没有它的位置。@racket[<trivial>] 里也不只有@tech{延续}变量：平凡集合是从内建原语开始的，@racket[add1] 和 @racket[k] 站在同一边。

如果刚才出错的原因就是这条界线，和被传递的是不是@tech{延续}无关，那么 @racket[add1] 当作值传递时也会出同样的错，包一层也同样管用。拿它试一下，一次直接绑定给 @racket[f]，一次包进 lambda：

@examples[#:eval ev-yy #:label #f
(cps '(let ([f add1]) (f 41)))
(cps '(let ([f (λ (x) (add1 x))]) (f 41)))]

第一个输出里，@racket[f] 不在平凡集合中，编译器把 @racket[(f 41)] 当作用户定义函数的调用，多传了一个 @racket[values]。运行时 @racket[f] 是宿主的 @racket[add1]，直接返回 @racket[42]，@racket[42] 接着被当作过程调用，报的是同一种错。「平凡」是编译器按名字认的，名字一换就认不出来了。第二个输入把 @racket[add1] 包进 lambda，编译出来是 @racket[(cps add1)] 的展开，一个 @racket[<proc>]，运行结果是 @racket[42]。

@section[#:tag "04:wrapped"]{包装之后的阶梯}

包装就位后，编译完整的谜题，内联定义以保持输出可读：

@examples[#:eval ev-yy #:label #f
(define wrapped-puzzle
  '(reset
    (let* ([kn (let/lc k0   (λ (v) (k0   v)))]
           [_  (displayln #\@)]
           [km (let/lc kn+1 (λ (v) (kn+1 v)))]
           [_  (display #\*)])
      (kn km))))
(cps wrapped-puzzle)]

把形如 @racket[((λ (_) …) (display …))] 的应用还原成先打印、再往下做，改写为 @racket[define] 形式：

@examples[#:eval ev-yy #:label #f #:no-prompt
(define (k0 kn)
  (displayln #\@)
  (define (kn+1 km)
    (display #\*)
    ((kn km) values))
  (kn+1 (λ (v) (λ (k.1) (k.1 (kn+1 v))))))]

启动也照编译输出最外层的那次调用：交给 @racket[k0] 的不再是它自己，而是包了一层@tech{延续}参数的 @racket[(λ (v) (λ (k.0) (k.0 (k0 v))))]：

@examples[#:eval ev-yy #:label #f
(eval:alts (k0 (λ (v) (λ (k.0) (k.0 (k0 v)))))
           (show-lines 5 (λ () (k0 (λ (v) (λ (k.0) (k.0 (k0 v))))))))]

这次每个@tech{延续}都待在文法给它的位置上，代码也说明了阶梯为什么永不停止。每个@tech{延续}参数（@racket[k.0]、@racket[k.1]）都使用过了：@racket[(k.0 (k0 v))] 和 @racket[(k.1 (kn+1 v))]。但在运行时，每次调用传递的@tech{延续}参数都是 @racket[values]，即@tech{局部终结延续}，所以 @racket[k.0] 和 @racket[k.1] 总是绑定到 @racket[values]，从不做事。递归调用 @racket[(k0 v)] 和 @racket[(kn+1 v)] 语法上处在非尾位置，外面包着 @racket[(k.0 ...)] 和 @racket[(k.1 ...)]；但因为 @racket[values] 是恒等，等着它们的帧不做任何工作，只是接收递归调用的结果，原样传回。帧在宿主栈上累积，而谜题永不返回，它们永远不会被回卷。递归永远旋转。

@section[#:tag "04:let-cc"]{换成 let/cc}

这些帧是不是必需的？把包装去掉，让谜题里的@tech{延续}不是由 @racket[let/lc]、而是由 @racket[let/cc] 捕获，再编译一次：

@examples[#:eval ev-yy #:label #f
(define cc-puzzle
  '(reset
    (let* ([kn (let/cc k0 k0)]
           [_  (displayln #\@)]
           [km (let/cc kn+1 kn+1)]
           [_  (display #\*)])
      (kn km))))
(cps cc-puzzle)
(eval:alts (eval (cps cc-puzzle))
           (show-lines 5 (λ () (eval (cps cc-puzzle)))))]

输出同样是阶梯，也不需要包装：@racket[let/cc] 交出的 @racket[(λ (v.1) (λ (k.1) (k.0 v.1)))] 本来就是一个 @racket[<proc>]。两份输出只差交给程序的@tech{延续}。@racket[let/lc] 版交出的是 @racket[(λ (v) (λ (k.0) (k.0 (k0 v))))]，即 @racket[(cps kₐp)]：@racket[(k0 v)] 不在尾位置，外面还留着 @racket[k.0] 等它返回。@racket[let/cc] 版交出的是 @racket[(λ (v.1) (λ (k.1) (k.0 v.1)))]，即 @racket[(cps* kₐp)]：忽略调用处的 @racket[k.1]，直接把 @racket[v.1] 交给捕获时的 @racket[k.0]，在尾位置。

差别在内存里看得出来。在 Racket 9.3 里让两个版本各输出两千五百行，每五百行 GC 一次后量内存：@racket[let/cc] 版稳定在 90 MB 上下，@racket[let/lc] 版是 92、95、100、107、116 MB，一直往上涨。阶梯没有变，变的是等在后面的帧：@racket[let/lc] 版每一级都在宿主栈上多留一帧，@racket[let/cc] 版一帧也不留。@xref["02:yin-yang"]{「阴阳谜题」}里 @racket[cps:call/cc] 与 @racket[cps:call/lc] 的差别，在编译输出里就是这两种形状。
