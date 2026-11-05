#lang acf/scribble

@title[#:tag "02:2-split"]{把延续独立出来}

@xref["02:anf"]{「求值顺序与 ANF」}里，每个 @racket[let] 绑定都配着一个@tech{延续} @racket[(λ (v) b)]，只是 @racket[let] 的语法替我们藏好了。把它取出来，起个名字 @racket[k]，再把整段写回函数调用：

@racketblock[
#,(hspace 2)(let ([v e]) b)
= ((λ (v) b) e)
= (let ([k (λ (v) b)]) (k e))
= ((λ (k) (k e)) (λ (v) b))]

最后一行里，@tech{延续}成了一个普通的参数：@racket[(λ (k) (k e))] 先等着@tech{延续}，拿到以后把 @racket[e] 的值交给它。第一章改写阴阳谜题时，@tech{延续}也是这样作为参数传来传去的，只不过那里要先追踪出跳转规律，才写得出这些函数。不追踪，每一步都这样收一个@tech{延续}，普通的函数和递归会变成什么样？

@(define ev0 (make-acf-eval))
@examples[#:eval ev0 #:hidden
(define-type ⊥ (∪))
(define-type (¬ p ...) (→ p ... ⊥))
(define-type (¬¬ p) (¬ (¬ p)))
(define-type (← q p) (→ p q))
(define ∘ compose)
(define id (∘))
(define (⨾ . f*) (apply ∘ (reverse f*)))]

@section[#:tag "02:cps"]{延续与 CPS}

让每个函数都额外接受这样一个参数 @racket[k]，代表「我算完之后该做什么」。函数不再把值返回给调用者，而是直接交给 @racket[k]。@racket[fact] 的 @tech[#:key "延续传递风格"]{CPS} 版本：

@examples[#:eval ev0 #:label #f #:no-prompt
(: fact/k (¬ Natural (¬ Natural)))
(define (fact/k n k)
  (if (= n 0)
      (k 1)
      (fact/k (- n 1)
              (λ (v) (k (* n v))))))

(: fib/k (¬ Natural (¬ Natural)))
(define (fib/k n k)
  (if (< n 2)
      (k n)
      (fib/k (- n 1)
             (λ (v)
               (fib/k (- n 2)
                      (λ (w)
                        (k (+ v w))))))))]

读一下类型：@racket[(¬ Natural (¬ Natural))]。接收一个自然数和一个@tech{延续} @math{¬@ty{Natural}}，返回 @math{⊥}。函数不再「返回」值：它把结果交给@tech{延续}，自己不再回来。

代码的形状变了。@racket[fact/k] 的递归调用 @racket[(fact/k (- n 1) (λ (v) ...))] 是整个 @racket[if] 分支的最后一个动作，后面没有任何待执行的表达式。@racket[fib/k] 也是：每个递归调用都处于尾位置。递归调用与对@tech{延续}的调用，都成了尾调用。

当@tech{延续}是显式参数时，「做完之后的事情」不再堆叠在调用栈上，而是编进了 @racket[k] 这个闭包里。@racket[fib/k] 递归时，@racket[(λ (v) (fib/k (- n 2) (λ (w) (k (+ v w)))))] 把「等算完第一个分支，再递归第二个分支，最后加起来交给 k」整个未来打包进了一个函数。

拿 @racket[(fact/k 3 k)] 跑一遍，看手里的@tech{延续}怎么变。把 @racket[(λ (v) (* 3 v))] 记作 @racket[mul3]，其余类推：

@racketblock[
(fact/k 3 k)                                    =  (fact/k 3 (∘ k #,(hspace 14)))
= (fact/k 2 (λ (v) ((∘ k #,(hspace 9)) (* 3 v))))  =  (fact/k 2 (∘ k mul3 #,(hspace 9)))
= (fact/k 1 (λ (v) ((∘ k mul3 #,(hspace 4)) (* 2 v))))  =  (fact/k 1 (∘ k mul3 mul2 #,(hspace 4)))
= (fact/k 0 (λ (v) ((∘ k mul3 mul2) (* 1 v))))  =  (fact/k 0 (∘ k mul3 mul2 mul1))
= ((∘ k mul3 mul2 mul1) 1)]

每递归一层，新的@tech{延续}就是在旧的前面复合一次乘法。递归到底，交给@tech{延续}的是 @racket[1]：先乘 1，再乘 2，再乘 3，得到的 @racket[6] 交给 @racket[k]。调用栈没有增长，增长的是 @racket[k] 前面这一串函数：它们是堆上的闭包，一环接一环，叫作@defterm[#:en "closure chain"]{闭包链}。@racket[k] 自己没有动过。

直接风格里也有不增长栈的写法：尾递归版本的 @racket[fact] 用一个累积器。

@examples[#:eval ev0 #:label #f #:no-prompt
(: fact (→ Natural Natural))
(define (fact n)
  (let loop ([n n] [acc 1])
    (if (= n 0)
        acc
        (loop (- n 1) (* n acc)))))]

把它也变换成 @tech[#:key "延续传递风格"]{CPS}，重新定义 @racket[fact/k]，换成累积器的版本：

@examples[#:eval ev0 #:label #f #:no-prompt
(: fact/k (¬ Natural (¬ Natural)))
(define (fact/k n k)
  (let loop/k ([n n] [acc 1] [k k])
    (if (= n 0)
        (k acc)
        (loop/k (- n 1) (* n acc) k))))]

同样拿 @racket[(fact/k 3 k)] 跑一遍：

@racketblock[
#,(hspace 2)(fact/k 3 k)
= (loop/k 3 (* #,(hspace 5)) k)
= (loop/k 2 (*     3) k)
= (loop/k 1 (*   2 3) k)
= (loop/k 0 (* 1 2 3) k)
= (k (* 1 2 3))]

循环体把 @racket[k] 原样传下去，不再包上新的闭包。尾递归之所以不消耗栈空间，正因为它不创建新的@tech{延续}：每一步复用同一个 @racket[k]。非尾递归版本里@tech{闭包链}的增长，对应着调用栈的增长。@tech[#:key "延续传递风格"]{CPS} 只是把这种增长从栈搬到了堆上。

@tech[#:key "A-范式"]{ANF} 命名中间值，让求值顺序显式；@tech[#:key "延续传递风格"]{CPS} 命名@tech{延续}，让@tech{延续}显式。

@subsection[#:tag "02:exit"]{终结延续}

@tech[#:key "延续传递风格"]{CPS} 函数需要一个@tech{延续}才能启动。启动时交进去什么？

许多语言有一个内置的@tech{延续}：@racket[exit]，类型为 @math{¬@ty{Byte}}。可以包装一下得到 @math{¬@ty{Natural}}：

@examples[#:eval ev0 #:label #f
(eval:alts (fact/k 5 (λ (ans) (displayln ans) (exit 0)))
           (void (fact/k 5 (λ (ans) (displayln ans)))))]

结果打印出来了，进程也随之终止。@racket[exit] 一调用，整段计算就到此为止。启动时交进去的这条@tech{延续}，就是前面那条@tech{闭包链}的终点：值走完整条链，最后抵达的是它，所以叫它@defterm[#:en "terminal continuation"]{终结延续}。可是用 @racket[exit] 做@tech{终结延续}，进程一结束，就没法拿着结果继续工作。

@defsym["a->⊥" "终结延续：把答案包进 ans 抛出"]@defsym["⊥->a" "接住 a->⊥ 抛出的答案，交回调用处"]我们需要另一个类型为 @math{a → ⊥} 的函数：它不返回，也不杀死进程，而是把答案送到一个取得回来的地方。@racket[raise] 正合适：它不返回，handler 又能捕获它抛出的值。要的只有两件事：@racket[a->⊥] 把答案抛出去，@racket[⊥->a] 在外面接住。和第一章由操作系统交来的 @racket[exit] 一样，这一对是在程序外面提供的终点和接收处：@racket[raise] 藏在 @racket[a->⊥] 里，程序调用的只是这条@tech{终结延续}。再用一个专门的 struct，把我们的答案和别的异常区分开：

@examples[#:eval ev0 #:label #f #:no-prompt
(struct (r) ans ([a* : (Listof r)]) #:type-name Ans)
(define (list->values v*) (apply values v*))

(: a->⊥ (∀ (a) (¬ a)))
(define (a->⊥ . a*) (raise (ans a*)))
(define-syntax-rule (⊥->a exp)
  (with-handlers ([ans? (∘ list->values ans-a*)]) exp))]

@margin-note{@racket[ans] 装的是列表，取出时用 @racket[list->values]，是为了顺带兼容多值；正文的例子只用单值。}

@racket[a->⊥] 把值包进 @racket[ans] struct 并抛出。@racket[⊥->a] 安装一个 handler 来捕获这个 struct 并提取内容，@racket[list->values] 把收到的列表拆回多个返回值。命名反映了类型层面的操作：@racket[a->⊥] 把值送入 @math{⊥}（抛出），@racket[⊥->a] 把值取回（捕获）。

@examples[#:eval ev0 #:label #f
(⊥->a (fact/k 5 a->⊥))
(⊥->a (fib/k 10 a->⊥))]

@tech[#:key "延续传递风格"]{CPS} 函数运行起来，@racket[a->⊥] 充当@tech{终结延续}，@tech{闭包链}接在它前面一环环长出来；@racket[⊥->a] 在外面接住答案。

@subsection[#:tag "02:first-class-control"]{一等控制}

@tech[#:key "延续传递风格"]{CPS} 真正的力量不在于尾递归，而在于@tech{延续}成了@bold{一等值}。@tech{延续}就是函数，可以存储、复制、丢弃，也可以改为调用另一个。@racket[call/cc] 靠在运行时捕获当前@tech{延续}，给了我们这种能力。在 @tech[#:key "延续传递风格"]{CPS} 里，当前@tech{延续}已经是一个显式的参数。

@xref["01:cc"]{「从标签到延续：cc 操作符」}里用 @racket[cc] 写过 @racket[mul]：遇到零就短路。在 @tech[#:key "延续传递风格"]{CPS} 里，@tech{延续}就是普通的函数参数，同样的短路可以直接写出来：

@examples[#:eval ev0 #:label #f #:no-prompt
(: mul (→ Real * Real))
(define (mul . r*)
  (: loop/k (¬ (Listof Real) (¬ Real)))
  (define (loop/k r* k)
    (if (null? r*)
        (k (*))
        (let ([r (car r*)])
          (if (zero? r)
              (a->⊥ r)
              (loop/k (cdr r*) (λ (v) (k (* v r))))))))
  (⊥->a (loop/k r* a->⊥)))]

外面的 @racket[⊥->a] 接住从 @racket[a->⊥] 出来的答案，所以 @racket[mul] 照常返回一个数：

@examples[#:eval ev0 #:label #f
(mul 1 2 3 4)
(mul 1 2 0 3 4)]

正常路径上，累积的乘积沿着 @racket[k] 交回去。遇到零时，跳过 @racket[k]，直接调用 @racket[a->⊥]。@racket[k] 代表「继续乘下去然后返回结果」的@tech{延续}；@racket[a->⊥] 代表「直接结束整段计算，把值交给 handler」的@tech{延续}。选择调用哪一个，就是选择走哪条控制流。不需要 @racket[call/cc]。@tech{延续}是普通的函数，切换@tech{延续}是普通的函数调用。

但代价也很明显：程序员必须亲手编写每一个@tech{延续}，把 @racket[k] 穿过每一层调用。能否自动化 @tech[#:key "延续传递风格"]{CPS} 包装？

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define-type ⊥ (∪))
(define-type (¬ p ...) (→ p ... ⊥))
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

@defsym["cps" "把宿主函数提升成 CPS 箭头：延续在后"]@defsym["neg" "把宿主函数提升成逆否箭头：延续在前"]@racket[zero?/k] 的两个参数是两种东西：@racket[x] 交给 @racket[zero?] 去算，@racket[k] 只等着接住结果。通用的包装要把这两种参数分开处理，前一种原样交给 @racket[f]，后一种接住 @racket[f] 的结果。挤在同一层参数表里，它们就得一次交齐。柯里化让@tech{延续}独占一层，和其余参数分开，两层就能分开交：先交其余参数，得到一段还没开始的计算；先交@tech{延续}，得到一个把@tech{延续}换成另一条@tech{延续}的函数。两种次序各有用处，都写出来。@tech{延续}独立在内层还是外层，操作上没有区别，函数体都一样：

@examples[#:eval ev #:hidden
(define (((cps f) . p*) kq) (kq (apply f p*)))
(define (((neg f) kq) . p*) (kq (apply f p*)))]
@racketblock[
(define (((cps f) . p*) kq) (kq (apply f p*)))  (code:comment "延续在后")
(define (((neg f) kq) . p*) (kq (apply f p*)))  (code:comment "延续在前")]

这样的函数头是嵌套 @racket[λ] 的简写：@racket[(define (((cps f) . p*) kq) body)] 就是 @racket[(define (cps f) (λ p* (λ (kq) body)))]，一层括号收一层参数，@tt{. p*} 把其余参数收成列表，原样交给 @racket[f]，不管 @racket[f] 收几个参数。

这只是把 @racket[f] 整个包上一层：@racket[f] 自己里面的计算照旧，@racket[cps] 并不改写它的内部。

拿 @racket[+] 各走一遍。@racket[(cps +)] 先收操作数 @racket[1]、@racket[2]，交出一个等着@tech{延续}的值；再交给它一个@tech{延续}，计算才开始。@racket[(neg +)] 次序反过来，先收@tech{延续}，再收操作数：

@examples[#:eval ev #:label #f
(⊥->a (((cps +) 1 2) (λ (v) (a->⊥ (* v 10)))))
(⊥->a (((neg +) (λ (v) (a->⊥ (* v 10)))) 1 2))]

操作上一样，类型却不同：

@examples[#:eval ev #:label #f #:no-prompt
(: cps (∀ (p q) (→ (→ p q) (→    p (¬¬ q)))))
(: neg (∀ (p q) (→ (→ p q) (← (¬ p) (¬ q)))))]

@racket[(cps f)] 先收操作数，交出的 @math{¬¬q} 是一段还没开始的计算：@racket[((cps +) 1 2)] 就是还没开始的 @racket[(+ 1 2)]。@xref["01:program-type"]{「代入 Byte」}里，这样的值有类型：程序就是一个 @math{¬¬@ty{Byte}}，等操作系统交来 @racket[exit] 才运行。

@racket[(neg f)] 先收@tech{延续}：交给它一条等 @math{q} 的@tech{延续} @racket[kq]，它交回一条等 @math{p} 的@tech{延续}：这条@tech{延续}拿到 @math{p}，先交给 @racket[f] 算出 @math{q}，再交给 @racket[kq]。@racket[f] 从 @math{p} 到 @math{q}，@racket[(neg f)] 却从 @math{¬q} 到 @math{¬p}，方向反了过来，所以它的类型用@xref["02:laws"]{「结合律与单位律」}里的反向箭头 @racket[←] 来写。

@defsym["flip" "交换两层柯里化参数的次序；在逆否箭头与 CPS 箭头之间来回"]两者的差别只在柯里化的方向：@tech{延续}在前还是在后。既然是参数顺序的差别，交换顺序就能在两种写法之间来回：

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

回头看@xref["02:cps"]{「延续与 CPS」}里 @racket[(fact/k 3 k)] 的展开，用的是会构造乘法闭包链的第一版。每递归一层，新的@tech{延续}都是在旧的前面复合一次乘法：@racket[k] 换成 @racket[(∘ k mul3)]，再换成 @racket[(∘ k mul3 mul2)]。收一条@tech{延续}，在它前面复合一个函数，交出另一条@tech{延续}，这正是 @racket[neg] 做的事：@racket[(neg f)] 收到等 @math{q} 的@tech{延续}，交出等 @math{p} 的@tech{延续}。照这个意思重写 @racket[neg]，得到的和前面的定义是同一个函数，只是可变参数交给 @racket[∘] 去处理：

@examples[#:eval ev #:label #f #:no-prompt
(define ((neg f) kq) (∘ kq f))]

于是递归的每一层都是一次 @racket[neg]：第一层用 @racket[(neg mul3)]，第二层用 @racket[(neg mul2)]，第三层用 @racket[(neg mul1)]。递归到底时的那条链，就是三次 @racket[neg] 依次用在 @racket[k] 上：

@racketblock[
#,(hspace 2)(∘ k mul3 mul2 mul1)
= ((neg mul1) ((neg mul2) ((neg mul3) k)))
= ((∘ (neg mul1) (neg mul2) (neg mul3)) k)]

@racket[(neg mul3)] 最先用，@racket[mul3] 紧挨着 @racket[k]；@racket[(neg mul1)] 最后用，@racket[mul1] 却最先算。几次 @racket[neg] 用 @racket[∘] 接起来，次序和里面的乘法正好相反。整条@tech{闭包链}从 @racket[k] 开始，一环环向内建起来。@racket[k] 是出口，也就是这段计算的@tech{终结延续}：@racket[(fact/k 3 k)] 若就是整个程序，它就是程序的出口，也就是 @racket[exit]；启动时交进去的若是@tech{终结延续} @racket[a->⊥]，它就是 @racket[a->⊥]。

以上是链的构造。运行时，值又怎样沿着它走？@xref["02:anf"]{「求值顺序与 ANF」}说过，@racket[let*] 就是复合。反过来，把这条@tech{闭包链}拆回 @racket[let*]，给中间结果起名，值从 @racket[v0] 出发：

@racketblock[
#,(hspace 2)((∘ k mul3 mul2 mul1) v0)
= (let* ([v1 (mul1 v0)]
         [v2 (mul2 v1)]
         [v3 (mul3 v2)])
    (k v3))]

每个名字处都有一条@tech{延续}在等它：等 @racket[v3] 的是 @racket[k]，等 @racket[v2] 的是先乘 3 再交给 @racket[k]，依次类推。把等 @racket[vn] 的那一条记作 @racket[kn]：

@racketblock[
k3  =  (∘ k #,(hspace 14))  (code:comment "等 v3")
k2  =  (∘ k mul3 #,(hspace 9))  (code:comment "等 v2")
k1  =  (∘ k mul3 mul2 #,(hspace 4))  (code:comment "等 v1")
k0  =  (∘ k mul3 mul2 mul1)  (code:comment "等 v0")]

@racket[v0] 是递归到底交来的 @racket[1]，@racket[vn] 正是 @racket[(fact n)] 的值。这些@tech{延续}的类型都是 @math{¬@ty{Natural}}，每一条都是这个类型的一个具体的值，各自标出程序运行到的一个位置：等到 @racket[vn] 以后，还要乘上哪几个数，再交给 @racket[k]。@racket[(label)] 捕获的「当前位置」，就是这样一条@tech{延续}。@racket[let*] 的每个绑定处都有一条；直接风格的 @racket[fact] 里，它们一样在，只是藏在嵌套的 @racket[let] 里。

相邻两个位置之间，隔着一步计算。从 @racket[k2] 到 @racket[k3]，中间一步是 @racket[mul3]：@racket[k2] 拿到值，先乘 3，再交给 @racket[k3]。用 @racket[neg] 写出来：

@racketblock[
k2  =  (∘ k3 mul3)  =  ((neg mul3) k3)]

@racket[(neg mul3)] 的类型 @math{¬@ty{Natural} → ¬@ty{Natural}} 说的是它在两个@tech{延续}类型之间映射；这里交给它的是一个具体的值 @racket[k3]，交出的是另一个具体的值 @racket[k2]：它把一个位置上的@tech{延续}，映射成另一个位置上的@tech{延续}。一般地，一步 @racket[f] 从 @math{p} 算到 @math{q}。等 @math{p} 的@tech{延续}记作 @racket[kp]，等 @math{q} 的记作 @racket[kq]，这一步前后的两个位置就满足 @c{kp = ((neg f) kq)}，也就是 @racket[(∘ kq f)]：前一处的@tech{延续}，正是这一步接上后一处的@tech{延续}。

这条等式从右往左读，是构造：@racket[(neg f)] 收到后一处的@tech{延续}，交出前一处的@tech{延续}。前面那条@tech{闭包链}就是这样建起来的，从出口 @racket[k3] 开始，一步步往前得到 @racket[k2]、@racket[k1]、@racket[k0]。

从左往右读，是运行：@racket[(kp p)] 就是 @racket[(kq (f p))]，值走完 @racket[f] 这一步，等着它的@tech{延续}就从 @racket[kp] 换成了 @racket[kq]。递归到底，@racket[1] 作为 @racket[v0] 交给 @racket[k0]，@racket[let*] 一行行往下：过 @racket[mul1] 到 @racket[k1]，过 @racket[mul2] 到 @racket[k2]，过 @racket[mul3] 得到 @racket[6]，到 @racket[k3]，也就是出口。

两种读法方向相反，起止却是同一条：出口的那条@tech{延续}，既是@tech{延续}构造的起点，也是值移动的终点：计算开始时交进来的是它，计算最后抵达的也是它。执行一个程序，就是沿着@tech{闭包链}，从一个位置走到下一个位置。
