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

从类型看，复合是把首尾相接的箭头拼成一支：`(∘ g f)` 里，`f` 从 `p1` 到 `p2`，`g` 从 `p2` 到 `p3`，拼起来就是从 `p1` 到 `p3`。`⨾` 也是拼接，只是参数的次序反了过来，拼的是反着写的箭头。把箭头反着写，结果在左边，参数在右边，记作 `←`：`(← q p)` 就是 `(→ p q)`。用 `→` 写出两支的 `∘` 的类型，用 `←` 写出两支的 `⨾` 的类型，两行只差把 `→` 换成 `←`：

```racket
(define-type (← q p) (→ p q))

(: ∘ (∀ (p1 p2 p3) (→ (→ p2 p3) (→ p1 p2) (→ p1 p3))))
(: ⨾ (∀ (p1 p2 p3) (→ (← p2 p3) (← p1 p2) (← p1 p3))))
(define (⨾ . f*) (apply ∘ (reverse f*)))
```

读 `⨾` 那一行：第一支 `(← p2 p3)` 从 `p3` 到 `p2`，先算；第二支 `(← p1 p2)` 从 `p2` 到 `p1`，后算；拼成从 `p3` 到 `p1`。`⨾` 只是把参数顺序倒过来的 `∘`，两条运算律原样继承下来，`(⨾)` 也是 `id`。

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

# 把延续独立出来

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

拿 `+` 各走一遍。`(cps +)` 先收操作数 `1`、`2`，交出一个等着延续的值；再交给它一个延续，计算才开始。`(neg +)` 次序反过来，先收延续，再收操作数：

```racket
> (⊥->a (((cps +) 1 2) (λ (v) (a->⊥ (* v 10)))))
30
> (⊥->a (((neg +) (λ (v) (a->⊥ (* v 10)))) 1 2))
30
```

操作上一样，类型却不同：

```racket
(: neg (∀ (p q) (→ (→ p q) (→ (¬ q) (¬ p)))))
(: cps (∀ (p q) (→ (→ p q) (→    p (¬¬ q)))))
```

两者的差别只在柯里化的方向：延续在前还是在后。既然是参数顺序的差别，交换顺序就能在两种写法之间来回：

```racket
(: flip (∀ (x y z) (→ (→ x (→ y z)) (→ y (→ x z)))))
(define (((flip f) . y*) . x*) (apply (apply f x*) y*))
```

`flip` 交换参数顺序，对任何两层柯里化的函数都适用。`neg` 产出的 $¬q → ¬p$ 展开是 $¬q → p → ⊥$，正是这样的两层函数，`flip` 把它变成 $p → ¬¬q$；反过来，又把 $p → ¬¬q$ 变回 $¬q → ¬p$。对纯函数来说，交换两次参数顺序就回到原处，所以 `flip` 是它自己的逆：在两种写法之间来回，什么也不会丢失。

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

## 手中的延续

第一篇用 `cc` 实现 `call/cc`：先由 `(cc)` 取得当前延续，再把它交给 `proc`。在 CPS 里，这一步不必做。一等控制一节说过，当前延续已经是一个显式的参数：照 `cps` 的写法也好，照 `neg` 的写法也好，函数收到的延续参数，就是这次调用之后要做的事。那么照这两种写法，`call/cc` 该怎么写？

照 `call/cc` 自己的意思写，先看它收到什么。`cps:call/cc` 照 `cps` 的写法，先收到输入 `cps:proc`，再收到延续 `kp`；`neg:call/cc` 照 `neg` 的写法，次序反过来，先收到 `kp`，再收到 `neg:proc`：

```racket
(define ((cps:call/cc cps:proc) kp) ...)
(define ((neg:call/cc kp) neg:proc) ...)
```

`kp` 就是当前延续，要做的是把它交给 `proc`。两个 `proc` 也照同一种写法写成，收到的参数将来也要照这种写法来调用。`kp` 却是宿主里的一条延续，收到值就交出去，没有那一层延续参数，形状对不上，所以先提升一份再交出去：`cps` 的写法里用 `cps`，`neg` 的写法里用 `neg`。`proc` 算出来的仍是一段等着延续的计算，另一份 `kp` 留下来，交给它，接住它正常交回的结果。两者只差在次序：`cps:proc` 先收提升过的 `(cps kp)`，再收留下的 `kp`；`neg:proc` 反过来，先收留下的 `kp`，再收提升过的 `(neg kp)`。两个定义写完整：

```racket
(define ((cps:call/cc cps:proc) kp) ((cps:proc (cps kp)) kp))
(define ((neg:call/cc kp) neg:proc) ((neg:proc kp) (neg kp)))
```

