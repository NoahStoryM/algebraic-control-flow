#lang acf/scribble

@title[#:tag "02:1-anf-cps"]{求值顺序}

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define-type ⊥ (∪))
(define-type (¬ p ...) (→ p ... ⊥))
(define-type (¬¬ p) (¬ (¬ p)))]

考虑两个常见的递归函数：

@examples[#:eval ev #:no-result
(: fact (→ Natural Natural))
(define (fact n)
  (if (= n 0)
      1
      (* n (fact (- n 1)))))

(: fib (→ Natural Natural))
(define (fib n)
  (if (< n 2)
      n
      (+ (fib (- n 1))
         (fib (- n 2)))))]

@racket[(* n (fact (- n 1)))] 中，哪个先求值？@racket[(- n 1)] 要先算，因为 @racket[fact] 需要它的结果；@racket[fact] 的返回值又要在 @racket[*] 之前就绪。但这些依赖关系藏在表达式的嵌套结构里，要盯着括号才能看出来。@racket[fib] 更微妙：@racket[(+ (fib (- n 1)) (fib (- n 2)))] 的两个 @racket[fib] 调用之间有没有固定顺序？在 Racket 中有（从左到右），但仅凭表达式本身看不出来。

能不能让求值顺序变得显式？

把每个中间结果绑定到一个名字上，让 @racket[let*] 链条记录执行的步骤：

@examples[#:eval ev #:no-result
(: fact (→ Natural Natural))
(define (fact n)
  (if (= n 0) 1
      (let* ([n-1 (- n 1)]
             [v   (fact n-1)])
        (* n v))))

(: fib (→ Natural Natural))
(define (fib n)
  (if (< n 2) n
      (let* ([n-1 (- n 1)]
             [v   (fib n-1)]
             [n-2 (- n 2)]
             [w   (fib n-2)])
        (+ v w))))]

@racket[let*] 的每个绑定从上到下依次执行，中间不跳跃。@racket[fib] 中先算 @racket[(fib n-1)] 再算 @racket[(fib n-2)]，不再需要知道 Racket 的求值策略，代码本身就是策略的忠实记录。这种把所有中间计算命名、排成序列的形式叫作@defterm[#:en "A-Normal Form" #:abbr "ANF"]{A-范式}。@racket[if] 本身已经定下先算测试、再算一支分支；这里只展开了递归调用周围的步骤，测试照旧写在原处，完整的 @tech[#:key "A-范式"]{ANF} 连它也要命名。

但 @racket[let] 不是什么新东西。它脱糖为 @racket[lambda] 调用：

@racketblock[
(let ([v e]) b)  =  ((λ (v) b) e)]

每个 @racket[let] 绑定都配着两样东西：一个待求值的表达式 @racket[e]，和一个等待结果的函数 @racket[(λ (v) b)]。后者接收 @racket[e] 的值，然后执行剩余的计算。这个「等待结果并执行剩余计算的函数」，就是@tech{延续}。求值的每一步，都能这样拆成两半：眼下要归约的那一小段叫@defterm[#:en "reducible expression" #:abbr "redex"]{可归约式}，围着它、等它结果的其余部分就是@tech{延续}。@racket[e] 若还要分几步算，@tech{可归约式}就在 @racket[e] 里面。

@racket[let] 的先后次序，也来自这次脱糖。调用 @racket[((λ (v) b) e)] 时，先算出实参 @racket[e]，再把结果绑定到形参 @racket[v]，最后算函数体 @racket[b]。所以 @racket[(let ([v e]) b)] 总是先算 @racket[e]，再算 @racket[b]。

最简单的情形，函数体只是把一个函数用在绑定的值上：

@racketblock[
#,(hspace 2)(let ([y (f x)])
    (g y))
= ((λ (y) (g y)) (f x))
= (g (f x))
= ((∘ g f) x)]

先算 @racket[(f x)]，再算 @racket[(g y)]，正是 @racket[f] 与 @racket[g] 的复合：绑定的先后，就是复合的先后。@racket[let] 比复合多做的一件事，是给中间结果起了名字。这里的@defsym["g ∘ f" "复合：先 f 后 g，即 compose"] @racket[∘] 就是 @racket[compose]，把几个函数接成一个，最右边的先算。

@margin-note{后一步若用到前面不止一个名字，比如 @racket[fib] 最后的 @racket[(+ v w)]，就不只是一串函数首尾相接了：@racket[v] 得一路带到最后。这里只看每一步只用到上一步结果的情形。}

上面 @racket[fact]、@racket[fib] 用的是 @racket[let*]。@racket[let*] 是嵌套的 @racket[let]：后一个绑定连同它后面的全部代码，是前一个 @racket[let] 的函数体。三步计算 @racket[f]、@racket[g]、@racket[h]，照 @racket[let*] 写，再拆成 @racket[let]：

@racketblock[
#,(hspace 2)(let* ([y (f x)]
         [z (g y)])
    (h z))
