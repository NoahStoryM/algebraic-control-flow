#lang acf/scribble

@title[#:tag "01:3-substitution"]{代入具体的类型}

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define-type ⊥ (∪))
(define-type (¬ p) (→ p ⊥))]

@xref["01:watershed"]{「分水岭」}从定律出发找程序。这一小篇接着从定律出发，换一个办法：代入。

逻辑里，一条定律对任何命题都成立；把一个具体的命题代进去，就得到它的一个实例。在程序里，就是给类型参数 @math{p} 填上一个具体的类型。直觉主义定律的实例，本来就能用 @racket[λ] 写出。经典定律不同：@racket[call/cc] 要对每一个 @math{p} 都管用，只好去捕获当前@tech{延续}。可要是 @math{p} 只是某一个具体的类型，手里也许就有别的办法。把几个具体的类型代进 DNE @math{¬¬p → p}，看看哪些要捕获，哪些不用。

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

所以程序是一个 @math{¬¬@ty{Byte}}：它等着计算终结处的那条@tech{延续}。真实的操作系统也是这样运行程序的：启动一个程序时，退出通道已经在那里了，就是 @racket[exit]，背后是 OS 提供的退出调用。程序交回退出码有两种方式：显式地调用 @racket[exit]，或者从 @racket[main] 返回；C 语言规定后者等于拿返回值调用 @racket[exit]，正是上面外层那个 @racket[(exit …)]。对程序内部，调用 @racket[exit] 不再返回；对外部，OS 接到了退出码。OS 承担的是外部运行环境的角色：提供出口，接收结果。@racket[exit] 在程序体里是交来的假设，在 @racket[(λ (exit) …)] 里则被绑定。把计算运行起来、在出口接收结果的整个过程，对应@xref["01:watershed"]{「分水岭」}里的 DNE；这个过程不是语言里的某个函数，是运行环境本身。和 @racket[call/cc] 的区别，在谁来提供这条@tech{延续}：多数语言本身只提供 @racket[exit]，由 OS 从外面交来，语言里什么也不用捕获；有了 @racket[call/cc]，没有 @racket[exit] 也能像上面那样自己捕获出来。

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

交出去的 @racket[kq] 等一个 @racket[q]。等 @racket[q] 交来，手里就有了 @racket[q] 和 @racket[kkkq]。@racket[kkkq] 等的是一个 @math{¬¬q}，@racket[q] 还差两个否定；用一次 DNI，加上两层否定：@racket[kkq] 等一条否定 @math{q} 的@tech{延续} @racket[k]，正是 @math{¬¬q}，交给 @racket[kkkq]。只有 @racket[λ] 和函数调用，什么也没有捕获。

试一试。用 @racket[let/cc] 拿到一条真正的@tech{延续} @racket[k]，照 DNI 的写法包成一个 @racket[kkkq]，交给 @racket[triple-negation] 取回一个 @math{¬q}，再把 @racket[q] 交给它：

