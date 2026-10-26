#lang acf

@title[#:tag "01:3-fixed-point"]{否定的不动点}

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define-type ⊥ (∪))
(define primitive-call/cc call/cc)
(define (goto l) (l l))
(define (label) (primitive-call/cc goto))
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

@section{代入 @m{@ty{Label}}}

@tech{排中律} @m{p ∨ ¬p} 的两个分支，一个是 @m{p}，一个是 @m{¬p}：一真
一假。但如果代入的类型让真假变成同一个东西呢？更进一步：既然两个分支是
同一个类型，我们何必再区分它们？

既真又假，这正是@tech{说谎者悖论}，我们熟悉的 @m{@ty{Label}}。放
宽@tech{排中律}对不相交的要求，把 @m{@ty{Label}} 代入 @m{p}：

@mm{@ty{Label} ∨ ¬@ty{Label} = @ty{Label} ∨ @ty{Label} = @ty{Label}}

一切坍缩为 @racket[Label]。@m{@ty{Label}} 是@defterm{否定的不动点}：它
的反驳就是它自己。特别地，@bold{@racket[goto] 本身就是一个
@racket[Label]}：

@mm{@ty{Label} → ⊥ = ¬@ty{Label} = @ty{Label}}

之前所有的例子中，我们都是 @racket[goto] 配 @racket[label] 使用：

@racketblock[
(goto (label))]

但既然每个 @m{@ty{Label}} 同时也是一个合法的 @m{¬@ty{Label}}，没有什么
能阻止我们把@italic{任意}@tech{标签}传给任何其他@tech{标签}：

@racketblock[
((label) (label))]

在类型层面上，「跳转目标」和「跳转指令」没有区别：它们是同一种东西。这
种自指式的坍缩不是 bug，它是@tech{延续}令人费解的那些行为的源头。

@subsection{阴阳谜题}

把@tech{标签}直接交给@tech{标签}，就得到 David Madore 的阴阳谜题：