= (let ([y (f x)])
    (let ([z (g y)])
      (h z)))
= (let ([y (f x)])
    ((∘ h g) y))
= ((λ (y) ((∘ h g) y)) (f x))
= ((∘ (∘ h g) f) x)]

里层的 @racket[let] 算的是 @racket[((∘ h g) y)]，所以 @racket[y] 的@tech{延续}就是 @racket[(∘ h g)]：它包下了剩下的全部工作，先 @racket[g] 再 @racket[h]。外层再把它接在 @racket[f] 后面。每个绑定各藏着这样一个@tech{延续}。


@section[#:tag "02:laws"]{结合律与单位律}

把计算写成 @racket[let]，写法并不唯一。@racket[fact]、@racket[fib] 把每个新的 @racket[let] 嵌在前一个 @racket[let] 的函数体 @racket[b] 里；可 @racket[let] 里还有一处能放表达式，就是被求值的 @racket[e]：同样几步，也可以先接成一段，嵌进 @racket[e]。中间还可以插一个只给值换名的 @racket[let]。@tech[#:key "A-范式"]{ANF} 本来是要把计算顺序写死的，写法一多，定下的还是同一个顺序吗？

先看嵌进 @racket[e]。同样三步，把前两步写成一段，嵌进第三步的 @racket[e]：

@racketblock[
#,(hspace 2)(let ([z (let ([y (f x)])
             (g y))])
    (h z))
= (h ((∘ g f) x))
= ((∘ h (∘ g f)) x)]

这回先把 @racket[f]、@racket[g] 接成一段，再接上 @racket[h]。

两种写法都是先算 @racket[(f x)]，再算 @racket[(g y)]，最后算 @racket[(h z)]，结果也一样。嵌在 @racket[b] 里还是嵌进 @racket[e] 里，只是同一个复合的两种分组：

@racketblock[
(∘ (∘ h g) f)  =  (∘ h (∘ g f))]

