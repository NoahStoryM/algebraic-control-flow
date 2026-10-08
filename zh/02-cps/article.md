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

`let*` 是嵌套的 `let`，每个绑定各藏着一个延续。最简单的情形，每一步只用上一步的结果：

```racket
  (let* ([y (f x)]
         [z (g y)])
    z)
= ((λ (y)
     ((λ (z) z)
      (g y)))
   (f x))
= ((λ (y) (g y))
   (f x))
= (g (f x))
= ((∘ g f) x)
```

两层 λ 是 `let*` 替我们写的。里面一层只把 `z` 原样交出，拿掉以后，剩下的是 `f` 与 `g` 的复合：绑定的先后，就是复合的先后。`let*` 比复合多做的一件事，是给中间结果起了名字。

延续一直藏在 `let` 里面。ANF 所做的事情，不过是让这种隐藏变得有规律。

但如果把延续从 `let` 的语法糖里拉出来，当作独立的值呢？一个可以传来传去、存储、反复调用的函数参数？

---

# 延续与 CPS

让每个函数额外接受一个参数 `k`，代表「我算完之后该做什么」。不再返回值给调用者，而是把结果直接传给 `k`。`fact` 的 CPS 版本：

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

代码的形状变了。`fact/k` 的递归调用 `(fact/k (- n 1) (λ (v) ...))` 是整个 `if` 分支的最后一个动作，后面没有任何待执行的表达式。`fib/k` 也是：每个递归调用都处于尾位置。所有调用都变成了尾调用。

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

## 初始延续

CPS 函数需要一个延续才能启动。用什么作为初始延续？

许多语言有一个内置的延续：`exit`，类型为 $¬\text{Byte}$。可以包装一下得到 $¬\text{Natural}$：

```racket
(fact/k 5 (λ (ans) (displayln ans) (exit 0)))
;; 打印 120，然后终止
```

结果打印出来了，进程也随之终止，没法拿着结果继续工作。

我们需要的是另一个类型为 $a → ⊥$ 的函数：它不返回，但能把答案送到某个我们可以取回的地方，而不杀死进程。`raise` 正合适：它不返回，而 handler 可以捕获它的值。我们只需一个专用的 struct 来区分我们的答案和其他异常：

```racket
(struct (r) ans ([a* : (Listof r)]) #:type-name Ans)
(: a->⊥ (∀ (a) (¬ a)))
(define (a->⊥ . a*) (raise (ans a*)))
(define-syntax-rule (⊥->a exp)
  (with-handlers ([ans? (compose list->values ans-a*)]) exp))
```

`a->⊥` 把值包进 `ans` struct 并抛出。`⊥->a` 安装一个 handler 来捕获这个 struct 并提取内容。命名反映了类型层面的操作：`a->⊥` 把值送入 $⊥$（抛出），`⊥->a` 把值取回（捕获）。

```racket
(⊥->a (fact/k 5 a->⊥))   ; => 120
(⊥->a (fib/k 10 a->⊥))   ; => 55
```

CPS 函数运行起来，`a->⊥` 充当初始延续构建出闭包链，`⊥->a` 在外面接住答案。计算在 raise/handler 的边界内执行，结果穿过边界传出来。

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

(mul 1 2 3 4)    ; => 24
(mul 1 2 0 3 4)  ; => 0
```

正常路径沿着 `k` 返回累积的乘积。遇到零时，跳过 `k`，直接调用 `a->⊥`。`k` 代表「继续乘下去然后返回结果」的延续；`a->⊥` 代表「直接跳出整个循环，把值交给 handler」的延续。选择调用哪一个，就是选择走哪条控制流。不需要 `call/cc`，不需要任何特殊操作符。延续是普通的函数，切换延续是普通的函数调用。

但代价也很明显：程序员必须亲手编写每一个延续，把 `k` 穿过每一层调用。能否自动化 CPS 包装？

---

# 否定的层次

对固定参数的函数，CPS 包装是平凡的。`zero?` 的 CPS 版本：

```racket
(define (zero?/k x k) (k (zero? x)))
```

`zero?/k` 在 `zero?` 的结果外面套一层 `k` 调用，就完成了包装。任何固定参数的函数都能这样包。但可变参数函数怎么办？延续和参数共享同一层。参数个数不确定，延续就没法和操作数分开。

```racket
(define (+/k . args-and-k) ...)  ; 哪个参数是 k？
```

为了区分延续参数，可以通过柯里化把延续参数独立出来。独立在外层还是内层，操作上没有区别，函数体都一样：

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

`flip` 交换参数顺序，对任何两层柯里化的函数都适用。`neg` 产出的 $¬q → ¬p$ 展开是 $¬q → p → ⊥$，正是这样的两层函数。代入 $x = ¬q$、$y = p$、$z = ⊥$，得到 $p → ¬¬q$；反过来代入 $x = p$、$y = ¬q$，又从 $p → ¬¬q$ 回到 $¬q → ¬p$。本文只在这两种形状之间使用它，分别命名两个方向：

```racket
(: flip  (∀ (p q) (→ (→ (¬ q) (¬ p)) (→ p (¬¬ q)))))
(: flip¹ (∀ (p q) (→ (→ p (¬¬ q)) (→ (¬ q) (¬ p)))))
(define flip¹ flip)
```

`flip¹` 就是 `flip`：对纯函数来说，交换两次参数顺序就回到原处，所以两者互为逆运算，在两种箭头之间来回，什么也不会丢失。按照 Curry-Howard，它们的类型 $(¬q → ¬p) → (p → ¬¬q)$ 和 $(p → ¬¬q) → (¬q → ¬p)$ 也都是直觉主义定理。

有了 `flip`，`cps` 和 `neg` 可以互相定义：

```racket
cps  =  (∘ flip  neg)
neg  =  (∘ flip¹ cps)
```

> **练习：** 上面用 `flip` 在 `neg` 和 `cps` 之间来回。反过来，只用 `neg` 和 `cps`，写出 `flip`。提示：先想想 `(cps values)` 做了什么。

回头看 `neg`。`(neg f)` 的类型 $¬q → ¬p$ 是延续之间的变换，将期望 $q$ 的延续变换为期望 $p$ 的延续。变换的方式很直接，把 `f` 复合到延续前面：

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

`cps`、`neg`、`flip[¹]` 的类型对应四条直觉主义定理，其中三种命题形状反复出现：$p → q$、$¬q → ¬p$、$p → ¬¬q$。函数类型 $p → q$ 经过 `neg` 变成 $¬q → ¬p$，经过 `cps` 变成 $p → ¬¬q$，而 `flip` 在后两种之间互转。既然这三种形状反复出现，不妨为它们取个名字：

```racket
(define-type (→𝒞 p q) (→ p q))
(define-type (→𝒦 p q) (→ p (¬¬ q)))
(define-type (→𝒰 p q) (→ (¬ q) (¬ p)))