两行里都有两份 `kp`，角色不同：提升过的那一份交给 `proc` 当参数，`proc` 调用它，就是逃逸；原样的那一份是 `proc` 正常交回时的出口。

跑一个很短的例子。在 `cps:call/cc` 后面接一步加 1，交给它的 `proc` 不理会收到的延续，只算 `2` 乘 `3`。后面那一步加 1 也得写成延续：拿到结果，加 1，再交给终结延续：

```racket
> (define (cps:proc1 cps:k) ((cps *) 2 3))
> (⊥->a ((cps:call/cc cps:proc1) (λ (v) (a->⊥ (add1 v)))))
7
```

`cps:proc1` 正常交回 `6`。留下的那份 `kp`，也就是手写的那个 λ，接住它，先加 1，再交给终结延续，得到 `7`。

换一个 `proc`，让它用上收到的延续：先把 `10` 交给 `cps:k`，再加 1。`cps:k` 收到 `10`，交出的仍是一段等着延续的计算，后面的加 1 只能再手写一个延续接上：

```racket
> (define (cps:proc2 cps:k) (λ (k) ((cps:k 10) (λ (v) (k (add1 v))))))
> (⊥->a ((cps:call/cc cps:proc2) (λ (v) (a->⊥ (add1 v)))))
11
```

结果是 `11`，不是 `12`。`cps:k` 是提升过的 `kp`，一调用，计算就改走 `kp`：外面那一步加 1，然后是终结延续。`cps:proc2` 里排在后面的那一步加 1，再也轮不到。这正是第一篇里 `call/cc` 的行为：调用交出去的延续，就是丢下手头的工作，回到 `call/cc` 之后。

> **练习：** 用 `neg:call/cc` 把这两个例子各跑一遍，结果仍是 `7` 和 `11`。提示：`neg` 的写法先收延续，再收输入；外面那一步加 1，用 `(neg add1)` 接在终结延续前面。

第一篇里，当前延续要靠 `cc` 或 `call/cc` 在运行时捕获。`cps:call/cc` 却什么也没有捕获：它交给 `proc` 的延续，就是自己收到的参数 `kp`。那么 `kp` 又是谁给的？

另一件事也很明显。这么短的两个例子，延续却得一个个手写：外面的加 1 一个，`cps:proc2` 里又一个。一等控制一节那句抱怨，到这里更重了：每个延续都得亲手写。

# 再次隐藏延续

回想开头的观察。`let` 脱糖为 lambda 调用，延续藏在 `let` 里面：等待结果的那个 λ 不用我们写，绑定的语法替我们写了。CPS 变换把延续拉出来变成显式参数，这个 λ 就得亲手写。能不能反过来：用 `let` 语法把 CPS 的延续再藏回去？

先看一个具体例子。把加法和乘法用 `cps` 提升：

```racket
(define cps:+ (cps +))
(define cps:* (cps *))
```

想计算 `(1 + 2) × 3`。像 `fib/k` 那样手写延续：`(cps:+ 1 2)` 的延续拿到 `v`，交给 `(cps:* v 3)`，结果再交给最外面的 `k`：

```racket
> (⊥->a ((λ (k)
           ((cps:+ 1 2)
            (λ (v)
              ((cps:* v 3) k))))
         a->⊥))
9
```

想要的是像 `let` 一样给中间结果起名，λ 由语法替我们写：

```racket
(anf:let ([v (cps:+ 1 2)])
  (cps:* v 3))
```

它的意思应当和上面手写的一样。

## 对不上的两段

先试着把 `anf:let` 当作 `let` 来读。延续与 CPS 一节把 `let` 拆成过一次调用：

```racket
  (let ([v e]) b)
= ((λ (v) b) e)
= (let ([k (λ (v) b)]) (k e))
= ((λ (k) (k e)) (λ (v) b))
```

`let` 手里有两样东西：等着结果的 `k`，和右边算出的值 `e`。直接调用 `(k e)`，类型对得上。照样拆 `anf:let`，手里也有两样：函数体包成的 `(λ (v) (cps:* v 3))`，把前面的 `mul3` 提升成 `(cps mul3)`，记作 `cps:mul3`，它就是这个 λ；右边 `(cps:+ 1 2)` 算出的值，记作 `kk3`（两个 `k` 对应 $¬¬$ 的两层）。可 `(cps:mul3 kk3)` 对不上：`cps:mul3` 要的是一个数，`kk3` 却是一段还在等延续的计算，延续拿到的才是 `3`。

步数多了也一样。照 `let*` 读，三步的

```racket
(anf:let* ([y (cps:f x)]
           [z (cps:g y)])
  (cps:h z))
```

该对应开头那样的复合 `((∘ cps:h cps:g cps:f) x)`。`let*` 给复合的中间结果起名，可这里每一步交出的都是一段计算：`cps:f` 交出的是 `kky`，不是 `y`。手里有 `cps:g` 和 `kky`，类型对不上，没法调用。

