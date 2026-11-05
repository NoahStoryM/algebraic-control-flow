#lang acf/scribble

@title[#:tag "04:6-caller"]{调用者的延续}

出错的例子告诉了我们缺少什么：lambda 体需要知道调用者的延续。

@section[#:tag "04:fix"]{修复}

@racket[if] 分支解决了一个类似的问题。@racket[if] 的两个分支共享与整个 @racket[if] 表达式相同的@tech{延续}。编译器在进入分支之前命名了那个@tech{延续}，两个分支通过名字访问它。

Lambda 的情况类似。如果调用者的@tech{延续}在调用点被命名了，函数体就可以通过同一个名字访问它。区别在于时机：对 @racket[if] 来说，@tech{延续}在编译时就可用，所以一个 @racket[let] 绑定就够了。对 lambda 体来说，@tech{延续}要等到函数被调用时才会到达。所以我们不用 @racket[let]，而用一个@emph{参数}：lambda 把调用者的@tech{延续}作为额外参数，调用点提供它。

Lambda 分支加上 @racket[(λ (k) ...)]：

@racketblock[
(code:comment "之前：")
[`(λ ,x* ,body)
 `(λ ,x* ,(anf1 body id))]
(code:comment "之后：")
[`(λ ,x* ,body)
 (define kn (fk))
 (define ctx0 (reset `(,kn ,(shift k k))))
 `(λ ,x* (λ (,kn) ,(anf1 body ctx0)))]]

现在每个用户定义的 lambda 都产出形如 @racket[(λ (x ...) (λ (k.0) body))] 的代码：它接受参数，然后接受一个@tech{延续}，然后运行主体。主体从 @racket[ctx0] 开始编译，后者在末尾发射 @racket[(k.0 v)]，结果在尾位置交给 @racket[k.0]。而 @racket[k.0] 是调用处提供的剩余工作，一直积累到最近的 @racket[reset]。修正之前，主体从 @racket[id] 开始，函数调用自己就是一条边界；修正之后，主体接着调用者的@tech{局部延续}往下做，函数调用不再定界。

这正是@xref["03:delimited-cps"]{「定界延续与 CPS」}说过的做法：@tech[#:key "延续传递风格"]{CPS} 把栈上的帧搬到堆上的闭包里，宿主栈不再为局部工作保留帧，于是可以承担定界。@racket[k.0] 就是这样的闭包。不同的是，这里只搬用户定义的函数，宿主栈留给了 @racket[reset]。诊断中被等同起来的两种边界，由此分开了。

调用点必须提供它。但不是每个函数都需要@tech{延续}参数。@racket[+] 和 @racket[add1] 这样的内建函数直接计算并返回。只有用户定义的函数接受额外参数。我们把不需要的称为@defterm[#:en "trivial"]{平凡的}，初始集合包含内建原语：

@racketblock[
(define trivial* (mutable-seteq))
(define (trivial? x) (set-member? trivial* x))
(define (add-trivial! x) (set-add! trivial* x))
(for-each add-trivial!
 '(identity values
   display displayln
   zero? add1 sub1
   + - * /
   = < <= > >=
   eq? eqv? equal?))]

除了内建函数之外，@racket[shift] 捕获的@tech{延续}也是平凡的。@xref["03:local-k"]{「局部延续」}已经看到，@tech{局部延续}是普通函数：调用它就执行剩余的局部工作，正常返回结果，用不着另一个@tech{延续}。由于源程序经过了 α-重命名，@racket[k] 是全局唯一的；@racket[fk] 生成的每个 @racket[k.n] 也是如此。所以每个 @racket[shift] 的绑定器和每个@tech{延续}名字在创建时就加入平凡集合：

@racketblock[
[`(shift ,k ,body)
 (add-trivial! k)
 ...]

(define ((make-genvar name [n 0]))
  (define var (string->symbol (format "~a.~a" name n)))
  (when (eq? name 'k) (add-trivial! var))
  (set! n (add1 n))
  var)]

平凡集合现在包含内建函数、@racket[shift] 捕获的@tech{延续}和编译器生成的@tech{延续}名字。它们都直接接收值，不期望@tech{延续}参数。

调用点相应地分裂。平凡调用不需要@tech{延续}参数；用户定义的调用必须传递一个：

@racketblock[
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
   `((,r . ,d*) (λ (,vn) ,(ctx vn))))]]

平凡调用发射 @racket[(let ([,vn (,r . ,d*)]) ,(ctx vn))]，和之前相同的 @tech[#:key "A-范式"]{ANF} @racket[let] 绑定。用户定义的调用发射 @racket[((,r . ,d*) (λ (,vn) ,(ctx vn)))]，传递一个显式的@tech{延续}参数。

再编译那个出错的例子：

@(define ev-caller (make-acf-eval))
@examples[#:eval ev-caller #:hidden
(require (submod acf/zh/04-compiler/code stage-caller))]

@examples[#:eval ev-caller #:label #f
(anf '(reset (let ([f (λ (x) (shift k 999))]) (add1 (f 42)))))]

现在 @racket[f] 接受一个@tech{延续}参数 @racket[k.0]。在调用点，@racket[((f 42) (λ (v.3) ...))] 传递了@tech{局部延续}，其中包含 @racket[add1]。运行时，@racket[shift] 捕获调用点的@tech{延续}（包裹着 @racket[add1]），体返回 @racket[999] 给 @racket[reset] 边界，结果如期是 @racket[999]。

@section[#:tag "04:hybrid"]{混合体}

输出里有两种函数调用：@racket[(let ([v.2 (add1 v.3)]) ...)] 是对 @racket[add1] 的平凡调用，@racket[((f 42) (λ (v.3) ...))] 是对用户定义的 @racket[f] 的调用。输出是一个混合体：一部分是 @tech[#:key "A-范式"]{ANF}，一部分是 @tech[#:key "延续传递风格"]{CPS}。这个混合体是什么意思？

输出是正确的，但噪声很多。到处都是包装器：@racket[(λ (v.1) (k.0 v.1))] 包裹着 @racket[k.0]，@racket[(λ (v.3) (let ([v.2 (add1 v.3)]) v.2))] 包裹着 @racket[add1]。要读懂混合体，先要剥去噪声。

考虑：

@examples[#:eval ev-caller #:label #f
(anf '(λ (n) (f (g n))))]

尾调用是 @racket[((f v.1) (λ (v.0) (k.0 v.0)))]。@tech{延续} @racket[(λ (v.0) (k.0 v.0))] 接受一个值，立即传给 @racket[k.0]。我们之前见过这种包装：为了匹配对应表，我们把 @racket[(anf1 sub ctx)] 包装成 @racket[(anf1 sub (λ (w) (ctx w)))]。那个包装器当时是多余的，现在也是多余的。

把 @racket[(λ (x) (f x))] 替换为 @racket[f]，当 @racket[x] 不出现在 @racket[f] 中。这个化简叫做@defterm[#:en "eta-reduction"]{η-归约}：

@racketblock[
((f v.1) (λ (v.0) (k.0 v.0)))
(code:comment "η => ((f v.1) k.0)")]

尾调用直接传递 @racket[k.0]。不需要包装器。

非尾调用点的@tech{延续}呢？在上面 @racket[999] 的例子中，@racket[f] 的调用点@tech{延续}是 @racket[(λ (v.3) (let ([v.2 (add1 v.3)]) v.2))]。对 @racket[let] 做脱糖：

@racketblock[
(λ (v.3) ((λ (v.2) v.2) (add1 v.3)))]

内层 @racket[((λ (v.2) v.2) (add1 v.3))] 把恒等函数应用到 @racket[(add1 v.3)]。把已知 lambda 应用到其参数上，在 @racket[((λ (x) body) arg)] 中执行 @racket[body[x := arg]]，这是@defterm[#:en "beta-reduction"]{β-归约}：

@racketblock[
((λ (v.2) v.2) (add1 v.3))
(code:comment "β => (add1 v.3)")]

@tech{延续}化简为 @racket[(λ (v.3) (add1 v.3))]，它本身又是一个 η-可归约式：归约为 @racket[add1]。@racket[f] 的调用点@tech{延续}不是一个包裹 @racket[add1] 的 lambda。它@emph{就是} @racket[add1]。

在尾调用处，包装器 @racket[(λ (v.0) (k.0 v.0))] 归约为 @racket[k.0]；在非尾调用处，包装器归约为 @racket[add1]。于是在@tech{延续}参数的位置上，一个是编译器命名的@tech{延续}，一个是内建函数，都接受一个值，把它送往下一步。归约后仍然存活的 @racket[(λ (v) ...)] 也是如此。

@xref["03:local-k"]{「局部延续」}说过，@tech{局部延续}是普通函数。这里看到的是反过来的一面：平凡的普通函数，本身就是@tech{局部延续}。平凡集合原本是「不需要@tech{延续}参数的函数」，从内建原语开始，陆续加入 @racket[shift] 捕获的@tech{延续}和 @racket[fk] 生成的名字，看上去像一个杂烩。β 和 η 剥去管理性的包装之后可以看清，它就是@tech{延续}的集合。混合体的 @tech[#:key "A-范式"]{ANF} 那一半也从来不是没有@tech{延续}的：

@racketblock[
(let ([v (f x)]) body)  =  ((λ (v) body) (f x))]

每个 @racket[let] 都是把一个@tech{延续} @racket[(λ (v) body)] 应用到 @racket[(f x)] 的结果上。编译器没有引入@tech{延续}；它发现了原本就在那里的@tech{延续}。

@section[#:tag "04:two-kinds"]{两种函数}

现在两种函数有了名字。一种接受@tech{延续}参数：这些是用户定义的函数，其主体可能包含 @racket[shift]。另一种@emph{本身就是}@tech{延续}：它接受一个值并传递出去。平凡调用 @racket[(let ([v (add1 x)]) (ctx v))] 就是 @racket[(ctx (add1 x))]，也就是@xref["03:delimited-cps"]{「定界延续与 CPS」}里 @racket[cps] 的展开 @racket[(((cps add1) x) ctx)]：编译器在调用处就地把平凡函数提升成 @tech[#:key "延续传递风格"]{CPS} 箭头。输出中的每次调用，要么是调用一个函数并交给它一个@tech{延续}，要么是把一个@tech{延续}应用到一个值上。这就是 @tech[#:key "延续传递风格"]{CPS}。

文法达到了最终形式：

@out-block|{
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
}|

从扁平的 @tech[#:key "A-范式"]{ANF} 到这里，文法变了三次：@racket[if] 的复制引入了@tech{命名延续}，@racket[reset] 让 @racket[let] 可以绑定一整段 @racket[<anf>]，@racket[shift] 需要穿过函数边界，又让 lambda 接受了@tech{延续}参数。

读 @racket[<cont>] 产生式，它有两个选项：@racket[(λ <head> <cps>)] 或 @racket[<trivial>]。@tech{延续}要么是编译器构造的 lambda，要么是平凡集合中的一个名字。平凡集合从内建原语开始；它增长到包含每个@tech{延续}变量。文法不区分它们，因为 η-归约已经表明它们是同一种东西。

@racket[<apply-cont>] 有两种写法。此前文法里的 @racket[(let ([<var> <anf>]) <anf>)]，对应的正是 @racket[(<cont> <cps>)]：@racket[(let ([v e]) body)] 就是 @racket[((λ (v) body) e)]，一段计算的结果交给了@tech{延续}。另一种 @racket[(<cont> <val> ...)] 是参数都已经是值的调用。

@racket[<cont²>] 产生式 @racket[(λ (<trivial>) <cps>)] 是一个@defterm[#:en "second-order continuation"]{二阶延续}：它以调用者的@tech{延续}为参数，使它成为@tech{延续}的@tech{延续}。它的类型是 @math{(p → a) → a = ¬ₐ¬ₐp}，@xref["03:any-base"]{「换了基的箭头」}的局部编码。@racket[<proc>] 的形状是 @racket[(λ <head> <cont²>)]，接受参数后交出一个 @math{¬ₐ¬ₐ}，正是 @racket[anf1] 那样的 @math{→𝒦ₐ} 箭头：编译器自己的写法，现在也成了目标程序的写法。而 @racket[<apply-cont²>] 不过是一个 @racket[let]，只是绑定的值碰巧是一个@tech{延续}：@racket[((λ (<trivial>) <cps>) <cont>)] = @racket[(let ([<trivial> <cont>]) <cps>)]。绑定本身没有什么特别的；特别的是参数。

β、η 都是我们手工做的；编译器能不能自己做？
