#lang acf/scribble

@title[#:tag "01:4-fixed-point"]{否定的不动点}

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

从 @racket[call/cc] 倒回 @racket[cc]，再倒回一步，就回到了起点：
@racket[Label]。这个类型我们早就认识，却一直没拿来代入。
@math{@ty{Label} = @ty{Label} → ⊥} 用 @math{¬} 改写，就是
@math{@ty{Label} = ¬@ty{Label}}：它的否定就是它自己，是@defterm{否定的不动点}。
连 @racket[goto] 也是一个@tech{标签}：

@mm{@ty{Label} → ⊥ = ¬@ty{Label} = @ty{Label}}

层数还数得下去吗？以 @racket[Label] 为底，它外面包一层否定，得到的
@math{¬@ty{Label}} 还是 @racket[Label]；再包一层，还是 @racket[Label]。
层号照样数得下去，可每一层都是同一个类型。可以把它想成一座无穷高的否定塔，
每一层都是同一个 @racket[Label]；层数在这里不再能区分角色，
分不清一个@tech{标签}是被调用的那个，还是交出去的那个。

@section[#:tag "01:label-sub"]{代入 @racket[Label]}

把 @racket[Label] 代入@tech{排中律} @math{p ∨ ¬p}。按定义，@math{¬@ty{Label}}
就是 @racket[Label]，两个分支成了同一个类型：

@mm{@ty{Label} ∨ ¬@ty{Label} = @ty{Label} ∨ @ty{Label}}

一真一假的两支，在这里分不出真假。@racket[(cc)] 交出的
@math{@ty{Label} ∐ @ty{Label}} 里，两支还配着标记：每个@tech{标签} @math{l} 有
@math{(l, 0)}、@math{(l, 1)} 两份，记着自己来自哪一支。
可@xref["01:label-from-call-cc"]{「从 call/cc 定义标签」}里，
@tech{标签}是这样从 @racket[cc] 写出来的：

@racketblock[
(define (label) (car (cc)))]

@racket[car] 丢掉了标记，两份并成一个 @math{l}，就像普通的并集不记来源。
两支就坍缩成了一支：

@mm{@ty{Label} ∪ @ty{Label} = @ty{Label}}

既然只剩一支，也就不必再分。@racket[mul] 当初要用 @racket[match] 分辨
@racket[(cc)] 交出的是值还是@tech{延续}；在 @racket[Label] 上，不管交出哪一支，
拿到的都是一个@tech{标签}，既能当值存着，也能当@tech{延续}去调
用。@racket[(label)] 就是这样一个不分支的 @racket[cc]。

@section[#:tag "01:yin-yang"]{把标签交给标签}

之前的例子里，我们总是先用 @racket[(label)] 造一个@tech{标签}，存进变量，再交给
@racket[goto] 跳回去。省掉中间的变量，就是：

@racketblock[
(goto (label))]

@racket[goto] 跳回 @racket[(label)]，它再次交出同一个@tech{标签}，又交给
@racket[goto]，一直回跳下去。

@racket[goto] 本身也是一个@tech{标签}。既然每个 @racket[Label]
同时也是一个合法的 @math{¬@ty{Label}}，没有什么能阻止我们把它也换成一个新捕获
的@tech{标签}：

@racketblock[
((label) (label))]

这回会怎样运行？光看这一行看不出来。Racket 从左往右求值，
先捕获前一个@tech{标签}，再捕获后一个。用 @racket[let] 把这个次序写明，
给两个@tech{标签}起名 @racket[yin]、@racket[yang]，再在中间打印点什么：

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

这就是 David Madore 的阴阳谜题。两次 @racket[(label)] 交出的都是@tech{标
签}。@racket[(yin yang)] 就是一次函数调用：同一个类型，@racket[yin]
当作@tech{延续}，@racket[yang] 当作交给它的值。

程序里没有循环，没有计数器，也没有 @racket[set!]：只有两次 @racket[(label)]、
两次打印和一次调用。输出却是一道无限增长的阶梯，每一轮都比上一轮多打印一个
@racket[*]。多出来的那个 @racket[*]，记在了哪里？

@subsection[#:tag "01:trace"]{追踪谜题}

要回答这个问题，得看清每一步跳向了谁。@xref["01:neg-q"]{「代入
¬q」}里的调用链只有四步，手算就够了；这回停不下来，得让程序自己印出来。
给每个@tech{延续}起一个名字：@racket[k0]、@racket[k1]、@racket[k2]……为此，
这一节里先换一种否定类型：@tech{延续}带上一个编号，装进 @racket[cons] 对。

@examples[#:eval ev #:label #f #:no-prompt
(define-type (¬ p) (Pair (→ p ⊥) Natural))
(define-type Label (¬ Label))]

@racket[Label] 照旧是它自己的否定，只是否定换了表示。插桩版的 @racket[label]
每捕获一个@tech{延续}，就给它配上一个新编号：

@examples[#:eval ev #:label #f #:no-prompt
(define n -1)

(: label (→ Label))
(define (label)
  (set! n (+ n 1))
  (let/cc kn
    (define ln (cons kn n))
    (apply-cont ln ln)))]

交出去的 @racket[ln] 装着第 @racket[n] 条@tech{延续} @racket[kn] 和它的编号
@racket[n]，不再是能直接调用的函数，调用它的办法得我们自己规
定。@racket[apply-cont] 的签名还是那一个，只是这里 @math{p} 取 @racket[Label]：
向一个@tech{否定}交一个值，不管@tech{否定}怎样表示，都是这个操作。
插桩版要印出两边的编号，所以用 @racket[match-define] 拆开两个对，印出谁跳向谁，
再调用里面的函数：

@examples[#:eval ev #:label #f #:no-prompt
(: apply-cont (→ (¬ Label) Label ⊥))
(define (apply-cont ln lm)
  (match-define (cons kn n) ln)
  (match-define (cons km m) lm)
  (display (format "    (k~a k~a): " n m))
  (kn lm))]

插桩版的 @racket[label] 和@xref["01:label-from-call-cc"]{原来那个}一样，
捕获@tech{延续}之后先拿它调用它自己，只是这一次经过 @racket[apply-cont]，
所以每个@tech{延续}第一次出现，都是 @racket[(kn kn)] 这样一项。

谜题里的 @racket[(yin yang)] 换成 @racket[apply-cont]，打印照旧：

@examples[#:eval ev #:label #f
(eval:alts
 (let ([yin (label)])
   (displayln #\@)
   (let ([yang (label)])
     (display #\*)
     (apply-cont yin yang)))
 (show-lines 4
  (λ ()
    (let ([yin (label)])
      (displayln #\@)
      (let ([yang (label)])
        (display #\*)
        (apply-cont yin yang))))))]

每一项是一对名字，前一个是被跳向的目标，后一个是交给它的参数。程序里的
@racket[yin]、@racket[yang] 只是变量名；印出来的
@racket[k0]、@racket[k1]、@racket[k2]……才是一条条具体的@tech{延续}。@racket[k0]
由第一处 @racket[(label)] 捕获，只有这一条；@racket[k1]、@racket[k2]……都由第二处
捕获。

@subsection[#:tag "01:rules"]{读出规律}

规律就在每一对名字里。先看第三行 @c|{(k2 k2): *  (k1 k2): *  (k0 k2): @}|：
右边总是 @racket[k2]，最近捕获的那条；左边一步步往回退。@racket[k2]
被捕获时，@racket[yin] 绑的是 @racket[k1]，所以跳回 @racket[k2]，
继续执行的是捕获时那份环境里的 @racket[(yin yang)]：@racket[yin] 是
@racket[k1]，@racket[yang] 收到这次交来的 @racket[k2]。@racket[(k2 k2)] 打印
@racket[*] 之后，下一步就是 @racket[(k1 k2)]；@racket[k1] 被捕获时 @racket[yin]
绑的是 @racket[k0]，于是接着是 @racket[(k0 k2)]。

一般地，把第 @math{n} 条@tech{延续}记作 @racket[kn]。右边是交出去的参数，
总是最近捕获的那条@tech{延续}，记作 @racket[km]；左边是当前被调用的那条。
调用的若是 @racket[(kn+1 km)]，打印一个 @racket[*]，下一步就是
@racket[(kn km)]，把同一个 @racket[km] 交给前一条：@racket[kn+1]
被捕获时，@racket[yin] 绑的正是 @racket[kn]，它记下的就是这一条。调用的若是
@racket[(k0 km)]，打印 @c|{@}|，下一步捕获一条新的 @racket[km+1]，从
@racket[(km+1 km+1)] 开始。每到一次 @racket[k0]，就多一条@tech{延续}，
下一行就要多退一步，多打印一个 @racket[*]。多出来的那个 @racket[*]，
就记在@tech{延续}里：每条 @racket[kn+1] 都记着前一条 @racket[kn]，
一条接一条连成链。

这条规律只说@tech{延续}之间谁调用谁、交出的是什么，照着写成函数就行：
跳向一条@tech{延续}，就是调用它；捕获一条新@tech{延续}，就是定义一个新函数。

@examples[#:eval ev #:label #f
(define (k0 kn)
  (displayln #\@)
  (define (kn+1 km)
    (display #\*)
    (kn km))
  (kn+1 kn+1))
(eval:alts (k0 k0) (show-lines 5 (λ () (k0 k0))))]

输出和原版谜题一模一样。

这段代码里没有 @racket[label]、@racket[cc]，也没有 @racket[set!]。原来由
@racket[cc] 捕获的@tech{延续}，现在都成了显式传递的参数：@racket[k0] 收到
@racket[kn]，@racket[kn+1] 收到 @racket[km]，每一次跳转都是把@tech{延续}交给下一
个函数的尾调用。这种把@tech{延续}作为参数传递的写法，叫
做@defterm[#:en "Continuation-Passing Style" #:abbr "CPS"]{延续传递风格}；
把程序改写成这种写法，就是 @defterm{CPS 变换}。

反过来看，原来的谜题就是这样一组@bold{函数调用}，只是其中的@tech{延续}由
@racket[(label)] 在运行时捕获，而不是作为参数传进来。

@section[#:tag "01:where-fails"]{对应关系在哪里失效}

阴阳谜题有类型，却永远停不下来。「写出表达式就是证明」的读法，
在这里显然不成立了。回头看，它在好几处都不成立。@tech{Curry-Howard
对应}在纯粹的全函数语言（每个函数都会终止并交出值，如 Agda 和 Coq）中是精确的：
对任意非空的 @math{p}，@math{¬p} 确实是空的。真实的编程语言打破了这一点。

最简单的是 @racket[(define (loop) (loop))]。它是一个交出 @math{⊥} 的
@racket[thunk]，类型是 @math{⊤ → ⊥ = ¬⊤}：真的@tech{否定}。@math{¬⊤}
本应是空的，因为真不可反驳；@racket[loop] 却是这个类型下合法的表达式，
只不过一调用就永不终止。合法的表达式不一定终止，并非每个表达式都是证明。

再看语言内置的 @racket[exit]。若把它当作无需任何假设就能用的常量，赋予它
@math{@ty{Byte} → ⊥} 的类型，那么 @racket[(λ (_) (exit 0))] 就能占据任意
@math{p → ⊥}。@racket[raise] 抛出异常，也不正常返回到抛出的位
置，@racket[(λ (_) (raise 'oops))] 同样是一个 @math{¬p}。
任何真命题的@tech{否定}都变成了非空，这类内置操作不能直接纳入同一套无条件证明的
读法。@xref["01:program-type"]{「代入 Byte」}中由参数交来的 @racket[exit]
则算一个假设，不是这样的反例。

第三种就是 @racket[Label]。@math{@ty{Label} = ¬@ty{Label}} 读作命题，
就是一句「这句话是假的」。推一推：如果 @racket[Label] 为真（非
空），@math{¬@ty{Label}} 也就非空，@racket[Label] 的@tech{否定}为
真，@racket[Label] 为假。如果 @racket[Label] 为假（空），@math{¬@ty{Label}}
反倒有元素：空类型出发的函数总写得出来，就像 @racket[absurd] 填充了
@math{⊥ → p}；可 @math{¬@ty{Label} = @ty{Label}}，于是 @racket[Label]
又有了元素，变成了真。这就是@defterm{说谎者悖论}，它无法被一致地赋予真假值。
阴阳谜题就像让它运行了起来：同一个@tech{标签}一会儿被调用，一会儿被交出去，
永远落不了地。更简单的是把 @racket[goto] 交给它自己：@racket[(goto goto)]
的类型是 @racket[⊥]，却永远算不完。Agda 和 Coq 这样的一致类型论禁止这类定
义；Racket 没有这个限制。

每种情况下，严格的 Curry-Howard 解读都失效了：本应为空的@tech{否定}类型有了元
素，本应非法的自指类型变得合法。不能把任意 Racket 表达式都当作证明。
前面读出逻辑定律时，无限循环、内置的 @racket[exit]、抛出异常和自指类型，
都不在这个读法之内；@racket[cc] 和 @racket[call/cc] 当作现成的操作，
按它们的类型来用；它们内部怎样用 @racket[label]、@racket[set!] 实现，
不算在证明里。

前面真正用到的是两条规则：按给定的类型使用控制操作符，程序里交进来的东西，
在证明里算假设。在这个范围内，程序的类型推导对应逻辑证明；除了交进来的东西，
不再依赖别的时候，得到的才是相应命题的无条件证明。加入控制操作，
就多了@tech{排中律}、DNE 这样的推理规则。
