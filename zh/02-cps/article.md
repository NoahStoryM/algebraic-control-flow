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

`let*` 的每个绑定从上到下依次执行，中间不跳跃。`fib` 中先算 `(fib n-1)` 再算 `(fib n-2)`，不再需要知道 Racket 的求值策略，代码本身就是策略的忠实记录。这种把所有中间计算命名、排成序列的形式叫作**A-范式**（*A-Normal Form*，ANF）。

但 `let` 不是什么新东西。它脱糖为 lambda 调用：

```racket
(let ([v e]) b)  =  ((λ (v) b) e)
```

每个 `let` 绑定都配着两样东西：一个被求值的**可归约式**（*reducible expression*，redex）`e`，和一个等待结果的函数 `(λ (v) b)`。后者接收 `e` 的值，然后执行剩余的计算。这个「等待结果并执行剩余计算的函数」，就是**延续**（continuation）。

`let` 的先后次序，也来自这次脱糖。调用 `((λ (v) b) e)` 时，先算出实参 `e`，再把结果绑定到形参 `v`，最后算函数体 `b`。所以 `(let ([v e]) b)` 总是先算 `e`，再算 `b`。

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

> **注意：** 后一步若用到前面不止一个名字，比如 `fib` 最后的 `(+ v w)`，就不只是一串函数首尾相接了：`v` 得一路带到最后。这里只看每一步只用到上一步结果的情形。

## 结合律与单位律

把计算写成 `let`，写法并不唯一。`fact`、`fib` 把每个新的 `let` 嵌在前一个 `let` 的函数体 `b` 里；可 `let` 里还有一处能放表达式，就是被求值的 `e`：同样几步，也可以先接成一段，嵌进 `e`。中间还可以插一个只给值换名的 `let`。ANF 本来是要把计算顺序写死的，写法一多，定下的还是同一个顺序吗？

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

再看只换名的 `let`。`let` 定下计算顺序，靠的是先算 `e`、后算 `b`。`(let ([y x]) (f y))` 把 `x` 改叫 `y` 再交给 `f`，`(let ([y (f x)]) y)` 给 `f` 的结果起名 `y` 再原样交出。两种写法里都只有 `f` 一步计算，没有先后可分，和直接写 `(f x)` 行为一样。

换名的那一步什么也不做，收到什么就原样交出什么。这样的函数，`∘` 自己就给得出来。`(∘ g f)` 把两个函数接成一个；只给一个，`(∘ f)` 就是 `f` 本身；一个也不给，`(∘)` 什么也没接上，收到什么就交出什么。把它记作 `id`：

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

从类型看，复合是把首尾相接的箭头拼成一支：`(∘ g f)` 里，`f` 从 `p1` 到 `p2`，`g` 从 `p2` 到 `p3`，拼起来就是从 `p1` 到 `p3`。`⨾` 也是拼接，只是参数的次序反了过来，拼的是反着写的箭头。把箭头反着写，结果在左边，参数在右边，记作 `←`：`(← q p)` 就是 `(→ p q)`。用 `→` 写出 `∘` 接两支时的类型，用 `←` 写出 `⨾` 接两支时的类型，两行只差把 `→` 换成 `←`：

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

那就让每个函数都额外接受这样一个参数 `k`，代表「我算完之后该做什么」。函数不再把值返回给调用者，而是直接交给 `k`。`fact` 的 CPS 版本：

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

读一下类型：`(→ Natural (¬ Natural) ⊥)`。接收一个自然数和一个延续 $¬\text{Natural}$，返回 $⊥$。函数不再「返回」值：它把结果交给延续，自己不再回来。

代码的形状变了。`fact/k` 的递归调用 `(fact/k (- n 1) (λ (v) ...))` 是整个 `if` 分支的最后一个动作，后面没有任何待执行的表达式。`fib/k` 也是：每个递归调用都处于尾位置。递归调用与对延续的调用，都成了尾调用。

当延续是显式参数时，「做完之后的事情」不再堆叠在调用栈上，而是编进了 `k` 这个闭包里。`fib/k` 递归时，`(λ (v) (fib/k (- n 2) (λ (w) (k (+ v w)))))` 把「等算完第一个分支，再递归第二个分支，最后加起来交给 k」整个未来打包进了一个函数。

拿 `(fact/k 3 k)` 跑一遍，看手里的延续怎么变。把 `(λ (v) (* 3 v))` 记作 `mul3`，其余类推：

```racket
  (fact/k 3 k)                                  =  (fact/k 3 (∘ k               ))
= (fact/k 2 (λ (v) ((∘ k          ) (* 3 v))))  =  (fact/k 2 (∘ k mul3          ))
= (fact/k 1 (λ (v) ((∘ k mul3     ) (* 2 v))))  =  (fact/k 1 (∘ k mul3 mul2     ))
= (fact/k 0 (λ (v) ((∘ k mul3 mul2) (* 1 v))))  =  (fact/k 0 (∘ k mul3 mul2 mul1))
= ((∘ k mul3 mul2 mul1) 1)
```

每递归一层，新的延续就是在旧的前面复合一次乘法。递归到底，交给延续的是 `1`：先乘 1，再乘 2，再乘 3，得到的 `6` 交给 `k`。调用栈没有增长，增长的是 `k` 前面这一串函数：它们是堆上的闭包，一环接一环，叫作**闭包链**。`k` 自己没有动过。

直接风格里也有不增长栈的写法：尾递归版本的 `fact` 用一个累积器。

```racket
(: fact (→ Natural Natural))
(define (fact n)
  (let loop ([n n] [acc 1])
    (if (= n 0)
        acc
        (loop (- n 1) (* n acc)))))
```

把它也变换成 CPS：

```racket
(: fact/k (→ Natural (¬ Natural) ⊥))
(define (fact/k n k)
  (let loop/k ([n n] [acc 1] [k k])
    (if (= n 0)
        (k acc)
        (loop/k (- n 1) (* n acc) k))))
```

同样拿 `(fact/k 3 k)` 跑一遍：

```racket
  (fact/k 3 k)
= (loop/k 3 (*      ) k)
= (loop/k 2 (*     3) k)
= (loop/k 1 (*   2 3) k)
= (loop/k 0 (* 1 2 3) k)
= (k (* 1 2 3))
```

循环体把 `k` 原样传下去，不再包上新的闭包。尾递归之所以不消耗栈空间，正因为它不创建新的延续：每一步复用同一个 `k`。非尾递归版本里闭包链的增长，对应着调用栈的增长。CPS 只是把这种增长从栈搬到了堆上。

ANF 命名中间值，让求值顺序显式；CPS 命名延续，让延续显式。

## 终结延续

CPS 函数需要一个延续才能启动。启动时交进去什么？

许多语言有一个内置的延续：`exit`，类型为 $¬\text{Byte}$。可以包装一下得到 $¬\text{Natural}$：

```racket
> (fact/k 5 (λ (ans) (displayln ans) (exit 0)))
120
```

结果打印出来了，进程也随之终止。`exit` 一调用，整段计算就到此为止。启动时交进去的这条延续，就是前面那条闭包链的终点：值走完整条链，最后抵达的是它，所以叫它终结延续。可是用 `exit` 做终结延续，进程一结束，就没法拿着结果继续工作。

我们需要另一个类型为 $a → ⊥$ 的函数：它不返回，也不杀死进程，而是把答案送到一个取得回来的地方。`raise` 正合适：它不返回，handler 又能捕获它抛出的值。再用一个专门的 struct，把我们的答案和别的异常区分开：

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

CPS 函数运行起来，`a->⊥` 充当终结延续，闭包链接在它前面一环环长出来；`⊥->a` 在外面接住答案。计算在 raise/handler 划出的边界内执行，结果穿过边界传出来。

## 一等控制

CPS 真正的力量不在于尾递归，而在于延续成了**一等值**。延续就是函数，可以存储、复制、丢弃，也可以改为调用另一个。`call/cc` 靠在运行时捕获当前延续，给了我们这种能力。在 CPS 里，当前延续已经是一个显式的参数。

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

