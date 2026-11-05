#lang acf/scribble

@title[#:tag "04:3-erase"]{擦除延续参数}

修正后的 @racket[anf1] 在每次递归调用中显式传递 @racket[ctx]，每一步都在它上面裹一层 lambda。之前，我们从第一版 @racket[anf1] 中擦除了@tech{延续}参数，得到了 @racket[anf0]，一个近恒等函数。我们能不能也从@emph{修正后}的版本中擦除@tech{延续}参数？

第一次擦除之所以能成功，是因为 @racket[ctx] 只被尾调用：每个分支都以 @racket[(ctx ...)] 结尾，意味着 @racket[ctx] 不扮演任何结构角色。修正后的版本不同。在 application 分支中，@racket[ctx] 出现在生成的 @racket[let]@emph{内部}：@racket[(ctx vn)] 被嵌入了目标代码。在 @racket[if] 分支中，@racket[ctx] 被传入两个子编译。@tech{延续}不再是结果的被动接收者；它在塑造输出。简单地移除参数会丢失信息。

但@xref["03:delimited-cps"]{「定界延续与 CPS」}的对应表恰好描述了这个变换。表中 @tech[#:key "延续传递风格"]{CPS} 那一行以显式参数传递@tech{延续}，@tech[#:key "A-范式"]{ANF} 加 @racket[reset]、@racket[shift] 那一行用 @racket[shift] 在原来的位置取得它，两行是同一个程序。而 @racket[anf1] 本身就是一个 @tech[#:key "延续传递风格"]{CPS} 程序：它接收一个源表达式和一条@tech{局部延续} @math{¬ₐ⟨@ty{val}⟩}，交出 @racket[_anf]，正是@xref["03:any-base"]{「换了基的箭头」}里 @math{→@subscript{𝒦ₐ}} 箭头的形状。这张表应该也能用在编译器自己的源代码上。

需要的是表的最后一组，@racket[v] 接收计算结果，@racket[k] 接收剩余工作：

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list @elem{写法} @elem{代码})
   (list @tech[#:key "延续传递风格"]{CPS} @racket[((λ (v k) body) exp (λ (w) body1))])
   (list @tech[#:key "A-范式"]{ANF} @racket[(let ([v exp] [k (λ (w) body1)]) body)])
   (list @elem{@tech[#:key "A-范式"]{ANF} 加 @racket[reset]、@racket[shift]} @racket[(reset (let ([w (let ([v exp]) (shift k body))]) body1))]))]

@section[#:tag "04:lookup"]{查表}

考虑 @racket[ctx] 以字面 lambda 出现的调用点。为了匹配表中的 @tech[#:key "延续传递风格"]{CPS} 形式，把 @racket[anf1] 包在一个 lambda 里，使两参数结构显式化。结构吻合：一个表达式和一个@tech{延续}，分别作为参数传递。@tech[#:key "A-范式"]{ANF} 加 @racket[reset]、@racket[shift] 一行给出了@tech{延续}由 @racket[shift] 取得、而非作为参数传递时的写法：

@racketblock[
(code:comment "原始调用点：")
(anf1 sub (λ (w) body))

(code:comment "与表中 CPS 形式相同的两参数结构：")
(code:comment "表： ((λ (v k) body) exp (λ (w) body1))")
(code:comment "anf1： ((λ (exp ctx) (anf1 exp ctx)) sub (λ (w) body))")

(code:comment "ANF + reset/shift 一行：用 shift 取得 ctx：")
(anf1 sub (λ (w) body))
(code:comment "=>")
(reset (let ([w (shift ctx (anf1 sub ctx))]) body))]

@racket[(shift ctx (anf1 sub ctx))] 出现在每一个这样的调用点。给它起个名字，调用点就简化了：

@racketblock[
(define (anf0 exp) (shift ctx (anf1 exp ctx)))

(code:comment "每个 (anf1 sub (λ (w) body)) 变成：")
(reset (let ([w (anf0 sub)]) body))]

另一类调用点直接传递 @racket[ctx]，没有包在 lambda 里。同样的包装技巧可用：@racket[(anf1 sub (λ (w) (ctx w)))]。应用同一组表：

@racketblock[
(anf1 sub ctx)
(code:comment "= (anf1 sub (λ (w) (ctx w)))    ; η-展开")
(code:comment "=>")
(reset (let ([w (anf0 sub)]) (ctx w)))
(code:comment "= (reset (ctx (anf0 sub)))")]

在 @racket[(reset (ctx (anf0 sub)))] 中，@racket[anf0] 执行 @racket[shift] 时，从 @racket[(anf0 ...)] 到 @racket[reset] 末尾的@tech{局部延续}恰好就是 @racket[ctx] 本身。所以 @racket[shift] 取得的，正是 @racket[anf1] 原先作为参数接收的东西。

不过@xref["03:delimited-cps"]{「定界延续与 CPS」}列表时加过限定：@racket[exp]、@racket[body] 指不再含其他控制操作的普通代码。这里的 @racket[body] 会调用 @racket[anf0]，也就含有 @racket[shift]。用@xref["03:rules"]{「规约规则」}核对一下：@racket[(reset (let ([w (shift ctx e)]) body))] 规约后，@racket[ctx] 绑定的是 @racket[(λ (w) (reset body))]，比原来的 @racket[(λ (w) body)] 多了一层 @racket[reset]。而改写之后，@racket[body] 里对 @racket[anf0] 的每次调用都各自包在自己的 @racket[reset] 里，下面的三种模式都是如此。它们的 @racket[shift] 碰不到外面这层，多出来的 @racket[reset] 也就不起作用，表在这里照样适用。

一个特殊情况：当 @racket[ctx] 是 @racket[id] 时，@racket[(reset (id (anf0 sub)))] 化简为 @racket[(reset (anf0 sub))]。从 @racket[anf0] 到边界没有剩余工作，@tech{局部延续}就是恒等函数。@xref["03:delimited-cps"]{「定界延续与 CPS」}的对应表里恒等的那一组说的正是这件事：@racket[(reset (shift k exp))] 中，@racket[k] 绑定的是 @racket[(λ (v) v)]。取 @racket[exp] 为 @racket[k] 本身，就得到 @racket[id] 的另一种写法：@racket[(define id (reset (shift k k)))]。

@section[#:tag "04:skeleton"]{骨架}

@racket[anf1] 中的每个调用点都匹配三种模式之一：

@itemlist[#:style 'ordered
 @item{@racket[(anf1 sub (λ (w) ...))] 变成 @racket[(reset (let ([w (anf0 sub)]) ...))]}
 @item{@racket[(anf1 sub ctx)] 变成 @racket[(reset (ctx (anf0 sub)))]}
 @item{@racket[(anf1 sub id)] 变成 @racket[(reset (anf0 sub))]}]

@(define ev-skel (make-acf-eval))
@examples[#:eval ev-skel #:hidden
(require racket/control racket/contract/base)
(define ((make-genvar name [n 0]))
  (define var (string->symbol (format "~a.~a" name n)))
  (set! n (add1 n))
  var)]

@examples[#:eval ev-skel #:label #f #:no-prompt
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
  (reset (anf0 exp)))]

@section[#:tag "04:invert"]{反转定义}

这次改写把 @racket[anf0] 引入为 @racket[anf1] 的包装器，但它同时也确立了反向关系：

@racketblock[
(anf0 exp)     = (shift  ctx (anf1 exp ctx))     (code:comment "anf0 由 anf1 定义")
(anf1 exp ctx) = (reset (ctx (anf0 exp)))        (code:comment "anf1 由 anf0 定义")

(code:comment "两者可以互换。把 match 逻辑移入 anf0：")
(define (anf1 exp ctx) (reset (ctx (anf0 exp))))
(define (anf0 exp)
  (shift ctx
    (match exp
      ...各分支同前...)))
(anf1 exp id)]

骨架的顶层调用 @racket[(reset (anf0 exp))] 就是 @racket[(anf1 exp id)]：@racket[anf1] 的定义在 @racket[ctx = id] 时的形式。

@section[#:tag "04:simplify"]{化简}

外层 @racket[shift] 包裹了 @racket[match] 的每个分支。由于 @racket[match] 只是纯粹的分派，@racket[shift] 可以被推入各个分支内部，然后用两条局部等式化简：

@itemlist[#:style 'ordered
 @item{@bold{@racket[(shift ctx (ctx e))] = @racket[e]}，@racket[ctx] 不在 @racket[e] 中自由出现。@xref["03:abort-shift"]{「从 return 到 shift」}给过两条等式：@racket[(shift k (k e)) = (let/lc k e)]，捕获后立即调用，跳转被撤销，只剩捕获；@racket[e] 不用 @racket[k] 时，@racket[(let/lc k e)] 又退化为 @racket[e]。两步连起来就是这一条。}
 @item{@bold{@racket[(shift ctx (reset e))] = @racket[(shift ctx e)]。}@xref["03:rules"]{「规约规则」}里，@racket[shift] 的主体规约后仍然在原来的 @racket[reset] 里，规约式最外面保留了 @racket[reset]。主体本来就处在一层边界之内，再加一层 @racket[reset] 不改变任何事。}]

在原子和 lambda 分支中，@racket[shift] 化简消失了：

@racketblock[
[(? (not/c pair?) x) (shift ctx (ctx x))]                   (code:comment "等式 1 => x")
[`(λ ,x* ,body) (shift ctx (ctx `(λ ,x* ,(anf1 body id))))] (code:comment "等式 1 => `(λ ,x* ,(anf1 body id))")]

两个都完全化简掉了。原子和 lambda 本身已经是值；捕获@tech{延续}只是为了把它们交出去，纯属多余。在第一版 @racket[anf1] 中，@racket[ctx] 只被尾调用，@emph{每个}分支都是这种形式：@racket[(shift ctx (ctx ...))]。每个 @racket[shift] 都化简消失了，@racket[anf0] 退化为一个对@tech{延续}无所作为的近恒等函数。修正后的版本不同：复合分支在生成的代码内部使用了 @racket[ctx]，所以它们的 @racket[shift] 存活了下来。

@racket[if] 和 lambda-application 分支保留了它们的 @racket[shift]：

@racketblock[
[`(if ,test ,conseq ,alt)
 (shift ctx (code:comment "保留：ctx 在发射的代码内部使用")
   (reset (code:comment "等式 2 => 移除")
    (let ([t (anf0 test)])
      `(if ,t ,(anf1 conseq ctx) ,(anf1 alt ctx)))))]

[`((λ (,x) ,body) ,rand)
 (shift ctx (code:comment "保留：ctx 在体的编译中使用")
   (reset (code:comment "等式 2 => 移除")
    (let ([d (anf0 rand)])
      `(let ([,x ,d]) ,(anf1 body ctx)))))]]

每个分支内最外层的 @racket[reset] 被等式 2 吸收。

@racket[let] 分支需要两条等式依次应用：

@racketblock[
(code:comment "之前：")
[`(let ([,x ,e]) ,body)
 (shift ctx
   (reset (code:comment "等式 2 => 移除")
    (ctx (code:comment "等式 1 => 移除")
     (anf0 `((λ (,x) ,body) ,e)))))]

(code:comment "等式 2 去掉 reset，等式 1 去掉 (shift ctx (ctx ...))：")
[`(let ([,x ,e]) ,body)
 (anf0 `((λ (,x) ,body) ,e))]]

