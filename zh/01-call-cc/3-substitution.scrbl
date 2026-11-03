#lang acf/scribble

@title[#:tag "01:3-substitution"]{代入具体的类型}

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define-type ⊥ (∪))
(define-type (¬ p ...) (→ p ... ⊥))]

@xref["01:watershed"]{「分水岭」}从定律出发找程序。这一节接着从定律出发，换一个办法：代入。

逻辑里，一条定律对任何命题都成立；把一个具体的命题代进去，就得到它的一个实例。在程序里，就是给类型参数 @math{p} 填上一个具体的类型。直觉主义定律的实例，本来就能用 @racket[λ] 写出。经典定律不同：@racket[call/cc] 要对每一个 @math{p} 都管用，只好去捕获当前@tech{延续}。可要是 @math{p} 只是某一个具体的类型，手里也许就有别的办法。把几个具体的类型代进 @tech[#:key "双重否定消除"]{DNE} @math{¬¬p → p}，看看哪些要捕获，哪些不用。

@section[#:tag "01:program-type"]{代入 Byte}

先代入最朴素的一个：退出码的类型 @racket[Byte]，得到 @math{¬¬@ty{Byte} → @ty{Byte}}。选它，是因为程序最后交出的就是退出码；顺着它会看到，@tech{延续}不一定靠捕获，也可以由运行环境交来。这一回既看类型能不能填上，也看能不能留住交进来的计算的行为。光看类型，@racket[(λ (kk) 0)] 就填上了，什么也不捕获。逻辑上也不奇怪：@racket[Byte] 类型有元素，是真命题，从任何前提推出它都成立，丢掉前提、直接拿出一个 @racket[Byte] 就是证明。

可逻辑只问命题真不真，不问拿出的是哪一个 @racket[Byte]；@racket[0] 和程序算出来的退出码，在它眼里没有分别。我们却在乎。

@racket[(λ (kk) 0)] 根本不理会交给它的那个 @math{¬¬@ty{Byte}}；我们要的实例，得真把那个 @math{¬¬@ty{Byte}} 跑起来，交出它给出的那个 @racket[Byte]。这是运行的行为，类型里看不出来。

要找这样的实例，先得知道一个 @math{¬¬@ty{Byte}} 长什么样。最常见的，就是一个程序：它算出一个退出码，交给 @racket[exit]，然后结束。要看清 @racket[exit] 从哪里来，假设我们的语言有 @racket[call/cc] 但没有内置的 @racket[exit]，把整个程序包在 @racket[call/cc] 里：

@racketblock[
(call/cc (λ (exit) (exit ...程序体...)))]

@racket[call/cc] 交给 @racket[λ] 的，是它被调用处的当前@tech{延续}。这个 @racket[call/cc] 包着整个程序，它返回以后什么也不剩，所以这条@tech{延续}通向的就是计算终结的地方：交给它一个退出码，整个计算到此结束。这就是 @racket[exit]，计算终结时的当前@tech{延续}。程序体里任何地方调用 @racket[(exit 0)]，都直接跳到终点；程序体正常算完，结果也经外层的 @racket[exit] 交过去。

@racket[exit] 等一个退出码，类型是 @math{¬@ty{Byte}}。@racket[(λ (exit) (exit ...))] 等一个 @racket[exit]，无论走哪条路，结果都经 @racket[exit] 交出，自己从不正常返回，类型是 @math{¬¬@ty{Byte}}。外层那个 @racket[(exit …)] 不能省。少了它，程序体正常结束时，这个函数会把结果正常返回，它的类型就成了 @math{¬@ty{Byte} → @ty{Byte}}，而不是 @math{¬@ty{Byte} → ⊥}，也就不再是 @math{¬¬@ty{Byte}}。

把等着出口的计算记作 @racket[program]，上面的做法就是 @racket[(λ (program) (call/cc program))]：它把当前@tech{延续}作为 @racket[exit] 交给 @racket[program]，并在这里接到退出码。

所以程序是一个 @math{¬¬@ty{Byte}}：它等着计算终结处的那条@tech{延续}。真实的操作系统也是这样运行程序的：启动一个程序时，退出通道已经在那里了，就是 @racket[exit]，背后是 OS 提供的退出调用。程序交回退出码有两种方式：显式地调用 @racket[exit]，或者从 @racket[main] 返回；C 语言规定后者等于拿返回值调用 @racket[exit]，正是上面外层那个 @racket[(exit …)]。对程序内部，调用 @racket[exit] 不再返回；对外部，OS 接到了退出码。OS 承担的是外部运行环境的角色：提供出口，接收结果。@racket[exit] 在程序体里是交来的假设，在 @racket[(λ (exit) …)] 里则被绑定。把计算运行起来、在出口接收结果的整个过程，对应@xref["01:watershed"]{「分水岭」}里的 @tech[#:key "双重否定消除"]{DNE}；这个过程不是语言里的某个函数，是运行环境本身。和 @racket[call/cc] 的区别，在谁来提供这条@tech{延续}：多数语言本身只提供 @racket[exit]，由 OS 从外面交来，语言里什么也不用捕获；有了 @racket[call/cc]，没有 @racket[exit] 也能像上面那样自己捕获出来。

@section[#:tag "01:neg-q"]{代入 ¬q}

再换一个类型，看看否定叠起来时会怎样。不代入一个光秃秃的类型，而是代入一个本身就是否定的类型 @math{¬q}：

@mm{¬¬¬q → ¬q}

手里是一个 @math{¬¬¬q}，叫它 @racket[kkkq]，要交出一个 @math{¬q}。@math{¬q} 是一个函数，等一个 @racket[q]，那就先把这个函数交出去：

@examples[#:eval ev #:label #f #:no-prompt
(define-type (¬¬  q) (¬ (¬  q)))
(define-type (¬¬¬ q) (¬ (¬¬ q)))

(: triple-negation (∀ (q) (→ (¬¬¬ q) (¬ q))))
(define (triple-negation kkkq)
  (define (kq q)
    (define (kkq k) (k q))
    (kkkq kkq))
  kq)]

交出去的 @racket[kq] 等一个 @racket[q]。等 @racket[q] 交来，手里就有了 @racket[q] 和 @racket[kkkq]。@racket[kkkq] 等的是一个 @math{¬¬q}，@racket[q] 还差两个否定；用一次 @tech[#:key "双重否定引入"]{DNI}，加上两层否定：@racket[kkq] 等一条否定 @math{q} 的@tech{延续} @racket[k]，正是 @math{¬¬q}，交给 @racket[kkkq]。只有 @racket[λ] 和函数调用，什么也没有捕获。

试一试。用 @racket[let/cc] 拿到一条真正的@tech{延续} @racket[k]，照 @tech[#:key "双重否定引入"]{DNI} 的写法包成一个 @racket[kkkq]，交给 @racket[triple-negation] 取回一个 @math{¬q}，再把 @racket[q] 交给它：

@examples[#:eval ev #:label #f
(define q 'hello)
(let/cc k
  (define (kkkq kkq) (kkq k))
  (let ([kq (triple-negation kkkq)])
    (kq q)))]

@racket[q] 经取回的 @racket[kq] 交到了 @racket[let/cc] 返回的地方，一路是 @racket[(kq q)]、@racket[(kkkq kkq)]、@racket[(kkq k)]、@racket[(k q)]。取回的 @racket[kq] 和 @racket[k] 不是同一个值，行为却一样：先用 @tech[#:key "双重否定引入"]{DNI} 包一层，再用三重否定律取回，回到了原样。定义里 @racket[kkq] 的形参 @racket[k]，这次收到的也正是这个 @racket[k]。

@math{¬¬¬q → ¬q} 这条定律叫@defterm[#:en "law of triple negation"]{三重否定律}，是一条直觉主义定理。

@section[#:tag "01:layers"]{否定塔}

@racket[triple-negation] 里的几个名字，@racket[q]、@racket[kq]、@racket[kkq]、@racket[kkkq]，差的只是外面叠了几个否定。数一数，刚才的做法能说得更清楚。

以 @racket[q] 为底，把 @racket[q] 算作第 0 层。@racket[kq] 等一个 @racket[q]，是第 1 层；@racket[kkq] 等一个 @racket[kq]，是第 2 层；@racket[kkkq] 等一个 @racket[kkq]，是第 3 层。多一层的类型，正是「接收少一层的值、结果为 @math{⊥}」的函数类型；名字替我们数着，有几个 @racket[k]，就比底多几层。

@racket[triple-negation] 收下第 3 层的 @racket[kkkq]，交出第 1 层的 @racket[kq]。@racket[kq] 拿到第 0 层的 @racket[q] 以后做了两件事：先把 @racket[q] 包成 @racket[kkq]，从第 0 层升到第 2 层；再把 @racket[kkq] 交给 @racket[kkkq]，第 3 层与第 2 层相遇，得到 @math{⊥}。

这两步，正是@xref["01:watershed"]{「分水岭」}里的两条构造性定律：@tech[#:key "双重否定引入"]{DNI} 加两层，从第 @math{n} 层升到第 @math{n+2} 层；@tech{矛盾律}让第 @math{n+1} 层与第 @math{n} 层相遇，得到 @math{⊥}。另外两条经典定律，也有层数的说法：@tech[#:key "双重否定消除"]{DNE} 减两层，从第 @math{n+2} 层落到第 @math{n} 层；@tech{排中律}交出相邻两层之一，第 @math{n} 层或第 @math{n+1} 层。

一般地，固定一个类型 @math{A}，把 @math{A} 本身算作第 0 层，@math{¬A} 算作第 1 层，@math{¬¬A} 算作第 2 层，依此类推。谈论同一座否定塔的时候，@math{A} 要固定下来，只数它外面包了几层，不去拆它的内部。

层数带出一个规律。@tech[#:key "双重否定引入"]{DNI}、@tech[#:key "双重否定消除"]{DNE} 一次加减两层，不改变奇偶；@tech{矛盾律}却要一奇一偶。@racket[q] 在第 0 层，@racket[kkkq] 在第 3 层，奇偶不同，@racket[triple-negation] 把低的那个升两层，两者就相邻了。奇偶不同的两个，总能这样把低的那个一次次升两层，直到相邻再调用；奇偶相同的两个，只靠 @tech[#:key "双重否定引入"]{DNI}、@tech[#:key "双重否定消除"]{DNE} 凑不成相邻。

回到@xref["01:watershed"]{「分水岭」}留下的问题：从 @math{¬¬p} 取出 @math{p}，非得凭空拿到一个@tech{延续}不可吗？不一定。@xref["01:program-type"]{「代入 Byte」}里，那条@tech{延续}由 OS 交来；@racket[triple-negation] 更省事，它交出的 @math{¬q}，用交进来的 @racket[kkkq] 就做成了，不需要另外交来一条。

用层数说，区别在要交出的东西落在哪一层。@racket[triple-negation] 交出的落在第 1 层，是一个函数，可以先交出去，等第 0 层的值来了再算。落到第 0 层，就得当场交出一个值，这时就没有对任何类型都适用的纯 @racket[λ] 写法了；要把计算真的跑起来，又不捕获，就得像运行程序那样，由外面交来一条@tech{延续}。

@subsection[#:tag "01:two-logics"]{两种逻辑}

层数也照出了两种逻辑的分别。把能互相推出的层归为一类；这里按对任意底类型 @math{A} 都成立的互推来归类，不利用 @math{A} 的额外性质。

经典逻辑里，@tech[#:key "双重否定引入"]{DNI} 加两层，@tech[#:key "双重否定消除"]{DNE} 减两层，相差两层的都能互推，一座塔只剩两类：偶数层，奇数层。直觉主义逻辑里，@tech[#:key "双重否定消除"]{DNE} 一般不成立，往下落要靠@tech{三重否定律}：它从第 3 层回到第 1 层；把其中的 @math{q} 换成 @math{¬A}，就从第 4 层回到第 2 层，依此类推。只有第 0 层一般回不去，那要用 @tech[#:key "双重否定消除"]{DNE}，@xref["01:watershed"]{「分水岭」}里试过，对任意类型写不出来。塔于是分成三类：第 0 层，奇数层，第 2 层起的偶数层。最低的五层排出来：

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list @elem{层} @elem{经典逻辑} @elem{直觉主义逻辑})
   (list @elem{0} @elem{偶数层：与 2、4 层经 @tech[#:key "双重否定引入"]{DNI}、@tech[#:key "双重否定消除"]{DNE} 互推}
         @elem{单独一类：@tech[#:key "双重否定引入"]{DNI} 升到第 2 层，一般不能落回})
   (list @elem{1} @elem{奇数层} @elem{奇数层：@tech[#:key "双重否定引入"]{DNI} 升到第 3 层，@tech{三重否定律}落回})
   (list @elem{2} @elem{偶数层} @elem{第 2 层起的偶数层：与第 4 层互推})
   (list @elem{3} @elem{奇数层} @elem{奇数层})
   (list @elem{4} @elem{偶数层} @elem{第 2 层起的偶数层：@tech{三重否定律}落回第 2 层}))]

在这座否定塔上，两种逻辑的区别，就在第 0 层是否与其余的偶数层合并：从上面落回第 0 层，只有经典逻辑做得到。

不过，要是从第 2 层取出第 0 层的值，只是为了马上交给一条等着它的@tech{延续}，最后照样是相邻两层相遇，调用一次@tech{延续}。让两层相遇，构造性的办法也有。经典逻辑绕到第 0 层的这一步，和它们有没有区别？

@subsection[#:tag "01:pairing"]{三种配对}

手里有一段等着@tech{延续}的计算 @racket[kkp]，在第 2 层；又有一条等着 @math{p} 的@tech{延续} @racket[kp]，在第 1 层。让它们相遇，有三种办法。

第一种最直接。两者相邻，把低一层的交给高一层，@racket[(kkp kp)]，这就是@tech{矛盾律}。前面见过的配对都是这个样子：@racket[triple-negation] 里的 @racket[(kkkq kkq)]，第 3 层遇上第 2 层；@racket[kkq] 里的 @racket[(k q)]，第 1 层遇上第 0 层。

第二种先往上走。用 @tech[#:key "双重否定引入"]{DNI} 把第 1 层的 @racket[kp] 升到第 3 层，再和第 2 层的 @racket[kkp] 相遇，@racket[triple-negation] 把 @racket[q] 升成 @racket[kkq]，也是这样做的：

@racketblock[
(define (kkkp kkp) (kkp kp))
(kkkp kkp)]

照定义展开一步，@racket[(kkkp kkp)] 就是 @racket[(kkp kp)]，和第一种是同一个计算。这两种只用到交到手里的东西，是构造性的。

第三种往下走，只有经典逻辑做得到：用 @tech[#:key "双重否定消除"]{DNE} 把第 2 层的 @racket[kkp] 落到第 0 层，取出 @math{p}，再和第 1 层的 @racket[kp] 相遇，@racket[(kp p)]。@tech[#:key "双重否定消除"]{DNE} 用 @racket[call/cc] 写：

@racketblock[
(let ([p (call/cc kkp)]) (kp p))]

绕到第 0 层的这一种，和前两种有没有区别？拿一个具体的 @racket[kkp] 试，@racket[kp] 用 @racket[let/cc] 捕获。外面的 @racket[(+ 10 …)]、@racket[(+ 100 …)] 让跳没跳走看得见：

@examples[#:eval ev #:label #f
(define p 5)
(define (kkp k) (k p))
(+ 100 (let/cc kp (+ 10 (kkp kp))))
(+ 100 (let/cc kp (+ 10 (let ([p (call/cc kkp)]) (kp p)))))]

两行都是 @racket[105]：@racket[5] 交给 @racket[kp]，跳回 @racket[let/cc] 返回的地方，加十那一步跳过了。

这个 @racket[kkp] 是用 @tech[#:key "双重否定引入"]{DNI} 把 @racket[5] 升到第 2 层得来的，和 @racket[triple-negation] 里的 @racket[kkq] 一个样子，第三种办法把它取了回来。一步步改写，看得更清楚：

@racketblock[
#,(hspace 2)(call/cc kkp)
= (call/cc (λ (k) (k p)))
= (let/cc k (k p))
= (let/cc k p)
= p]

前两步照定义展开。第三步用的是@xref["01:call-cc-types"]{「call/cc 的几种类型」}里的道理：@racket[p] 算出一个值，显式跳到 @racket[k] 和正常返回，去的是同一个出口。第四步，@racket[k] 已经用不到，捕获也就可以省去。取回的 @racket[p] 再交给 @racket[kp]，就是 @racket[(kp 5)]，和第一种一样。

一般的 @racket[kkp] 不一定这样展得开。把它写成 @racket[(λ (k) body)]，第三种去掉中间的名字 @racket[p]，和第一种并排：

@racketblock[
(kp (call/cc kkp))  =  (kp (let/cc k body))
(kkp kp)            =  ((λ (k) body) kp)]

差别只在 @racket[body] 拿到的是哪一条@tech{延续}：第一行拿到这里捕获的 @racket[k]，第二行直接拿到外面的 @racket[kp]。

看这两个出口接下来做什么。假设 @racket[body] 在某处调用 @racket[(k 5)]。第一行先丢下 @racket[body] 剩下的工作，把 @racket[5] 送回 @racket[let/cc] 的位置，接下来做的正是 @racket[(kp 5)]。第二行就在调用处做 @racket[(kp 5)]；@racket[kp] 不回来，@racket[body] 剩下的工作同样走不到。即使 @racket[body] 是 @racket[(+ 10 (k 5))]，两边的加十也都走不到。所以这里不要求 @racket[body] 在尾位置调用 @racket[k]。

两个不返回，各管一处。@racket[kp] 是 @math{¬p}，调用以后不回来，第二行里 @racket[body] 剩下的工作才走不到。@racket[kkp] 是 @math{¬¬p}，也不向调用处返回：要是 @racket[body] 正常返回 @racket[7]，第一行还会接着做 @racket[(kp 7)]，第二行却直接交回 @racket[7]，两条路就分开了。@racket[kkp] 不必真的调用参数，从别的出口离开，或者一直算下去，也都守这个约定。会正常返回的函数，类型不是否定，不在这座塔上。

@margin-note{第一行先回到捕获的地方，才调用 @racket[kp]；第二行就在调用处调用 @racket[kp]。程序若用 @racket[continuation?] 分辨收到的是不是原生的@tech{延续}，或者借异常处理器这类动态环境分辨这两个位置，也能把它们分开。}

在只通过调用使用@tech{延续}、也不借动态环境分辨这两个位置的程序里，第三种和前两种行为相同：绕到第 0 层，什么也没有多出来。手里已经有 @racket[kp]，要做的只是把结果交给它，直接写 @racket[(kkp kp)] 就行，不必落到第 0 层。要对任意 @math{p}、任意一段 @racket[kkp]，只凭 @racket[kkp] 统一交出一个 @math{p}，这才是 @tech[#:key "双重否定消除"]{DNE}。
