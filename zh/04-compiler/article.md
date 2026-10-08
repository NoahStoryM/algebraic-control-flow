# 前沿回望之时：机器中的镜子

大家好，

这是控制流系列的第四篇。[第一篇](https://zhuanlan.zhihu.com/p/2019516690904401803)中，我们从一等标签出发构建了 `call/cc`，发现了控制操作符与经典逻辑之间的 Curry-Howard 对应。[第二篇](https://zhuanlan.zhihu.com/p/2024852076593694078)中，我们构造了逆否世界 𝒰 和 CPS 世界 𝒦，用否定翻译让构造性的 𝒟 在内部模拟经典逻辑，并用 `anf:` 宏构建了一门将 ANF 编译为 CPS 的嵌入语言。[第三篇](https://zhuanlan.zhihu.com/p/2032178684895946051)中，我们把延续的终点从 $⊥$ 换成了局部答案 $⊥ᵃ$。取平凡表示时，局部空就是普通的答案类型 $a$：局部延续成了普通函数 $p → a$，初始局部延续就是恒等函数，`reset` 开启一段新的局部计算，`shift` 则是命名了局部延续的 `return`。

第三篇「定界延续与 CPS」一节把几个例子手工化简成了 CPS，并把其中的对应整理成几组对应表：CPS 把等待结果的工作作为参数传进去，ANF 用 `let` 把它藏起来，`shift` 在原来的位置把它取出来。文章结尾又回到这些表：每一组是同一个程序的几种写法，写法之间的转换是机械的，应当能交给一个程序去做。

这个程序一边读源代码，一边要记住读完当前这一块之后还得接着写什么：它也有自己的剩余工作。这份剩余工作能以哪些形式存在？第二篇的 `fib` 里就能找到好几种。

---

# 从递归到遍历

这是第二篇中的 `fib`，斐波那契函数：

```racket
(define (fib n)
  (if (< n 2)
      n
      (+ (fib (- n 1))
         (fib (- n 2)))))
```

它是递归的，而且不是尾递归：每次子调用返回后，还有待执行的工作（第二次子调用，然后是加法）。这些待执行的工作活在调用栈上。怎么把它变成循环？

标准技巧：自己管理栈。用一个显式的**帧**（frame）列表替换隐式的调用栈，每个帧记录一件待执行的工作和它所需的数据。`fib` 中出现两种待执行的工作：「第一次子调用返回了，现在算第二次」（需要 `(- n 2)`）和「两次子调用都返回了，现在相加」（需要第一个结果）。给每种打上标签，压入列表：

```racket
(define (fib n) (fib/k n '()))

(define (fib/k n k)
  (if (< n 2)
      (apply-cont k n)
      (fib/k (- n 1) (cons `(fib ,(- n 2)) k))))

