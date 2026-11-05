#lang acf/scribble

@title[#:tag "04:2-print"]{打印前沿}

修复在 application 分支。用 @racket[fv] 给中间结果命名，发射一个 @racket[let]，把 @racket[ctx] 放在 @racket[let] 体内部：

@racketblock[
[`(,rator ,rand)
 (define vn (fv))
 (anf1 rator
       (λ (r)
         (anf1 rand
               (λ (d)
                 `(let ([,vn (,r ,d)])
                    ,(ctx vn))))))]]

看 @racket[(ctx vn)] 的位置。第一版里，@racket[ctx] 总在分支的末尾被调用，它的结果就是整个分支的结果；现在它被放进了反引号里，调用的结果成了生成的 @racket[let] 的体。以 @racket[(h (f (g a)))] 为例，编译器处理最内层的 @racket[(g a)] 时，手上的 @racket[ctx] 记着两件还没做的事：把结果交给 @racket[f]，再把 @racket[f] 的结果交给 @racket[h]。调用 @racket[(ctx vn)]，这两件事被写成了 @racket[(g a)] 之后的两层 @racket[let]。程序运行时，@racket[(g a)] 求值完毕后要做的，也正是这两件事。

换一个更小的输入 @racket[(f (g a))]，把编译时与运行时分开列出来：

@racketblock[
(code:comment "编译器处理 (g a) 时手里的 ctx，是编译时的一个闭包：")
(λ (d) `(let ([v.0 (f ,d)]) ,(id 'v.0)))
(code:comment "编译器调用 (ctx 'v.1)，在编译时得到一段代码：")
(let ([v.0 (f v.1)]) v.0)
(code:comment "发射出的目标程序：")
(let ([v.1 (g a)]) (let ([v.0 (f v.1)]) v.0))]

@racket[(ctx 'v.1)] 在编译时执行，只执行这一次，交出的是代码，不是值。这段代码要等到目标程序运行、@racket[(g a)] 算完之后才执行：把结果叫作 @racket[v.1]，交给 @racket[f]，再交出 @racket[f] 的结果。

编译器在这一点的剩余工作，打印出来，就是目标程序在同一点的剩余工作。一边是编译时等着被调用的闭包，一边是它留在纸上的代码，镜子两侧映着同一份剩余工作。这个闭包就是编译器此刻的@tech{前沿}：它记着处理完 @racket[(g a)] 之后，语法树里还要做的那部分工作。

输入 @racket[vn] 是一个 @racket[_var]，更一般地说 @racket[ctx] 始终接收一个 @racket[_val]（变量、字面量或 lambda），因为这些正是 @tech[#:key "A-范式"]{ANF} 代码传给@tech{延续}的值；它交出的是一段 @racket[_anf]。所以 @racket[ctx : _val → _anf]。按@xref["03:local-k"]{「局部延续」}的记法，这是一条@tech{局部延续} @math{¬ₐ⟨@ty{val}⟩}，答案类型 @math{a} 是 @racket[_anf]：编译器这段局部计算的答案，就是生成的代码。@racket[id] 是这里的@tech{局部终结延续} @racket[a->⊥ᵃ]。

对比 @racket[fib/k] 的 @racket[k]，它是 @math{¬ₐ@ty{Natural}}。一个在运行时接收一个数字并计算下一步，另一个在编译时接收一段代码片段并构建目标程序的下一块。

@racket[ctx] 的类型给出了接口，再加上源程序的语义，其余每个分支的写法就定下来了。比如 @racket[if]：无论测试选中哪一支，那一支算出的值都要交给原来等着整个 @racket[if] 的工作，所以两个分支都要用 @racket[ctx] 继续：

@(define ev-anf (make-acf-eval))
@examples[#:eval ev-anf #:hidden
(require racket/contract/base)
(define ((make-genvar name [n 0]))
  (define var (string->symbol (format "~a.~a" name n)))
  (set! n (add1 n))
  var)]

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
  (anf1 exp id))]

字面量、变量和 lambda 本身已经是 @racket[_val]，所以直接传给 @racket[ctx]。Lambda 体用 @racket[id] 编译：每次函数调用分配一个全新的栈。@racket[if] 的测试条件必须是 @racket[_val]，所以先编译它，然后发射 @racket[if]，两个分支都用 @racket[ctx] 继续。@racket[let]/lambda-application 分支做脱糖并发射 @racket[let]，体部用 @racket[ctx] 继续。

@examples[#:eval ev-anf #:label #f
(anf '(h (f (g a))))]

真正的 @tech[#:key "A-范式"]{ANF}。每个中间结果都被命名，@racket[let] 链条使求值顺序显式化：先 @racket[(g a)]，再 @racket[(f v.2)]，最后 @racket[(h v.1)]。

这里依赖 uniquify 的假设。如果没有它，源代码中的绑定器可以遮蔽编译器已经发射到待处理上下文中的名字。例如，@racket[(let ([g 1]) (let ([x (let ([g 2]) g)]) g))] 会编译为 @racket[(let ([g 1]) (let ([g 2]) (let ([x g]) g)))]，求值结果是 @racket[2] 而非 @racket[1]：末尾的 @racket[g] 引用的是外层绑定，但它被发射在内层绑定器的作用域下，被捕获了。

第一版里，擦掉 @racket[ctx] 靠的是它只在尾位置被调用。现在 @racket[ctx] 被放进了生成的代码，@racket[anf1] 的延续参数还能擦掉吗？