(: neg   (∀ (p q) (→ (→𝒞 p q) (→𝒰 p q))))
(: cps   (∀ (p q) (→ (→𝒞 p q) (→𝒦 p q))))
(: flip  (∀ (p q) (→ (→𝒰 p q) (→𝒦 p q))))
(: flip¹ (∀ (p q) (→ (→𝒦 p q) (→𝒰 p q))))
```

| 世界       | 箭头类型            |
|------------|---------------------|
| 𝒞 宿主世界 | $p →_𝒞 q = p → q$   |
| 𝒦 CPS 世界 | $p →_𝒦 q = p → ¬¬q$ |
| 𝒰 逆否世界 | $p →_𝒰 q = ¬q → ¬p$ |

每种箭头类型自成一个世界，四个运算符在世界之间搬运箭头。其中 `flip` 和 `flip¹` 互逆，所以 𝒰 和 𝒦 之间可以自由互转。但搬运只是第一步：两个 𝒰 箭头，或两个 𝒦 箭头，能在各自的世界里复合吗？

𝒰 可以直接写出来。两个 𝒰 箭头 $p →_𝒰 q$ 和 $q →_𝒰 r$，复合后期望得到 $p →_𝒰 r$。展开别名：前者是 $¬q → ¬p$，后者是 $¬r → ¬q$，期望的结果是 $¬r → ¬p$。在宿主里 $(¬q → ¬p) ∘ (¬r → ¬q) = ¬r → ¬p$，刚好接得上，只是复合的顺序反了过来：

```racket
(: ∘𝒰 (∀ (p ...) (→ (→𝒰 pn-1 pn) ... (→𝒰 p1 p2) (→𝒰 p1 pn))))
(define (∘𝒰 . neg:f*) (apply ∘ (reverse neg:f*)))
```

𝒦 的箭头却不能直接复合：$p → ¬¬q$ 接不上 $q → ¬¬r$，中间差一个 $¬¬$。不过 `flip` 和 `flip¹` 互逆，𝒦 的箭头可以无损地搬到 𝒰 再搬回来。$p →_𝒦 q$ 经 `flip¹` 变成 $p →_𝒰 q$，$q →_𝒦 r$ 变成 $q →_𝒰 r$，保持着首尾相连的关系，在 𝒰 那边复合得到 $p →_𝒰 r$，最后通过 `flip` 变回 $p →_𝒦 r$：

```racket
(: ∘𝒦 (∀ (p ...) (→ (→𝒦 pn-1 pn) ... (→𝒦 p1 p2) (→𝒦 p1 pn))))
(define (∘𝒦 . cps:f*) (flip (apply ∘𝒰 (map flip¹ cps:f*))))
```

这个定义是照着类型接出来的：搬过去，复合，再搬回来。它算出来的是什么？取两支箭头，把 `(flip¹ cps:f)` 记作 `neg:f`，`(flip¹ cps:g)` 记作 `neg:g`，再交给 `(∘𝒦 cps:g cps:f)` 一个输入 `x` 和一个延续 `k`：

```racket
  (((∘𝒦 cps:g cps:f) x) k)