先接哪两个都一样，这条性质叫@defterm[#:en "associativity"]{结合律}。正因为分组无关紧要，三个函数可以不加括号，直接写成 @racket[(∘ h g f)]。两种写法互改时要留意名字：嵌在 @racket[b] 里，@racket[y] 对 @racket[(h z)] 也看得见；嵌进 @racket[e] 里，就看不见了。

再看只换名的 @racket[let]。@racket[let] 定下计算顺序，靠的是先算 @racket[e]、后算 @racket[b]。@racket[(let ([y x]) (f y))] 把 @racket[x] 改叫 @racket[y] 再交给 @racket[f]，@racket[(let ([y (f x)]) y)] 给 @racket[f] 的结果起名 @racket[y] 再原样交出。两种写法里都只有 @racket[f] 一步计算，没有先后可分，和直接写 @racket[(f x)] 行为一样。

@defsym["id" "恒等函数，(∘) 也就是 values"]换名的那一步什么也不做，收到什么就原样交出什么。这样的函数，@racket[∘] 自己就给得出来。@racket[(∘ g f)] 把两个函数接成一个；只给一个，@racket[(∘ f)] 就是 @racket[f] 本身；一个也不给，@racket[(∘)] 什么也没接上，收到什么就交出什么。把它记作 @racket[id]：

@examples[#:eval ev #:no-result
(define ∘ compose)
(define id (∘))]

@racket[∘] 就是 Racket 的 @racket[compose]，@racket[id] 就是 Racket 的 @racket[values]。前面 @racket[let] 的两种换名写法，化成复合，多出来的正是 @racket[id]：

@racketblock[
(let ([y (f x)])   y)   =  (let ([y (f x)]) (id y))  =  ((∘ id f) x)  =  (f x)
(let ([y    x]) (f y))  =  (let ([y (id x)]) (f y))  =  ((∘ f id) x)  =  (f x)]

@racket[id] 接在哪一头都不改变什么：@racket[(∘ id f)] 和 @racket[(∘ f id)] 都等于 @racket[(∘ f)]，也就是 @racket[f]。这条性质叫@defterm[#:en "identity law"]{单位律}，@racket[id] 是 @racket[∘] 的单位元。

这就回答了前面的问题，至少对这里比较的这种一步只用上一步结果的复合：@tech{结合律}说，@racket[let] 嵌在 @racket[b] 里还是 @racket[e] 里都一样；@tech{单位律}说，只换名的 @racket[let] 可有可无。写法尽可以不同，定下的是同一个计算顺序，行为也都一样。这两条是 @racket[∘] 的运算律。

@racket[∘] 写的顺序和算的顺序相反：@racket[(∘ h g f)] 里最右边的 @racket[f] 先算。@racket[let*] 却是照算的顺序，从上往下写。照算的顺序写的复合记作@defsym["f ⨾ g" "反向复合：先 f 后 g，与 let* 的次序一致"] @racket[⨾]，@racket[(⨾ f g h)] 先调用 @racket[f]，再调用 @racket[g]，最后调用 @racket[h]：

@racketblock[
#,(hspace 2)(let* ([y (f x)]
         [z (g y)])
    (h z))
= ((∘ h g f) x)
= ((⨾ f g h) x)]

从类型看，复合是把首尾相接的箭头拼成一支：@racket[(∘ g f)] 里，@racket[f] 从 @racket[p1] 到 @racket[p2]，@racket[g] 从 @racket[p2] 到 @racket[p3]，拼起来就是从 @racket[p1] 到 @racket[p3]。@racket[⨾] 也是拼接，只是参数的次序反了过来，拼的是反着写的箭头。把箭头反着写，结果在左边，参数在右边，记作@defsym["q ← p" "反向箭头：从 p 到 q 的函数，结果写在左边"] @racket[←]：@racket[(← q p)] 就是 @racket[(→ p q)]。用 @racket[→] 写出 @racket[∘] 接两支时的类型，用 @racket[←] 写出 @racket[⨾] 接两支时的类型：

@examples[#:eval ev #:no-result
(define-type (← q p) (→ p q))

(: ∘ (∀ (p1 p2 p3) (→ (→ p2 p3) (→ p1 p2) (→ p1 p3))))
(: ⨾ (∀ (p3 p2 p1) (→ (← p2 p1) (← p3 p2) (← p3 p1))))
(define (⨾ . f*) (apply ∘ (reverse f*)))]

读 @racket[⨾] 那一行：第一支 @racket[(← p2 p1)] 从 @racket[p1] 到 @racket[p2]，先算；第二支 @racket[(← p3 p2)] 从 @racket[p2] 到 @racket[p3]，后算；拼成从 @racket[p1] 到 @racket[p3]。@racket[∘] 那一行的参数从右往左看，@racket[⨾] 那一行从左往右看，先算的都是从 @racket[p1] 出发的那一支。@racket[⨾] 只是把参数顺序倒过来的 @racket[∘]：反的是书写的次序，算的次序不变。两条运算律原样继承下来，@racket[(⨾)] 也是 @racket[id]。
