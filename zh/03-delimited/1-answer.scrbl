#lang acf/scribble

@title[#:tag "03:1-answer"]{返回答案}

函数算出结果，交还给调用它的地方。这一步平时由语言替我们做好，先把它拆开来看。

@(define ev (make-acf-eval))

@section[#:tag "03:call"]{函数调用}

@xref["01:first-class"]{「一等标签」}里，用 @racket[goto] 和 @racket[label] 写过一个提前返回的 @racket[mul]：

@racketblock[
(define (mul . r*)
  (define first? #t)
  (define result (*))
  (define ret (label))
  (when first?
    (set! first? #f)
    (for ([r (in-list r*)])
      (when (zero? r)
        (set! result r)
        (goto ret))
      (set! result (* result r))))
  result)]

遇到零，@racket[(goto ret)] 回到 @racket[ret] 那一处。这时 @racket[first?] 已经是 @racket[#f]，循环不再执行，函数直接交出 @racket[result]，剩下的迭代都跳过了。@tech{标签} @racket[ret] 标出的，是函数交出结果的地方，也就是函数计算的边界；@racket[goto] 越过的，是边界以内还没做完的工作。

汇编里的函数调用，用的也是这两样东西：调用者存下一个返回地址，跳进函数体，算完再跳回来。大多数语言把它们藏在内建的 @tt{return} 后面。Racket 没有内建的 @tt{return}，这里假想有一个，用它改写 @racket[mul]：

@racketblock[
(define (mul . r*)
  (define result (*))
  (for ([r (in-list r*)])
    (when (zero? r) (return 0))
    (set! result (* result r)))
  (return result))]

@racket[(return 0)] 和 @racket[(set! result r)] 再 @racket[(goto ret)] 做的是同一件事：把一个值直接交给调用者，跳过函数体里当前位置之后的计算。

@section[#:tag "03:answer"]{返回答案}

@racket[goto] 版和 @tt{return} 版的 @racket[mul] 都借用了语言提供的跳转，一个用@tech{标签}，一个用内建的 @tt{return}，一步就把控制转到函数出口。不用任何跳转，遇到零时提前返回，还做得到吗？

先想清楚提前返回意味着什么。它意味着这段计算的答案提前出现了：遇到零的那一刻，最终结果已经定了，后面再怎么乘也改变不了零。答案既然已经在手上，剩下的每一层只需要做一件事：把它原样往上递，不再拿它参与计算。所以不需要跳转，只需要分辨：手里这个东西，是还在算的中间结果，还是已经定了的答案？

@margin-note{用结构体给一支打上@tech{标记}，见@xref["01:disjoint-struct"]{「为分支定义专门的结构」}。}

给答案打上@tech{标记}就分得开。用一个带类型参数的结构体：

@examples[#:eval ev #:label #f #:no-prompt
(struct (r) ans ([a : r]) #:type-name Ans)]

@defsym["ans" "给一段计算的答案打上标记的结构体，类型是 (Ans r)"]@racket[(Ans r)] 包着一个 @racket[r] 类型的答案。@xref["02:exit"]{「终结延续」}里的 @racket[ans] 装的是一个列表，为的是顺带兼容多值；这里只要一个答案，字段换成单值。裸的 @racket[0] 是中间结果，还能接着乘；@racket[(ans 0)] 说的是「这段计算的答案是零」，后面只需要把它交出去。有了这个@tech{标记}，@racket[mul] 可以完全不跳转：

@examples[#:eval ev #:label #f #:no-prompt
(: mul (→ Real * Real))
(define (mul . r*)
  (: real* (→ Real Real (∪ Real (Ans Real))))
  (define (real* a b)
    (if (or (zero? a) (zero? b))
        (ans 0)
        (* a b)))
  (: loop (→ (Listof Real) (∪ Real (Ans Real)) (Ans Real)))
  (define (loop r* result)
    (cond
      [(ans? result) result]
      [(null? r*) (ans result)]
      [else (loop (cdr r*) (real* (car r*) result))]))
  (ans-a (loop r* (*))))]

这一版里没有 @racket[raise]，也没有任何跳转。先试一组不含零的输入，再试一组含零的：

@examples[#:eval ev #:label #f
(mul 1 2 3 4)
(mul 1 2 0 3 4)]

看 @racket[loop] 的三条分支：拿到 @racket[ans] 就原样交出；列表空了，就把累积的结果包成 @racket[ans]；否则接着乘。三条路最后交出的都是 @racket[(Ans Real)]。

@section[#:tag "03:two-sides"]{边界的两侧}

@racket[ans] 出现在两处：@racket[real*] 遇到零，提前知道了答案；@racket[loop] 走完列表，处理完了所有元素。两条路都把最终结果包成 @racket[ans]，交给最外面的 @racket[ans-a]。看 @racket[mul] 的最后一行：

@racketblock[
(ans-a (loop r* (*)))]

@racket[ans-a] 圈出了一段局部计算：括号里是 @racket[loop] 的整段迭代，以一个 @racket[(Ans Real)] 收场。@racket[loop] 收到答案只是原样交出，不拆开，也不用里面的值。到了边界外面，@racket[ans-a] 才取出那个实数，交给调用者接着算。

@defsym["Pᵃ" "普通结果 P 之外，再留一支给答案 a：(∪ P (Ans a))"]@racket[real*] 的结果类型 @racket[(∪ Real (Ans Real))] 把两条路放在了一起：普通的实数还能接着乘，打了@tech{标记}的答案直接交出。普通结果的类型记作 @racket[P]，整段计算的答案类型记作 @racket[a]，这两条路就写成 @racket[(∪ P (Ans a))]，缩写为 @math{Pᵃ}：上标 @math{a} 表示给这段计算的答案留了一条路。在 @racket[mul] 里，普通结果和答案都是实数，@racket[(∪ Real (Ans Real))] 就记作 @math{@ty{Real}ᵃ}。

要是 @racket[P] 是 @math{⊥} 呢？普通结果那一支没有元素，联合里只剩答案：

@mm{⊥ᵃ = ⊥ ∪ @ty{Ans} a = @ty{Ans} a}

@tech{空类型}是联合的单位元，@xref["01:types-to-logic"]{「析取与合取」}里，它也是析取的单位元。给它添上答案这一支，得到的正是答案的类型；在眼前的 @racket[mul] 里，@math{⊥ᵃ} 就是 @racket[(Ans Real)]。

@defsym["⊥ᵃ" "局部空：一段局部计算的答案类型；从内部看是空，从外部看是答案"]这个名字也对得上 @racket[loop] 的行为。收到 @racket[ans] 以后，它不再调用 @racket[real*]，不再乘，只把答案交出去。对这段局部计算来说，得出答案和结束是同一件事。答案不会再作为普通结果参与里面的运算，@math{⊥ᵃ} 因此充当@defterm[#:en "local bottom"]{局部空}；到了边界外面，@racket[ans-a] 却能从中取出一个普通的实数，交给调用者接着用。从内部看到的@tech{局部空}，从外部看就是@defterm[#:en "local answer"]{局部答案}。

整个程序的 @math{⊥} 也是这样一个答案。@xref["01:program-type"]{「代入 Byte」}里，程序是一个 @math{¬¬@ty{Byte}}，由操作系统交来 @racket[exit]。进程终止时交出一个 @racket[Byte] 类型的退出码：从进程内部看，@racket[exit] 之后再也没有运算能拿着退出码接着算；从操作系统看，退出码是一个普通的字节，操作系统拿着它接着工作。@racket[exit] 之于进程，就像 @racket[ans] 之于 @racket[loop]。

@defsym["⊥ᵃ?" "判断一个值是不是局部答案，这里就是 ans?"]@defsym["a->⊥ᵃ" "把值送进局部空，成为局部答案"]@defsym["⊥ᵃ->a" "在边界外从局部空里取出答案"]给这段局部计算的答案和边界上的两个操作起名，照 @racket[a->⊥]、@racket[⊥->a] 的样子：

@examples[#:eval ev #:label #f #:no-prompt
(define-type ⊥ᵃ (Ans Real))
(define ⊥ᵃ?   ans?)
(define a->⊥ᵃ ans)
(define ⊥ᵃ->a ans-a)]

@racket[a->⊥ᵃ] 就是 @racket[ans]，@racket[⊥ᵃ->a] 就是 @racket[ans-a]。一个把值送进这段局部计算的空，一个从空里取出答案。这一对操作划出的边界，叫作@defterm[#:en "prompt"]{界桩}。用这组名字重写 @racket[mul]，函数体不变：

@racketblock[
(define-type Realᵃ (∪ Real ⊥ᵃ))

(: mul (→ Real * Real))
(define (mul . r*)
  (: real* (→ Real Real Realᵃ))
  (define (real* a b) ...)
  (: loop (→ (Listof Real) Realᵃ ⊥ᵃ))
  (define (loop r* result) ...)
  (⊥ᵃ->a (loop r* (*))))]

在能跳转的语言里，@racket[real*] 的结果类型 @racket[Real] 其实是 @racket[(∪ Real ⊥)]：@math{⊥} 那一支留给跳转，由 @tt{return} 越过边界。@xref["02:exit"]{「终结延续」}的 @racket[a->⊥] 用 @racket[raise] 一步越过所有中间层，@racket[⊥->a] 用 handler 接住。拿掉 @racket[raise] 和 handler，只剩 @racket[ans] 这个结构体，每一层就只能自己检查、自己往上递。全局的 @math{⊥} 换成了局部的 @math{⊥ᵃ}，中间层也可能提前拿到答案，多出一条分支，中间层的结果类型 @racket[Real] 于是成了 @math{@ty{Real}ᵃ}。

@racket[loop] 里那个 @racket[(ans? result)]，也就是 @racket[(⊥ᵃ? result)]，和 @racket[mul] 要算的乘法毫无关系，纯粹是程序员额外操心的事。@xref["01:cc"]{「从标签到延续：cc 操作符」}里的 @racket[cc] 有过同样的问题：交出来的可能是值，也可能是@tech{延续}，调用者得自己分支；@xref["01:call-cc"]{「消除分支：call/cc」}把这个分支藏进了操作符内部。这里的 @racket[(⊥ᵃ? result)]，能不能也藏起来？
