#lang acf/scribble

@title[#:tag "02:3-embedded"]{再把延续藏起来}

绑定的语法替我们写的，正是那个等待结果的 @racket[λ]。照它的样子，给手写的延续也造一个绑定。

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

@section[#:tag "02:hide-again"]{再次隐藏延续}

先看一个具体例子：@racket[(fact/k 2 k)] 的@tech{闭包链} @racket[(∘ k mul2 mul1)]，两步乘法。把两步用 @racket[cps] 提升，像 @racket[fact/k] 那样手写@tech{延续}：

@examples[#:eval ev #:label #f
(define cps:mul1 (cps (λ (v) (* 1 v))))
(define cps:mul2 (cps (λ (v) (* 2 v))))
(⊥->a ((λ (k)
           ((cps:mul1 1)
            (λ (v)
              ((cps:mul2 v) k))))
         a->⊥))]

想要的是像 @racket[let] 一样写成 @racket[(anf:let ([v (cps:mul1 1)]) (cps:mul2 v))]，@racket[λ] 由语法替我们写。对照手写版，@racket[(cps:mul1 1)] 是 @racket[e]，@racket[(cps:mul2 v)] 是 @racket[b]，宏把它们放回原处：

@examples[#:eval ev #:label #f #:no-prompt
(define-syntax-rule (anf:let ([v e]) b)
  (λ (k) (e (λ (v) (b k)))))]

@racket[anf:let] 自己也交出一段计算，收到@tech{延续}后才开始运行。展开出来的，除了程序员写下的箭头，只有 @racket[λ] 和函数调用。@racket[cps:] 箭头加上绑定的语法，就成了一门嵌在宿主里的小语言：宏充当编译器，把类似 @tech[#:key "A-范式"]{ANF} 的写法翻译成 @math{¬¬} 编码的 @tech[#:key "延续传递风格"]{CPS}。编译出来的程序还要有人运行，这门语言还缺一个解释器：交给程序@tech{终结延续} @racket[a->⊥]，再用 @racket[⊥->a] 接住答案：

@examples[#:eval ev #:label #f #:no-prompt
(define (anf:eval kka) (⊥->a (kka a->⊥)))]

重跑例子：

@examples[#:eval ev #:label #f
(anf:eval (anf:let ([v (cps:mul1 1)]) (cps:mul2 v)))]

@section[#:tag "02:early-return"]{提前返回}

手写的 @tech[#:key "延续传递风格"]{CPS} 版 @racket[mul] 有两处要程序员亲自动手：正常路径上，每一步都要写出新的@tech{延续} @racket[(λ (v) (k (* v r)))]；遇到零时，要手动改调 @racket[a->⊥]。不写@tech{延续}，用宿主自己的 @racket[let/cc]、@racket[let*]、@racket[if] 和原语，@racket[mul] 可以这样写：

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

照这个样子，把它一行行改写进嵌入语言：正常路径的每一步交给绑定，遇零交给 @racket[cps:call/cc] 交来的@tech{延续}。先把用到的原语经 @racket[cps] 提升：

@examples[#:eval ev #:label #f #:no-prompt
(define cps:*         (cps *))
(define cps:zero?     (cps zero?))
(define cps:car       (cps car))
(define cps:cdr       (cps cdr))
(define cps:null?     (cps null?))
(define cps:display   (cps display))
(define cps:displayln (cps displayln))]

它们都收值、交出计算，可以直接放进绑定。@racket[mul] 里的 @racket[let*]、@racket[if]、@racket[let/cc]，各要一样对应的语法，都照 @racket[anf:let] 的套路来。

几个绑定依次接起来，就是一层层嵌套的 @racket[anf:let]：

@examples[#:eval ev #:label #f #:no-prompt
(define-syntax anf:let*
  (syntax-rules ()
    [(_ () b) b]
    [(_ ([v e] [v* e*] ...) b)
     (anf:let ([v e]) (anf:let* ([v* e*] ...) b))]))]

分支也一样：测试那一段算出的计算，收到一条等测试结果的@tech{延续}；它拿到测试的值，选一支分支，再把 @racket[k] 交给它：

@examples[#:eval ev #:label #f #:no-prompt
(define-syntax-rule (anf:if test conseq alt)
  (λ (k) (test (λ (b) ((if b conseq alt) k)))))]

遇零跳出，要用 @racket[cps:call/cc] 交来的@tech{延续}。@racket[anf:let/cc] 给它起个名字：

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

@racket[(cps:mul 1 2 3 4)] 交回的是一段等待@tech{延续}的计算，交给 @racket[anf:eval] 运行。宏在展开时把程序编译成等待@tech{延续}的计算，@racket[anf:eval] 在运行时交入@tech{终结延续}。这和第一篇里操作系统运行程序是同一种分工：程序是一个 @math{¬¬@ty{Byte}}，退出通道由操作系统在启动时交给它。@racket[anf:eval] 扮演的就是操作系统：

@examples[#:eval ev #:label #f
(anf:eval (cps:mul 1 2 3 4))
(anf:eval (cps:mul 1 2 0 3 4))]

@racket[cps:loop] 和 @racket[cps:car] 一样收值、交出计算，所以它的递归调用也写在 @racket[anf:let*] 里。@racket[anf:let/cc] 把当前@tech{延续}交给程序，名字叫 @racket[cps:return]。遇零时调用它，和@xref["02:k-in-hand"]{「手中的延续」}里的 @racket[cps:proc2] 一样，计算改走保存的@tech{延续}，还没做完的乘法全部跳过。其余每一步的@tech{延续}都由 @racket[anf:let*] 接好，程序员不需要触碰。最后一步同时用到 @racket[res] 和更早的 @racket[r]：宏把后面的代码嵌进前面绑定的函数体，@racket[r] 一路看得见，所以照样能写。

@section[#:tag "02:yin-yang"]{阴阳谜题}

@racket[cps:return] 只用来跳出循环。第一篇的阴阳谜题对@tech{延续}要求更多：被捕获的@tech{延续}要作为值传来传去，再被调用。

@racket[label] 要把捕获的@tech{延续}原样交出来，用得上一段什么也不做的计算：收到值，交出一段计算，收到@tech{延续}后把值原样交给它。它就是 @racket[(cps id)]，记作 @racket[cps:id]：

@examples[#:eval ev #:label #f #:no-prompt
(define cps:id (cps id))]

@racket[label] 在嵌入语言里写作：

@examples[#:eval ev #:label #f #:no-prompt
(define (cps:label) (cps:call/cc cps:id))]

@margin-note{这类值的类型记作 @defsym[@ty{Label𝒦} "嵌入语言里标签的类型：Label𝒦 = Label𝒦 → ¬¬⊥"]@ty{Label𝒦}：它接收同类的值，交出结果为 @math{⊥} 的计算，@math{@ty{Label𝒦} = @ty{Label𝒦} → ¬¬⊥}。这仍是第一篇那样的递归类型，只是调用的结果多了计算这一层；@racket[(cps:label)] 的类型是 @math{¬¬@ty{Label𝒦}}。}

展开一层，@racket[((cps:label) k)] 是 @racket[((cps:call/cc cps:id) k)]，也就是 @racket[((cps:id (cps k)) k)]：@racket[cps:id] 把提升过的 @racket[(cps k)] 原样交给 @racket[k]。@racket[(cps:label)] 交回一段等待@tech{延续}的计算；运行时，它把提升过的当前@tech{延续} @racket[(cps k)] 作为结果交给 @racket[k]，和第一篇的 @racket[(label)] 一样。绑定得到的 @racket[cps:yin]、@racket[cps:yang]，就是这样的值。

谜题写进 @racket[anf:let*]。中间还有打印：打印也是一步计算，只是结果用不着。一串计算依次做下去、只留最后一个的结果，就是 @racket[anf:begin]：把前面的结果绑定到一个用不着的变量 @racket[_] 上，忽略掉。

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

@racket[cps:yin] 是提升过的@tech{延续}，所以能像 @racket[cps:mul] 这些函数一样直接调用。它包着的，就是@xref["02:position"]{「计算的位置」}里那样的一条@tech{延续}：@racket[(cps:label)] 把它所在的位置捕获下来，交给程序。这个位置也是从出口那条@tech{延续}一步步接出来的，出口那一条，是 @racket[anf:eval] 在计算开始时交进来的。

@racket[anf:let] 照 @racket[let] 的样子写成。@racket[let] 有@tech{结合律}与@tech{单位律}，@racket[anf:let] 也有吗？