正常路径上，累积的乘积沿着 `k` 交回去。遇到零时，跳过 `k`，直接调用 `a->⊥`。`k` 代表「继续乘下去然后返回结果」的延续；`a->⊥` 代表「直接跳出整个循环，把值交给 handler」的延续。选择调用哪一个，就是选择走哪条控制流。不需要 `call/cc`。延续是普通的函数，切换延续是普通的函数调用。

但代价也很明显：程序员必须亲手编写每一个延续，把 `k` 穿过每一层调用。能否自动化 CPS 包装？

---

# 把延续独立出来

给一个具体的函数写 CPS 包装，并不难。`zero?` 的 CPS 版本：

```racket
(define (zero?/k x k) (k (zero? x)))
```

`zero?/k` 在 `zero?` 的结果外面套一层 `k` 调用，就完成了包装。可这层包装，每个函数都得手写一遍。要自动化，就要一个通用的包装：交给它任意函数 `f`，交回 `f` 的 CPS 版本。

`zero?/k` 的两个参数是两种东西：`x` 交给 `zero?` 去算，`k` 只等着接住结果。通用的包装要把这两种参数分开处理，前一种原样交给 `f`，后一种接住 `f` 的结果。挤在同一层参数表里，它们就得一次交齐。柯里化让延续独占一层，和其余参数分开。延续独立在内层还是外层，操作上没有区别，函数体都一样：

```racket
(define (((cps f) . p*) kq) (kq (apply f p*)))   ; 延续在后
(define (((neg f) kq) . p*) (kq (apply f p*)))   ; 延续在前
```

这样的函数头是嵌套 λ 的简写：`(define (((cps f) . p*) kq) body)` 就是 `(define (cps f) (λ p* (λ (kq) body)))`，一层括号收一层参数，`. p*` 把其余参数收成列表，原样交给 `f`，不管 `f` 收几个参数。

拿 `+` 各走一遍。`(cps +)` 先收操作数 `1`、`2`，交出一个等着延续的值；再交给它一个延续，计算才开始。`(neg +)` 次序反过来，先收延续，再收操作数：

```racket
> (⊥->a (((cps +) 1 2) (λ (v) (a->⊥ (* v 10)))))
30
> (⊥->a (((neg +) (λ (v) (a->⊥ (* v 10)))) 1 2))
30
```

操作上一样，类型却不同：

```racket
(: cps (∀ (p q) (→ (→ p q) (→    p (¬¬ q)))))
(: neg (∀ (p q) (→ (→ p q) (← (¬ p) (¬ q)))))
```

`(cps f)` 先收操作数，交出的 $¬¬q$ 是一段还没开始的计算：`((cps +) 1 2)` 就是还没开始的 `(+ 1 2)`。第一篇里，这样的值有类型：程序就是一个 $¬¬\text{Byte}$，等操作系统交来 `exit` 才运行。

`(neg f)` 先收延续：交给它一条等 $q$ 的延续 `kq`，它交回一条等 $p$ 的延续：这条延续拿到 $p$，先交给 `f` 算出 $q$，再交给 `kq`。`f` 从 $p$ 到 $q$，`(neg f)` 却从 $¬q$ 到 $¬p$，方向反了过来，所以它的类型用开头的反向箭头 `←` 来写。

两者的差别只在柯里化的方向：延续在前还是在后。既然是参数顺序的差别，交换顺序就能在两种写法之间来回：

```racket
(: flip (∀ (x y z) (→ (→ x (→ y z)) (→ y (→ x z)))))
(define (((flip f) . y*) . x*) (apply (apply f x*) y*))
```

`flip` 交换参数顺序，对任何两层柯里化的函数都适用。`neg` 产出的 $¬q → ¬p$ 展开是 $¬q → p → ⊥$，正是这样的两层函数，`flip` 把它变成 $p → ¬¬q$；反过来，又把 $p → ¬¬q$ 变回 $¬q → ¬p$。只要两层 λ 之间不做别的事，`(flip (flip f))` 就和 `f` 行为一样：`flip` 是它自己的逆，在两种写法之间来回，什么也不会丢失。`neg`、`cps` 造出的函数都满足这一条。

有了 `flip`，`cps` 和 `neg` 可以互相定义：

```racket
cps  =  (∘ flip neg)
neg  =  (∘ flip cps)
```

> **练习：** 上面用 `flip` 在 `neg` 和 `cps` 之间来回。反过来，只用 `neg` 和 `cps`，写出 `flip`。提示：先想想 `(cps id)` 做了什么。

## 计算的位置

`neg` 的类型只说它在延续类型之间映射。$¬\text{Natural}$ 里装的是一条条具体的延续；一步计算，怎样把其中两条联系起来？

回头看 CPS 一节 `(fact/k 3 k)` 的展开。每递归一层，新的延续都是在旧的前面复合一次乘法：`k` 换成 `(∘ k mul3)`，再换成 `(∘ k mul3 mul2)`。收一条延续，在它前面复合一个函数，交出另一条延续，这正是 `neg` 做的事：`(neg f)` 收到等 $q$ 的延续，交出等 $p$ 的延续。照这个意思重写 `neg`，得到的和前面的定义是同一个函数，只是可变参数交给 `∘` 去处理：

```racket
(define ((neg f) kq) (∘ kq f))
```

于是递归的每一层都是一次 `neg`：第一层用 `(neg mul3)`，第二层用 `(neg mul2)`，第三层用 `(neg mul1)`。递归到底时的那条链，就是三次 `neg` 依次用在 `k` 上：

```racket
  (∘ k mul3 mul2 mul1)
= ((neg mul1) ((neg mul2) ((neg mul3) k)))
= ((∘ (neg mul1) (neg mul2) (neg mul3)) k)
```

`(neg mul3)` 最先用，`mul3` 紧挨着 `k`；`(neg mul1)` 最后用，`mul1` 排在最前。几次 `neg` 用 `∘` 接起来，次序和里面的乘法正好相反。整条闭包链从 `k` 开始，一环环向内建起来。`k` 是出口：`(fact/k 3 k)` 若就是整个程序，它就是程序的出口，第一篇里的 `exit`；启动时交进去的若是终结延续 `a->⊥`，它就是 `a->⊥`。

以上是链的构造。运行时，值又怎样沿着它走？开头说过，`let*` 就是复合。反过来，把这条闭包链拆回 `let*`，给中间结果起名，值从 `v0` 出发：

```racket
  ((∘ k mul3 mul2 mul1) v0)
= (let* ([v1 (mul1 v0)]
         [v2 (mul2 v1)]
         [v3 (mul3 v2)])
    (k v3))
```

每个名字处都有一条延续在等它：等 `v3` 的是 `k`，等 `v2` 的是先乘 3 再交给 `k`，依次类推。把等 `vn` 的那一条记作 `kn`：

```racket
k3  =  (∘ k               )
k2  =  (∘ k mul3          )
k1  =  (∘ k mul3 mul2     )
k0  =  (∘ k mul3 mul2 mul1)
```

`v0` 是递归到底交来的 `1`，`vn` 正是 `(fact n)` 的值。这些延续的类型都是 $¬\text{Natural}$，每一条都是这个类型的一个具体的值，各自标出程序运行到的一个位置：等到 `vn` 以后，还要乘上哪几个数，再交给 `k`。第一篇 `(label)` 捕获的「当前位置」，就是这样一条延续。`let*` 的每个绑定处都有一条；直接风格的 `fact` 里，它们一样在，只是藏在嵌套的 `let` 里。

相邻两个位置之间，隔着一步计算。从 `k2` 到 `k3`，中间一步是 `mul3`：`k2` 拿到值，先乘 3，再交给 `k3`。用 `neg` 写出来：

```racket
k2  =  (∘ k3 mul3)  =  ((neg mul3) k3)
```

`(neg mul3)` 的类型 $¬\text{Natural} → ¬\text{Natural}$ 说的是它在两个延续类型之间映射；这里交给它的是一个具体的值 `k3`，交出的是另一个具体的值 `k2`：它把一个位置上的延续，映射成另一个位置上的延续。一般地，一步 `f` 能把位置 `kp` 带到位置 `kq`，条件就是 `kp = ((neg f) kq)`，也就是 `(∘ kq f)`：前一处的延续，正是这一步接上后一处的延续。

