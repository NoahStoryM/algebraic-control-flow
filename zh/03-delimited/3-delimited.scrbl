#lang acf/scribble

@title[#:tag "03:3-delimited"]{定界延续}

@racket[cps*] 把一条@tech{局部延续}提升成会跳走的@tech{延续}，@racket[cps:call/cc] 拿它提升的是当前的那一条。还有一条@tech{局部延续}，也在手边。

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define ∘ compose)
(define id (∘))
(define-type ⊥ᵃ Real)
(define a->⊥ᵃ id)
(define ⊥ᵃ->a id)
(define (((cps f) . p*) kₐq) (kₐq (apply f p*)))
(define (((cps* kₐp) . p*) _kₐq) (apply kₐp p*))
(define ((cps:call/lc cps:proc) kₐp) ((cps:proc (cps  kₐp)) kₐp))
(define ((cps:call/cc cps:proc) kₐp) ((cps:proc (cps* kₐp)) kₐp))
(define (anf:eval kₐkₐa) (⊥ᵃ->a (kₐkₐa a->⊥ᵃ)))
(define anf:reset (cps anf:eval))
(define-syntax anf:let*-values
  (syntax-rules ()
    [(_ () b* ...)
     (anf:begin b* ...)]
    [(_ ([v* e]) b* ...)
     (λ (k) (e (λ v* ((anf:begin b* ...) k))))]
    [(_ ([v* e] [v** e*] ...) b* ...)
     (anf:let*-values ([v* e])
       (anf:let*-values ([v** e*] ...)
         b* ...))]))
(define-syntax anf:begin
  (syntax-rules ()
    [(_ b) b]
    [(_ b b* ...) (anf:let*-values ([_ b]) b* ...)]))
(define-syntax-rule (anf:let* ([v e] ...) b* ...)
  (anf:let*-values ([(v) e] ...) b* ...))
(define cps:id (cps id))
(define cps:+  (cps +))]

