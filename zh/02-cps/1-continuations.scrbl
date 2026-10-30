#lang acf/scribble

@title[#:tag "02:1-continuations"]{从 ANF 到 CPS}

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

但 @racket[let] 不是什么新东西。它脱糖为 lambda 调用：

@racketblock[
(let ([v e]) b)  =  ((λ (v) b) e)]

每个 @racket[let] 绑定都配着两样东西：一个待求值的表达式 @racket[e]，和一个等待结果的函数 @racket[(λ (v) b)]。后者接收 @racket[e] 的值，然后执行剩余的计算。这个「等待结果并执行剩余计算的函数」，就是@tech{延续}。求值的每一步，都能这样拆成两半：眼下要归约的那一小段叫@defterm[#:en "reducible expression" #:abbr "redex"]{可归约式}，围着它、等它结果的其余部分就是@tech{延续}。@racket[e] 还没算完时，@tech{可归约式}就在 @racket[e] 里面。

@racket[let] 的先后次序，也来自这次脱糖。调用 @racket[((λ (v) b) e)] 时，先算出实参 @racket[e]，再把结果绑定到形参 @racket[v]，最后算函数体 @racket[b]。所以 @racket[(let ([v e]) b)] 总是先算 @racket[e]，再算 @racket[b]。

最简单的情形，函数体只是把一个函数用在绑定的值上：

@racketblock[
  (let ([y (f x)])
    (g y))
= ((λ (y) (g y)) (f x))
= (g (f x))
= ((∘ g f) x)]

先算 @racket[(f x)]，再算 @racket[(g y)]，正是 @racket[f] 与 @racket[g] 的复合：绑定的先后，就是复合的先后。@racket[let] 比复合多做的一件事，是给中间结果起了名字。这里的 @racket[∘] 就是第一篇用过的 @racket[compose]，把几个函数接成一个，最右边的先算。

@margin-note{后一步若用到前面不止一个名字，比如 @racket[fib] 最后的 @racket[(+ v w)]，就不只是一串函数首尾相接了：@racket[v] 得一路带到最后。这里只看每一步只用到上一步结果的情形。}

上面 @racket[fact]、@racket[fib] 用的是 @racket[let*]。@racket[let*] 是嵌套的 @racket[let]：后一个绑定连同它后面的全部代码，是前一个 @racket[let] 的函数体。三步计算 @racket[f]、@racket[g]、@racket[h]，照 @racket[let*] 写，再拆成 @racket[let]：

@racketblock[
  (let* ([y (f x)]
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


@subsection[#:tag "02:laws"]{结合律与单位律}

把计算写成 @racket[let]，写法并不唯一。@racket[fact]、@racket[fib] 把每个新的 @racket[let] 嵌在前一个 @racket[let] 的函数体 @racket[b] 里；可 @racket[let] 里还有一处能放表达式，就是被求值的 @racket[e]：同样几步，也可以先接成一段，嵌进 @racket[e]。中间还可以插一个只给值换名的 @racket[let]。ANF 本来是要把计算顺序写死的，写法一多，定下的还是同一个顺序吗？

先看嵌进 @racket[e]。同样三步，把前两步写成一段，嵌进第三步的 @racket[e]：

@racketblock[
  (let ([z (let ([y (f x)])
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
  (let* ([y (f x)]
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

回头看开头的 @racket[let]。每个绑定都配着一个@tech{延续} @racket[(λ (v) b)]，只是 @racket[let] 的语法替我们藏好了；ANF 所做的，不过是让这种隐藏变得有规律。把@tech{延续}取出来，起个名字 @racket[k]，再把整段写回函数调用：

@racketblock[
  ((λ (v) b) e)
= (let ([k (λ (v) b)]) (k e))
= ((λ (k) (k e)) (λ (v) b))]

最后一行里，@tech{延续}成了一个普通的参数：@racket[(λ (k) (k e))] 先等着@tech{延续}，拿到以后把 @racket[e] 的值交给它。@tech{延续}于是成了独立的值，可以传来传去、存储、反复调用。

那就让每个函数都额外接受这样一个参数 @racket[k]，代表「我算完之后该做什么」。函数不再把值返回给调用者，而是直接交给 @racket[k]。@racket[fact] 的 CPS 版本：

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
  (fact/k 3 k)                                  =  (fact/k 3 (∘ k               ))
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

把它也变换成 CPS：

@examples[#:eval ev #:label #f #:no-prompt
(: fact/k (→ Natural (¬ Natural) ⊥))
(define (fact/k n k)
  (let loop/k ([n n] [acc 1] [k k])
    (if (= n 0)
        (k acc)
        (loop/k (- n 1) (* n acc) k))))]

同样拿 @racket[(fact/k 3 k)] 跑一遍：

@racketblock[
  (fact/k 3 k)
= (loop/k 3 (*      ) k)
= (loop/k 2 (*     3) k)
= (loop/k 1 (*   2 3) k)
= (loop/k 0 (* 1 2 3) k)
= (k (* 1 2 3))]

循环体把 @racket[k] 原样传下去，不再包上新的闭包。尾递归之所以不消耗栈空间，正因为它不创建新的@tech{延续}：每一步复用同一个 @racket[k]。非尾递归版本里@tech{闭包链}的增长，对应着调用栈的增长。CPS 只是把这种增长从栈搬到了堆上。

ANF 命名中间值，让求值顺序显式；CPS 命名@tech{延续}，让@tech{延续}显式。

@subsection[#:tag "02:exit"]{终结延续}

CPS 函数需要一个@tech{延续}才能启动。启动时交进去什么？

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

CPS 函数运行起来，@racket[a->⊥] 充当@tech{终结延续}，@tech{闭包链}接在它前面一环环长出来；@racket[⊥->a] 在外面接住答案。计算在 raise/handler 划出的边界内执行，结果穿过边界传出来。

@subsection[#:tag "02:first-class-control"]{一等控制}

CPS 真正的力量不在于尾递归，而在于@tech{延续}成了@bold{一等值}。@tech{延续}就是函数，可以存储、复制、丢弃，也可以改为调用另一个。@racket[call/cc] 靠在运行时捕获当前@tech{延续}，给了我们这种能力。在 CPS 里，当前@tech{延续}已经是一个显式的参数。

第一篇用 @racket[cc] 写过 @racket[mul]：遇到零就短路。在 CPS 里，@tech{延续}就是普通的函数参数，同样的短路可以直接写出来：

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

但代价也很明显：程序员必须亲手编写每一个@tech{延续}，把 @racket[k] 穿过每一层调用。能否自动化 CPS 包装？


@section[#:tag "02:split-k"]{把延续独立出来}

给一个具体的函数写 CPS 包装，并不难。@racket[zero?] 的 CPS 版本：

@examples[#:eval ev #:label #f #:no-prompt
(define (zero?/k x k) (k (zero? x)))]

@racket[zero?/k] 在 @racket[zero?] 的结果外面套一层 @racket[k] 调用，就完成了包装。可这层包装，每个函数都得手写一遍。要自动化，就要一个通用的包装：交给它任意函数 @racket[f]，交回 @racket[f] 的 CPS 版本。

@racket[zero?/k] 的两个参数是两种东西：@racket[x] 交给 @racket[zero?] 去算，@racket[k] 只等着接住结果。通用的包装要把这两种参数分开处理，前一种原样交给 @racket[f]，后一种接住 @racket[f] 的结果。挤在同一层参数表里，它们就得一次交齐。柯里化让@tech{延续}独占一层，和其余参数分开。@tech{延续}独立在内层还是外层，操作上没有区别，函数体都一样：

@examples[#:eval ev #:label #f #:no-prompt
(define (((cps f) . p*) kq) (kq (apply f p*)))  (code:comment "延续在后")
(define (((neg f) kq) . p*) (kq (apply f p*)))  (code:comment "延续在前")]

这样的函数头是嵌套 λ 的简写：@racket[(define (((cps f) . p*) kq) body)] 就是 @racket[(define (cps f) (λ p* (λ (kq) body)))]，一层括号收一层参数，@tt{. p*} 把其余参数收成列表，原样交给 @racket[f]，不管 @racket[f] 收几个参数。

拿 @racket[+] 各走一遍。@racket[(cps +)] 先收操作数 @racket[1]、@racket[2]，交出一个等着@tech{延续}的值；再交给它一个@tech{延续}，计算才开始。@racket[(neg +)] 次序反过来，先收@tech{延续}，再收操作数：

@examples[#:eval ev #:label #f
(⊥->a (((cps +) 1 2) (λ (v) (a->⊥ (* v 10)))))
(⊥->a (((neg +) (λ (v) (a->⊥ (* v 10)))) 1 2))]

操作上一样，类型却不同：

@examples[#:eval ev #:label #f #:no-prompt
(: cps (∀ (p q) (→ (→ p q) (→    p (¬¬ q)))))
(: neg (∀ (p q) (→ (→ p q) (← (¬ p) (¬ q)))))]

@racket[(cps f)] 先收操作数，交出的 @math{¬¬q} 是一段还没开始的计算：@racket[((cps +) 1 2)] 就是还没开始的 @racket[(+ 1 2)]。第一篇里，这样的值有类型：程序就是一个 @math{¬¬@ty{Byte}}，等操作系统交来 @racket[exit] 才运行。

@racket[(neg f)] 先收@tech{延续}：交给它一条等 @math{q} 的@tech{延续} @racket[kq]，它交回一条等 @math{p} 的@tech{延续}：这条@tech{延续}拿到 @math{p}，先交给 @racket[f] 算出 @math{q}，再交给 @racket[kq]。@racket[f] 从 @math{p} 到 @math{q}，@racket[(neg f)] 却从 @math{¬q} 到 @math{¬p}，方向反了过来，所以它的类型用@xref["02:laws"]{「结合律与单位律」}里的反向箭头 @racket[←] 来写。

两者的差别只在柯里化的方向：@tech{延续}在前还是在后。既然是参数顺序的差别，交换顺序就能在两种写法之间来回：

@examples[#:eval ev #:label #f #:no-prompt
(: flip (∀ (x y z) (→ (→ x (→ y z)) (→ y (→ x z)))))
(define (((flip f) . y*) . x*) (apply (apply f x*) y*))]

@racket[flip] 交换参数顺序，对任何两层柯里化的函数都适用。@racket[neg] 产出的 @math{¬q → ¬p} 展开是 @math{¬q → p → ⊥}，正是这样的两层函数，@racket[flip] 把它变成 @math{p → ¬¬q}；反过来，又把 @math{p → ¬¬q} 变回 @math{¬q → ¬p}。只要两层 λ 之间不做别的事，@racket[(flip (flip f))] 就和 @racket[f] 行为一样：@racket[flip] 是它自己的逆，在两种写法之间来回，什么也不会丢失。@racket[neg]、@racket[cps] 造出的函数都满足这一条。

有了 @racket[flip]，@racket[cps] 和 @racket[neg] 可以互相定义：

@racketblock[
cps  =  (∘ flip neg)
neg  =  (∘ flip cps)]

@bold{练习}：上面用 @racket[flip] 在 @racket[neg] 和 @racket[cps] 之间来回。反过来，只用 @racket[neg] 和 @racket[cps]，写出 @racket[flip]。提示：先想想 @racket[(cps id)] 做了什么。

@subsection[#:tag "02:position"]{计算的位置}

@racket[neg] 的类型只说它在@tech{延续}类型之间映射。@math{¬@ty{Natural}} 里装的是一条条具体的@tech{延续}；一步计算，怎样把其中两条联系起来？

回头看@xref["02:cps"]{「延续与 CPS」}里 @racket[(fact/k 3 k)] 的展开。每递归一层，新的@tech{延续}都是在旧的前面复合一次乘法：@racket[k] 换成 @racket[(∘ k mul3)]，再换成 @racket[(∘ k mul3 mul2)]。收一条@tech{延续}，在它前面复合一个函数，交出另一条@tech{延续}，这正是 @racket[neg] 做的事：@racket[(neg f)] 收到等 @math{q} 的@tech{延续}，交出等 @math{p} 的@tech{延续}。照这个意思重写 @racket[neg]，得到的和前面的定义是同一个函数，只是可变参数交给 @racket[∘] 去处理：

@examples[#:eval ev #:label #f #:no-prompt
(define ((neg f) kq) (∘ kq f))]

于是递归的每一层都是一次 @racket[neg]：第一层用 @racket[(neg mul3)]，第二层用 @racket[(neg mul2)]，第三层用 @racket[(neg mul1)]。递归到底时的那条链，就是三次 @racket[neg] 依次用在 @racket[k] 上：

@racketblock[
  (∘ k mul3 mul2 mul1)
= ((neg mul1) ((neg mul2) ((neg mul3) k)))
= ((∘ (neg mul1) (neg mul2) (neg mul3)) k)]

@racket[(neg mul3)] 最先用，@racket[mul3] 紧挨着 @racket[k]；@racket[(neg mul1)] 最后用，@racket[mul1] 排在最前。几次 @racket[neg] 用 @racket[∘] 接起来，次序和里面的乘法正好相反。整条@tech{闭包链}从 @racket[k] 开始，一环环向内建起来。@racket[k] 是出口：@racket[(fact/k 3 k)] 若就是整个程序，它就是程序的出口，第一篇里的 @racket[exit]；启动时交进去的若是@tech{终结延续} @racket[a->⊥]，它就是 @racket[a->⊥]。

以上是链的构造。运行时，值又怎样沿着它走？@xref["02:anf"]{「求值顺序与 ANF」}说过，@racket[let*] 就是复合。反过来，把这条@tech{闭包链}拆回 @racket[let*]，给中间结果起名，值从 @racket[v0] 出发：

@racketblock[
  ((∘ k mul3 mul2 mul1) v0)
= (let* ([v1 (mul1 v0)]
         [v2 (mul2 v1)]
         [v3 (mul3 v2)])
    (k v3))]

每个名字处都有一条@tech{延续}在等它：等 @racket[v3] 的是 @racket[k]，等 @racket[v2] 的是先乘 3 再交给 @racket[k]，依次类推。把等 @racket[vn] 的那一条记作 @racket[kn]：

@racketblock[
k3  =  (∘ k               )
k2  =  (∘ k mul3          )
k1  =  (∘ k mul3 mul2     )
k0  =  (∘ k mul3 mul2 mul1)]

@racket[v0] 是递归到底交来的 @racket[1]，@racket[vn] 正是 @racket[(fact n)] 的值。这些@tech{延续}的类型都是 @math{¬@ty{Natural}}，每一条都是这个类型的一个具体的值，各自标出程序运行到的一个位置：等到 @racket[vn] 以后，还要乘上哪几个数，再交给 @racket[k]。第一篇 @racket[(label)] 捕获的「当前位置」，就是这样一条@tech{延续}。@racket[let*] 的每个绑定处都有一条；直接风格的 @racket[fact] 里，它们一样在，只是藏在嵌套的 @racket[let] 里。

相邻两个位置之间，隔着一步计算。从 @racket[k2] 到 @racket[k3]，中间一步是 @racket[mul3]：@racket[k2] 拿到值，先乘 3，再交给 @racket[k3]。用 @racket[neg] 写出来：

@racketblock[
k2  =  (∘ k3 mul3)  =  ((neg mul3) k3)]

@racket[(neg mul3)] 的类型 @math{¬@ty{Natural} → ¬@ty{Natural}} 说的是它在两个@tech{延续}类型之间映射；这里交给它的是一个具体的值 @racket[k3]，交出的是另一个具体的值 @racket[k2]：它把一个位置上的@tech{延续}，映射成另一个位置上的@tech{延续}。一般地，一步 @racket[f] 能把位置 @racket[kp] 带到位置 @racket[kq]，条件就是 @c{kp = ((neg f) kq)}，也就是 @racket[(∘ kq f)]：前一处的@tech{延续}，正是这一步接上后一处的@tech{延续}。

这条等式从右往左读，是构造：@racket[(neg f)] 收到后一处的@tech{延续}，交出前一处的@tech{延续}，前面那条@tech{闭包链}就是这样从出口建起来的。从左往右读，是运行：@racket[(kp p)] 就是 @racket[(kq (f p))]，值走完 @racket[f] 这一步，等着它的@tech{延续}就从 @racket[kp] 换成了 @racket[kq]。递归到底，@racket[1] 作为 @racket[v0] 交给 @racket[k0]，@racket[let*] 一行行往下：过 @racket[mul1] 到 @racket[k1]，过 @racket[mul2] 到 @racket[k2]，过 @racket[mul3] 得到 @racket[6]，到 @racket[k3]，也就是出口。出口的那条@tech{延续}，既是@tech{延续}构造的起点，也是值移动的终点：计算开始时交进来的是它，计算最后抵达的也是它。执行一个程序，就是沿着@tech{闭包链}，从一个位置走到下一个位置。

@subsection[#:tag "02:k-in-hand"]{手中的延续}

第一篇用 @racket[cc] 实现 @racket[call/cc]：先由 @racket[(cc)] 取得当前@tech{延续}，再把它交给 @racket[proc]。在 CPS 里，这一步不必做。@xref["02:first-class-control"]{「一等控制」}说过，当前@tech{延续}已经是一个显式的参数：照 @racket[cps] 的写法也好，照 @racket[neg] 的写法也好，函数收到的@tech{延续}参数，就是这次调用之后要做的事。那么照这两种写法，@racket[call/cc] 该怎么写？

照 @racket[call/cc] 自己的意思写，先看它收到什么。@racket[cps:call/cc] 照 @racket[cps] 的写法，先收到输入 @racket[cps:proc]，再收到@tech{延续} @racket[kp]；@racket[neg:call/cc] 照 @racket[neg] 的写法，次序反过来，先收到 @racket[kp]，再收到 @racket[neg:proc]：

@racketblock[
(define ((cps:call/cc cps:proc) kp) ...)
(define ((neg:call/cc kp) neg:proc) ...)]

@racket[kp] 就是当前@tech{延续}，要交给 @racket[proc]。@racket[cps:proc] 照 @racket[cps] 的写法写成，期望得到的是 @racket[cps:kp]，也就是 @racket[(cps kp)]；@racket[neg:proc] 照 @racket[neg] 的写法，期望得到的是 @racket[neg:kp]，也就是 @racket[(neg kp)]。两个定义写完整：

@examples[#:eval ev #:label #f #:no-prompt
(define ((cps:call/cc cps:proc) kp) ((cps:proc (cps kp)) kp))
(define ((neg:call/cc kp) neg:proc) ((neg:proc kp) (neg kp)))]

两行里都有两份 @racket[kp]，角色不同：提升过的那一份交给 @racket[proc] 当参数，@racket[proc] 调用它，就是逃逸；原样的那一份接住 @racket[proc] 正常交回的结果。

跑一个很短的例子。在 @racket[cps:call/cc] 后面接一步加 1，交给它的 @racket[proc] 不理会收到的@tech{延续}，只算 @racket[2] 乘 @racket[3]。后面那一步加 1 也得写成@tech{延续}：拿到结果，加 1，再交给@tech{终结延续}：

@examples[#:eval ev #:label #f
(define (cps:proc1 cps:k) ((cps *) 2 3))
(⊥->a ((cps:call/cc cps:proc1) (λ (v) (a->⊥ (add1 v)))))]

@racket[cps:proc1] 正常交回 @racket[6]。原样的那份 @racket[kp]，也就是手写的那个 λ，接住它，先加 1，再交给@tech{终结延续}，得到 @racket[7]。

换一个 @racket[proc]，让它用上收到的@tech{延续}：先把 @racket[10] 交给 @racket[cps:k]，再加 1。@racket[cps:k] 收到 @racket[10]，交出的仍是一段等着@tech{延续}的计算，后面的加 1 只能再手写一个@tech{延续}接上：

@examples[#:eval ev #:label #f
(define (cps:proc2 cps:k) (λ (k) ((cps:k 10) (λ (v) (k (add1 v))))))
(⊥->a ((cps:call/cc cps:proc2) (λ (v) (a->⊥ (add1 v)))))]

结果是 @racket[11]，不是 @racket[12]。@racket[cps:k] 是提升过的 @racket[kp]，一调用，计算就改走 @racket[kp]：外面那一步加 1，然后是@tech{终结延续}。@racket[cps:proc2] 里排在后面的那一步加 1，再也轮不到。这正是第一篇里 @racket[call/cc] 的行为：调用交出去的@tech{延续}，就是丢下手头的工作，回到 @racket[call/cc] 之后。

@bold{练习}：用 @racket[neg:call/cc] 把这两个例子各跑一遍，结果仍是 @racket[7] 和 @racket[11]。提示：@racket[neg] 的写法先收@tech{延续}，再收输入；外面那一步加 1，用 @racket[(neg add1)] 接在@tech{终结延续}前面。

这么短的两个例子，@tech{延续}却得一个个手写：外面的加 1 一个，@racket[cps:proc2] 里又一个。@xref["02:first-class-control"]{「一等控制」}那句抱怨，到这里更重了：每个@tech{延续}都得亲手写。