这是把 @racket[anf0] 的定义反着读：对脱糖形式调用 @racket[anf0]，等价于对它调用 @racket[anf1] 并传入当前的 @racket[ctx]，因为 @racket[(shift ctx (anf1 e ctx))] 就是 @racket[(anf0 e)]。

application 分支有两个 @racket[reset]：

@racketblock[
(code:comment "之前：")
[`(,rator ,rand)
 (shift ctx
   (define vn (fv))
   (reset (code:comment "等式 2 => 移除")
    (let ([r (anf0 rator)])
      (reset (code:comment "这个能去掉吗？")
       (let ([d (anf0 rand)])
         `(let ([,vn (,r ,d)])
            ,(ctx vn)))))))]

(code:comment "之后：")
[`(,rator ,rand)
 (shift ctx
   (define vn (fv))
   (let ([r (anf0 rator)])
     (let ([d (anf0 rand)])
       `(let ([,vn (,r ,d)])
          ,(ctx vn)))))]]

外层 @racket[reset] 被等式 2 吸收，和其他分支一样。内层 @racket[reset] 在语法上不直接与上方的定界符相邻，所以等式 2 不能直接使用。

但考虑动态行为。@racket[(anf0 rator)] 运行时，它执行的每个 @racket[shift] 都会发射 @racket[let] 绑定，包裹剩余部分。等 @racket[r] 绑定好，剩下的工作是 @racket[(reset (let ([d ...]) ...))]，紧挨在它外面的就是来自 @racket[anf1] 的那层 @racket[reset]，两层定界符之间什么也没有了。@xref["03:rules"]{「规约规则」}由两条规约规则得出过 @racket[(reset (reset e))] = @racket[(reset e)]，两层等于一层，内层 @racket[reset] 于是坍缩。

