#lang acf/scribble

@title[#:tag "02:5-where"]{箭头指向何方}

嵌入语言写下的都是等待@tech{延续}的计算。宿主里的普通代码要用它们，总得有人交进一条@tech{延续}。

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define-type ⊥ (∪))
(define-type (¬ p ...) (→ p ... ⊥))
(define-type (¬¬ p) (¬ (¬ p)))
(define-type (← q p) (→ p q))
(define-type (→𝒦 p ... q) (→    p ... (¬¬ q)))
(define-type (→𝒰 p ... q) (← (¬ p ...) (¬ q)))
(define ∘ compose)
(define id (∘))
(define (⨾ . f*) (apply ∘ (reverse f*)))
(struct (r) ans ([a* : (Listof r)]) #:type-name Ans)
(define (list->values v*) (apply values v*))
(define (a->⊥ . a*) (raise (ans a*)))
(define-syntax-rule (⊥->a exp)
  (with-handlers ([ans? (∘ list->values ans-a*)]) exp))
(define (((cps f) . p*) kq) (kq (apply f p*)))
(define ((neg f) kq) (∘ kq f))
(define (((flip f) . y*) . x*) (apply (apply f x*) y*))
(define cps:id (cps id))
(define neg:id id)
(define-type (→𝒟 p ... q) (→ p ... q))
(define ((cps:call/cc cps:proc) kp) ((cps:proc (cps kp)) kp))
(define ((neg:call/cc kp) neg:proc) ((neg:proc kp) (neg kp)))
(define-syntax-rule (anf:let ([v e]) b)
  (λ (k) (e (λ (v) (b k)))))
(define-syntax anf:let*
  (syntax-rules ()
    [(_ () b) b]
    [(_ ([v e] [v* e*] ...) b)
     (anf:let ([v e]) (anf:let* ([v* e*] ...) b))]))
(define-syntax-rule (anf:if test conseq alt)
  (λ (k) (test (λ (b) ((if b conseq alt) k)))))
(define-syntax-rule (anf:let/cc cps:k b* ...)
  (cps:call/cc (λ (cps:k) b* ...)))
(define (anf:eval kka) (⊥->a (kka a->⊥)))
(define cps:*     (cps *))
(define cps:zero? (cps zero?))
(define cps:car   (cps car))
(define cps:cdr   (cps cdr))
(define cps:null? (cps null?))
(define (cps:mul . r*)
  (anf:let/cc cps:return
    (define (cps:loop r*)
      (anf:if (cps:null? r*)
              (cps:*)
              (anf:let* ([r (cps:car r*)])
                (anf:if (cps:zero? r)
                        (cps:return r)
                        (anf:let* ([r* (cps:cdr r*)]
                                   [res (cps:loop r*)])
                          (cps:* res r))))))
    (cps:loop r*)))]