这条等式从右往左读，是构造：`(neg f)` 收到后一处的延续，交出前一处的延续，前面那条闭包链就是这样从出口建起来的。从左往右读，是运行：`(kp p)` 就是 `(kq (f p))`，值走完 `f` 这一步，等着它的延续就从 `kp` 换成了 `kq`。递归到底，`1` 作为 `v0` 交给 `k0`，`let*` 一行行往下：过 `mul1` 到 `k1`，过 `mul2` 到 `k2`，过 `mul3` 得到 `6`，到 `k3`，也就是出口。出口的那条延续，既是延续构造的起点，也是值移动的终点：计算开始时交进来的是它，计算最后抵达的也是它。执行一个程序，就是沿着闭包链，从一个位置走到下一个位置。

## 手中的延续

第一篇用 `cc` 实现 `call/cc`：先由 `(cc)` 取得当前延续，再把它交给 `proc`。在 CPS 里，这一步不必做。一等控制一节说过，当前延续已经是一个显式的参数：照 `cps` 的写法也好，照 `neg` 的写法也好，函数收到的延续参数，就是这次调用之后要做的事。那么照这两种写法，`call/cc` 该怎么写？

照 `call/cc` 自己的意思写，先看它收到什么。`cps:call/cc` 照 `cps` 的写法，先收到输入 `cps:proc`，再收到延续 `kp`；`neg:call/cc` 照 `neg` 的写法，次序反过来，先收到 `kp`，再收到 `neg:proc`：

```racket
(define ((cps:call/cc cps:proc) kp) ...)
(define ((neg:call/cc kp) neg:proc) ...)
```

`kp` 就是当前延续，要交给 `proc`。`cps:proc` 照 `cps` 的写法写成，期望得到的是 `cps:kp`，也就是 `(cps kp)`；`neg:proc` 照 `neg` 的写法，期望得到的是 `neg:kp`，也就是 `(neg kp)`。两个定义写完整：

```racket
(define ((cps:call/cc cps:proc) kp) ((cps:proc (cps kp)) kp))
(define ((neg:call/cc kp) neg:proc) ((neg:proc kp) (neg kp)))
```

两行里都有两份 `kp`，角色不同：提升过的那一份交给 `proc` 当参数，`proc` 调用它，就是逃逸；原样的那一份接住 `proc` 正常交回的结果。

跑一个很短的例子。在 `cps:call/cc` 后面接一步加 1，交给它的 `proc` 不理会收到的延续，只算 `2` 乘 `3`。后面那一步加 1 也得写成延续：拿到结果，加 1，再交给终结延续：

```racket
> (define (cps:proc1 cps:k) ((cps *) 2 3))
> (⊥->a ((cps:call/cc cps:proc1) (λ (v) (a->⊥ (add1 v)))))
7
```

`cps:proc1` 正常交回 `6`。原样的那份 `kp`，也就是手写的那个 λ，接住它，先加 1，再交给终结延续，得到 `7`。

换一个 `proc`，让它用上收到的延续：先把 `10` 交给 `cps:k`，再加 1。`cps:k` 收到 `10`，交出的仍是一段等着延续的计算，后面的加 1 只能再手写一个延续接上：

```racket
> (define (cps:proc2 cps:k) (λ (k) ((cps:k 10) (λ (v) (k (add1 v))))))
> (⊥->a ((cps:call/cc cps:proc2) (λ (v) (a->⊥ (add1 v)))))
11
```

结果是 `11`，不是 `12`。`cps:k` 是提升过的 `kp`，一调用，计算就改走 `kp`：外面那一步加 1，然后是终结延续。`cps:proc2` 里排在后面的那一步加 1，再也轮不到。这正是第一篇里 `call/cc` 的行为：调用交出去的延续，就是丢下手头的工作，回到 `call/cc` 之后。

> **练习：** 用 `neg:call/cc` 把这两个例子各跑一遍，结果仍是 `7` 和 `11`。提示：`neg` 的写法先收延续，再收输入；外面那一步加 1，用 `(neg add1)` 接在终结延续前面。

这么短的两个例子，延续却得一个个手写：外面的加 1 一个，`cps:proc2` 里又一个。一等控制一节那句抱怨，到这里更重了：每个延续都得亲手写。

# 嵌入语言

回想开头的观察。`let` 脱糖为 lambda 调用，延续藏在 `let` 里面：等待结果的那个 λ 不用我们写，绑定的语法替我们写了。CPS 变换把延续拉出来变成显式参数，这个 λ 就得亲手写。能不能反过来：用 `let` 语法把 CPS 的延续再藏回去？

## 再次隐藏延续

先看一个具体例子：`(fact/k 2 k)` 的闭包链 `(∘ k mul2 mul1)`，两步乘法。把两步用 `cps` 提升，像 `fact/k` 那样手写延续：

```racket
> (define cps:mul1 (cps (λ (v) (* 1 v))))
> (define cps:mul2 (cps (λ (v) (* 2 v))))
> (⊥->a ((λ (k)
           ((cps:mul1 1)
            (λ (v)
              ((cps:mul2 v) k))))
         a->⊥))
2
```

想要的是像 `let` 一样写成 `(anf:let ([v (cps:mul1 1)]) (cps:mul2 v))`，λ 由语法替我们写。对照手写版，`(cps:mul1 1)` 是 `e`，`(cps:mul2 v)` 是 `b`，宏把它们放回原处：

```racket
(define-syntax-rule (anf:let ([v e]) b)
  (λ (k) (e (λ (v) (b k)))))
```

`anf:let` 自己也交出一段计算，收到延续后才开始运行。展开出来的，除了程序员写下的箭头，只有 λ 和函数调用。`cps:` 箭头加上绑定的语法，就成了一门嵌在宿主里的小语言：宏充当编译器，把类似 ANF 的写法翻译成 $¬¬$ 编码的 CPS。编译出来的程序还要有人运行，这门语言还缺一个解释器：交给程序终结延续 `a->⊥`，再用 `⊥->a` 接住答案：

```racket
(define (anf:eval kka) (⊥->a (kka a->⊥)))
```

重跑例子：

```racket
> (anf:eval (anf:let ([v (cps:mul1 1)]) (cps:mul2 v)))
2
```

## 提前返回

手写的 CPS 版 `mul` 有两处要程序员亲自动手：正常路径上，每一步都要写出新的延续 `(λ (v) (k (* v r)))`；遇到零时，要手动改调 `a->⊥`。不写延续，用宿主自己的 `let/cc`、`let*`、`if` 和原语，`mul` 可以这样写：

```racket
(: mul (→ Real * Real))
(define (mul . r*)
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

遇零照样提前跳出：

```racket
> (mul 1 2 3 4)
24
> (mul 1 2 0 3 4)
0
```

照这个样子，把它一行行改写进嵌入语言：正常路径的每一步交给绑定，遇零交给 `cps:call/cc` 交来的延续。先把用到的原语经 `cps` 提升：

```racket
(define cps:*         (cps *))
(define cps:zero?     (cps zero?))
(define cps:car       (cps car))
(define cps:cdr       (cps cdr))
(define cps:null?     (cps null?))
(define cps:display   (cps display))
(define cps:displayln (cps displayln))
```

它们都收值、交出计算，可以直接放进绑定。`mul` 里的 `let*`、`if`、`let/cc`，各要一样对应的语法，都照 `anf:let` 的套路来。

几个绑定依次接起来，就是一层层嵌套的 `anf:let`：

```racket
(define-syntax anf:let*
  (syntax-rules ()
    [(_ () b) b]
    [(_ ([v e] [v* e*] ...) b)
     (anf:let ([v e]) (anf:let* ([v* e*] ...) b))]))
```

分支也一样：测试那一段算出的计算，收到一条等测试结果的延续；它拿到测试的值，选一支分支，再把 `k` 交给它：

```racket
(define-syntax-rule (anf:if test conseq alt)
  (λ (k) (test (λ (b) ((if b conseq alt) k)))))
