#lang acf/scribble

@title[#:tag "02:3-translation"]{经典的控制去了哪里}

两种写法都只用 @racket[λ] 和函数调用，却做着第一篇要靠捕获才做得到的事。照第一篇的办法，把这些类型读成命题，看看它们说了什么。

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define-type ⊥ (∪))
(define-type (¬ p) (→ p ⊥))
(define-type (¬¬ p) (¬ (¬ p)))
(define-type (← q p) (→ p q))
(define-type (→𝒦 p q) (→    p (¬¬ q)))
(define-type (→𝒰 p q) (← (¬ p) (¬ q)))
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

@section[#:tag "02:propositions"]{读出命题}

第一篇的 @racket[call/cc] 要靠宿主捕获@tech{延续}；@xref["02:k-in-hand"]{「手中的延续」}里的 @racket[cps:call/cc] 却只用了 @racket[λ] 和函数调用，什么也没有捕获。两者做的是同一件事：把当前@tech{延续}交给 @racket[proc]。它们究竟是同一个什么？@xref["01:call-cc-types"]{「call/cc 的几种类型」}把 @racket[call/cc] 的类型读成了命题，其中一种是 @tech{Clavius 律}。照这个办法，把这一篇写下的类型也读成命题。

先读最早的两个。@racket[neg] 和 @racket[cps] 的类型，按照 Curry-Howard 对应，是两条直觉主义定理：

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list @elem{命题} @elem{定理})
   (list @elem{@math{(p → q) → (¬q → ¬p)}}
         @elem{@defterm[#:en "law of contraposition"]{逆否律}})
   (list @elem{@math{(p → q) → (p → ¬¬q)}}
         @elem{DNI 的推广形式}))]

用在 @racket[id] 上，@racket[cps:id] 的类型就是 @math{p → ¬¬p}，第一篇的 DNI 本身。@racket[flip] 的两行读法 @math{(¬q → ¬p) → (p → ¬¬q)} 和 @math{(p → ¬¬q) → (¬q → ¬p)}，也都是直觉主义定理。

两种新箭头有了名字，宿主里普通的函数也给一个，叫@defterm[#:en "host arrow"]{宿主箭头}，记作 @math{→@subscript{𝒞}}，好和它们并排：

@examples[#:eval ev #:label #f #:no-prompt
(define-type (→𝒞 p q) (→ p q))]

三种箭头，各是一种命题形状：

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list @elem{箭头} @elem{类型})
   (list @elem{宿主箭头} @elem{@math{p →@subscript{𝒞} q = p → q}})
   (list @elem{CPS 箭头} @elem{@math{p →@subscript{𝒦} q = p → ¬¬q}})
   (list @elem{逆否箭头} @elem{@math{p →@subscript{𝒰} q = ¬q → ¬p}}))]

