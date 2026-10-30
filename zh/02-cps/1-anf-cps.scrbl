#lang acf/scribble

@title[#:tag "02:1-anf-cps"]{从 ANF 到 CPS}

求值的每一步，都有一段余下的工作在等它的结果。这些工作平时藏在表达式的嵌套里，先把它们一段段找出来。

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define-type ⊥ (∪))
(define-type (¬ p) (→ p ⊥))
(define-type (¬¬ p) (¬ (¬ p)))]

@section[#:tag "02:anf"]{求值顺序与 ANF}

考虑两个常见的递归函数：

@examples[#:eval ev #:label #f #:no-prompt
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

@examples[#:eval ev #:label #f #:no-prompt
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

@racket[let*] 的每个绑定从上到下依次执行，中间不跳跃。@racket[fib] 中先算 @racket[(fib n-1)] 再算 @racket[(fib n-2)]，不再需要知道 Racket 的求值策略，代码本身就是策略的忠实记录。这种把所有中间计算命名、排成序列的形式叫作@defterm[#:en "A-Normal Form" #:abbr "ANF"]{A-范式}。

但 @racket[let] 不是什么新东西。它脱糖为 @racket[lambda] 调用：

@racketblock[
(let ([v e]) b)  =  ((λ (v) b) e)]

每个 @racket[let] 绑定都配着两样东西：一个待求值的表达式 @racket[e]，和一个等待结果的函数 @racket[(λ (v) b)]。后者接收 @racket[e] 的值，然后执行剩余的计算。这个「等待结果并执行剩余计算的函数」，就是@tech{延续}。求值的每一步，都能这样拆成两半：眼下要归约的那一小段叫@defterm[#:en "reducible expression" #:abbr "redex"]{可归约式}，围着它、等它结果的其余部分就是@tech{延续}。@racket[e] 还没算完时，@tech{可归约式}就在 @racket[e] 里面。

@racket[let] 的先后次序，也来自这次脱糖。调用 @racket[((λ (v) b) e)] 时，先算出实参 @racket[e]，再把结果绑定到形参 @racket[v]，最后算函数体 @racket[b]。所以 @racket[(let ([v e]) b)] 总是先算 @racket[e]，再算 @racket[b]。

最简单的情形，函数体只是把一个函数用在绑定的值上：

@racketblock[
#,(hspace 2)(let ([y (f x)])
    (g y))
= ((λ (y) (g y)) (f x))
= (g (f x))
= ((∘ g f) x)]

先算 @racket[(f x)]，再算 @racket[(g y)]，正是 @racket[f] 与 @racket[g] 的复合：绑定的先后，就是复合的先后。@racket[let] 比复合多做的一件事，是给中间结果起了名字。这里的 @racket[∘] 就是第一篇用过的 @racket[compose]，把几个函数接成一个，最右边的先算。

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
= ((@racket[λ] (y) ((∘ h g) y)) (f x))
= ((∘ (∘ h g) f) x)]

里层的 @racket[let] 算的是 @racket[((∘ h g) y)]，所以 @racket[y] 的@tech{延续}就是 @racket[(∘ h g)]：它包下了剩下的全部工作，先 @racket[g] 再 @racket[h]。外层再把它接在 @racket[f] 后面。每个绑定各藏着这样一个@tech{延续}。


@subsection[#:tag "02:laws"]{结合律与单位律}

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

换名的那一步什么也不做，收到什么就原样交出什么。这样的函数，@racket[∘] 自己就给得出来。@racket[(∘ g f)] 把两个函数接成一个；只给一个，@racket[(∘ f)] 就是 @racket[f] 本身；一个也不给，@racket[(∘)] 什么也没接上，收到什么就交出什么。把它记作 @racket[id]：

@examples[#:eval ev #:label #f #:no-prompt
(define ∘ compose)
(define id (∘))]

@racket[∘] 就是 Racket 的 @racket[compose]，@racket[id] 就是 Racket 的 @racket[values]。前面 @racket[let] 的两种换名写法，化成复合，多出来的正是 @racket[id]：

@racketblock[
(let ([y (f x)])   y)   =  ((∘ id f) x)  =  (f x)
(let ([y    x]) (f y))  =  ((∘ f id) x)  =  (f x)]

@racket[id] 接在哪一头都不改变什么：@racket[(∘ id f)] 和 @racket[(∘ f id)] 都等于 @racket[(∘ f)]，也就是 @racket[f]。这条性质叫@defterm[#:en "identity law"]{单位律}，@racket[id] 是 @racket[∘] 的单位元。

这就回答了前面的问题。@tech{结合律}说，@racket[let] 嵌在 @racket[b] 里还是 @racket[e] 里都一样；@tech{单位律}说，只换名的 @racket[let] 可有可无。写法尽可以不同，定下的是同一个计算顺序，行为也都一样。这两条是 @racket[∘] 的运算律。

@racket[∘] 写的顺序和算的顺序相反：@racket[(∘ h g f)] 里最右边的 @racket[f] 先算。@racket[let*] 却是照算的顺序，从上往下写。照算的顺序写的复合记作 @racket[⨾]，@racket[(⨾ f g h)] 先调用 @racket[f]，再调用 @racket[g]，最后调用 @racket[h]：

@racketblock[
#,(hspace 2)(let* ([y (f x)]
         [z (g y)])
    (h z))
= ((∘ h g f) x)
= ((⨾ f g h) x)]

从类型看，复合是把首尾相接的箭头拼成一支：@racket[(∘ g f)] 里，@racket[f] 从 @racket[p1] 到 @racket[p2]，@racket[g] 从 @racket[p2] 到 @racket[p3]，拼起来就是从 @racket[p1] 到 @racket[p3]。@racket[⨾] 也是拼接，只是参数的次序反了过来，拼的是反着写的箭头。把箭头反着写，结果在左边，参数在右边，记作 @racket[←]：@racket[(← q p)] 就是 @racket[(→ p q)]。用 @racket[→] 写出 @racket[∘] 接两支时的类型，用 @racket[←] 写出 @racket[⨾] 接两支时的类型，两行只差把 @racket[→] 换成 @racket[←]：

@examples[#:eval ev #:label #f #:no-prompt
(define-type (← q p) (→ p q))

(: ∘ (∀ (p1 p2 p3) (→ (→ p2 p3) (→ p1 p2) (→ p1 p3))))
(: ⨾ (∀ (p1 p2 p3) (→ (← p2 p3) (← p1 p2) (← p1 p3))))
(define (⨾ . f*) (apply ∘ (reverse f*)))]

读 @racket[⨾] 那一行：第一支 @racket[(← p2 p3)] 从 @racket[p3] 到 @racket[p2]，先算；第二支 @racket[(← p1 p2)] 从 @racket[p2] 到 @racket[p1]，后算；拼成从 @racket[p3] 到 @racket[p1]。@racket[⨾] 只是把参数顺序倒过来的 @racket[∘]，两条运算律原样继承下来，@racket[(⨾)] 也是 @racket[id]。


@section[#:tag "02:cps"]{延续与 CPS}

回头看开头的 @racket[let]。每个绑定都配着一个@tech{延续} @racket[(λ (v) b)]，只是 @racket[let] 的语法替我们藏好了；@tech[#:key "A-范式"]{ANF} 所做的，不过是让这种隐藏变得有规律。把@tech{延续}取出来，起个名字 @racket[k]，再把整段写回函数调用：

@racketblock[
#,(hspace 2)((λ (v) b) e)
= (let ([k (λ (v) b)]) (k e))
= ((λ (k) (k e)) (λ (v) b))]

最后一行里，@tech{延续}成了一个普通的参数：@racket[(λ (k) (k e))] 先等着@tech{延续}，拿到以后把 @racket[e] 的值交给它。@tech{延续}于是成了独立的值，可以传来传去、存储、反复调用。

那就让每个函数都额外接受这样一个参数 @racket[k]，代表「我算完之后该做什么」。函数不再把值返回给调用者，而是直接交给 @racket[k]。@racket[fact] 的 @tech[#:key "延续传递风格"]{CPS} 版本：

@examples[#:eval ev #:label #f #:no-prompt
(: fact/k (→ Natural (¬ Natural) ⊥))
(define (fact/k n k)
  (if (= n 0)
      (k 1)
      (fact/k (- n 1)
              (λ (v) (k (* n v))))))

(: fib/k (→ Natural (¬ Natural) ⊥))
(define (fib/k n k)
  (if (< n 2)
      (k n)
      (fib/k (- n 1)
             (λ (v)
               (fib/k (- n 2)
                      (λ (w)
                        (k (+ v w))))))))]

读一下类型：@racket[(→ Natural (¬ Natural) ⊥)]。接收一个自然数和一个@tech{延续} @math{¬@ty{Natural}}，返回 @math{⊥}。函数不再「返回」值：它把结果交给@tech{延续}，自己不再回来。

代码的形状变了。@racket[fact/k] 的递归调用 @racket[(fact/k (- n 1) (λ (v) ...))] 是整个 @racket[if] 分支的最后一个动作，后面没有任何待执行的表达式。@racket[fib/k] 也是：每个递归调用都处于尾位置。递归调用与对@tech{延续}的调用，都成了尾调用。

当@tech{延续}是显式参数时，「做完之后的事情」不再堆叠在调用栈上，而是编进了 @racket[k] 这个闭包里。@racket[fib/k] 递归时，@racket[(λ (v) (fib/k (- n 2) (λ (w) (k (+ v w)))))] 把「等算完第一个分支，再递归第二个分支，最后加起来交给 k」整个未来打包进了一个函数。

拿 @racket[(fact/k 3 k)] 跑一遍，看手里的@tech{延续}怎么变。把 @racket[(λ (v) (* 3 v))] 记作 @racket[mul3]，其余类推：

@racketblock[
(fact/k 3 k)                                    =  (fact/k 3 (∘ k               ))
= (fact/k 2 (λ (v) ((∘ k          ) (* 3 v))))  =  (fact/k 2 (∘ k mul3          ))
= (fact/k 1 (λ (v) ((∘ k mul3     ) (* 2 v))))  =  (fact/k 1 (∘ k mul3 mul2     ))
= (fact/k 0 (λ (v) ((∘ k mul3 mul2) (* 1 v))))  =  (fact/k 0 (∘ k mul3 mul2 mul1))
= ((∘ k mul3 mul2 mul1) 1)]

每递归一层，新的@tech{延续}就是在旧的前面复合一次乘法。递归到底，交给@tech{延续}的是 @racket[1]：先乘 1，再乘 2，再乘 3，得到的 @racket[6] 交给 @racket[k]。调用栈没有增长，增长的是 @racket[k] 前面这一串函数：它们是堆上的闭包，一环接一环，叫作@defterm[#:en "closure chain"]{闭包链}。@racket[k] 自己没有动过。

直接风格里也有不增长栈的写法：尾递归版本的 @racket[fact] 用一个累积器。

@examples[#:eval ev #:label #f #:no-prompt
(: fact (→ Natural Natural))
(define (fact n)
  (let loop ([n n] [acc 1])
    (if (= n 0)
        acc
        (loop (- n 1) (* n acc)))))]

把它也变换成 @tech[#:key "延续传递风格"]{CPS}：

@examples[#:eval ev #:label #f #:no-prompt
(: fact/k (→ Natural (¬ Natural) ⊥))
(define (fact/k n k)
  (let loop/k ([n n] [acc 1] [k k])
    (if (= n 0)
        (k acc)
        (loop/k (- n 1) (* n acc) k))))]

同样拿 @racket[(fact/k 3 k)] 跑一遍：

@racketblock[
#,(hspace 2)(fact/k 3 k)
= (loop/k 3 (*      ) k)
= (loop/k 2 (*     3) k)
= (loop/k 1 (*   2 3) k)
= (loop/k 0 (* 1 2 3) k)
= (k (* 1 2 3))]

循环体把 @racket[k] 原样传下去，不再包上新的闭包。尾递归之所以不消耗栈空间，正因为它不创建新的@tech{延续}：每一步复用同一个 @racket[k]。非尾递归版本里@tech{闭包链}的增长，对应着调用栈的增长。@tech[#:key "延续传递风格"]{CPS} 只是把这种增长从栈搬到了堆上。

@tech[#:key "A-范式"]{ANF} 命名中间值，让求值顺序显式；@tech[#:key "延续传递风格"]{CPS} 命名@tech{延续}，让@tech{延续}显式。

@subsection[#:tag "02:exit"]{终结延续}

@tech[#:key "延续传递风格"]{CPS} 函数需要一个@tech{延续}才能启动。启动时交进去什么？

许多语言有一个内置的@tech{延续}：@racket[exit]，类型为 @math{¬@ty{Byte}}。可以包装一下得到 @math{¬@ty{Natural}}：

@examples[#:eval ev #:label #f
(eval:alts (fact/k 5 (λ (ans) (displayln ans) (exit 0)))
           (void (fact/k 5 (λ (ans) (displayln ans)))))]

结果打印出来了，进程也随之终止。@racket[exit] 一调用，整段计算就到此为止。启动时交进去的这条@tech{延续}，就是前面那条@tech{闭包链}的终点：值走完整条链，最后抵达的是它，所以叫它@defterm[#:en "terminal continuation"]{终结延续}。可是用 @racket[exit] 做@tech{终结延续}，进程一结束，就没法拿着结果继续工作。

我们需要另一个类型为 @math{a → ⊥} 的函数：它不返回，也不杀死进程，而是把答案送到一个取得回来的地方。@racket[raise] 正合适：它不返回，handler 又能捕获它抛出的值。再用一个专门的 struct，把我们的答案和别的异常区分开：

@examples[#:eval ev #:label #f #:no-prompt
(struct (r) ans ([a* : (Listof r)]) #:type-name Ans)
(define (list->values v*) (apply values v*))

(: a->⊥ (∀ (a) (¬ a)))
(define (a->⊥ . a*) (raise (ans a*)))
(define-syntax-rule (⊥->a exp)
  (with-handlers ([ans? (∘ list->values ans-a*)]) exp))]

@racket[a->⊥] 把值包进 @racket[ans] struct 并抛出。@racket[⊥->a] 安装一个 handler 来捕获这个 struct 并提取内容，@racket[list->values] 把收到的列表拆回多个返回值。命名反映了类型层面的操作：@racket[a->⊥] 把值送入 @math{⊥}（抛出），@racket[⊥->a] 把值取回（捕获）。

@examples[#:eval ev #:label #f
(⊥->a (fact/k 5 a->⊥))
(⊥->a (fib/k 10 a->⊥))]

@tech[#:key "延续传递风格"]{CPS} 函数运行起来，@racket[a->⊥] 充当@tech{终结延续}，@tech{闭包链}接在它前面一环环长出来；@racket[⊥->a] 在外面接住答案。计算在 raise/handler 划出的边界内执行，结果穿过边界传出来。

@subsection[#:tag "02:first-class-control"]{一等控制}

@tech[#:key "延续传递风格"]{CPS} 真正的力量不在于尾递归，而在于@tech{延续}成了@bold{一等值}。@tech{延续}就是函数，可以存储、复制、丢弃，也可以改为调用另一个。@racket[call/cc] 靠在运行时捕获当前@tech{延续}，给了我们这种能力。在 @tech[#:key "延续传递风格"]{CPS} 里，当前@tech{延续}已经是一个显式的参数。

第一篇用 @racket[cc] 写过 @racket[mul]：遇到零就短路。在 @tech[#:key "延续传递风格"]{CPS} 里，@tech{延续}就是普通的函数参数，同样的短路可以直接写出来：

@examples[#:eval ev #:label #f #:no-prompt
(: mul (→ Real * Real))
(define (mul . r*)
  (: loop/k (→ (Listof Real) (→ Real ⊥) ⊥))
  (define (loop/k r* k)
    (if (null? r*)
        (k (*))
        (let ([r (car r*)])
          (if (zero? r)
              (a->⊥ r)
              (loop/k (cdr r*) (λ (v) (k (* v r))))))))
  (⊥->a (loop/k r* a->⊥)))]

外面的 @racket[⊥->a] 接住从 @racket[a->⊥] 出来的答案，所以 @racket[mul] 照常返回一个数：

@examples[#:eval ev #:label #f
(mul 1 2 3 4)
(mul 1 2 0 3 4)]

正常路径上，累积的乘积沿着 @racket[k] 交回去。遇到零时，跳过 @racket[k]，直接调用 @racket[a->⊥]。@racket[k] 代表「继续乘下去然后返回结果」的@tech{延续}；@racket[a->⊥] 代表「直接跳出整个循环，把值交给 handler」的@tech{延续}。选择调用哪一个，就是选择走哪条控制流。不需要 @racket[call/cc]。@tech{延续}是普通的函数，切换@tech{延续}是普通的函数调用。

但代价也很明显：程序员必须亲手编写每一个@tech{延续}，把 @racket[k] 穿过每一层调用。能否自动化 @tech[#:key "延续传递风格"]{CPS} 包装？
