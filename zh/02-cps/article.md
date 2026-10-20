# 箭头指向何方：CPS 与否定翻译

大家好，

这是控制流系列的第二篇，承接[《标签成为逻辑之时：揭开 call/cc 的神秘面纱》](https://zhuanlan.zhihu.com/p/2019516690904401803)。上一篇中，我们用一等标签从零构建了 `call/cc`，发现了它与经典逻辑的对应，并借助 CPS 解开了阴阳谜题。

结尾留下了两根线头。第一根：构造性类型系统对应直觉主义逻辑，而 `call/cc` 填充的却是经典逻辑的重言式。一门构造性语言怎么能支持经典推理？阴阳谜题的 CPS 分解暗示了答案：经典的控制流并未消失，只是编码成了显式的延续传递。第二根线头：程序类型中的 $⊥$ 并不是世界的终结。进程终止后，OS 继续运行。如果能在程序*内部*拥有相对的 $⊥$，会意味着什么？

这篇文章回答第一个问题。

---

# 求值顺序与 ANF

考虑两个常见的递归函数：

```racket
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
         (fib (- n 2)))))
```

`(* n (fact (- n 1)))` 中，哪个先求值？`(- n 1)` 要先算，因为 `fact` 需要它的结果；`fact` 的返回值又要在 `*` 之前就绪。但这些依赖关系藏在表达式的嵌套结构里，要盯着括号才能看出来。`fib` 更微妙：`(+ (fib (- n 1)) (fib (- n 2)))` 的两个 `fib` 调用之间有没有固定顺序？在 Racket 中有（从左到右），但仅凭表达式本身看不出来。

能不能让求值顺序变得显式？

把每个中间结果绑定到一个名字上，让 `let*` 链条记录执行的步骤：

```racket
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
        (+ v w))))
```

`let*` 的每个绑定从上到下依次执行，中间不跳跃。`fib` 中先算 `(fib n-1)` 再算 `(fib n-2)`，不再需要知道 Racket 的求值策略，代码本身就是策略的忠实记录。这种把所有中间计算命名、排成序列的形式叫做**A-范式**（*A-Normal Form*，ANF）。

但 `let` 不是什么新东西。它脱糖为 lambda 调用：

```racket
(let ([v e]) b)  =  ((λ (v) b) e)
```

每个 `let` 绑定配对了两件东西：一个被求值的**可归约式**（*reducible expression*，redex）`e`，和一个等待结果的函数 `(λ (v) b)`。后者接收 `e` 的值，然后执行剩余的计算。这个「等待结果并执行剩余计算的函数」，就是**延续**（continuation）。

`let` 的先后也是从脱糖来的。调用 `((λ (v) b) e)` 时，先算出实参 `e`，再把结果绑定到形参 `v`，最后算函数体 `b`。所以 `(let ([v e]) b)` 总是先算 `e`，再算 `b`。

最简单的情形，函数体只是把一个函数用在绑定的值上：

```racket
  (let ([y (f x)])
    (g y))
= ((λ (y) (g y)) (f x))
= (g (f x))
= ((∘ g f) x)
```

先算 `(f x)`，再算 `(g y)`，正是 `f` 与 `g` 的复合：绑定的先后，就是复合的先后。`let` 比复合多做的一件事，是给中间结果起了名字。这里的 `∘` 就是第一篇用过的 `compose`，把几个函数接成一个，最右边的先算。

上面 `fact`、`fib` 用的是 `let*`。`let*` 是嵌套的 `let`：后一个绑定连同它后面的全部代码，是前一个 `let` 的函数体。三步计算 `f`、`g`、`h`，照 `let*` 写，再拆成 `let`：

```racket
  (let* ([y (f x)]
         [z (g y)])
    (h z))
= (let ([y (f x)])
    (let ([z (g y)])
      (h z)))
= (let ([y (f x)])
    ((∘ h g) y))
= ((λ (y) ((∘ h g) y)) (f x))
= ((∘ (∘ h g) f) x)
```

里层的 `let` 算的是 `((∘ h g) y)`，所以 `y` 的延续就是 `(∘ h g)`：它包下了剩下的全部工作，先 `g` 再 `h`。外层再把它接在 `f` 后面。每个绑定各藏着这样一个延续。

> **注意：** 后一步若用到前面不止一个名字，比如 `fib` 最后的 `(+ v w)`，就不只是一串函数首尾相接了：`v` 得一路带到最后。本文只看每一步只用上一步结果的情形。

## 结合律与单位律

把计算写成 `let`，写法却不唯一。`fact`、`fib` 把每个新的 `let` 嵌在前一个 `let` 的函数体 `b` 里；可 `let` 里还有另一个位置放得下表达式，就是被求值的 `e`，同样几步，也可以先接成一段，嵌进 `e`；中间还可以插一个只给值换名的 `let`。ANF 本来是要把计算顺序写死的，写法一多，定下的还是同一个顺序吗？

先看嵌进 `e`。同样三步，把前两步写成一段，嵌进第三步的 `e`：

```racket
  (let ([z (let ([y (f x)])
             (g y))])
    (h z))
= (h ((∘ g f) x))
= ((∘ h (∘ g f)) x)
```

这回先把 `f`、`g` 接成一段，再接上 `h`。

两种写法都是先算 `(f x)`，再算 `(g y)`，最后算 `(h z)`，结果也一样。嵌在 `b` 里还是嵌进 `e` 里，只是同一个复合的两种分组：

```racket
(∘ (∘ h g) f)  =  (∘ h (∘ g f))
```

先接哪两个都一样，这条性质叫**结合律**（*associativity*）。正因为分组无关紧要，三个函数可以不加括号，直接写成 `(∘ h g f)`。两种写法互改时要留意名字：嵌在 `b` 里，`y` 对 `(h z)` 也看得见；嵌进 `e` 里，就看不见了。

再看只换名的 `let`。`let` 能确定计算顺序，靠的是先算 `e`、后算 `b`；`(let ([y x]) (f y))` 把 `x` 改叫 `y` 再交给 `f`；`(let ([y (f x)]) y)` 给 `f` 的结果起名 `y`，又原样交出。这两种写法里只有 `f` 一步计算，没有先后可分，和直接写 `(f x)` 行为一样。

换名的那一步什么也不做，收到什么就原样交出什么。这样的函数，`∘` 自己就给得出来。`(∘ g f)` 把两个函数接成一个；只交一个，`(∘ f)` 就是 `f` 本身；一个也不交，`(∘)` 什么也没接上，收到什么就交出什么。把它记作 `id`：

```racket
(define ∘ compose)
(define id (∘))
```

`∘` 就是 Racket 的 `compose`，`id` 就是 Racket 的 `values`。前面 `let` 的两种换名写法，化成复合，多出来的正是 `id`：

```racket
(let ([y (f x)])   y)   =  ((∘ id f) x)  =  (f x)
(let ([y    x]) (f y))  =  ((∘ f id) x)  =  (f x)
```

`id` 接在哪一头都不改变什么：`(∘ id f)` 和 `(∘ f id)` 都等于 `(∘ f)`，也就是 `f`。这条性质叫**单位律**（*identity law*），`id` 是 `∘` 的单位元。

这就回答了前面的问题。结合律说，`let` 嵌在 `b` 里还是 `e` 里都一样；单位律说，只换名的 `let` 可有可无。写法尽可以不同，定下的是同一个计算顺序，行为也都一样。这两条是 `∘` 的运算律。

`∘` 写的顺序和算的顺序相反：`(∘ h g f)` 里最右边的 `f` 先算。`let*` 却是照算的顺序，从上往下写。照算的顺序写的复合记作 `⨾`，`(⨾ f g h)` 先调用 `f`，再调用 `g`，最后调用 `h`：

```racket
  (let* ([y (f x)]
         [z (g y)])
    (h z))
= ((∘ h g f) x)
= ((⨾ f g h) x)
```

从类型看，复合是把首尾相接的箭头拼成一支：`(∘ g f)` 里，`f` 从 `p1` 到 `p2`，`g` 从 `p2` 到 `p3`，拼起来就是从 `p1` 到 `p3`。`⨾` 也是拼接，只是参数的次序反了过来，拼的是反着写的箭头。把箭头反着写，结果在左边，参数在右边，记作 `←`：`(← q p)` 就是 `(→ p q)`。下面的 `p ...` 代表一串类型 `p1`、`p2`、…、`pn`。用 `→` 写出 `∘` 的类型，用 `←` 写出 `⨾` 的类型，两者形状一样：

```racket
(define-type (← q p) (→ p q))

(: ∘ (∀ (p ...) (→ (→ pn-1 pn) ... (→ p1 p2) (→ p1 pn))))
(: ⨾ (∀ (p ...) (→ (← pn-1 pn) ... (← p1 p2) (← p1 pn))))
(define (⨾ . f*) (apply ∘ (reverse f*)))
```

`⨾` 只是把参数顺序倒过来的 `∘`，两条运算律原样继承下来，`(⨾)` 也是 `id`。

---

# 延续与 CPS

回头看开头的 `let`。每个绑定都配着一个延续 `(λ (v) b)`，只是 `let` 的语法替我们藏好了；ANF 所做的，不过是让这种隐藏变得有规律。把延续取出来，起个名字 `k`，再把整段写回函数调用：

```racket
  ((λ (v) b) e)
= (let ([k (λ (v) b)]) (k e))
= ((λ (k) (k e)) (λ (v) b))
```

最后一行里，延续成了一个普通的参数：`(λ (k) (k e))` 先等着延续，拿到以后把 `e` 的值交给它。延续于是成了独立的值，可以传来传去、存储、反复调用。

那就让每个函数都额外接受这样一个参数 `k`，代表「我算完之后该做什么」。不再返回值给调用者，而是把结果直接传给 `k`。`fact` 的 CPS 版本：

```racket
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
                        (k (+ v w))))))))
```

读一下类型：`(→ Natural (¬ Natural) ⊥)`。接收一个自然数和一个延续 $¬\text{Natural}$，返回 $⊥$。函数不再「返回」值，它把结果推入延续，然后自己不返回。

代码的形状变了。`fact/k` 的递归调用 `(fact/k (- n 1) (λ (v) ...))` 是整个 `if` 分支的最后一个动作，后面没有任何待执行的表达式。`fib/k` 也是：每个递归调用都处于尾位置。递归调用与对延续的调用，都成了尾调用。

当延续是显式参数时，「做完之后的事情」不再堆叠在调用栈上，而是编码在 `k` 参数所携带的闭包里。`fib/k` 递归时，`(λ (v) (fib/k (- n 2) (λ (w) (k (+ v w)))))` 把「等算完第一个分支，再递归第二个分支，最后加起来交给 k」整个未来打包进了一个函数。调用栈不再增长，堆上的闭包链在增长。

直接风格里也有不增长栈的写法：尾递归版本的 `fact` 使用累积器。

```racket
(: fact (→ Natural Natural))
(define (fact n)
  (let loop ([n n] [acc 1])
    (if (= n 0)
        acc
        (loop (- n 1) (* n acc)))))
```

把它也变换成 CPS，闭包链还会增长吗？

```racket
(: fact/k (→ Natural (¬ Natural) ⊥))
(define (fact/k n k)
  (let loop/k ([n n] [acc 1] [k k])
    (if (= n 0)
        (k acc)
        (loop/k (- n 1) (* n acc) k))))
```

延续 `k` 在循环体中被原样传递，不会有新的闭包包裹。尾递归之所以不消耗栈空间，正因为它不创建新的延续：每一步复用同一个 `k`。非尾递归版本的闭包链增长，对应着调用栈的增长。CPS 只是把这种增长从栈搬到了堆上。

ANF 命名中间值，让求值顺序显式；CPS 命名延续，让延续显式。

## 终结延续

CPS 函数需要一个延续才能启动。启动时交进去什么？

许多语言有一个内置的延续：`exit`，类型为 $¬\text{Byte}$。可以包装一下得到 $¬\text{Natural}$：

```racket
> (fact/k 5 (λ (ans) (displayln ans) (exit 0)))
120
```

结果打印出来了，进程也随之终止。`exit` 一调用，整段计算就到此为止：启动时交进去的延续，也是计算最后抵达的地方，所以叫它终结延续。可是用 `exit` 做终结延续，进程一结束，就没法拿着结果继续工作。

我们需要的是另一个类型为 $a → ⊥$ 的函数：它不返回，但能把答案送到某个我们可以取回的地方，而不杀死进程。`raise` 正合适：它不返回，而 handler 可以捕获它的值。我们只需一个专用的 struct 来区分我们的答案和其他异常：

```racket
(struct (r) ans ([a* : (Listof r)]) #:type-name Ans)
(define (list->values v*) (apply values v*))
(: a->⊥ (∀ (a) (¬ a)))
(define (a->⊥ . a*) (raise (ans a*)))
(define-syntax-rule (⊥->a exp)
  (with-handlers ([ans? (∘ list->values ans-a*)]) exp))
```

`a->⊥` 把值包进 `ans` struct 并抛出。`⊥->a` 安装一个 handler 来捕获这个 struct 并提取内容，`list->values` 把收到的列表拆回多个返回值。命名反映了类型层面的操作：`a->⊥` 把值送入 $⊥$（抛出），`⊥->a` 把值取回（捕获）。

```racket
> (⊥->a (fact/k 5 a->⊥))
120
> (⊥->a (fib/k 10 a->⊥))
55
```

CPS 函数运行起来，`a->⊥` 充当终结延续构建出闭包链，`⊥->a` 在外面接住答案。计算在 raise/handler 的边界内执行，结果穿过边界传出来。

## 一等控制

CPS 真正的力量不在于尾递归，而在于延续成为了**一等值**。延续就是函数，可以存储、复制、丢弃，也可以改为调用另一个。`call/cc` 通过在运行时捕获当前延续赋予了我们这种能力。在 CPS 里，当前延续已经是一个显式的参数。

第一篇用 `cc` 写过 `mul`：遇到零就短路。在 CPS 里，延续就是普通的函数参数，同样的短路可以直接写出来：

```racket
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
  (⊥->a (loop/k r* a->⊥)))
```

外面的 `⊥->a` 接住从 `a->⊥` 出来的答案，所以 `mul` 照常返回一个数：

```racket
> (mul 1 2 3 4)
24
> (mul 1 2 0 3 4)
0
```

正常路径沿着 `k` 返回累积的乘积。遇到零时，跳过 `k`，直接调用 `a->⊥`。`k` 代表「继续乘下去然后返回结果」的延续；`a->⊥` 代表「直接跳出整个循环，把值交给 handler」的延续。选择调用哪一个，就是选择走哪条控制流。不需要 `call/cc`，不需要任何特殊操作符。延续是普通的函数，切换延续是普通的函数调用。

但代价也很明显：程序员必须亲手编写每一个延续，把 `k` 穿过每一层调用。能否自动化 CPS 包装？

---

# 否定的层次

对固定参数的函数，CPS 包装是平凡的。`zero?` 的 CPS 版本：

```racket
(define (zero?/k x k) (k (zero? x)))
```

`zero?/k` 在 `zero?` 的结果外面套一层 `k` 调用，就完成了包装。任何固定参数的函数都能这样包。但可变参数函数怎么办？延续和操作数挤在同一层：

```racket
(define (+/k . args-and-k) ...)  ; 哪个参数是 k？
```

延续放在最后，参数个数不定，得先数一数才找得到它；放在最前，倒是分得开。可无论放哪一头，操作数和延续都得一起交齐，交齐了计算就开始：没有一个值代表还没开始的 `(+ 1 2)`。第一篇里，这样的值有类型：程序就是一个 $¬¬\text{Byte}$，等操作系统交来 `exit` 才运行。通过柯里化，让延续参数独占一层，先交操作数，得到的正是这样一个等着延续的值。延续独立在外层还是内层，操作上没有区别，函数体都一样：

```racket
(define (((neg f) kq) . p*) (kq (apply f p*)))   ; 延续在前
(define (((cps f) . p*) kq) (kq (apply f p*)))   ; 延续在后
```

操作上一样，类型却不同：

```racket
(: neg (∀ (p q) (→ (→ p q) (→ (¬ q) (¬ p)))))
(: cps (∀ (p q) (→ (→ p q) (→    p (¬¬ q)))))
```

按照 Curry-Howard 对应，这两个类型对应的命题正是两条直觉主义定理：

| 命题                  | 定理                                  |
|-----------------------|---------------------------------------|
| $(p → q) → (¬q → ¬p)$ | **逆否律**（*law of contraposition*） |
| $(p → q) → (p → ¬¬q)$ | **双重否定引入**（DNI）的推广形式     |

两者的差别只在柯里化的方向：延续在前还是在后。既然是参数顺序的差别，交换顺序就能在两种箭头之间来回：

```racket
(: flip (∀ (x y z) (→ (→ x (→ y z)) (→ y (→ x z)))))
(define (((flip f) . y*) . x*) (apply (apply f x*) y*))
```

`flip` 交换参数顺序，对任何两层柯里化的函数都适用。`neg` 产出的 $¬q → ¬p$ 展开是 $¬q → p → ⊥$，正是这样的两层函数。代入 $x = ¬q$、$y = p$、$z = ⊥$，得到 $p → ¬¬q$；反过来代入 $x = p$、$y = ¬q$，又从 $p → ¬¬q$ 回到 $¬q → ¬p$。本文只在这两种形状之间使用它。`case→` 列出同一个函数的几种类型，调用时按交给它的参数取用其中一种；把两种读法都写进类型：

```racket
(: flip (∀ (p q) (case→ (→ (→ (¬ q) (¬ p)) (→ p (¬¬ q)))
                        (→ (→ p (¬¬ q)) (→ (¬ q) (¬ p))))))
```

这两行是同一段代码的两种读法：第一行把 $¬q → ¬p$ 变成 $p → ¬¬q$，第二行再变回来。对纯函数来说，交换两次参数顺序就回到原处，所以 `flip` 是它自己的逆，在两种箭头之间来回，什么也不会丢失。按照 Curry-Howard，两行的类型 $(¬q → ¬p) → (p → ¬¬q)$ 和 $(p → ¬¬q) → (¬q → ¬p)$ 也都是直觉主义定理。

有了 `flip`，`cps` 和 `neg` 可以互相定义：

```racket
cps  =  (∘ flip neg)
neg  =  (∘ flip cps)
```

> **练习：** 上面用 `flip` 在 `neg` 和 `cps` 之间来回。反过来，只用 `neg` 和 `cps`，写出 `flip`。提示：先想想 `(cps id)` 做了什么。

回头看 `neg`。`(neg f)` 的类型 $¬q → ¬p$ 是延续之间的变换，将期望 $q$ 的延续变换为期望 $p$ 的延续。变换的方式很直接，把 `f` 复合到延续前面。这和前面的定义是同一个函数，只是可变参数交给 `∘` 去处理：

```racket
(define ((neg f) kq) (∘ kq f))
```

CPS 一节中闭包链的每一步，都是这样一次复合。`(λ (v) (k (* n v)))` 在 `k` 前面复合乘法，调用栈上的压栈到了堆上就成了复合。

接两次，就是两步。`k` 先交给 `(neg g)`，再交给 `(neg f)`：

```racket
  (((∘ (neg f) (neg g)) k) x)
= (((neg f) ((neg g) k)) x)
= (((neg g) k) (f x))
= (k (g (f x)))
= ((∘ k g f) x)
```

`k` 前面先接上 `g`，再接上 `f`；值到来时先过 `f`，再过 `g`，最后交给 `k`。不带累积器的那版 `fact/k` 每递归一层就这样接一次。把 `(λ (v) (* 3 v))` 记作 `mul3`，其余类推，`(fact/k 3 k)` 递归到底时，手里的延续是：

```racket
  (∘ k (λ (v) (* 3 v)) (λ (v) (* 2 v)) (λ (v) (* 1 v)))
= (∘ k mul3 mul2 mul1)
```

递归到底，交给它的是 `1`：先乘 1，再乘 2，再乘 3，得到的 `6` 交给 `k`。闭包链就是 `k` 前面的这一串函数。堆上一环环增长的是这一串，`k` 自己没有动过。

## 三种箭头

`cps`、`neg` 和 `flip` 的两种读法，类型对应四条直觉主义定理，其中三种命题形状反复出现：$p → q$、$¬q → ¬p$、$p → ¬¬q$。函数类型 $p → q$ 经过 `neg` 变成 $¬q → ¬p$，经过 `cps` 变成 $p → ¬¬q$，而 `flip` 在后两种之间互转。既然这三种形状反复出现，不妨为它们取个名字：

```racket
(define-type (→𝒞 p q) (→ p q))
(define-type (→𝒦 p q) (→ p (¬¬ q)))
(define-type (→𝒰 p q) (← (¬ p) (¬ q)))

(: neg  (∀ (p q) (→ (→𝒞 p q) (→𝒰 p q))))
(: cps  (∀ (p q) (→ (→𝒞 p q) (→𝒦 p q))))
(: flip (∀ (p q) (case→ (→ (→𝒰 p q) (→𝒦 p q))
                        (→ (→𝒦 p q) (→𝒰 p q)))))
```

| 世界       | 箭头类型            |
|------------|---------------------|
| 𝒞 宿主世界 | $p →_𝒞 q = p → q$   |
| 𝒦 CPS 世界 | $p →_𝒦 q = p → ¬¬q$ |
| 𝒰 逆否世界 | $p →_𝒰 q = ¬q → ¬p$ |

每种箭头类型自成一个世界，三个运算符在世界之间搬运箭头。其中 `flip` 是它自己的逆，所以 𝒰 和 𝒦 之间可以自由互转。但搬运只是第一步：两个 𝒰 箭头，或两个 𝒦 箭头，能在各自的世界里复合吗？

𝒰 可以直接写出来。$p →_𝒰 q$ 从 $p$ 写到 $q$，函数却从 $¬q$ 指向 $¬p$，方向和函数相反，所以上面用开头的反向箭头 `←` 来写：𝒰 的箭头，就是两个否定之间的一支反向箭头。两支 𝒰 箭头首尾相连，复合就是反向箭头的复合 `⨾`：

```racket
(: ∘𝒰 (∀ (p ...) (→ (→𝒰 pn-1 pn) ... (→𝒰 p1 p2) (→𝒰 p1 pn))))
(define ∘𝒰 ⨾)
```

`⨾` 的两条运算律，`∘𝒰` 也原样都有：分组无关紧要，也有单位元。和 `(∘)` 一样，一支箭头也不交给它，`(∘𝒰)` 就是单位元，记作 `neg:id`；它其实还是 `id`：

```racket
(: neg:id (∀ (q) (→𝒰 q q)))
(define neg:id (∘𝒰))
```

𝒦 的箭头却不能直接复合：$p → ¬¬q$ 接不上 $q → ¬¬r$，中间差一个 $¬¬$。不过 `flip` 是它自己的逆，𝒦 的箭头可以无损地搬到 𝒰 再搬回来。$p →_𝒦 q$ 经 `flip` 变成 $p →_𝒰 q$，$q →_𝒦 r$ 变成 $q →_𝒰 r$，保持着首尾相连的关系，在 𝒰 那边复合得到 $p →_𝒰 r$，最后通过 `flip` 变回 $p →_𝒦 r$：

```racket
(: ∘𝒦 (∀ (p ...) (→ (→𝒦 pn-1 pn) ... (→𝒦 p1 p2) (→𝒦 p1 pn))))
(define (∘𝒦 . cps:f*) (flip (apply ∘𝒰 (map flip cps:f*))))
```

这个定义是照着类型接出来的：搬过去，复合，再搬回来。`flip` 来回一趟什么也不丢，𝒦 的箭头和 𝒰 的箭头一一对应，所以 `∘𝒰` 的两条运算律也跟着到了 `∘𝒦` 上：分组无关紧要；一支箭头也不交给它，`(∘𝒦)` 就是单位元：

```racket
(: cps:id (∀ (q) (→𝒦 q q)))
(define cps:id (∘𝒦))
```

这样定义的复合，算出来的是什么？从最少的箭头开始，每次交给它一个输入 `x` 和一个延续 `k`。一支箭头也不交：

```racket
  (((∘𝒦) x) k)
= (((flip (∘𝒰)) x) k)
= (((∘𝒰) k) x)
= (k x)
```

`flip` 把 `k` 换到 `x` 前面，`(∘𝒰)` 原样交出 `k`，最后 `x` 交给 `k`：单位元 `cps:id` 收到 `x`，原样交给延续。第二行也说明，`cps:id` 就是 `(flip neg:id)`。`neg:id` 是 `(neg id)`：把 `id` 接在延续前面，什么也没改。于是 `cps:id` 是 `(flip (neg id))`，也就是 `(cps id)`。

> **练习：** 只交一支 `cps:f`，照同样的办法展开 `(((∘𝒦 cps:f) x) k)`，验证得到的还是 `cps:f`，和 `(∘ f)` 就是 `f` 一样。

交两支 `cps:f`、`cps:g`，把 `(flip cps:f)` 记作 `neg:f`，`(flip cps:g)` 记作 `neg:g`：

```racket
  (((∘𝒦 cps:g cps:f) x) k)
= (((flip (∘𝒰 neg:g neg:f)) x) k)
= (((flip (∘ neg:f neg:g)) x) k)
= (((∘ neg:f neg:g) k) x)
= ((neg:f (neg:g k)) x)
= ((cps:f x) (neg:g k))
= ((cps:f x) (λ (y) ((cps:g y) k)))
```

前两步拆开 `∘𝒦` 和 `∘𝒰` 的定义，`flip` 再把 `k` 换到 `x` 前面：`k` 先交给 `neg:g`，再交给 `neg:f`，和接闭包链时一样。最后两步把 `neg:f`、`neg:g` 里的 `flip` 拆开，𝒰 就不见了。`cps:f` 拿到 `x`，收到的延续是 `(λ (y) ((cps:g y) k))`：拿到 `y`，交给 `cps:g`，`cps:g` 的结果再交给 `k`。

手写 `fib/k` 时，`(λ (v) (fib/k (- n 2) (λ (w) (k (+ v w)))))` 就是这样写出来的：后一步连同它的延续包成一个 λ，交给前一步。`∘𝒦` 把这个包法做成了复合。

𝒞、𝒰、𝒦 各有自己的复合，三种复合都满足单位律和结合律。程序怎样连接，于是有了可以照着变形的等式，就像算式按运算律变形一样。

> **注意：** `flip` 来回一趟什么也不丢，说的是纯函数。对 𝒦 的箭头，还要它收到参数时只造出一个等待延续的函数，不做别的事；否则 `(∘𝒦 cps:f cps:id)` 就不再等于 `cps:f`：`cps:f` 原本一收到参数就做的事，要等收到延续才做。`cps` 造出的箭头都是这样，本文一直这样假定。

## 手中的延续

第一篇用 `cc` 实现 `call/cc`：先由 `(cc)` 取得当前延续，再把它交给 `proc`。在 CPS 里，这一步不必做。一等控制一节说过，当前延续已经是一个显式的参数：𝒦 和 𝒰 的箭头收到的延续参数，就是这次调用之后要做的事。那么在这两个世界里，`call/cc` 该怎么写？

照 `call/cc` 自己的意思写，先看它收到什么。`cps:call/cc` 是 𝒦 的箭头，先收到输入 `cps:proc`，再收到延续 `kp`；`neg:call/cc` 是 𝒰 的箭头，次序反过来，先收到 `kp`，再收到 `neg:proc`：

```racket
(define ((cps:call/cc cps:proc) kp) ...)
(define ((neg:call/cc kp) neg:proc) ...)
```

`kp` 就是当前延续，要做的是把它交给 `proc`。两个 `proc` 都是本世界的箭头，收到的参数将来也要当作本世界的箭头来调用。`kp` 却是宿主里的一条延续，收到值就交出去，没有本世界箭头的那一层延续参数，形状对不上，所以先提升一份再交出去：𝒦 里用 `cps`，𝒰 里用 `neg`。`proc` 算出来的仍是一段等着延续的计算，另一份 `kp` 留下来，交给它，接住它正常交回的结果。两者只差在次序：`cps:proc` 先收提升过的 `(cps kp)`，再收留下的 `kp`；`neg:proc` 反过来，先收留下的 `kp`，再收提升过的 `(neg kp)`。两个定义写完整：

```racket
(define ((cps:call/cc cps:proc) kp) ((cps:proc (cps kp)) kp))
(define ((neg:call/cc kp) neg:proc) ((neg:proc kp) (neg kp)))
```

跑一个很短的例子。在 `cps:call/cc` 后面接一步加 1，交给它的 `proc` 不理会收到的延续，只算 `2` 乘 `3`：

```racket
> (define cps:add1 (cps add1))
> (define (cps:proc1 cps:k) ((cps *) 2 3))
> (⊥->a (((∘𝒦 cps:add1 cps:call/cc) cps:proc1) a->⊥))
7
```

`cps:proc1` 正常交回 `6`。留下的那份 `kp` 接住它，先加 1，再交给终结延续，得到 `7`。

换一个 `proc`，让它用上收到的延续：先把 `10` 交给 `cps:k`，再加 1：

```racket
> (define (cps:proc2 cps:k) ((∘𝒦 cps:add1 cps:k) 10))
> (⊥->a (((∘𝒦 cps:add1 cps:call/cc) cps:proc2) a->⊥))
11
```

结果是 `11`，不是 `12`。`cps:k` 是提升过的 `kp`，一调用，计算就改走 `kp`：外面那一步加 1，然后是终结延续。`cps:proc2` 里排在后面的那一步加 1，再也轮不到。这正是第一篇里 `call/cc` 的行为：调用交出去的延续，就是丢下手头的工作，回到 `call/cc` 之后。

> **练习：** 用 `neg:call/cc` 在 𝒰 里把这两个例子各跑一遍，结果仍是 `7` 和 `11`。提示：𝒰 的箭头先收延续，再收输入；外面那一步加 1，用 `(neg add1)` 和 `∘𝒰` 接上。

## 新世界下的 Clavius 律

两个新 `call/cc` 的类型，可以从定义里读出来。拿 `cps:call/cc` 来看。把它交出的结果的类型记作 `p`。`kp` 是这次调用的当前延续，等的就是这个结果，类型是 `(¬ p)`。`cps` 把它提升成 `(→𝒦 p ⊥)`，这是 𝒦 里的否定，记作 `¬𝒦`；𝒰 里的否定同样记作 `¬𝒰`：

```racket
(define-type (¬𝒦 p) (→𝒦 p ⊥))
(define-type (¬𝒰 p) (→𝒰 p ⊥))
```

`cps:proc` 收到的是 `(¬𝒦 p)`；它交回的计算又交给了 `kp`，所以是 `(¬¬ p)`。`cps:proc` 因此是 `(→𝒦 (¬𝒦 p) p)`。`cps:call/cc` 先收 `cps:proc`，再收 `kp`，结果是 `⊥`，它的类型就出来了。`neg:call/cc` 同理：

```racket
(: cps:call/cc (∀ (p) (→𝒦 (→𝒦 (¬𝒦 p) p) p)))
(: neg:call/cc (∀ (p) (→𝒰 (→𝒰 (¬𝒰 p) p) p)))
```

> **练习：** 照推出 `cps:call/cc` 类型的办法，推出 `neg:call/cc` 的类型：`kp` 仍是 `(¬ p)`，留意 `neg:proc` 先收的是哪一个。`(neg kp)` 的类型是 $¬⊥ → ¬p$，也就是 `(¬𝒰 p)`。

这个形状眼熟。照三种箭头一节的写法，把宿主 𝒞 里的否定记作 `¬𝒞`，第一篇的 `call/cc` 的类型是：

```racket
(define-type (¬𝒞 p) (→𝒞 p ⊥))
(: call/cc (∀ (p) (→𝒞 (→𝒞 (¬𝒞 p) p) p)))
```

读作 $(¬p → p) → p$，Clavius 律。两个新 `call/cc` 的类型是同一条定律，只是 𝒞 换成了 𝒦、𝒰：它们是 Clavius 律在 𝒦、𝒰 里的样子。

可第一篇的分水岭说过：`call/cc` 要先凭空造出一个 $¬p$ 交给 `proc`，只用 λ 和函数调用写不出来，必须捕获。`cps:call/cc` 却只用了 λ。它交给 `proc` 的否定，是从哪里来的？

把 $→_𝒦$ 展开成宿主的箭头：

$$(¬_𝒦 p →_𝒦 p) →_𝒦 p \;=\; (¬_𝒦 p → ¬¬p) → ¬p → ⊥$$

$¬p$ 在箭头左边，是参数，就是 `kp`。宿主的 Clavius 律只收 `proc` 一个输入，手里没有否定，只能凭空去造；到了 𝒦 里，这个否定作为参数交了进来。交给 `cps:proc` 的 $¬_𝒦 p$，是 `cps` 从 `kp` 加工出来的。$¬_𝒦 p$ 展开是 $p → ¬¬⊥$；手里若有一个 $¬¬⊥$ 的值，把类型为 $⊥ → ⊥$ 的 `id` 交给它，就得到 $⊥$ 的值，所以 $¬¬⊥$ 和 $⊥$ 一样空。对非空的 $p$，𝒦 里同样凭空造不出 $¬_𝒦 p$，它只能从收到的 `kp` 得来。`cps:call/cc` 做的，是分水岭构造性那一侧的事：消耗交到手里的否定。

所以展开后的这条公式，已经不是宿主里的 Clavius 律，而是一条直觉主义定理：按照 Curry-Howard，它有闭合的、有类型的纯 λ 项，就是 `cps:call/cc`。`neg:call/cc` 也一样。同一条经典定律，换到 𝒦 或 𝒰 里写，就成了直觉主义定理。经典的控制并没有消失，宿主要捕获的那条延续，成了显式的参数。

一等控制在 𝒦 里有了，写法却还是 CPS。手写 `mul` 时的那句抱怨只消掉了一半：有了 `∘𝒦`，延续不必手写，箭头却只能一支支首尾排开，中间结果没有名字。

# 再次隐藏延续

回想开头的观察。`let` 脱糖为 lambda 调用，延续藏在 `let` 里面：等待结果的那个 λ 不用我们写，绑定的语法替我们写了。CPS 变换把延续拉出来变成显式参数，这个 λ 就得亲手写。能不能反过来：用 `let` 语法把 CPS 的延续再藏回去？

先看一个具体例子。假设我们有 CPS 提升的加法 `cps:+` 和乘法 `cps:*`，想计算 `(1 + 2) × 3`。到这里，已经有两种写法。一种像 `fib/k` 那样手写延续：`(cps:+ 1 2)` 的延续拿到 `v`，交给 `(cps:* v 3)`，结果再交给最外面的 `k`。另一种用三种箭头一节的 `∘𝒦`：把前面的 `mul3` 也提升成一支箭头 `(cps mul3)`，记作 `cps:mul3`，与 `cps:+` 复合。展开 `∘𝒦` 时看过，两者是同一个计算：

```racket
  (λ (k)
    ((cps:+ 1 2)
     (λ (v)
       ((cps:* v 3) k))))
= ((∘𝒦 cps:mul3 cps:+) 1 2)
```

前一种得亲手写 λ。后一种不用写 λ，可中间结果没有名字，每一步还得先做成一支箭头，再一支支排开。想要的是第三种：像 `let` 一样给中间结果起名，λ 由语法替我们写：

```racket
(anf:let ([v (cps:+ 1 2)])
  (cps:* v 3))
```

它的意思应当和上面两种一样。

## 接上一段计算

先试着把 `anf:let` 当作 `let` 来读。延续与 CPS 一节把 `let` 拆成过一次调用：

```racket
  (let ([v e]) b)
= ((λ (v) b) e)
= (let ([k (λ (v) b)]) (k e))
= ((λ (k) (k e)) (λ (v) b))
```

`let` 手里有两样东西：等着结果的 `k`，和右边算出的值 `e`。直接调用 `(k e)`，类型对得上。照样拆 `anf:let`，手里也有两样：函数体包成的 `(λ (v) (cps:* v 3))`，它就是 `cps:mul3`；右边 `(cps:+ 1 2)` 算出的值，记作 `kk3`（两个 `k` 对应 $¬¬$ 的两层）。可 `(cps:mul3 kk3)` 对不上：`cps:mul3` 要的是一个数，`kk3` 却是一段还在等延续的计算，延续拿到的才是 `3`。

`let` 背后是 `∘`：开头那条等式 `(let ([y (f x)]) (g y)) = ((∘ g f) x)`。这里要的却是 `((∘𝒦 cps:mul3 cps:+) 1 2)`，`anf:let` 背后该是 `∘𝒦`。

可宏拿到的是整个右边。右边不一定是一次调用，可以是任何算出一段计算的表达式；宏手里只有它算出的 `kk3`，没有单独的 `cps:+` 和 `1`、`2`，写不出 `(∘𝒦 cps:mul3 cps:+)`。那就把 `kk3` 当作输入，在 `cps:mul3` 前面接一支箭头 `X`，由它收下 `kk3`：

```racket
((∘𝒦 cps:mul3 X) kk3)
```

`X` 接在 `∘𝒦` 里，又得收下 `kk3`，所以是一支 $¬¬\text{Nat} →_𝒦 \text{Nat}$ 的箭头，展开就是 $¬¬\text{Nat} → ¬¬\text{Nat}$。

`X` 该做什么？交给它一个延续 `k`，照 `∘𝒦` 展开：

```racket
  (((∘𝒦 cps:mul3 X) kk3) k)
= ((X kk3) (λ (v) ((cps:mul3 v) k)))
```

要的那个复合，也照样展开：

```racket
  (((∘𝒦 cps:mul3 cps:+) 1 2) k)
= ((cps:+ 1 2) (λ (v) ((cps:mul3 v) k)))
= (kk3 (λ (v) ((cps:mul3 v) k)))
```

中间一行就是开头手写的那一种，只是 `(cps:* v 3)` 写成了 `(cps:mul3 v)`。两边对一对，`(X kk3)` 得是 `kk3` 自己：`X` 收到什么，就交出什么。

```racket
(define (neg²:id kkv) kkv)
```

它就是 `id`，只是收的是 $¬¬\text{Nat}$。类型写成 $¬¬\text{Nat} →_𝒦 \text{Nat}$ 时，它看上去像 DNE，要从 $¬¬\text{Nat}$ 取出一个 $\text{Nat}$；展开一看，却只是原样交出。`kk3` 就是 `(cps:+ 1 2)`，于是：

```racket
((∘𝒦 cps:mul3 neg²:id) (cps:+ 1 2))  =  ((∘𝒦 cps:mul3 cps:+) 1 2)
```

左边是 `anf:let` 要写成的样子，右边是复合的那一种，两边展开出来都是手写的那一种：三种写法在这里合上。

> **练习：** 名字里的 `neg²` 是怎么来的？只用 `neg` 和 `id`，写出一个与 `neg²:id` 行为相同的函数。提示：先看 `(neg id)` 的类型。

## 绑定就是复合

照这个办法，`(anf:let ([v kkv]) kkw)` 一般写成 `((∘𝒦 cps:kv neg²:id) kkv)`，其中 `cps:kv` 是函数体包成的 `(λ (v) kkw)`。右边 `kkv` 是一次调用 `(cps:f x)` 时，上一节的推导照样走得通：把 `cps:mul3` 换成 `cps:kv`，`(cps:+ 1 2)` 换成 `(cps:f x)`，两边的展开一步不改：

```racket
((∘𝒦 cps:kv neg²:id) (cps:f x))  =  ((∘𝒦 cps:kv cps:f) x)
```

`neg²:id` 不见了，`cps:f` 直接接在 `cps:kv` 前面。函数体是 `(cps:g y)` 时，`cps:kv` 就是 `cps:g`，`anf:let` 落到的正是上一节想要的 `∘𝒦`。和开头宿主的那条等式并排：

```racket
(let     ([y     (f x)])     (g y))  =  ((∘      g     f) x)
(anf:let ([y (cps:f x)]) (cps:g y))  =  ((∘𝒦 cps:g cps:f) x)
```

`let` 是 `∘` 的另一种写法，`anf:let` 是 `∘𝒦` 的另一种写法，多出来的是中间结果的名字。

> **练习：** 上面第一条等式，左边先算出 `(cps:f x)`，右边要等收到延续才调用 `cps:f`。两边为什么仍然相同？要是 `cps:f` 一收到参数就打印一行，两边还相同吗？

开头的两条运算律，`anf:let` 也有。三步计算照 `anf:let*` 写，是一层层嵌在函数体里的 `anf:let`；也可以把前两步写成一段，嵌进第三步被求值的那一段。两种写法计算顺序相同，对应 `∘𝒦` 的两种分组：

```racket
(anf:let* ([y (cps:f x)] [z (cps:g y)]) (cps:h z))
  =  ((∘𝒦 (∘𝒦 cps:h cps:g) cps:f) x)
(anf:let ([z (anf:let ([y (cps:f x)]) (cps:g y))]) (cps:h z))
  =  ((∘𝒦 cps:h (∘𝒦 cps:g cps:f)) x)
```

单位律也有绑定的样子，和开头宿主的两行一一对应：

```racket
(anf:let ([y (cps:f x)]) (cps:id y))  =  ((∘𝒦 cps:id cps:f) x)  =  (cps:f x)
(anf:let ([y (cps:id x)]) (cps:f y))  =  ((∘𝒦 cps:f cps:id) x)  =  (cps:f x)
```

> **练习：** 用上面并排的第二行和 `∘𝒦` 的两条运算律，推出这四条等式。

## 写成宏

回到开头的例子。宏要替我们写出的，是这样一段代码：

```racket
(let ([kk3 (cps:+ 1 2)])
  (: neg²:id  (→𝒦 (¬¬ Nat) Nat))
  (: cps:mul3 (→𝒦     Nat  Nat))
  (define (neg²:id kkv) kkv)
  (define (cps:mul3 v) (cps:* v 3))
  ((∘𝒦 cps:mul3 neg²:id) kk3))
```

把这些写成宏，`Nat` 换成类型变量 `a`、`b`。宏里的类型标注只是示意：本文的代码在 `no-check` 下运行，标注不经检查，`a`、`b` 也就不必绑定。宏里定义的 `neg²:id`、`cps:kv`、`cps:kkkv` 只在展开出的代码里可见，不会和程序员自己的名字相混。`anf:let` 就是只有一个绑定的 `anf:let*`：

```racket
(define-syntax anf:let*-values
  (syntax-rules ()
    [(_ () b* ...)
     (anf:begin b* ...)]
    [(_ ([v* e]) b* ...)
     (let ([kkv e])
       (: neg²:id  (→𝒦 (¬¬ a) a))
       (: cps:kv   (→𝒦     a  b))
       (: cps:kkkv (→𝒦 (¬¬ a) b))
       (define (neg²:id kkv) kkv)
       (define (cps:kv . v*) (anf:begin b* ...))
       (define cps:kkkv (∘𝒦 cps:kv neg²:id))
       (cps:kkkv kkv))]
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

(define-syntax-rule (anf:let ([v e]) b* ...)
  (anf:let* ([v e]) b* ...))

(define-syntax-rule (anf:if test conseq alt)
  (let ([kkb test])
    (: neg²:id  (→𝒦 (¬¬ Boolean) Boolean))
    (: cps:kb   (→𝒦     Boolean  a))
    (: cps:kkkb (→𝒦 (¬¬ Boolean) a))
    (define (neg²:id kkb) kkb)
    (define (cps:kb . b*) (if (equal? b* '(#f)) alt conseq))
    (define cps:kkkb (∘𝒦 cps:kb neg²:id))
    (cps:kkkb kkb)))

(define-syntax-rule (anf:let/cc cps:k b* ...)
  (cps:call/cc (λ (cps:k) b* ...)))
```

`anf:let*-values` 里的 `v*` 是一张形参表：`(define (cps:kv . v*) …)` 里的 `v*` 换成 `(v)`，就是 `(define (cps:kv v) …)`。`anf:if` 中那个 λ 是可变参数的：测试值作为列表 `b*` 到达。在 Racket 中只有 `#f` 是假值，所以 `(equal? b* '(#f))` 恰好检测单值为假的情况。`anf:begin` 把一串表达式依次接起来：前面每一个的结果都绑定到 `_` 上丢掉，最后一个的结果就是整段的结果。

宏不能直接写 `(cps:kv kkv)`：`cps:kv` 收的是值，`kkv` 却是一段还在等延续的计算，所以前面要接上 `neg²:id`。宏展开出来的，除了程序员写下的箭头，只有 `∘𝒦` 和一支什么也不做的 `neg²:id`，而 `∘𝒦` 又只由 `flip` 与复合拼成。它们只把箭头接起来，不改写箭头本身做的事。

宏充当编译器，把类似 ANF 的语法翻译成 $¬¬$ 编码的 CPS。

# 嵌入语言

手写的 CPS 版 `mul` 有两处要程序员亲自动手：正常路径上，每一步都要写出新的延续 `(λ (v) (k (* v r)))`；遇到零时，要手动改调 `a->⊥`。在嵌入语言里，前一件由 `anf:let*` 完成，后一件交给 `anf:let/cc` 捕获的延续。用到的宿主函数先经 `cps` 提升：

```racket
(define cps:+         (cps +))
(define cps:*         (cps *))
(define cps:zero?     (cps zero?))
(define cps:car       (cps car))
(define cps:cdr       (cps cdr))
(define cps:null?     (cps null?))
(define cps:display   (cps display))
(define cps:displayln (cps displayln))
```

它们都是 𝒦 的箭头，可以直接放进 `anf:let*` 和 `anf:if`。照一等控制一节的 `mul` 写一个嵌入语言的版本，它本身也是一支 𝒦 的箭头：

```racket
(: cps:mul (→ Real * (¬¬ Real)))
(define (cps:mul . r*)
  (anf:let/cc cps:return
    (: cps:loop (→𝒦 (Listof Real) Real))
    (define (cps:loop r*)
      (anf:if (cps:null? r*)
              (cps:*)
              (anf:let* ([r (cps:car r*)])
                (anf:if (cps:zero? r)
                        (cps:return r)
                        (anf:let* ([r* (cps:cdr r*)]
                                   [res (cps:loop r*)])
                          (cps:* res r))))))
    (cps:loop r*)))
```

`(cps:mul 1 2 3 4)` 交回的是一段等待延续的计算。宏把程序编译成了这样的编码，要运行它，还缺一个解释器：

```racket
(: anf:eval (∀ (a) (→ (¬¬ a) a)))
(define (anf:eval kka) (⊥->a (kka a->⊥)))
```

`anf:eval` 的类型是 $¬¬a → a$：接收一个编码后的程序，提供 `a->⊥` 作为终结延续，`⊥->a` 捕获答案。宏在展开时把程序编码为 $¬¬a$，`anf:eval` 在运行时交入终结延续。这和第一篇里操作系统运行程序是同一种分工：程序是一个 $¬¬\text{Byte}$，退出通道由操作系统在启动时交给它。`anf:eval` 扮演的就是操作系统。



```racket
> (anf:eval (cps:mul 1 2 3 4))
24
> (anf:eval (cps:mul 1 2 0 3 4))
0
```

`cps:loop` 和 `cps:car` 一样是 𝒦 的箭头，所以它的递归调用也写在 `anf:let*` 里。`anf:let/cc` 把当前延续交给程序，名字叫 `cps:return`。遇零时调用它，和手中的延续一节的 `cps:proc2` 一样，计算改走保存的延续，还没做完的乘法全部跳过。其余每一步的延续都由 `anf:let*` 接好，程序员不需要触碰。最后一步同时用到 `res` 和更早的 `r`：宏把后面的代码嵌进前面绑定的函数体，`r` 一路看得见，所以照样能写，只是这一段不再是一串首尾相接的 `∘𝒦`。

`cps:return` 只用来跳出循环。第一篇的阴阳谜题对延续要求更多：被捕获的延续要作为值传来传去，再被调用。`label` 和整个谜题在嵌入语言里写作：

```racket
(define (cps:label) (cps:call/cc cps:id))
```

`(cps:label)` 交回的是提升过的当前延续，和第一篇的 `(label)` 一样。谜题照原样写进 `anf:let*`：

```racket
> (anf:eval
   (anf:let* ([cps:yin (cps:label)])
     (cps:displayln #\@)
     (anf:let* ([cps:yang (cps:label)])
       (cps:display #\*)
       (cps:yin cps:yang))))
@
*@
**@
***@
****@
...
```

`cps:yin` 是提升过的延续，所以能像别的 𝒦 箭头一样直接调用。

## 计算的位置

新世界下的 Clavius 律一节问过：`cps:call/cc` 交给 `proc` 的否定，是从哪里来的？它来自参数 `kp`，`cps` 只是把它提升了一层。阴阳谜题把这样的 `kp` 捕获了下来：`(cps:label)` 和第一篇的 `(label)` 一样，把它所在的位置交给程序，`cps:yin`、`cps:yang` 各是一个被捕获下来的位置，可以传递，也可以调用。那么 `kp` 自己又是从哪里来的？

到这里为止，我们的注意力一直在否定类型上：`neg`、`flip`、`∘𝒦` 在 $¬$ 之间搬运箭头。`kp` 却是否定类型的一个具体元素：运行时的一条延续，标着程序走到的一个位置。要回答这个问题，得换个角度，来看这些元素，看程序运行时它们怎样变化。

没有被捕获的位置，也是这样的元素。回到开头 ANF 版的 `fib`：

```racket
(let* ([n-1 (- n 1)]
       [v   (fib n-1)]
       [n-2 (- n 2)]
       [w   (fib n-2)])
  (+ v w))
```

每个绑定处都有一个具体的延续，在等这个位置的结果：`w` 处的延续拿到 `w`，算出 `(+ v w)`，交给出口；`v` 处的延续拿到 `v`，接着算 `n-2` 和 `w`，最后同样交给出口。这些延续的类型都是 $¬\text{Natural}$，每一个都是这个类型的一个具体的值，也各自标出程序走到了哪里：等的是一个 $\text{Natural}$，等到以后接着做哪些事。把这样一处叫作一个**计算位置**。`(cps:label)` 把位置捕获下来；这里的位置没有被捕获，藏在嵌套的 `let` 里，标记的是同一种东西。

位置与位置之间，隔着一步计算。从 `n-2` 处到 `w` 处，中间一步是 `fib`：`n-2` 处的延续拿到值，先算 `fib`，再交给 `w` 处的延续。把两处的延续分别记作 `kn-2` 和 `kw`：

```racket
kn-2  =  (∘ kw fib)  =  ((neg fib) kw)
```

`(neg fib)` 的类型是 $¬\text{Natural} → ¬\text{Natural}$，在两个延续类型之间映射。前面只看过它的类型；这里交给它的是一个具体的值 `kw`，交出的是另一个具体的值 `kn-2`：它把一个计算位置，映射成另一个计算位置。一般地，一步 `f` 能把位置 `kp` 带到位置 `kq`，条件就是 `kp = ((neg f) kq)`，也就是 `(∘ kq f)`：前一处的延续，正是这一步接上后一处的延续。

这条等式有两种读法。构造时从右往左读：`(neg f)` 收到后一处的延续，交出前一处的延续。出口处的延续是 `k`：`fib` 的调用若就是整个程序，它就是程序的出口，第一篇里的 `exit`；在嵌入语言里，这个位置上是 `anf:eval` 交进来的终结延续 `a->⊥`。`(neg (λ (w) (+ v w)))` 把 `k` 变成 `w` 处的延续，`(neg fib)` 再把它变成 `n-2` 处的延续。整条链从出口开始，一环环向内建起来。

运行时从左往右读：`(kp p)` 就是 `(kq (f p))`，值走完 `f` 这一步，等着它的延续就从 `kp` 换成了 `kq`。`(- n 2)` 的结果交给 `n-2` 处的延续，值从这里出发，算完 `(fib n-2)` 抵达 `w` 处，再算完 `(+ v w)`，交给出口。出口的那条延续，在嵌入语言里就是终结延续 `a->⊥`，既是延续构造的起点，也是值移动的终点：计算开始时交进来的是它，计算最后抵达的也是它。执行一个程序，就是顺着 `let*` 链，从一个位置走到下一个位置。`cps:yin` 捕获的 `kp`，就是这样一条链上的一环：它从出口那条延续一步步接出来，出口那一条，是计算开始时交进来的。

# 编码与运行

阴阳谜题和 `cps:mul` 用的是同一套宏、同一个 `cps:call/cc`。`cps:mul` 遇零就跳出循环，用的是第一篇里要靠 `call/cc` 才写得出来的控制，宿主的 `call/cc` 却一次也没有出现。阴阳谜题同样没有用到宿主的 `call/cc`，可它每走一步都往外打印字符，而且永远不会结束。说这些控制是用纯函数写出来的，纯的究竟是哪一部分？

先把宿主拆成两部分。完整的宿主仍叫 𝒞，`call/cc`、`raise`、`exit`、`display` 都在里面。从中只留下没有可观察的副作用、在合法输入上总会返回的程序，记作 𝒟；作为参数交进来的函数，也要在 𝒟 里。𝒟 是 𝒞 的一部分，箭头还是普通的函数类型，和 𝒞 用同样的类型别名：两者的区别不在类型上，在于允许写哪些宿主程序。别名不会检查这些条件，它们要靠程序怎样写成来保证。𝒟 的箭头在 𝒞 里同样合法：

```racket
(define-type (→𝒟 p q) (→ p q))

(: inj (∀ (p q) (→ (→𝒟 p q) (→𝒞 p q))))
(define (inj f) f)
```

`inj` 把 𝒟 的箭头原样放进 𝒞，什么也不改。

## 否定翻译

要看清纯在哪里，先看 `cps:mul` 是从什么改写来的。用宿主自己的 `let/cc`、`let*`、`if` 和原语，把同一个 `mul` 写一遍：

```racket
(: mul/cc (→ Real * Real))
(define (mul/cc . r*)
  (let/cc return
    (: loop (→ (Listof Real) Real))
    (define (loop r*)
      (if (null? r*)
          (*)
          (let* ([r (car r*)])
            (if (zero? r)
                (return r)
                (let* ([r* (cdr r*)]
                       [res (loop r*)])
                  (* res r))))))
    (loop r*)))
```

它和 `cps:mul` 算出同样的结果，遇零照样提前跳出：

```racket
> (mul/cc 1 2 3 4)
24
> (mul/cc 1 2 0 3 4)
0
```

和嵌入语言一节的 `cps:mul` 一行行对照，程序的结构一模一样，换掉的只有三样：`let/cc` 换成了 `anf:let/cc`，`let*`、`if` 换成了 `anf:let*`、`anf:if`，原语换成了提升过的 `cps:car`、`cps:*` 这些。这几处替换是我们亲手做的；宏做的，是把替换后的各步接起来。

接口也跟着变了。`mul/cc` 收到乘数，交出乘积；`cps:mul` 收到同样的乘数，交出一段等待延续的计算：一个是 $a → b$，一个是 $a → ¬¬b$。控制的做法也换了。`mul/cc` 遇零时，调用的是 `let/cc` 从宿主那里捕获的延续；`cps:mul` 的 `cps:return` 却是 `cps:call/cc` 交到程序手里的参数，新世界下的 Clavius 律一节看过，`cps:call/cc` 是一个纯 λ 项。

普通的输入，可以直接交给 `cps:mul`。可改写后的程序里，每一步的输入往往还在前一段计算里：`anf:let*` 每个绑定的右边，交来的都是一段计算。这样的一步怎样接上去？还用接上一段计算一节的例子：`kk3` 是 `(cps:+ 1 2)` 算出的计算，`cps:mul3` 是 `(cps mul3)`。交给它一个延续 `k`，照 `∘𝒦` 展开：

```racket
  (((∘𝒦 cps:mul3 neg²:id) kk3) k)
= (kk3 (λ (v) ((cps:mul3 v) k)))
= (kk3 (λ (v) (k (mul3 v))))
= (kk3 ((neg mul3) k))
= (((neg (neg mul3)) kk3) k)
```

第一行到第二行是接上一段计算一节的展开。第三行拆开 `cps:mul3`：它收到 `v` 和 `k`，就是 `(k (mul3 v))`。第四行是 `neg` 的定义：`(neg mul3)` 收到 `k`，把 `mul3` 接在它前面。最后一步又是一次 `neg`，这回站在延续位置上的是 `kk3`。$¬¬\text{Nat}$ 就是 $¬(¬\text{Nat})$，`kk3` 本身就是一条等着 $¬\text{Nat}$ 的延续，而 `((neg mul3) k)` 正是一个 $¬\text{Nat}$。

两次 `neg` 接起来，记作 `neg²`。第二次 `neg` 收到的是 𝒰 的箭头 `(neg mul3)`，这是 `neg` 的第二种读法：类型 $(¬q → ¬p) → (¬¬p → ¬¬q)$，仍然是一条逆否律。

```racket
(: neg² (∀ (p q) (→ (→𝒟 p q) (→𝒟 (¬¬ p) (¬¬ q)))))
(define neg² (∘ neg neg))
```

输入还在一段计算里时，接上一个提升过的纯函数，就是对它用一次 `neg²`：`(∘𝒦 cps:mul3 neg²:id)` 就是 `(neg² mul3)`。接上一段计算一节那道练习也有了答案：`neg²:id` 就是 `(neg² id)`，`id` 接在延续前面，接两层也什么都没改。

函数体里若有控制，比如调用了 `cps:return`，就没有一个 `mul3` 可拆，第三行走不通。可第二行到第四行做的，只是把 `(λ (v) ((cps:mul3 v) k))` 写成一个收到 `k` 才交出的延续，这件事 `flip` 对任何 `cps:kv` 都做得到：`(flip cps:kv)` 先收延续、后收值，`((flip cps:kv) k)` 就是那个 λ。对 `cps:mul3`，`(flip cps:mul3)` 正是 `(neg mul3)`：`cps` 是 `(∘ flip neg)`，两次 `flip` 相消。`(neg mul3)` 的位置由 `(flip cps:kv)` 接替，一般的绑定是：

```racket
(∘𝒦 cps:kv neg²:id)  =  (neg (flip cps:kv))
```

绑定所做的，只是用 `flip` 换一次参数顺序，再用一次 `neg`。

这就看得出纯在哪里了。`neg`、`flip`、`cps`、`∘𝒦`、`cps:call/cc`、`neg²` 都由 λ、函数应用、复合，以及有限参数表上的 `apply`、`map`、`reverse` 写成，自己不跳转，也不输出：交给它们的函数在 𝒟 里，得到的也在 𝒟 里。`cps:mul` 用到的原语都是纯函数，`car`、`cdr` 只在 `null?` 判过非空以后调用；`cps:loop` 是递归的，但每次处理更短的有限列表。所以 `cps:mul` 整个落在 𝒟 里。阴阳谜题的控制部分同样是纯的；它的输出来自宿主的 `display`，不终止来自程序本身，这两样在 𝒟 之外，不是改写带进来的。

第一篇结尾说过，经典的控制流可以编码成显式的延续传递，这种编码叫作**否定翻译**（negative translation）。逻辑里，它把经典证明系统地改写成直觉主义证明。从 `mul/cc` 到 `cps:mul`，我们对程序做的正是这样一次改写：控制操作换成纯的 CPS 构造，原语换成提升过的箭头，类型从 $a → b$ 变成 $a → ¬¬b$，各步再由宏用 `∘𝒦` 接起来。新世界下的 Clavius 律一节把一条经典定律换到 𝒦 里写，这里换的是整段程序。改写要落在程序本身：把 `mul/cc` 原样包一层 `cps`，里面的 `let/cc` 照样会去捕获宿主的延续。

经典的控制写成了 𝒟 里的纯程序，代价是结果的类型裹上一层 $¬¬$。裹着 $¬¬$ 的程序，还得有人来运行。

## 填上延续参数

𝒦 的箭头等着一个延续参数，运行时总得有人把它填上。`anf:eval` 填的是终结延续 `a->⊥`。把它放进一个普通的宿主表达式里：

```racket
> (+ 1 (anf:eval (cps:mul 1 2 3 4)))
25
> (+ 1 (anf:eval (cps:mul 1 2 0 3 4)))
1
```

两条路都回到了 `(+ 1 _)`。可 `anf:eval` 交进去的是 `a->⊥`，它一调用就 `raise`，不会返回。乘积是怎么回到加 1 那里的？

靠的是外面那层 `⊥->a`。答案交给 `a->⊥`，`a->⊥` 把它抛出，`anf:eval` 里的 handler 接住，作为 `anf:eval` 的返回值交回调用处，加 1 接着做。遇零时，`cps:return` 改走的那条延续，最后也是 `a->⊥`。运行开始的那一刻，这段计算真正的去处，就是调用处之后的工作 `(+ 1 _)`。`anf:eval` 没有去捕获它，而是用 `raise` 与 handler 的跳转模拟了它。

宿主若有 `call/cc`，就不用模拟：`call/cc` 捕获的正是当前延续，可以直接作为实参，填进延续参数：

```racket
(: uncps (∀ (p q) (→ (→𝒦 p q) (→𝒞 p q))))
(define (uncps cps:f) (∘ call/cc cps:f))
```

`((uncps cps:f) x)` 先算出 `(cps:f x)`，一段等待延续的计算，再交给 `call/cc`，`call/cc` 把当前延续交给它。`uncps` 收 𝒦 的箭头，交出 𝒞 的箭头，也就是一个普通的宿主函数，可以放进同一个 `(+ 1 _)`：

```racket
> (+ 1 ((uncps cps:mul) 1 2 3 4))
25
> (+ 1 ((uncps cps:mul) 1 2 0 3 4))
1
```

结果和 `anf:eval` 那两行一样，这回却没有 handler 去接：正常乘完的 `24`，和遇零从 `cps:return` 跳出来的 `0`，交给的都是 `call/cc` 填进去的那条延续本身，也就是 `(+ 1 _)`。手中的延续一节在编码里实现 `call/cc`，把当前延续交给程序；这里用宿主的 `call/cc` 运行编码，把当前延续交进编码。

`anf:eval` 的类型 $¬¬a → a$，就是第一篇的 DNE；`uncps` 里那个 `call/cc`，类型也是 $¬¬q → q$。`uncps` 自己的类型展开是 $(p → ¬¬q) → (p → q)$：它的定义，就是在 $p → ¬¬q$ 的函数后面接一次这样的 DNE。

宿主函数经 `cps` 提升，再经 `uncps` 放回，还是原来那个吗？`cps:id` 的类型 $a → ¬¬a$ 是第一篇的 DNI。对纯函数 `f`，`(cps f)` 与 `(∘ cps:id f)` 行为相同，都是先 `f`，再 `cps:id`；两者只差在 `f` 什么时候调用，`(cps f)` 等收到延续才调用，`(∘ cps:id f)` 一收到参数就调用，纯函数看不出这个差别。`(cps f)` 是 `f` 之后接 DNI，`uncps` 再接上 DNE：

```racket
((uncps (cps f)) . p*)  =  (call/cc ((cps f) . p*))
                        =  (call/cc (λ (kq) (kq (f . p*))))
                        =  (f . p*)
```

第三步是第一篇「那条看不见的延续」里的论证：`(kq …)` 处在尾位置，`call/cc` 捕获的延续就是它自己的延续，显式调用和正常返回汇入同一个出口。对这里用 `call/cc` 实现的 DNE，DNI 接上它就是恒等。

---

# 结论

新世界下的 Clavius 律一节问的那件事，到这里可以答完了。交给 `proc` 的否定来自参数 `kp`。计算的位置一节从右往左读过 `kp = ((neg f) kq)`：在这里的纯编码中，每一处的延续，都是从出口那条延续出发，由 `neg` 这样的纯构造一环环接出来的。出口那一条，运行时由 `anf:eval` 或 `call/cc` 交进来。

第一篇的分水岭把控制分成两列：只消耗交到手里的否定，普通函数就写得出；要凭空造出一个非空类型的否定，就必须捕获。这条分界线还在，只是挪到了程序的边界上。边界以内，消耗、变换延续的工作，`neg`、`flip`、`∘𝒦`、`cps:call/cc`，全都是 𝒟 里的纯函数，控制只是在已有的延续之间选一条来调用。边界上，这里的纯编码运行一次，需要宿主提供一条终结延续：`anf:eval` 交入现成的 `a->⊥`，再用 handler 接回答案；`uncps` 交入 `call/cc` 捕获的当前延续。

这就是第一篇那个问题的回答：经典的控制有了纯的 CPS 表示，留在程序里面；提供终结延续、运行编码并把答案交回宿主的 DNE，留在了编码之外的运行边界上。

## 未解的线索

$¬¬a$ 仍然不是 $a$。展开别名：$¬¬a = (a → ⊥) → ⊥$，它是一个等待延续的函数。要从中取出 $a$ 类型的结果，必须向它交一条 $a → ⊥$ 类型的延续。第一篇说过，只用 λ 和函数调用，写不出非空类型的否定。𝒟 一般不能自行提供这条终结延续，也没有对任意类型都成立的纯函数，能从这里的双重否定编码中取回结果。

`anf:eval` 借来的那一条是 `a->⊥`。它的跳转来自 `raise`，而跳转函数的返回类型是 $⊥$，第一篇定义 `goto : Label → ⊥` 时就确立了这一点。`⊥->a` 再把答案接回来。按字面读，这对名字似乎在说 $a$ 和 $⊥$ 可以互相转化。但 $⊥$ 是空类型，没有值的类型，而 $a$ 是一个完全正常的、拥有值的类型。它们怎么可能互相转化？

开头的第二根线头问的也是 $⊥$：程序类型里的 $⊥$ 并不是世界的终结，进程终止以后，OS 还在运行。$⊥$ 到底是什么？

那是[另一篇文章](https://zhuanlan.zhihu.com/p/2032178684895946051)的故事了。

---

# 完整代码参考

```racket
#lang typed/racket/no-check

(provide (all-defined-out))

(: ∘ (∀ (p ...) (→ (→ pn-1 pn) ... (→ p1 p2) (→ p1 pn))))
(define ∘ compose)
(define id (∘))
(define (list->values v*) (apply values v*))

(define-type (← q p) (→ p q))
(: ⨾ (∀ (p ...) (→ (← pn-1 pn) ... (← p1 p2) (← p1 pn))))
(define (⨾ . f*) (apply ∘ (reverse f*)))


;;; 类型别名

(define-type ⊥ (∪))
(define-type (¬  a) (→ a ⊥))
(define-type (¬¬ a) (¬ (¬ a)))


;;; 答案类型（通过 raise 实现终结延续）

(struct (r) ans ([a* : (Listof r)]) #:type-name Ans)
(: a->⊥ (∀ (a) (¬ a)))
(define (a->⊥ . a*) (raise (ans a*)))
(define-syntax-rule (⊥->a exp)
  (with-handlers ([ans? (∘ list->values ans-a*)]) exp))


;;; 宿主世界

(define-type (→𝒟 p q) (→ p q))
(define-type (→𝒞 p q) (→ p q))

(: inj (∀ (p q) (→ (→𝒟 p q) (→𝒞 p q))))
(define (inj f) f)

;;; 逆否世界

(define-type (→𝒰 p q) (← (¬ p) (¬ q)))
(define-type (¬𝒰 p)   (→𝒰 p ⊥))

(: neg (∀ (p q) (case→ (→ (→𝒞 p q) (→𝒰 p q))
                       (→ (→𝒰 p q) (→ (¬¬ p) (¬¬ q))))))
(define ((neg f) kq) (∘ kq f))

(: ∘𝒰 (∀ (p ...) (→ (→𝒰 pn-1 pn) ... (→𝒰 p1 p2) (→𝒰 p1 pn))))
(define ∘𝒰 ⨾)

(: neg:id (∀ (q) (→𝒰 q q)))
(define neg:id (∘𝒰))


;;; CPS 世界

(define-type (→𝒦 p q) (→ p (¬¬ q)))
(define-type (¬𝒦 p)   (→𝒦 p ⊥))

(: flip (∀ (p q) (case→ (→ (→𝒰 p q) (→𝒦 p q))
                        (→ (→𝒦 p q) (→𝒰 p q)))))
(define (((flip f) . y*) . x*) (apply (apply f x*) y*))

(: cps (∀ (p q) (→ (→𝒞 p q) (→𝒦 p q))))
(define cps (∘ flip neg))

(: ∘𝒦 (∀ (p ...) (→ (→𝒦 pn-1 pn) ... (→𝒦 p1 p2) (→𝒦 p1 pn))))
(define (∘𝒦 . cps:f*) (flip (apply ∘𝒰 (map flip cps:f*))))

(: cps:id (∀ (q) (→𝒦 q q)))
(define cps:id (∘𝒦))


;;; Clavius 律

(: neg:call/cc  (∀ (p) (→𝒰 (→𝒰 (¬𝒰 p) p) p)))
(: cps:call/cc  (∀ (p) (→𝒦 (→𝒦 (¬𝒦 p) p) p)))

(define ((neg:call/cc kp) neg:proc) ((neg:proc kp) (neg kp)))
(define ((cps:call/cc cps:proc) kp) ((cps:proc (cps kp)) kp))


;;; 两次逆否

(: neg² (∀ (p q) (→ (→𝒟 p q) (→𝒟 (¬¬ p) (¬¬ q)))))
(define neg² (∘ neg neg))


;;; anf: 宏

(define-syntax anf:let*-values
  (syntax-rules ()
    [(_ () b* ...)
     (anf:begin b* ...)]
    [(_ ([v* e]) b* ...)
     (let ([kkv e])
       (: neg²:id  (→𝒦 (¬¬ a) a))
       (: cps:kv   (→𝒦     a  b))
       (: cps:kkkv (→𝒦 (¬¬ a) b))
       (define (neg²:id kkv) kkv)
       (define (cps:kv . v*) (anf:begin b* ...))
       (define cps:kkkv (∘𝒦 cps:kv neg²:id))
       (cps:kkkv kkv))]
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

(define-syntax-rule (anf:let ([v e]) b* ...)
  (anf:let* ([v e]) b* ...))

(define-syntax-rule (anf:if test conseq alt)
  (let ([kkb test])
    (: neg²:id  (→𝒦 (¬¬ Boolean) Boolean))
    (: cps:kb   (→𝒦     Boolean  a))
    (: cps:kkkb (→𝒦 (¬¬ Boolean) a))
    (define (neg²:id kkb) kkb)
    (define (cps:kb . b*) (if (equal? b* '(#f)) alt conseq))
    (define cps:kkkb (∘𝒦 cps:kb neg²:id))
    (cps:kkkb kkb)))

(define-syntax-rule (anf:let/cc cps:k b* ...)
  (cps:call/cc (λ (cps:k) b* ...)))


;;; 填上延续参数

(: anf:eval (∀ (a) (→ (¬¬ a) a)))
(define (anf:eval kka) (⊥->a (kka a->⊥)))

(: uncps (∀ (p q) (→ (→𝒦 p q) (→𝒞 p q))))
(define (uncps cps:f) (∘ call/cc cps:f))


;;; CPS 提升的基本操作

(define cps:+         (cps +))
(define cps:*         (cps *))
(define cps:zero?     (cps zero?))
(define cps:car       (cps car))
(define cps:cdr       (cps cdr))
(define cps:null?     (cps null?))
(define cps:display   (cps display))
(define cps:displayln (cps displayln))
```