@section[#:tag "02:back-to-host"]{回到宿主}

回到宿主，就是把@tech{延续}参数填上。@racket[anf:eval] 填的是@tech{终结延续} @racket[a->⊥]，@xref["02:early-return"]{「提前返回」}就是这样运行 @racket[cps:mul] 的。这回把它放进一个普通的宿主表达式里：

@examples[#:eval ev #:label #f
(+ 1 (anf:eval (cps:mul 1 2 3 4)))
(+ 1 (anf:eval (cps:mul 1 2 0 3 4)))]

两条路都回到了 @racket[(+ 1 _)]。@racket[a->⊥] 一调用就 @racket[raise]，是外面那层 @racket[⊥->a] 的 handler 接住答案，交回调用处，加 1 接着做。@racket[anf:eval] 没有捕获调用处的@tech{延续}，是借 @racket[raise] 与 handler 把答案送回来的。

宿主若有 @racket[call/cc]，就能直接捕获当前@tech{延续}，填进编码的@tech{延续}参数：

@examples[#:eval ev #:label #f #:no-prompt
(: uncps (∀ (p q) (→ (→𝒦 p q) (→𝒟 p q))))
(define (uncps cps:f) (∘ call/cc cps:f))]

@racket[((uncps cps:f) x)] 先算出 @racket[(cps:f x)]，一段等待@tech{延续}的计算，再交给 @racket[call/cc]，@racket[call/cc] 把当前@tech{延续}交给它。@racket[uncps] 收 @tech{CPS 箭头}，交出@tech{宿主箭头}，也就是一个普通的宿主函数，可以放进同一个 @racket[(+ 1 _)]：

@examples[#:eval ev #:label #f
(+ 1 ((uncps cps:mul) 1 2 3 4))
(+ 1 ((uncps cps:mul) 1 2 0 3 4))]

结果和 @racket[anf:eval] 那两行一样，这回却没有 handler 去接：正常乘完的 @racket[24]，和遇零从 @racket[cps:return] 跳出来的 @racket[0]，交给的都是 @racket[call/cc] 填进去的那条@tech{延续}本身，也就是 @racket[(+ 1 _)]。@xref["02:k-in-hand"]{「手中的延续」}在编码里实现 @racket[call/cc]，把当前@tech{延续}交给程序；这里用宿主的 @racket[call/cc] 运行编码，把当前@tech{延续}交进编码。

宿主函数经 @racket[cps] 提升，再经 @racket[uncps] 放回，还是原来那个吗？对纯函数 @racket[f]，展开看：

@racketblock[
((uncps (cps f)) . p*)  =  (call/cc ((cps f) . p*))
                        =  (call/cc (λ (kq) (kq (f . p*))))
                        =  (f . p*)]

第三步用的是@xref["01:call-cc-types"]{「call/cc 的几种类型」}里的道理：@racket[proc] 正常返回，走的也正是交给它的那条@tech{延续}，只是没有写出来。这里反过来，@racket[(kq …)] 处在尾位置，@racket[kq] 就是调用 @racket[call/cc] 这一处的当前@tech{延续}，显式调用它和直接返回 @racket[(f . p*)] 汇入同一个出口。提起来再放回去，还是原来的函数。

@section[#:tag "02:three-forms"]{三种写法}

反过来呢？一支 @tech{CPS 箭头}先经 @racket[uncps] 运行回宿主，再经 @racket[cps] 提升，还是原来那支吗？交给它输入 @racket[x] 和@tech{延续} @racket[kq]，展开：

@racketblock[
#,(hspace 2)(((cps (uncps cps:f)) x) kq)
= (kq ((uncps cps:f) x))
= (kq (call/cc (cps:f x)))
≈ ((cps:f x) kq)]

前两步照定义展开。最后一步换成了@defsym["a ≈ b" "行为相同，前提比 = 多，见「三种写法」的旁注"] @racket[≈]，用的是 @racket[call/cc] 的一条规律：

@racketblock[
#,(hspace 2)(let ([p (call/cc kkp)]) (kp p))
= (kp (call/cc kkp))
≈ (kkp kp)]

@margin-note{@racket[=] 只是照定义展开，用到的前提只有「两层参数之间不做别的事」；@racket[≈] 说的是行为相同，前提比 @racket[=] 多。@racket[kp] 和 @racket[kkp] 都要遵守结果为 @math{⊥} 的约定，调用以后不向当前调用处正常返回：@racket[kp] 若正常返回，捕获的@tech{延续}还会接着做 @racket[(kp p)] 之后的事；@racket[kkp] 若正常交回一个值，左边会把它交给 @racket[kp]，右边却直接返回。@racket[kkp] 也不能借助异常处理器这类动态的控制环境，否则直接调用与经过捕获的@tech{延续}，所处的环境不同。函数和@tech{延续}只通过调用来使用。在这些约定下，行为相同也包括把它们放进本章的调用、绑定和复合中使用。}

@racket[call/cc] 捕获的，是收到 @racket[p] 以后交给 @racket[kp] 这件剩下的工作。@racket[kp] 若是一条真正的@tech{延续}，交出去就不再回来，捕获到的就和 @racket[kp] 一样。把它交给 @racket[kkp]，和直接把 @racket[kp] 交给 @racket[kkp]，行为相同。


两个方向都回到原处：@tech{宿主箭头}经 @racket[cps] 变成 @tech{CPS 箭头}，@tech{CPS 箭头}经 @racket[uncps] 变回@tech{宿主箭头}，来回什么也不丢。@tech{逆否箭头}和 @tech{CPS 箭头}之间，@racket[flip] 也是来回什么也不丢。把这几种转换画在一起，箭头的种类记在顶点上（𝒟、𝒰、𝒦 分别指@tech{宿主箭头}、@tech{逆否箭头}、@tech{CPS 箭头}），转换标在边上，就是一张@defterm[#:en "diagram"]{图表}：

@out-block|{ 𝒟 ←───────────┐
 │             │
neg          uncps
 │             │
 ↓             │
 𝒰 ───flip───→ 𝒦}|

从 𝒟 出发，经 @racket[neg]、@racket[flip] 到 𝒦，就是 @c{cps = (∘ flip neg)}；再经 @racket[uncps] 回到 𝒟，得到的还是原来的箭头。从 𝒦 出发，经 @racket[uncps] 回到 𝒟，再经 @racket[neg] 走到 𝒰，得到的是什么？展开只用到上面那条规律：

@racketblock[
#,(hspace 2)(((neg (uncps cps:f)) kq) x)
= (kq ((uncps cps:f) x))
= (kq (call/cc (cps:f x)))
≈ ((cps:f x) kq)
= (((flip cps:f) kq) x)]

@racket[(neg (uncps cps:f))] 与 @racket[(flip cps:f)] 行为相同：@racket[flip] 从 𝒦 到 𝒰 的那个方向，就是 @racket[(∘ neg uncps)]，和 @c{cps = (∘ flip neg)} 正好对称。三条边绕成一个圈，从哪一处出发绕一圈，都回到原来的箭头；从一处沿不同的路径走到另一处，结果也都一样。图表有这种性质，就说它是@defterm[#:en "commutative"]{交换}的，叫作@defterm[#:en "commutative diagram"]{交换图表}。

所以每条边都能由另外两条倒回去：@racket[uncps] 由 @racket[cps] 倒回，@racket[flip] 由 @racket[(∘ neg uncps)] 倒回。@racket[neg] 由 @racket[(∘ uncps flip)] 倒回，从 𝒰 回到 𝒟 本来没有直接的一条边，这一支撤销 @racket[neg]，记作 @racket[unneg]：

@examples[#:eval ev #:label #f #:no-prompt
(: unneg (∀ (p q) (→ (→𝒰 p q) (→𝒟 p q))))
(define unneg (∘ uncps flip))]

@margin-note{这里的同构只就本章的@tech{延续}编码、在 @racket[≈] 的意义下说，@racket[uncps] 还要靠宿主的 @racket[call/cc] 才写得出来；并不是任意具有这些类型的 Racket 函数都这样。}

在 @racket[≈] 的意义下，三种写法是@defterm[#:en "isomorphic"]{同构}的：同一组箭头的三种写法。

@section[#:tag "02:count-k"]{数一数 k}

名字里的 @racket[k] 一直在数否定的层数，@xref["01:layers"]{「否定塔」}数过：@racket[kv] 等 @racket[v]，@racket[kkv] 等 @racket[kv]，多一层的正好接收少一层的。那里的几条规则，在这一章里都有了现成的写法。

DNI 加两层，在这里就是 @racket[cps:id]：收下 @racket[p]，等一条 @racket[kp] 来，再把 @racket[p] 交给它。@xref["02:cps"]{「延续与 CPS」}开头那串等式，把 @racket[(k e)] 改写成 @racket[((λ (k) (k e)) (λ (v) b))]，做的就是这一步。交来的若正是 @racket[(cps:id p)]，把 @racket[kp] 交给它，照定义一步就回到原处：

@racketblock[
#,(hspace 2)(let ([kkp (cps:id p)]) (kkp kp))
= (kp p)]

手里的 @racket[kkp] 若是随便一段计算，就不能这样拆开。@xref["02:three-forms"]{「三种写法」}那条规律倒过来读，从 @racket[(kkp kp)] 走到 @racket[(kp p)]，中间要 @racket[call/cc]，也就是 DNE，减两层，落到第 0 层：

@racketblock[
#,(hspace 2)(kkp kp)
≈ (kp (call/cc kkp))
= (let ([p (call/cc kkp)]) (kp p))]

这一步用的是那里的 @racket[≈]，前提也照样要。

减两层而不落到第 0 层，用@tech{三重否定律}就够了，不必 @racket[call/cc]。它在这里也有现成的写法，就是 DNI 的逆否 @racket[(neg cps:id)]：

@racketblock[
(((neg cps:id) kkkp) p)  =  (kkkp (cps:id p))]

收下第 3 层的 @racket[kkkp]，交出第 1 层：等 @racket[p] 来了，把它升两层交给 @racket[kkkp]，和@xref["01:neg-q"]{「代入 ¬q」}里的 @racket[triple-negation] 做的一样。第 0 层仍是例外：对任意类型，没有纯的写法落到那里。

@section[#:tag "02:same-arrow"]{同一支箭头}

@xref["02:clavius"]{「Clavius 律」}有了 @racket[cps:call/cc] 和 @racket[neg:call/cc]。照名字的约定，@racket[cps:car] 就是 @racket[(cps car)]；@racket[cps:call/cc] 却不是 @racket[(cps call/cc)]，它是整条 @tech{Clavius 律}换写出来的，@racket[proc] 也换成了新的箭头。那 @racket[(cps call/cc)] 和 @racket[(neg call/cc)] 又是什么？

不换写定律，只把箭头搬过去。宿主的 @racket[call/cc] 照 DNE 来读，是一支@tech{宿主箭头} @math{¬¬p →@subscript{𝒟} p}：收下第 2 层的 @racket[kkp]，交出第 0 层的值。

先看 @tech{CPS 箭头}。交给 @racket[(cps call/cc)] 一段 @racket[kkp] 和@tech{延续} @racket[kp]，用@xref["02:three-forms"]{「三种写法」}那条规律：

@racketblock[
#,(hspace 2)(((cps call/cc) kkp) kp)
= (kp (call/cc kkp))
= (let ([p (call/cc kkp)]) (kp p))
≈ (kkp kp)]

收下 @racket[kkp]，把@tech{延续} @racket[kp] 原样交给它：这支箭头什么也不运行，收下一段计算，原样交出。代码和 @racket[id] 一样，类型却是一支 @tech{CPS 箭头}：从 @math{¬¬p} 到 @math{p}。这和@xref["02:via-contrapositive"]{「借道逆否复合」}里的 @racket[neg:id] 是同一种情形：定义相同，箭头的种类不同。记作 @racket[neg²:id]：

@examples[#:eval ev #:label #f #:no-prompt
(: neg²:id (∀ (p) (→𝒦 (¬¬ p) p)))
(define (neg²:id kkp) kkp)]

于是上面那段展开说的是：

@racketblock[
(cps call/cc)  ≈  neg²:id]

@math{¬¬p →@subscript{𝒦} p} 看上去也像 DNE；展开到宿主，它只是 @math{¬¬p → ¬¬p}，从第 2 层到第 2 层。名字照前缀的约定读：@racket[neg²] 指连用两次 @racket[neg]，@racket[neg²:id] 就是 @racket[(neg (neg id))]，也就是 @racket[(neg neg:id)]。验证一下：@racket[(neg neg:id)] 收下 @racket[kkp]，交出 @racket[(∘ kkp id)]，行为和 @racket[kkp] 一样。反过来，把它交给 @racket[uncps]，沿图表回到宿主，得到的正是 @racket[call/cc]：

@racketblock[
(uncps neg²:id)  ≈  (uncps (cps call/cc))  =  call/cc]

后一步是@xref["02:back-to-host"]{「回到宿主」}里的往返，那里的论证只用到 @racket[(kq …)] 处在尾位置。直接展开也一样，@racket[(uncps neg²:id)] 就是 @racket[(∘ call/cc neg²:id)]，也就是 @racket[call/cc]：工作来自 @racket[uncps] 里已有的 @racket[call/cc]，不是 @racket[neg²:id] 自己捕获了什么。

到这里，从 @racket[id] 造出的已经有四支。它们都从 @racket[id] 造出，箭头的种类与展开后的层数各不相同：

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list @elem{名字} @elem{由 @racket[id] 造出} @elem{箭头} @elem{展开到宿主} @elem{层数})
   (list @racket[id] @elem{} @elem{@math{p →@subscript{𝒟} p}} @elem{@math{p → p}} @elem{0 → 0})
   (list @racket[neg:id] @racket[(neg id)] @elem{@math{p →@subscript{𝒰} p}} @elem{@math{¬p → ¬p}} @elem{1 → 1})
   (list @racket[cps:id] @racket[(cps id)] @elem{@math{p →@subscript{𝒦} p}} @elem{@math{p → ¬¬p}} @elem{0 → 2})
   (list @racket[neg²:id] @racket[(neg neg:id)] @elem{@math{¬¬p →@subscript{𝒦} p}} @elem{@math{¬¬p → ¬¬p}} @elem{2 → 2}))]

再看@tech{逆否箭头}：

@racketblock[
#,(hspace 2)(((neg call/cc) kp) kkp)
= (kp (call/cc kkp))
= (let ([p (call/cc kkp)]) (kp p))
≈ (kkp kp)
= ((cps:id kp) kkp)]

@racket[(neg call/cc)] 收下第 1 层的 @racket[kp]，交出第 3 层：它就是用在 @math{¬p} 上的 @racket[cps:id]，多两层。@racket[neg:id] 就是 @racket[id]，所以它也是 @racket[(cps neg:id)]。宿主里 2 → 0 的这一步，换成 @tech{CPS 箭头}是 2 → 2，换成@tech{逆否箭头}是 1 → 3，接口一变，都不再落到第 0 层。@racket[(cps call/cc)] 和 @racket[(neg call/cc)] 搬的是 DNE 这一支箭头，和换写整条 @tech{Clavius 律}得到的 @racket[cps:call/cc]、@racket[neg:call/cc] 是两回事。

@racket[uncps] 回到宿主，靠的是 @racket[call/cc]。不用它，这些箭头能不能落到纯的宿主函数？