可以先试着从计算中取出值，再交给下一步。但宏要对任意类型都适用，这就要求一个对任意 $a$ 都成立的 $¬¬a → a$，也就是第一篇的 DNE；只用纯函数，给不出这样的操作。

那就反过来，改造下一步，让它直接接收这段计算。`cps:g` 从 $q$ 到 $¬¬r$：收一个值，交出一段计算。要的是一个从 $¬¬q$ 到 $¬¬r$ 的函数：吃掉 `kky`，交出一段仍在等最终延续的计算。从要的类型倒着找：

- $¬¬q$ 就是 $¬(¬q)$。`neg` 把 $a → b$ 变成 $¬b → ¬a$；交给它一个 $¬r → ¬q$，交出的是 $¬¬q → ¬¬r$，正是要的。还是同一个 `neg`，只是交给它的函数形状不同，这是 `neg` 的第二种读法。
- $¬r → ¬q$ 又从哪里来？`cps:g` 的 $q → ¬¬r$ 展开是 $q → ¬r → ⊥$；`flip` 交换两层参数，得到 $¬r → q → ⊥$，也就是 $¬r → ¬q$。

所以先 `flip`，再 `neg`。交给它 `kky`，看它做了什么：

```racket
  ((neg (flip cps:g)) kky)
= (λ (k) (kky ((flip cps:g) k)))
= (λ (k) (kky (λ (y) ((cps:g y) k))))
```

第一行是 `neg` 的定义：`(neg h)` 收到 `kky`，交出 `(∘ kky h)`。最后一行正是手写的那种包法：`kky` 收到的延续，是下一步连同最外面的 `k` 包成的 λ。先 `flip`、再 `neg`，记作 `cps->neg²`：

```racket
(define cps->neg² (∘ neg flip))
```

`cps:g` 里可以有 `cps:call/cc` 这样的控制，`cps->neg²` 对它照样适用。

回到 `(1 + 2) × 3`。`cps:mul3` 是 `(cps mul3)`，把 `cps->neg²` 用在它上面，就能直接接上 `(cps:+ 1 2)` 算出的计算：

```racket
> (define cps:mul3 (cps (λ (v) (* v 3))))
> (⊥->a (((cps->neg² cps:mul3) (cps:+ 1 2)) a->⊥))
9
```

宏要写出的，就是这样一段代码：

```racket
(let ([kk3 (cps:+ 1 2)])
  (define (cps:mul3 v) (cps:* v 3))
  (define neg²:mul3 (cps->neg² cps:mul3))
  (neg²:mul3 kk3))
```

`neg²:mul3` 是接收计算的下一步，由 `cps->neg²` 从 `cps:mul3` 得到。右边不一定是一次调用，可以是任何算出一段计算的表达式；宏只需要它算出的 `kk3`，再把函数体包成的箭头交给 `cps->neg²`。

## 写成宏

把这段代码写成宏。`anf:let` 收一个绑定和一个函数体，函数体包成 `cps:kv`，交给 `cps->neg²`，再接上右边算出的计算：

```racket
(define-syntax-rule (anf:let ([v e]) b)
  (let ([kkv e])
    (define (cps:kv v) b)
    (define neg²:kv (cps->neg² cps:kv))
    (neg²:kv kkv)))
```

宏里定义的 `kkv`、`cps:kv`、`neg²:kv` 只在展开出的代码里可见，不会和程序员自己的名字相混。跑一下开头的例子：

```racket
> (⊥->a ((anf:let ([v (cps:+ 1 2)]) (cps:* v 3)) a->⊥))
9
```

宏展开出来的，除了程序员写下的箭头，只有 `cps->neg²`，而它只由 `flip` 与 `neg` 拼成。它只把箭头接起来，不改写箭头本身做的事。宏充当编译器，把类似 ANF 的语法翻译成 $¬¬$ 编码的 CPS。别的语法也照这个套路写，用到时再给。正文先给单值的简化版；附录的完整代码把同一种接法扩展到多值和多个表达式组成的函数体。

## 绑定就是复合

宏写好了，回头看它把两步接成了什么。展开 `anf:let`：

```racket
  (anf:let ([y (cps:f x)]) (cps:g y))
= ((cps->neg² cps:g) (cps:f x))
= ((∘ (cps->neg² cps:g) cps:f) x)
```

又是一次复合。照 `let` 读，本来该是 `((∘ cps:g cps:f) x)`，接不上；现在第一支保持不变，后一支把输入提升成 $¬¬$，普通的 `∘` 就接得上了。几步也一样：第一支不动，其余几支各经过一次 `cps->neg²`。这就是照 `cps` 写法的函数自己的复合，记作 `∘𝒦`（取 continuation 的字母）：

