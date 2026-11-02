#lang acf/scribble

@title[#:tag "03:4-meta"]{元延续}

要回答这个问题，先得看清：定界以后，当前@tech{延续}里都有什么。

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(require (only-in racket/control reset [shift primitive-shift]))
(define ∘ compose)
(define (abort . v*) (primitive-shift _ (apply values v*)))
(define (call/lc proc) (primitive-shift k (k (proc k))))
(define-syntax-rule (let/lc k body ...) (call/lc (λ (k) body ...)))
(define-syntax-rule (shift k expr) (let/lc k (let ([v expr]) (abort v))))
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

@section[#:tag "03:meta"]{元延续}

@tech{局部延续}只到 @racket[id] 为止，而 @racket[id] 收到什么就交出什么。整段局部工作做完，或者被 @racket[abort] 丢掉以后，交出来的值去了哪里？

@xref["03:abort-shift"]{「从 return 到 shift」}展开过 @racket[anf:reset]：@racket[(kₐa (anf:eval kₐkₐa))] 里，@racket[(anf:eval kₐkₐa)] 不在尾位置。执行它之前，Racket 在调用栈上记下了一件工作：拿到返回值，交给 @racket[kₐa]。边界以内，计算靠尾调用往前推，宿主栈不随局部的工作增长；边界本身却是一次非尾调用，@racket[anf:reset] 留下的等待帧记着外面的 @racket[kₐa]。里面算完，得到的 @racket[a] 普通地返回到这一帧，@racket[(kₐa a)] 开始执行。@xref["03:four-examples"]{「四个例子」}里外面的加十，就是这样等来的。

@defsym["ka" "元延续：边界外等着局部答案的工作，由宿主的调用栈记着"]于是边界以内任何一处剩下的工作，都分成两段：从这一处沿@tech{闭包链}到 @racket[id] 的@tech{局部延续}，和边界外面等着局部答案的工作。后一段由宿主的调用栈记着，叫作@defterm[#:en "meta-continuation"]{元延续}。正常执行时，值沿@tech{闭包链}经过每一步局部的工作，到达 @racket[id]，再普通地返回，交给@tech{元延续}。完整的@tech{延续}是两段的复合：

@mm{@tech{延续} = @tech{元延续} ∘ @tech{局部延续}}

@racket[abort] 和 @racket[let/lc] 恰好各管一段。@racket[abort] 把值送到边界外面，它就是当前的@tech{元延续}；@racket[let/lc] 拿到当前的@tech{局部延续} @racket[k]。把两段接起来，当前@tech{延续}就是 @racket[(∘ abort k)]：

@examples[#:eval ev #:label #f #:no-prompt
(define (call/cc proc)
  (let/lc k (proc (∘ abort k))))]

@examples[#:eval ev #:hidden
(define-syntax-rule (let/cc k body ...) (call/cc (λ (k) body ...)))]

留意，@racket[k] 是捕获时的@tech{局部延续}，可调用 @racket[abort]，调用的是调用时的@tech{元延续}，不是捕获时的那一条。把捕获和调用放进两个不同的 @racket[reset]，差别就显出来了：

@examples[#:eval ev #:label #f
(let ([k (reset
          (let ([x (let/cc k (abort k))])
            (+ x 2)))])
  (+ (reset (k 3)) 100))]

第一个 @racket[reset] 里，@racket[let/cc] 捕获当前的@tech{延续}，@racket[(abort k)] 把它作为答案交出来，它带着的局部工作是加二。第二个 @racket[reset] 里调用 @racket[(k 3)]。照上面的定义，这条@tech{延续}先把 @racket[3] 交给捕获时的@tech{局部延续}，做完加二，得到 @racket[5]，再把 @racket[5] 交给 @racket[abort]；@racket[abort] 用的是调用时的@tech{元延续}，把 @racket[5] 送出当前的边界，也就是第二个 @racket[reset]。边界外的加一百照常执行，得到 @racket[105]。

当然，捕获和调用时最近的边界若是同一次 @racket[reset] 划出来的，边界外等着的就是同一份工作，调用时的@tech{元延续}也就是捕获时的那一条。

上面比的是边界外面的工作。再看边界以内：@racket[let/cc] 交出的@tech{延续} @racket[(∘ abort k)]，比 @racket[let/lc] 捕获的 @racket[k] 多了一层 @racket[abort]。这条@tech{延续}要是在某个 @racket[reset] 的尾位置调用，调用结果外面没有局部的工作需要丢掉，外层的 @racket[reset] 就把这层 @racket[abort] 消去了：

@racketblock[
#,(hspace 2)(reset ((∘ abort k) v))
= (reset (abort (k v)))
= (reset (k v))
= (reset (reset E[v]))
= (reset E[v])]

后两步展开 @racket[k]：@racket[let/lc] 拿到的 @racket[k] 和 @racket[shift] 拿到的一样，是 @c{(λ (v) (reset E[v]))}；再用@xref["03:rules"]{「规约规则」}里两层边界等于一层的那条。在 @racket[reset] 的尾位置，跳转和普通的调用落到同一个地方：在这层边界里，把 @racket[v] 放回捕获时的上下文 @c{E}。

所以，@racket[let/cc] 捕获的@tech{延续}若只在 @racket[reset] 的尾位置调用，就可以改用 @racket[let/lc]，只捕获@tech{局部延续}。@xref["02:yin-yang"]{「阴阳谜题」}里，@racket[label] 写成了 @racket[(let/cc k k)]；谜题里的@tech{延续}恰好只在这样的尾位置调用。照@xref["01:rules"]{「读出规律」}的名字写谜题，把 @racket[let/cc] 换成 @racket[let/lc]：

@examples[#:eval ev #:label #f
(eval:alts
 (reset
  (let ([kn (let/lc k0 k0)])
    (displayln #\@)
    (let ([km (let/lc kn+1 kn+1)])
      (display #\*)
      (kn km))))
 (show-lines 5
  (λ ()
    (reset
     (let ([kn (let/lc k0 k0)])
       (displayln #\@)
       (let ([km (let/lc kn+1 kn+1)])
         (display #\*)
         (kn km)))))))]

输出不变。@racket[kn] 和 @racket[km] 仍是会正常返回的@tech{局部延续}，并没有跳转的能力；只是每次调用它们时，@racket[abort] 本来要丢掉的局部工作都是空的。两层边界等于一层，说的是行为：@racket[let/lc] 每调用一次，原来那层边界还留着，@racket[let/cc] 的 @racket[abort] 却会先把它丢掉。

@section[#:tag "03:stack-slice"]{栈的切片}

@xref["02:position"]{「计算的位置」}把@tech{延续}写成了@tech{闭包链}。相邻两处的@tech{延续}只差一步：@racket[(neg f)] 把后一处的 @racket[kq] 变成前一处的 @c{kp = kq ∘ f}。从出口那一条开始一步步接上去，每一处的@tech{延续}都是一个具体的值。

拿@xref["03:four-examples"]{「四个例子」}里 @racket[x] 那一处来看。把加二的 @racket[(λ (x) (+ 2 x))] 记作 @racket[add2]，加十的 @racket[(λ (v) (+ 10 v))] 记作 @racket[add10]，整个程序之后的@tech{延续}记作 @racket[k]。这一处的@tech{延续}是 @racket[(∘ k add10 add2)]：先加二，再加十，最后交给 @racket[k]。@racket[reset] 的边界落在加二与加十之间，沿着它把链切开：

@racketblock[
#,(hspace 2)(∘ k add10 add2)
= (∘ (∘ k add10) add2)]

右边一段 @racket[add2] 是边界以内的工作，@racket[shift] 在这里拿到的@tech{局部延续}就是它。左边一段 @racket[(∘ k add10)] 是边界外面等着答案的工作，也就是@tech{元延续}。

一般的情形也这样切。把局部计算的答案类型记作 @math{a}，@racket[kq] 沿边界分成两段：@tech{局部延续} @math{kₐq : q → a} 做边界以内的工作，交出答案；@tech{元延续} @math{ka : a → ⊥} 接过答案，做边界外面的工作。@math{ka} 在 𝒞 里写不出来，它就是宿主调用栈记着的那段工作。@math{kq = ka ∘ kₐq}，落到栈上，就是两段首尾相接。

把这个分解代入 @c{kp = kq ∘ f}：

@racketblock[
#,(hspace 2)kp
= (∘ kq f)
= (∘ (∘ ka kₐq) f)
= (∘ ka (∘ kₐq f))
= (∘ ka kₐp)]

@math{ka} 不变，新添的工作落在局部那一段。@math{kₐq ∘ f} 先做 @math{f}，再做原有的局部工作 @math{kₐq}，结果仍然到达共同的出口 @math{a}。等着 @math{p} 的新@tech{局部延续}，就是 @math{kₐp = kₐq ∘ f : p → a}。

不同位置的@tech{局部延续}等着不同的输入，却都以 @math{a} 为终点。@xref["03:local-k"]{「局部延续」}的@tech{换基}，落到栈上就是这样一刀：完整的@tech{延续}以 @math{⊥} 为@tech{基}，在边界处切开，边界以内的一段以 @math{a} 为@tech{基}，@tech{元延续} @math{ka} 再把它接回 @math{⊥}。每条 @math{kₐp} 都是 @math{¬ₐp = p → a} 的一个元素，这就是@defterm[#:en "local negation"]{局部否定}。

走到边界处，局部已经没有剩下的工作，收到答案原样交出，完整的剩余工作就是 @math{ka ∘ idₐ = ka}。这正是 @racket[id] 所在的位置。@tech{平凡表示}下 @math{⊥ᵃ = a}，@tech{局部终结延续} @racket[a->⊥ᵃ] 就是 @math{idₐ : a → a}，@math{¬ₐa} 的一个元素。@racket[anf:eval] 每次启动一段计算，都把它作为栈底交给里面，局部的链从这里一层层往前接，长出各处具体的@tech{延续}。

整个程序在操作系统眼里，也是这样的结构。操作系统交给程序一个空栈，@tech{终结延续}是 @racket[exit]，程序是一段交出 @racket[Byte] 类型答案的局部计算。@racket[id] 之于局部计算，就像 @racket[exit] 之于整个程序：标出这一层已经没有剩下的工作。

@tech{换基}落到栈上，是沿边界切的一刀。@xref["02:4-arrows"]{「两种箭头与命题」}里那些箭头，都建在以 @math{⊥} 为@tech{基}的否定上；@tech{基}换成 @math{a}，它们还成立吗？
