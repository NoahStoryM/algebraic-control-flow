#lang acf/scribble

@title[#:tag "02:2-embedded"]{再把延续藏起来}

@tech{延续}交到了手里，代价是每一个都要亲手写。@racket[let]
当初替我们写好了它们，现在能不能请绑定的语法再写一次？

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define-type ⊥ (∪))
(define-type (¬ p) (→ p ⊥))
(define-type (¬¬ p) (¬ (¬ p)))
(define-type (← q p) (→ p q))
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
(define ((cps:call/cc cps:proc) kp) ((cps:proc (cps kp)) kp))
(define ((neg:call/cc kp) neg:proc) ((neg:proc kp) (neg kp)))
(code:comment "无限输出只看前 n 行，后面印出 ...")
(define (show-lines n thunk)
  (define out (open-output-string))
  (define t (parameterize ([current-output-port out]) (thread thunk)))
  (let loop ()
    (define s (get-output-string out))
    (cond [(>= (length (regexp-match* #rx"\n" s)) n)
           (kill-thread t)
           (define lines (string-split s "\n" #:trim? #f))
           (for ([l (in-list (take lines n))])
             (displayln l))
           (display "...")]
          [(thread-dead? t) (display s)]
          [else (sleep 0.01) (loop)])))]

@section[#:tag "02:embedded"]{嵌入语言}

回想@xref["02:anf"]{「求值顺序与 ANF」}里的观察。@racket[let] 脱糖为 lambda
调用，@tech{延续}藏在 @racket[let] 里面：等待结果的那个 λ 不用我们写，
绑定的语法替我们写了。CPS 变换把@tech{延续}拉出来变成显式参数，这个 λ
就得亲手写。能不能反过来：用 @racket[let] 语法把 CPS 的@tech{延续}再藏回去？

@subsection[#:tag "02:hide-again"]{再次隐藏延续}

先看一个具体例子：@racket[(fact/k 2 k)] 的@tech{闭包链}
@racket[(∘ k mul2 mul1)]，两步乘法。把两步用 @racket[cps] 提升，像
@racket[fact/k] 那样手写@tech{延续}：

@examples[#:eval ev #:label #f
(define cps:mul1 (cps (λ (v) (* 1 v))))
(define cps:mul2 (cps (λ (v) (* 2 v))))
(⊥->a ((λ (k)
           ((cps:mul1 1)
            (λ (v)
              ((cps:mul2 v) k))))
         a->⊥))]

想要的是像 @racket[let] 一样写成
@racket[(anf:let ([v (cps:mul1 1)]) (cps:mul2 v))]，λ 由语法替我们写。
对照手写版，@racket[(cps:mul1 1)] 是 @racket[e]，@racket[(cps:mul2 v)] 是
@racket[b]，宏把它们放回原处：

@examples[#:eval ev #:label #f #:no-prompt
(define-syntax-rule (anf:let ([v e]) b)
  (λ (k) (e (λ (v) (b k)))))]

@racket[anf:let] 自己也交出一段计算，收到@tech{延续}后才开始运行。展开出来的，
除了程序员写下的箭头，只有 λ 和函数调用。@racket[cps:] 箭头加上绑定的语法，
就成了一门嵌在宿主里的小语言：宏充当编译器，把类似 ANF 的写法翻译成 @math{¬¬}
编码的 CPS。编译出来的程序还要有人运行，这门语言还缺一个解释器：
交给程序@tech{终结延续} @racket[a->⊥]，再用 @racket[⊥->a] 接住答案：

@examples[#:eval ev #:label #f #:no-prompt
(define (anf:eval kka) (⊥->a (kka a->⊥)))]

重跑例子：

@examples[#:eval ev #:label #f
(anf:eval (anf:let ([v (cps:mul1 1)]) (cps:mul2 v)))]

@subsection[#:tag "02:early-return"]{提前返回}

手写的 CPS 版 @racket[mul] 有两处要程序员亲自动手：正常路径上，
每一步都要写出新的@tech{延续} @racket[(λ (v) (k (* v r)))]；遇到零时，要手动改调
@racket[a->⊥]。不写@tech{延续}，用宿主自己的
@racket[let/cc]、@racket[let*]、@racket[if] 和原语，@racket[mul] 可以这样写：

@examples[#:eval ev #:label #f #:no-prompt
(: mul (→ Real * Real))
(define (mul . r*)
  (let/cc return
    (: loop (→ (Listof Real) Real))
    (define (loop r*)
      (if (null? r*)
          (*)
          (let* ([r (car r*)])
            (if (zero? r)
                (return r)
                (let* ([r* (cdr r*)]
                       [res (loop r*)])
                  (* res r))))))
    (loop r*)))]

遇零照样提前跳出：

@examples[#:eval ev #:label #f
(mul 1 2 3 4)
(mul 1 2 0 3 4)]

照这个样子，把它一行行改写进嵌入语言：正常路径的每一步交给绑定，遇零交给
@racket[cps:call/cc] 交来的@tech{延续}。先把用到的原语经 @racket[cps] 提升：

@examples[#:eval ev #:label #f #:no-prompt
(define cps:*         (cps *))
(define cps:zero?     (cps zero?))
(define cps:car       (cps car))
(define cps:cdr       (cps cdr))
(define cps:null?     (cps null?))
(define cps:display   (cps display))
(define cps:displayln (cps displayln))]

它们都收值、交出计算，可以直接放进绑定。@racket[mul] 里的
@racket[let*]、@racket[if]、@racket[let/cc]，各要一样对应的语法，都照
@racket[anf:let] 的套路来。

几个绑定依次接起来，就是一层层嵌套的 @racket[anf:let]：

@examples[#:eval ev #:label #f #:no-prompt
(define-syntax anf:let*
  (syntax-rules ()
    [(_ () b) b]
    [(_ ([v e] [v* e*] ...) b)
     (anf:let ([v e]) (anf:let* ([v* e*] ...) b))]))]

分支也一样：测试那一段算出的计算，收到一条等测试结果的@tech{延续}；
它拿到测试的值，选一支分支，再把 @racket[k] 交给它：

@examples[#:eval ev #:label #f #:no-prompt
(define-syntax-rule (anf:if test conseq alt)
  (λ (k) (test (λ (b) ((if b conseq alt) k)))))]

遇零跳出，要用 @racket[cps:call/cc] 交来的@tech{延续}。@racket[anf:let/cc]
给它起个名字：

@examples[#:eval ev #:label #f #:no-prompt
(define-syntax-rule (anf:let/cc cps:k b* ...)
  (cps:call/cc (λ (cps:k) b* ...)))]

照上面的 @racket[mul] 一行行改写，它本身也收值、交出计算：

@examples[#:eval ev #:label #f #:no-prompt
(: cps:mul (→ Real * (¬¬ Real)))
(define (cps:mul . r*)
  (anf:let/cc cps:return
    (: cps:loop (→ (Listof Real) (¬¬ Real)))
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

@racket[(cps:mul 1 2 3 4)] 交回的是一段等待@tech{延续}的计算，交给
@racket[anf:eval] 运行。宏在展开时把程序编译成等待@tech{延续}的计
算，@racket[anf:eval] 在运行时交入@tech{终结延续}。这和第一篇里操作系统运行程序
是同一种分工：程序是一个 @math{¬¬@ty{Byte}}，退出通道由操作系统在启动时交给
它。@racket[anf:eval] 扮演的就是操作系统：

@examples[#:eval ev #:label #f
(anf:eval (cps:mul 1 2 3 4))
(anf:eval (cps:mul 1 2 0 3 4))]

@racket[cps:loop] 和 @racket[cps:car] 一样收值、交出计算，所以它的递归调用也写在
@racket[anf:let*] 里。@racket[anf:let/cc] 把当前@tech{延续}交给程序，名字叫
@racket[cps:return]。遇零时调用它，和@xref["02:k-in-hand"]{「手中的延续」}里的
@racket[cps:proc2] 一样，计算改走保存的@tech{延续}，还没做完的乘法全部跳过。
其余每一步的@tech{延续}都由 @racket[anf:let*] 接好，程序员不需要触碰。
最后一步同时用到 @racket[res] 和更早的 @racket[r]：宏把后面的代码嵌进前面绑定的
函数体，@racket[r] 一路看得见，所以照样能写。

@subsection[#:tag "02:yin-yang"]{阴阳谜题}

@racket[cps:return] 只用来跳出循环。第一篇的阴阳谜题对@tech{延续}要求更多：
被捕获的@tech{延续}要作为值传来传去，再被调用。

@racket[label] 要把捕获的@tech{延续}原样交出来，用得上一段什么也不做的计算：
收到值，交出一段计算，收到@tech{延续}后把值原样交给它。它就是
@racket[(cps id)]，记作 @racket[cps:id]：

@examples[#:eval ev #:label #f #:no-prompt
(define cps:id (cps id))]

@racket[label] 在嵌入语言里写作：

@examples[#:eval ev #:label #f #:no-prompt
(define (cps:label) (cps:call/cc cps:id))]

展开一层，@racket[((cps:label) k)] 是 @racket[((cps:call/cc cps:id) k)]，也就是
@racket[((cps:id (cps k)) k)]：@racket[cps:id] 把提升过的 @racket[(cps k)]
原样交给 @racket[k]。@racket[(cps:label)] 交回一段等待@tech{延续}的计算；
运行时，它把提升过的当前@tech{延续} @racket[(cps k)] 作为结果交给 @racket[k]，
和第一篇的 @racket[(label)] 一样。绑定得到的
@racket[cps:yin]、@racket[cps:yang]，就是这样的值。

谜题写进 @racket[anf:let*]。中间还有打印：打印也是一步计算，只是结果用不着。
一串计算依次做下去、只留最后一个的结果，就是 @racket[anf:begin]：
把前面的结果绑定到一个用不着的变量 @racket[_] 上，忽略掉。

@examples[#:eval ev #:label #f #:no-prompt
(define-syntax anf:begin
  (syntax-rules ()
    [(_ b) b]
    [(_ e b* ...) (anf:let ([_ e]) (anf:begin b* ...))]))]

谜题于是照第一篇的样子写：

@examples[#:eval ev #:label #f
(eval:alts
 (anf:eval
  (anf:let* ([cps:yin (cps:label)])
    (anf:begin
      (cps:displayln #\@)
      (anf:let* ([cps:yang (cps:label)])
        (anf:begin
          (cps:display #\*)
          (cps:yin cps:yang))))))
 (show-lines 5
  (λ ()
    (anf:eval
     (anf:let* ([cps:yin (cps:label)])
       (anf:begin
         (cps:displayln #\@)
         (anf:let* ([cps:yang (cps:label)])
           (anf:begin
             (cps:display #\*)
             (cps:yin cps:yang)))))))))]

@racket[cps:yin] 是提升过的@tech{延续}，所以能像 @racket[cps:mul]
这些函数一样直接调用。它包着的，就是@xref["02:position"]{「计算的位置」}里那样的
一条@tech{延续}：@racket[(cps:label)] 把它所在的位置捕获下来，交给程序。
这个位置也是从出口那条@tech{延续}一步步接出来的，出口那一条，是
@racket[anf:eval] 在计算开始时交进来的。

@section[#:tag "02:two-arrows"]{两种箭头}

@xref["02:early-return"]{「提前返回」}里的 @racket[anf:let*]，
一个绑定套着一个绑定。@racket[anf:let] 的写法和 @racket[let] 一样，
也就碰上@xref["02:laws"]{「结合律与单位律」}同样的问题：几步可以嵌在 @racket[b]
里，也可以先接成一段，嵌进 @racket[e]；还可以插一个只换名的绑定。三步嵌在
@racket[b] 里：

@racketblock[
(anf:let ([y (cps:f x)])
  (anf:let ([z (cps:g y)])
    (cps:h z)))]

先把前两步接成一段，嵌进 @racket[e]：

@racketblock[
(anf:let ([z (anf:let ([y (cps:f x)])
               (cps:g y))])
  (cps:h z))]

只换名的绑定也有。@racket[anf:let] 的右边得是一段计算，只换名，
用的就是阴阳谜题里那段什么也不做的计算 @racket[cps:id]。两种只换名的写法，
都该和直接写 @racket[(cps:f x)] 一样：

@racketblock[
(anf:let ([y (cps:id x)]) (cps:f y))
(anf:let ([y (cps:f x)]) (cps:id y))]

两种嵌套交出的，是同一段计算吗？只换名的绑定，真的可有可无吗？

@subsection[#:tag "02:bind-compose"]{绑定就是复合}

问题一样，解法也可以借来。那里把 @racket[let] 看成复合，
问题就成了复合是否满足@tech{结合律}与@tech{单位律}。这里也把一次绑定看成一次复
合：照 @racket[anf:let] 的样子，先 @racket[cps:f] 再 @racket[cps:g]，
接成一支新的箭头，记作 @racket[∘𝒦]（取 continuation 的字母）：

@examples[#:eval ev #:label #f #:no-prompt
(define ((∘𝒦 cps:g cps:f) x)
  (anf:let ([y (cps:f x)])
    (cps:g y)))]

和宿主里 @racket[let] 的那条等式并排：

@racketblock[
(let     ([y     (f x)])     (g y))  =  ((∘      g     f) x)
(anf:let ([y (cps:f x)]) (cps:g y))  =  ((∘𝒦 cps:g cps:f) x)]

@margin-note{这些等式说的是行为相同，用的是@xref["02:split-k"]{「把延续独立出
来」}里的那个前提：两层参数之间不做别的事。比如 @racket[cps:f]
一收到参数就打印，@racket[(∘𝒦 cps:id cps:f)] 就会把打印推迟到收到@tech{延续}之
后。}

@racket[let] 是 @racket[∘] 的另一种写法，@racket[anf:let] 是 @racket[∘𝒦]
的另一种写法，多出来的是中间结果的名字。嵌在 @racket[b] 里，写成复合是
@racket[(∘𝒦 (∘𝒦 cps:h cps:g) cps:f)]；嵌进 @racket[e] 里，是
@racket[(∘𝒦 cps:h (∘𝒦 cps:g cps:f))]；两种换名，是在 @racket[cps:f] 的两头接上
@racket[cps:id]。想让这几种写法行为一样，@racket[∘𝒦] 就得像 @racket[∘] 一样，
满足@tech{结合律}与@tech{单位律}：

@racketblock[
(∘𝒦 cps:h (∘𝒦 cps:g cps:f))  =  (∘𝒦 (∘𝒦 cps:h cps:g) cps:f)
(∘𝒦 cps:f cps:id)  =  cps:f
(∘𝒦 cps:id cps:f)  =  cps:f]


@subsection[#:tag "02:via-contrapositive"]{借道逆否复合}

@racket[∘𝒦] 满足这两条运算律吗？先拿例子试试。再提升一支 @racket[mul3]，用
@racket[(fact/k 3 k)] 的三步乘法比较两种分组：

@examples[#:eval ev #:label #f
(define cps:mul3 (cps (λ (v) (* 3 v))))
(anf:eval ((∘𝒦 cps:mul3 (∘𝒦 cps:mul2 cps:mul1)) 1))
(anf:eval ((∘𝒦 (∘𝒦 cps:mul3 cps:mul2) cps:mul1) 1))]

两种分组算得一样。一般也是这样吗？不必逐条展开，可以借已有的运算律。
先给两种写法的箭头起名：照 @racket[cps] 写法的叫 CPS 箭头，记作
@math{→@subscript{𝒦}}；照 @racket[neg] 写法的叫逆否箭头，记作
@math{→@subscript{𝒰}}（U 取掉头转弯的意思：箭头的方向倒了过来）。前面名字以
@racket[cps:]、@racket[neg:] 开头的函数，就分别是这两种箭头：

@examples[#:eval ev #:label #f #:no-prompt
(define-type (→𝒦 p q) (→    p (¬¬ q)))
(define-type (→𝒰 p q) (← (¬ p) (¬ q)))]

@math{p →@subscript{𝒦} q} 收到 @math{p}，交出等着 @math{q}
的计算。@math{p →@subscript{𝒰} q} 用的是反向箭头 @racket[←]：它从 @math{p} 写到
@math{q}，函数却从 @math{¬q} 指向 @math{¬p}。有了名字，
前面几个函数的类型可以重写；@xref["02:early-return"]{「提前返回」}里
@racket[cps:loop] 的类型，也就是 @racket[(→𝒦 (Listof Real) Real)]：

@examples[#:eval ev #:label #f #:no-prompt
(: neg  (∀ (p q) (→ (→ p q) (→𝒰 p q))))
(: cps  (∀ (p q) (→ (→ p q) (→𝒦 p q))))
(: flip (∀ (p q) (case→ (→ (→𝒰 p q) (→𝒦 p q))
                        (→ (→𝒦 p q) (→𝒰 p q)))))
(: cps:id (∀ (q) (→𝒦 q q)))
(: ∘𝒦 (∀ (p1 p2 p3) (→ (→𝒦 p2 p3) (→𝒦 p1 p2) (→𝒦 p1 p3))))]

@racket[case→] 列出同一个函数的几种类型，调用时按交给它的参数取用其中一种：
这两行是 @racket[flip] 同一段代码的两种读法，第一行从 𝒰 搬到 𝒦，第二行搬回来。
普通函数经 @racket[neg] 变成逆否箭头，经 @racket[cps] 变成 CPS
箭头，@racket[flip] 在两种箭头之间来回。沿用@xref["02:split-k"]{「把延续独立出
来」}的前提，来回一趟，什么也不丢。

逆否箭头也能复合吗？@racket[flip] 把它们一一对到 CPS 箭头，那就把 @racket[∘𝒦]
原样搬过去：两支各 @racket[flip] 成 CPS 箭头，用 @racket[∘𝒦] 接起来，再
@racket[flip] 回来：

@examples[#:eval ev #:label #f #:no-prompt
(define (∘𝒰       neg:g        neg:f)
  (flip (∘𝒦 (flip neg:g) (flip neg:f))))]

搬过来的复合是什么？把 @racket[(flip neg:g)]、@racket[(flip neg:f)] 记作
@racket[cps:g]、@racket[cps:f]，交齐@tech{延续} @racket[k] 和输入 @racket[x]，
展开：

@racketblock[
  (((∘𝒰 neg:g neg:f) k) x)
= (((∘𝒦 cps:g cps:f) x) k)
= ((cps:f x) (λ (y) ((cps:g y) k)))
= ((neg:f (λ (y) ((neg:g k) y))) x)
= ((neg:f (neg:g k)) x)
= (((∘ neg:f neg:g) k) x)
= (((⨾ neg:g neg:f) k) x)]

倒数第三步靠的还是那个前提。搬过来的，原来就是反向复合 @racket[⨾]：先用
@racket[neg:g]，再用 @racket[neg:f]。@xref["02:position"]{「计算的位置」}用几次
@racket[neg] 接出@tech{闭包链}，也是这样接的。于是逆否箭头的复合直接取
@racket[⨾]，单位元取 @racket[id]，记作 @racket[neg:id]：

@examples[#:eval ev #:label #f #:no-prompt
(: ∘𝒰 (∀ (p1 p2 p3) (→ (→𝒰 p2 p3) (→𝒰 p1 p2) (→𝒰 p1 p3))))
(define ∘𝒰 ⨾)

(: neg:id (∀ (q) (→𝒰 q q)))
(define neg:id id)]

@racket[⨾] 有@tech{结合律}与@tech{单位律}，@racket[∘𝒰] 也就有：
分组无关紧要，@racket[neg:id] 接在哪一头都不改变什么。@racket[id] 搬回 CPS
箭头这边，正是 @racket[cps:id]。@racket[flip] 来回一趟什么也不丢，@racket[∘𝒦]
搬过去是 @racket[∘𝒰]，两条运算律也就跟着搬了回来：两种嵌套的 @racket[anf:let]
交出同样的计算，只换名的绑定可有可无。

@bold{练习}：反过来，只用 @racket[∘𝒰] 和 @racket[flip] 写出 @racket[∘𝒦]，
验证它与由 @racket[anf:let] 给出的定义行为相同。