```racket
  (∘𝒦 cps:h cps:g cps:f)
= (∘ (cps->neg² cps:h) (cps->neg² cps:g) cps:f)
```

一支也不交时，它的单位元是 `cps:id`，收到 `x`，原样交给延续，和 `(cps id)` 做的事一样。写成代码，用 `split-at-right` 把最右边那一支分出来，它不动，其余的交给 `cps->neg²`：

```racket
(define cps:id (cps id))
(define (∘𝒦 . cps:f*)
  (if (null? cps:f*)
      cps:id
      (let-values ([(cps:g* cps:f) (split-at-right cps:f* 1)])
        (apply ∘ (append (map cps->neg² cps:g*) cps:f)))))
```

拿 `(1 + 2) × 3` 试一下：

```racket
> (⊥->a (((∘𝒦 cps:mul3 cps:+) 1 2) a->⊥))
9
```

和开头宿主的那条等式并排：

```racket
(let     ([y     (f x)])     (g y))  =  ((∘      g     f) x)
(anf:let ([y (cps:f x)]) (cps:g y))  =  ((∘𝒦 cps:g cps:f) x)
```

`let` 是 `∘` 的另一种写法，`anf:let` 是 `∘𝒦` 的另一种写法，多出来的是中间结果的名字。

开头的两条运算律，`∘𝒦` 也原样都有：分组无关紧要，`cps:id` 接在哪一头都不改变什么。拿 `cps:id` 接在右边试一次，交给它 `x` 和 `k`：

```racket
  (((∘𝒦 cps:f cps:id) x) k)
= (((cps->neg² cps:f) (cps:id x)) k)
= ((cps:id x) ((flip cps:f) k))
= (((flip cps:f) k) x)
= ((cps:f x) k)
```

第二行是 `cps->neg²` 的展开：`(cps:id x)` 收到的延续，是 `cps:f` 连同 `k` 包成的 λ。`cps:id` 把 `x` 原样交给它，最后就是 `cps:f` 收到 `x`，再收到 `k`。

> **注意：** 上面的展开交齐了 `x` 和 `k`。只交 `x` 时，左边还没有调用 `cps:f`：`cps:f` 收到参数时若会做什么事，比如打印一行，就被推迟到了收到延续之后，两边不再相同。所以本文要求 𝒦 的箭头收到参数时只造出一个等待延续的函数，不做别的事。`cps` 造出的箭头都是这样，本文一直这样假定；在这个前提下，才把 `(∘𝒦 cps:f cps:id)` 和 `cps:f` 当作同一支函数。

三步写成一层层嵌在函数体里的 `anf:let`，展开出来是嵌套的 `cps->neg²`；它和上面排平的 `(∘𝒦 cps:h cps:g cps:f)` 相同，靠的正是结合律。只换名的绑定，对应接上 `cps:id`。

> **练习：** 照开头宿主的写法，写出两条结合律、两条单位律在 `anf:let` 下的四条等式；再展开 `∘𝒦` 与 `cps->neg²` 的定义，验证 `∘𝒦` 的两条运算律。

`∘𝒦` 里第一支保持不变。那么第一支若什么也不做，`∘𝒦` 给出的，就是 `cps->neg²` 本身。什么也不做的那一支，收下一段计算，原样交出：它就是 `id`，只是收的是 $¬¬$ 类型，记作 `neg²:id`：

```racket
(: neg²:id (∀ (q) (→ (¬¬ q) (¬¬ q))))
(define (neg²:id kkv) kkv)
```

它为什么能放进 `∘𝒦`？`cps:` 箭头收一个值，交出一段计算。`neg²:id` 收的值碰巧本身就是一段计算 $¬¬q$，交出的是同一段：把 $¬¬q$ 当作输入的类型，它就是一支从 $¬¬q$ 到 $q$ 的 `cps:` 箭头，不需要再提升。

```racket
(∘𝒦 cps:g neg²:id)  =  (∘ (cps->neg² cps:g) neg²:id)  =  (cps->neg² cps:g)
```

把一支箭头的输入提升成 $¬¬$，和在它前面接一支什么也不做的 `neg²:id`，是同一件事。

照 `neg` 写法的函数也有自己的复合。$¬q → ¬p$ 这种形状的箭头首尾相接，用开头的 `⨾` 就接得起来，单位元是 `id`：把延续独立出来一节的「接两次就是闭包链」，正是这样接的。

有了复合与单位元，两种写法的函数各自成了一个世界：照 `cps` 写法的叫 CPS 世界 𝒦，照 `neg` 写法的叫逆否世界 𝒰（U 取掉头转弯的意思：箭头的方向倒了过来）。为两种形状取个名字：