@subsection[#:tag "02:clavius"]{新箭头下的 Clavius 律}

回到那个问题。两个新 @racket[call/cc] 的类型，可以从定义里读出来。拿 @racket[cps:call/cc] 来看。把它交出的结果的类型记作 @racket[p]。@racket[kp] 是这次调用的当前@tech{延续}，等的就是这个结果，类型是 @racket[(¬ p)]。@racket[cps] 把它提升成 @racket[(→𝒦 p ⊥)]，这是用 @tech{CPS 箭头}写的否定，记作 @racket[¬𝒦]；用@tech{逆否箭头}写的否定同样记作 @racket[¬𝒰]：

@examples[#:eval ev #:label #f #:no-prompt
(define-type (¬𝒦 p) (→𝒦 p ⊥))
(define-type (¬𝒰 p) (→𝒰 p ⊥))]

@racket[cps:proc] 收到的是 @racket[(¬𝒦 p)]；它交回的计算又交给了 @racket[kp]，所以是 @racket[(¬¬ p)]。@racket[cps:proc] 因此是 @racket[(→𝒦 (¬𝒦 p) p)]。@racket[cps:call/cc] 先收 @racket[cps:proc]，再收 @racket[kp]，结果是 @racket[⊥]，它的类型就出来了。@racket[neg:call/cc] 同理：

@examples[#:eval ev #:label #f #:no-prompt
(: cps:call/cc (∀ (p) (→𝒦 (→𝒦 (¬𝒦 p) p) p)))
(: neg:call/cc (∀ (p) (→𝒰 (→𝒰 (¬𝒰 p) p) p)))]

@bold{练习}：照推出 @racket[cps:call/cc] 类型的办法，推出 @racket[neg:call/cc] 的类型：@racket[kp] 仍是 @racket[(¬ p)]，留意 @racket[neg:proc] 先收的是哪一个。@racket[(neg kp)] 的类型是 @math{¬⊥ → ¬p}，也就是 @racket[(¬𝒰 p)]。

把宿主 𝒞 里的否定记作 @racket[¬𝒞]，第一篇的 @racket[call/cc] 的类型是：

@examples[#:eval ev #:label #f #:no-prompt
(define-type (¬𝒞 p) (→𝒞 p ⊥))

(: call/cc (∀ (p) (→𝒞 (→𝒞 (¬𝒞 p) p) p)))]

读作 @math{(¬p → p) → p}，@tech{Clavius 律}。两个新 @racket[call/cc] 的类型是同一条定律，只是 @math{→@subscript{𝒞}} 换成了 @math{→@subscript{𝒦}}、@math{→@subscript{𝒰}}：它们是 @tech{Clavius 律}用这两种箭头写出来的样子。

可@xref["01:watershed"]{「分水岭」}说过：@racket[call/cc] 要先凭空造出一个 @math{¬p} 交给 @racket[proc]，只用 @racket[λ] 和函数调用写不出来，必须捕获。@racket[cps:call/cc] 却只用了 @racket[λ]。把 @math{→@subscript{𝒦}} 展开成宿主的箭头：

@mm{(¬@subscript{𝒦} p →@subscript{𝒦} p) →@subscript{𝒦} p = (¬@subscript{𝒦} p → ¬¬p) → ¬p → ⊥}

@math{¬p} 在箭头左边，是参数，就是 @racket[kp]。宿主的 @tech{Clavius 律}只收 @racket[proc] 一个输入，手里没有否定，只能凭空去造；用 @tech{CPS 箭头}写，这个否定作为参数交了进来。交给 @racket[cps:proc] 的 @math{¬@subscript{𝒦} p}，是 @racket[cps] 从 @racket[kp] 加工出来的。

这个 @math{¬@subscript{𝒦} p} 能不能凭空造出来？@math{¬@subscript{𝒦} p} 展开是 @math{p → ¬¬⊥}；手里若有一个 @math{¬¬⊥} 的值，把类型为 @math{⊥ → ⊥} 的 @racket[id] 交给它，就得到 @math{⊥} 的值，所以 @math{¬¬⊥} 和 @math{⊥} 一样空。对非空的 @math{p}，同样凭空造不出 @math{¬@subscript{𝒦} p}。

@racket[cps:call/cc] 做的，是@xref["01:watershed"]{「分水岭」}构造性那一侧的事：消耗交到手里的否定。

所以展开后的这条公式，已经不是宿主里的 @tech{Clavius 律}，而是一条直觉主义定理：按照 Curry-Howard，它有闭合的、有类型的纯 @racket[λ] 项，就是 @racket[cps:call/cc]。@racket[neg:call/cc] 也一样。同一条经典定律，换用 @tech{CPS 箭头}或@tech{逆否箭头}来写，就成了直觉主义定理。经典的控制并没有消失，宿主要捕获的那条@tech{延续}，成了显式的参数。

@section[#:tag "02:where"]{箭头指向何方}

三种箭头之间，@racket[cps] 和 @racket[neg] 都从宿主出发，@racket[flip] 在后两种之间来回。还缺一个方向：嵌入语言写出的 @tech{CPS 箭头}，怎样回到宿主？

@subsection[#:tag "02:back-to-host"]{回到宿主}

回到宿主，就是把@tech{延续}参数填上。@racket[anf:eval] 填的是@tech{终结延续} @racket[a->⊥]，@xref["02:early-return"]{「提前返回」}就是这样运行 @racket[cps:mul] 的。这回把它放进一个普通的宿主表达式里：

@examples[#:eval ev #:label #f
(+ 1 (anf:eval (cps:mul 1 2 3 4)))
(+ 1 (anf:eval (cps:mul 1 2 0 3 4)))]

两条路都回到了 @racket[(+ 1 _)]。@racket[a->⊥] 一调用就 @racket[raise]，是外面那层 @racket[⊥->a] 的 handler 接住答案，交回调用处，加 1 接着做。@racket[anf:eval] 没有捕获调用处的@tech{延续}，是借 @racket[raise] 与 handler 把答案送回来的。

宿主若有 @racket[call/cc]，就能直接捕获当前@tech{延续}，填进编码的@tech{延续}参数：

@examples[#:eval ev #:label #f #:no-prompt
(: uncps (∀ (p q) (→ (→𝒦 p q) (→𝒞 p q))))
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

@subsection[#:tag "02:three-forms"]{三种写法}

反过来呢？一支 @tech{CPS 箭头}先经 @racket[uncps] 运行回宿主，再经 @racket[cps] 提升，还是原来那支吗？交给它输入 @racket[x] 和@tech{延续} @racket[kq]，展开：

@racketblock[
#,(hspace 2)(((cps (uncps cps:f)) x) kq)
= (kq ((uncps cps:f) x))
= (kq (call/cc (cps:f x)))
≈ ((cps:f x) kq)]

前两步照定义展开。最后一步换成了 @racket[≈]，用的是 @racket[call/cc] 的一条规律：

@racketblock[
#,(hspace 2)(let ([p (call/cc kkp)]) (kp p))
= (kp (call/cc kkp))
≈ (kkp kp)]

@margin-note{@racket[≈] 说的是行为相同，前提比 @racket[=] 多。@racket[kp] 得是交出去就不再回来的@tech{延续}；它若正常返回，捕获的@tech{延续}还会接着做 @racket[(kp p)] 之后的事。@racket[kkp] 也不能观察或改变动态的控制环境：它若先装上一个异常处理器，再调用 @racket[kp]，直接调用时还在处理器里面，捕获的@tech{延续}却会先离开它，两边就不同了；@racket[dynamic-wind] 同样分辨得出。这里的等式只比较这一篇的@tech{延续}编码，不考虑这类程序，@tech{终结延续}由外面的运行边界提供。@xref["02:split-k"]{「把延续独立出来」}的前提也照样要：两层参数之间不做别的事。}

@racket[call/cc] 捕获的，是收到 @racket[p] 以后交给 @racket[kp] 这件剩下的工作。@racket[kp] 若是一条真正的@tech{延续}，交出去就不再回来，捕获到的就和 @racket[kp] 一样。把它交给 @racket[kkp]，和直接把 @racket[kp] 交给 @racket[kkp]，行为相同。


两个方向都回到原处：@tech{宿主箭头}经 @racket[cps] 变成 @tech{CPS 箭头}，@tech{CPS 箭头}经 @racket[uncps] 变回@tech{宿主箭头}，来回什么也不丢。@tech{逆否箭头}和 @tech{CPS 箭头}之间，@racket[flip] 也是来回什么也不丢。把这几种转换画在一起，箭头的种类记在顶点上，转换标在边上，就是一张@defterm[#:en "diagram"]{图表}：

@out-block|{ 𝒞 ←───────────┐
 │             │
neg          uncps
 │             │
 ↓             │
 𝒰 ───flip───→ 𝒦}|

从 𝒞 出发，经 @racket[neg]、@racket[flip] 到 𝒦，就是 @c{cps = (∘ flip neg)}；再经 @racket[uncps] 回到 𝒞，得到的还是原来的箭头。从 𝒦 出发，经 @racket[uncps] 回到 𝒞，再经 @racket[neg] 走到 𝒰，得到的是什么？展开只用到上面那条规律：

@racketblock[
#,(hspace 2)(((neg (uncps cps:f)) kq) x)
= (kq ((uncps cps:f) x))
= (kq (call/cc (cps:f x)))
≈ ((cps:f x) kq)
= (((flip cps:f) kq) x)]

@racket[(neg (uncps cps:f))] 与 @racket[(flip cps:f)] 行为相同：@racket[flip] 从 𝒦 到 𝒰 的那个方向，就是 @racket[(∘ neg uncps)]，和 @c{cps = (∘ flip neg)} 正好对称。三条边绕成一个圈，从哪一处出发绕一圈，都回到原来的箭头；从一处沿不同的路径走到另一处，结果也都一样。图表有这种性质，就说它是@defterm[#:en "commutative"]{交换}的，叫作@defterm[#:en "commutative diagram"]{交换图表}。

所以每条边都能由另外两条倒回去：@racket[uncps] 由 @racket[cps] 倒回，@racket[flip] 由 @racket[(∘ neg uncps)] 倒回。@racket[neg] 由 @racket[(∘ uncps flip)] 倒回，从 𝒰 回到 𝒞 本来没有直接的一条边，这一支记作 @racket[unneg]：

@examples[#:eval ev #:label #f #:no-prompt
(: unneg (∀ (p q) (→ (→𝒰 p q) (→𝒞 p q))))
(define unneg (∘ uncps flip))]

在 @racket[≈] 的意义下，三种写法是@defterm[#:en "isomorphic"]{同构}的：同一组箭头的三种写法。

@subsection[#:tag "02:count-k"]{数一数 k}

名字里的 @racket[k] 一直在数否定的层数，@xref["01:layers"]{「否定塔」}数过：@racket[kv] 等 @racket[v]，@racket[kkv] 等 @racket[kv]，多一层的正好接收少一层的。那里的几条规则，在这一篇里都有了现成的写法。

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

@subsection[#:tag "02:same-arrow"]{同一支箭头}

@xref["02:clavius"]{「新箭头下的 Clavius 律」}有了 @racket[cps:call/cc] 和 @racket[neg:call/cc]。照名字的约定，@racket[cps:car] 就是 @racket[(cps car)]；@racket[cps:call/cc] 却不是 @racket[(cps call/cc)]，它是整条 @tech{Clavius 律}换写出来的，@racket[proc] 也换成了新的箭头。那 @racket[(cps call/cc)] 和 @racket[(neg call/cc)] 又是什么？

不换写定律，只把箭头搬过去。宿主的 @racket[call/cc] 照 DNE 来读，是一支@tech{宿主箭头} @math{¬¬p →@subscript{𝒞} p}：收下第 2 层的 @racket[kkp]，交出第 0 层的值。

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

@math{¬¬p →@subscript{𝒦} p} 看上去也像 DNE；展开到宿主，它只是 @math{¬¬p → ¬¬p}，从第 2 层到第 2 层。名字里的 @racket[neg²] 也有来由：@racket[(neg neg:id)] 收下 @racket[kkp]，交出 @racket[(∘ kkp id)]，行为和 @racket[kkp] 一样，所以 @racket[neg²:id] 就是 @racket[(neg neg:id)]。反过来，把它交给 @racket[uncps]，沿图表回到宿主，得到的正是 @racket[call/cc]：

@racketblock[
(uncps neg²:id)  ≈  (uncps (cps call/cc))  =  call/cc]

后一步是@xref["02:back-to-host"]{「回到宿主」}里的往返，那里的论证只用到 @racket[(kq …)] 处在尾位置。直接展开也一样，@racket[(uncps neg²:id)] 就是 @racket[(∘ call/cc neg²:id)]，也就是 @racket[call/cc]：工作来自 @racket[uncps] 里已有的 @racket[call/cc]，不是 @racket[neg²:id] 自己捕获了什么。

再看@tech{逆否箭头}：

@racketblock[
#,(hspace 2)(((neg call/cc) kp) kkp)
= (kp (call/cc kkp))
= (let ([p (call/cc kkp)]) (kp p))
≈ (kkp kp)
= ((cps:id kp) kkp)]

@racket[(neg call/cc)] 收下第 1 层的 @racket[kp]，交出第 3 层：它就是用在 @math{¬p} 上的 @racket[cps:id]，多两层。@racket[neg:id] 就是 @racket[id]，所以它也是 @racket[(cps neg:id)]。宿主里 2 → 0 的这一步，换成 @tech{CPS 箭头}是 2 → 2，换成@tech{逆否箭头}是 1 → 3，接口一变，都不再落到第 0 层。@racket[(cps call/cc)] 和 @racket[(neg call/cc)] 搬的是 DNE 这一支箭头，和换写整条 @tech{Clavius 律}得到的 @racket[cps:call/cc]、@racket[neg:call/cc] 是两回事。

@section[#:tag "02:negative-translation"]{否定翻译}

@xref["02:back-to-host"]{「回到宿主」}的 @racket[uncps] 把 @tech{CPS 箭头}变成宿主函数，里面用的是 @racket[call/cc]。宿主函数有两类：有的会跳转、会输出，像 @racket[call/cc]、@racket[raise]、@racket[exit]、@racket[display]；有的在合法输入上总会返回，没有可观察的副作用。全部宿主函数记作 𝒞，后一类叫纯函数，记作 𝒟；作为参数交进来的函数，也要是纯的。两类的类型都是普通的函数类型，区别只在函数怎么写，类型检查不出来。纯函数也是宿主函数，@racket[inj] 把它原样放进 𝒞：

@examples[#:eval ev #:label #f #:no-prompt
(define-type (→𝒟 p q) (→ p q))

(: inj (∀ (p q) (→ (→𝒟 p q) (→𝒞 p q))))
(define (inj f) f)]

不用 @racket[call/cc]，能不能把两种箭头变成纯的宿主函数，而且像宿主函数一样，用 @racket[∘] 从 @math{p} 接到 @math{q}？把类型展开看看。@tech{逆否箭头} @math{p →@subscript{𝒰} q} 是 @math{¬q → ¬p}，本身就是宿主函数，只是方向反了：从 @math{p} 写到 @math{q}，函数却从 @math{¬q} 指向 @math{¬p}。@tech{CPS 箭头} @math{p →@subscript{𝒦} q} 是 @math{p → ¬¬q}，两端对不上：一支交出的是 @math{¬¬q}，下一支要收的是 @math{q}。

两端对得上的，前面倒见过一支：@racket[neg²:id]。展开到宿主，它是 @math{¬¬p → ¬¬p}，从第 2 层到第 2 层。@xref["02:same-arrow"]{「同一支箭头」}还认出，它就是 @racket[(neg neg:id)]：@tech{逆否箭头}的恒等，再用一次 @racket[neg]。

@subsection[#:tag "02:neg-again"]{再用一次 neg}

@tech{逆否箭头}既然反了一次，就再反一次。交给 @racket[neg] 一支@tech{逆否箭头} @racket[neg:f]，得到的 @racket[(neg neg:f)] 是 @math{¬¬p → ¬¬q}：方向正了，两端都裹着 @math{¬¬}，宿主的 @racket[∘] 就能接。它只在@tech{延续}前面接上 @racket[neg:f]：@racket[neg:f] 是纯的，它也是纯的，落在 𝒟 里。落到的却不是原来那支箭头，@math{p} 换成了 @math{¬¬p}。

@racket[neg] 的两种读法，写进同一个 @racket[case→]，第二种读法落在 𝒟 里：

@examples[#:eval ev #:label #f #:no-prompt
(: neg
   (∀ (p q)
      (case→ (→ (→𝒞 p q) (→𝒰     p      q))
             (→ (→𝒰 p q) (→𝒟 (¬¬ p) (¬¬ q))))))]

两次 @racket[neg] 连起来，记作 @racket[neg²]。@tech{宿主箭头} @math{p → q} 进来，出去的是 @math{¬¬p → ¬¬q}，每个类型裹上一层 @math{¬¬}：

@examples[#:eval ev #:label #f #:no-prompt
(: neg² (∀ (p q) (→ (→𝒞 p q) (→𝒟 (¬¬ p) (¬¬ q)))))
(define neg² (∘ neg neg))]

把 𝒟 和 @racket[inj] 也画进前面那张图表：

@out-block|{𝒟 ───inj────→ 𝒞 ←───────────┐
↑             │             │
│            neg          uncps
│             │             │
│             ↓             │
└────neg───── 𝒰 ───flip───→ 𝒦}|

右边的三角形仍然@tech{交换}；左边 𝒟 的那一半不@tech{交换}。一支@tech{逆否箭头}沿 @racket[neg]、@racket[inj] 走到 𝒞，得到的是 @math{¬¬p → ¬¬q}；沿 @racket[flip]、@racket[uncps] 走到 𝒞，得到的是 @math{p → q}。两条路连类型都对不上，这一半只标出箭头怎样转换。

@subsection[#:tag "02:translate-call-cc"]{翻译 call/cc}

@racket[neg²] 的类型写出了想得到的接口：𝒞 里的箭头 @math{p → q}，换成 𝒟 里的 @math{¬¬p → ¬¬q}。要真正落进 𝒟，还得交出相应的纯程序。@racket[(neg² f)] 本身不一定是：它运行时仍原样调用 @racket[f]，@racket[f] 若用了宿主的 @racket[call/cc]，包一层以后照样依赖它，类型写成 @math{→@subscript{𝒟}} 改变不了这一点。

不过，就算 @racket[f] 里用了 @racket[call/cc]，也可能另有一个纯函数，和 @racket[(neg² f)] 行为一样。举个例子：@racket[cps:f] 是一支纯的 @tech{CPS 箭头}，把 @racket[f] 定义成 @racket[(uncps cps:f)]。@racket[uncps] 里用了 @racket[call/cc]，@racket[f] 里也就有 @racket[call/cc]。展开 @racket[(neg² f)]：

@racketblock[
#,(hspace 2)(neg² f)
= (neg² (uncps cps:f))
= (neg (neg (uncps cps:f)))
= (neg (flip (cps (uncps cps:f))))
≈ (neg (flip cps:f))]

第三步用的是 @c{neg = (∘ flip cps)}，最后一步是@xref["02:three-forms"]{「三种写法」}里的 @c{(cps (uncps cps:f)) ≈ cps:f}。右边只用 @racket[λ] 和函数调用，@racket[cps:f] 是纯的，它也落在 𝒟 里。

@racket[call/cc] 自己就是这样一支 @racket[f]：@xref["02:same-arrow"]{「同一支箭头」}说过，@racket[(uncps neg²:id)] 就是 @racket[call/cc]，而 @racket[neg²:id] 只用 @racket[λ] 写成。照同样的步子展开 @racket[(neg² call/cc)]，再把 @racket[neg²:id] 拆回 @racket[id]：

@racketblock[
#,(hspace 2)(neg² call/cc)
= (neg (neg call/cc))
= (neg (flip (cps call/cc)))
≈ (neg (flip neg²:id))
≈ (neg (flip (neg (neg id))))
= (neg (cps (neg id)))]

最后一行从 @racket[id] 出发，依次用 @racket[neg]、@racket[cps]、@racket[neg]，一路都不碰 @racket[call/cc]。交齐参数，看它做了什么。展开时用上@xref["02:same-arrow"]{「同一支箭头」}里@tech{逆否箭头}那一行：@racket[(neg call/cc)] 就是用在 @math{¬p} 上的 @racket[cps:id]。

@racketblock[
#,(hspace 2)(((neg² call/cc) kkkkp) kp)
= (kkkkp ((neg call/cc) kp))
≈ (kkkkp (cps:id kp))
= (kkkkp (λ (kkp) (kkp kp)))]

@racket[call/cc] 不见了，剩下的只用 @racket[λ] 和函数调用：外层的计算交来一段 @racket[kkp]，再把同一条 @racket[kp] 交给它。从第 4 层到第 2 层，消去两层而不落底，正是@xref["02:count-k"]{「数一数 k」}里的 @racket[(neg cps:id)]，@tech{三重否定律}用在 @math{¬p} 上。

@racket[neg]、@racket[cps]、@racket[neg] 这一串，用在别的@tech{宿主箭头}上也行，记作 @racket[join]；用在 @racket[id] 上的那一支，照名字的约定记作 @racket[join:id]：

@examples[#:eval ev #:label #f #:no-prompt
(: join (∀ (p q) (→ (→𝒞 p q) (→𝒟 (¬¬ (¬¬ p)) (¬¬ q)))))
(define join (∘ neg cps neg))

(: join:id (∀ (p) (→𝒟 (¬¬ (¬¬ p)) (¬¬ p))))
(define join:id (join id))]

和 @racket[neg²] 一样，@racket[join] 不会消除交给它的函数的副作用：@racket[(join f)] 运行时仍原样调用 @racket[f]。用在纯的 @racket[id] 上，得到的 @racket[join:id] 才确实是纯函数。

交给 @racket[join:id] 一段四重否定的 @racket[7]，交出的是一段等着@tech{延续}的 @racket[7]：

@examples[#:eval ev #:label #f
(anf:eval (join:id (cps:id (cps:id 7))))]

@bold{练习}：沿第二张图表从 𝒦 经 𝒰 走到 𝒟：先 @racket[flip]、再 @racket[neg]，记作 @racket[cps->neg²]。验证 @racket[(cps->neg² neg²:id)] 就是 @racket[join:id]。

同一支 @racket[call/cc]，沿图表换成各种写法。前三行是同一个 @math{¬¬p → p} 写在三种箭头上，最后一行换了类型；层数按展开到宿主以后来数（中间两行用的是@xref["02:three-forms"]{「三种写法」}那条规律的前提）：

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list @elem{类型} @elem{箭头} @elem{由 @racket[id] 造出} @elem{层数})
   (list @elem{@math{¬¬p →@subscript{𝒞} p}} @racket[call/cc] @elem{} @elem{2 → 0})
   (list @elem{@math{¬¬p →@subscript{𝒦} p}} @racket[neg²:id]
         @racket[(neg neg:id)] @elem{2 → 2})
   (list @elem{@math{¬¬p →@subscript{𝒰} p}} @elem{@racket[cps:id]，用在 @math{¬p} 上}
         @racket[(cps neg:id)] @elem{1 → 3})
   (list @elem{@math{¬¬¬¬p →@subscript{𝒟} ¬¬p}} @racket[join:id]
         @racket[(neg (cps neg:id))] @elem{4 → 2}))]

只有宿主那一行落到第 0 层。原来的 @racket[call/cc] 靠宿主的控制完成 @math{¬¬p → p}；改写以后，它有了一个 @math{¬¬¬¬p → ¬¬p} 的纯表示 @racket[join:id]，只用 DNI 和逆否就写得出。这并没有在纯语言里实现原来的 DNE：要取回原来类型的结果，仍然要靠运行边界上的控制能力。

改变类型，同时把经典的操作改写成构造性的程序，这就是@defterm[#:en "negative translation"]{否定翻译}的思想。逻辑里，@tech{否定翻译}把经典证明改写成直觉主义证明。@xref["02:clavius"]{「新箭头下的 Clavius 律」}用的也是它：同一条经典定律，换用 @tech{CPS 箭头}来写，就成了直觉主义定理。

@subsection[#:tag "02:mul"]{从 mul 到 cps:mul}

@racket[call/cc] 的例子展示了一个经典操作怎样取得纯表示。@xref["02:early-return"]{「提前返回」}则已经把整段程序按结构改写成了纯的 @tech[#:key "延续传递风格"]{CPS} 程序。照宿主的 @racket[mul] 一行行改写，程序的结构一模一样，换掉的只有三样：@racket[let/cc] 换成了 @racket[anf:let/cc]，@racket[let*]、@racket[if] 换成了 @racket[anf:let*]、@racket[anf:if]，原语换成了提升过的 @racket[cps:car]、@racket[cps:*] 这些。这几处替换是我们亲手做的；宏做的，是把替换后的各步接起来。

接口也跟着变了。@racket[mul] 收到乘数，交出乘积；@racket[cps:mul] 收到同样的乘数，交出一段等待@tech{延续}的计算：一个是 @math{p → q}，一个是 @math{p → ¬¬q}。控制的做法也换了。@racket[mul] 遇零时，调用的是 @racket[let/cc] 从宿主那里捕获的@tech{延续}；@racket[cps:mul] 的 @racket[cps:return] 却是 @racket[cps:call/cc] 交到程序手里的参数，而 @racket[cps:call/cc] 的定义只用了 @racket[λ] 和函数调用。

用到的构造都在 𝒟 里。@racket[neg]、@racket[flip]、@racket[cps]、@racket[∘𝒦]、@racket[cps:call/cc] 都由 @racket[λ]、函数应用、复合，以及有限参数表上的 @racket[apply] 写成，自己不跳转，也不输出：交给它们的函数在 𝒟 里，得到的也在 𝒟 里。@racket[cps:mul] 用到的原语都是纯函数，@racket[car]、@racket[cdr] 只在 @racket[null?] 判过非空以后调用；@racket[cps:loop] 是递归的，但每次处理更短的有限列表。所以 @racket[cps:mul] 整个落在 𝒟 里：遇零照样跳出，宿主的 @racket[call/cc] 一次也没有出现。

阴阳谜题也用这些纯构造连接和传递@tech{延续}，可它每走一步都往外打印字符，而且永远不会结束：整段程序的输出与不终止仍在 𝒟 之外，并不会因为改写成 @tech[#:key "延续传递风格"]{CPS} 就消失。

@racket[cps:mul] 把原来需要捕获@tech{延续}的控制写成了 𝒟 里的纯程序，代价是结果的类型裹上一层 @math{¬¬}。要两端都裹上，沿练习里的 @racket[cps->neg²] 走一步：@racket[(neg (flip cps:mul))] 就是一个 @math{¬¬p → ¬¬q} 的纯函数。

这回翻译的是整段程序：控制操作换成纯的 @tech[#:key "延续传递风格"]{CPS} 构造，原语换成提升过的箭头，各步由宏生成的@tech{延续}接起来，这种接法就是前面认出的 @racket[∘𝒦]。改写要落在程序本身：把 @racket[mul] 原样包一层 @racket[cps]，里面的 @racket[let/cc] 照样会去捕获宿主的@tech{延续}。
