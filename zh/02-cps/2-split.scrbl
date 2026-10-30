#lang acf/scribble

@title[#:tag "02:2-split"]{把延续独立出来}

延续成了参数，可每一个都得亲手写。先看看能不能有一个通用的包装，把普通函数变成这样的写法。

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define-type ⊥ (∪))
(define-type (¬ p) (→ p ⊥))
(define-type (¬¬ p) (¬ (¬ p)))
(define-type (← q p) (→ p q))
(define ∘ compose)
(define id (∘))
(struct (r) ans ([a* : (Listof r)]) #:type-name Ans)
(define (list->values v*) (apply values v*))
(define (a->⊥ . a*) (raise (ans a*)))
(define-syntax-rule (⊥->a exp)
  (with-handlers ([ans? (∘ list->values ans-a*)]) exp))]

@section[#:tag "02:split-k"]{延续独占一层}

给一个具体的函数写 @tech[#:key "延续传递风格"]{CPS} 包装，并不难。@racket[zero?] 的 @tech[#:key "延续传递风格"]{CPS} 版本：

@examples[#:eval ev #:label #f #:no-prompt
(define (zero?/k x k) (k (zero? x)))]

@racket[zero?/k] 在 @racket[zero?] 的结果外面套一层 @racket[k] 调用，就完成了包装。可这层包装，每个函数都得手写一遍。要自动化，就要一个通用的包装：交给它任意函数 @racket[f]，交回 @racket[f] 的 @tech[#:key "延续传递风格"]{CPS} 版本。

@racket[zero?/k] 的两个参数是两种东西：@racket[x] 交给 @racket[zero?] 去算，@racket[k] 只等着接住结果。通用的包装要把这两种参数分开处理，前一种原样交给 @racket[f]，后一种接住 @racket[f] 的结果。挤在同一层参数表里，它们就得一次交齐。柯里化让@tech{延续}独占一层，和其余参数分开，两层就能分开交：先交其余参数，得到一段还没开始的计算；先交@tech{延续}，得到一个把@tech{延续}换成另一条@tech{延续}的函数。两种次序各有用处，都写出来。@tech{延续}独立在内层还是外层，操作上没有区别，函数体都一样：

@examples[#:eval ev #:label #f #:no-prompt
(define (((cps f) . p*) kq) (kq (apply f p*)))  (code:comment "延续在后")
(define (((neg f) kq) . p*) (kq (apply f p*)))  (code:comment "延续在前")]

这样的函数头是嵌套 @racket[λ] 的简写：@racket[(define (((cps f) . p*) kq) body)] 就是 @racket[(define (cps f) (λ p* (λ (kq) body)))]，一层括号收一层参数，@tt{. p*} 把其余参数收成列表，原样交给 @racket[f]，不管 @racket[f] 收几个参数。

拿 @racket[+] 各走一遍。@racket[(cps +)] 先收操作数 @racket[1]、@racket[2]，交出一个等着@tech{延续}的值；再交给它一个@tech{延续}，计算才开始。@racket[(neg +)] 次序反过来，先收@tech{延续}，再收操作数：

@examples[#:eval ev #:label #f
(⊥->a (((cps +) 1 2) (λ (v) (a->⊥ (* v 10)))))
(⊥->a (((neg +) (λ (v) (a->⊥ (* v 10)))) 1 2))]

这只是把 @racket[f] 整个包上一层：@racket[f] 自己里面的计算照旧，@racket[cps] 并不改写它的内部。

操作上一样，类型却不同：

@examples[#:eval ev #:label #f #:no-prompt
(: cps (∀ (p q) (→ (→ p q) (→    p (¬¬ q)))))
(: neg (∀ (p q) (→ (→ p q) (← (¬ p) (¬ q)))))]

@racket[(cps f)] 先收操作数，交出的 @math{¬¬q} 是一段还没开始的计算：@racket[((cps +) 1 2)] 就是还没开始的 @racket[(+ 1 2)]。第一篇里，这样的值有类型：程序就是一个 @math{¬¬@ty{Byte}}，等操作系统交来 @racket[exit] 才运行。

@racket[(neg f)] 先收@tech{延续}：交给它一条等 @math{q} 的@tech{延续} @racket[kq]，它交回一条等 @math{p} 的@tech{延续}：这条@tech{延续}拿到 @math{p}，先交给 @racket[f] 算出 @math{q}，再交给 @racket[kq]。@racket[f] 从 @math{p} 到 @math{q}，@racket[(neg f)] 却从 @math{¬q} 到 @math{¬p}，方向反了过来，所以它的类型用@xref["02:laws"]{「结合律与单位律」}里的反向箭头 @racket[←] 来写。

两者的差别只在柯里化的方向：@tech{延续}在前还是在后。既然是参数顺序的差别，交换顺序就能在两种写法之间来回：

@examples[#:eval ev #:label #f #:no-prompt
(: flip (∀ (x y z) (→ (→ x (→ y z)) (→ y (→ x z)))))
(define (((flip f) . y*) . x*) (apply (apply f x*) y*))]

@racket[flip] 交换参数顺序，对任何两层柯里化的函数都适用。@racket[neg] 产出的 @math{¬q → ¬p} 展开是 @math{¬q → p → ⊥}，正是这样的两层函数，@racket[flip] 把它变成 @math{p → ¬¬q}；反过来，又把 @math{p → ¬¬q} 变回 @math{¬q → ¬p}。只要两层 @racket[λ] 之间不做别的事，@racket[(flip (flip f))] 就和 @racket[f] 行为一样：@racket[flip] 是它自己的逆，在两种写法之间来回，什么也不会丢失。@racket[neg]、@racket[cps] 造出的函数都满足这一条。

有了 @racket[flip]，@racket[cps] 和 @racket[neg] 可以互相定义：

@racketblock[
cps  =  (∘ flip neg)
neg  =  (∘ flip cps)]

@bold{练习}：上面用 @racket[flip] 在 @racket[neg] 和 @racket[cps] 之间来回。反过来，只用 @racket[neg] 和 @racket[cps]，写出 @racket[flip]。提示：先想想 @racket[(cps id)] 做了什么。

@section[#:tag "02:position"]{计算的位置}

@racket[neg] 的类型只说它在@tech{延续}类型之间映射。@math{¬@ty{Natural}} 里装的是一条条具体的@tech{延续}；一步计算，怎样把其中两条联系起来？

回头看@xref["02:cps"]{「延续与 CPS」}里 @racket[(fact/k 3 k)] 的展开。每递归一层，新的@tech{延续}都是在旧的前面复合一次乘法：@racket[k] 换成 @racket[(∘ k mul3)]，再换成 @racket[(∘ k mul3 mul2)]。收一条@tech{延续}，在它前面复合一个函数，交出另一条@tech{延续}，这正是 @racket[neg] 做的事：@racket[(neg f)] 收到等 @math{q} 的@tech{延续}，交出等 @math{p} 的@tech{延续}。照这个意思重写 @racket[neg]，得到的和前面的定义是同一个函数，只是可变参数交给 @racket[∘] 去处理：

@examples[#:eval ev #:label #f #:no-prompt
(define ((neg f) kq) (∘ kq f))]

于是递归的每一层都是一次 @racket[neg]：第一层用 @racket[(neg mul3)]，第二层用 @racket[(neg mul2)]，第三层用 @racket[(neg mul1)]。递归到底时的那条链，就是三次 @racket[neg] 依次用在 @racket[k] 上：

@racketblock[
#,(hspace 2)(∘ k mul3 mul2 mul1)
= ((neg mul1) ((neg mul2) ((neg mul3) k)))
= ((∘ (neg mul1) (neg mul2) (neg mul3)) k)]

@racket[(neg mul3)] 最先用，@racket[mul3] 紧挨着 @racket[k]；@racket[(neg mul1)] 最后用，@racket[mul1] 排在最前。几次 @racket[neg] 用 @racket[∘] 接起来，次序和里面的乘法正好相反。整条@tech{闭包链}从 @racket[k] 开始，一环环向内建起来。@racket[k] 是出口，也就是这段计算的@tech{终结延续}：@racket[(fact/k 3 k)] 若就是整个程序，它就是程序的出口，第一篇里的 @racket[exit]；启动时交进去的若是@tech{终结延续} @racket[a->⊥]，它就是 @racket[a->⊥]。

以上是链的构造。运行时，值又怎样沿着它走？@xref["02:anf"]{「求值顺序与 ANF」}说过，@racket[let*] 就是复合。反过来，把这条@tech{闭包链}拆回 @racket[let*]，给中间结果起名，值从 @racket[v0] 出发：

@racketblock[
#,(hspace 2)((∘ k mul3 mul2 mul1) v0)
= (let* ([v1 (mul1 v0)]
         [v2 (mul2 v1)]
         [v3 (mul3 v2)])
    (k v3))]

每个名字处都有一条@tech{延续}在等它：等 @racket[v3] 的是 @racket[k]，等 @racket[v2] 的是先乘 3 再交给 @racket[k]，依次类推。把等 @racket[vn] 的那一条记作 @racket[kn]：

@racketblock[
k3  =  (∘ k               )
k2  =  (∘ k mul3          )
k1  =  (∘ k mul3 mul2     )
k0  =  (∘ k mul3 mul2 mul1)]

@racket[v0] 是递归到底交来的 @racket[1]，@racket[vn] 正是 @racket[(fact n)] 的值。这些@tech{延续}的类型都是 @math{¬@ty{Natural}}，每一条都是这个类型的一个具体的值，各自标出程序运行到的一个位置：等到 @racket[vn] 以后，还要乘上哪几个数，再交给 @racket[k]。第一篇 @racket[(label)] 捕获的「当前位置」，就是这样一条@tech{延续}。@racket[let*] 的每个绑定处都有一条；直接风格的 @racket[fact] 里，它们一样在，只是藏在嵌套的 @racket[let] 里。

相邻两个位置之间，隔着一步计算。从 @racket[k2] 到 @racket[k3]，中间一步是 @racket[mul3]：@racket[k2] 拿到值，先乘 3，再交给 @racket[k3]。用 @racket[neg] 写出来：

@racketblock[
k2  =  (∘ k3 mul3)  =  ((neg mul3) k3)]

@racket[(neg mul3)] 的类型 @math{¬@ty{Natural} → ¬@ty{Natural}} 说的是它在两个@tech{延续}类型之间映射；这里交给它的是一个具体的值 @racket[k3]，交出的是另一个具体的值 @racket[k2]：它把一个位置上的@tech{延续}，映射成另一个位置上的@tech{延续}。一般地，一步 @racket[f] 从 @math{p} 算到 @math{q}。等 @math{p} 的@tech{延续}记作 @racket[kp]，等 @math{q} 的记作 @racket[kq]，这一步前后的两个位置就满足 @c{kp = ((neg f) kq)}，也就是 @racket[(∘ kq f)]：前一处的@tech{延续}，正是这一步接上后一处的@tech{延续}。

这条等式从右往左读，是构造：@racket[(neg f)] 收到后一处的@tech{延续}，交出前一处的@tech{延续}。前面那条@tech{闭包链}就是这样建起来的，从出口 @racket[k3] 开始，一步步往前得到 @racket[k2]、@racket[k1]、@racket[k0]。

从左往右读，是运行：@racket[(kp p)] 就是 @racket[(kq (f p))]，值走完 @racket[f] 这一步，等着它的@tech{延续}就从 @racket[kp] 换成了 @racket[kq]。递归到底，@racket[1] 作为 @racket[v0] 交给 @racket[k0]，@racket[let*] 一行行往下：过 @racket[mul1] 到 @racket[k1]，过 @racket[mul2] 到 @racket[k2]，过 @racket[mul3] 得到 @racket[6]，到 @racket[k3]，也就是出口。

两种读法方向相反，起止却是同一条：出口的那条@tech{延续}，既是@tech{延续}构造的起点，也是值移动的终点：计算开始时交进来的是它，计算最后抵达的也是它。执行一个程序，就是沿着@tech{闭包链}，从一个位置走到下一个位置。

@section[#:tag "02:k-in-hand"]{手中的延续}

第一篇用 @racket[cc] 实现 @racket[call/cc]：先由 @racket[(cc)] 取得当前@tech{延续}，再把它交给 @racket[proc]。在 @tech[#:key "延续传递风格"]{CPS} 里，这一步不必做。@xref["02:first-class-control"]{「一等控制」}说过，当前@tech{延续}已经是一个显式的参数：照 @racket[cps] 的写法也好，照 @racket[neg] 的写法也好，函数收到的@tech{延续}参数，就是这次调用之后要做的事。那么照这两种写法，@racket[call/cc] 该怎么写？

@margin-note{@defsym["cps:f" "照 cps 的写法：(cps f)"]@defsym["neg:f" "照 neg 的写法：(neg f)"]名字的前缀标出写法：@racket[cps:kp] 就是 @racket[(cps kp)]，@racket[neg:kp] 就是 @racket[(neg kp)]；以后 @racket[cps:f]、@racket[neg:f] 都照这个约定。@racket[cps:call/cc]、@racket[neg:call/cc] 是例外：它们照两种写法重写了 @racket[call/cc] 的意思，不是 @racket[(cps call/cc)]、@racket[(neg call/cc)]。}

照 @racket[call/cc] 自己的意思写，先看它收到什么。@racket[cps:call/cc] 照 @racket[cps] 的写法，先收到输入 @racket[cps:proc]，再收到@tech{延续} @racket[kp]；@racket[neg:call/cc] 照 @racket[neg] 的写法，次序反过来，先收到 @racket[kp]，再收到 @racket[neg:proc]：

@racketblock[
(define ((cps:call/cc cps:proc) kp) ...)
(define ((neg:call/cc kp) neg:proc) ...)]

@racket[kp] 就是当前@tech{延续}，要交给 @racket[proc]。可 @racket[proc] 照哪种写法写成，它里面的每一次函数调用就都守哪种写法的规矩，调用交给它的@tech{延续}也不例外。@racket[cps:proc] 里调用的函数都先收值、再收@tech{延续}，交给它的@tech{延续}也得这样调用，所以给它的是 @racket[(cps kp)]，记作 @racket[cps:kp]；@racket[neg:proc] 照 @racket[neg] 的写法，给它的是 @racket[(neg kp)]，记作 @racket[neg:kp]。两个定义写完整：

@examples[#:eval ev #:label #f #:no-prompt
(define ((cps:call/cc cps:proc) kp) ((cps:proc (cps kp)) kp))
(define ((neg:call/cc kp) neg:proc) ((neg:proc kp) (neg kp)))]

两行里都有两份 @racket[kp]，角色不同：提升过的那一份交给 @racket[proc] 当参数，@racket[proc] 调用它，就是逃逸；原样的那一份接住 @racket[proc] 正常交回的结果。

跑一个很短的例子。在 @racket[cps:call/cc] 后面接一步加 1，交给它的 @racket[proc] 不理会收到的@tech{延续}，只算 @racket[2] 乘 @racket[3]。后面那一步加 1 也得写成@tech{延续}：拿到结果，加 1，再交给@tech{终结延续}：

@examples[#:eval ev #:label #f
(define (cps:proc1 cps:k) ((cps *) 2 3))
(⊥->a ((cps:call/cc cps:proc1) (λ (v) (a->⊥ (add1 v)))))]

@racket[cps:proc1] 正常交回 @racket[6]。原样的那份 @racket[kp]，也就是手写的那个 @racket[λ]，接住它，先加 1，再交给@tech{终结延续}，得到 @racket[7]。

换一个 @racket[proc]，让它用上收到的@tech{延续}：先把 @racket[10] 交给 @racket[cps:k]，再加 1。@racket[cps:k] 收到 @racket[10]，交出的仍是一段等着@tech{延续}的计算，后面的加 1 只能再手写一个@tech{延续}接上：

@examples[#:eval ev #:label #f
(define (cps:proc2 cps:k) (λ (k) ((cps:k 10) (λ (v) (k (add1 v))))))
(⊥->a ((cps:call/cc cps:proc2) (λ (v) (a->⊥ (add1 v)))))]

结果是 @racket[11]，不是 @racket[12]。@racket[cps:k] 是提升过的 @racket[kp]，一调用，计算就改走 @racket[kp]：外面那一步加 1，然后是@tech{终结延续}。@racket[cps:proc2] 里排在后面的那一步加 1，再也轮不到。这正是第一篇里 @racket[call/cc] 的行为：调用交出去的@tech{延续}，就是丢下手头的工作，回到 @racket[call/cc] 之后。

@bold{练习}：用 @racket[neg:call/cc] 把这两个例子各跑一遍，结果仍是 @racket[7] 和 @racket[11]。提示：@racket[neg] 的写法先收@tech{延续}，再收输入；外面那一步加 1，用 @racket[(neg add1)] 接在@tech{终结延续}前面。

这么短的两个例子，@tech{延续}却得一个个手写：外面的加 1 一个，@racket[cps:proc2] 里又一个。@xref["02:first-class-control"]{「一等控制」}那句抱怨，到这里更重了：每个@tech{延续}都得亲手写。

回想@xref["02:anf"]{「求值顺序与 ANF」}里的观察。@racket[let] 脱糖为 @racket[lambda] 调用，@tech{延续}藏在 @racket[let] 里面：等待结果的那个 @racket[λ] 不用我们写，绑定的语法替我们写了。@tech{CPS 变换}把@tech{延续}拉出来变成显式参数，这个 @racket[λ] 就得亲手写。能不能反过来：用 @racket[let] 语法把 @tech[#:key "延续传递风格"]{CPS} 的@tech{延续}再藏回去？