```racket
(define-type (→𝒦 p q) (→ p (¬¬ q)))
(define-type (→𝒰 p q) (← (¬ p) (¬ q)))
```

$p →_𝒦 q$ 收到 $p$，交出等着 $q$ 的计算。$p →_𝒰 q$ 用的是开头的反向箭头 `←`：它从 $p$ 写到 $q$，函数却从 $¬q$ 指向 $¬p$。有了名字，前面几个函数的类型可以重写，复合与单位元也补上类型：

```racket
(: neg  (∀ (p q) (→ (→ p q) (→𝒰 p q))))
(: cps  (∀ (p q) (→ (→ p q) (→𝒦 p q))))
(: flip (∀ (p q) (case→ (→ (→𝒰 p q) (→𝒦 p q))
                        (→ (→𝒦 p q) (→𝒰 p q)))))
(: cps->neg² (∀ (p q) (→ (→𝒦 p q) (→ (¬¬ p) (¬¬ q)))))

(: ∘𝒰 (∀ (p ...) (→ (→𝒰 pn-1 pn) ... (→𝒰 p1 p2) (→𝒰 p1 pn))))
(define ∘𝒰 ⨾)
(: neg:id (∀ (q) (→𝒰 q q)))
(define neg:id (∘𝒰))

(: ∘𝒦 (∀ (p ...) (→ (→𝒦 pn-1 pn) ... (→𝒦 p1 p2) (→𝒦 p1 pn))))
(: cps:id (∀ (q) (→𝒦 q q)))
(: neg²:id (∀ (q) (→𝒦 (¬¬ q) q)))
```

`case→` 列出同一个函数的几种类型，调用时按交给它的参数取用其中一种：这两行是 `flip` 同一段代码的两种读法，第一行从 𝒰 搬到 𝒦，第二行搬回来。普通函数经 `neg` 进入 𝒰，经 `cps` 进入 𝒦，`flip` 在两个世界之间来回。`cps->neg²` 是先用 `flip` 进 𝒰，再用一次 `neg`。

> **练习：** 𝒰 的复合也能搬到 𝒦 用：把几支 𝒦 的箭头各 `flip` 到 𝒰，用 `⨾` 接起来，再 `flip` 回来。展开两支的情形，验证得到的就是 `∘𝒦`。

手中的延续一节那两个手写的例子，有了 `∘𝒦`，就不必再手写延续了：

```racket
> (define cps:add1 (cps add1))
> (⊥->a (((∘𝒦 cps:add1 cps:call/cc) cps:proc1) a->⊥))
7
> (define (cps:proc2 cps:k) ((∘𝒦 cps:add1 cps:k) 10))
> (⊥->a (((∘𝒦 cps:add1 cps:call/cc) cps:proc2) a->⊥))
11
```

这一节出现的几样东西，各自收什么、交出什么：

| 名字                 | 收                       | 交出                     |
|----------------------|--------------------------|--------------------------|
| `cps:f`              | 值 $p$                   | 计算 $¬¬q$               |
| `(flip cps:f)`       | 延续 $¬q$                | 延续 $¬p$                |
| `(cps->neg² cps:f)`  | 计算 $¬¬p$               | 计算 $¬¬q$               |
| `cps:id`             | 值 $q$                   | 计算 $¬¬q$；收到延续后，把原值交给它 |
| `neg²:id`            | 计算 $¬¬q$               | 同一段计算               |
| `∘𝒦`                 | 几支 `cps:` 箭头         | 一支 `cps:` 箭头         |

# 嵌入语言

手写的 CPS 版 `mul` 有两处要程序员亲自动手：正常路径上，每一步都要写出新的延续 `(λ (v) (k (* v r)))`；遇到零时，要手动改调 `a->⊥`。在嵌入语言里，前一件交给绑定，后一件交给 `cps:call/cc` 交来的延续。用到的其余宿主函数，也先经 `cps` 提升：

```racket
(define cps:zero?     (cps zero?))
(define cps:car       (cps car))
(define cps:cdr       (cps cdr))
(define cps:null?     (cps null?))
(define cps:display   (cps display))
(define cps:displayln (cps displayln))
```

它们都是 𝒦 的箭头，可以直接放进绑定。写 `mul` 还要三样语法，都照 `anf:let` 的套路来。

几个绑定依次接起来，就是一层层嵌套的 `anf:let`：

```racket
(define-syntax anf:let*
  (syntax-rules ()
    [(_ () b) b]
    [(_ ([v e] [v* e*] ...) b)
     (anf:let ([v e]) (anf:let* ([v* e*] ...) b))]))
```

分支也一样：测试那一段算出的计算，交给 `cps->neg²` 接上下一步；下一步拿到测试的值，选一支分支：