= (((flip (∘𝒰 neg:g neg:f)) x) k)
= (((flip (∘ neg:f neg:g)) x) k)
= (((∘ neg:f neg:g) k) x)
= ((neg:f (neg:g k)) x)
= ((cps:f x) (neg:g k))
= ((cps:f x) (λ (y) ((cps:g y) k)))
```

前两步拆开 `∘𝒦` 和 `∘𝒰` 的定义，`flip` 再把 `k` 换到 `x` 前面：`k` 先交给 `neg:g`，再交给 `neg:f`，和接闭包链时一样。最后两步把两个 `flip¹` 拆开，𝒰 就不见了。`cps:f` 拿到 `x`，收到的延续是 `(λ (y) ((cps:g y) k))`：拿到 `y`，交给 `cps:g`，`cps:g` 的结果再交给 `k`。

手写 `fib/k` 时，`(λ (v) (fib/k (- n 2) (λ (w) (k (+ v w)))))` 就是这样写出来的：后一步连同它的延续包成一个 λ，交给前一步。`∘𝒦` 把这个包法做成了复合。

# 经典与构造

`neg` 和 `cps` 把 𝒞 的箭头搬到 𝒰 和 𝒦，`flip` 在 𝒰 和 𝒦 之间互转。那反过来呢？能把 𝒰 或 𝒦 的箭头转回 𝒞 吗？

先写下类型，看 Curry-Howard 说什么。从 𝒦 回来：

$$(p →_𝒦 q) → (p →_𝒞 q) \;=\; (p → ¬¬q) → (p → q)$$

类型展开后要求把 $¬¬q$ 变成 $q$，这就是 DNE，第一篇见过的经典定理。从 𝒰 回来：

$$(p →_𝒰 q) → (p →_𝒞 q) \;=\; (¬q → ¬p) → (p → q)$$

逆否律的逆方向，同样是经典定理。

Curry-Howard 给了明确的信号：两个方向都是经典定理，不是直觉主义定理。想把 𝒰/𝒦 的箭头转回 𝒞，必须借助经典的控制操作，例如 `call/cc`。

我们知道 `call/cc` 的类型读作 $¬¬p → p$，即 DNE。反过来，`(cps values)` 的类型是 $p → ¬¬p$，即 DNI。DNI 包进 $¬¬$，DNE 拆出来。用 DNE 定义反方向的变换，把 CPS 箭头的 $¬¬$ 拆掉：

```racket
(: uncps (∀ (p q) (→ (→𝒦 p q) (→𝒞 p q))))
(define (uncps cps:f) (∘ call/cc cps:f))
```

`cps` 包裹，`uncps` 解包。它们互相抵消吗？如果是，𝒦 和 𝒞 就是同一个世界。

先看去程。把 `(uncps (cps f))` 应用于参数，展开：

```racket
((uncps (cps f)) . p*)  =  (call/cc ((cps f) . p*))
                        =  (call/cc (λ (kq) (kq (f . p*))))
                        =  (f . p*)
```

第三步用到之前的尾位置论证：`(call/cc (λ (k) (k expr)))` 中 `(k expr)` 处于尾位置，捕获的延续就是 `call/cc` 自己的延续，显式调用和正常返回汇入同一个出口，包裹可以消除。DNI 接上 DNE 就是恒等。

反方向呢？展开 `(cps (uncps cps:f))`：

```racket
((cps (uncps cps:f)) . p*)  =  (λ (kq) (kq ((uncps cps:f) . p*)))
                            =  (λ (kq) (kq (call/cc (cps:f . p*))))
                            ;; (kq _) 的延续就是 kq 自身
                            =  (λ (kq) ((cps:f . p*) kq))
                            =  (cps:f . p*)
```

第三步需要解释。在 `(kq (call/cc (cps:f . p*)))` 中，`call/cc` 捕获的延续是什么？是「把值交给 `kq`」这个动作。但 `kq` 本身就是延续参数，`(kq ...)` 之后不会再有代码执行，所以捕获到的延续就是 `kq` 本身。于是 `(call/cc (cps:f . p*))` 等价于 `((cps:f . p*) kq)`，`kq` 外面那一层包裹消失了。

两个方向都是恒等，$𝒦 ≅ 𝒞$。连同之前的 `neg` 和 `flip`，三个世界之间的关系整理成图表：

```
 𝒞 ←───────────┐
 │             │
 │             │
neg          uncps
 │             │
 ↓             │
 𝒰 ───flip───→ 𝒦
```

这是一张**交换图表**（commutative diagram）：从一个世界到另一个世界，无论沿哪条路径走，结果相同。三条边首尾相接，构成一个环：从 𝒞 出发，经 `neg`、`flip`、`uncps` 走一圈回到 𝒞，得到的还是原来的箭头。前两步复合起来正是 `cps = (∘ flip neg)`，而 `uncps` 抵消 `cps`，上一节已经验证过。

交换性让我们免费得到新的运算符。从 𝒰 到 𝒞 没有直达的路，但图表中有一条经 𝒦 的路径：

```racket
(: unneg (∀ (p q) (→ (→𝒰 p q) (→𝒞 p q))))
(define unneg (∘ uncps flip))
```

于是 $𝒰 ≅ 𝒦 ≅ 𝒞$。三个世界是同一个世界的三种写法。

>**注意：** 这个同构只在观察程序行为的意义下成立，而且有两个前提。其一，反方向化简的第三步依赖 `kq` 真的通过跳转离开、永不返回；如果延续会正常返回，这一步就不成立。其二，Racket 的 `dynamic-wind` 能观察到延续是 lambda 还是 `call/cc` 捕获的跳转，因此 `(k (call/cc proc))` 和 `(proc k)` 在完整的 Racket 中并不完全相同。

## 两个 call/cc

`uncps` 用了 `call/cc`，这是从 𝒦 回到 𝒞 的桥的代价。但看看桥两头：`neg`、`cps`、`flip` 全是纯 lambda，没有一处 `call/cc`。𝒰 和 𝒦 的定义是纯构造性的，与 𝒞 的同构却说它们拥有经典逻辑的全部力量。

𝒞 有 `call/cc`，其类型对应 Clavius 律。𝒰 和 𝒦 与 𝒞 同构，所以也满足 Clavius 律，那它们也应该有各自的 `call/cc`。

`call/cc` 捕获当前延续，把隐式的控制流变成一等值传给 `proc`。而 𝒰 和 𝒦 的箭头本身就接受延续参数，延续已经是显式的了，不需要额外的捕获机制。每个世界的 `call/cc` 只要把延续参数 `kp` 提升到本世界的箭头类型，交给 `proc`：

```racket
(define-type (¬𝒦 p) (→𝒦 p ⊥))
(define-type (¬𝒰 p) (→𝒰 p ⊥))

