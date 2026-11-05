#lang acf/scribble

@title[#:tag "02:5-where"]{箭头指向何方}

@racket[cps:call/cc] 读出来是一条直觉主义定理，它和宿主那个经典的 @racket[call/cc] 还是一回事吗？要比较，得先把两边放到一处：嵌入语言写下的箭头，放回宿主，行为还和原来一样吗？

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

@defsym["uncps" "把 CPS 箭头放回宿主：用 call/cc 捕获当前延续，填进延续参数"]宿主若有 @racket[call/cc]，就能直接捕获当前@tech{延续}，填进编码的@tech{延续}参数：

@examples[#:eval ev #:label #f #:no-prompt
(: uncps (∀ (p q) (→ (→𝒦 p q) (→𝒟 p q))))
(define (uncps cps:f) (∘ call/cc cps:f))]

@racket[((uncps cps:f) p)] 先算出 @racket[(cps:f p)]，一段等待@tech{延续}的计算，再交给 @racket[call/cc]，@racket[call/cc] 把当前@tech{延续}交给它。@racket[uncps] 收 @tech{CPS 箭头}，交出@tech{宿主箭头}，也就是一个普通的宿主函数，可以放进同一个 @racket[(+ 1 _)]：

@examples[#:eval ev #:label #f
(+ 1 ((uncps cps:mul) 1 2 3 4))
(+ 1 ((uncps cps:mul) 1 2 0 3 4))]

结果和 @racket[anf:eval] 那两行一样，这回却没有 handler 去接：正常乘完的 @racket[24]，和遇零从 @racket[cps:return] 跳出来的 @racket[0]，交给的都是 @racket[call/cc] 填进去的那条@tech{延续}本身，也就是 @racket[(+ 1 _)]。@xref["02:k-in-hand"]{「手中的延续」}在编码里实现 @racket[call/cc]，把当前@tech{延续}交给程序；这里用宿主的 @racket[call/cc] 运行编码，把当前@tech{延续}交进编码。

宿主函数经 @racket[cps] 提升，再经 @racket[uncps] 放回，还是原来那个吗？对@tech{宿主箭头} @racket[f]，展开看：

@racketblock[
#,(hspace 2)((uncps (cps f)) . p*)
= (call/cc ((cps f) . p*))
= (call/cc (λ (kq) (kq (f . p*))))
= (f . p*)]

第三步用的是@xref["01:call-cc-types"]{「call/cc 的几种类型」}里的道理：@racket[proc] 正常返回，走的也正是交给它的那条@tech{延续}，只是没有写出来。这里反过来，@racket[(kq …)] 处在尾位置，@racket[kq] 就是调用 @racket[call/cc] 这一处的当前@tech{延续}，显式调用它和直接返回 @racket[(f . p*)] 汇入同一个出口。提起来再放回去，还是原来的函数。

@section[#:tag "02:three-forms"]{三种写法}

反过来呢？一支 @tech{CPS 箭头}先经 @racket[uncps] 运行回宿主，再经 @racket[cps] 提升，还是原来那支吗？要回答它，得先说清怎样算「还是」。下面用@defsym["a ≈ b" "行为相同：延续只拿来调用，也不分辨在捕获处还是调用处执行它"] @racket[≈] 记@xref["01:pairing"]{「两种配对」}里约定的行为相同：@tech{延续}只拿来调用，程序也不分辨是在捕获处还是调用处执行它。在这个约定下，那一节的结论写成：

@racketblock[
#,(hspace 2)(let ([p (call/cc kkp)]) (kp p))
= (kp (call/cc kkp))
≈ (kkp kp)]

@racket[≈] 比 @racket[=] 弱，还要用到约定。约定回答的是两个问题，后文用到它，都回到这里。两种配对为什么到同一个出口？沿用第一章：@racket[kp]、@racket[kkp] 都是否定塔上不正常返回的函数；@tech{延续}只拿来调用，程序也不分辨是在捕获处还是调用处执行 @racket[kp]。换序，或者放进更大的程序，还能这样比吗？涉及两层参数的换写，沿用@xref["02:split-k"]{「延续独占一层」}的约定，第一层只造函数；各层参数和外围环境也守同样的约定，所以可以在本章的调用、绑定和复合里作这样的替换。交给提升回来的箭头输入 @racket[p] 和@tech{延续} @racket[kq]，展开：

@racketblock[
#,(hspace 2)(((cps (uncps cps:f)) p) kq)
= (kq ((uncps cps:f) p))
= (kq (call/cc (cps:f p)))
≈ ((cps:f p) kq)]

这里前两步的 @racket[=] 是照定义展开，最后一步就是上面那条。

两个方向都回到原处：@tech{宿主箭头}经 @racket[cps] 变成 @tech{CPS 箭头}，@tech{CPS 箭头}经 @racket[uncps] 变回@tech{宿主箭头}，来回一趟，行为不变。@tech{逆否箭头}和 @tech{CPS 箭头}之间，@racket[flip] 来回一趟，照定义就回到原样。把这几种转换画在一起，箭头的种类记在顶点上（𝒟、𝒰、𝒦 分别指@tech{宿主箭头}、@tech{逆否箭头}、@tech{CPS 箭头}），转换标在边上，就是一张@defterm[#:en "diagram"]{图表}：

@out-block|{ 𝒟 ←───────────┐
 │             │
neg          uncps
 │             │
 ↓             │
 𝒰 ───flip───→ 𝒦}|

从 𝒟 出发，经 @racket[neg]、@racket[flip] 到 𝒦，就是 @c{cps = (∘ flip neg)}；再经 @racket[uncps] 回到 𝒟，得到的还是原来的箭头。从 𝒦 出发，经 @racket[uncps] 回到 𝒟，再经 @racket[neg] 走到 𝒰，得到的是什么？展开只用到上面那条规律：

@racketblock[
#,(hspace 2)(((neg (uncps cps:f)) kq) p)
= (kq ((uncps cps:f) p))
= (kq (call/cc (cps:f p)))
≈ ((cps:f p) kq)
= (((flip cps:f) kq) p)]

@racket[(neg (uncps cps:f))] 与 @racket[(flip cps:f)] 行为相同：@racket[flip] 从 𝒦 到 𝒰 的那个方向，就是 @racket[(∘ neg uncps)]，和 @c{cps = (∘ flip neg)} 正好对称。三条边绕成一个圈，从哪一处出发绕一圈，都回到原来的箭头；因此从一处走到另一处，多绕几圈也不改变结果。图表有这种性质，就说它是@defterm[#:en "commutative"]{交换}的，叫作@defterm[#:en "commutative diagram"]{交换图表}。

@defsym["unneg" "撤销 neg：(∘ uncps flip)，要靠 call/cc"]所以每条边都能由另外两条倒回去：@racket[uncps] 由 @racket[cps] 倒回，@racket[flip] 由 @racket[(∘ neg uncps)] 倒回。@racket[neg] 由 @racket[(∘ uncps flip)] 倒回，从 𝒰 回到 𝒟 本来没有直接的一条边，这一支撤销 @racket[neg]，记作 @racket[unneg]：

@examples[#:eval ev #:label #f #:no-prompt
(: unneg (∀ (p q) (→ (→𝒰 p q) (→𝒟 p q))))
(define unneg (∘ uncps flip))]

@margin-note{这里的同构只就本章的@tech{延续}编码、在 @racket[≈] 的意义下说，@racket[uncps] 还要靠宿主的 @racket[call/cc] 才写得出来；并不是任意具有这些类型的 Racket 函数都这样。}

在 @racket[≈] 的意义下，三种写法是@defterm[#:en "isomorphic"]{同构}的：同一组箭头的三种写法。到这里，嵌入语言写出的箭头放得回宿主，放回去行为不变；可放回去要靠宿主的 @racket[call/cc]。三种写法互相转换不丢行为，以后在哪种写法里推导都行，推完再搬回来。