```racket
(define-syntax-rule (anf:if test conseq alt)
  (let ([kkb test])
    (define (cps:kb b) (if b conseq alt))
    (define neg²:kb (cps->neg² cps:kb))
    (neg²:kb kkb)))
```

遇零跳出，要用 `cps:call/cc` 交来的延续。`anf:let/cc` 给它起个名字：

```racket
(define-syntax-rule (anf:let/cc cps:k b* ...)
  (cps:call/cc (λ (cps:k) b* ...)))
```

照一等控制一节的 `mul` 写一个嵌入语言的版本，它本身也是一支 𝒦 的箭头：

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

展开一层，`((cps:label) k)` 是 `((cps:call/cc cps:id) k)`，也就是 `((cps:id (cps k)) k)`：`cps:id` 把提升过的 `(cps k)` 原样交给 `k`。`(cps:label)` 交回一段等待延续的计算；运行时，它把提升过的当前延续 `(cps k)` 作为结果交给 `k`，和第一篇的 `(label)` 一样。绑定得到的 `cps:yin`、`cps:yang`，就是这样的值。谜题写进 `anf:let*`。中间还有打印：打印也是一步计算，只是结果用不着。一串计算依次做下去、只留最后一个的结果，就是 `anf:begin`：把前面的结果绑定到一个用不着的变量 `_` 上，忽略掉。

```racket
(define-syntax anf:begin
  (syntax-rules ()
    [(_ b) b]
    [(_ e b* ...) (anf:let ([_ e]) (anf:begin b* ...))]))
```

谜题于是照第一篇的样子写：

```racket
> (anf:eval
   (anf:let* ([cps:yin (cps:label)])
     (anf:begin
       (cps:displayln #\@)
       (anf:let* ([cps:yang (cps:label)])
         (anf:begin
           (cps:display #\*)
           (cps:yin cps:yang))))))
@
*@
**@
***@
****@
...
```

`cps:yin` 是提升过的延续，所以能像别的 𝒦 箭头一样直接调用。

## 计算的位置

手中的延续一节留下过一个问题：`cps:call/cc` 交给 `proc` 的延续，来自它收到的参数 `kp`，`cps` 只是把它提升了一层；那么 `kp` 又是谁给的？阴阳谜题把这样的 `kp` 捕获了下来：`(cps:label)` 和第一篇的 `(label)` 一样，把它所在的位置交给程序，`cps:yin`、`cps:yang` 各是一个被捕获下来的位置，可以传递，也可以调用。

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

先把宿主拆成两部分。完整的宿主记作 𝒞，`call/cc`、`raise`、`exit`、`display` 都在里面。从中只留下没有可观察的副作用、在合法输入上总会返回的程序，记作 𝒟；作为参数交进来的函数，也要在 𝒟 里。𝒟 是 𝒞 的一部分，箭头还是普通的函数类型，和 𝒞 用同样的类型别名：两者的区别不在类型上，在于允许写哪些宿主程序。别名不会检查这些条件，它们要靠程序怎样写成来保证。𝒟 的箭头在 𝒞 里同样合法：

```racket
(define-type (→𝒞 p q) (→ p q))
(define-type (→𝒟 p q) (→ p q))

(: inj (∀ (p q) (→ (→𝒟 p q) (→𝒞 p q))))
(define (inj f) f)
```

`inj` 把 𝒟 的箭头原样放进 𝒞，什么也不改。

## 改写 `mul`

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

接口也跟着变了。`mul/cc` 收到乘数，交出乘积；`cps:mul` 收到同样的乘数，交出一段等待延续的计算：一个是 $a → b$，一个是 $a → ¬¬b$。控制的做法也换了。`mul/cc` 遇零时，调用的是 `let/cc` 从宿主那里捕获的延续；`cps:mul` 的 `cps:return` 却是 `cps:call/cc` 交到程序手里的参数，而 `cps:call/cc` 的定义只用了 λ 和函数调用。

各步又是怎样接起来的？`anf:let*` 每个绑定的右边交来的都是一段计算，宏用 `cps->neg²` 把下一步的输入提升成 $¬¬$。调用了 `cps:return` 的步骤含控制，用的就是 `cps->neg²` 本身。下一步若是一个纯函数 `g` 的提升 `(cps g)`，`(flip (cps g))` 就是 `(neg g)`，两次 `flip` 相消，接法正好是两次 `neg`。两次 `neg` 接起来，记作 `neg²`：

```racket
(define neg² (∘ neg neg))
```

```racket
(cps->neg² (cps g))  =  (neg² g)
```

> **练习：** `neg²:id` 名字里的 `neg²` 是怎么来的？验证 `neg²:id` 与 `(neg² id)` 行为相同。