(: cps:call/cc (∀ (p) (→𝒦 (→𝒦 (¬𝒦 p) p) p)))
(: neg:call/cc (∀ (p) (→𝒰 (→𝒰 (¬𝒰 p) p) p)))

(define ((cps:call/cc cps:proc) kp) ((cps:proc (cps kp)) kp))
(define ((neg:call/cc kp) neg:proc) ((neg:proc kp) (neg kp)))
```

两个定义只用了 lambda 和函数应用。经典逻辑的力量不是从外部引入的，而是从延续编码中长出来的。

> **练习：** 展开 `cps:call/cc` 的类型别名，验证 $(¬_𝒦 p →_𝒦 p) →_𝒦 p$ 就是 Clavius 律。对 `neg:call/cc` 做同样的事。

## 否定翻译

从 𝒰 或 𝒦 回到 𝒞，代价是 `call/cc`：消除 $¬¬$ 是经典操作。但看看另一面：搭建 𝒰 和 𝒦 本身不需要 `call/cc`，全部构件都是纯 lambda。这意味着一个没有 `call/cc` 的纯构造性宿主也足以搭建它们。

把宿主一分为二：带 `call/cc` 的部分仍叫 𝒞，拿掉 `call/cc` 剩下的叫 𝒟，是直觉主义的。𝒟 是 𝒞 的一部分，𝒟 的箭头在 𝒞 里同样合法：

```racket
(define-type (→𝒟 p q) (→ p q))

(: inj (∀ (p q) (→ (→𝒟 p q) (→𝒞 p q))))
(define (inj f) f)
```

`inj` 把 𝒟 的箭头注入 𝒞，不需要任何代价。反方向做不到：`uncps` 用了 `call/cc`，而 `call/cc` 不属于 𝒟。回到 𝒞 的障碍是消除 $¬¬$，那是经典操作。那如果不消除？能不能从 𝒰 或 𝒦 直接落回 𝒟？

𝒰 的箭头 $¬q → ¬p$ 本身就是 𝒟 的函数，似乎已经在 𝒟 里了。但检查一下首尾相连的条件。节点从宿主的 $p$ 映射到 $¬p$，那么 𝒰 箭头 $p →_𝒰 q$ 搬回 𝒟 之后，起点应该是 $¬p$，终点应该是 $¬q$。可 $¬q → ¬p$ 的起点是 $¬q$，终点是 $¬p$。**两端对调了。**

前面 `∘𝒰` 定义里那个 `reverse` 就是这次对调的证据：在 𝒰 内部一切正常，首尾相连也好复合也好，别名在兜底。一旦拆掉别名直接读回宿主，方向就露出来了。

既然方向是反的，不如在类型里直接写出来。定义一个反着写的箭头，结果写在左边，参数写在右边：

```racket
(define-type (← q p) (→ p q))
```

`(← q p)` 和 `(→ p q)` 是同一个函数类型，只是书写方向相反。用它重写 𝒰 的箭头：

```racket
(define-type (→𝒰 p q) (← (¬ p) (¬ q)))
```

$p$、$q$ 的先后依次对应 $¬p$、$¬q$，首尾相连在书写上照常成立；箭头却指向 $¬p$。𝒰 的箭头，就是两个否定之间的一支反向箭头。

方向反了一次，再反一次就正了。再用一次 `neg`：

```racket
(: neg¹ (∀ (p q) (→ (→𝒰 p q) (→𝒟 (¬¬ p) (¬¬ q)))))
(define neg¹ neg)
```

`neg¹` 就是 `neg`，同一段代码用在高一层。类型 $(¬q → ¬p) → (¬¬p → ¬¬q)$ 也是一条直觉主义定理。这次起点 $¬¬p$、终点 $¬¬q$，都对。

四个世界的全貌：

| 世界                  | 箭头类型            | 逻辑     |
|-----------------------|---------------------|----------|
| 𝒟：宿主（无 call/cc） | $p →_𝒟 q = p → q$   | 直觉主义 |
| 𝒞：宿主（有 call/cc） | $p →_𝒞 q = p → q$   | 经典     |
| 𝒦：CPS                | $p →_𝒦 q = p → ¬¬q$ | 经典     |
| 𝒰：逆否               | $p →_𝒰 q = ¬p ← ¬q$ | 经典     |

在前面的三世界图表基础上加入 𝒟：

```
 𝒟 ───inj────→ 𝒞 ←───────────┐
 ↑             ↑             │
 │             │             │
 │          [un]neg       [un]cps
 │             │             │
 │             ↓             ↓
 └────neg¹──── 𝒰 ←─flip[¹]─→ 𝒦