@section[#:tag "03:abort-shift"]{从 return 到 shift}

@racket[cps:call/cc] 提升的是 @tech[#:key "延续传递风格"]{CPS} 参数 @racket[kₐp]，也就是当前的@tech{局部延续}，它随着计算一步步变化。计算运行时，还有一条@tech{局部延续}始终不变：@racket[anf:eval] 启动时交进去的@tech{局部终结延续} @racket[a->⊥ᵃ]。@racket[cps*] 能提升任何一条@tech{局部延续}，把它用在 @racket[a->⊥ᵃ] 上：

@examples[#:eval ev #:label #f #:no-prompt
(define cps:abort (cps* a->⊥ᵃ))]

@defsym["cps:abort" "(cps* a->⊥ᵃ)：丢掉当前延续，把值交给局部终结延续"]照名字的约定，@racket[cps:abort] 是一支 @tech{CPS 箭头}；它不是把哪个 @racket[abort] 用 @racket[cps] 提升出来的，而是 @racket[cps*] 用在 @racket[a->⊥ᵃ] 上。它丢掉当前@tech{延续}，把值交给@tech{局部终结延续}：从@tech{闭包链}上的任何一处跳到链底，值成为这段局部计算的答案。回看@xref["03:escape-discard"]{「逃逸与丢弃」}里用 @racket[cps:call/cc] 提前退出的例子：

@racketblock[
(anf:eval
 (cps:call/cc
  (λ (cps:return)
    ...)))]

那里 @racket[cps:call/cc] 紧跟在 @racket[anf:eval] 后面，前面还没有任何绑定，当前@tech{延续}就是@tech{局部终结延续} @racket[a->⊥ᵃ]。@racket[cps:call/cc] 交出 @racket[(cps* kₐp)]，也就是 @racket[(cps* a->⊥ᵃ)]，就是 @racket[cps:abort]。之前靠 @racket[cps:call/cc] 拿到的 @racket[cps:return]，现在不必捕获：它就是 @tt{return}。

在一个函数里调用另一个函数，被调用的函数从自己的空栈开始执行。@racket[anf:reset] 做的是同一件事：@racket[anf:eval] 把 @racket[a->⊥ᵃ] 交给里面的计算 @racket[kₐkₐa]，一个空栈，没有待做的工作。里面的计算以它为底，由 @racket[anf:let*] 接出自己的@tech{闭包链}；外面的 @racket[kₐa] 没有接进来。展开 @racket[(cps anf:eval)]，外面的@tech{延续}在等它：

@racketblock[
(((cps anf:eval) kₐkₐa) kₐa)  =  (kₐa (anf:eval kₐkₐa))]

@racket[(anf:eval kₐkₐa)] 不在尾位置：宿主在当前的帧里记着「拿到答案后调用 @racket[kₐa]」这件待办的工作。

@tech[#:key "延续传递风格"]{CPS} 把栈上的帧搬进了堆上的闭包，靠尾调用往前推。宿主的栈不必再替局部的工作留帧，空出来，正好用来定界：里面的工作由显式的@tech{延续}表示，外面的等待由宿主的帧记着。里面算完，普通地返回，交出答案；外面拿着答案接着算。这正是这一章开头那件事：调用一个函数时，调用者记下返回的地方，函数体执行，算完再回来。在 @racket[anf:reset] 里面用 @racket[cps:abort]，就是从这次调用 @tt{return}。

@xref["03:nested"]{「边界中的边界」}已经表明，被 @tt{return} 丢掉的那段工作是一个普通函数：调用它，就做完剩下的局部工作，正常返回结果。程序要是既能拿到这个函数，又能交出答案，就可以选择调用、保存，还是丢掉它。@racket[cps:call/lc] 拿到函数，@racket[cps:abort] 交出答案，两个接起来：

@examples[#:eval ev #:label #f #:no-prompt
(define-syntax-rule (anf:let/lc cps:k b* ...)
  (cps:call/lc (λ (cps:k) b* ...)))

(define-syntax-rule (anf:shift cps:k e)
  (anf:let/lc cps:k
    (anf:let* ([v e])
      (cps:abort v))))]

@defsym["anf:shift" "取得到 reset 为止的局部延续，再把主体的结果作为答案交出"]@racket[anf:shift] 最后把主体的结果 @racket[v] 交给 @racket[cps:abort]：和 @tt{return} 一样，丢掉剩下的局部工作，把 @racket[v] 作为这段局部计算的答案交出。不同的是，丢掉之前，@racket[anf:let/lc] 先把那段工作命名为 @racket[cps:k]，交给了主体。@racket[shift] 就是给@tech{局部延续}起了名字的 @tt{return}。

前面一直叫作@tech{局部延续}的东西，范围由 @racket[reset] 的边界限定，通常叫作@defterm[#:en "delimited continuation"]{定界延续}。@racket[reset] 和 @racket[shift] 是操作@tech{定界延续}的一组接口。

@racket[shift] 做了两件事，捕获与跳转，也可以只留一件。主体捕获了@tech{局部延续}，又把结果交回给它，跳转就被撤销了，只剩下捕获：@racket[(shift k (k e))] 就是 @racket[(let/lc k e)]。主体不理会捕获的@tech{局部延续}，只剩下跳转：@racket[(shift _ e)] 就是 @racket[(abort e)]。倒过来读这条等式，@tt{return} 就是丢掉了@tech{局部延续}的 @racket[shift]。

@racketblock[
(define-syntax-rule (let/lc k body) (shift k (k body)))
(define (abort . v*) (shift _ (apply values v*)))]

@section[#:tag "03:four-examples"]{四个例子}

先用 @racket[anf:reset] 和 @racket[cps:abort] 做一次普通的调用与返回。里面给 @racket[3] 加上 @racket[2]，把答案交出来；外面拿到结果，再加上 @racket[10]：

@examples[#:eval ev #:label #f
(anf:eval
 (anf:let* ([v (anf:reset
                (anf:let* ([x (cps:id 3)]
                           [y (cps:+ 2 x)])
                  (cps:abort y)))])
   (cps:+ 10 v)))]

@racket[(cps:abort y)] 把 @racket[5] 交给里面的@tech{局部终结延续}，结束这段计算。@racket[anf:reset] 取出答案，外面绑定 @racket[v] 为 @racket[5]，接着算 @racket[(+ 10 5)]，得到 @racket[15]。里面的返回没有丢掉外面的工作。

只改产生 @racket[x] 的那一处：用 @racket[anf:shift] 捕获@tech{局部延续}，但先不用它：

@examples[#:eval ev #:label #f
(anf:eval
 (anf:let* ([v (anf:reset
                (anf:let* ([x (anf:shift cps:k (cps:id 3))]
                           [y (cps:+ 2 x)])
                  (cps:abort y)))])
   (cps:+ 10 v)))]

走到 @racket[anf:shift] 时，边界以内还等着的工作是：收下 @racket[x]，算 @racket[(+ 2 x)]，再经 @racket[cps:abort] 交出答案。这就是 @racket[cps:k] 保存的@tech{局部延续}。外面的加十在 @racket[anf:reset] 之外，没有被捕获。

主体 @racket[(cps:id 3)] 不用 @racket[cps:k]，结果就是 @racket[3]。@racket[anf:shift] 把它作为里面这段计算的答案交出，原来的加二没有执行，外面得到 @racket[13]。这是一次提前 @tt{return}：@racket[cps:k] 绑定的，正是 @tt{return} 每次都丢掉的那段工作，只是这次没有谁用它。

要是把这个 @racket[3] 交给刚刚捕获的@tech{延续}呢？

@examples[#:eval ev #:label #f
(anf:eval
 (anf:let* ([v (anf:reset
                (anf:let* ([x (anf:shift cps:k (cps:k 3))]
                           [y (cps:+ 2 x)])
                  (cps:abort y)))])
   (cps:+ 10 v)))]

@racket[(cps:k 3)] 做完保存的工作，得到 @racket[5]。@racket[cps:k] 来自 @racket[cps:call/lc]，调用它时，@racket[⊥ᵃ->a] 包着一段局部计算，取出答案；所以里面的 @racket[cps:abort] 交出的 @racket[5]，正常返回到 @racket[anf:shift] 的主体。

主体的结果就是这个 @racket[5]，@racket[anf:shift] 再把它作为所在那段局部计算的答案交出。外面仍然得到 @racket[15]，和第一个例子一样。@racket[(shift k (k e))] 就是 @racket[(let/lc k e)]；@racket[e] 不用 @racket[k] 时，捕获也可以省去，所以第三个例子和第一个是同一段计算。

调用既然会返回，就可以拿着返回值接着算。把主体改成先调用一次，再把结果交给同一个 @racket[cps:k]：

@examples[#:eval ev #:label #f
(anf:eval
 (anf:let* ([v (anf:reset
                (anf:let* ([x (anf:shift cps:k
                               (anf:let* ([r (cps:k 3)])
                                 (cps:k r)))]
                           [y (cps:+ 2 x)])
                  (cps:abort y)))])
   (cps:+ 10 v)))]

第一次 @racket[(cps:k 3)] 算出 @racket[5]，返回后绑定给 @racket[r]；第二次 @racket[(cps:k r)] 拿 @racket[5] 再加一次二，返回 @racket[7]。每次调用都有自己的边界，里面的 @racket[cps:abort] 结束的是那一次调用里的局部工作，主体仍然可以接着算。

保存下来的始终是同一条@tech{局部延续}：第一次调用的结果，成了第二次调用的输入。两次加二做完，主体交出 @racket[7]，外面再加上 @racket[10]，得到 @racket[17]。外面的加十没有重复执行，它一直在 @racket[anf:reset] 之外，等着最后的答案。

同一段局部工作，在后三个例子里有三种命运：被丢掉，被调用一次，被调用两次。第一个例子没有 @racket[anf:shift]，那段工作照常执行，谈不上丢掉还是捕获。@racket[shift] 做的，就是把这个选择交给程序。

@section[#:tag "03:delimited-cps"]{定界延续与 CPS}

@racket[shift] 能把剩下的工作交给程序，可实现它的时候，没有借助宿主原生的捕获。四个例子共用同一段局部工作：收下 @racket[x]，加二，交出答案。化简以后，这段工作以什么样子出现，@racket[shift] 的主体又怎样和它对接？

第一、第三个例子是同一段计算。@racket[(shift k (k e))] 就是 @racket[(let/lc k e)]，@racket[e] 不用 @racket[k] 时，@racket[let/lc] 可以化简成 @racket[e]；@racket[e] 里没有控制操作时，@racket[(reset (abort e))] 就是 @racket[e]。照这两条化简第三个例子，写成直接风格的 @racket[let]：

@racketblock[
#,(hspace 2)(let ([v (reset
                (let* ([x (shift k (k 3))]
                       [y (+ 2 x)])
                  (abort y)))])
    (+ 10 v))
= (let ([v (let ([x 3]) (+ 2 x))])
    (+ 10 v))]

化简以后，是普通的 @tech[#:key "A-范式"]{ANF}。里面的 @racket[(let ([x 3]) (+ 2 x))] 脱糖就是 @racket[((λ (x) (+ 2 x)) 3)]，@racket[(λ (x) (+ 2 x))] 是等着 @racket[x] 的那段工作，也就是@tech{局部延续}。把它命名为 @racket[k]：

@racketblock[
#,(hspace 2)((λ (v) (+ 10 v))
   ((λ (k) (k 3))
    (λ (x) (+ 2 x))))
= ((λ (v) (+ 10 v)) (+ 2 3))
= 15]

拿到@tech{延续}立刻调用，就是普通的绑定：@racket[((λ (k) (k e)) (λ (v) body))] 与 @racket[(let ([v e]) body)] 行为一样。

第二个例子不碰 @racket[k]，@racket[shift] 就是 @tt{return}，跳过了加二。消去末尾的 @racket[abort]：

@racketblock[
(let ([v (reset
           (let ([x (abort 3)])
             (+ 2 x)))])
  (+ 10 v))]

丢掉当前的@tech{局部延续}，改把值交给@tech{局部终结延续} @racket[id]。@racket[(id 3)] 就是 @racket[3]，于是主体成了 @racket[(λ (_) 3)]：

@examples[#:eval ev #:label #f
((λ (v) (+ 10 v))
 ((λ (_) 3)
  (λ (x) (+ 2 x))))]

@racket[(λ (x) (+ 2 x))] 交进去了，主体却没有调用它。前三个例子到这里都是见过的东西：第一、第三个是不带控制操作的普通计算，第二个是替换@tech{延续}的提前返回。

把这两份 @tech[#:key "延续传递风格"]{CPS} 的主体，和 @racket[shift] 的主体放在一起。第一份用一次 @racket[k]，第二份不用：

@racketblock[
(shift k (k 3))     (code:comment "主体对应 (λ (k) (k 3))")
(shift _ 3)         (code:comment "主体对应 (λ (_) 3)")]

形状完全一样。@racket[shift] 让主体拿到@tech{局部延续}，@tech[#:key "延续传递风格"]{CPS} 把@tech{局部延续}作为参数交给主体；主体怎样用它，两种写法的结构相同。

第四个例子的 @racket[shift] 主体是 @racket[(k (k 3))]，在同一处又调用了一次 @racket[k]。照这个对应，@tech[#:key "延续传递风格"]{CPS} 的主体就是 @racket[(λ (k) (k (k 3)))]。消去末尾的 @racket[abort]：

@racketblock[
(let ([v (reset
           (let ([x (shift k (k (k 3)))])
             (+ 2 x)))])
  (+ 10 v))]

加二的@tech{延续}和外面的加十，都和前两份相同，只有主体不同：

@examples[#:eval ev #:label #f
((λ (v) (+ 10 v))
 ((λ (k) (k (k 3)))
  (λ (x) (+ 2 x))))]

前两种主体都把@tech{局部延续}当作最后一步来用：调用一次，交出控制，或者干脆不用。第四种不同：@racket[(k 3)] 不在尾位置，它返回以后，外面还有一次 @racket[(k …)] 等着用这个结果。同一条@tech{局部延续}被调用了两次，第一次不是为了交出控制，而是为了拿回一个值接着算。

这做得到，因为@tech{局部延续}是普通的函数。@racket[(k 3)] 加二以后正常返回 @racket[5]，等着它的 @racket[(k 5)] 接着得到 @racket[7]。调用者拿到结果以后要做的事，由宿主的调用帧记着；@xref["03:abort-shift"]{「从 return 到 shift」}说空出来的宿主栈正好用来定界，就是在这样的调用处。

三份 @tech[#:key "延续传递风格"]{CPS} 外面都一样，区别只在主体怎样用@tech{局部延续}。从 @tech[#:key "延续传递风格"]{CPS} 看，三种情形是一步步放宽限制。照前面的 @tech{CPS 变换}，没有控制操作时，必须在@italic{尾位置}用@italic{当前的}@tech{局部延续}，把每一步的结果交给它，而且@italic{恰好用一次}：@racket[(shift k (k e))] 就是 @racket[(let/lc k e)]，@racket[(let/lc _ e)] 就是 @racket[e]。能跳转，意味着可以@italic{换掉}@tech{局部延续}，第二个例子就是不用 @racket[k]，改用@tech{局部终结延续} @racket[id]：@racket[(id e)] 就是 @racket[e]，@racket[(shift _ e)] 就是 @racket[(abort e)]。@tech{定界延续}则@italic{去掉了位置与次数的限制}：@tech{局部延续}和普通函数一样，在哪里用、用几次都行。@racket[reset] 与 @racket[shift] 让 @tech[#:key "A-范式"]{ANF} 的程序也能拿到这些@tech{局部延续}，随意使用。

上面的 @tech[#:key "延续传递风格"]{CPS} 反复做两件事：@racket[v] 绑定计算的结果，@racket[k] 命名等着结果的工作。@racket[let] 给计算的结果起名，脱糖就是 @racket[λ] 的调用：

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list @elem{写法} @elem{代码})
   (list @tech[#:key "延续传递风格"]{CPS} @racket[((λ (v) body) exp)])
   (list @tech[#:key "A-范式"]{ANF} @racket[(let ([v exp]) body)]))]

被命名的也可以是等着结果的工作。普通的 @racket[let] 给这个函数起名，@racket[shift] 则在原来计算的位置拿到它。下面的 @racket[exp]、@racket[body] 指不再含别的控制操作的普通代码：

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list @elem{写法} @elem{代码})
   (list @tech[#:key "延续传递风格"]{CPS} @racket[((λ (k) exp) (λ (v) body))])
   (list @tech[#:key "A-范式"]{ANF} @racket[(let ([k (λ (v) body)]) exp)])
   (list @elem{@tech[#:key "A-范式"]{ANF} 加 @racket[reset]、@racket[shift]} @racket[(reset (let ([v (shift k exp)]) body))]))]

边界以内要是已经没有剩下的工作，收到什么就交出什么，这个函数就是恒等，也就是 @racket[id]：

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list @elem{写法} @elem{代码})
   (list @tech[#:key "延续传递风格"]{CPS} @racket[((λ (k) exp) (λ (v) v))])
   (list @tech[#:key "A-范式"]{ANF} @racket[(let ([k (λ (v) v)]) exp)])
   (list @elem{@tech[#:key "A-范式"]{ANF} 加 @racket[reset]、@racket[shift]} @racket[(reset (shift k exp))]))]

一段计算也可以既要输入的值，又要剩下的工作。把前两种绑定放在一起，@racket[v] 收计算的结果，@racket[k] 收剩下的工作：

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list @elem{写法} @elem{代码})
   (list @tech[#:key "延续传递风格"]{CPS} @racket[((λ (v k) body) exp (λ (w) body1))])
   (list @tech[#:key "A-范式"]{ANF} @racket[(let ([v exp] [k (λ (w) body1)]) body)])
   (list @elem{@tech[#:key "A-范式"]{ANF} 加 @racket[reset]、@racket[shift]} @racket[(reset (let ([w (let ([v exp]) (shift k body))]) body1))]))]

@section[#:tag "03:rules"]{规约规则}

前面的分析一直和 @tech[#:key "延续传递风格"]{CPS} 的实现绑在一起。脱开实现，只要两条@defterm[#:en "reduction rule"]{规约规则}：

@racketblock[
(reset val)
  => val
(reset E[(shift k expr)])
  => (reset (let ([k (λ (v) (reset E[v]))]) expr))]

@defsym["E[e]" "求值上下文 E 里，把 e 放进那个空位"]@racket[val] 是一个值；@racket[E] 是不跨过另一层 @racket[reset] 的@defterm[#:en "evaluation context"]{求值上下文}，@c{E[v]} 表示把值 @racket[v] 放回 @racket[shift] 所在的位置。第一条：边界以内已经是一个值，直接取出。

第二条是 @racket[shift] 的规约：把从 @racket[shift] 到 @racket[reset] 之间的上下文 @racket[E] 取出来，包成函数 @racket[(λ (v) (reset E[v]))] 绑定给 @racket[k]，再在边界以内执行 @racket[expr]。规则里有两个 @racket[reset]。

前面用 @racket[shift] 定义了 @racket[let/lc] 和 @racket[abort]；反过来，@racket[shift] 也能由这两个定义。和@xref["01:compare"]{「比较」}里的三种控制操作符一样，@racket[shift] 与 @racket[let/lc] 加 @racket[abort] 可以互相定义。@racket[shift] 是给@tech{局部延续}起了名字的 @tt{return}：用 @racket[let/lc] 给@tech{局部延续}起名，用 @racket[abort] 交出答案：

@racketblock[
(define-syntax-rule (let/lc k body ...)
  (call/lc (λ (k) body ...)))

(define-syntax-rule (shift k expr)
  (let/lc k (let ([v expr]) (abort v))))]

先算 @racket[expr] 得到 @racket[v]，再 @racket[(abort v)] 返回。@racket[expr] 在返回之前照常计算，仍在原来的 @racket[reset] 里面，所以规约式最外面还留着一层 @racket[reset]。

里面那层 @racket[reset] 藏在 @racket[k] 的定义里：@racket[(λ (v) (reset E[v]))]。@tech{平凡表示}下，@tech{局部延续}就是普通的函数，调用 @racket[k] 就是一次普通的函数调用。@tech[#:key "延续传递风格"]{CPS} 把局部的工作搬进堆上的闭包，空出来的宿主栈用来定界，调用 @racket[k] 时分配的新栈帧，就是一次新的定界。

@racket[k] 要是在某个 @racket[reset] 的尾位置调用，@racket[(reset (k v))] 展开是 @racket[(reset (reset E[v]))]，两层边界紧挨在一起。两层等于一层：@racket[(reset (reset e))] 与 @racket[(reset e)] 行为一样。用上面两条规则比较两边。@racket[e] 是值时，两边都规约成这个值。@racket[e] 执行 @racket[shift] 时，@racket[shift] 只取到最近的一层 @racket[reset]，两边取到的上下文 @racket[E] 相同：

@racketblock[
(reset (reset E[(shift k expr)]))
  => (reset (reset (let ([k (λ (v) (reset E[v]))]) expr)))
(reset E[(shift k expr)])
  => (reset (let ([k (λ (v) (reset E[v]))]) expr))]

@racket[k] 绑定的是同一个函数，规约之后两边仍然只差最外面一层 @racket[reset]。每一步都是这样，直到里面算出值，多出的那层也随第一条规则消失。

结构体表示下，同一层边界以另一种样子出现。@xref["03:nested"]{「边界中的边界」}里，@racket[cps:call/lc] 用 @racket[⊥ᵃ->a] 把捕获的@tech{局部延续}包了一层：调用时沿@tech{闭包链}做完局部的工作，在链底碰到 @racket[a->⊥ᵃ]，@racket[⊥ᵃ->a] 取出答案，和 @racket[anf:eval] 是同一个结构。@racket[⊥ᵃ->a] 出现在哪里，哪里就有一次定界。两种表示看到的是同一件事：把 @racket[v] 放回原来的上下文 @racket[E]，在一层新的边界里求值。

@racket[shift] 定义得出 @racket[let/lc] 和 @racket[abort]：一个只捕获，一个只跳转。@racket[cps:call/cc] 捕获的@tech{延续}会跳走，@racket[shift] 也定义得出 @racket[let/cc] 吗？