`neg²` 只用 `neg`，`neg` 只做复合。交给 `neg²` 的函数是纯的，得到的也是纯的，`neg²` 的类型于是可以写成：

```racket
(: neg² (∀ (p q) (→ (→𝒟 p q) (→𝒟 (¬¬ p) (¬¬ q)))))
```

这就看得出纯在哪里了。`neg`、`flip`、`cps`、`cps->neg²`、`∘𝒦`、`cps:call/cc`、`neg²` 都由 λ、函数应用、复合，以及有限参数表上的 `apply`、`map`、`append`、`split-at-right` 写成，自己不跳转，也不输出：交给它们的函数在 𝒟 里，得到的也在 𝒟 里。`cps:mul` 用到的原语都是纯函数，`car`、`cdr` 只在 `null?` 判过非空以后调用；`cps:loop` 是递归的，但每次处理更短的有限列表。所以 `cps:mul` 整个落在 𝒟 里。

阴阳谜题的控制部分同样是纯的；它的输出来自宿主的 `display`，不终止来自程序本身，这两样在 𝒟 之外，不是改写带进来的。

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

宿主函数经 `cps` 提升，再经 `uncps` 放回，还是原来那个吗？对纯函数 `f`，展开看：

```racket
((uncps (cps f)) . p*)  =  (call/cc ((cps f) . p*))
                        =  (call/cc (λ (kq) (kq (f . p*))))
                        =  (f . p*)
```

第三步是第一篇「那条看不见的延续」里的论证：`(kq …)` 处在尾位置，`call/cc` 捕获的延续就是它自己的延续，显式调用和正常返回汇入同一个出口。提起来再放回去，还是原来的函数。

# 箭头指向何方

第一篇的 `call/cc` 要靠宿主捕获延续；手中的延续一节的 `cps:call/cc` 却只用了 λ 和函数调用，什么也没有捕获。两者做的是同一件事：把当前延续交给 `proc`。它们究竟是同一个什么？照第一篇的办法，把类型读成命题。

## 读出命题

先读最早的两个。`neg` 和 `cps` 的类型，按照 Curry-Howard 对应，是两条直觉主义定理：

| 命题                  | 定理                                  |
|-----------------------|---------------------------------------|
| $(p → q) → (¬q → ¬p)$ | **逆否律**（*law of contraposition*） |
| $(p → q) → (p → ¬¬q)$ | **双重否定引入**（DNI）的推广形式     |

`flip` 的两行读法 $(¬q → ¬p) → (p → ¬¬q)$ 和 $(p → ¬¬q) → (¬q → ¬p)$，也都是直觉主义定理。三种箭头，各是一种命题形状：

| 世界       | 箭头类型            |
|------------|---------------------|
| 𝒞 宿主世界 | $p →_𝒞 q = p → q$   |
| 𝒦 CPS 世界 | $p →_𝒦 q = p → ¬¬q$ |
| 𝒰 逆否世界 | $p →_𝒰 q = ¬q → ¬p$ |

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

把宿主 𝒞 里的否定记作 `¬𝒞`，第一篇的 `call/cc` 的类型是：

```racket
(define-type (¬𝒞 p) (→𝒞 p ⊥))
(: call/cc (∀ (p) (→𝒞 (→𝒞 (¬𝒞 p) p) p)))
```

读作 $(¬p → p) → p$，Clavius 律。两个新 `call/cc` 的类型是同一条定律，只是 𝒞 换成了 𝒦、𝒰：它们是 Clavius 律在 𝒦、𝒰 里的样子。

可第一篇的分水岭说过：`call/cc` 要先凭空造出一个 $¬p$ 交给 `proc`，只用 λ 和函数调用写不出来，必须捕获。`cps:call/cc` 却只用了 λ。把 $→_𝒦$ 展开成宿主的箭头：

$$(¬_𝒦 p →_𝒦 p) →_𝒦 p \;=\; (¬_𝒦 p → ¬¬p) → ¬p → ⊥$$

$¬p$ 在箭头左边，是参数，就是 `kp`。宿主的 Clavius 律只收 `proc` 一个输入，手里没有否定，只能凭空去造；到了 𝒦 里，这个否定作为参数交了进来。交给 `cps:proc` 的 $¬_𝒦 p$，是 `cps` 从 `kp` 加工出来的。

这个 $¬_𝒦 p$ 能不能凭空造出来？$¬_𝒦 p$ 展开是 $p → ¬¬⊥$；手里若有一个 $¬¬⊥$ 的值，把类型为 $⊥ → ⊥$ 的 `id` 交给它，就得到 $⊥$ 的值，所以 $¬¬⊥$ 和 $⊥$ 一样空。对非空的 $p$，𝒦 里同样凭空造不出 $¬_𝒦 p$。