```

𝒞、𝒰、𝒦 三者之间每条边都可逆（方括号标出逆运算），是同一个世界的三种写法。`neg¹` 从 𝒰 到 𝒟 是单向的，而且改变了节点：$p$ 变成 $¬¬p$。`inj` 是 𝒟 进入 𝒞 的单向注入。

图表上从 𝒞 经 𝒰 到 𝒟 有一条路径。`neg` 把 𝒞 的箭头送到 𝒰，`neg¹` 把 𝒰 的箭头落回 𝒟：

```racket
(: neg² (∀ (p q) (→ (→𝒞 p q) (→𝒟 (¬¬ p) (¬¬ q)))))
(define neg² (∘ neg¹ neg))
```

出发时 $p →_𝒞 q$，落地时 $¬¬p →_𝒟 ¬¬q$。经典世界的箭头类型，变成了构造性世界的箭头类型，代价是每个类型裹上 $¬¬$。两层不是凑出来的：第一层（`neg`）把延续变成参数，这是全部经典能力的来源；第二层（`neg¹`）什么也没添，只是把翻过去的方向翻回来。

不过 `neg²` 翻译的只是箭头的类型，不是箭头里的程序：`(neg² f)` 运行时仍然原样调用 `f`，`f` 若用了 `call/cc`，包装之后照样依赖它。要让程序本身落在 𝒟 里，每一步都得写成 𝒦 的箭头，`call/cc` 也换成 𝒦 世界自己的 `cps:call/cc`。图表上正好还有一条从 𝒦 经 𝒰 到 𝒟 的路径：

```racket
(: cps->neg² (∀ (p q) (→ (→𝒦 p q) (→𝒟 (¬¬ p) (¬¬ q)))))
(define cps->neg² (∘ neg¹ flip¹))
```

落到 𝒟 以后，箭头用宿主的 `∘` 就能接。`cps:f` 的类型是 $p → ¬¬q$，`cps:g` 的类型是 $q → ¬¬r$，「三种箭头」一节里它们接不上，中间差一个 $¬¬$。只搬后一支就够了：`(cps->neg² cps:g)` 的类型是 $¬¬q → ¬¬r$，补上的正是这一层，`cps:f` 交出的 $¬¬q$ 它直接收下。把它记作 `neg²:g`，`(∘ neg²:g cps:f)` 就是一支 $p → ¬¬r$ 的箭头。

它和绕道 𝒰 接出来的 `(∘𝒦 cps:g cps:f)` 是同一支吗？那里的化简经过 `((cps:f x) (neg:g k))` 这一行。从它出发，换一个方向：

```racket
  ((cps:f x) (neg:g k))
= (((neg¹ neg:g) (cps:f x)) k)
= ((neg²:g (cps:f x)) k)
= (((∘ neg²:g cps:f) x) k)
```

`neg¹` 就是 `neg`，`((neg¹ neg:g) kk)` 是 `(∘ kk neg:g)`：交给 `kk` 的延续，先由 `neg:g` 在前面接上一段。取 `kk` 为 `(cps:f x)`，就是第一行。而 `neg:g` 是 `(flip¹ cps:g)`，`(neg¹ neg:g)` 按定义正是 `neg²:g`。两种接法是一回事：

```racket
(∘𝒦 cps:g cps:f)  =  (∘ neg²:g cps:f)
```

两段化简都没有用到 `cps:f`、`cps:g` 的来历，用了 `cps:call/cc` 的箭头也一样。𝒦 的箭头连同它们的复合，就这样整个落在了 𝒟 里。

经典逻辑并非偷渡到 𝒟，走进 𝒟 的是它裹了 $¬¬$ 的样子。这就是第一篇结尾提到的**否定翻译**，也叫双重否定翻译。

> **注意：** 否定翻译有几种变体，差别在于 $¬¬$ 插在哪里。本文 𝒦 世界的箭头 $p → ¬¬q$ 对应按值调用的 CPS，最接近 Kuroda 的版本；按名调用的 CPS 则对应 Kolmogorov 的版本（Murthy, 1990）。

第一篇留下的问题，一门构造性语言怎么能支持经典推理，到这里有了回答：*编码*这一步不需要 `call/cc`。

一等控制能力有了，写法却还是 CPS。手写 `mul` 时的那句抱怨仍然成立：程序员必须亲手编写每一个延续。用 `∘𝒦` 可以不写，箭头却只能一支支首尾排开，中间结果没有名字。

# 再次隐藏延续

回想开头的观察。`let` 脱糖为 lambda 调用，延续藏在 `let` 里面：等待结果的那个 λ 不用我们写，绑定的语法替我们写了。CPS 变换把延续拉出来变成显式参数，这个 λ 就得亲手写。能不能反过来：用 `let` 语法把 CPS 的延续再藏回去？

先看一个具体例子。假设我们有 CPS 提升的加法 `cps:+` 和乘法 `cps:*`，想计算 `(1 + 2) × 3`：

```racket
(anf:let ([v (cps:+ 1 2)])
  (cps:* v 3))
```

照 `let` 的办法，函数体包成 `(λ (v) (cps:* v 3))`，再用在 `(cps:+ 1 2)` 上。可是用不上去：`(cps:+ 1 2)` 是一个 $¬¬\text{Nat}$，这个 λ 要的是普通的 `v`。「否定翻译」一节里 `cps:g` 接不到 `(cps:f x)` 后面，是同一个情形，补一个 `cps->neg²` 就接上了。宏照这样展开：

```racket
(let ([kkv (cps:+ 1 2)])              ; kkv : ¬¬Nat
  (define (cps:kv v)                  ; cps:kv : Nat →𝒦 Nat
    (cps:* v 3))
  (define neg²:kv (cps->neg² cps:kv)) ; neg²:kv : ¬¬Nat → ¬¬Nat
  (neg²:kv kkv))                      ; 连接