@examples[#:eval ev #:label #f
(define q 'hello)
(let/cc k
  (define (kkkq kkq) (kkq k))
  (let ([kq (triple-negation kkkq)])
    (kq q)))]

@racket[q] 经取回的 @racket[kq] 交到了 @racket[let/cc] 返回的地方，一路是 @racket[(kq q)]、@racket[(kkkq kkq)]、@racket[(kkq k)]、@racket[(k q)]。取回的 @racket[kq] 和 @racket[k] 不是同一个值，行为却一样：先用 DNI 包一层，再用三重否定律取回，回到了原样。定义里 @racket[kkq] 的形参 @racket[k]，这次收到的也正是这个 @racket[k]。

@math{¬¬¬q → ¬q} 这条定律叫@defterm[#:en "law of triple negation"]{三重否定律}，是一条直觉主义定理。

@section[#:tag "01:layers"]{否定塔}

@racket[triple-negation] 里的几个名字，@racket[q]、@racket[kq]、@racket[kkq]、@racket[kkkq]，差的只是外面叠了几个否定。数一数，刚才的做法能说得更清楚。

固定一个类型 @math{A}，把 @math{A} 本身算作第 0 层，@math{¬A} 算作第 1 层，@math{¬¬A} 算作第 2 层，依此类推：多一层的类型，正是「接收少一层的值、结果为 @math{⊥}」的函数类型。谈论同一座否定塔的时候，@math{A} 要固定下来，只数它外面包了几层，不去拆它的内部。名字也替我们数：一个值叫 @racket[v]，等它的@tech{延续}就叫 @racket[kv]，等 @racket[kv] 的就叫 @racket[kkv]，名字里有几个 @racket[k]，就比 @racket[v] 多几层。

@xref["01:watershed"]{「分水岭」}里的四条定律，用层数说就是：

@itemlist[
  @item{@tech{矛盾律}：第 @math{n+1} 层与第 @math{n} 层相遇，得到 @math{⊥}。}
  @item{DNI：加两层，从第 @math{n} 层升到第 @math{n+2} 层。}
  @item{DNE：减两层，从第 @math{n+2} 层落到第 @math{n} 层。}
  @item{@tech{排中律}：交出相邻两层之一，第 @math{n} 层或第 @math{n+1} 层。}]
以 @math{q} 为底，@racket[triple-negation] 从第 3 层减到第 1 层：第 0 层的 @racket[q] 用 DNI 升到第 2 层，正好与第 3 层的 @racket[kkkq] 相邻。

接下来要比较的是，哪些层能互相推出，哪些不能。层数先带出一个规律。DNI、DNE 一次加减两层，不改变奇偶，@tech{矛盾律}却要一奇一偶。奇偶不同的两个值，把低的那个反复做 DNI，总能升到与另一个相邻，再调用，@racket[triple-negation] 就是这样做的。例如第 0 层与第 5 层：第 0 层用 DNI 升到第 2 层，再升到第 4 层，就与第 5 层相邻，交给它，得到 @math{⊥}。奇偶相同的两个，只靠 DNI、DNE 凑不成相邻。

回到@xref["01:watershed"]{「分水岭」}留下的问题：从 @math{¬¬p} 取出 @math{p}，非得凭空拿到一个@tech{延续}不可吗？不一定。@xref["01:program-type"]{「代入 Byte」}里，那条@tech{延续}由 OS 交来；@racket[triple-negation] 更省事，不需要另外交来一条 @math{¬q}，它交出的 @math{¬q}，用交进来的 @racket[kkkq] 就做成了。

用层数说，区别在要交出的东西落在哪一层。落在第 1 层或更高，要交出的是一个函数，可以先交出去，等下一层的值来了再算。落到第 0 层，就得当场交出一个值，这时就没有对任何类型都适用的纯 @racket[λ] 写法了；要把计算真的跑起来，又不捕获，就得像运行程序那样，由外面交来一条@tech{延续}。

层数也照出了两种逻辑的分别。把能互相推出的层归为一类；这里按对任意底类型 @math{A} 都成立的互推来归类，不利用 @math{A} 的额外性质：

@itemlist[
  @item{经典逻辑里，DNI 加两层，DNE 减两层，相差两层的都能互推，一座塔只剩两类：偶数层，奇数层。}
  @item{直觉主义逻辑里，DNE 一般不成立，但三重否定律能从第 3 层回到第 1 层；把其中的 @math{q} 换成 @math{¬A}，就从第 4 层回到第 2 层；依此类推。只有第 0 层一般回不去：那要用 DNE，@xref["01:watershed"]{「分水岭」}里试过，对任意类型写不出来。塔分成三类：第 0 层，奇数层，第 2 层起的偶数层。}]
最低的五层排出来：

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list @elem{层} @elem{经典逻辑} @elem{直觉主义逻辑})
   (list @elem{0} @elem{偶数层：与 2、4 层经 DNI、DNE 互推}
         @elem{单独一类：DNI 升到第 2 层，一般不能落回})
   (list @elem{1} @elem{奇数层} @elem{奇数层：DNI 升到第 3 层，三重否定律落回})
   (list @elem{2} @elem{偶数层} @elem{第 2 层起的偶数层：与第 4 层互推})
   (list @elem{3} @elem{奇数层} @elem{奇数层})
   (list @elem{4} @elem{偶数层} @elem{第 2 层起的偶数层：三重否定律落回第 2 层}))]

在这座否定塔上，两种逻辑的区别，就在第 0 层是否与其余的偶数层合并。