@examples[#:eval ev #:label #f
(eval:alts
 (let ([yin (label)])
   (displayln #\@)
   (let ([yang (label)])
     (display #\*)
     (yin yang)))
 (show-lines 5
  (λ ()
    (let ([yin (label)])
      (displayln #\@)
      (let ([yang (label)])
        (display #\*)
        (yin yang))))))]

程序里没有循环，没有计数器，也没有 @racket[set!]：只有两次
@racket[(label)]、两次打印和一次调用。输出却是一道无限增长的阶梯，每一
轮都比上一轮多打印一个 @racket[*]。多出来的那个 @racket[*]，记在了哪里
？

@subsubsection{追踪谜题}

给每个@tech{延续}一个唯一的名字
（@racket[k0]、@racket[k1]、@racket[k2]……），让每次
@racket[apply-cont] 都记录哪个@tech{延续}被应用于哪个：

@examples[#:eval ev #:label #f #:no-prompt
(define n -1)
(define (cc)
  (set! n (+ n 1))
  (let/cc k
    (define l
      (cons k (string->symbol
               (string-append "k" (number->string n)))))
    (apply-cont l l)))
(define (apply-cont kl l)
  (display (list (cdr kl) (cdr l)))
  (display #\tab)
  ((car kl) l))]

这里的 @racket[let/cc] 借的是 Racket 自带的那一个。前文的
@racket[let/cc]、@racket[call/cc]、@racket[cc] 是互相定义的，插桩时需
要一个现成的起点。

这里的@tech{延续}是函数和名字的 @racket[cons] 对，不能再直接调用。「
向@tech{延续}传递一个值」也就不再只是函数调用：@racket[apply-cont] 先
拆开这个对，记下名字，再调用里面的函数。@racket[cc] 构造@tech{延
续}，@racket[apply-cont] 消费@tech{延续}。插桩版的 @racket[cc] 在交回
新@tech{延续}时，先把它交给它自己，所以追踪里每个@tech{延续}第一次出现
都是 @racket[(kn kn)] 这样的一行。谜题改用这两个函数来写：

@examples[#:eval ev #:label #f
(eval:alts
 (let ([kn (cc)])
   (displayln #\@)
   (let ([kn+1 (cc)])
     (displayln #\*)
     (apply-cont kn kn+1)))
 (show-lines 10
  (λ ()
    (let ([kn (cc)])
      (displayln #\@)
      (let ([kn+1 (cc)])
        (displayln #\*)
        (apply-cont kn kn+1))))))]

@subsubsection{读矩阵}

把追踪排列成矩阵（行按参数@tech{标签}索引，列按目标@tech{标签}索引，越
往左的列越新）：

@out-block|{
      ...  k3   k2   k1   k0
k0                        @
k1                   *    @
k2              *    *    @
k3         *    *    *    @
...
}|

矩阵的每一行对应追踪输出中的一段，到 @racket[k0] 被调用为止。每行从左
往右读，就是执行的先后：追踪里的
@c{(k3 k3)*}、@c{(k2 k3)*}、@c{(k1 k3)*}、@c|{(k0 k3)@}| 正是第
@racket[k3] 行的 @racket[*]、@racket[*]、@racket[*]、@c|{@}|。每一行正
是原版谜题打印出的一行（插桩版为了配合追踪，每个字符各占一行）。每行
@m{n} 打印 @m{n} 个 @racket[*] 和一个 @c|{@}|。这个模式来自：

@itemlist[#:style 'ordered
  @item{@bold{@racket[k0] 打印 @c|{@}|} 并捕获一个新的@tech{延续}
  @racket[kn+1]。}
  @item{@bold{@racket[kn+1] 打印 @racket[*]} 并跳向 @racket[kn]。}
  @item{@bold{每个 @racket[kn]} 被调用时，收到最近捕获的@tech{延续}
  @racket[k] 作为参数。}]
之所以能级联，是因为每个@tech{延续}都「记得」下一步要跳向哪个
@racket[kn]，形成一条链，每经过一次 @racket[k0] 就多一个链节。

@subsubsection{用函数重写}

这三条规律只涉及@tech{延续}之间谁调用谁、传的是什么。照着它们，把每
个@tech{延续}直接写成一个函数：跳向一个@tech{延续}，就是调用它；捕获一
个新@tech{延续}，就是定义一个新函数。

@racketblock[
(define (k0 kn)
  (displayln #\@)
  (define (kn+1 k)
    (display #\*)
    (kn k))
  (kn+1 kn+1))
(k0 k0)]

@racket[k0] 打印 @c|{@}|，定义一个新函数 @racket[kn+1] 打印 @racket[*]
并委托给 @racket[kn]，然后用自身调用 @racket[kn+1]：

@itemlist[
  @item{第一次调用时，@c{kn = k0}。打印 @c|{@}| 后，创建一个新闭包
  @racket[kn+1]（我们叫它 @racket[k1]），它打印 @racket[*] 并委托给
  @racket[k0]。然后 @racket[(kn+1 kn+1)] 用自身调用
  @racket[k1]：@racket[k1] 打印 @racket[*] 并调用 @racket[(k0 k1)]。}
  @item{现在回到 @racket[k0]，此时 @c{kn = k1}：打印 @c|{@}|，创建另一
  个新闭包 @racket[k2]，它打印 @racket[*] 并委托给 @racket[k1]，然后调
  用 @racket[(k2 k2)]。@racket[k2] 打印 @racket[*] 并调用
  @racket[(k1 k2)]；@racket[k1] 打印 @racket[*] 并调用
  @racket[(k0 k2)]。}
  @item{以此类推：每次经过 @racket[k0] 都给委托链多加一环。}]
运行它，输出和前面一样。

这段代码里没有 @racket[label]、@racket[cc]，也没有 @racket[set!]。原来
由 @racket[cc] 捕获的@tech{延续}，现在都成了显式传递的参数
：@racket[k0] 收到 @racket[kn]，@racket[kn+1] 收到 @racket[k]，每一次
跳转都是把@tech{延续}交给下一个函数的尾调用。这种把@tech{延续}作为参数
传递的写法，叫
做@defterm[#:en "Continuation-Passing Style" #:abbr "CPS"]{延续传递风
格}；把程序改写成这种写法，就是 @defterm{CPS 变换}。

反过来看，原来的谜题就是这组@bold{互递归调用}，只是其中的@tech{延续}由
@racket[(label)] 在运行时捕获，而不是作为参数传进来。回忆我们说过的
@m{@ty{Label} = ¬@ty{Label}}，它是@tech{说谎者悖论}，一个既不能判真也
不能判假的命题。阴阳谜题就是那个悖论作为程序运行起来的样子：永不终止地
振荡，永远无法落定为真或为假。

@section{结论}

@xref["01:compare"]{比较一节}把三种风格的力量归于同一步：跳转目标成为
值。这个值的类型是 @m{¬p}。只用 @racket[λ] 和函数调用，写不出非空
@m{p} 的@tech{否定}，@racket[cc] 和 @racket[call/cc] 交出的@tech{延
续}都是在运行时捕获的。@xref["01:watershed"]{分水岭一节}的表格沿着同一
条线分成两列：@racket[apply-cont] 和 DNI 只消耗交到手里的@tech{否定}，
只需要普通函数；@racket[cc] 和 @racket[call/cc] 要凭空造出一个非空
@m{p} 的@tech{否定}，必须捕获。

程序在操作系统面前也处在这条线上。它是一个 @m{¬¬@ty{Byte}}，等待的那条
@m{¬@ty{Byte}} 不由它自己写出，而是在启动时由操作系统交给它。

@subsection{未解的线索}

但我们小心避开了一个问题。编程语言建立在@bold{构造性}的基础之上
：@tech{Curry-Howard 对应}把程序与直觉主义证明配对，而在@tech{直觉主义
逻辑}中，@tech{排中律}不是定理。然而我们一直在愉快地使用@tech{排中
律}、Clavius 律和 DNE，仿佛它们是天经地义的。

这怎么可能？一个构造性语言如何支持经典推理？

阴阳谜题的 CPS 分解提供了一条线索。当我们只用纯 lambda 和函数调用（没
有 @racket[call/cc]、没有 @racket[goto]、没有可变状态）重写谜题时，表
达能力没有任何损失。经典的控制流仍然存在，只是被@bold{换了一种方式编
码}：作为显式的@tech{延续}传递。在证明论中，这种编码叫
做@defterm[#:en "negative translation"]{否定翻译}；它在计算上的对应物
，叫做@bold{@tech{延续}单子}。

还有另一根线头。程序类型 @m{¬¬@ty{Byte}} 中的 @m{⊥} 不是世界的终结：进
程终止后，OS 继续运行。@m{⊥} 只是@italic{这个进程}的终结，不是所有计算
的终结。它是一个@italic{相对的} bottom，不是绝对的。

如果我们能在程序@italic{内部}拥有相对的 @m{⊥} 呢？如果函数调用，而不仅
仅是 OS，也能充当定界符呢？

但那些
是@hyperlink["https://zhuanlan.zhihu.com/p/2024852076593694078"]{后续
文章}的故事了。