`cps:call/cc` 做的，是分水岭构造性那一侧的事：消耗交到手里的否定。

所以展开后的这条公式，已经不是宿主里的 Clavius 律，而是一条直觉主义定理：按照 Curry-Howard，它有闭合的、有类型的纯 λ 项，就是 `cps:call/cc`。`neg:call/cc` 也一样。同一条经典定律，换到 𝒦 或 𝒰 里写，就成了直觉主义定理。经典的控制并没有消失，宿主要捕获的那条延续，成了显式的参数。

## 否定翻译

`neg²` 的类型 $(p → q) → (¬¬p → ¬¬q)$ 也是一条逆否律，两次取逆否。运行的那一端也读得出来。`cps:id` 的类型 $a → ¬¬a$ 是第一篇的 DNI；`anf:eval` 的类型 $¬¬a → a$ 是 DNE，`uncps` 里那个 `call/cc` 也是。填上延续参数一节的往返，就是 `f` 之后接 DNI，再接上这里用 `call/cc` 实现的 DNE，接起来就是恒等。

`neg²:id` 的类型 $¬¬a →_𝒦 a$，看上去也像 DNE；展开到宿主，它却只是 $¬¬a$ 上的 `id`，什么也不运行。把它交给 `uncps`，得到的正是宿主的 `call/cc`：

```racket
(uncps neg²:id)  =  (∘ call/cc neg²:id)  =  call/cc
```

工作来自 `uncps` 里已有的 `call/cc`，不是 `neg²:id` 自己捕获了什么。

可前面说过，纯函数给不出对任意类型都成立的 DNE。这里却又出现了一个纯的。若交来的不是一段计算本身，而是一段会交出它的计算，就仍用 `cps->neg²` 接上 `neg²:id`。得到的 `(cps->neg² neg²:id)`，类型是 $¬¬¬¬a → ¬¬a$：它只接掉外面一层，结果仍在等待终结延续，并没有从 $¬¬a$ 中取出 $a$。对 $¬¬$ 形式的命题，这样的 DNE 可以用纯函数写出。

回头看，`cps:call/cc` 展示了一个控制构造怎样改写，`cps:mul` 展示了这些构造怎样连成整段程序。第一篇结尾说过，经典的控制流可以编码成显式的延续传递，这种编码叫作**否定翻译**（negative translation）。逻辑里，它把经典证明系统地改写成直觉主义证明。改写 `mul` 一节从 `mul/cc` 到 `cps:mul` 做的，正是这样一次改写：控制操作换成纯的 CPS 构造，原语换成提升过的箭头，类型从 $a → b$ 变成 $a → ¬¬b$，各步再由宏用 `∘𝒦` 接起来。上一节换的是一条经典定律，这里换的是整段程序。改写要落在程序本身：把 `mul/cc` 原样包一层 `cps`，里面的 `let/cc` 照样会去捕获宿主的延续。

---

# 结论

手中的延续一节问的那件事，到这里可以答完了。交给 `proc` 的延续来自参数 `kp`。计算的位置一节从右往左读过 `kp = ((neg f) kq)`：在这里的纯编码中，每一处的延续，都是从出口那条延续出发，由 `neg` 这样的纯构造一环环接出来的。出口那一条，运行时由 `anf:eval` 或 `call/cc` 交进来。

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

(: cps->neg² (∀ (p q) (→ (→𝒦 p q) (→ (¬¬ p) (¬¬ q)))))
(define cps->neg² (∘ neg flip))

(: cps:id (∀ (q) (→𝒦 q q)))
(define cps:id (cps id))

(: ∘𝒦 (∀ (p ...) (→ (→𝒦 pn-1 pn) ... (→𝒦 p1 p2) (→𝒦 p1 pn))))
(define (∘𝒦 . cps:f*)
  (if (null? cps:f*)
      cps:id
      (let-values ([(cps:g* cps:f) (split-at-right cps:f* 1)])
        (apply ∘ (append (map cps->neg² cps:g*) cps:f)))))

(: neg²:id (∀ (q) (→𝒦 (¬¬ q) q)))
(define (neg²:id kkv) kkv)


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
       (: cps:kv  (→      a  (¬¬ b)))
       (: neg²:kv (→ (¬¬ a) (¬¬ b)))
       (define (cps:kv . v*) (anf:begin b* ...))
       (define neg²:kv (cps->neg² cps:kv))
       (neg²:kv kkv))]
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
    (: cps:kb  (→ Boolean (¬¬ a)))
    (: neg²:kb (→ (¬¬ Boolean) (¬¬ a)))
    (define (cps:kb . b*) (if (equal? b* '(#f)) alt conseq))
    (define neg²:kb (cps->neg² cps:kb))
    (neg²:kb kkb)))

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