(define (apply-cont k v)
  (match k
    ['() v]
    [`((fib ,n-2) . ,k) (fib/k n-2 (cons `(add ,v) k))]
    [`((add ,w) . ,k)   (apply-cont k (+ w v))]))
```

`fib/k` 压入一个 `(fib ...)` 帧，然后递归。当基础情况触发时，`apply-cont` 根据栈顶帧分派。`(fib n-2)` 帧意味着「第一次子调用完成了，现在做第二次」，于是压入一个 `(add v)` 帧并再次调用 `fib/k`。`(add w)` 帧意味着「两次子调用都完成了，相加然后继续」，于是弹出帧并在尾部递归。每次调用都是尾调用；帧列表就是栈。

## 认出延续

`fib/k` 的第二个参数是什么？第二篇中，我们把 `fib` 写成了 CPS 形式：

```racket
(define (fib/k n k)
  (if (< n 2)
      (k n)
      (fib/k (- n 1)
             (λ (v)
               (fib/k (- n 2)
                      (λ (w)
                        (k (+ v w))))))))
```

每次递归调用都在 `k` 上多裹一层 lambda。这条 lambda 链就是调用栈，以闭包的形式建在堆上。每个闭包恰好携带一个帧所需的数据。`(λ (v) (fib/k (- n 2) (λ (w) (k (+ v w)))))` 携带两份数据：`(- n 2)`（待执行的第二次子调用）和外层延续 `k`。第二个闭包 `(λ (w) (k (+ v w)))` 携带 `v`（第一个结果）和 `k`。每个闭包就是一个帧：一个标记说明接下来做什么，加上做这件事所需的数据。

循环版本和 CPS 版本是同一个程序。一个把栈表示为带标签的数据列表，另一个把栈表示为闭包链。从闭包到数据标签的变换有个名字：**去函数化**（defunctionalization）。反向变换，从数据标签到闭包，叫做**再函数化**（refunctionalization）。任何一个把递归函数改写为 while 循环加显式栈的程序员，都在手工执行去函数化。

帧列表仍然是延续。`'()` 是空栈，走到它时 `apply-cont` 把 `v` 原样返回。换成闭包版本，就相当于以恒等函数为初始延续，也就是第三篇的初始局部延续 `a->⊥ᵃ`。整条帧列表是一条局部延续 $¬ₐ\text{Natural}$，答案类型 $a$ 就是 `Natural`。`apply-cont` 把延续应用于值，仍是第一篇中的矛盾律，只是得到的不再是 $⊥$，而是局部答案。表示变了，从闭包变成了数据；类型和定律没有变。

但帧列表有一个闭包没有的性质：它是可以检查、拆开和重组的数据。由闭包构成的延续是一个黑盒：只能调用，看不见里面。由数据构成的延续是透明的：可以对它做模式匹配，根据看到的内容决定如何处理，还可以重组它。

## 前沿

还有另一种方式来读 `fib/k`。它遍历一棵二叉树（斐波那契的递归树），在一个栈中累积中间结果。这个栈是一条**前沿**（frontier）：在任何时刻，它记录的是树中已访问部分和尚未探索部分之间的边界。CPS 就是树遍历，延续就是前沿。

如果把算术树换成语法树呢？

---

# 遍历语法树

将源代码变换为 ANF 的编译趟（pass）做的事情和 `fib/k` 一样：遍历一棵树（源 AST），累积一个结果（目标代码）。遍历的前沿（延续）记录着编译器打算在每个子表达式的结果计算出来之后如何处理它。

既然前沿就是延续，变换器也可以像 `fib/k` 那样写成 CPS：`fib/k` 传递 `k` 穿过递归树，变换器传递一个延续 `ctx` 穿过语法树。

ANF 需要给中间结果命名。如果函数调用的参数本身也是函数调用，内层结果必须先用 `let` 绑定到一个新名字，然后才能作为参数传递。所以我们需要一个新名字的供应源。本文所有示例都假设源代码已经过一趟 uniquify pass，重命名了绑定器使得没有重名。对于目标代码，生产编译器会用 `gensym`；为了可读性，我们定义 `make-genvar`，变换器实例化自己的生成器 `fv`，产出 `v.0`、`v.1`、`v.2` 这样的名字。点号分隔编译器的命名空间和源代码的命名空间。

```racket
(define ((make-genvar name [n 0]))
  (define var (string->symbol (format "~a.~a" name n)))
  (set! n (add1 n))
  var)
```

要处理哪些情况，由目标文法决定。这是用 BNF（Backus-Naur 范式）写的目标文法，ANF 的初始草图：

```BNF
<anf> ::= <val> | (if <val> <anf> <anf>) | (let ([<var> <atom>]) <anf>)

<atom> ::= <val> | (<var> <val> ...)
<val>  ::= <var> | <literal> | <proc>

<proc> ::= (λ <head> <anf>)

<head>  ::= <var> | (<var> ...) | (<var> ... . <var>)
```

在 ANF 中，函数调用的参数必须是一个*值*（变量、字面量或 lambda），不能是复合表达式。如果参数本身是函数调用，就必须先用 `let` 绑定到一个变量。这正是使求值顺序显式化的方式：`let` 链条*就是*求值轨迹。文法的各种情况告诉我们变换器需要哪些分支。

```racket
(define (anf exp)
  (define fv (make-genvar 'v))
  (define (id v) v)
  (define (anf1 exp ctx)
    (match exp
      [(? (not/c pair?) x) (ctx x)]
      [`(λ ,x* ,body)
       (ctx `(λ ,x* ,(anf1 body id)))]
      [`(if ,test ,conseq ,alt)
       (anf1 test
             (λ (t) (anf1 conseq
                          (λ (c) (anf1 alt
                                 (λ (a) (ctx `(if ,t ,c ,a))))))))]
      [`(let ([,x ,e]) ,body)
       (anf1 `((λ (,x) ,body) ,e) ctx)]
      [`((λ (,x) ,body) ,rand)
       (anf1 rand (λ (d) (anf1 body (λ (b) (ctx `(let ([,x ,d]) ,b))))))]
      [`(,rator ,rand)
       (anf1 rator (λ (r) (anf1 rand (λ (d) (ctx `(,r ,d))))))]))
  (anf1 exp id))
```

每个分支递归进入子表达式，在 `ctx` 上多裹一层 lambda，表示「一旦你拿到这个子表达式的结果，接下来该做什么」。当一个子表达式被完全处理后，它的结果就传给 `ctx`。Lambda 体用 `id`（恒等函数）编译，因为每个 lambda 体从一个全新的空延续开始：每次函数调用分配一个全新的栈。

以 `(h (f (g a)))` 为例：

```racket
> (anf '(h (f (g a))))
'(h (f (g a)))
```

什么都没发生。输出和输入一模一样。

我们遍历了整棵树，但几乎什么都没做。为什么？我们定义了 `fv` 来生成新名字，但 `fv` 从未被调用过。没有中间结果被命名。没有 `let` 被发射。

把问题追溯到 application 分支 `(,rator ,rand)`。它产出 `(,r ,d)`：把 application 原样重建了。子表达式被处理了，但结果从未被绑定到新变量。

在每个分支中，`ctx` 恰好被调用一次，在尾位置。它从不出现在发射的代码内部。正如 `fib/k` 可以在 CPS 变换之前写成普通递归函数 `fib`，`anf1` 也可以写回一个没有延续参数的普通递归函数。去掉 `ctx`：

```racket
(define (anf0 exp)
  (match exp
    [(? (not/c pair?) x) x]
    [`(λ ,x* ,body)
     `(λ ,x* ,(anf0 body))]
    [`(if ,test ,conseq ,alt)
     `(if ,(anf0 test) ,(anf0 conseq) ,(anf0 alt))]
    [`(let ([,x ,e]) ,body)
     (anf0 `((λ (,x) ,body) ,e))]
    [`((λ (,x) ,body) ,rand)
     `(let ([,x ,(anf0 rand)]) ,(anf0 body))]
    [`(,rator ,rand)
     `(,(anf0 rator) ,(anf0 rand))]))
```

`anf0` 几乎是恒等函数。它递归穿过树，原样重建，唯一的区别是裸 lambda application `((λ (x) body) rand)` 被规范化为 `let` 形式 `(let ([x rand]) body)`。

当 `ctx` 被擦除后，程序自己的延续（宿主的调用栈，即元延续）在做遍历。前沿仍然在那里，但它隐含在宿主中，而不是显式地写在代码里。

## 打印前沿

修复在 application 分支。用 `fv` 给中间结果命名，发射一个 `let`，把 `ctx` 放在 `let` 体内部：

```racket
[`(,rator ,rand)
 (define vn (fv))
 (anf1 rator
       (λ (r)
         (anf1 rand
               (λ (d)
                 `(let ([,vn (,r ,d)])
                    ,(ctx vn))))))]
```

看 `(ctx vn)` 的位置。第一版里，`ctx` 总在分支的末尾被调用，它的结果就是整个分支的结果；现在它被放进了反引号里，调用的结果成了生成的 `let` 的体。以 `(h (f (g a)))` 为例，编译器处理最内层的 `(g a)` 时，手上的 `ctx` 记着两件还没做的事：把结果交给 `f`，再把 `f` 的结果交给 `h`。调用 `(ctx vn)`，这两件事被写成了 `(g a)` 之后的两层 `let`。程序运行时，`(g a)` 求值完毕后要做的，也正是这两件事。

编译器在这一点的剩余工作，打印出来，就是目标程序在同一点的剩余工作。一边是编译时等着被调用的闭包，一边是它留在纸上的代码，镜子两侧映着同一份剩余工作。

输入 `vn` 是一个 `<var>`，更一般地说 `ctx` 始终接收一个 `<val>`（变量、字面量或 lambda），因为这些正是 ANF 代码传给延续的值；它交出的是一段 `<anf>`。所以 `ctx : <val> → <anf>`。按第三篇的记法，这是一条局部延续 $¬ₐ⟨\text{val}⟩$，答案类型 $a$ 是 `<anf>`：编译器这段局部计算的答案，就是生成的代码。`id` 是这里的初始局部延续 `a->⊥ᵃ`。

对比 `fib/k` 的 `k`，它是 $¬ₐ\text{Natural}$。一个在运行时接收一个数字并计算下一步，另一个在编译时接收一段代码片段并构建目标程序的下一块。

理解了 `ctx` 的类型之后，其余每个分支的正确实现就被决定了：

```racket
(define (anf exp)
  (define fv (make-genvar 'v))
  (define (id v) v)
  (define (anf1 exp ctx)
    (match exp
      [(? (not/c pair?) x) (ctx x)]
      [`(λ ,x* ,body)
       (ctx `(λ ,x* ,(anf1 body id)))]
      [`(if ,test ,conseq ,alt)
       (anf1 test
             (λ (t) `(if ,t ,(anf1 conseq ctx) ,(anf1 alt ctx))))]
      [`(let ([,x ,e]) ,body)
       (anf1 `((λ (,x) ,body) ,e) ctx)]
      [`((λ (,x) ,body) ,rand)
       (anf1 rand (λ (d) `(let ([,x ,d]) ,(anf1 body ctx))))]
      [`(,rator ,rand)
       (define vn (fv))
       (anf1 rator
             (λ (r)
               (anf1 rand
                     (λ (d)
                       `(let ([,vn (,r ,d)])
                          ,(ctx vn))))))]))
  (anf1 exp id))
```

字面量、变量和 lambda 本身已经是 `<val>`，所以直接传给 `ctx`。Lambda 体用 `id` 编译：每次函数调用分配一个全新的栈。`if` 的测试条件必须是 `<val>`，所以先编译它，然后发射 `if`，两个分支都用 `ctx` 继续。`let`/lambda-application 分支做脱糖并发射 `let`，体部用 `ctx` 继续。

```racket
> (anf '(h (f (g a))))
'(let ([v.2 (g a)]) (let ([v.1 (f v.2)]) (let ([v.0 (h v.1)]) v.0)))
```

真正的 ANF。每个中间结果都被命名，`let` 链条使求值顺序显式化：先 `(g a)`，再 `(f v.2)`，最后 `(h v.1)`。

这里依赖 uniquify 的假设。如果没有它，源代码中的绑定器可以遮蔽编译器已经发射到待处理上下文中的名字。例如，`(let ([g 1]) (let ([x (let ([g 2]) g)]) g))` 会编译为 `(let ([g 1]) (let ([g 2]) (let ([x g]) g)))`，求值结果是 `2` 而非 `1`：末尾的 `g` 引用的是外层绑定，但它被发射在内层绑定器的作用域下，被捕获了。

---

# 擦除延续参数

修正后的 `anf1` 在每次递归调用中显式传递 `ctx`，每一步都在它上面裹一层 lambda。之前，我们从第一版 `anf1` 中擦除了延续参数，得到了 `anf0`，一个近恒等函数。我们能不能也从*修正后*的版本中擦除延续参数？

第一次擦除之所以能成功，是因为 `ctx` 只被尾调用：每个分支都以 `(ctx ...)` 结尾，意味着 `ctx` 不扮演任何结构角色。修正后的版本不同。在 application 分支中，`ctx` 出现在生成的 `let` *内部*：`(ctx vn)` 被嵌入了目标代码。在 `if` 分支中，`ctx` 被传入两个子编译。延续不再是结果的被动接收者；它在塑造输出。简单地移除参数会丢失信息。

但第三篇的对应表恰好描述了这个变换。表中 CPS 那一行以显式参数传递延续，ANF + reset/shift 那一行用 `shift` 在原来的位置取得它，两行是同一个程序。而 `anf1` 本身就是一个 CPS 程序：它接收一个源表达式和一条局部延续 $¬ₐ⟨\text{val}⟩$，交出 `<anf>`，正是第三篇 $𝒦ₐ$ 世界的箭头形状。这张表应该能作用于编译器自己的源代码。

需要的是表的最后一组，`v` 接收计算结果，`k` 接收剩余工作：

| 风格              | 代码                                                       |
|-------------------|------------------------------------------------------------|
| CPS               | `((λ (v k) body) exp (λ (w) body1))`                       |
| ANF               | `(let ([v exp] [k (λ (w) body1)]) body)`                   |
| ANF + reset/shift | `(reset (let ([w (let ([v exp]) (shift k body))]) body1))` |

## 查表

考虑 `ctx` 以字面 lambda 出现的调用点。为了匹配表中的 CPS 形式，把 `anf1` 包在一个 lambda 里，使两参数结构显式化。结构吻合：一个表达式和一个延续，分别作为参数传递。ANF + reset/shift 一行给出了延续由 `shift` 取得、而非作为参数传递时的写法：

```racket
;; 原始调用点：
(anf1 sub (λ (w) body))

;; 与表中 CPS 形式相同的两参数结构：
;; 表：   ((λ (v   k)   body)           exp (λ (w) body1))
;; anf1:  ((λ (exp ctx) (anf1 exp ctx)) sub (λ (w) body))

;; ANF + reset/shift 一行：用 shift 取得 ctx：
(anf1 sub (λ (w) body))
;; =>
(reset (let ([w (shift ctx (anf1 sub ctx))]) body))
```

`(shift ctx (anf1 sub ctx))` 出现在每一个这样的调用点。给它起个名字，调用点就简化了：

```racket
(define (anf0 exp) (shift ctx (anf1 exp ctx)))

;; 每个 (anf1 sub (λ (w) body)) 变成：
(reset (let ([w (anf0 sub)]) body))
```

另一类调用点直接传递 `ctx`，没有包在 lambda 里。同样的包装技巧可用：`(anf1 sub (λ (w) (ctx w)))`。应用同一组表：

```racket
(anf1 sub ctx)
;; = (anf1 sub (λ (w) (ctx w)))    ; η-展开
;; =>
(reset (let ([w (anf0 sub)]) (ctx w)))
;; = (reset (ctx (anf0 sub)))
```

在 `(reset (ctx (anf0 sub)))` 中，`anf0` 执行 `shift` 时，从 `(anf0 ...)` 到 `reset` 末尾的局部延续恰好就是 `ctx` 本身。所以 `shift` 取得的，正是 `anf1` 原先作为参数接收的东西。

不过第三篇列表时加过限定：`exp`、`body` 指不再含其他控制操作的普通代码。这里的 `body` 会调用 `anf0`，也就含有 `shift`。用第三篇的规约规则核对一下：`(reset (let ([w (shift ctx e)]) body))` 规约后，`ctx` 绑定的是 `(λ (w) (reset body))`，比原来的 `(λ (w) body)` 多了一层 `reset`。而改写之后，`body` 里对 `anf0` 的每次调用都各自包在自己的 `reset` 里，下面的三种模式都是如此。它们的 `shift` 碰不到外面这层，多出来的 `reset` 也就不起作用，表在这里照样适用。

一个特殊情况：当 `ctx` 是 `id` 时，`(reset (id (anf0 sub)))` 化简为 `(reset (anf0 sub))`。从 `anf0` 到边界没有剩余工作，局部延续就是恒等函数。第三篇对应表里恒等的那一组说的正是这件事：`(reset (shift k exp))` 中，`k` 绑定的是 `(λ (v) v)`。取 `exp` 为 `k` 本身，就得到 `id` 的另一种写法：`(define id (reset (shift k k)))`。

## 骨架

`anf1` 中的每个调用点都匹配三种模式之一：

1. `(anf1 sub (λ (w) ...))` 变成 `(reset (let ([w (anf0 sub)]) ...))`
2. `(anf1 sub ctx)` 变成 `(reset (ctx (anf0 sub)))`
3. `(anf1 sub id)` 变成 `(reset (anf0 sub))`

```racket
(define (anf exp)
  (define fv (make-genvar 'v))
  (define (anf0 exp) (shift ctx (anf1 exp ctx)))
  (define (anf1 exp ctx)
    (match exp
      [(? (not/c pair?) x) (ctx x)]
      [`(λ ,x* ,body)
       (ctx `(λ ,x* ,(reset (anf0 body))))]
      [`(if ,test ,conseq ,alt)
       (reset
        (let ([t (anf0 test)])
          `(if ,t ,(reset (ctx (anf0 conseq))) ,(reset (ctx (anf0 alt))))))]
      [`(let ([,x ,e]) ,body)
       (reset (ctx (anf0 `((λ (,x) ,body) ,e))))]
      [`((λ (,x) ,body) ,rand)
       (reset
        (let ([d (anf0 rand)])
          `(let ([,x ,d]) ,(reset (ctx (anf0 body))))))]
      [`(,rator ,rand)
       (define vn (fv))
       (reset
        (let ([r (anf0 rator)])
          (reset
           (let ([d (anf0 rand)])
             `(let ([,vn (,r ,d)])
                ,(ctx vn))))))]))
  (reset (anf0 exp)))
```

## 反转定义

这次改写把 `anf0` 引入为 `anf1` 的包装器，但它同时也确立了反向关系：

```racket
(anf0 exp)     = (shift  ctx (anf1 exp ctx))     ; anf0 由 anf1 定义
(anf1 exp ctx) = (reset (ctx (anf0 exp)))        ; anf1 由 anf0 定义

;; 两者可以互换。把 match 逻辑移入 anf0：
(define (anf1 exp ctx) (reset (ctx (anf0 exp))))
(define (anf0 exp)
  (shift ctx
    (match exp
      ...各分支同前...)))
(anf1 exp id)
```

骨架的顶层调用 `(reset (anf0 exp))` 就是 `(anf1 exp id)`：`anf1` 的定义在 `ctx = id` 时的形式。

## 化简

外层 `shift` 包裹了 `match` 的每个分支。由于 `match` 只是纯粹的分派，`shift` 可以被推入各个分支内部，然后用两条局部等式化简：

1. **`(shift ctx (ctx e))` = `e`**，`ctx` 不在 `e` 中自由出现。第三篇给过两条等式：`(shift k (k e)) = (let/lc k e)`，捕获后立即调用，跳转被撤销，只剩捕获；`e` 不用 `k` 时，`(let/lc k e)` 又退化为 `e`。两步连起来就是这一条。
2. **`(shift ctx (reset e))` = `(shift ctx e)`。** 第三篇的规约规则里，`shift` 的主体规约后仍然在原来的 `reset` 里，规约式最外面保留了 `reset`。主体本来就处在一层边界之内，再加一层 `reset` 不改变任何事。

在原子和 lambda 分支中，`shift` 化简消失了：

```racket
[(? (not/c pair?) x) (shift ctx (ctx x))]                   ; 等式 1 => x
[`(λ ,x* ,body) (shift ctx (ctx `(λ ,x* ,(anf1 body id))))] ; 等式 1 => `(λ ,x* ,(anf1 body id))
```

两个都完全化简掉了。原子和 lambda 本身已经是值；捕获延续只是为了把它们交出去，纯属多余。在第一版 `anf1` 中，`ctx` 只被尾调用，*每个*分支都是这种形式：`(shift ctx (ctx ...))`。每个 `shift` 都化简消失了，`anf0` 退化为一个对延续无所作为的近恒等函数。修正后的版本不同：复合分支在生成的代码内部使用了 `ctx`，所以它们的 `shift` 存活了下来。

`if` 和 lambda-application 分支保留了它们的 `shift`：

```racket
[`(if ,test ,conseq ,alt)
 (shift ctx        ; 保留：ctx 在发射的代码内部使用
   (reset          ; 等式 2 => 移除
    (let ([t (anf0 test)])
      `(if ,t ,(anf1 conseq ctx) ,(anf1 alt ctx)))))]

[`((λ (,x) ,body) ,rand)
 (shift ctx        ; 保留：ctx 在体的编译中使用
   (reset          ; 等式 2 => 移除
    (let ([d (anf0 rand)])
      `(let ([,x ,d]) ,(anf1 body ctx)))))]
```

每个分支内最外层的 `reset` 被等式 2 吸收。

`let` 分支需要两条等式依次应用：

```racket
;; 之前：
[`(let ([,x ,e]) ,body)
 (shift ctx
   (reset          ; 等式 2 => 移除
    (ctx           ; 等式 1 => 移除
     (anf0 `((λ (,x) ,body) ,e)))))]

;; 等式 2 去掉 reset，等式 1 去掉 (shift ctx (ctx ...))：
[`(let ([,x ,e]) ,body)
 (anf0 `((λ (,x) ,body) ,e))]
```

这是把 `anf0` 的定义反着读：对脱糖形式调用 `anf0`，等价于对它调用 `anf1` 并传入当前的 `ctx`，因为 `(shift ctx (anf1 e ctx))` 就是 `(anf0 e)`。

application 分支有两个 `reset`：

```racket
;; 之前：
[`(,rator ,rand)
 (shift ctx
   (define vn (fv))
   (reset          ; 等式 2 => 移除
    (let ([r (anf0 rator)])
      (reset       ; 这个能去掉吗？
       (let ([d (anf0 rand)])
         `(let ([,vn (,r ,d)])
            ,(ctx vn)))))))]

;; 之后：
[`(,rator ,rand)
 (shift ctx
   (define vn (fv))
   (let ([r (anf0 rator)])
     (let ([d (anf0 rand)])
       `(let ([,vn (,r ,d)])
          ,(ctx vn)))))]
```

外层 `reset` 被等式 2 吸收，和其他分支一样。内层 `reset` 在语法上不直接与上方的定界符相邻，所以等式 2 不能直接使用。但考虑动态行为。`(anf0 rator)` 运行，它执行的每个 `shift` 都会发射 `let` 绑定，包裹剩余部分。一旦 `r` 被绑定，剩余工作是 `(reset (let ([d ...]) ...))`。来自 `anf1` 的上方 `reset` 中的定界符现在直接相邻了。两个相邻的定界符之间没有任何东西：`(reset (reset e))` = `(reset e)`。内层 `reset` 坍缩。

把嵌套的 `let` 改写为内部 `define`，并把 application 推广到任意数量参数（用 `map`），整个变换器变成：

```racket
(require racket/control)

(define (anf exp)
  (define fv (make-genvar 'v))
  (define id (reset (shift k k)))
  (define (anf1 exp ctx) (reset (ctx (anf0 exp))))
  (define anf0
    (match-λ
      [(? (not/c pair?) x) x]
      [`(λ ,x* ,body)
       `(λ ,x* ,(anf1 body id))]
      [`(if ,test ,conseq ,alt)
       (shift ctx
         (define t (anf0 test))
         `(if ,t ,(anf1 conseq ctx) ,(anf1 alt ctx)))]
      [`(let ([,x ,e]) ,body)
       (anf0 `((λ (,x) ,body) ,e))]
      [`((λ (,x) ,body) ,rand)
       (shift ctx
         (define d (anf0 rand))
         `(let ([,x ,d]) ,(anf1 body ctx)))]
      [`(,rator . ,rand*)
       (shift ctx
         (define vn (fv))
         (define r (anf0 rator))
         (define d* (map anf0 rand*))
         `(let ([,vn (,r . ,d*)]) ,(ctx vn)))]))
  (anf1 exp id))
```

三个例子，分别覆盖多参数调用、lambda 和 `if`：

```racket
> (anf '(f (g a) (h b)))
'(let ([v.1 (g a)]) (let ([v.2 (h b)]) (let ([v.0 (f v.1 v.2)]) v.0)))
> (anf '(λ (x) (f (g x))))
'(λ (x) (let ([v.1 (g x)]) (let ([v.0 (f v.1)]) v.0)))
> (anf '(if (f x) (g a) (h b)))
'(let ([v.0 (f x)]) (if v.0 (let ([v.1 (g a)]) v.1) (let ([v.2 (h b)]) v.2)))
```

与 CPS 版本的 `anf1` 完全相同的逻辑、相同的分支、相同的输出。但没有 `ctx` 参数，没有层层嵌套的 lambda 来传递它。`shift` 恰好在需要的地方捕获延续，其余的由宿主自己的栈处理。

## 文法类型

`anf0` 的返回类型是什么？有些分支直接返回一个值，另一些调用 `shift`，永远不返回给调用者。答案在 `anf1` 的定义中：`(reset (ctx (anf0 exp)))`。`anf0` 的返回值被传给 `ctx`，所以 `anf0` 的返回类型就是 `ctx` 的参数类型：`<val>`。简单情况证实了这一点：字面量、变量、lambda，都是 `<val>`。复合情况下，`shift` 的主体越过 `ctx`，把一段 `<anf>` 直接交到 `reset` 边界。这是这段局部计算的答案 $⊥ᵃ$，成为 `anf1` 的返回值。

---

# 命名延续

`shift` 正是 `ctx` 被拼接进生成代码的地方。在 `if` 分支中，`ctx` 出现在*两个*子编译中：

```racket
[`(if ,test ,conseq ,alt)
 (shift ctx
   (define t (anf0 test))
   `(if ,t ,(anf1 conseq ctx) ,(anf1 alt ctx)))]
```

整个剩余上下文被复制进了每个分支。试着把一个 `if` 放进一个更大的表达式：

```racket
> (anf '(f (if a b c)))
'(if a (let ([v.0 (f b)]) v.0) (let ([v.0 (f c)]) v.0))
```

对 `f` 的调用出现在两个分支中。如果 `if` 嵌套，每一层都把代码翻倍。指数膨胀。

但 `if` 的两个分支都在尾位置：两个分支都不扩展延续。`if` 表达式的延续*就是*每个分支的延续。如果我们把 `ctx` 打印为一个 lambda，绑定到一个命名变量，让两个分支都应用那个名字，重复就消失了。

每个 `if` 需要自己的延续名字，嵌套的 `if` 不能冲突。所以我们在 `fv` 之外引入第二个生成器，产出 `k.0`、`k.1`、`k.2` 这样的名字：

```racket
(define fk (make-genvar 'k))

[`(if ,test ,conseq ,alt)
 (shift ctx
   (define vn (fv))
   (define kn (fk))
   (define t (anf0 test))
   `(let ([,kn (λ (,vn) ,(ctx vn))])
      (if ,t
          ,(anf1 conseq (λ (v) `(,kn ,v)))
          ,(anf1 alt    (λ (v) `(,kn ,v))))))]
```

`ctx` 被打印为 lambda 一次，绑定到 `kn`。两个分支接收的上下文都是对 `kn` 的调用。无论 `if` 嵌套得多深，上下文都被共享而非复制，每一层都有自己的名字。

两个分支用了相同的上下文 `` (λ (v) `(,kn ,v)) ``。我们可以用定义 `id` 的方式给它起个名字：正如 `(λ (v) v)` 就是 `(reset (shift k k))`，上下文 `` (λ (v) `(,kn ,v)) `` 就是 `` (reset `(,kn ,(shift k k))) ``。用了这个命名后，`if` 分支变成：

```racket
[`(if ,test ,conseq ,alt)
 (shift ctx
   (define vn (fv))
   (define kn (fk))
   (define t (anf0 test))
   (define ctx0 (reset `(,kn ,(shift k k))))
   `(let ([,kn (λ (,vn) ,(ctx vn))])
      (if ,t ,(anf1 conseq ctx0) ,(anf1 alt ctx0))))]
```

用之前让代码膨胀的那个例子测试：

```racket
> (anf '(f (if a b c)))
'(let ([k.0 (λ (v.1) (let ([v.0 (f v.1)]) v.0))])
   (if a (k.0 b) (k.0 c)))
```

对 `f` 的调用只出现一次，在绑定到 `k.0` 的 lambda 内部。两个分支都调用 `k.0`，而不是复制上下文。嵌套 `if` 不再导致指数膨胀。

文法演化了。`<if>` 产生式获得了一个新选项，`<atom>` 获得了一个延续调用：

```BNF
<anf> ::= <val> | <if> | (let ([<var> <atom>]) <anf>)

<atom> ::= <val> | (<var> <val> ...) | (<k> <val> ...)
<val>  ::= <var> | <literal> | <proc>

<if>     ::= <anf-if> | (let ([<k> <proc>]) <anf-if>)
<anf-if> ::= (if <val> <anf> <anf>)
<k>      ::= <var>                         ;; 延续变量，由 <if> 绑定

<proc> ::= (λ <head> <anf>)

<head>  ::= <var> | (<var> ...) | (<var> ... . <var>)
```

`<if>` 产生式现在有两种形式：裸的，和包在一个 `let` 中、绑定了一个延续的。`let` 形式就是「命名延续」：把编译时的上下文具体化为运行时的 lambda，然后通过名字引用它。

---

# 镜子破裂

到目前为止，对应表一直用在编译器自己的代码上：`ctx` 由 `shift` 取得，`id` 写成 `(reset (shift k k))`。源程序里也可以出现 `reset` 和 `shift`，同一张表也告诉我们该怎样编译它们。

`reset` 开启一段新的局部计算，对编译器来说，就是从初始局部延续 `id` 开始编译它的主体，再把得到的局部答案命名后交给 `ctx`。`shift` 对源程序做的事，和命名延续时 `if` 分支对编译器做的事一样：把局部延续写成一个 lambda，绑定到一个名字。区别在于 `if` 的情况下编译器自己选了名字（从 `fk` 得到 `kn`），这里则由程序员提供名字（`k`），局部延续在源代码中可见：

```racket
[`(reset ,body)
 (shift ctx
   (define vn (fv))
   `(let ([,vn ,(anf1 body id)])
      ,(ctx vn)))]
[`(shift ,k ,body)
 (shift ctx
    (define vn (fv))
    `(let ([,k (λ (,vn) ,(ctx vn))])
       ,(anf1 body id)))]
```

`shift` 分支里有两个 `shift`。源程序的 `shift` 是被编译的对象；编译器自己的 `shift` 取得此刻的 `ctx`，而 `ctx` 要打印的，正是源程序中从这个 `shift` 到最近 `reset` 的剩余工作。编译器把它打印成 lambda，绑定给 `k`。主体用 `id` 编译：按第三篇的规约规则，`shift` 的主体在边界处运行，局部延续是空的。

有了 `reset`，`let` 绑定的东西变了。此前每个 `let` 绑定的都是一个 `<atom>`：一个值，或者一次调用。`reset` 分支发射的 `let`，绑定位置上是 `(anf1 body id)`，主体编译出来的一整段 `<anf>`。文法必须演化来容纳这一点：

```BNF
<anf> ::= <val> | <if> | (let ([<var> <anf>]) <anf>) | <apply-proc>

<val> ::= <var> | <literal> | <proc>

<if>     ::= <anf-if> | (let ([<k> <proc>]) <anf-if>)
<anf-if> ::= (if <val> <anf> <anf>)

<apply-proc> ::= (<val> <val> ...)

<proc> ::= (λ <head> <anf>)

<head> ::= <var> | (<var> ...) | (<var> ... . <var>)
```

`<atom>` 消失了。有了定界之后，代码不再是单栈线性序列。`let` 绑定现在可以绑定一个 `<anf>`，一个拥有自己栈的定界计算。

函数调用改叫 `<apply-proc>`，直接列进了 `<anf>`；它的参数仍然是 `<val>`。

先试两个简单的例子：

```racket
> (anf '(reset (+ 1 (shift k (k 42)))))
'(let ([v.0 (let ([k (λ (v.2) (let ([v.1 (+ 1 v.2)]) v.1))]) (let ([v.3 (k 42)]) v.3))])
   v.0)
> (anf '(+ 10 (reset (+ 1 (shift k 42)))))
'(let ([v.1 (let ([k (λ (v.3) (let ([v.2 (+ 1 v.3)]) v.2))]) 42)])
   (let ([v.0 (+ 10 v.1)]) v.0))
```

第二个输出里，外层 `let` 把 `v.1` 绑定到一整条 `let` 链 `(let ([k ...]) 42)`，加十排在它后面，用的是 `v.1`。这就是 `(let ([<var> <anf>]) <anf>)` 产生式的实例。

定界之前，`let` 绑定总是一个 `<atom>`，一次单独的操作。现在一个绑定可以是整个 `<anf>`，一个拥有自己栈的定界计算：

```racket
;; 定界之前：扁平的。每个 let 扩展同一个栈
(let ([v.2 (g a)]) (let ([v.1 (f v.2)]) (let ([v.0 (h v.1)]) v.0)))

;; 定界之后：嵌套的。内层 let 链运行、产出一个值、
;; 返回外层栈
(let ([v.1 (let ([k ...]) 42)])
  (let ([v.0 (+ 10 v.1)]) v.0))
```

简单情况没问题。再拿第三篇的阴阳谜题来试。第三篇把第一篇的 `(label)` 写成了 `(let/lc k k)`：谜题中的延续都只在 `reset` 的尾位置调用，局部延续就够用。

```racket
(reset
 (let ([kn (let/lc k0 k0)])
   (display #\@)
   (let ([k (let/lc kn+1 kn+1)])
     (display #\*)
     (kn k))))
```

编译器还不认识 `let/lc`。第三篇说过，`shift` 做两件事，捕获与跳转，也可以只留下一样。主体把结果交回给捕获的延续，跳转就被撤销了，剩下的只是捕获：`(shift k (k e)) = (let/lc k e)`。第三篇正是这样把 `let/lc` 定义成 `shift` 的宏，编译器也只需把它展开，交给已有的 `shift` 分支。`let*` 则展开成嵌套的单绑定 `let`：

```racket
[`(let/lc ,k ,body)
 (anf0 `(shift ,k (,k ,body)))]
[`(let* () ,body)
 (anf0 body)]
[`(let* ([,x ,e] . ,bind*) ,body)
 (anf0 `(let ([,x ,e]) (let* ,bind* ,body)))]
```

先去掉 `display`，只看控制结构：

```racket
> (anf '(reset
         (let* ([kn (let/lc k0 k0)]
                [k  (let/lc kn+1 kn+1)])
           (kn k))))
'(let ([v.0
        (let ([k0
               (λ (v.1)
                 (let ([kn v.1])
                   (let ([kn+1 (λ (v.2) (let ([k v.2]) (let ([v.3 (kn k)]) v.3)))])
                     (let ([v.4 (kn+1 kn+1)]) v.4))))])
          (let ([v.5 (k0 k0)]) v.5))])
   v.0)
```

编译后的代码只包含别名绑定（`kn = v.1`，`k = v.2`）和两个真正的 lambda：两个被捕获的延续。两条清理规则就能恢复第一篇的互递归。传播别名：把每个 `v.N` 替换为它被绑定的来源名字。消除尾绑定：`(let ([v expr]) v)` 就是 `expr`。结果是：

```racket
(let ([k0 (λ (kn)
            (let ([kn+1 (λ (k) (kn k))])
              (kn+1 kn+1)))])
  (k0 k0))
```

插入打印 `@` 和 `*` 的 `display` 调用，改写为 `define` 形式：

```racket
(define (k0 kn)
  (display #\@)
  (define (kn+1 k)
    (display #\*)
    (kn k))
  (kn+1 kn+1))
```

```racket
> (k0 k0)
@*@**@***@****@...
```

第一篇的互递归，逐行对应。那里我们读着追踪输出写出了它；这里编译器从源代码推导出了它。

不过第三篇的写法和第一篇并不完全相同。第一篇的 `label` 是一个函数，谜题里的 `(label)` 是对它的调用；第三篇把调用处直接换成了 `(let/lc k k)`。把 `let/lc` 放回函数里，写回第一篇的样子：

```racket
(anf '(reset
       (let* ([label (λ () (let/lc k k))]
              [yin   (label)]
              [_     (display #\@)]
              [yang  (label)]
              [_     (display #\*)])
         (yin yang))))
```

和上一个版本相比，唯一的差别是 `let/lc` 被包进了一个 lambda。程序编译没有报错。运行它：

```
@*
```

两个字符，然后程序就结束了。无穷阶梯在第一步之后就停了。

## 诊断

看 `label` 编译成了什么：

```racket
(λ () (let ([k (λ (v.1) v.1)]) (let ([v.2 (k k)]) v.2)))
```

`k` 被绑定成了恒等函数。它本该是调用 `(label)` 之后的剩余工作：绑定 `yin`，打印 `@`，再调用一次 `label`，一直到 `(yin yang)`。可这些工作都在 lambda 外面。编译器处理 `(λ () ...)` 时，用 `(anf1 body id)` 编译主体，走到 `shift` 分支时手上的 `ctx` 是 `id`，能打印的只有恒等函数。于是 `(label)` 返回恒等函数，`yin` 和 `yang` 都是它，`(yin yang)` 调用一次就结束了。

内联的版本里，`reset` 和 `shift` 之间的剩余工作都写在同一个表达式里。编译器从外往里走，走到 `shift` 时，手上的 `ctx` 就是完整的剩余工作。函数不同：lambda 的主体在定义处编译，调用处的剩余工作写在别的地方，编译主体时根本不在 `ctx` 里。

主体用 `id` 编译，是因为每次函数调用都从空栈开始；`reset` 分支也用 `id`，因为 `reset` 开启一段新的局部计算。第三篇说过：「在函数里调用另一个函数，被调用者从自己的空栈开始执行。`anf:reset` 做的是同一件事。」编译器把这个等同忠实地带进了代码，函数调用和 `reset` 一样，都在定界。

两个特性分开时都能工作。没有 `reset`/`shift`，函数调用定界不会被察觉：每个 lambda 主体从 `id` 开始，没有 `shift` 需要看到调用处。没有函数，`reset`/`shift` 也能正确编译，内联的谜题就是证据。两者同时出现时，lambda 主体里的 `shift` 要取得的局部延续，应当越过函数调用，一直延伸到 `reset`。函数调用和 `reset` 在这里被要求表现不同：`reset` 仍然定界，函数调用却不能再定界。

文法也说明了这一点。`<proc>` 产生式是 `(λ <head> <anf>)`：lambda 的主体是一段完整的 `<anf>`，文法中没有任何东西让调用处的剩余工作进入主体。

再用一个更小的例子确认。一个函数，主体包含 `shift`，在 `reset` 内部、一个还有剩余工作的调用处被调用：

```racket
> (anf '(reset (let ([f (λ (x) (shift k 999))]) (add1 (f 42)))))
'(let ([v.0
        (let ([f (λ (x) (let ([k (λ (v.1) v.1)]) 999))])
          (let ([v.3 (f 42)]) (let ([v.2 (add1 v.3)]) v.2)))])
   v.0)
```

我们期望 `999`：`f` 执行 `shift`，丢弃捕获的延续，直接把 `999` 交给 `reset` 边界。追踪编译后的代码，`k` 又被绑定成了恒等函数，lambda 主体自己的初始局部延续，而不是调用处的剩余工作。`f` 返回 `999` 之后，外层代码绑定 `v.3 = 999` 并计算 `(add1 v.3) = 1000`。期望：`999`。实际：`1000`。

---

# 调用者的延续

## 修复

那个出错的例子告诉了我们缺少什么：lambda 体需要知道调用者的延续。

`if` 分支解决了一个类似的问题。`if` 的两个分支共享与整个 `if` 表达式相同的延续。编译器在进入分支之前命名了那个延续，两个分支通过名字访问它。

Lambda 的情况类似。如果调用者的延续在调用点被命名了，函数体就可以通过同一个名字访问它。区别在于时机：对 `if` 来说，延续在编译时就可用，所以一个 `let` 绑定就够了。对 lambda 体来说，延续要等到函数被调用时才会到达。所以我们不用 `let`，而用一个**参数**：lambda 把调用者的延续作为额外参数，调用点提供它。

Lambda 分支加上 `(λ (k) ...)`：

```racket
;; 之前：
[`(λ ,x* ,body)
 `(λ ,x* ,(anf1 body id))]

;; 之后：
[`(λ ,x* ,body)
 (define kn (fk))
 (define ctx0 (reset `(,kn ,(shift k k))))
 `(λ ,x* (λ (,kn) ,(anf1 body ctx0)))]
```

现在每个用户定义的 lambda 都产出形如 `(λ (x ...) (λ (k.0) body))` 的代码：它接受参数，然后接受一个延续，然后运行主体。主体从 `ctx0` 开始编译，后者在末尾发射 `(k.0 v)`，结果在尾位置交给 `k.0`。而 `k.0` 是调用处提供的剩余工作，一直积累到最近的 `reset`。修正之前，主体从 `id` 开始，函数调用自己就是一条边界；修正之后，主体接着调用者的局部延续往下做，函数调用不再定界。

这正是第三篇说过的做法：CPS 把栈上的帧搬到堆上的闭包里，宿主栈不再为局部工作保留帧，于是可以承担定界。`k.0` 就是这样的闭包。不同的是，这里只搬用户定义的函数，宿主栈留给了 `reset`。诊断中被等同起来的两种边界，由此分开了。

调用点必须提供它。但不是每个函数都需要延续参数。`+` 和 `add1` 这样的内建函数直接计算并返回。只有用户定义的函数接受额外参数。我们把不需要的称为**平凡的**（trivial），初始集合包含内建原语：

```racket
(define trivial* (mutable-seteq))
(define (trivial? x) (set-member? trivial* x))
(define (add-trivial! x) (set-add! trivial* x))
(for-each add-trivial!
 '(identity values
   display displayln
   zero? add1 sub1
   + - * /
   = < <= > >=
   eq? eqv? equal?))
```

除了内建函数之外，`shift` 捕获的延续也是平凡的。第三篇已经看到，局部延续是普通函数：调用它就执行剩余的局部工作，正常返回结果，用不着另一个延续。由于源程序经过了 α-重命名，`k` 是全局唯一的；`fk` 生成的每个 `k.n` 也是如此。所以每个 `shift` 的绑定器和每个延续名字在创建时就加入平凡集合：

```racket
[`(shift ,k ,body)
 (add-trivial! k)
 ...]

(define ((make-genvar name [n 0]))
  (define var (string->symbol (format "~a.~a" name n)))
  (when (eq? name 'k) (add-trivial! var))
  (set! n (add1 n))
  var)
```

平凡集合现在包含内建函数、`shift` 捕获的延续和编译器生成的延续名字。它们都直接接收值，不期望延续参数。

调用点相应地分裂。平凡调用不需要延续参数；用户定义的调用必须传递一个：

```racket
[`(,(? trivial? r) . ,rand*)
 (shift ctx
   (define vn (fv))
   (define d* (map anf0 rand*))
   `(let ([,vn (,r . ,d*)]) ,(ctx vn)))]

[`(,rator . ,rand*)
 (shift ctx
   (define vn (fv))
   (define r (anf0 rator))
   (define d* (map anf0 rand*))
   `((,r . ,d*) (λ (,vn) ,(ctx vn))))]
```

平凡调用发射 `(let ([,vn (,r . ,d*)]) ,(ctx vn))`，和之前相同的 ANF `let` 绑定。用户定义的调用发射 `((,r . ,d*) (λ (,vn) ,(ctx vn)))`，传递一个显式的延续参数。

再编译那个出错的例子：

```racket
> (anf '(reset (let ([f (λ (x) (shift k 999))]) (add1 (f 42)))))
'(let ([v.0
        (let ([f (λ (x) (λ (k.0) (let ([k (λ (v.1) (k.0 v.1))]) 999)))])
          ((f 42) (λ (v.3) (let ([v.2 (add1 v.3)]) v.2))))])
   v.0)
```

现在 `f` 接受一个延续参数 `k.0`。在调用点，`((f 42) (λ (v.3) ...))` 传递了局部延续，其中包含 `add1`。运行时，`shift` 捕获调用点的延续（包裹着 `add1`），体返回 `999` 给 `reset` 边界，结果如期是 `999`。

## 混合体

输出里有两种函数调用：`(let ([v.2 (add1 v.3)]) ...)` 是对 `add1` 的平凡调用，`((f 42) (λ (v.3) ...))` 是对用户定义的 `f` 的调用。输出是一个混合体：一部分是 ANF，一部分是 CPS。这个混合体是什么意思？

输出是正确的，但噪声很多。到处都是包装器：`(λ (v.1) (k.0 v.1))` 包裹着 `k.0`，`(λ (v.3) (let ([v.2 (add1 v.3)]) v.2))` 包裹着 `add1`。要读懂混合体，先要剥去噪声。

考虑：

```racket
> (anf '(λ (n) (f (g n))))
'(λ (n) (λ (k.0) ((g n) (λ (v.1) ((f v.1) (λ (v.0) (k.0 v.0)))))))
```

尾调用是 `((f v.1) (λ (v.0) (k.0 v.0)))`。延续 `(λ (v.0) (k.0 v.0))` 接受一个值，立即传给 `k.0`。我们之前见过这种包装：为了匹配对应表，我们把 `(anf1 sub ctx)` 包装成 `(anf1 sub (λ (w) (ctx w)))`。那个包装器当时是多余的，现在也是多余的。

把 `(λ (x) (f x))` 替换为 `f`，当 `x` 不出现在 `f` 中。这个化简叫做 **η-归约**（eta-reduction）：

```racket
((f v.1) (λ (v.0) (k.0 v.0)))
;; η => ((f v.1) k.0)
```

尾调用直接传递 `k.0`。不需要包装器。

非尾调用点的延续呢？在上面 999 的例子中，`f` 的调用点延续是 `(λ (v.3) (let ([v.2 (add1 v.3)]) v.2))`。对 `let` 做脱糖：

```racket
(λ (v.3) ((λ (v.2) v.2) (add1 v.3)))
```

内层 `((λ (v.2) v.2) (add1 v.3))` 把恒等函数应用到 `(add1 v.3)`。把已知 lambda 应用到其参数上，在 `((λ (x) body) arg)` 中执行 `body[x := arg]`，这是 **β-归约**（beta-reduction）：

```racket
((λ (v.2) v.2) (add1 v.3))
;; β => (add1 v.3)
```

延续化简为 `(λ (v.3) (add1 v.3))`，它本身又是一个 η-可归约式：归约为 `add1`。`f` 的调用点延续不是一个包裹 `add1` 的 lambda。它*就是* `add1`。

在尾调用处，包装器 `(λ (v.0) (k.0 v.0))` 归约为 `k.0`；在非尾调用处，包装器归约为 `add1`。于是在延续参数的位置上，一个是编译器命名的延续，一个是内建函数，都接受一个值，把它送往下一步。归约后仍然存活的 `(λ (v) ...)` 也是如此。

第三篇说过，局部延续是普通函数。这里看到的是反过来的一面：平凡的普通函数，本身就是局部延续。平凡集合原本是「不需要延续参数的函数」，从内建原语开始，陆续加入 `shift` 捕获的延续和 `fk` 生成的名字，看上去像一个杂烩。β 和 η 剥去管理性的包装之后可以看清，它就是延续的集合。混合体的 ANF 那一半也从来不是没有延续的：

```racket
(let ([v (f x)]) body)  =  ((λ (v) body) (f x))
```

每个 `let` 都是把一个延续 `(λ (v) body)` 应用到 `(f x)` 的结果上。编译器没有引入延续；它发现了原本就在那里的延续。

## 两种函数

现在两种函数有了名字。一种接受延续参数：这些是**用户定义的函数**，其主体可能包含 `shift`。另一种*本身就是*延续：它接受一个值并传递出去。平凡调用 `(let ([v (add1 x)]) (ctx v))` 就是 `(ctx (add1 x))`，也就是第三篇 `cps` 的展开 `(((cps add1) x) ctx)`：编译器在调用处就地把平凡函数提升进 CPS 世界。输出中的每次调用，要么是调用一个函数并交给它一个延续，要么是把一个延续应用到一个值上。这就是 **CPS**。

文法达到了最终形式：

```BNF
<cps> ::= <val> | <if> | <apply>

<val>   ::= <var> | <literal> | <proc>
<if>    ::= (if <val> <cps> <cps>)
<apply> ::= <apply-proc> | <apply-cont> | <apply-cont²>

<apply-proc>  ::= ((<val> <val> ...) <cont>)
<apply-cont>  ::= (<cont> <cps>) | (<cont> <val> ...)
<apply-cont²> ::= (<cont²> <cont>)

<proc>  ::= (λ <head> <cont²>)
<cont>  ::= (λ <head> <cps>) | <trivial>
<cont²> ::= (λ (<trivial>) <cps>)

<head>  ::= <var> | (<var> ...) | (<var> ... . <var>)
```

从扁平的 ANF 到这里，文法变了三次：`if` 的复制引入了命名延续，`reset` 让 `let` 可以绑定一整段 `<anf>`，`shift` 需要穿过函数边界，又让 lambda 接受了延续参数。

读 `<cont>` 产生式：`(λ <head> <cps>) | <trivial>`。延续要么是编译器构造的 lambda，要么是平凡集合中的一个名字。平凡集合从内建原语开始；它增长到包含每个延续变量。文法不区分它们，因为 η-归约已经表明它们是同一种东西。

`<apply-cont>` 有两种写法。`(<cont> <cps>)` 把一段计算的结果交给延续，对应此前文法里的 `(let ([<var> <anf>]) <anf>)`：`((λ (v) body) e)` 就是 `(let ([v e]) body)`。另一种 `(<cont> <val> ...)` 是参数都已经是值的调用。

`<cont²>` 产生式 `(λ (<trivial>) <cps>)` 是一个**二阶延续**：它以调用者的延续为参数，使它成为延续的延续。它的类型是 $(p → a) → a = ¬ₐ¬ₐp$，第三篇的局部编码。`<proc>` 的形状是 `(λ <head> <cont²>)`，接受参数后交出一个 $¬ₐ¬ₐ$，正是 `anf1` 那样的 $𝒦ₐ$ 箭头：编译器自己的写法，现在也成了目标程序的写法。而 `<apply-cont²>` 不过是一个 `let`，只是绑定的值碰巧是一个延续：`((λ (<trivial>) <cps>) <cont>)` = `(let ([<trivial> <cont>]) <cps>)`。绑定本身没有什么特别的；特别的是参数。

---

# 教编译器做规范化

β 和 η 归约是我们手工做的。没有它们输出也是正确的，但臃肿。Lambda 链的尾调用包装器 `(λ (v.0) (k.0 v.0))` 消失了；999 的例子更为显著，lambda 从 8 个降到 4 个（`let` 都已脱糖）：

```racket
;; Lambda 链：之前
(λ (n) (λ (k.0) ((g n) (λ (v.1) ((f v.1) (λ (v.0) (k.0 v.0)))))))
;; 之后：
(λ (n) (λ (k.0) ((g n) (λ (v.1) ((f v.1) k.0)))))

;; 999 的例子：之前
((λ (v.0) v.0)
 ((λ (f) ((f 42) (λ (v.3) ((λ (v.2) v.2) (add1 v.3)))))
  (λ (x) (λ (k.0) ((λ (k) 999) (λ (v.1) (k.0 v.1)))))))
;; 之后：
((λ (f) ((f 42) add1)) (λ (x) (λ (k.0) ((λ (k) 999) k.0))))
```

编译器在每个构造 lambda 的地方生成这些包装器。`(λ (,vn) ,(ctx vn))` 是典型的情况。编译器每次准备发射一个 lambda 时，先检查 β 或 η 能否把它化简掉：

```racket
(match `(λ (,vn) ,(ctx vn))
  [`(λ (,vn) ,b)       #:when (β? b vn) ...]   ; 体归约为 vn：直接发射 b
  [`(λ (,vn) (,k ,vn)) #:when (η? k vn) ...]   ; 对 k 的包装器：坍缩为 k
  [k                                    ...])  ; 真正的工作：保留 lambda
```

三个分支对应三种结果：lambda 从来不需要（β 化简掉了），lambda 是一层平凡的包装（η 坍缩为内部的函数），或者 lambda 做了真正的工作，存活下来。

两个谓词：

```racket
(define (β? b v)
  (match b
    [`((λ (,u) ,u) ,e) (eq? e v)]
    [`((λ (,u) ,b) ,e)
     (and (eq? b v)
          (if (eq? u v)
              (eq? e v)
              (not (pair? e))))]
    [_ (eq? b v)]))

(define (η? k v)
  (match k
    [`(λ (,u) ,b)
     (or (eq? u v)
         (not (if (pair? b)
                  (memq v (flatten b))
                  (eq? b v))))]
    [(? trivial?) (not (eq? k v))]
    [_ #f]))
```

`β?` 问的是函数体 `b` 是否归约为 `v`；`η?` 问的是 `v` 是否在 `k` 中自由出现。每个谓词中的守卫标出了归约不再可靠的边界。举一个例子：`β?` 中间子句的 `(not (pair? e))` 检查阻止丢弃一个复合表达式 `e`，而那个表达式是目标程序本应执行的计算。没有这个守卫，纸面上看起来正确的归约会悄悄擦除一段运行时计算。

其余守卫遵循同样的纪律：每一个都保护着一种朴素归约会改变产出代码行为的情况。

三路 match 还做了一件事。编译器的 `ctx` 是一个闭包：不透明，只能调用，无法检查内部。`(λ (,vn) ,(ctx vn))` 却是数据，就像「认出延续」一节的帧列表：编译器把自己的延续打印为代码，然后对打印的结果做模式匹配来决定它的命运。

β-归约和 η-归约是 λ-演算三大基本等价中的两个。第三个是 **α-转换**（alpha-conversion）：重命名绑定变量以避免捕获。这正是 `uniquify` 在流水线起点做的事。三个等价现在都在编译器中了：

|   | 之前              | 之后                  | 编译器步骤      |
|---|-------------------|-----------------------|-----------------|
| α | `(λ (x) (+ x y))` | `(λ (x.0) (+ x.0 y))` | `uniquify`      |
| β | `((λ (x) b) v)`   | `b[x := v]`           | `β?` match 分支 |
| η | `(λ (x) (f x))`   | `f`                   | `η?` match 分支 |

---

# 完整的变换器

输出已经是 CPS，变换器也随之改名：`anf` 改为 `cps`，`anf0` 改为 `cps0`，`anf1` 改为 `cps1`。三路规范化要装进所有构造延续 lambda 的分支，分三组：

1. **平凡调用**、**用户定义的调用**和 **`reset`**。三者都构造 `(λ (,vn) ,(ctx vn))` 作为延续；match 检查它是 β-归约、η-归约还是做了真正的工作。

```racket
[`(,(? trivial? r) . ,rand*)
 (shift ctx
   (define vn (fv))
   (define d* (map cps0 rand*))
   (define r* `(,r . ,d*))
   (match `(λ (,vn) ,(ctx vn))
     [`(λ (,vn) ,b)       #:when (β? b vn) r*]
     [`(λ (,vn) (,k ,vn)) #:when (η? k vn) `(,k ,r*)]
     [k                                    `(,k ,r*)]))]

[`(,rator . ,rand*)
 (shift ctx
   (define vn (fv))
   (define r  (cps0 rator))
   (define d* (map cps0 rand*))
   (define r* `(,r . ,d*))
   (match `(λ (,vn) ,(ctx vn))
     [`(λ (,vn) ,b)       #:when (β? b vn) `(,r* values)]
     [`(λ (,vn) (,k ,vn)) #:when (η? k vn) `(,r* ,k)]
     [k                                    `(,r* ,k)]))]

[`(reset ,body)
 (shift ctx
   (define vn (fv))
   (define r* (cps1 body id))
   (match `(λ (,vn) ,(ctx vn))
     [`(λ (,vn) ,b)       #:when (β? b vn) r*]
     [`(λ (,vn) (,k ,vn)) #:when (η? k vn) `(,k ,r*)]
     [k                                    `(,k ,r*)]))]
```

三个分支共享相同的三路 match。`reset` 分支与平凡调用写法相同，只是 `r*` 换成了主体编译出的代码 `(cps1 body id)`：局部答案和平凡调用的结果一样，命名后交给 `ctx`。两种调用唯一的区别是 β 触发时发射什么：平凡调用直接发射 `r*`（结果不需要进一步分派），用户定义的调用发射 `(,r* values)`。函数被调用时没有剩余工作，它的延续就是初始局部延续 `a->⊥ᵃ`，也就是恒等函数，在目标代码里写作 `values`。这是 `values` 第一次作为延续名字进入输出。

2. **shift** 分支。match 应用两次：一次在 `(λ (,vn) ,(ctx vn))` 上（与情况 1 相同的检查），一次在 `(λ (,k) ,(cps1 body id))` 上（为 shift 体命名延续）。

```racket
[`(shift _ ,body)
 (shift _ (cps1 body id))]

[`(shift ,k ,body)
 (add-trivial! k)
 (define r
   (match `(λ (,k) ,(cps1 body id))
     [`(λ (,k) ,b)      #:when (β? b k) id]
     [`(λ (,k) (,r ,k)) #:when (η? r k) (λ (k) `(,r ,k))]
     [r                                 (λ (k) `(,r ,k))]))
 (shift ctx
   (define vn (fv))
   (match `(λ (,vn) ,(ctx vn))
     [`(λ (,vn) ,b)       #:when (β? b vn) (r 'values)]
     [`(λ (,vn) (,k ,vn)) #:when (η? k vn) (r k)]
     [k                                    (r k)]))]
```

`(shift _ body)` 丢弃了捕获的延续，编译器也随之丢弃自己的 `ctx`：本来会打印程序剩余部分的那段代码根本不会被生成。未使用的延续不只是在运行时被跳过，它们根本不存在。

3. **if** 分支。match 像之前一样检查 β/η。`r` 内部的 `cond` 决定延续是否需要被命名以避免跨分支复制：如果它是 `values`（恒等），两个分支用 `id` 编译；如果它已经是一个 symbol，可以直接使用；否则 `(fk)` 创建一个新名字。

```racket
[`(if ,test ,conseq ,alt)
 (shift ctx
   (define (r k)
     (define kn (fk))
     (cond
       [(eq? k 'values)  (cps-if id)]
       [(symbol? k)      (cps-if (reset `(,k  ,(shift k k))))]
       [else `((λ (,kn) ,(cps-if (reset `(,kn ,(shift k k))))) ,k)]))
   (define vn (fv))
   (define t (cps0 test))
   (define (cps-if ctx0)
     `(if ,t ,(cps1 conseq ctx0) ,(cps1 alt ctx0)))
   (match `(λ (,vn) ,(ctx vn))
     [`(λ (,vn) ,b)       #:when (β? b vn) (r 'values)]
     [`(λ (,vn) (,k ,vn)) #:when (η? k vn) (r k)]
     [k                                    (r k)]))]
```

`cond` 的三个分支避免在延续已经简单到可以直接复制时分配名字：`values` 没有代价，裸 symbol 已经是名字。只有复合延续才获得一个新的 `kn`，绑定一次，在两个分支中引用。

每个分支一个输入：

```racket
> (cps '(if a b c))
'(if a b c)
> (cps '(add1 (if a b c)))
'(if a (add1 b) (add1 c))
> (cps '(f (if a b c)))
'((λ (k.0) (if a (k.0 b) (k.0 c))) (λ (v.1) ((f v.1) values)))
```

在顶层，延续是 `values`，所以两个分支在 `id` 下编译，`if` 原样通过。在 `add1` 下方，延续是裸 symbol，足够廉价可以写入两个分支；不分配名字。在 `f` 下方，一个用户定义的调用，延续是一个复合 lambda，只有现在编译器才把它绑定到 `k.0`，让两个分支引用这个名字。绑定形式就是文法中的 `<apply-cont²>`：一个 `let`，其绑定值恰好是一个延续。

前面手工归约过的两个例子：

```racket
> (cps '(λ (n) (f (g n))))
'(λ (n) (λ (k.0) ((g n) (λ (v.1) ((f v.1) k.0)))))
> (cps '(reset (let ([f (λ (x) (shift k 999))]) (add1 (f 42)))))
'((λ (f) ((f 42) add1)) (λ (x) (λ (k.0) ((λ (k) 999) k.0))))
```

Lambda 链的尾调用直接传递 `k.0`，999 例子的调用点延续是裸名字 `add1`。两者都与我们在上一节手工推导的结果一致。

## 语法糖

`let*` 和 `let/lc` 在「镜子破裂」一节已经加过。多绑定的 `let` 脱糖为 lambda 应用：

```racket
[`(let ([,x* ,exp*] ...) ,body)
 (cps0 `((λ ,x* ,body) . ,exp*))]
```

剩下 `abort` 和 `let/cc`。第三篇的 `abort` 不是宏，而是一个函数：`(define (abort . v*) (shift _ (apply values v*)))`。它对应元延续，作为一等值还可以参与复合，`let/cc` 的定义里就用到了 `(∘ abort k)`。编译器也把它当作函数：`abort` 这个名字代表它的定义 `(λ (v) (shift _ v))`。

```racket
['abort (cps0 '(λ (v) (shift _ v)))]
[`(abort . ,rand*) (cps0 `((λ (v) (shift _ v)) . ,rand*))]
```

第一条处理 `abort` 作为值出现的地方。第二条在调用处直接代入定义，交给 lambda 应用的分支，省去一次用户函数调用。

>**注意：** 编译器只处理单值，`abort` 也只接受一个参数。第三篇的 `abort` 用 `(apply values v*)` 支持多值；多值不影响本文的讨论，这里从略。

`let/cc` 照第三篇「元延续」一节 `call/cc` 的定义 `(let/lc k (proc (∘ abort k)))` 展开，复合写成 lambda：

```racket
[`(let/cc ,k ,body)
 (define vn (fv))
 (define kn (fk))
 (cps0 `(let/lc ,kn (let ([,k (λ (,vn) (abort (,kn ,vn)))]) ,body)))]
```

`abort` 作为一等值，编译出来是什么？

```racket
> (cps '(reset (let ([f abort]) (+ 1 (f 5)))))
'((λ (f) ((f 5) (λ (v.2) (+ 1 v.2)))) (λ (v) (λ (k.0) v)))
```

运行结果是 `5`，加一被跳过了。`abort` 变成了 `(λ (v) (λ (k.0) v))`：一个用户定义的函数，接受调用处的延续 `k.0`，却不用它，直接交出 `v`。这正是第三篇的 `cps:abort`，即 `(cps* a->⊥ᵃ)`：`cps*` 丢弃当前延续，把值交给初始局部延续，而初始局部延续是恒等函数。除了把名字换成定义，编译器没有为 `abort` 写任何特殊处理，修复之后用户定义函数的一般规则就产生了这个形状。

`let/cc` 也是如此。第三篇「元延续」一节的例子：

```racket
> (cps '(let ([k (reset (let ([x (let/cc k (abort k))]) (+ x 2)))])
          (+ (reset (k 3)) 100)))
'((λ (k) ((λ (v.7) (+ v.7 100)) ((k 3) values)))
  ((λ (k.0) (λ (v.1) (λ (k.1) (k.0 v.1)))) (λ (x) (+ x 2))))
```

运行结果是 `105`。`let/cc` 交出的延续是 `(λ (v.1) (λ (k.1) (k.0 v.1)))`：同样忽略调用处的延续 `k.1`，改用保存的局部延续 `k.0`，就是 `(cps* k.0)`。而 `let/lc` 交出的 `k` 是平凡的，调用时与当前延续组合，对应 `cps`。第三篇 CPS 世界里 `call/lc` 与 `call/cc` 的区别，在编译输出里就是这两种形状。

## 四个例子的编译结果

第三篇「定界延续与 CPS」一节，把四个例子逐步化简成了 CPS。现在交给编译器。例一：

```racket
> (cps '(let ([v (reset (let* ([x 3]  ; 例 1：reset 加 abort，没有 shift
                               [y (+ 2 x)])
                          (abort y)))])
          (+ 10 v)))
'((λ (v) (+ 10 v)) ((λ (x) (+ 2 x)) 3))
```

第三篇化简例三、例一时得到的是 `(let ([v (let ([x 3]) (+ 2 x))]) (+ 10 v))`，这里只是 `let` 脱糖成了 lambda 应用。`abort` 代入定义后落进 `(shift _ ...)` 分支，`reset` 的主体在 `id` 下编译，两者都没有在输出中留下痕迹。

例二到例四：

```racket
> (cps '(let ([v (reset (let* ([x (shift k 3)]  ; 例 2：捕获后不使用
                               [y (+ 2 x)])
                          (abort y)))])
          (+ 10 v)))
'((λ (v) (+ 10 v)) ((λ (k) 3) (λ (x) (+ 2 x))))
> (cps '(let ([v (reset (let* ([x (shift k (k 3))]  ; 例 3：调用被捕获的延续一次
                               [y (+ 2 x)])
                          (abort y)))])
          (+ 10 v)))
'((λ (v) (+ 10 v)) ((λ (k) (k 3)) (λ (x) (+ 2 x))))
> (cps '(let ([v (reset (let* ([x (shift k (let ([r (k 3)]) (k r)))]  ; 例 4：调用被捕获的延续两次
                               [y (+ 2 x)])
                          (abort y)))])
          (+ 10 v)))
'((λ (v) (+ 10 v)) ((λ (k) (k (k 3))) (λ (x) (+ 2 x))))
```

三份输出与第三篇手工写出的 CPS 逐字相同，只是例二的参数第三篇写作 `_`。`shift` 和 `reset` 之间的剩余工作，也就是加二，被写成 `(λ (x) (+ 2 x))` 交给主体；外层的加十是 `(λ (v) (+ 10 v))`。三份输出只有主体不同，分别调用 `k` 零次、一次、两次。`k` 是平凡的，所以每次调用编译为普通调用。例四的主体 `(let ([r (k 3)]) (k r))` 经 η-归约成为 `(k (k 3))`。结果：`13`、`15`、`17`。

# `reset` 去了哪里

每个源程序都包含 `reset`；没有一个目标程序包含。没有标记，没有包装器，没有运行时支持。边界去了哪里？

看例二的输出：`((λ (v) (+ 10 v)) ((λ (k) 3) (λ (x) (+ 2 x))))`。`reset` 的主体编译成了 `((λ (k) 3) (λ (x) (+ 2 x)))`，它是外层延续 `(λ (v) (+ 10 v))` 的参数。主体内部的调用都在尾位置，用户函数把延续参数一路传下去，没有谁在等待；主体本身却处在参数位置，宿主要在自己的栈上留一帧，等它算完，再把结果交给加十。这一帧就是边界。

第三篇的 `anf:reset` 是同一个结构：`(kₓa (anf:eval kₐkₐa))` 中，`anf:eval` 不在尾位置，宿主的等待帧保存了外层的 `kₓa`。编译器把这一步写进了目标代码：`reset` 的主体编译到非尾位置，定界由宿主自己的调用与返回提供。主体从 `id` 开始编译，初始局部延续是恒等函数，所以输出里连它也看不见，只在用户定义函数没有剩余工作的调用处，以 `values` 的样子出现。这正是第三篇平凡表示下的分工：局部延续是一路传下去的延续参数，住在堆上的闭包里；元延续是宿主的栈。

---

# 再看阴阳谜题

「镜子破裂」一节，函数形式的谜题只打印出 `@*`。修复之后再编译它：

```racket
> (cps '(reset
         (let* ([label (λ () (let/lc k k))]
                [yin   (label)]
                [_     (display #\@)]
                [yang  (label)]
                [_     (display #\*)])
           (yin yang))))
'((λ (label)
    ((label)
     (λ (yin)
       ((λ (_) ((label) (λ (yang) ((λ (_) ((yin yang) values)) (display #\*)))))
        (display #\@)))))
  (λ () (λ (k.0) ((λ (k) (k k)) k.0))))
```

运行，阶梯回来了：

```
@*@**@***@****@...
```

但对照文法读一读输出。`label` 编译成 `(λ () (λ (k.0) ((λ (k) (k k)) k.0)))`，化简一步就是 `(k.0 k.0)`：调用处的延续 `k.0` 被当作值，交给了它自己。于是 `yin` 和 `yang` 拿到的都是延续。而 `(yin yang)` 编译成了 `((yin yang) values)`：`yin` 不在平凡集合里，编译器把它当作用户定义的函数，额外传了一个延续参数 `values`。文法说延续通过 `<apply-cont>` 调用，写作 `(<cont> <val> ...)`，不带自己的延续参数；这里却是 `<apply-proc>`，一个延续被用在了文法期望过程的位置。

程序照样能跑，只因为 `(yin yang)` 永远不会返回，多传的那个 `values` 从来没有机会被用上。换一个会返回的程序，问题就露出来了：

```racket
> (cps '(let ([id (reset (shift k k))]) (id (id 3))))
'((λ (id) ((id 3) (λ (v.3) ((id v.3) values)))) values)
```

`id` 被绑定到恒等延续，`(id (id 3))` 把它当作一等值使用。化简后：`(define id values)`，然后 `((id 3) (λ (v.3) ((id v.3) values)))`。运行：`application: not a procedure; given: 3`。第一个 `(id 3)` 返回 `3`，而 `3` 被当作过程调用了。

文法把 `<val>` 和 `<cont>` 分开：延续可以被调用，却不能当作值传来传去，它不是一等的。谜题的类型恰恰要求相反。第一篇的 $\text{Label} = ¬\text{Label}$ 换到局部，是 $\text{Label} = ¬ₐ\text{Label}$：`Label` 既是传来传去的值，又是被调用的延续。

第三篇其实处理过这件事。`call/lc` 交给程序的不是裸的 `kₐp`，而是 `(cps kₐp)`：局部延续在宿主里是普通函数，要交给 CPS 世界里的程序，先得用 `cps` 提升成 $𝒦ₐ$ 的箭头。在源程序里做同样的事，就是把延续包进一个 lambda：

```racket
> (cps '(let ([id (reset (shift k (λ (v) (k v))))]) (id (id 3))))
'((λ (id) ((id 3) (λ (v.4) ((id v.4) values))))
  ((λ (k) (λ (v) (λ (k.0) (k.0 (k v))))) values))
```

运行结果是 `3`。包装 `(λ (v) (k v))` 编译成了 `(λ (v) (λ (k.0) (k.0 (k v))))`，正是 `(cps k)` 的展开：先把 `v` 交给 `k`，再把结果交给调用处的延续。它是一个合格的 `<val>`。它同时也是一个 η-可归约式，归约后就是刚才出问题的裸 `k`：前面一个接一个擦除包装器的 η 在这里不再成立，因为两侧不再是同一种东西。`(λ (v) (k v))` 是 `<val>`，`k` 是 `<cont>`。

这条界线在文法里是两条产生式：

```BNF
<val>  ::= <var> | <literal> | <proc>
<cont> ::= (λ <head> <cps>) | <trivial>
```

`shift` 命名的 `k` 属于 `<trivial>`，是 `<cont>` 的一种，`<val>` 里没有它的位置。`<trivial>` 里也不只有延续变量：平凡集合是从内建原语开始的，`add1` 和 `k` 站在同一边。

如果刚才出错的原因就是这条界线，和被传递的是不是延续无关，那么 `add1` 当作值传递时也会出同样的错，包一层也同样管用。拿它试一下，一次直接绑定给 `f`，一次包进 lambda：

```racket
> (cps '(let ([f add1]) (f 41)))
'((λ (f) ((f 41) values)) add1)
> (cps '(let ([f (λ (x) (add1 x))]) (f 41)))
'((λ (f) ((f 41) values)) (λ (x) (λ (k.0) (k.0 (add1 x)))))
```

第一个输出里，`f` 不在平凡集合中，编译器把 `(f 41)` 当作用户定义函数的调用，多传了一个 `values`。运行时 `f` 是宿主的 `add1`，直接返回 `42`，`42` 接着被当作过程调用，报的是同一种错。「平凡」是编译器按名字认的，名字一换就认不出来了。第二个输入把 `add1` 包进 lambda，编译出来是 `(cps add1)` 的展开，一个 `<proc>`，运行结果是 `42`。

包装就位后，编译完整的谜题，内联定义以保持输出可读：

```racket
> (cps '(reset
         (let* ([kn (let/lc k0   (λ (v) (k0   v)))]
                [_  (display #\@)]
                [k  (let/lc kn+1 (λ (v) (kn+1 v)))]
                [_  (display #\*)])
           (kn k))))
'((λ (k0) (k0 (λ (v) (λ (k.0) (k.0 (k0 v))))))
  (λ (kn)
    ((λ (_)
       ((λ (kn+1) (kn+1 (λ (v) (λ (k.1) (k.1 (kn+1 v))))))
        (λ (k) ((λ (_) ((kn k) values)) (display #\*)))))
     (display #\@))))
```

改写为 `define` 形式：

```racket
(define (k0 kn)
  (display #\@)
  (define (kn+1 k)
    (display #\*)
    ((kn k) values))
  (kn+1 (λ (v) (λ (k.1) (k.1 (kn+1 v))))))
```

```racket
> (k0 (λ (v) (λ (k.0) (k.0 (k0 v)))))
@*@**@***@****@...
```

这次每个延续都待在文法给它的位置上，代码也说明了阶梯为什么永不停止。每个延续参数（`k.0`、`k.1`）都使用过了：`(k.0 (k0 v))` 和 `(k.1 (kn+1 v))`。但在运行时，每次调用传递的延续参数都是 `values`，即初始局部延续，所以 `k.0` 和 `k.1` 总是绑定到 `values`，从不做事。递归调用 `(k0 v)` 和 `(kn+1 v)` 语法上处在非尾位置，外面包着 `(k.0 ...)` 和 `(k.1 ...)`；但因为 `values` 是恒等，等着它们的帧不做任何工作，只是接收递归调用的结果，原样传回。帧在宿主栈上累积，而谜题永不返回，它们永远不会被回卷。递归永远旋转。

---

# 结论

编译器的 `ctx` 和目标程序的延续，从一开始就是同一份剩余工作的两种形态：一边是编译时等着被调用的闭包，一边是打印在纸上的代码。

转折发生在函数边界。第三篇说，函数调用和 `reset` 做的是同一件事，都从空栈开始。编译器照此编译，lambda 主体里的 `shift` 就看不见调用处的剩余工作。修复让函数调用放弃定界：用户定义的函数接受调用者的延续，剩余工作搬到堆上，宿主栈只留给 `reset`。ANF 是每个调用都借一个宿主帧的记法，CPS 是调用不借帧的记法；要同时有一等函数和定界延续，本篇选的办法是让函数调用不借帧，编译器的输出也就从 ANF 变成了 CPS。这是实现上的一种选择，不是唯一的出路。

第二篇的 `anf:` 宏在展开时做过同一种翻译，把 ANF 写法译成 CPS 编码；第三篇在那套编码里加上了 `reset` 与 `shift`。本篇的编译器把翻译的对象从宏的参数换成了源程序的语法树，第三篇手工搭起来的构造也就按一般规则出现在了编译输出里：四个例子的 CPS，与第三篇手写的逐字相同。

## 未解的线索

我们现在已经遍历了两棵树。`fib/k` 走过斐波那契的递归树；编译器走过源程序的语法树。两者中，延续都充当遍历的前沿：树中已访问部分和尚未到来部分之间的边界。第三篇把 CPS 里使用局部延续的方式归结为三条约束：在尾位置、使用当前的那一条、恰好使用一次。`fib/k` 三条都遵守：宿主栈保持扁平，前沿完全活在参数中。编译器取消了位置的限制。`ctx` 在编译器需要的任何地方被调用，在 `(ctx (cps0 exp))` 中，在组装一个 `if` 的中途：前沿不再装得进参数，一部分溢出到了程序自己的栈上。擦除参数使这正式化了：有了 `shift` 和 `reset`，所有剩余工作都活在程序自己的栈上，编译器需要前沿时就从栈中把它捞出来。编译器的前沿与程序自己的调用栈，从此合在了同一个栈上。

位置的限制消失了，但「恰好一次」在两棵树中都存活了下来，而且是有原因的。两次遍历都描述一次单独的计算，而一次计算有一条单独的时间线：在任何时刻恰好有一份剩余工作，一旦运行过了就成为过去。即使 `if` 分支也遵守这一点。延续出现在生成代码的两个分支中，但测试值在任一分支之前算出，选择了其中一个；另一个永远不会被进入。未来被写了两次，运行了一次。重复存在于文本中，不在时间中，而命名延续使文本与时间保持一致。什么样的树会真正打破这条限制？一棵没有任何值在备选项之间做选择的树，每个备选项都被走到，同一份剩余工作必须为每个备选项各运行一次。一棵**搜索树**：一棵拥有不止一条时间线的树。

而合并本身也隐藏着第二个问题。两条前沿进入了同一个栈，但栈保持了两种取出工作的方式：返回消耗栈顶帧，`shift` 在最近的 `reset` 处切割。一个容器，两种出口；这就是两条前沿能共享它的原因。如果第三条前沿想加入合并呢？第四条呢？

那些是后续文章的故事了。

---

# 完整代码参考

变换器基于 Yin Wang 的 [`cps.ss`](https://github.com/yinwang0/historical/blob/master/cps.ss)。它输出的文法：

```BNF
<cps> ::= <val> | <if> | <apply>

<val>   ::= <var> | <literal> | <proc>
<if>    ::= (if <val> <cps> <cps>)
<apply> ::= <apply-proc> | <apply-cont> | <apply-cont²>

<apply-proc>  ::= ((<val> <val> ...) <cont>)
<apply-cont>  ::= (<cont> <cps>) | (<cont> <val> ...)
<apply-cont²> ::= (<cont²> <cont>)

<proc>  ::= (λ <head> <cont²>)
<cont>  ::= (λ <head> <cps>) | <trivial>
<cont²> ::= (λ (<trivial>) <cps>)

<head>  ::= <var> | (<var> ...) | (<var> ... . <var>)
```

```racket
(require racket/control)

(define (cps exp)
  (define trivial* (mutable-seteq))
  (define (trivial? x) (set-member? trivial* x))
  (define (add-trivial! x) (set-add! trivial* x))
  (for-each add-trivial!
   '(identity values
     display displayln
     zero? add1 sub1
     + - * /
     = < <= > >=
     eq? eqv? equal?))

  (define (β? b v)
    (match b
      [`((λ (,u) ,u) ,e) (eq? e v)]
      [`((λ (,u) ,b) ,e)
       (and (eq? b v)
            (if (eq? u v)
                (eq? e v)
                (not (pair? e))))]
      [_ (eq? b v)]))
  (define (η? k v)
    (match k
      [`(λ (,u) ,b)
       (or (eq? u v)
           (not (if (pair? b)
                    (memq v (flatten b))
                    (eq? b v))))]
      [(? trivial?) (not (eq? k v))]
      [_ #f]))

  (define ((make-genvar name [n 0]))
    (define var (string->symbol (format "~a.~a" name n)))
    (when (eq? name 'k) (add-trivial! var))
    (set! n (add1 n))
    var)
  (define fv (make-genvar 'v))
  (define fk (make-genvar 'k))

  (define id (reset (shift k k)))
  (define (cps1 exp ctx) (reset (ctx (cps0 exp))))
  (define cps0
    (match-λ
      ['abort (cps0 '(λ (v) (shift _ v)))]
      [(? (not/c pair?) x) x]
      [`(λ ,x* ,body)
       (define kn (fk))
       (define ctx0 (reset `(,kn ,(shift k k))))
       `(λ ,x* (λ (,kn) ,(cps1 body ctx0)))]

      [`(reset ,body)
       (shift ctx
         (define vn (fv))
         (define r* (cps1 body id))
         (match `(λ (,vn) ,(ctx vn))
           [`(λ (,vn) ,b)       #:when (β? b vn) r*]
           [`(λ (,vn) (,k ,vn)) #:when (η? k vn) `(,k ,r*)]
           [k                                    `(,k ,r*)]))]
      [`(shift _ ,body)
       (shift _ (cps1 body id))]
      [`(shift ,k ,body)
       (add-trivial! k)
       (define r
         (match `(λ (,k) ,(cps1 body id))
           [`(λ (,k) ,b)      #:when (β? b k) id]
           [`(λ (,k) (,r ,k)) #:when (η? r k) (λ (k) `(,r ,k))]
           [r                                 (λ (k) `(,r ,k))]))
       (shift ctx
         (define vn (fv))
         (match `(λ (,vn) ,(ctx vn))
           [`(λ (,vn) ,b)       #:when (β? b vn) (r 'values)]
           [`(λ (,vn) (,k ,vn)) #:when (η? k vn) (r k)]
           [k                                    (r k)]))]

      [`(let/lc ,k ,body)
       (cps0 `(shift ,k (,k ,body)))]
      [`(let/cc ,k ,body)
       (define vn (fv))
       (define kn (fk))
       (cps0 `(let/lc ,kn (let ([,k (λ (,vn) (abort (,kn ,vn)))]) ,body)))]

      [`(if ,test ,conseq ,alt)
       (shift ctx
         (define (r k)
           (define kn (fk))
           (cond
             [(eq? k 'values)  (cps-if id)]
             [(symbol? k)      (cps-if (reset `(,k  ,(shift k k))))]
             [else `((λ (,kn) ,(cps-if (reset `(,kn ,(shift k k))))) ,k)]))
         (define vn (fv))
         (define t (cps0 test))
         (define (cps-if ctx0)
           `(if ,t ,(cps1 conseq ctx0) ,(cps1 alt ctx0)))
         (match `(λ (,vn) ,(ctx vn))
           [`(λ (,vn) ,b)       #:when (β? b vn) (r 'values)]
           [`(λ (,vn) (,k ,vn)) #:when (η? k vn) (r k)]
           [k                                    (r k)]))]

      [`(let* () ,body)
       (cps0 `(let () ,body))]
      [`(let* ([,x ,exp] . ,bind*) ,body)
       (cps0 `(let ([,x ,exp]) (let* ,bind* ,body)))]
      [`(let ([,x* ,exp*] ...) ,body)
       (cps0 `((λ ,x* ,body) . ,exp*))]
      [`((λ () ,body))
       (cps0 body)]
      [`((λ (,x) ,body) ,rand)
       (shift ctx
         (define d (cps0 rand))
         (match `(λ (,x) ,(cps1 body ctx))
           [`(λ (,v) ,b)      #:when (β? b v) d]
           [`(λ (,v) (,k ,v)) #:when (η? k v) `(,k ,d)]
           [k                                 `(,k ,d)]))]
      [`((λ ,x* ,body) . ,rand*)
       (shift ctx
         (define k `(λ ,x* ,(cps1 body ctx)))
         (define d* (map cps0 rand*))
         `(,k . ,d*))]

      [`(abort . ,rand*) (cps0 `((λ (v) (shift _ v)) . ,rand*))]

      [`(,(? trivial? r) . ,rand*)
       (shift ctx
         (define vn (fv))
         (define d* (map cps0 rand*))
         (define r* `(,r . ,d*))
         (match `(λ (,vn) ,(ctx vn))
           [`(λ (,vn) ,b)       #:when (β? b vn) r*]
           [`(λ (,vn) (,k ,vn)) #:when (η? k vn) `(,k ,r*)]
           [k                                    `(,k ,r*)]))]

      [`(,rator . ,rand*)
       (shift ctx
         (define vn (fv))
         (define r  (cps0 rator))
         (define d* (map cps0 rand*))
         (define r* `(,r . ,d*))
         (match `(λ (,vn) ,(ctx vn))
           [`(λ (,vn) ,b)       #:when (β? b vn) `(,r* values)]
           [`(λ (,vn) (,k ,vn)) #:when (η? k vn) `(,r* ,k)]
           [k                                    `(,r* ,k)]))]))

  (cps1 exp id))
```
