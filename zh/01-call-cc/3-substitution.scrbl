#lang acf/scribble

@title[#:tag "01:3-substitution"]{代入具体的类型}

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define-type ⊥ (∪))
(define-type (¬ p ...) (→ p ... ⊥))]

@xref["01:watershed"]{「分水岭」}从定律出发找程序。这一节接着从定律出发，换一个办法：代入。

逻辑里，一条定律对任何命题都成立；把一个具体的命题代进去，就得到它的一个实例。在程序里，就是给类型参数 @math{p} 填上一个具体的类型。直觉主义定律的实例，本来就能用 @racket[λ] 写出。经典定律不同：@racket[call/cc] 要对每一个 @math{p} 都管用，只好去捕获当前@tech{延续}。把几个具体的类型代进 @tech[#:key "双重否定消除"]{DNE} @math{¬¬p → p}，看看哪些要捕获，哪些不用。

@section[#:tag "01:program-type"]{代入 Byte}

先代入最朴素的一个：退出码的类型 @racket[Byte]，得到 @math{¬¬@ty{Byte} → @ty{Byte}}。选它，是因为程序最后交出的就是退出码。这一回的实例要满足一个更强的要求：不光类型对，还要留住交进来的计算的行为。光看类型，@racket[(λ (kk) 0)] 就填上了，什么也不捕获。逻辑上也不奇怪：@racket[Byte] 类型有元素，是真命题，从任何前提推出它都成立，丢掉前提、直接拿出一个 @racket[Byte] 就是证明。

可逻辑只问命题真不真，不问拿出的是哪一个 @racket[Byte]；@racket[0] 和程序算出来的退出码，在它眼里没有分别。我们却在乎。

@racket[(λ (kk) 0)] 根本不理会交给它的那个 @math{¬¬@ty{Byte}}；我们要的实例，得真把那个 @math{¬¬@ty{Byte}} 跑起来，交出它给出的那个 @racket[Byte]。这是运行的行为，类型里看不出来。

要找这样的实例，先得知道一个 @math{¬¬@ty{Byte}} 长什么样。最常见的，就是一个程序：它算出一个退出码，交给 @racket[exit]，然后结束。要看清 @racket[exit] 从哪里来，假设我们的语言有 @racket[call/cc] 但没有内置的 @racket[exit]，把整个程序包在 @racket[call/cc] 里：

@racketblock[
(call/cc (λ (exit) (exit ...程序体...)))]

@racket[call/cc] 交给 @racket[λ] 的，是它被调用处的当前@tech{延续}。这个 @racket[call/cc] 包着整个程序，它返回以后什么也不剩，所以这条@tech{延续}通向的就是计算终结的地方：交给它一个退出码，整个计算到此结束。这就是 @racket[exit]，计算终结时的当前@tech{延续}。程序体里任何地方调用 @racket[(exit 0)]，都直接跳到终点；程序体正常算完，结果也经外层的 @racket[exit] 交过去。

@racket[exit] 等一个退出码，类型是 @math{¬@ty{Byte}}。@racket[(λ (exit) (exit ...))] 等一个 @racket[exit]，无论走哪条路，结果都经 @racket[exit] 交出，自己从不正常返回，类型是 @math{¬¬@ty{Byte}}。外层那个 @racket[(exit …)] 不能省。少了它，程序体正常结束时，这个函数会把结果正常返回，它的类型就成了 @math{¬@ty{Byte} → @ty{Byte}}，而不是 @math{¬@ty{Byte} → ⊥}，也就不再是 @math{¬¬@ty{Byte}}。

把等着出口的计算记作 @racket[program]，上面的做法就是 @racket[(λ (program) (call/cc program))]：它把当前@tech{延续}作为 @racket[exit] 交给 @racket[program]，并在这里接到退出码。这就是 @math{¬¬@ty{Byte} → @ty{Byte}} 的一个实例，它真把计算跑了起来，只是用到了 @racket[call/cc]。

所以程序是一个 @math{¬¬@ty{Byte}}：它等着计算终结处的那条@tech{延续}。真实的操作系统也是这样运行程序的：启动一个程序时，出口已经在那里了，就是 @racket[exit]，背后是 OS 提供的退出调用。C 程序交回退出码，可以显式调用 @racket[exit]，也可以从 @racket[main] 返回；C 语言规定后者等于拿返回值调用 @racket[exit]，正是上面外层那个 @racket[(exit …)]。

在语言里写这个实例，要用 @racket[call/cc]；多数语言不这样做，它们的出口由外面交来。把计算运行起来、在出口接收结果，这个过程同样对应 @tech[#:key "双重否定消除"]{DNE}，但它在语言之外，是运行环境本身：OS 提供出口，接收结果。程序体只用到交来的 @racket[exit]，什么也不用捕获。两种做法的区别，在谁来提供这条@tech{延续}：一种由 OS 从外面交来，一种由 @racket[call/cc] 在语言里自己捕获。

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

以 @racket[q] 为底，把 @racket[q] 算作第 0 层。@racket[kq] 等一个 @racket[q]，是第 1 层；@racket[kkq] 等一个 @racket[kq]，是第 2 层；@racket[kkkq] 等一个 @racket[kkq]，是第 3 层。多一层的类型，正是「接收少一层的值、结果为 @math{⊥}」的函数类型；名字替我们数着，有几个 @racket[k]，就比底多几层。一般地，固定一个类型 @math{A}，@math{A} 本身是第 0 层，@math{¬A} 是第 1 层，@math{¬¬A} 是第 2 层，依此类推；谈论同一座否定塔时，只数 @math{A} 外面包了几层，不拆它的内部。

@racket[triple-negation] 收下第 3 层的 @racket[kkkq]，交出第 1 层的 @racket[kq]。@racket[kq] 拿到第 0 层的 @racket[q] 以后做了两件事：先把 @racket[q] 包成 @racket[kkq]，从第 0 层升到第 2 层；再把 @racket[kkq] 交给 @racket[kkkq]，第 3 层与第 2 层相遇，得到 @math{⊥}。

这两步，正是@xref["01:watershed"]{「分水岭」}里的两条构造性定律：@tech[#:key "双重否定引入"]{DNI} 加两层，从第 @math{n} 层升到第 @math{n+2} 层；@tech{矛盾律}让第 @math{n+1} 层与第 @math{n} 层相遇，得到 @math{⊥}。另外两条经典定律，也有层数的说法：@tech[#:key "双重否定消除"]{DNE} 减两层，从第 @math{n+2} 层落到第 @math{n} 层；@tech{排中律}交出相邻两层之一，第 @math{n} 层或第 @math{n+1} 层。

固定底类型，只用 @tech[#:key "双重否定引入"]{DNI}、@tech[#:key "双重否定消除"]{DNE} 和调用，层数带出一个规律。@tech[#:key "双重否定引入"]{DNI}、@tech[#:key "双重否定消除"]{DNE} 一次加减两层，不改变奇偶；@tech{矛盾律}却要一奇一偶。@racket[q] 在第 0 层，@racket[kkkq] 在第 3 层，奇偶不同，@racket[triple-negation] 把低的那个升两层，两者就相邻了。奇偶不同的两个，总能这样把低的那个一次次升两层，直到相邻再调用；奇偶相同的两个，只靠 @tech[#:key "双重否定引入"]{DNI}、@tech[#:key "双重否定消除"]{DNE} 凑不成相邻。

前两次代入的分别，也在落到哪一层：@racket[triple-negation] 交出的在第 1 层，是一个函数，可以等第 0 层的值来了再算；@tech[#:key "双重否定消除"]{DNE} 要落到第 0 层，当场就得有一个值，对任意类型纯 @racket[λ] 做不到，不捕获的话，就得像运行程序那样由外面交来一条@tech{延续}。

@subsection[#:tag "01:two-logics"]{两种逻辑}

层数也照出了两种逻辑的分别。把能互相推出的层归为一类；这里按对任意底类型 @math{A} 都成立的互推来归类，不利用 @math{A} 的额外性质。

经典逻辑里，相差两层的都能互推。直觉主义逻辑里，@tech[#:key "双重否定消除"]{DNE} 一般不成立，往下落要靠@tech{三重否定律}：它从第 3 层回到第 1 层；把其中的 @math{q} 换成 @math{¬A}，就从第 4 层回到第 2 层，依此类推。最低的五层排出来：

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list @elem{层} @elem{经典逻辑} @elem{直觉主义逻辑})
   (list @elem{0} @elem{偶数层：与 2、4 层经 @tech[#:key "双重否定引入"]{DNI}、@tech[#:key "双重否定消除"]{DNE} 互推}
         @elem{单独一类：@tech[#:key "双重否定引入"]{DNI} 升到第 2 层，一般不能落回})
   (list @elem{1} @elem{奇数层} @elem{奇数层：@tech[#:key "双重否定引入"]{DNI} 升到第 3 层，@tech{三重否定律}落回})
   (list @elem{2} @elem{偶数层} @elem{第 2 层起的偶数层：与第 4 层互推})
   (list @elem{3} @elem{奇数层} @elem{奇数层})
   (list @elem{4} @elem{偶数层} @elem{第 2 层起的偶数层：@tech{三重否定律}落回第 2 层}))]

经典逻辑的塔分成偶数层、奇数层两类，直觉主义逻辑多出一类：第 0 层。从上面落回第 0 层，只有经典逻辑做得到。

第 0 层特殊在哪里？第 1 层往上，每一层都是函数，等着下一层交来东西才动；只有第 0 层是一个现成的值，落到这里，就得当场把它交出来。可要是落下来拿到的值，只是为了马上交给一条等着它的@tech{延续}，最后照样是第 1 层遇上第 0 层，调用一次@tech{延续}。这样落一次地，和不落地、直接让上面两层相遇，有没有区别？

@subsection[#:tag "01:pairing"]{两种配对}

手里有一段等着@tech{延续}的计算 @racket[kkp]，在第 2 层；又有一条等着 @math{p} 的@tech{延续} @racket[kp]，在第 1 层。让它们相遇，有两种办法。

一种不落地。两者相邻，把低一层的交给高一层，@racket[(kkp kp)]，这就是@tech{矛盾律}。前面见过的配对都是这个样子：@racket[triple-negation] 里的 @racket[(kkkq kkq)]，第 3 层遇上第 2 层；@racket[kkq] 里的 @racket[(k q)]，第 1 层遇上第 0 层。也可以先往上走，用 @tech[#:key "双重否定引入"]{DNI} 把 @racket[kp] 升到第 3 层，再和 @racket[kkp] 相遇，@racket[triple-negation] 把 @racket[q] 升成 @racket[kkq] 就是这样做的：

@racketblock[
(define (kkkp kkp) (kkp kp))
(kkkp kkp)]

照定义展开一步，@racket[(kkkp kkp)] 就是 @racket[(kkp kp)]，还是同一个计算。不落地的配对只用到交到手里的东西，是构造性的。

另一种先落地，只有经典逻辑做得到：用 @tech[#:key "双重否定消除"]{DNE} 把第 2 层的 @racket[kkp] 落到第 0 层，取出 @math{p}，再和第 1 层的 @racket[kp] 相遇，@racket[(kp p)]。@tech[#:key "双重否定消除"]{DNE} 用 @racket[call/cc] 写，名字 @racket[p] 只用一次，也可以不起：

@racketblock[
#,(hspace 2)(let ([p (call/cc kkp)]) (kp p))
= (kp (call/cc kkp))]

拿一个具体的 @racket[kkp] 试，@racket[kp] 用 @racket[let/cc] 捕获。外面的 @racket[(+ 10 …)]、@racket[(+ 100 …)] 让跳没跳走看得见：

@examples[#:eval ev #:label #f
(define p 5)
(define (kkp k) (k p))
(+ 100 (let/cc kp (+ 10 (kkp kp))))
(+ 100 (let/cc kp (+ 10 (let ([p (call/cc kkp)]) (kp p)))))]

两行都是 @racket[105]：@racket[5] 交给 @racket[kp]，跳回 @racket[let/cc] 返回的地方，加十那一步跳过了。

这个 @racket[kkp] 是用 @tech[#:key "双重否定引入"]{DNI} 把 @racket[5] 升到第 2 层得来的，和 @racket[triple-negation] 里的 @racket[kkq] 一个样子，落地的配对把它取了回来。一步步改写，看得更清楚：

@racketblock[
#,(hspace 2)(call/cc kkp)
= (call/cc (λ (k) (k p)))
= (let/cc k (k p))
= (let/cc k p)
= p]

前两步照定义展开。第三步用的是@xref["01:call-cc-types"]{「call/cc 的几种类型」}里的道理：@racket[p] 算出一个值，显式跳到 @racket[k] 和正常返回，去的是同一个出口。第四步，@racket[k] 已经用不到，捕获也就可以省去。取回的 @racket[p] 再交给 @racket[kp]，就是 @racket[(kp 5)]，和不落地的配对一样。

上面的 @racket[kkp] 是 @racket[(λ (k) (k p))]，函数体就是 @racket[(k p)]。一般的 @racket[kkp] 写成 @racket[(λ (k) body)]，@racket[body] 不一定是 @racket[(k p)]，也就不一定这样展得开。把两种写法都照定义展开：

@racketblock[
(kp (call/cc kkp))  =  (kp (let/cc k body))
(kkp kp)            =  ((λ (k) body) kp)]

两边跑的是同一个 @racket[body]，只是 @racket[k] 不同。绕道第 0 层时，@racket[k] 是 @racket[let/cc] 在这里捕获的@tech{延续}；直接配对时，@racket[k] 就是外面的 @racket[kp]。

假设 @racket[body] 在某处调用 @racket[(k 5)]。@racket[k] 若是捕获的那一条，调用它，就丢下 @racket[body] 剩下的工作，把 @racket[5] 送回 @racket[let/cc] 的位置，接着做 @racket[(kp 5)]。@racket[k] 若就是 @racket[kp]，当场做的也是 @racket[(kp 5)]。@racket[kp] 的类型是 @math{¬p}，结果是 @math{⊥}，一调用就不再回来，@racket[body] 剩下的工作同样走不到。两边都做了 @racket[(kp 5)]，也都丢下了 @racket[body] 剩下的工作。@racket[(k 5)] 不在尾位置也是这样：@racket[body] 即使是 @racket[(+ 10 (k 5))]，两边的加十都走不到。

@racket[body] 也可能根本不调用 @racket[k]，自己算完，正常返回一个值，比如 @racket[7]。这时两边就不一样了。绕道第 0 层时，@racket[7] 回到 @racket[let/cc] 的位置，接着还会做 @racket[(kp 7)]。直接配对时，@racket[7] 交回调用 @racket[kkp] 的地方，@racket[kp] 根本没有用上。@racket[kkp] 的类型是 @math{¬¬p}，结果也是 @math{⊥}，排除的正是这种情形。@racket[body] 可以调用 @racket[k]，可以从别的出口离开，也可以一直算下去，只是不能正常返回。

所以，在上面追过的这两种走法里，绕到第 0 层再调用 @racket[kp]，和直接把 @racket[kp] 交给 @racket[kkp]，行为相同：绕到第 0 层，什么也没有多出来。手里已经有 @racket[kp]，要做的只是把结果交给它，直接写 @racket[(kkp kp)] 就行，不必落到第 0 层。手里没有 @racket[kp] 的时候，等着 @math{p} 的就是没写出来的当前@tech{延续}；@racket[call/cc] 做的，正是把它捕获下来，交给 @racket[kkp]。
