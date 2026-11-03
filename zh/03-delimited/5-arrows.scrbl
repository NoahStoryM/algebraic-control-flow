#lang acf/scribble

@title[#:tag "03:5-arrows"]{局部否定下的箭头}

@racket[neg]、@racket[cps]、@racket[flip] 只管把函数接到@tech{延续}前面、交换参数，从没问过@tech{延续}落在哪里。

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define ∘ compose)
(define id (∘))
(define-type ⊥ (∪))
(define-type (← q p) (→ p q))
(define-type (→𝒟 p ... q) (→ p ... q))
(define-type ⊥ᵃ a)
(define-type (¬ₐ p ...) (→ p ... ⊥ᵃ))
(define-type (¬ₐ¬ₐ p) (¬ₐ (¬ₐ p)))]

@section[#:tag "03:any-base"]{换了基的箭头}

@xref["02:via-contrapositive"]{「借道逆否复合」}里，@tech{逆否箭头} @math{p →@subscript{𝒰} q} 是 @math{¬q → ¬p}，@tech{CPS 箭头} @math{p →@subscript{𝒦} q} 是 @math{p → ¬¬q}，用的都是落在 @math{⊥} 上的否定。@tech{基}换成 @math{a}，把 @math{¬} 换成 @math{¬ₐ}，同样的两种箭头记作 @math{→@subscript{𝒰ₐ}}、@math{→@subscript{𝒦ₐ}}：

@examples[#:eval ev #:label #f #:no-prompt
(define-type (→𝒰ₐ p ... q) (← (¬ₐ p ...) (¬ₐ q)))
(define-type (→𝒦ₐ p ... q) (→ p ... (¬ₐ¬ₐ q)))]

@defsym["p →𝒰ₐ q" "以 a 为基的逆否箭头：¬ₐq → ¬ₐp"]@defsym["p →𝒦ₐ q" "以 a 为基的 CPS 箭头：p → ¬ₐ¬ₐq"]下标换成别的类型，比如 @math{x}，就是以 @math{x} 为@tech{基}的同一组箭头：@math{¬ₓ}、@math{→@subscript{𝒰ₓ}}、@math{→@subscript{𝒦ₓ}}。

@racket[neg] 的定义没有变：

@examples[#:eval ev #:label #f #:no-prompt
(define ((neg f) kq) (∘ kq f))]

它把 @racket[f] 接在收到的@tech{延续}前面，沿用那条@tech{延续}的终点，终点是什么，它并不在乎。所以 @racket[(neg f)] 对任何@tech{基}都是一支@tech{逆否箭头}：收到一条 @math{¬ₓq}，交出一条 @math{¬ₓp}。@racket[cps]、@racket[flip] 也一样，它们只管参数的次序，同样不在乎@tech{基}。

@xref["02:k-in-hand"]{「手中的延续」}里，@racket[neg:call/cc] 也把 @racket[neg] 用在了@tech{延续} @racket[kp] 上。可 @racket[kp] 的终点是 @math{⊥}：它一调用就跳走，不再返回，@racket[(neg kp)] 接在它后面的那段@tech{延续}永远轮不到。那一节的练习提示过，@racket[(neg kp)] 先收的是一条 @math{¬⊥} 的@tech{延续}。

@tech{局部延续}不一样。@tech{平凡表示}下，@tech{局部空} @math{⊥ᵃ} 就是普通的类型 @math{a}，@tech{局部否定} @math{¬ₐp} 也就是普通的函数类型 @math{p → a}。@tech{局部延续}是普通的函数，调用完会正常返回；交给 @racket[neg] 以后，接在它后面的工作也真的会运行。

把 @racket[f] 换成一条@tech{局部延续} @math{kₐp : p → ⊥ᵃ}，@racket[(neg kₐp)] 收下一条等着 @math{⊥ᵃ} 的@tech{延续}，交出一条等着 @math{p} 的@tech{延续}。这两条@tech{延续}最后落在哪里，@math{kₐp} 管不着，可以是任何一个@tech{基}。@tech{基}说的是组成这支箭头的那些@tech{延续}共同的终点，和@xref["03:local-k"]{「局部延续」}里一样；@math{kₐp} 自己落在 @math{⊥ᵃ} 上，@racket[(neg kₐp)] 收到的@tech{延续}落在哪里，却由用到它的地方定。@math{a} 已经是 @math{kₐp} 自己的答案类型，另起一个名字才分得开，记作 @math{x}。展开就是：

@mm{(⊥ᵃ → x) → (p → x)}

它是一支以 @math{x} 为@tech{基}、从 @math{p} 指向 @math{⊥ᵃ} 的@tech{逆否箭头}，@math{p →@subscript{𝒰ₓ} ⊥ᵃ}。展开式里看得出 @math{a} 和 @math{x} 为什么可以不同：@math{⊥ᵃ} 是 @math{kₐp} 自己交出的答案，@math{x} 是收到的@tech{延续}的终点。落点直接写在箭头里，@racket[neg] 的两种读法写进同一个 @racket[case→]：

@examples[#:eval ev #:label #f #:no-prompt
(: neg (∀ (p q a x) (case→ (→ (→𝒟 p q) (→𝒰ₓ p q))
                           (→ (¬ₐ p)    (→𝒰ₓ p ⊥ᵃ)))))]

第一行是@xref["02:via-contrapositive"]{「借道逆否复合」}的读法，只是@tech{基}可以任选；第二行是把它用在@tech{局部延续}上。第二章从 𝒰 读到 𝒞 的那种读法，这一节用不上，不再列出。@math{kₐp} 的终点 @math{⊥ᵃ} 由它自己定下，箭头的@tech{基} @math{x} 由用到它的地方定下，两者不必相同。

@section[#:tag "03:two-call-cc"]{两个 call/cc}

控制运算符把当前的@tech{局部延续}提升以后交给程序。当前的@tech{局部延续}落在自己的@tech{局部空} @math{⊥ᵃ} 上，@math{⊥ᵃ} 又正是这段局部计算的答案 @math{a}。终点和@tech{基}重合，取 @math{x = a}，交给程序的就是一支 @math{p →@subscript{𝒰ₐ} ⊥ᵃ}，这就是 @racket[neg:call/lc]：

@examples[#:eval ev #:label #f #:no-prompt
(: neg:call/lc (∀ (p a) (→𝒰ₐ (→𝒰ₐ (→𝒰ₐ p ⊥ᵃ) p) p)))
(define ((neg:call/lc kₐp) neg:proc) ((neg:proc kₐp) (neg kₐp)))]

程序拿到的 @racket[(neg kₐp)] 是一个映射：给它一条等着 @math{a} 的@tech{延续}，它把保存的局部工作接在前面。调用它，局部的工作做完就正常返回，当前的@tech{延续}接着运行。

@racket[call/cc] 交出的@tech{延续}不接在当前@tech{延续}前面，而是把它丢掉。照@xref["03:meta"]{「元延续」}的分解，调用这条@tech{延续}，保存的局部工作做完，答案越过边界，交给调用时边界外的工作，不再回到这段局部计算里。从局部计算内部看，那里没有任何值能返回，是全局的空 @math{⊥}。所以交给程序的箭头不再落在 @math{⊥ᵃ} 上，而是落在 @math{⊥} 上：@math{p →@subscript{𝒰ₐ} ⊥}，形状和@xref["02:liar"]{「说谎者」}里的 @math{¬@subscript{𝒰}p} 一样，只是@tech{基}换成了 @math{a}。

@math{p →@subscript{𝒰ₐ} ⊥} 展开是 @racket[(← (¬ₐ p) (¬ₐ ⊥))]，一个从 @math{¬ₐ⊥ = ⊥ → a} 到 @math{¬ₐp} 的函数。它收到的参数是调用处的@tech{延续}，等着一个 @math{⊥} 类型的结果，就是前面说的那条 @math{¬⊥} 的@tech{延续}换了@tech{基}。这个参数和@xref["01:call-cc-types"]{「call/cc 的几种类型」}里的 @racket[absurd] 一样，是一个函数，却没有 @math{⊥} 类型的值可以交给它。@racket[neg*] 因此直接略过它，交出保存的@tech{局部延续} @math{kₐp}：

@examples[#:eval ev #:label #f #:no-prompt
(: neg* (∀ (p a) (→ (¬ₐ p) (→𝒰ₐ p ⊥))))
(define ((neg* kₐp) k) kₐp)]

@defsym["neg*" "把局部延续提升成丢弃当前延续的逆否箭头"]用 @racket[neg*] 代替 @racket[neg]，就是 @racket[call/cc]：

@examples[#:eval ev #:label #f #:no-prompt
(: neg:call/cc (∀ (p a) (→𝒰ₐ (→𝒰ₐ (→𝒰ₐ p ⊥) p) p)))
(define ((neg:call/cc kₐp) neg:proc) ((neg:proc kₐp) (neg* kₐp)))]

两个控制运算符保存的是同一份局部工作 @math{kₐp}。@racket[neg:call/lc] 交出的@tech{延续}，调用时把这份工作接在当前@tech{延续}前面，做完正常返回；@racket[neg:call/cc] 交出的@tech{延续}，调用时丢掉当前@tech{延续}，只留下这份工作。

两个类型只差最里面那支箭头的终点：@racket[neg:call/lc] 的是 @math{⊥ᵃ}，@racket[neg:call/cc] 的是 @math{⊥}。把 @math{→@subscript{𝒰ₐ}} 读作蕴含，终点记作 @math{q}，得到 @math{((p → q) → p) → p}，正是 @tech{Peirce 律}的外形；@math{q = ⊥} 时，它就是 @tech{Clavius 律}的外形。把 @math{p →@subscript{𝒰ₐ} ⊥ᵃ} 看作落在 @math{⊥ᵃ} 上的否定，@racket[neg:call/lc] 也有 @tech{Clavius 律}的外形；把落点 @math{⊥ᵃ} 展开成 @math{a}，就是 @math{q = a} 的 @tech{Peirce 律}外形。这里比的只是外形：箭头换了，展开到宿主就不是同一个命题。@xref["01:call-cc-types"]{「call/cc 的几种类型」}里，借助 @racket[absurd]，两条定律在操作上分不出来。在这里，两个实现分开了：@racket[neg:call/lc] 把保存的工作接在当前@tech{延续}之前，做完回到调用处；@racket[neg:call/cc] 丢掉当前的@tech{局部延续}。

这些构造搬得到 @tech{CPS 箭头}上。@racket[flip] 对任何两层柯里化的函数都成立，@tech{基}换成 @math{a} 也不例外，仍然在两种写法之间来回；只要两层参数之间不做别的事，来回一趟行为不变，@xref["02:split-k"]{「延续独占一层」}说过：

@examples[#:eval ev #:label #f #:no-prompt
(: flip (∀ (p q a) (case→ (→ (→𝒰ₐ p q) (→𝒦ₐ p q))
                        (→ (→𝒦ₐ p q) (→𝒰ₐ p q)))))
(define (((flip f) . y*) . x*) (apply (apply f x*) y*))]

@racket[neg]、@racket[neg*] 经 @racket[flip] 分别得到 @racket[cps]、@racket[cps*]，和@xref["03:escape-discard"]{「逃逸与丢弃」}里直接写出的定义行为一样，@tech{局部延续}的读法也一起带了过来：

@examples[#:eval ev #:label #f #:no-prompt
(: cps  (∀ (p q a x) (case→ (→ (→𝒟 p q) (→𝒦ₓ p q))
                            (→ (¬ₐ p)    (→𝒦ₓ p ⊥ᵃ)))))
(: cps* (∀ (p a) (→ (¬ₐ p) (→𝒦ₐ p ⊥))))
(define cps  (∘ flip neg))
(define cps* (∘ flip neg*))]

把交给程序的@tech{延续}，和接收它的程序，都换成 @tech[#:key "延续传递风格"]{CPS} 的写法：

@examples[#:eval ev #:label #f #:no-prompt
(: cps:call/lc (∀ (p a) (→𝒦ₐ (→𝒦ₐ (→𝒦ₐ p ⊥ᵃ) p) p)))
(: cps:call/cc (∀ (p a) (→𝒦ₐ (→𝒦ₐ (→𝒦ₐ p ⊥) p) p)))

(define ((cps:call/lc cps:proc) kₐp) ((cps:proc (cps  kₐp)) kₐp))
(define ((cps:call/cc cps:proc) kₐp) ((cps:proc (cps* kₐp)) kₐp))]

@racket[cps:abort] 是 @racket[(cps* a->⊥ᵃ)]，类型也就读得出来：@racket[a->⊥ᵃ] 是一条 @math{¬ₐa}，@racket[cps:abort] 是 @math{a →@subscript{𝒦ₐ} ⊥}，一支以 @math{a} 为@tech{基}、落在全局 @math{⊥} 上的 @tech{CPS 箭头}。

@section[#:tag "03:eval-boundary"]{求值与边界}

这些控制运算符，用在 @racket[anf:] 宏编译出的计算里。编译出的计算有类型 @math{¬ₐ¬ₐp = (p → a) → a}，等着一条@tech{局部延续} @math{¬ₐp}。@racket[anf:eval] 给 @math{¬ₐ¬ₐa} 交进@tech{局部终结延续} @racket[a->⊥ᵃ]，类型是 @math{¬ₐa}，得到答案 @math{a}：

@examples[#:eval ev #:label #f #:no-prompt
(: a->⊥ᵃ (∀ (a) (¬ₐ a)))
(define a->⊥ᵃ id)

(: anf:eval (∀ (a) (→ (¬ₐ¬ₐ a) a)))
(define (anf:eval kₐkₐa) (kₐkₐa a->⊥ᵃ))]

@racket[anf:eval] 的类型，外形还是 @tech[#:key "双重否定消除"]{DNE}。原来的 @racket[anf:eval] 也是这个外形，那里终点是 @math{⊥}，要交进去的@tech{终结延续} @math{¬a} 写不出来，只好借 @racket[raise] 和 handler。这里普通结果的类型和答案的类型都是 @math{a}，@tech{局部终结延续} @math{¬ₐa = a → a} 有现成的元素，就是 @racket[id]，不必借助宿主的跳转。

再看这个类型的结果 @math{a}。@tech{平凡表示}下，@math{a} 就是 @math{⊥ᵃ}，这段局部计算的空。值域是 @math{⊥ᵃ} 的箭头写成 @math{¬ₐ}，@racket[anf:eval] 也就是一条@tech{局部延续}，类型是 @math{¬ₐ(¬ₐ¬ₐa)}，三重@tech{局部否定}。@racket[a->⊥ᵃ] 是一条 @math{¬ₐa}，@racket[cps] 把 @racket[id] 提升成 @tech[#:key "双重否定引入"]{DNI}，@racket[cps:id]，把它用在 @racket[a->⊥ᵃ] 上，正好是这样一个元素：

@examples[#:eval ev #:label #f #:no-prompt
(define-type (¬ₐ¬ₐ¬ₐ p) (¬ₐ (¬ₐ¬ₐ p)))

(: cps:id (∀ (p a) (→𝒦ₐ p p)))
(define cps:id (cps id))

(: anf:eval (∀ (a) (¬ₐ¬ₐ¬ₐ a)))
(define anf:eval (cps:id a->⊥ᵃ))]

@tech[#:key "双重否定消除"]{DNE} 的外形，终点换成了答案，就成了三重否定，有一个只用 @tech[#:key "双重否定引入"]{DNI} 写成的元素。

@racket[anf:eval] 本身是一条以 @math{a} 为@tech{基}的@tech{局部延续}，照 @racket[cps] 的第二种读法，提升出来的 @racket[anf:reset] 是 @math{¬ₐ¬ₐa →@subscript{𝒦ₓ} ⊥ᵃ}，@tech{基} @math{x} 任选。展开成普通的类型：

@examples[#:eval ev #:label #f #:no-prompt
(: anf:reset (∀ (a x) (→ (¬ₐ¬ₐ a) (¬ₓ¬ₓ a))))
(define anf:reset (cps anf:eval))]

里面的答案类型是 @math{a}，提升以后，外面可以是任何答案类型 @math{x}。展开定义：

@racketblock[
(define ((anf:reset kₐkₐa) kₓa)
  (kₓa (anf:eval kₐkₐa)))]

@racket[anf:eval] 把 @racket[id] 交给里面的计算，运行得到答案 @math{a}。外面的@tech{延续} @math{kₓa : a → x} 接过这个值，接着做自己的工作。同一个值，在里面已经是答案，越过边界就成了普通的结果。里面从恒等函数开始，一层层积起局部的工作；外面等着它交出答案，这正是@xref["03:stack-slice"]{「栈的切片」}里看到的边界。@racket[anf:reset] 的类型把两侧分别写了出来：里面以 @math{a} 为@tech{基}，外面以 @math{x} 为@tech{基}，@racket[reset] 两侧的@tech{基}可以分别选取。

局部计算不再需要 @racket[raise]，靠的是两件事：@math{⊥} 换成了 @math{⊥ᵃ}，普通结果的类型 @racket[Real] 也换成了 @math{@ty{Real}ᵃ}。前一件已经用到底了；后一件，在代码里却找不到。@xref["03:local-k"]{「局部延续」}以后，代码一直只传一个@tech{延续}，答案那一支到哪里去了？
