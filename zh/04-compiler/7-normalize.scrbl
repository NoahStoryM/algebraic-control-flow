#lang acf/scribble

@title[#:tag "04:7-normalize"]{教编译器做规范化}

@tech{β-归约}和 @tech{η-归约}是我们手工做的。没有它们输出也是正确的，但臃肿。Lambda 链的尾调用包装器 @racket[(λ (v.0) (k.0 v.0))] 消失了；@racket[999] 的例子更为显著，lambda 从 8 个降到 4 个（@racket[let] 都已脱糖）：

@racketblock[
(code:comment "Lambda 链：之前")
(λ (n) (λ (k.0) ((g n) (λ (v.1) ((f v.1) (λ (v.0) (k.0 v.0)))))))
(code:comment "之后：")
(λ (n) (λ (k.0) ((g n) (λ (v.1) ((f v.1) k.0)))))

(code:comment "999 的例子：之前")
((λ (v.0) v.0)
 ((λ (f) ((f 42) (λ (v.3) ((λ (v.2) v.2) (add1 v.3)))))
  (λ (x) (λ (k.0) ((λ (k) 999) (λ (v.1) (k.0 v.1)))))))
(code:comment "之后：")
((λ (f) ((f 42) add1)) (λ (x) (λ (k.0) ((λ (k) 999) k.0))))]

编译器在每个构造 lambda 的地方生成这些包装器。@racket[(λ (,vn) ,(ctx vn))] 是典型的情况。编译器每次准备发射一个 lambda 时，先检查 β 或 η 能否把它化简掉：

@racketblock[
(match `(λ (,vn) ,(ctx vn))
  [`(λ (,vn) ,b)       #:when (β? b vn) ...]   (code:comment "体归约为 vn：直接发射 b")
  [`(λ (,vn) (,k ,vn)) #:when (η? k vn) ...]   (code:comment "对 k 的包装器：坍缩为 k")
  [k                                    ...])  (code:comment "真正的工作：保留 lambda")]

三个分支对应三种结果：lambda 从来不需要（β 化简掉了），lambda 是一层平凡的包装（η 坍缩为内部的函数），或者 lambda 做了真正的工作，存活下来。

@section[#:tag "04:predicates"]{两个谓词}

守卫由两个谓词给出：

@racketblock[
(define (β? b v)
  (match b
    [`((λ (,u) ,u) ,e) (eq? e v)]
    [`((λ (,u) ,b) ,e)
     (and (eq? b v)
          (if (eq? u v)
              (eq? e v)
              (not (pair? e))))]
    [_ (eq? b v)]))

(define (η? k v)
  (match k
    [`(λ (,u) ,b)
     (or (eq? u v)
         (not (if (pair? b)
                  (memq v (flatten b))
                  (eq? b v))))]
    [(? trivial?) (not (eq? k v))]
    [_ #f]))]

@racket[β?] 问的是函数体 @racket[b] 是否归约为 @racket[v]；@racket[η?] 问的是 @racket[v] 是否在 @racket[k] 中自由出现。每个谓词中的守卫标出了归约不再可靠的边界。下面各举一例。

@racket[β?] 中间子句的 @racket[(not (pair? e))] 阻止丢弃一个复合表达式 @racket[e]，那个表达式是目标程序本应执行的计算：

@racketblock[
(code:comment "源程序：")
(let ([x 2]) (let ([_ (display 7)]) x))
(code:comment "编译结果：")
((λ (x) ((λ (_) x) (display 7))) 2)
(code:comment "拿掉 (not (pair? e)) 之后：")
2]

内层的 @racket[(λ (_) x)] 不用自己的参数，交出的是外层的 @racket[x]，外层 lambda 看上去就成了恒等函数。拿掉守卫，β 把整个调用化简成 @racket[2]，@racket[(display 7)] 也跟着消失了。纸面上看起来正确的归约，悄悄擦除了一段运行时计算。

@racket[η?] 第一个子句里的 @racket[memq] 检查 @racket[v] 是否出现在 @racket[k] 的函数体里：

@racketblock[
(code:comment "源程序：")
(let ([x (add1 3)]) (let ([y x]) (add1 x)))
(code:comment "编译结果：")
((λ (x) ((λ (y) (add1 x)) x)) (add1 3))
(code:comment "拿掉 memq 的检查之后：")
((λ (y) (add1 x)) (add1 3))]

外层的 @racket[(λ (x) (k x))] 形如 η 包装，@racket[k] 是 @racket[(λ (y) (add1 x))]，可 @racket[k] 的体里还用着 @racket[x]。拿掉守卫，坍缩之后的 @racket[(add1 x)] 里，@racket[x] 失去了绑定。

其余守卫遵循同样的纪律：每一个都保护着一种朴素归约会改变产出代码行为的情况。

三路 @racket[match] 还做了一件事。编译器的 @racket[ctx] 是一个闭包：不透明，只能调用，无法检查内部。@racket[(λ (,vn) ,(ctx vn))] 却是数据，就像@xref["04:recognize-k"]{「认出延续」}的帧列表：编译器把自己的@tech{延续}打印为代码，然后对打印的结果做模式匹配来决定它的命运。

@tech{β-归约}和 @tech{η-归约}是 λ-演算三大基本等价中的两个。第三个是@defterm[#:en "alpha-conversion"]{α-转换}：重命名绑定变量以避免捕获。这正是 @racket[uniquify] 在流水线起点做的事。三个等价现在都在编译器中了：

@tabular[#:style 'boxed #:sep @hspace[2] #:row-properties '(bottom-border ())
(list (list @bold{} @bold{之前} @bold{之后} @bold{编译器步骤})
      (list @bold{α} @racket[(λ (x) (+ x y))] @racket[(λ (x.0) (+ x.0 y))] @racket[uniquify])
      (list @bold{β} @racket[((λ (x) b) v)] @racket[b[x := v]] @elem{@racket[β?] @racket[match] 分支})
      (list @bold{η} @racket[(λ (x) (f x))] @racket[f] @elem{@racket[η?] @racket[match] 分支}))]

@section[#:tag "04:full"]{完整的变换器}

输出已经是 @tech[#:key "延续传递风格"]{CPS}，变换器也随之改名：@racket[anf] 改为 @racket[cps]，@racket[anf0] 改为 @racket[cps0]，@racket[anf1] 改为 @racket[cps1]。三路规范化要装进所有构造@tech{延续} lambda 的分支，分三组。

第一组是@bold{平凡调用}、@bold{用户定义的调用}和 @bold{@racket[reset]}。三者都构造 @racket[(λ (,vn) ,(ctx vn))] 作为@tech{延续}；@racket[match] 检查它是 β-归约、η-归约还是做了真正的工作。

@racketblock[
[`(,(? trivial? r) . ,rand*)
 (shift ctx
   (define vn (fv))
   (define d* (map cps0 rand*))
   (define r* `(,r . ,d*))
   (match `(λ (,vn) ,(ctx vn))
     [`(λ (,vn) ,b)       #:when (β? b vn) r*]
     [`(λ (,vn) (,k ,vn)) #:when (η? k vn) `(,k ,r*)]
     [k                                    `(,k ,r*)]))]

[`(,rator . ,rand*)
 (shift ctx
   (define vn (fv))
   (define r  (cps0 rator))
   (define d* (map cps0 rand*))
   (define r* `(,r . ,d*))
   (match `(λ (,vn) ,(ctx vn))
     [`(λ (,vn) ,b)       #:when (β? b vn) `(,r* values)]
     [`(λ (,vn) (,k ,vn)) #:when (η? k vn) `(,r* ,k)]
     [k                                    `(,r* ,k)]))]

[`(reset ,body)
 (shift ctx
   (define vn (fv))
   (define r* (cps1 body id))
   (match `(λ (,vn) ,(ctx vn))
     [`(λ (,vn) ,b)       #:when (β? b vn) r*]
     [`(λ (,vn) (,k ,vn)) #:when (η? k vn) `(,k ,r*)]
     [k                                    `(,k ,r*)]))]]

三个分支共享相同的三路 @racket[match]。@racket[reset] 分支与平凡调用写法相同，只是 @racket[r*] 换成了主体编译出的代码 @racket[(cps1 body id)]：@tech{局部答案}和平凡调用的结果一样，命名后交给 @racket[ctx]。两种调用的区别在@tech{延续}放在哪里：平凡调用把结果交给@tech{延续}，写作 @racket[(,k ,r*)]；用户定义的调用把@tech{延续}交给函数，写作 @racket[(,r* ,k)]。β 触发时@tech{延续}是恒等，平凡调用可以把它省掉，直接发射 @racket[r*]（结果不需要进一步分派）；用户定义的函数却要收一个@tech{延续}参数，省不掉，发射 @racket[(,r* values)]。函数被调用时没有剩余工作，它的@tech{延续}就是@tech{局部终结延续} @racket[a->⊥ᵃ]，也就是恒等函数 @racket[id]。目标代码里写的是 Racket 自带的 @racket[values]，@racket[id] 本来就是它。这是 @racket[values] 第一次作为@tech{延续}名字进入输出。

第二组是 @bold{@racket[shift]} 分支。@racket[match] 应用两次：一次在 @racket[(λ (,vn) ,(ctx vn))] 上（与第一组相同的检查），一次在 @racket[(λ (,k) ,(cps1 body id))] 上（为 @racket[shift] 体命名@tech{延续}）。

@racketblock[
[`(shift _ ,body)
 (shift _ (cps1 body id))]

[`(shift ,k ,body)
 (add-trivial! k)
 (define r
   (match `(λ (,k) ,(cps1 body id))
     [`(λ (,k) ,b)      #:when (β? b k) id]
     [`(λ (,k) (,r ,k)) #:when (η? r k) (λ (k) `(,r ,k))]
     [r                                 (λ (k) `(,r ,k))]))
 (shift ctx
   (define vn (fv))
   (match `(λ (,vn) ,(ctx vn))
     [`(λ (,vn) ,b)       #:when (β? b vn) (r 'values)]
     [`(λ (,vn) (,k ,vn)) #:when (η? k vn) (r k)]
     [k                                    (r k)]))]]

@racket[(shift _ body)] 丢弃了捕获的@tech{延续}，编译器也随之丢弃自己的 @racket[ctx]：本来会打印程序剩余部分的那段代码根本不会被生成。未使用的@tech{延续}不只是在运行时被跳过，它们根本不存在。

第三组是 @bold{@racket[if]} 分支。@racket[match] 像之前一样检查 β/η。@racket[r] 内部的 @racket[cond] 决定@tech{延续}是否需要被命名以避免跨分支复制：如果它是 @racket[values]（恒等），两个分支用 @racket[id] 编译；如果它已经是一个 symbol，可以直接使用；否则 @racket[(fk)] 创建一个新名字。

@racketblock[
[`(if ,test ,conseq ,alt)
 (shift ctx
   (define (r k)
     (define kn (fk))
     (cond
       [(eq? k 'values)  (cps-if id)]
       [(symbol? k)      (cps-if (reset `(,k  ,(shift k k))))]
       [else `((λ (,kn) ,(cps-if (reset `(,kn ,(shift k k))))) ,k)]))
   (define vn (fv))
   (define t (cps0 test))
   (define (cps-if ctx0)
     `(if ,t ,(cps1 conseq ctx0) ,(cps1 alt ctx0)))
   (match `(λ (,vn) ,(ctx vn))
     [`(λ (,vn) ,b)       #:when (β? b vn) (r 'values)]
     [`(λ (,vn) (,k ,vn)) #:when (η? k vn) (r k)]
     [k                                    (r k)]))]]

@racket[cond] 的三个分支避免在@tech{延续}已经简单到可以直接复制时分配名字：@racket[values] 没有代价，裸 symbol 已经是名字。只有复合@tech{延续}才获得一个新的 @racket[kn]，绑定一次，在两个分支中引用。

每个分支一个输入：

@(define ev-cps (make-acf-eval))
@examples[#:eval ev-cps #:hidden
(require acf/zh/04-compiler/code)]

@examples[#:eval ev-cps #:label #f
(cps '(if a b c))
(cps '(add1 (if a b c)))
(cps '(f (if a b c)))]

在顶层，@tech{延续}是 @racket[values]，所以两个分支在 @racket[id] 下编译，@racket[if] 原样通过。在 @racket[add1] 下方，@tech{延续}是裸 symbol，足够廉价可以写入两个分支；不分配名字。在 @racket[f] 下方，一个用户定义的调用，@tech{延续}是一个复合 lambda，只有现在编译器才把它绑定到 @racket[k.0]，让两个分支引用这个名字。绑定形式就是文法中的 @racket[<apply-cont²>]：一个 @racket[let]，其绑定值恰好是一个@tech{延续}。

前面手工归约过的两个例子：

@examples[#:eval ev-cps #:label #f
(cps '(λ (n) (f (g n))))
(cps '(reset (let ([f (λ (x) (shift k 999))]) (add1 (f 42)))))]

Lambda 链的尾调用直接传递 @racket[k.0]，@racket[999] 例子的调用点@tech{延续}是裸名字 @racket[add1]。两者都与我们在上一节手工推导的结果一致。

@section[#:tag "04:sugar"]{语法糖}

@racket[let*] 和 @racket[let/lc] 在@xref["04:5-broken"]{「镜子破裂」}一节已经加过。多绑定的 @racket[let] 脱糖为 lambda 应用：

@racketblock[
[`(let ([,x* ,exp*] ...) ,body)
 (cps0 `((λ ,x* ,body) . ,exp*))]]

剩下 @racket[abort] 和 @racket[let/cc]。@xref["03:meta"]{「元延续」}的 @racket[abort] 不是宏，而是一个函数：@racket[(define (abort . v*) (shift _ (apply values v*)))]。它对应@tech{元延续}，作为一等值还可以参与复合，@racket[let/cc] 的定义里就用到了 @racket[(∘ abort k)]。编译器也把它当作函数：@racket[abort] 这个名字代表它的定义 @racket[(λ (v) (shift _ v))]。

@margin-note{编译器只处理单值，@racket[abort] 也只接受一个参数。@xref["03:meta"]{「元延续」}的 @racket[abort] 用 @racket[(apply values v*)] 支持多值；多值不影响本章的讨论，这里从略。}

@racketblock[
['abort (cps0 '(λ (v) (shift _ v)))]
[`(abort . ,rand*) (cps0 `((λ (v) (shift _ v)) . ,rand*))]]

第一条处理 @racket[abort] 作为值出现的地方。第二条在调用处直接代入定义，交给 lambda 应用的分支，省去一次用户函数调用。

@racket[let/cc] 照@xref["03:meta"]{「元延续」}里 @racket[call/cc] 的定义 @racket[(let/lc k (proc (∘ abort k)))] 展开，复合写成 lambda：

@racketblock[
[`(let/cc ,k ,body)
 (define vn (fv))
 (define kn (fk))
 (cps0 `(let/lc ,kn (let ([,k (λ (,vn) (abort (,kn ,vn)))]) ,body)))]]

@racket[abort] 作为一等值，编译出来是什么？

@examples[#:eval ev-cps #:label #f
(cps '(reset (let ([f abort]) (+ 1 (f 5)))))]

运行结果是 @racket[5]，加一被跳过了。@racket[abort] 变成了 @racket[(λ (v) (λ (k.0) v))]：一个用户定义的函数，接受调用处的@tech{延续} @racket[k.0]，却不用它，直接交出 @racket[v]。这正是@xref["03:escape-discard"]{「逃逸与丢弃」}里的 @racket[(cps* a->⊥ᵃ)]：@racket[cps*] 丢弃当前@tech{延续}，把值交给@tech{局部终结延续}，而@tech{局部终结延续}是恒等函数。除了把名字换成定义，编译器没有为 @racket[abort] 写任何特殊处理，修复之后用户定义函数的一般规则就产生了这个形状。

@racket[let/cc] 也是如此。@xref["03:meta"]{「元延续」}的例子：

@examples[#:eval ev-cps #:label #f
(cps '(let ([k (reset (let ([x (let/cc k (abort k))]) (+ x 2)))])
        (+ (reset (k 3)) 100)))]

运行结果是 @racket[105]。@racket[let/cc] 交出的@tech{延续}是 @racket[(λ (v.1) (λ (k.1) (k.0 v.1)))]：同样忽略调用处的@tech{延续} @racket[k.1]，改用保存的@tech{局部延续} @racket[k.0]，就是 @racket[(cps* k.0)]。而 @racket[let/lc] 交出的 @racket[k] 是平凡的，调用时与当前@tech{延续}组合，对应 @racket[cps]。@xref["03:escape-discard"]{「逃逸与丢弃」}里写成 @tech[#:key "延续传递风格"]{CPS} 箭头的 @racket[call/lc] 与 @racket[call/cc]，区别在编译输出里就是这两种形状。

@section[#:tag "04:four-examples"]{四个例子的编译结果}

@xref["03:delimited-cps"]{「定界延续与 CPS」}把四个例子逐步化简成了 @tech[#:key "延续传递风格"]{CPS}。现在交给编译器。例一，@racket[reset] 加 @racket[abort]，没有 @racket[shift]：

@examples[#:eval ev-cps #:label #f
(cps '(let ([v (reset (let* ([x 3]
                             [y (+ 2 x)])
                        (abort y)))])
        (+ 10 v)))]

第三章化简例三、例一时得到的是 @racket[(let ([v (let ([x 3]) (+ 2 x))]) (+ 10 v))]，这里只是 @racket[let] 脱糖成了 lambda 应用。@racket[abort] 代入定义后落进 @racket[(shift _ ...)] 分支，@racket[reset] 的主体在 @racket[id] 下编译，两者都没有在输出中留下痕迹。

例二到例四。例二，捕获后不使用：

@examples[#:eval ev-cps #:label #f
(cps '(let ([v (reset (let* ([x (shift k 3)]
                             [y (+ 2 x)])
                        (abort y)))])
        (+ 10 v)))]

例三，调用被捕获的@tech{延续}一次：

@examples[#:eval ev-cps #:label #f
(cps '(let ([v (reset (let* ([x (shift k (k 3))]
                             [y (+ 2 x)])
                        (abort y)))])
        (+ 10 v)))]

例四，调用被捕获的@tech{延续}两次：

@examples[#:eval ev-cps #:label #f
(cps '(let ([v (reset (let* ([x (shift k (let ([r (k 3)]) (k r)))]
                             [y (+ 2 x)])
                        (abort y)))])
        (+ 10 v)))]

三份输出与第三章手工写出的 @tech[#:key "延续传递风格"]{CPS} 逐字相同，只是例二的参数第三章写作 @racket[_]。@racket[shift] 和 @racket[reset] 之间的剩余工作，也就是加二，被写成 @racket[(λ (x) (+ 2 x))] 交给主体；外层的加十是 @racket[(λ (v) (+ 10 v))]。三份输出只有主体不同，分别调用 @racket[k] 零次、一次、两次。@racket[k] 是平凡的，所以每次调用编译为普通调用。例四的主体 @racket[(let ([r (k 3)]) (k r))] 经 η-归约成为 @racket[(k (k 3))]。结果：@racket[13]、@racket[15]、@racket[17]。

每个源程序都有 @racket[reset]，目标程序里一个也没有；边界去了哪里？
