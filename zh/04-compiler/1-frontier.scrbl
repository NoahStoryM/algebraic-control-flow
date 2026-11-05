#lang acf/scribble

@title[#:tag "04:1-frontier"]{从递归到遍历}

这是@xref["02:1-anf-cps"]{「求值顺序」}里的 @racket[fib]，斐波那契函数：

@(define ev-fib (make-acf-eval))
@examples[#:eval ev-fib #:no-result
(define (fib n)
  (if (< n 2)
      n
      (+ (fib (- n 1))
         (fib (- n 2)))))]

它是递归的，而且不是尾递归：每次子调用返回后，还有待执行的工作（第二次子调用，然后是加法）。这些待执行的工作活在调用栈上。怎么把它变成循环？

标准技巧：自己管理栈。用一个显式的@defterm[#:en "frame"]{帧}列表替换隐式的调用栈，每个帧记录一件待执行的工作和它所需的数据。@racket[fib] 中出现两种待执行的工作：「第一次子调用返回了，现在算第二次」（需要 @racket[(- n 2)]）和「两次子调用都返回了，现在相加」（需要第一个结果）。给每种打上@tech{标记}，压入列表：

@(define ev-loop (make-acf-eval))
@examples[#:eval ev-loop #:no-result
(define (fib n) (fib/k n '()))

(define (fib/k n k)
  (if (< n 2)
      (apply-cont k n)
      (fib/k (- n 1) (cons `(fib ,(- n 2)) k))))

(define (apply-cont k v)
  (match k
    ['() v]
    [`((fib ,n-2) . ,k) (fib/k n-2 (cons `(add ,v) k))]
    [`((add ,w) . ,k)   (apply-cont k (+ w v))]))]

@racket[fib/k] 压入一个 @racket[(fib ...)] 帧，然后递归。当基础情况触发时，@racket[apply-cont] 根据栈顶帧分派。@racket[(fib n-2)] 帧意味着「第一次子调用完成了，现在做第二次」，于是压入一个 @racket[(add v)] 帧并再次调用 @racket[fib/k]。@racket[(add w)] 帧意味着「两次子调用都完成了，相加然后继续」，于是弹出帧并在尾部递归。每次调用都是尾调用；帧列表就是栈。

@section[#:tag "04:recognize-k"]{认出延续}

@racket[fib/k] 的第二个参数是什么？@xref["02:cps"]{「延续与 CPS」}里，我们把 @racket[fib] 写成了 @tech[#:key "延续传递风格"]{CPS} 形式：

@(define ev-cps (make-acf-eval))
@examples[#:eval ev-cps #:no-result
(define (fib/k n k)
  (if (< n 2)
      (k n)
      (fib/k (- n 1)
             (λ (v)
               (fib/k (- n 2)
                      (λ (w)
                        (k (+ v w))))))))]

每次递归调用都在 @racket[k] 上多裹一层 lambda。这条 lambda 链就是调用栈，以闭包的形式建在堆上。每个闭包恰好携带一个帧所需的数据。@racket[(λ (v) (fib/k (- n 2) (λ (w) (k (+ v w)))))] 携带两份数据：@racket[(- n 2)]（待执行的第二次子调用）和外层@tech{延续} @racket[k]。第二个闭包 @racket[(λ (w) (k (+ v w)))] 携带 @racket[v]（第一个结果）和 @racket[k]。每个闭包就是一个帧：一个@tech{标记}说明接下来做什么，加上做这件事所需的数据。

循环版本和 @tech[#:key "延续传递风格"]{CPS} 版本是同一个程序。一个把栈表示为带@tech{标记}的数据列表，另一个把栈表示为@tech{闭包链}。从闭包到数据@tech{标记}的变换有个名字：@defterm[#:en "defunctionalization"]{去函数化}。反向变换，从数据@tech{标记}到闭包，叫做@defterm[#:en "refunctionalization"]{再函数化}。任何一个把递归函数改写为 while 循环加显式栈的程序员，都在手工执行去函数化。

帧列表仍然是@tech{延续}。@racket['()] 是空栈，走到它时 @racket[apply-cont] 把 @racket[v] 原样返回。换成闭包版本，就相当于以恒等函数为@tech{终结延续}，也就是@tech{局部终结延续} @racket[a->⊥ᵃ]。整条帧列表是一条@tech{局部延续} @math{¬ₐ@ty{Natural}}，答案类型 @math{a} 就是 @racket[Natural]。@racket[apply-cont] 把@tech{延续}应用于值，仍是@tech{矛盾律}：由 @math{v : p} 和 @math{k : ¬ₐp} 得到 @math{k(v) : a}，只是得到的不再是 @math{⊥}，而是@tech{局部答案}。表示变了，从闭包变成了数据；类型和定律没有变。

但帧列表有一个闭包没有的性质：它是可以检查、拆开和重组的数据。由闭包构成的@tech{延续}是一个黑盒：只能调用，看不见里面。由数据构成的@tech{延续}是透明的：可以对它做模式匹配，根据看到的内容决定如何处理，还可以重组它。

@section[#:tag "04:frontier"]{前沿}

还有另一种方式来读 @racket[fib/k]。它遍历一棵二叉树（斐波那契的递归树），在一个栈中累积中间结果。这个栈是一条@defterm[#:en "frontier"]{前沿}：在任何时刻，它记录的是树中已访问部分和尚未探索部分之间的边界。@tech[#:key "延续传递风格"]{CPS} 就是树遍历，@tech{延续}就是@tech{前沿}。

如果把算术树换成语法树呢？

@section[#:tag "04:traverse"]{遍历语法树}

将源代码变换为 @tech[#:key "A-范式"]{ANF} 的@defterm[#:en "pass"]{编译趟}做的事情和 @racket[fib/k] 一样：遍历一棵树（源 AST），累积一个结果（目标代码）。遍历的@tech{前沿}（@tech{延续}）记录着编译器打算在每个子表达式的结果计算出来之后如何处理它。

既然@tech{前沿}就是@tech{延续}，变换器也可以像 @racket[fib/k] 那样写成 @tech[#:key "延续传递风格"]{CPS}：@racket[fib/k] 传递 @racket[k] 穿过递归树，变换器传递一个@tech{延续} @racket[ctx] 穿过语法树。

@tech[#:key "A-范式"]{ANF} 需要给中间结果命名。如果函数调用的参数本身也是函数调用，内层结果必须先用 @racket[let] 绑定到一个新名字，然后才能作为参数传递。所以我们需要一个新名字的供应源。这一章所有示例都假设源代码已经过一趟 uniquify pass，重命名了绑定器使得没有重名。对于目标代码，生产编译器会用 @racket[gensym]；为了可读性，我们定义 @racket[make-genvar]，变换器实例化自己的生成器 @racket[fv]，产出 @racket[v.0]、@racket[v.1]、@racket[v.2] 这样的名字。点号分隔编译器的命名空间和源代码的命名空间。

@(define ev-anf (make-acf-eval))
@examples[#:eval ev-anf #:hidden
(require racket/contract/base)]

@examples[#:eval ev-anf #:no-result
(define ((make-genvar name [n 0]))
  (define var (string->symbol (format "~a.~a" name n)))
  (set! n (add1 n))
  var)]

要处理哪些情况，由目标文法决定。这是用 BNF（Backus-Naur 范式）写的目标文法，@tech[#:key "A-范式"]{ANF} 的初始草图：

@racketgrammar*[
#:literals (λ if let)
[anf val (if val anf anf) (let ([var atom]) anf)]
[atom val (var val ...) (proc val ...)]
[val var literal proc]
[proc (λ head anf)]
[head var (var ...) (var ... . var)]]

一个 @racket[_atom] 要么是值，要么是一次调用：调用的函数和实参都已经是值，不需要先计算任何子表达式。@racket[(f x)] 是一个 @racket[_atom]，@racket[(f (g x))] 不是，要先给 @racket[(g x)] 的结果命名。

在 @tech[#:key "A-范式"]{ANF} 中，函数调用的参数必须是一个@emph{值}（变量、字面量或 lambda），不能是复合表达式。如果参数本身是函数调用，就必须先用 @racket[let] 绑定到一个变量。这正是使求值顺序显式化的方式：@racket[let] 链条@emph{就是}求值轨迹。文法的各种情况告诉我们变换器需要哪些分支。

@examples[#:eval ev-anf #:no-result
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
  (anf1 exp id))]

每个分支递归进入子表达式，在 @racket[ctx] 上多裹一层 lambda，表示「一旦你拿到这个子表达式的结果，接下来该做什么」。当一个子表达式被完全处理后，它的结果就传给 @racket[ctx]。Lambda 体用 @racket[id]（恒等函数）编译，因为每个 lambda 体从一个全新的空@tech{延续}开始：每次函数调用分配一个全新的栈。

以 @racket[(h (f (g a)))] 为例：

@examples[#:eval ev-anf #:label #f
(anf '(h (f (g a))))]

什么都没发生。输出和输入一模一样。

我们遍历了整棵树，但几乎什么都没做。为什么？我们定义了 @racket[fv] 来生成新名字，但 @racket[fv] 从未被调用过。没有中间结果被命名。没有 @racket[let] 被发射。

把问题追溯到 application 分支 @racket[(,rator ,rand)]。它产出 @racket[(,r ,d)]：把 application 原样重建了。子表达式被处理了，但结果从未被绑定到新变量。

在每个分支中，@racket[ctx] 恰好被调用一次，在尾位置。它从不出现在发射的代码内部。正如 @racket[fib/k] 可以在 @tech[#:key "延续传递风格"]{CPS} 变换之前写成普通递归函数 @racket[fib]，@racket[anf1] 也可以写回一个没有@tech{延续}参数的普通递归函数。去掉 @racket[ctx]：

@examples[#:eval ev-anf #:no-result
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
     `(,(anf0 rator) ,(anf0 rand))]))]

@racket[anf0] 几乎是恒等函数。它递归穿过树，原样重建，唯一的区别是裸 lambda application @racket[((λ (x) body) rand)] 被规范化为 @racket[let] 形式 @racket[(let ([x rand]) body)]。

当 @racket[ctx] 被擦除后，程序自己的@tech{延续}（宿主的调用栈，即@tech{元延续}）在做遍历。@tech{前沿}仍然在那里，但它隐含在宿主中，而不是显式地写在代码里。

可问题还在：中间结果没有名字，也没有 @racket[let] 被发射。要让 @racket[fv] 派上用场，@racket[ctx] 该放在哪里？