```

遇零跳出，要用 `cps:call/cc` 交来的延续。`anf:let/cc` 给它起个名字：

```racket
(define-syntax-rule (anf:let/cc cps:k b* ...)
  (cps:call/cc (λ (cps:k) b* ...)))
```

照上面的 `mul` 一行行改写，它本身也收值、交出计算：

```racket
(: cps:mul (→ Real * (¬¬ Real)))
(define (cps:mul . r*)
  (anf:let/cc cps:return
    (: cps:loop (→ (Listof Real) (¬¬ Real)))
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

`(cps:mul 1 2 3 4)` 交回的是一段等待延续的计算，交给解释器 `anf:eval` 运行：它提供 `a->⊥` 作为终结延续，`⊥->a` 捕获答案。宏在展开时把程序编译成等待延续的计算，`anf:eval` 在运行时交入终结延续。这和第一篇里操作系统运行程序是同一种分工：程序是一个 $¬¬\text{Byte}$，退出通道由操作系统在启动时交给它。`anf:eval` 扮演的就是操作系统：

```racket
> (anf:eval (cps:mul 1 2 3 4))
24
> (anf:eval (cps:mul 1 2 0 3 4))
0
```

`cps:loop` 和 `cps:car` 一样收值、交出计算，所以它的递归调用也写在 `anf:let*` 里。`anf:let/cc` 把当前延续交给程序，名字叫 `cps:return`。遇零时调用它，和手中的延续一节的 `cps:proc2` 一样，计算改走保存的延续，还没做完的乘法全部跳过。其余每一步的延续都由 `anf:let*` 接好，程序员不需要触碰。最后一步同时用到 `res` 和更早的 `r`：宏把后面的代码嵌进前面绑定的函数体，`r` 一路看得见，所以照样能写。

## 阴阳谜题

`cps:return` 只用来跳出循环。第一篇的阴阳谜题对延续要求更多：被捕获的延续要作为值传来传去，再被调用。

`label` 要把捕获的延续原样交出来，用得上一段什么也不做的计算：收到值，交出一段计算，收到延续后把值原样交给它。它就是 `(cps id)`，记作 `cps:id`：

```racket
(define cps:id (cps id))
```

`label` 在嵌入语言里写作：

```racket
(define (cps:label) (cps:call/cc cps:id))
```

展开一层，`((cps:label) k)` 是 `((cps:call/cc cps:id) k)`，也就是 `((cps:id (cps k)) k)`：`cps:id` 把提升过的 `(cps k)` 原样交给 `k`。`(cps:label)` 交回一段等待延续的计算；运行时，它把提升过的当前延续 `(cps k)` 作为结果交给 `k`，和第一篇的 `(label)` 一样。绑定得到的 `cps:yin`、`cps:yang`，就是这样的值。

谜题写进 `anf:let*`。中间还有打印：打印也是一步计算，只是结果用不着。一串计算依次做下去、只留最后一个的结果，就是 `anf:begin`：把前面的结果绑定到一个用不着的变量 `_` 上，忽略掉。

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

`cps:yin` 是提升过的延续，所以能像 `cps:mul` 这些函数一样直接调用。它包着的，就是计算的位置一节里那样的一条延续：`(cps:label)` 把它所在的位置捕获下来，交给程序。这个位置也是从出口那条延续一步步接出来的，出口那一条，是 `anf:eval` 在计算开始时交进来的。

# 两种箭头

提前返回里的 `anf:let*`，一个绑定套着一个绑定。`anf:let` 的写法和 `let` 一样，也就碰上开头同样的问题：几步可以嵌在 `b` 里，也可以先接成一段，嵌进 `e`；还可以插一个只换名的绑定。三步嵌在 `b` 里：

```racket
(anf:let ([y (cps:f x)])
  (anf:let ([z (cps:g y)])
    (cps:h z)))
```

先把前两步接成一段，嵌进 `e`：

```racket
(anf:let ([z (anf:let ([y (cps:f x)])
               (cps:g y))])
  (cps:h z))
```

只换名的绑定也有。`anf:let` 的右边得是一段计算，只换名，用的就是阴阳谜题里那段什么也不做的计算 `cps:id`。两种只换名的写法，都该和直接写 `(cps:f x)` 一样：

```racket
(anf:let ([y (cps:id x)]) (cps:f y))
(anf:let ([y (cps:f x)]) (cps:id y))
```

两种嵌套交出的，是同一段计算吗？只换名的绑定，真的可有可无吗？

## 绑定就是复合

问题一样，解法也可以借来。开头把 `let` 看成复合，问题就成了复合是否满足结合律与单位律。这里也把一次绑定看成一次复合：照 `anf:let` 的样子，先 `cps:f` 再 `cps:g`，接成一支新的箭头，记作 `∘𝒦`（取 continuation 的字母）：

```racket
(define ((∘𝒦 cps:g cps:f) x)
  (anf:let ([y (cps:f x)])
    (cps:g y)))
```

和开头宿主的那条等式并排：

```racket
(let     ([y     (f x)])     (g y))  =  ((∘      g     f) x)
(anf:let ([y (cps:f x)]) (cps:g y))  =  ((∘𝒦 cps:g cps:f) x)
```

`let` 是 `∘` 的另一种写法，`anf:let` 是 `∘𝒦` 的另一种写法，多出来的是中间结果的名字。嵌在 `b` 里，写成复合是 `(∘𝒦 (∘𝒦 cps:h cps:g) cps:f)`；嵌进 `e` 里，是 `(∘𝒦 cps:h (∘𝒦 cps:g cps:f))`；两种换名，是在 `cps:f` 的两头接上 `cps:id`。想让这几种写法行为一样，`∘𝒦` 就得像开头的 `∘` 一样，满足结合律与单位律：

```racket
(∘𝒦 cps:h (∘𝒦 cps:g cps:f))  =  (∘𝒦 (∘𝒦 cps:h cps:g) cps:f)
(∘𝒦 cps:f cps:id)  =  cps:f
(∘𝒦 cps:id cps:f)  =  cps:f
```

> **注意：** 这些等式说的是行为相同，用的是把延续独立出来一节的那个前提：两层参数之间不做别的事。比如 `cps:f` 一收到参数就打印，`(∘𝒦 cps:id cps:f)` 就会把打印推迟到收到延续之后。

## 借道逆否复合

`∘𝒦` 满足这两条运算律吗？先拿例子试试。再提升一支 `mul3`，用 `(fact/k 3 k)` 的三步乘法比较两种分组：

```racket
> (define cps:mul3 (cps (λ (v) (* 3 v))))
> (anf:eval ((∘𝒦 cps:mul3 (∘𝒦 cps:mul2 cps:mul1)) 1))
6
> (anf:eval ((∘𝒦 (∘𝒦 cps:mul3 cps:mul2) cps:mul1) 1))
6
```

两种分组算得一样。一般也是这样吗？不必逐条展开，可以借已有的运算律。先给两种写法的箭头起名：照 `cps` 写法的叫 CPS 箭头，记作 $→_𝒦$；照 `neg` 写法的叫逆否箭头，记作 $→_𝒰$（U 取掉头转弯的意思：箭头的方向倒了过来）。前面名字以 `cps:`、`neg:` 开头的函数，就分别是这两种箭头：

```racket
(define-type (→𝒦 p q) (→    p (¬¬ q)))
(define-type (→𝒰 p q) (← (¬ p) (¬ q)))
```

$p →_𝒦 q$ 收到 $p$，交出等着 $q$ 的计算。$p →_𝒰 q$ 用的是开头的反向箭头 `←`：它从 $p$ 写到 $q$，函数却从 $¬q$ 指向 $¬p$。有了名字，前面几个函数的类型可以重写；提前返回里 `cps:loop` 的类型，也就是 `(→𝒦 (Listof Real) Real)`：

```racket
(: neg  (∀ (p q) (→ (→ p q) (→𝒰 p q))))
(: cps  (∀ (p q) (→ (→ p q) (→𝒦 p q))))
(: flip (∀ (p q) (case→ (→ (→𝒰 p q) (→𝒦 p q))
                        (→ (→𝒦 p q) (→𝒰 p q)))))
(: cps:id (∀ (q) (→𝒦 q q)))
(: ∘𝒦 (∀ (p1 p2 p3) (→ (→𝒦 p2 p3) (→𝒦 p1 p2) (→𝒦 p1 p3))))
```

`case→` 列出同一个函数的几种类型，调用时按交给它的参数取用其中一种：这两行是 `flip` 同一段代码的两种读法，第一行从 𝒰 搬到 𝒦，第二行搬回来。普通函数经 `neg` 变成逆否箭头，经 `cps` 变成 CPS 箭头，`flip` 在两种箭头之间来回。沿用把延续独立出来一节的前提，来回一趟，什么也不丢。

逆否箭头也能复合吗？`flip` 把它们一一对到 CPS 箭头，那就把 `∘𝒦` 原样搬过去：两支各 `flip` 成 CPS 箭头，用 `∘𝒦` 接起来，再 `flip` 回来：

```racket
(define (∘𝒰       neg:g        neg:f)
  (flip (∘𝒦 (flip neg:g) (flip neg:f))))
```

搬过来的复合是什么？把 `(flip neg:g)`、`(flip neg:f)` 记作 `cps:g`、`cps:f`，交齐延续 `k` 和输入 `x`，展开：

```racket
  (((∘𝒰 neg:g neg:f) k) x)
= (((∘𝒦 cps:g cps:f) x) k)
= ((cps:f x) (λ (y) ((cps:g y) k)))
= ((neg:f (λ (y) ((neg:g k) y))) x)
= ((neg:f (neg:g k)) x)
= (((∘ neg:f neg:g) k) x)
= (((⨾ neg:g neg:f) k) x)
```

倒数第三步靠的还是那个前提。搬过来的，原来就是开头的反向复合 `⨾`：先用 `neg:g`，再用 `neg:f`。计算的位置一节用几次 `neg` 接出闭包链，也是这样接的。于是逆否箭头的复合直接取 `⨾`，单位元取 `id`，记作 `neg:id`：

```racket
(: ∘𝒰 (∀ (p1 p2 p3) (→ (→𝒰 p2 p3) (→𝒰 p1 p2) (→𝒰 p1 p3))))
(define ∘𝒰 ⨾)

(: neg:id (∀ (q) (→𝒰 q q)))
(define neg:id id)
```

`⨾` 有结合律与单位律，`∘𝒰` 也就有：分组无关紧要，`neg:id` 接在哪一头都不改变什么。`id` 搬回 CPS 箭头这边，正是 `cps:id`。`flip` 来回一趟什么也不丢，`∘𝒦` 搬过去是 `∘𝒰`，两条运算律也就跟着搬了回来：两种嵌套的 `anf:let` 交出同样的计算，只换名的绑定可有可无。

> **练习：** 反过来，只用 `∘𝒰` 和 `flip` 写出 `∘𝒦`，验证它与由 `anf:let` 给出的定义行为相同。

# 箭头指向何方

## 回到宿主

嵌入语言写出的程序，交出的都是一段等待延续的计算。普通的宿主代码要用它，总得有人把延续参数填上。`anf:eval` 填的是终结延续 `a->⊥`。把它放进一个普通的宿主表达式里：

```racket
> (+ 1 (anf:eval (cps:mul 1 2 3 4)))
25
> (+ 1 (anf:eval (cps:mul 1 2 0 3 4)))
1
```

两条路都回到了 `(+ 1 _)`。`a->⊥` 一调用就 `raise`，是外面那层 `⊥->a` 的 handler 接住答案，交回调用处，加 1 接着做。`anf:eval` 没有捕获调用处的延续，是借 `raise` 与 handler 把答案送回来的。

宿主若有 `call/cc`，就能直接捕获当前延续，填进编码的延续参数。宿主里普通的函数类型，记作 $→_𝒞$：

```racket
(define-type (→𝒞 p q) (→ p q))

(: uncps (∀ (p q) (→ (→𝒦 p q) (→𝒞 p q))))
(define (uncps cps:f) (∘ call/cc cps:f))
```

`((uncps cps:f) x)` 先算出 `(cps:f x)`，一段等待延续的计算，再交给 `call/cc`，`call/cc` 把当前延续交给它。`uncps` 收 CPS 箭头，交出宿主箭头，也就是一个普通的宿主函数，可以放进同一个 `(+ 1 _)`：

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

## 三种写法

反过来呢？一支 CPS 箭头先经 `uncps` 运行回宿主，再经 `cps` 提升，还是原来那支吗？交给它输入 `a` 和延续 `kb`，展开：

```racket
  (((cps (uncps cps:f)) a) kb)
= (kb ((uncps cps:f) a))
= (kb (call/cc (cps:f a)))
≈ ((cps:f a) kb)
```

前两步照定义展开。最后一步换成了 `≈`，用的是 `call/cc` 的一条规律：

```racket
  (let ([a (call/cc kka)]) (ka a))
= (ka (call/cc kka))
≈ (kka ka)
```

`call/cc` 捕获的，是收到 `a` 以后交给 `ka` 这件剩下的工作。`ka` 若是一条真正的延续，交出去就不再回来，捕获到的就和 `ka` 一样。把它交给 `kka`，和直接把 `ka` 交给 `kka`，行为相同。

> **注意：** `≈` 说的是行为相同，前提比 `=` 多。`ka` 得是交出去就不再回来的延续；它若正常返回，捕获的延续还会接着做 `(ka a)` 之后的事。Racket 的 `dynamic-wind` 能分辨一条延续是普通函数还是 `call/cc` 捕获的跳转，在它看来两边并不相同。把延续独立出来一节的前提也照样要：两层参数之间不做别的事。

两个方向都回到原处：宿主箭头经 `cps` 变成 CPS 箭头，CPS 箭头经 `uncps` 变回宿主箭头，来回什么也不丢。逆否箭头和 CPS 箭头之间，`flip` 也是来回什么也不丢。把这几种转换画在一起，箭头的种类记在顶点上，转换标在边上，就是一张**图表**（*diagram*）：

```
 𝒞 ←───────────┐
 │             │
neg          uncps
 │             │
 ↓             │
 𝒰 ───flip───→ 𝒦
```

从 𝒞 出发，经 `neg`、`flip` 到 𝒦，就是 `cps = (∘ flip neg)`；再经 `uncps` 回到 𝒞，得到的还是原来的箭头。从 𝒦 出发也一样，`uncps` 接上 `neg` 走到 𝒰，展开只用到上面那条规律：

```racket
  (((neg (uncps cps:f)) kb) a)
= (kb ((uncps cps:f) a))
= (kb (call/cc (cps:f a)))
≈ ((cps:f a) kb)
= (((flip cps:f) kb) a)
```

`(neg (uncps cps:f))` 与 `(flip cps:f)` 行为相同，再 `flip` 一次，就回到 `cps:f`。这张图表里，从一处沿不同的路径走到另一处，结果都一样。图表有这种性质，就说它是**交换**的（*commutative*），叫作**交换图表**（*commutative diagram*）。从 𝒰 回到 𝒞 没有直接的一条边，沿图表绕过 𝒦 就有：

```racket
(: unneg (∀ (p q) (→ (→𝒰 p q) (→𝒞 p q))))
(define unneg (∘ uncps flip))
```

只说箭头一一对应，还不够说三种写法是一回事：恒等和复合也得对上。宿主的 `id` 经 `cps` 成了 `cps:id`；两步 `(∘ g f)` 经 `cps` 成了 `(∘𝒦 (cps g) (cps f))`，展开就看得出。借道逆否复合一节又看到，`flip` 把 `∘𝒦` 搬成 `∘𝒰`、`cps:id` 搬成 `neg:id`。箭头一一对应，恒等对恒等，复合对复合，在 `≈` 的意义下，三种写法是**同构**的（*isomorphic*）：同一组箭头的三种写法。

## 数一数 k

名字里的 `k` 一直在数否定的层数：`kv` 等 `v`，`kkv` 等 `kv`。对同一个类型 $a$，把 $a$ 本身算作第 0 层，叠了 $n$ 层的 $¬^n a$ 算作第 $n$ 层。

一个值比另一个多一层时，多一层的那个正好可以接收少一层的那个，结果是 $⊥$：`(kv v)`、`(kkv kv)` 都是这样。这是第一篇的矛盾律，$¬p$ 遇上 $p$。

`cps:id` 让一个值多两层：收下 `x`，等一个比 `x` 多一层的值来，再把 `x` 交给它。这是第一篇的 DNI。

反过来少两层呢？结果若仍带着至少一层否定，可以统一地消去两层。要消去的值 `x` 在第 $n+2$ 层；结果在第 $n$ 层，是一个等着第 $n-1$ 层的值 `y` 的函数。`cps:id` 把 `y` 升到第 $n+1$ 层，正好交给 `x`：

```racket
(((neg cps:id) x) y)  =  (x (cps:id y))
```

这一步就是 `cps:id` 的逆否，只用 λ 和函数调用。要从第 2 层落到第 0 层，结果本身是一个值，没有可以垫底的 `y`。对任意的 $a$，没有统一的纯函数完成 $¬¬a → a$。这是 DNE，宿主靠 `call/cc` 捕获一条延续来做到。

## 同一支箭头

宿主的 `call/cc` 照 DNE 来读，是一支宿主箭头 $¬¬a →_𝒞 a$：收下第 2 层的 `kka`，交出第 0 层的值。三种写法既然同构，它在另外两种写法里各是什么样子？

先看 CPS 箭头。交给 `(cps call/cc)` 一段 `kka` 和延续 `kb`，用三种写法一节那条规律：

```racket
  (((cps call/cc) kka) kb)
= (kb (call/cc kka))
≈ (kka kb)
```

收下 `kka`，把延续 `kb` 原样交给它：这支箭头什么也不运行，收下一段计算，原样交出。代码和 `id` 一样，类型却是一支 CPS 箭头：从 $¬¬a$ 到 $a$。这和借道逆否复合一节的 `neg:id` 是同一种情形：定义相同，箭头的种类不同。记作 `neg²:id`：

```racket
(: neg²:id (∀ (a) (→𝒦 (¬¬ a) a)))
(define (neg²:id kka) kka)
```

$¬¬a →_𝒦 a$ 看上去也像 DNE；展开到宿主，它只是 $¬¬a → ¬¬a$，从第 2 层到第 2 层。名字里的 `neg²` 也有来由：`(neg neg:id)` 收下 `kka`，交出 `(∘ kka id)`，行为和 `kka` 一样，所以 `neg²:id` 就是 `(neg neg:id)`。反过来，把它交给 `uncps`，得到的正是宿主的 `call/cc`：

```racket
(uncps neg²:id)  =  (∘ call/cc neg²:id)  =  call/cc
```

工作来自 `uncps` 里已有的 `call/cc`，不是 `neg²:id` 自己捕获了什么。

再看逆否箭头：

```racket
  (((neg call/cc) ka) kka)
= (ka (call/cc kka))
≈ (kka ka)
= ((cps:id ka) kka)
```

`(neg call/cc)` 收下第 1 层的 `ka`，交出第 3 层：它就是用在 $¬a$ 上的 `cps:id`，多两层。`neg:id` 就是 `id`，所以它也是 `(cps neg:id)`。宿主里 2 → 0 的这一步，换成 CPS 箭头是 2 → 2，换成逆否箭头是 1 → 3，接口一变，都不再落到第 0 层。

## 读出命题

照第一篇的办法，把这些箭头的类型读成命题。先读最早的两个。`neg` 和 `cps` 的类型，按照 Curry-Howard 对应，是两条直觉主义定理：

| 命题                  | 定理                                  |
|-----------------------|---------------------------------------|
| $(p → q) → (¬q → ¬p)$ | **逆否律**（*law of contraposition*） |
| $(p → q) → (p → ¬¬q)$ | **双重否定引入**（DNI）的推广形式     |

`flip` 的两行读法 $(¬q → ¬p) → (p → ¬¬q)$ 和 $(p → ¬¬q) → (¬q → ¬p)$，也都是直觉主义定理。三种箭头，各是一种命题形状：

| 箭头     | 类型                |
|----------|---------------------|
| 宿主箭头 | $p →_𝒞 q = p → q$   |
| CPS 箭头 | $p →_𝒦 q = p → ¬¬q$ |
| 逆否箭头 | $p →_𝒰 q = ¬q → ¬p$ |

## 新箭头下的 Clavius 律

第一篇的 `call/cc` 要靠宿主捕获延续；手中的延续一节的 `cps:call/cc` 却只用了 λ 和函数调用，什么也没有捕获。两者做的是同一件事：把当前延续交给 `proc`。它们究竟是同一个什么？

这和上一节不同。上一节把 `call/cc` 照 DNE 读，搬的是同一支箭头；这里照 Clavius 律读，换写的是整条定律，`proc` 本身也换成了新的箭头。所以 `cps:call/cc` 不是 `(cps call/cc)`：后者收的 `proc` 仍是宿主函数。

两个新 `call/cc` 的类型，可以从定义里读出来。拿 `cps:call/cc` 来看。把它交出的结果的类型记作 `p`。`kp` 是这次调用的当前延续，等的就是这个结果，类型是 `(¬ p)`。`cps` 把它提升成 `(→𝒦 p ⊥)`，这是用 CPS 箭头写的否定，记作 `¬𝒦`；用逆否箭头写的否定同样记作 `¬𝒰`：

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

读作 $(¬p → p) → p$，Clavius 律。两个新 `call/cc` 的类型是同一条定律，只是 $→_𝒞$ 换成了 $→_𝒦$、$→_𝒰$：它们是 Clavius 律用这两种箭头写出来的样子。

可第一篇的分水岭说过：`call/cc` 要先凭空造出一个 $¬p$ 交给 `proc`，只用 λ 和函数调用写不出来，必须捕获。`cps:call/cc` 却只用了 λ。把 $→_𝒦$ 展开成宿主的箭头：

$$(¬_𝒦 p →_𝒦 p) →_𝒦 p \;=\; (¬_𝒦 p → ¬¬p) → ¬p → ⊥$$

$¬p$ 在箭头左边，是参数，就是 `kp`。宿主的 Clavius 律只收 `proc` 一个输入，手里没有否定，只能凭空去造；用 CPS 箭头写，这个否定作为参数交了进来。交给 `cps:proc` 的 $¬_𝒦 p$，是 `cps` 从 `kp` 加工出来的。

这个 $¬_𝒦 p$ 能不能凭空造出来？$¬_𝒦 p$ 展开是 $p → ¬¬⊥$；手里若有一个 $¬¬⊥$ 的值，把类型为 $⊥ → ⊥$ 的 `id` 交给它，就得到 $⊥$ 的值，所以 $¬¬⊥$ 和 $⊥$ 一样空。对非空的 $p$，同样凭空造不出 $¬_𝒦 p$。

`cps:call/cc` 做的，是分水岭构造性那一侧的事：消耗交到手里的否定。

所以展开后的这条公式，已经不是宿主里的 Clavius 律，而是一条直觉主义定理：按照 Curry-Howard，它有闭合的、有类型的纯 λ 项，就是 `cps:call/cc`。`neg:call/cc` 也一样。同一条经典定律，换用 CPS 箭头或逆否箭头来写，就成了直觉主义定理。经典的控制并没有消失，宿主要捕获的那条延续，成了显式的参数。

# 否定翻译

## 再用一次 `neg`

回到宿主的两条边，`uncps` 和 `unneg`，类型读出来是

$$(p → ¬¬q) → (p → q), \qquad (¬q → ¬p) → (p → q)$$

前一条要从 $¬¬q$ 取出 $q$，是 DNE；后一条是逆否律反过来。两条都只在经典逻辑里成立，所以离不开 `call/cc`。`anf:eval` 的类型 `(∀ (a) (→ (¬¬ a) a))` 也是 DNE。回到宿主一节的往返，是在 `f` 之后接 DNI，也就是 `cps:id`，再接用 `call/cc` 实现的 DNE；后两步合起来是恒等，所以整体仍是 `f`。

不回宿主呢？逆否箭头本身就是一个普通函数 $¬q → ¬p$，只是方向和 $p$ 到 $q$ 相反，开头才用 `←` 写成 `(← (¬ p) (¬ q))`。再用一次 `neg`，方向翻回来：交给 `neg` 一支逆否箭头 `neg:f`，得到的 `(neg neg:f)` 是 $¬¬p → ¬¬q$。它只在延续前面接上 `neg:f`，`neg:f` 是纯的，它也是纯的。

这里要分清宿主里的两类程序。完整的宿主就是 𝒞，`call/cc`、`raise`、`exit`、`display` 都在里面。从中只留下没有可观察的副作用、在合法输入上总会返回的程序，记作 𝒟；作为参数交进来的函数，也要在 𝒟 里。𝒟 是 𝒞 的一部分，箭头还是普通的函数类型：两者的区别不在类型上，在于允许写哪些宿主程序。别名不会检查这些条件，它们要靠程序怎样写成来保证。𝒟 的箭头在 𝒞 里同样合法，`inj` 把它原样放进 𝒞：

```racket
(define-type (→𝒟 p q) (→ p q))

(: inj (∀ (p q) (→ (→𝒟 p q) (→𝒞 p q))))
(define (inj f) f)
```

`neg` 的两种读法，写进同一个 `case→`，第二种读法落在 𝒟 里：

```racket
(: neg (∀ (p q) (case→ (→ (→𝒞 p q) (→𝒰 p q))
                       (→ (→𝒰 p q) (→𝒟 (¬¬ p) (¬¬ q))))))
```

两次 `neg` 连起来，记作 `neg²`。宿主箭头 $p → q$ 进来，出去的是 $¬¬p → ¬¬q$，每个类型裹上一层 $¬¬$：

```racket
(: neg² (∀ (p q) (→ (→𝒞 p q) (→𝒟 (¬¬ p) (¬¬ q)))))
(define neg² (∘ neg neg))
```

把 𝒟 和 `inj` 也画进前面那张图表：

```
 𝒟 ───inj────→ 𝒞 ←───────────┐
 ↑             │             │
 │            neg          uncps
 │             │             │
 │             ↓             │
 └────neg───── 𝒰 ───flip───→ 𝒦
```

从 𝒰 到 𝒟 的这一次 `neg`，把类型 $a$ 换成了 $¬¬a$。右边的三角形仍然交换；左边 𝒟 的那一半不交换。一支逆否箭头沿 `neg`、`inj` 走到 𝒞，得到的是 $¬¬p → ¬¬q$；沿 `unneg` 走到 𝒞，得到的是 $p → q$。两条路连类型都对不上，这一半只标出箭头怎样转换。

可 `(neg² f)` 运行时仍原样调用 `f`：`f` 若用了宿主的 `call/cc`，包一层以后照样依赖它，类型写成 $→_𝒟$ 改变不了这一点。若 `f` 是从一支 CPS 箭头运行回来的，`f` 就是 `(uncps cps:f)`，三种写法一节的等式给出另一种写法：

```racket
  (neg² (uncps cps:f))
= (neg (neg (uncps cps:f)))
≈ (neg (flip cps:f))
```

右边只用 λ 和函数调用。`cps:f` 是纯的 CPS 箭头，比如 `cps:mul`，它就是 𝒟 里的纯程序。

## 翻译 `call/cc`

同一支箭头一节停在逆否箭头那一行：`call/cc` 换成逆否箭头，是用在 $¬a$ 上的 `cps:id`。再用一次 `neg`，就到了 𝒟。交齐参数展开：

```racket
  (((neg² call/cc) kkkka) ka)
= (kkkka ((neg call/cc) ka))
≈ (kkkka (cps:id ka))
= (kkkka (λ (kka) (kka ka)))
```

`call/cc` 不见了，剩下的只用 λ 和函数调用：外层的计算交来一段 `kka`，再把同一条 `ka` 交给它。从第 4 层到第 2 层，消去两层而不落底，正是数一数 k 一节的 `(neg cps:id)`：原来要靠 `call/cc` 的 DNE，翻译出来是 DNI 的逆否。

逆否箭头那一行是 `(cps neg:id)`，再用一次 `neg`，就是 `(neg (cps neg:id))`：从 `id` 出发，依次用 `neg`、`cps`、`neg`，一路都不碰 `call/cc`。这一串用在别的宿主箭头上也行，记作 `join`；用在 `id` 上的那一支，照名字的约定记作 `join:id`：

```racket
(: join (∀ (p q) (→ (→𝒞 p q) (→𝒟 (¬¬ (¬¬ p)) (¬¬ q)))))
(define join (∘ neg cps neg))

(: join:id (∀ (a) (→𝒟 (¬¬ (¬¬ a)) (¬¬ a))))
(define join:id (join id))
```

交给 `join:id` 一段四重否定的 `7`，交出的是一段等着延续的 `7`：

```racket
> (anf:eval (join:id (cps:id (cps:id 7))))
7
```

`join` 和 `cps` 是一对。`cps` 把宿主箭头 `f` 变成「先 `f`，再多两层」；`join` 把它变成「先消去两层，再 `f`」。两者都能拆成用在 `id` 上的那一支，接上 `f` 或 `(neg² f)`，两种拆法都对：

```racket
(cps  f)  =  (∘ cps:id f)               =  (∘ (neg² f) cps:id)
(join f)  =  (∘ (neg² f) join:id)       =  (∘ join:id (neg² (neg² f)))
```

> **练习：** 沿第二张图表从 𝒦 经 𝒰 走到 𝒟：先 `flip`、再 `neg`，记作 `cps->neg²`。验证 `((cps->neg² cps:f) kkx)` 与 `(anf:let ([x kkx]) (cps:f x))` 行为相同，再验证 `(cps->neg² neg²:id)` 就是 `join:id`。

同一支 `call/cc`，沿图表换成各种写法，层数这样变化（CPS 箭头、逆否箭头两行，用的是三种写法一节那条规律的前提）：

| 写法     | 箭头                        | 由 `id` 造出             | 层数   |
|----------|-----------------------------|--------------------------|--------|
| 宿主箭头 | `call/cc`                   |                          | 2 → 0  |
| CPS 箭头 | `neg²:id`                   | `(neg neg:id)`           | 2 → 2  |
| 逆否箭头 | `cps:id`，用在 $¬a$ 上      | `(cps neg:id)`           | 1 → 3  |
| 𝒟        | `join:id`                   | `(neg (cps neg:id))`     | 4 → 2  |

只有宿主那一行落到第 0 层。翻译没有在纯语言里实现原来的 DNE；它改变了输入和输出的类型，让这个经典操作有了一个由 DNI 和逆否构成的纯表示。要取回原来类型的结果，仍然要靠运行边界上的控制能力。

## 从 `mul` 到 `cps:mul`

阴阳谜题和 `cps:mul` 用的是同一套宏、同一个 `cps:call/cc`。`cps:mul` 遇零就跳出循环，用的是第一篇里要靠 `call/cc` 才写得出来的控制，宿主的 `call/cc` 却一次也没有出现。阴阳谜题同样没有用到宿主的 `call/cc`，可它每走一步都往外打印字符，而且永远不会结束。说这些控制是用纯函数写出来的，纯的究竟是哪一部分？

先回看 `cps:mul` 是怎么来的。提前返回一节照宿主的 `mul` 一行行改写，程序的结构一模一样，换掉的只有三样：`let/cc` 换成了 `anf:let/cc`，`let*`、`if` 换成了 `anf:let*`、`anf:if`，原语换成了提升过的 `cps:car`、`cps:*` 这些。这几处替换是我们亲手做的；宏做的，是把替换后的各步接起来。

接口也跟着变了。`mul` 收到乘数，交出乘积；`cps:mul` 收到同样的乘数，交出一段等待延续的计算：一个是 $a → b$，一个是 $a → ¬¬b$。控制的做法也换了。`mul` 遇零时，调用的是 `let/cc` 从宿主那里捕获的延续；`cps:mul` 的 `cps:return` 却是 `cps:call/cc` 交到程序手里的参数，而 `cps:call/cc` 的定义只用了 λ 和函数调用。

这就看得出纯在哪里了。`neg`、`flip`、`cps`、`∘𝒦`、`cps:call/cc` 都由 λ、函数应用、复合，以及有限参数表上的 `apply` 写成，自己不跳转，也不输出：交给它们的函数在 𝒟 里，得到的也在 𝒟 里。`cps:mul` 用到的原语都是纯函数，`car`、`cdr` 只在 `null?` 判过非空以后调用；`cps:loop` 是递归的，但每次处理更短的有限列表。所以 `cps:mul` 整个落在 𝒟 里。

阴阳谜题也用这些纯构造连接和传递延续；整段程序的输出与不终止仍在 𝒟 之外，并不会因为改写成 CPS 就消失。

`cps:mul` 把原来需要捕获延续的控制写成了 𝒟 里的纯程序，代价是结果的类型裹上一层 $¬¬$。

第一篇结尾说过，经典的控制流可以编码成显式的延续传递，这种编码叫作**否定翻译**（negative translation）。逻辑里，它把经典证明系统地改写成直觉主义证明。`cps:call/cc` 换的是一条经典定律，`join:id` 换的是一个经典操作，从 `mul` 到 `cps:mul` 换的是整段程序：控制操作换成纯的 CPS 构造，原语换成提升过的箭头，类型从 $a → b$ 变成 $a → ¬¬b$，各步由宏生成的延续接起来，这种接法就是前面认出的 `∘𝒦`。改写要落在程序本身：把 `mul` 原样包一层 `cps`，里面的 `let/cc` 照样会去捕获宿主的延续。

---

# 结论

`cps:call/cc` 什么也没有捕获，交给 `proc` 的延续来自它收到的参数 `kp`。计算的位置一节从右往左读过 `kp = ((neg f) kq)`：在这里的纯编码中，每一处的延续，都是从出口那条延续出发，由 `neg` 这样的纯构造一环环接出来的。出口那一条，运行时由 `anf:eval` 或 `call/cc` 交进来。

第一篇的分水岭把控制分成两列：只消耗交到手里的否定，普通函数就写得出；要自行提供非空类型的否定，就得借助 𝒟 之外的宿主控制能力。这条分界线还在，只是挪到了程序的边界上。边界以内，消耗、变换延续的工作，`neg`、`flip`、`∘𝒦`、`cps:call/cc`，全都是 𝒟 里的纯函数，控制只是在已有的延续之间选一条来调用。边界上，这里的纯编码运行一次，需要宿主提供一条终结延续：`anf:eval` 交入现成的 `a->⊥`，再用 handler 接回答案；`uncps` 交入 `call/cc` 捕获的当前延续。

这就是第一篇那个问题的回答：经典的控制有了纯的 CPS 表示，留在程序里面；提供终结延续、运行编码并把答案交回宿主的 DNE，留在了编码之外的运行边界上。

## 未解的线索

$¬¬a$ 仍然不是 $a$。展开别名：$¬¬a = (a → ⊥) → ⊥$，它是一个等待延续的函数。要从中取出 $a$ 类型的结果，必须向它交一条 $a → ⊥$ 类型的延续。第一篇说过，只用 λ 和函数调用，写不出非空类型的否定。𝒟 一般不能自行提供这条终结延续，也没有对任意类型都成立的纯函数，能从这里的双重否定编码中取回结果。

`anf:eval` 借来的那一条是 `a->⊥`。它的跳转来自 `raise`，而跳转函数的返回类型是 $⊥$，第一篇定义 `goto : Label → ⊥` 时就确立了这一点。`⊥->a` 再把答案接回来。按字面读，这对名字似乎在说 $a$ 和 $⊥$ 可以互相转化。但 $⊥$ 是空类型，没有值的类型，而 $a$ 是一个完全正常的、拥有值的类型。它们怎么可能互相转化？

开头的第二根线头问的也是 $⊥$：程序类型里的 $⊥$ 并不是世界的终结，进程终止以后，OS 还在运行。$⊥$ 到底是什么？

那是[另一篇文章](https://zhuanlan.zhihu.com/p/2032178684895946051)的故事了。

---

# 完整代码参考

这里的 `anf:` 宏处理多值和多个表达式组成的函数体；正文给的是单值、单个函数体的写法。

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


;;; 宿主的箭头

(define-type (→𝒟 p q) (→ p q))
(define-type (→𝒞 p q) (→ p q))

(: inj (∀ (p q) (→ (→𝒟 p q) (→𝒞 p q))))
(define (inj f) f)

;;; 逆否箭头

(define-type (→𝒰 p q) (← (¬ p) (¬ q)))
(define-type (¬𝒰 p)   (→𝒰 p ⊥))

(: neg (∀ (p q) (case→ (→ (→𝒞 p q) (→𝒰 p q))
                       (→ (→𝒰 p q) (→𝒟 (¬¬ p) (¬¬ q))))))
(define ((neg f) kq) (∘ kq f))


;;; CPS 箭头

(define-type (→𝒦 p q) (→ p (¬¬ q)))
(define-type (¬𝒦 p)   (→𝒦 p ⊥))

(: flip (∀ (p q) (case→ (→ (→𝒰 p q) (→𝒦 p q))
                        (→ (→𝒦 p q) (→𝒰 p q)))))
(define (((flip f) . y*) . x*) (apply (apply f x*) y*))

(: cps (∀ (p q) (→ (→𝒞 p q) (→𝒦 p q))))
(define cps (∘ flip neg))

(: cps:id (∀ (q) (→𝒦 q q)))
(define cps:id (cps id))


;;; anf: 宏

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

(define-syntax-rule (anf:let ([v e]) b* ...)
  (anf:let* ([v e]) b* ...))

(define-syntax-rule (anf:if test conseq alt)
  (λ (k) (test (λ b* ((if (equal? b* '(#f)) alt conseq) k)))))

(define-syntax-rule (anf:let/cc cps:k b* ...)
  (cps:call/cc (λ (cps:k) b* ...)))


;;; 两种箭头的复合

(: ∘𝒦 (∀ (p1 p2 p3) (→ (→𝒦 p2 p3) (→𝒦 p1 p2) (→𝒦 p1 p3))))
(define ((∘𝒦 cps:g cps:f) x)
  (anf:let ([y (cps:f x)])
    (cps:g y)))

(: ∘𝒰 (∀ (p1 p2 p3) (→ (→𝒰 p2 p3) (→𝒰 p1 p2) (→𝒰 p1 p3))))
(define ∘𝒰 ⨾)

(: neg:id (∀ (q) (→𝒰 q q)))
(define neg:id id)


;;; Clavius 律

(: neg:call/cc  (∀ (p) (→𝒰 (→𝒰 (¬𝒰 p) p) p)))
(: cps:call/cc  (∀ (p) (→𝒦 (→𝒦 (¬𝒦 p) p) p)))

(define ((neg:call/cc kp) neg:proc) ((neg:proc kp) (neg kp)))
(define ((cps:call/cc cps:proc) kp) ((cps:proc (cps kp)) kp))



;;; 回到宿主

(: anf:eval (∀ (a) (→ (¬¬ a) a)))
(define (anf:eval kka) (⊥->a (kka a->⊥)))

(: uncps (∀ (p q) (→ (→𝒦 p q) (→𝒞 p q))))
(define (uncps cps:f) (∘ call/cc cps:f))

(: unneg (∀ (p q) (→ (→𝒰 p q) (→𝒞 p q))))
(define unneg (∘ uncps flip))


;;; 再用一次 neg

(: neg² (∀ (p q) (→ (→𝒞 p q) (→𝒟 (¬¬ p) (¬¬ q)))))
(define neg² (∘ neg neg))


;;; 翻译 call/cc

(: neg²:id (∀ (a) (→𝒦 (¬¬ a) a)))
(define (neg²:id kka) kka)

(: join (∀ (p q) (→ (→𝒞 p q) (→𝒟 (¬¬ (¬¬ p)) (¬¬ q)))))
(define join (∘ neg cps neg))

(: join:id (∀ (a) (→𝒟 (¬¬ (¬¬ a)) (¬¬ a))))
(define join:id (join id))


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