把嵌套的 @racket[let] 改写为内部 @racket[define]，并把 application 推广到任意数量参数（用 @racket[map]），整个变换器变成：

@(define ev-shift (make-acf-eval))
@examples[#:eval ev-shift #:hidden
(require racket/contract/base)
(define ((make-genvar name [n 0]))
  (define var (string->symbol (format "~a.~a" name n)))
  (set! n (add1 n))
  var)]

@examples[#:eval ev-shift #:label #f #:no-prompt
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
  (anf1 exp id))]

三个例子，分别覆盖多参数调用、lambda 和 @racket[if]：

@examples[#:eval ev-shift #:label #f
(anf '(f (g a) (h b)))
(anf '(λ (x) (f (g x))))
(anf '(if (f x) (g a) (h b)))]

与 @tech[#:key "延续传递风格"]{CPS} 版本的 @racket[anf1] 完全相同的逻辑、相同的分支、相同的输出。但没有 @racket[ctx] 参数，没有层层嵌套的 lambda 来传递它。@racket[shift] 恰好在需要的地方捕获@tech{延续}，其余的由宿主自己的栈处理。

@section[#:tag "04:grammar-type"]{文法类型}

@racket[anf0] 的返回类型是什么？有些分支直接返回一个值，另一些调用 @racket[shift]，永远不返回给调用者。答案在 @racket[anf1] 的定义中：@racket[(reset (ctx (anf0 exp)))]。@racket[anf0] 的返回值被传给 @racket[ctx]，所以 @racket[anf0] 的返回类型就是 @racket[ctx] 的参数类型：@racket[_val]。简单情况证实了这一点：字面量、变量、lambda，都是 @racket[_val]。复合情况下，@racket[shift] 的主体越过 @racket[ctx]，把一段 @racket[_anf] 直接交到 @racket[reset] 边界。这是这段局部计算的答案 @math{⊥ᵃ}，成为 @racket[anf1] 的返回值。

@racket[if] 分支把同一个 @racket[ctx] 交给了两个子编译。这样生成的代码，会是什么样？