```

把三个名字代回去，与 `let` 的脱糖并排，只多一个 `cps->neg²`：

```racket
(let     ([v e]) b)  =  ((λ (v) b) e)
(anf:let ([v e]) b)  =  ((cps->neg² (λ (v) b)) e)
```

多个绑定 `anf:let*` 是嵌套的单个绑定，和 `let*` 一样。开头看过宿主里接连两个绑定的展开：两层 λ，拿掉只把 `z` 原样交出的那一层，剩下 `((∘ g f) x)`。`anf:let*` 走的是同样的几步。只把 `z` 交出去的那一步，在 𝒦 里是 `(cps values)`，前面认出它的类型是 DNI，下面记作 `cps:id`：

```racket
  (anf:let* ([y (cps:f x)]
             [z (cps:g y)])
    (cps:id z))
= ((cps->neg²
    (λ (y)
      ((cps->neg²
        (λ (z)
          (cps:id z)))
       (cps:g y))))
   (cps:f x))
= ((cps->neg²
    (λ (y)
      ((cps->neg² cps:id)
       (cps:g y))))
   (cps:f x))
= ((cps->neg²
    (λ (y) (neg²:id (cps:g y))))
   (cps:f x))
= ((cps->neg²
    (λ (y) (cps:g y)))
   (cps:f x))
= ((cps->neg² cps:g)
   (cps:f x))
