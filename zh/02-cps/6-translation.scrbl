#lang acf/scribble

@title[#:tag "02:6-translation"]{否定翻译}

宿主的 @racket[call/cc] 照 @tech[#:key "双重否定消除"]{DNE} 读，是一支箭头。把它搬到别的写法上，会落在第几层？

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
(define (uncps cps:f) (∘ call/cc cps:f))
(define (neg²:id kkp) kkp)
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

@section[#:tag "02:same-arrow"]{同一支箭头}

@xref["02:clavius"]{「Clavius 律」}末尾问过：@racket[cps:call/cc] 还算不算原来的 @racket[call/cc]？先分清两件事。@racket[cps:call/cc] 是把整条 @tech{Clavius 律}换写一遍：类型里的箭头全是 @math{→@subscript{𝒦}}，@racket[proc] 也换成了新的箭头。另一件是不换写定律，只把宿主的 @racket[call/cc] 照 @tech[#:key "双重否定消除"]{DNE} 读成一支@tech{宿主箭头} @math{¬¬p →@subscript{𝒟} p}，收下第 2 层的 @racket[kkp]，交出第 0 层的值，再把这一支搬到 @tech{CPS 箭头}或@tech{逆否箭头}上：这就是 @racket[(cps call/cc)] 和 @racket[(neg call/cc)]。@racket[cps:car] 就是 @racket[(cps car)]，@racket[cps:call/cc] 却不是 @racket[(cps call/cc)]，两者连 @racket[proc] 的接口都不同。至于还算不算：把过程参数和逃逸用的@tech{延续}也按新接口改写以后，@racket[cps:call/cc] 实现的仍是同一个操作，把当前@tech{延续}交给 @racket[proc]。下面看后一件事。

用@xref["01:layers"]{「否定塔」}的层数看，那里的几条规则，这一章都有了现成的写法。@tech[#:key "双重否定引入"]{DNI} 加两层，就是 @racket[cps:id]：收下 @racket[p]，等一条 @racket[kp] 来，再把 @racket[p] 交给它。交来的若正是 @racket[(cps:id p)]，把 @racket[kp] 交给它，照定义一步就回到原处：

@racketblock[
#,(hspace 2)(let ([kkp (cps:id p)]) (kkp kp))
= (kp p)]

@tech{三重否定律}从第 3 层减到第 1 层，不必 @racket[call/cc]，就是 @tech[#:key "双重否定引入"]{DNI} 的逆否 @racket[(neg cps:id)]，和@xref["01:neg-q"]{「代入 ¬q」}里的 @racket[triple-negation] 做的一样：

@racketblock[
(((neg cps:id) kkkp) p)  =  (kkkp (cps:id p))]

@tech[#:key "双重否定消除"]{DNE} 从第 2 层落到第 0 层，要 @racket[call/cc]；可手里的 @racket[kkp] 若只是要交给一条 @racket[kp]，@xref["01:pairing"]{「两种配对」}说，不必落到第 0 层，直接配对就行。

先看 @tech{CPS 箭头}。交给 @racket[(cps call/cc)] 一段 @racket[kkp] 和@tech{延续} @racket[kp]，用@xref["02:three-forms"]{「三种写法」}那条规律：

@racketblock[
#,(hspace 2)(((cps call/cc) kkp) kp)
= (kp (call/cc kkp))
= (let ([p (call/cc kkp)]) (kp p))
≈ (kkp kp)]

@defsym["neg²:id" "(neg (neg id))：¬¬p →𝒦 p，也是 ¬¬p →𝒞 ¬¬p；(cps call/cc) 的纯表示"]收下 @racket[kkp]，把@tech{延续} @racket[kp] 原样交给它：这支箭头什么也不运行，收下一段计算，原样交出。代码和 @racket[id] 一样，类型却是一支 @tech{CPS 箭头}：从 @math{¬¬p} 到 @math{p}。这和@xref["02:via-contrapositive"]{「借道逆否复合」}里的 @racket[neg:id] 是同一种情形：定义相同，箭头的种类不同。记作 @racket[neg²:id]：

@examples[#:eval ev #:label #f #:no-prompt
(: neg²:id (∀ (p) (→𝒦 (¬¬ p) p)))
(define (neg²:id kkp) kkp)]

于是上面那段展开说的是：

@racketblock[
(cps call/cc)  ≈  neg²:id]

@math{¬¬p →@subscript{𝒦} p} 看上去也像 @tech[#:key "双重否定消除"]{DNE}；展开到宿主，它只是 @math{¬¬p → ¬¬p}，从第 2 层到第 2 层。名字的由来：@racket[neg²] 指连用两次 @racket[neg]，@racket[neg²:id] 就是 @racket[(neg (neg id))]，也就是 @racket[(neg neg:id)]。验证一下：@racket[(neg neg:id)] 收下 @racket[kkp]，交出 @racket[(∘ kkp id)]，行为和 @racket[kkp] 一样。反过来，把它交给 @racket[uncps]，沿图表回到宿主，得到的正是 @racket[call/cc]：

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

表里 @racket[neg:id] 写作 @racket[(neg id)]：@racket[(neg id)] 交给 @racket[k] 得到 @racket[(∘ k id)]，与 @racket[k] 行为相同，所以代码直接用 @racket[id]。

再看@tech{逆否箭头}：

@racketblock[
#,(hspace 2)(((neg call/cc) kp) kkp)
= (kp (call/cc kkp))
= (let ([p (call/cc kkp)]) (kp p))
≈ (kkp kp)
= ((cps:id kp) kkp)]

@racket[(neg call/cc)] 收下第 1 层的 @racket[kp]，交出第 3 层，多了两层。最后两步，正是@xref["01:pairing"]{「两种配对」}里的两种走法：先落到第 0 层再交给 @racket[kp]，和把 @racket[kp] 升到第 3 层再与 @racket[kkp] 相遇，行为相同。展开的最后一行说，@racket[(neg call/cc)] 的行为和用在 @math{¬p} 上的 @racket[cps:id] 相同。@racket[neg:id] 就是 @racket[id]，所以 @racket[cps:id] 也就是 @racket[(cps neg:id)]。宿主里 2 → 0 的这一步，换成 @tech{CPS 箭头}是 2 → 2，换成@tech{逆否箭头}是 1 → 3，接口一变，都不再落到第 0 层。

@racket[uncps] 回到宿主，靠的是 @racket[call/cc]。不用它，这些箭头能不能落到纯的宿主函数？

@section[#:tag "02:neg-again"]{再用一次 neg}

@margin-note{𝒞 取 constructive，构造性。}

@defsym["inj" "把纯函数原样放进 𝒟（injection，注入）"]@xref["02:back-to-host"]{「回到宿主」}的 @racket[uncps] 把 @tech{CPS 箭头}变成宿主函数，里面用的是 @racket[call/cc]。这一章说的@tech{宿主箭头} 𝒟，指的是这里讨论的计算：普通的函数，加上 @racket[call/cc] 这样的控制，按@xref["02:three-forms"]{「三种写法」}约定的行为相同来比较；打印、状态这类别的作用不算在内。其中纯的那一部分，记作 𝒞@defsym["p →𝒞 q" "纯的宿主函数 p → q；𝒞 取 constructive"]：由 @racket[λ]、函数应用和纯原语写成，自己不引入控制，递归只限于能终止的情形；作为参数交进来的函数，也要是纯的。这样的构造填入纯参数时仍是纯的。运行时交进去的@tech{终结延续}由外部提供，调用它以后的退出，不算纯程序内部的构造。这里讨论的是有纯 @tech[#:key "延续传递风格"]{CPS} 表示的控制计算：对一支这样的宿主箭头 @racket[f]，有纯的 @racket[cps:f]，把它用 @racket[uncps] 放回宿主，就与 @racket[f] 行为相同。@xref["02:early-return"]{「提前返回」}里的 @racket[mul]，是按程序结构写出这支表示的一个例子。𝒟 和 𝒞 的类型都是普通的函数类型，区别只在函数怎么写，类型检查不出来。纯函数也是宿主函数，@racket[inj]（injection，注入）把它原样放进 𝒟：

@examples[#:eval ev #:label #f #:no-prompt
(define-type (→𝒞 p ... q) (→ p ... q))

(: inj (∀ (p q) (→ (→𝒞 p q) (→𝒟 p q))))
(define (inj f) f)]

要落到纯的宿主函数，还得像宿主函数一样，用 @racket[∘] 从 @math{p} 接到 @math{q}。把类型展开看看。@tech{逆否箭头} @math{p →@subscript{𝒰} q} 是 @math{¬q → ¬p}，本身就是宿主函数，只是方向反了：从 @math{p} 写到 @math{q}，函数却从 @math{¬q} 指向 @math{¬p}。@tech{CPS 箭头} @math{p →@subscript{𝒦} q} 是 @math{p → ¬¬q}，两端对不上：一支交出的是 @math{¬¬q}，下一支要收的是 @math{q}。

两端对得上的，前面倒见过一支：@racket[neg²:id]。展开到宿主，它是 @math{¬¬p → ¬¬p}，从第 2 层到第 2 层。@xref["02:same-arrow"]{「同一支箭头」}还认出，它就是 @racket[(neg neg:id)]：@tech{逆否箭头}的恒等，再用一次 @racket[neg]。

@tech{逆否箭头}既然反了一次，就再反一次。交给 @racket[neg] 一支@tech{逆否箭头} @racket[neg:f]，得到的 @racket[(neg neg:f)] 是 @math{¬¬p → ¬¬q}：方向正了，两端都裹着 @math{¬¬}，宿主的 @racket[∘] 就能接。它只在@tech{延续}前面接上 @racket[neg:f]：@racket[neg:f] 是纯的，它也是纯的，落在 𝒞 里。落到的却不是原来那支箭头，@math{p} 换成了 @math{¬¬p}。

@racket[neg] 的两种读法，写进同一个 @racket[case→]，第二种读法落在 𝒞 里：

@examples[#:eval ev #:label #f #:no-prompt
(: neg
   (∀ (p q)
      (case→ (→ (→𝒟 p q) (→𝒰     p      q))
             (→ (→𝒰 p q) (→𝒞 (¬¬ p) (¬¬ q))))))]

从宿主出发，沿 @racket[neg] 走两次，类型上走的正是这条路：一支 @math{p →@subscript{𝒟} q} 的控制计算，对应一支纯的 @math{¬¬p →@subscript{𝒞} ¬¬q}，每个类型裹上一层 @math{¬¬}。这个对应记作 @racket[neg²]。

这支纯箭头怎样得到？取 @racket[f] 的纯表示 @racket[cps:f]，先 @racket[flip]、再 @racket[neg]：@racket[(flip cps:f)] 是 @math{¬q → ¬p}，再取一次逆否，正好是 @math{¬¬p → ¬¬q}。@racket[cps:f] 是纯的，@racket[(neg (flip cps:f))] 也只用 @racket[λ] 和函数调用，落在 𝒞 里。

代码上，@racket[neg²] 就是两次 @racket[neg] 连起来。它只把 @racket[f] 包上两层，并不改写 @racket[f] 的内部，有两种读法：

@examples[#:eval ev #:label #f #:no-prompt
(: neg²
   (∀ (p q)
      (case→ (→ (→𝒞 p q) (→𝒞 (¬¬ p) (¬¬ q)))
             (→ (→𝒟 p q) (→𝒟 (¬¬ p) (¬¬ q))))))
(define neg² (∘ neg neg))]

纯的进来，包出来的就是那支纯箭头。@tech{宿主箭头}进来，包出来的仍是@tech{宿主箭头}：@racket[f] 用了 @racket[call/cc]，包装运行时照样依赖它；它和上面那支纯箭头行为相同，下一节验证。从纯箭头出发，先放进 𝒟，再取上面的纯表示，这支箭头可以直接用包装写出。从 𝒟 出发，先取纯表示，再放回 𝒟，所得箭头与直接包装行为相同。

@racket[neg²:id] 就是 @racket[(neg² id)]。它标在 𝒦 上，是 @math{¬¬p →@subscript{𝒦} p}；作为纯的@tech{宿主箭头}，它也是 @math{¬¬p →@subscript{𝒞} ¬¬p}，𝒞 里 @math{¬¬p} 上的恒等箭头。两种读法展开到宿主，都是 @math{¬¬p → ¬¬p}。

把 𝒞 和 @racket[inj] 也画进前面那张图表：

@out-block|{𝒞 ───inj────→ 𝒟 ←───────────┐
↑             │             │
│            neg          uncps
│             │             │
│             ↓             │
└────neg───── 𝒰 ───flip───→ 𝒦}|

右边的三角形仍然@tech{交换}；左边 𝒞 的那一半谈不上@tech{交换}。从 𝒰 出发，沿 @racket[flip]、@racket[uncps] 回到 𝒟，是还原：得到原来的 @math{p → q}，靠的是 @racket[call/cc]。沿 @racket[neg] 走到 𝒞，是翻译：落到纯的箭头，代价是类型成了 @math{¬¬p → ¬¬q}，再经 @racket[inj] 放进 𝒟 也还是它。两条路连类型都对不上，这一半只标出箭头怎样转换。

@section[#:tag "02:translate-call-cc"]{翻译 call/cc}

上一节说，@racket[(neg² f)] 的包装和纯的 @racket[(neg (flip cps:f))] 行为相同。取 @racket[f] 为 @racket[(uncps cps:f)]，展开看看：

@racketblock[
#,(hspace 2)(neg² f)
= (neg² (uncps cps:f))
= (neg (neg (uncps cps:f)))
= (neg (flip (cps (uncps cps:f))))
≈ (neg (flip cps:f))]

第一步是这样选取的，第二步照 @racket[neg²] 的定义，第三步用的是 @c{neg = (∘ flip cps)}，最后一步是@xref["02:three-forms"]{「三种写法」}里的 @c{(cps (uncps cps:f)) ≈ cps:f}，放进 @racket[neg]、@racket[flip] 里仍然成立，那里的约定说过。右边只用 @racket[λ] 和函数调用，@racket[cps:f] 是纯的，它也落在 𝒞 里。

@racket[call/cc] 自己就是这样一支 @racket[f]：@xref["02:same-arrow"]{「同一支箭头」}说过，@racket[(uncps neg²:id)] 就是 @racket[call/cc]，而 @racket[neg²:id] 只用 @racket[λ] 写成。@racket[cps:f] 取 @racket[neg²:id]，先 @racket[flip]：

@racketblock[
#,(hspace 2)(((flip neg²:id) kp) kkp)
= ((neg²:id kkp) kp)
= (kkp kp)
= ((cps:id kp) kkp)]

@racket[(flip neg²:id)] 就是用在 @math{¬p} 上的 @racket[cps:id]；按@xref["02:same-arrow"]{「同一支箭头」}的配对规律，它与 @racket[(neg call/cc)] 行为相同。再用一次 @racket[neg]，交齐参数，看它做了什么：

@racketblock[
#,(hspace 2)(((neg cps:id) kkkkp) kp)
= (kkkkp (cps:id kp))
= (kkkkp (λ (kkp) (kkp kp)))]

@racket[call/cc] 不见了，剩下的只用 @racket[λ] 和函数调用：外层的计算交来一段 @racket[kkp]，再把同一条 @racket[kp] 交给它。从第 4 层到第 2 层，消去两层而不落底，正是@xref["02:same-arrow"]{「同一支箭头」}里的 @racket[(neg cps:id)]，@tech{三重否定律}用在 @math{¬p} 上。

@racket[neg:id] 就是 @racket[id]，所以 @racket[cps:id] 也就是 @racket[(cps neg:id)]，@racket[(neg cps:id)] 是从 @racket[id] 出发，依次用 @racket[neg]、@racket[cps]、@racket[neg] 得到的，一路都不碰 @racket[call/cc]。

@defsym["join" "(∘ neg cps neg)：把外面的两层 ¬¬ 并成一层"]@defsym["join:id" "(join id)：¬¬¬¬p →𝒞 ¬¬p，call/cc 的纯翻译"]这一串把外面的两层 @math{¬¬} 并成一层，用在别的纯箭头上也行，记作 @racket[join]；用在 @racket[id] 上的那一支记作 @racket[join:id]：

@examples[#:eval ev #:label #f #:no-prompt
(: join (∀ (p q) (→ (→𝒞 p q) (→𝒞 (¬¬ (¬¬ p)) (¬¬ q)))))
(define join (∘ neg cps neg))

(: join:id (∀ (p) (→𝒞 (¬¬ (¬¬ p)) (¬¬ p))))
(define join:id (join id))]

和 @racket[neg²] 的包装一样，@racket[join] 不负责改写交给它的函数：@racket[(join f)] 运行时仍原样调用 @racket[f]。交给它纯的箭头，得到的也是纯的；用在 @racket[id] 上，得到的 @racket[join:id] 就是 𝒞 里的一支。

交给 @racket[join:id] 一段四重否定的 @racket[7]，交出的是一段等着@tech{延续}的 @racket[7]：

@examples[#:eval ev #:label #f
(anf:eval (join:id (cps:id (cps:id 7))))]

同一支 @racket[call/cc]，沿图表换成各种写法。前三行的类型外形都是 @math{¬¬p → p}，只是写在三种箭头上，最后一行换了类型；层数按展开到宿主以后来数（后三行与原 @racket[call/cc] 的行为对应，用的是@xref["02:three-forms"]{「三种写法」}那条规律的前提）：

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list @elem{类型} @elem{箭头} @elem{由 @racket[id] 造出} @elem{层数})
   (list @elem{@math{¬¬p →@subscript{𝒟} p}} @racket[call/cc] @elem{} @elem{2 → 0})
   (list @elem{@math{¬¬p →@subscript{𝒦} p}} @racket[neg²:id]
         @racket[(neg neg:id)] @elem{2 → 2})
   (list @elem{@math{¬¬p →@subscript{𝒰} p}} @elem{@racket[cps:id]，用在 @math{¬p} 上}
         @racket[(cps neg:id)] @elem{1 → 3})
   (list @elem{@math{¬¬¬¬p →@subscript{𝒞} ¬¬p}} @racket[join:id]
         @racket[(neg (cps neg:id))] @elem{4 → 2}))]

只有宿主那一行落到第 0 层。原来的 @racket[call/cc] 靠宿主的控制完成 @math{¬¬p → p}；改写以后，它有了一个 @math{¬¬¬¬p → ¬¬p} 的纯表示 @racket[join:id]，只用 @tech[#:key "双重否定引入"]{DNI} 和逆否就写得出。这并没有在纯语言里实现原来的 @tech[#:key "双重否定消除"]{DNE}：要取回原来类型的结果，仍然要靠 @racket[anf:eval] 这样在外面交进@tech{终结延续}、接住答案的控制能力。

改变类型，同时把经典的操作改写成构造性的程序，这就是@defterm[#:en "negative translation"]{否定翻译}的思想。逻辑里，@tech{否定翻译}把经典证明改写成直觉主义证明。@xref["02:clavius"]{「Clavius 律」}用的也是它：@tech{Clavius 律}换用 @tech{CPS 箭头}得到的翻译，展开后是直觉主义定理。

@section[#:tag "02:mul"]{从 mul 到 cps:mul}

@racket[call/cc] 的例子展示了一个经典操作怎样取得纯表示。@xref["02:early-return"]{「提前返回」}则已经把整段程序按结构改写成了纯的 @tech[#:key "延续传递风格"]{CPS} 程序：替换是我们亲手做的，宏把替换后的各步接起来。

编译出的函数构造都在 𝒞 里。@racket[neg]、@racket[flip]、@racket[cps]、@racket[∘𝒦]、@racket[cps:call/cc] 都由 @racket[λ]、函数应用、复合，以及有限参数表上的 @racket[apply] 写成，自己不跳转，也不输出：交给它们的函数在 𝒞 里，得到的也在 𝒞 里。@racket[cps:mul] 用到的原语都是纯函数，@racket[car]、@racket[cdr] 只在 @racket[null?] 判过非空以后调用；@racket[cps:loop] 是递归的，但每次处理更短的有限列表。所以 @racket[cps:mul] 编译出的函数构造落在 𝒞 里：遇零照样跳出，宿主的 @racket[call/cc] 一次也没有出现。

阴阳谜题也用这些纯构造连接和传递@tech{延续}，可它每走一步都往外打印字符，而且永远不会结束：整段程序的输出与不终止仍在 𝒞 之外，并不会因为改写成 @tech[#:key "延续传递风格"]{CPS} 就消失。

@racket[cps:mul] 把原来需要捕获@tech{延续}的控制写成了 𝒞 里的纯程序，代价是结果的类型裹上一层 @math{¬¬}。要两端都裹上，照 @racket[neg²] 的构造先 @racket[flip] 再 @racket[neg]：@racket[(neg (flip cps:mul))] 就是一个 @math{¬¬p → ¬¬q} 的纯函数。

这回翻译的是整段程序：控制操作换成纯的 @tech[#:key "延续传递风格"]{CPS} 构造，原语换成提升过的箭头，各步由宏生成的@tech{延续}接起来，这种接法就是前面认出的 @racket[∘𝒦]。改写要落在程序本身：把 @racket[mul] 原样包一层 @racket[cps]，里面的 @racket[let/cc] 照样会去捕获宿主的@tech{延续}。