= (neg²:g (cps:f x))
= ((∘ neg²:g cps:f) x)
= ((∘𝒦 cps:g cps:f) x)
```

两层 λ 同样是语法写的，每层多一个 `cps->neg²`。`cps:id` 是 `(cps values)`，`cps` 里的 `flip` 被 `cps->neg²` 里的 `flip¹` 抵消，`(cps->neg² cps:id)` 就是 `(neg² values)`，记作 `neg²:id`：什么也不做的函数搬过去，还是什么也不做，这一层可以拿掉。最后一步是「否定翻译」一节的等式。两边并排：

```racket
(let*     ([y     (f x)] [z     (g y)])         z)   =  ((∘      g     f) x)
(anf:let* ([y (cps:f x)] [z (cps:g y)]) (cps:id z))  =  ((∘𝒦 cps:g cps:f) x)
```

`let*` 是 `∘` 的另一种写法，`anf:let*` 是 `∘𝒦` 的另一种写法，多出来的是中间结果的名字。「三种箭头」一节看过 `∘𝒦` 展开的样子，`((cps:f x) (λ (y) ((cps:g y) k)))`：手写 CPS 时的那个 λ 还在，只是不用我们写了。

把这些写成宏。`anf:let` 就是只有一个绑定的 `anf:let*`，定义省去：

```racket
(define-syntax anf:let*-values
  (syntax-rules ()
    [(_ () b* ...)
     (anf:begin b* ...)]
    [(_ ([v* e]) b* ...)
     (let ([kkv e])
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

(define-syntax-rule (anf:if test conseq alt)
  (let ([kkb test])
    (define (cps:kb . b*) (if (equal? b* '(#f)) alt conseq))
    (define neg²:kb (cps->neg² cps:kb))
    (neg²:kb kkb)))

(define-syntax-rule (anf:let/cc cps:k b* ...)
  (cps:call/cc (λ (cps:k) b* ...)))
```

`anf:if` 中 `cps:kb` 是可变参数的：测试值作为列表 `b*` 到达。在 Racket 中只有 `#f` 是假值，所以 `(equal? b* '(#f))` 恰好检测单值为假的情况。

宏充当编译器，把类似 ANF 的语法翻译成 $¬¬$ 编码的 CPS。还缺一个解释器，把编码后的程序运行出结果：

```racket
(: anf:eval (∀ (a) (→ (¬¬ a) a)))
(define (anf:eval kka) (⊥->a (kka a->⊥)))
```

`anf:eval` 的类型是 $¬¬a → a$：接收一个编码后的程序，提供 `a->⊥` 作为初始延续，`⊥->a` 捕获答案。

宏在展开时把程序编码为 $¬¬a$，`anf:eval` 在运行时交入初始延续。这和第一篇里操作系统运行程序是同一种分工：程序是一个 $¬¬\text{Byte}$，退出通道由操作系统在启动时交给它。`anf:eval` 扮演的就是操作系统。

# 嵌入语言

手写的 CPS 版 `mul` 有两处要程序员亲自动手：正常路径上，每一步都要写出新的延续 `(λ (v) (k (* v r)))`；遇到零时，要手动改调 `a->⊥`。在嵌入语言里，前一件由 `anf:let*` 完成，后一件交给 `anf:let/cc` 捕获的延续。用到的宿主函数先经 `cps` 提升：

```racket
(define cps:id        (cps values))
(define cps:+         (cps +))
(define cps:*         (cps *))
(define cps:zero?     (cps zero?))
(define cps:car       (cps car))
(define cps:cdr       (cps cdr))
(define cps:null?     (cps null?))
(define cps:display   (cps display))
(define cps:displayln (cps displayln))
```

它们都是 𝒦 的箭头，可以直接放进 `anf:let*` 和 `anf:if`：

```racket
(anf:eval
 (anf:let/cc cps:return
   (let cps:loop ([r* '(1 2 0 3 4)])
     (anf:if (cps:null? r*)
             (cps:*)
             (anf:let* ([r (cps:car r*)])
               (anf:if (cps:zero? r)
                       (cps:return r)
                       (anf:let* ([r* (cps:cdr r*)]
                                  [res (cps:loop r*)])
                         (cps:* res r))))))))
;; => 0
```

`anf:let/cc` 捕获的 `cps:return` 是 CPS 世界的逃逸通道：遇零时调用它，直接跳出循环。其余每一步的延续都由 `anf:let*` 接好，程序员不需要触碰。

`cps:return` 只用来跳出循环。第一篇的阴阳谜题对延续要求更多：被捕获的延续要作为值传来传去，再被调用。`label` 和整个谜题在嵌入语言里写作：

```racket
(define (cps:label) (cps:call/cc cps:id))

(anf:eval
 (anf:let* ([cps:yin (cps:label)])
   (cps:display #\@)
   (anf:let* ([cps:yang (cps:label)])
     (cps:display #\*)
     (cps:yin cps:yang))))
;; => @*@**@***@****@...
```

`(cps:yin cps:yang)` 中，`cps:yin` 是一个捕获的延续。它可以直接作为 CPS 箭头调用，因为 `cps:call/cc` 在交给用户函数之前已经用 `(cps kp)` 把裸的延续提升到了 CPS 世界的箭头类型。

## 计算的位置

阴阳谜题里，被捕获的延续是一个个具体的值，可以传递，也可以调用。没有被捕获的延续同样是具体的值。回到开头 ANF 版的 `fib`：

```racket
(let* ([n-1 (- n 1)]
       [v   (fib n-1)]
       [n-2 (- n 2)]
       [w   (fib n-2)])
  (+ v w))
```

每个绑定处都是一个计算位置，也都有一个具体的延续在等待这个位置的结果：`w` 处的延续拿到 `w`，算出 `(+ v w)`，交给出口；`v` 处的延续拿到 `v`，接着算 `n-2` 和 `w`，最后同样交给出口。第一篇的 `(let ([l (label)]) ...)` 用标签把位置显式地捕获下来；这里的位置藏在嵌套的 `let` 里，标记的是同一种东西。这些延续的类型都是 $¬\text{Natural}$，每一个都是这个类型的一个具体元素。

相邻两个位置上的延续，只差中间那一步。从一处到下一处的一步是 `f`，后一处的延续是 `kq`，前一处的延续 `kp` 就是：

```racket
kp  =  ((neg f) kq)  =  (∘ kq f)
```

`neg` 先接收延续，正好用来从后一处造出前一处。出口处的延续是 `k`，在最外层它就是初始延续 `a->⊥`。`(neg (λ (w) (+ v w)))` 把 `k` 变成 `w` 处的延续，`(neg fib)` 再把它变成 `n-2` 处的延续。整条链从 `a->⊥` 开始，一环环向内建起来。

运行时方向相反。同一条等式换个读法：`(kp p)` 就是 `(kq (f p))`，值走完 `f` 这一步，等着它的延续就从 `kp` 换成了 `kq`。`(- n 1)` 的结果交给 `n-1` 处的延续，值从这里出发，算完 `(fib n-1)` 抵达 `v` 处，再到 `n-2` 处、`w` 处，最后交给 `a->⊥`。`a->⊥` 既是延续构造的起点，也是值移动的终点。执行一个程序，就是从一个具体的延续走到下一个具体的延续。

---

# 结论

开头的 `fib` 写成 `let*` 之后，延续藏在每个绑定里，由宿主保管；要把它当作值拿到手，只能靠 `call/cc`。嵌入语言里的 `anf:let*` 写法几乎相同，展开后，每个绑定之后的代码却被包成了一个 λ，接上末尾的延续，作为参数交给前一步；`cps:call/cc` 只需把手里的参数交给程序。同样的 `let*`，背后的复合从 `∘` 换成了 `∘𝒦`，延续从宿主的调用栈变成了程序手里的参数。

延续成为参数以后，控制流就是在几条延续之间选择调用哪一条：手写的 CPS 版 `mul` 在 `k` 和 `a->⊥` 之间选择，嵌入语言版在 `anf:let*` 接好的延续和 `cps:return` 之间选择。宿主的 `call/cc` 在这篇的代码里只出现在 `uncps`：从 𝒦 回到 𝒞，要求 CPS 箭头像普通函数一样返回一个值。不提这个要求，箭头就能留在 𝒟 里，代价是每个类型裹上 $¬¬$。

## 未解的线索

`neg`、`cps`、`flip`、`neg²`、`cps:call/cc`，一直到 `anf:` 宏，全部是纯 lambda，全部住在 𝒟 里。经典嵌入语言的每一步计算，经过这条流水线，变成宿主 𝒟 里一个 $¬¬a$ 类型的值。*编码*完成了。编码之后的 $¬¬a$ 值可以继续复合和变换：`neg²:f` 把 $¬¬a$ 映射为 $¬¬b$，`anf:let*` 把多步计算串成一条链，`cps:call/cc` 在编码内部提供经典控制，每一步都在 𝒟 内部完成。

但 $¬¬a$ 不是 $a$。展开别名：$¬¬a = (a → ⊥) → ⊥$，它是一个等待延续的函数。要从中取出 $a$ 类型的结果，必须向它提供一个 $a → ⊥$ 类型的初始延续。第一篇论证过：对任何非空的 $a$，$a → ⊥$ 是空的，构造性的 𝒟 无法交出这个参数。`anf:eval` 做的恰恰是这件事：它的类型 $¬¬a → a$ 对应 DNE，要求对任意 $a$ 都能提供初始延续并交出结果。𝒟 能够编码经典计算，能够在编码之间复合和变换，但无法构造一个对任意类型都成立的解释器来提取最终结果。

回头审视流水线，缺口的面貌更清晰。`neg` 造的是延续之间的*映射*：给定 $f : p → q$，把 $¬q$ 变换为 $¬p$。`flip` 交换参数顺序，`neg²` 两次取逆否，`anf:let*` 复合它们，每一步操作的都是 $¬$ 之间的映射关系，从不需要 $¬$ 的*元素*，即某一个具体的 $¬a$。偏偏启动 $¬¬a$ 那一刻需要的恰恰是元素。

`anf:eval` 用 `a->⊥` 填了这个位置，但 `a->⊥` 不是 𝒟 自己产出的：`raise` 和 handler 都是宿主内置的机制。它是从宿主*借*来的一个 $¬a$ 元素；程序里每个位置上的延续，都是在它前面接上一段普通函数得来的。`a->⊥` 的跳转来自 `raise`，而跳转函数的返回类型是 $⊥$，第一篇定义 `goto : Label → ⊥` 时就确立了这一点。不借用宿主的跳转，$⊥$ 根本不会出现在代码里。

回顾两个边界操作的名字：`a->⊥` 和 `⊥->a`。按字面读，它们似乎在说 $a$ 和 $⊥$ 可以互相转化。但 $⊥$ 是空类型，没有值的类型，而 $a$ 是一个完全正常的、拥有值的类型。它们怎么可能互相转化？$⊥$ 到底是什么？

那是[另一篇文章](https://zhuanlan.zhihu.com/p/2032178684895946051)的故事了。

---

# 完整代码参考

```racket
#lang typed/racket/no-check

(provide (all-defined-out))

(define ∘ compose)
(define (list->values v*) (apply values v*))


;;; 类型别名

(define-type ⊥ (∪))
(define-type (¬  a) (→ a ⊥))
(define-type (¬¬ a) (¬ (¬ a)))
(define-type (← q p) (→ p q))


;;; 答案类型（通过 raise 实现初始延续）

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

(: neg (∀ (p q) (→ (→𝒞 p q) (→𝒰 p q))))
(: neg¹ (∀ (p q) (→ (→𝒰 p q) (→𝒟 (¬¬ p) (¬¬ q)))))
(define ((neg f) kq) (∘ kq f))
(define neg¹ neg)

(: ∘𝒰 (∀ (p ...) (→ (→𝒰 pn-1 pn) ... (→𝒰 p1 p2) (→𝒰 p1 pn))))
(define (∘𝒰 . neg:f*) (apply ∘ (reverse neg:f*)))


;;; CPS 世界

(define-type (→𝒦 p q) (→ p (¬¬ q)))
(define-type (¬𝒦 p)   (→𝒦 p ⊥))

(: flip  (∀ (p q) (→ (→𝒰 p q) (→𝒦 p q))))
(: flip¹ (∀ (p q) (→ (→𝒦 p q) (→𝒰 p q))))
(define (((flip f) . y*) . x*) (apply (apply f x*) y*))
(define flip¹ flip)

(: cps   (∀ (p q) (→ (→𝒞 p q) (→𝒦 p q))))
(: uncps (∀ (p q) (→ (→𝒦 p q) (→𝒞 p q))))
(define cps (∘ flip neg))
(define (uncps cps:f) (∘ call/cc cps:f))

(: ∘𝒦 (∀ (p ...) (→ (→𝒦 pn-1 pn) ... (→𝒦 p1 p2) (→𝒦 p1 pn))))
(define (∘𝒦 . cps:f*) (flip (apply ∘𝒰 (map flip¹ cps:f*))))


;;; Clavius 律

(: neg:call/cc  (∀ (p) (→𝒰 (→𝒰 (¬𝒰 p) p) p)))
(: cps:call/cc  (∀ (p) (→𝒦 (→𝒦 (¬𝒦 p) p) p)))

(define ((neg:call/cc kp) neg:proc) ((neg:proc kp) (neg kp)))
(define ((cps:call/cc cps:proc) kp) ((cps:proc (cps kp)) kp))


;;; 否定翻译

(: neg² (∀ (p q) (→ (→𝒞 p q) (→𝒟 (¬¬ p) (¬¬ q)))))
(define neg² (∘ neg¹ neg))

(: cps->neg² (∀ (p q) (→ (→𝒦 p q) (→𝒟 (¬¬ p) (¬¬ q)))))
(define cps->neg² (∘ neg¹ flip¹))


;;; anf: 宏

(define-syntax anf:let*-values
  (syntax-rules ()
    [(_ () b* ...)
     (anf:begin b* ...)]
    [(_ ([v* e]) b* ...)
     (let ([kkv e])
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

(define-syntax-rule (anf:if test conseq alt)
  (let ([kkb test])
    (define (cps:kb . b*) (if (equal? b* '(#f)) alt conseq))
    (define neg²:kb (cps->neg² cps:kb))
    (neg²:kb kkb)))

(define-syntax-rule (anf:let/cc cps:k b* ...)
  (cps:call/cc (λ (cps:k) b* ...)))


;;; 解释器

(: anf:eval (∀ (a) (→ (¬¬ a) a)))
(define (anf:eval kka) (⊥->a (kka a->⊥)))


;;; CPS 提升的基本操作

(define cps:id        (cps values))
(define cps:+         (cps +))
(define cps:*         (cps *))
(define cps:zero?     (cps zero?))
(define cps:car       (cps car))
(define cps:cdr       (cps cdr))
(define cps:null?     (cps null?))
(define cps:display   (cps display))
(define cps:displayln (cps displayln))
```
