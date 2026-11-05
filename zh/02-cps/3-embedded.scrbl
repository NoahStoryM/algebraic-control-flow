#lang acf/scribble

@title[#:tag "02:3-embedded"]{再把延续藏起来}

执行一个程序，就是沿着@tech{闭包链}从一个位置走到下一个位置；@racket[call/cc] 要捕获的当前位置，在这种写法里已经是手里的参数。不捕获，只用这个参数，写得出 @racket[call/cc] 吗？

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define-type ⊥ (∪))
(define-type (¬ p ...) (→ p ... ⊥))
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

@section[#:tag "02:k-in-hand"]{手中的延续}

@xref["01:call-cc"]{「消除分支：call/cc」}用 @racket[cc] 实现 @racket[call/cc]：先由 @racket[(cc)] 取得当前@tech{延续}，再把它交给 @racket[proc]。在 @tech[#:key "延续传递风格"]{CPS} 里，这一步不必做。@xref["02:first-class-control"]{「一等控制」}说过，当前@tech{延续}已经是一个显式的参数：照 @racket[cps] 的写法也好，照 @racket[neg] 的写法也好，函数收到的@tech{延续}参数，就是这次调用之后要做的事。那么照这两种写法，@racket[call/cc] 该怎么写？

@margin-note{@defsym["cps:f" "照 cps 的写法写成的函数；参数、参数的参数中的函数也照这个写法"]@defsym["neg:f" "照 neg 的写法写成的函数；参数、参数的参数中的函数也照这个写法"]名字的前缀标出写法：以 @racket[cps:] 开头的函数，照 @racket[cps] 的写法收参数、交结果；它的参数、参数的参数……凡是函数的，也都照这个写法。@racket[neg:] 同理。@racket[(cps f)] 只改最外面一层，@racket[f] 的参数原样不动：@racket[f] 不收函数时，@racket[(cps f)] 就是 @racket[cps:f]，比如 @racket[cps:car]、下面的 @racket[cps:kp]；@racket[f] 收函数时就不一样了。@racket[call/cc] 收的 @racket[proc] 是函数，@racket[cps:call/cc] 收的 @racket[cps:proc] 也得照 @racket[cps] 的写法，所以 @racket[cps:call/cc] 要另写，不是 @racket[(cps call/cc)]。}

照 @racket[call/cc] 自己的意思写，先看它收到什么。@racket[cps:call/cc] 照 @racket[cps] 的写法，先收到输入 @racket[cps:proc]，再收到@tech{延续} @racket[kp]；@racket[neg:call/cc] 照 @racket[neg] 的写法，次序反过来，先收到 @racket[kp]，再收到 @racket[neg:proc]：

@racketblock[
(define ((cps:call/cc cps:proc) kp) ...)
(define ((neg:call/cc kp) neg:proc) ...)]

@racket[kp] 就是当前@tech{延续}，要交给 @racket[proc]。可 @racket[proc] 照哪种写法写成，它里面的每一次函数调用就都守哪种写法的规矩，调用交给它的@tech{延续}也不例外。@racket[cps:proc] 里调用的函数都先收值、再收@tech{延续}，交给它的@tech{延续}也得这样调用，所以给它的是 @racket[(cps kp)]，记作 @racket[cps:kp]；@racket[neg:proc] 照 @racket[neg] 的写法，给它的是 @racket[(neg kp)]，记作 @racket[neg:kp]。@racket[kp] 自己落在 @math{⊥} 上，@racket[(cps kp)] 和 @racket[(neg kp)] 都会多收一条等着 @math{⊥} 的@tech{延续}：@racket[(cps kp)] 的形状是 @math{p → (⊥ → ⊥) → ⊥}。@racket[kp] 不回来，这条@tech{延续}轮不到。@racket[neg:proc] 自己也照 @racket[neg] 的写法：先收结果的@tech{延续}，也就是原样的 @racket[kp]；再收输入，也就是提升过的 @racket[neg:kp]。两个定义写完整：

@examples[#:eval ev #:no-result
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

结果是 @racket[11]，不是 @racket[12]。@racket[cps:k] 是提升过的 @racket[kp]，@racket[(cps:k 10)] 收到手写的那个@tech{延续}以后，先算 @racket[(kp 10)]：外面那一步加 1，然后是@tech{终结延续}。@racket[kp] 不回来：在这里，它把结果交给 @racket[a->⊥]，由它 @racket[raise] 出去。等它结果的那个 @racket[λ]，也就是 @math{⊥ → ⊥} 那一层收到的@tech{延续}，连同 @racket[cps:proc2] 里排在后面的那一步加 1，再也轮不到。这正是 @racket[call/cc] 的行为：调用交出去的@tech{延续}，就是丢下手头的工作，回到 @racket[call/cc] 之后。

@bold{练习}：用 @racket[neg:call/cc] 把这两个例子各跑一遍，结果仍是 @racket[7] 和 @racket[11]。提示：@racket[neg] 的写法先收@tech{延续}，再收输入；外面那一步加 1，用 @racket[(neg add1)] 接在@tech{终结延续}前面。

这么短的两个例子，@tech{延续}却得一个个手写：外面的加 1 一个，@racket[cps:proc2] 里又一个。@xref["02:first-class-control"]{「一等控制」}那句抱怨，到这里更重了：每个@tech{延续}都得亲手写。

回想@xref["02:1-anf-cps"]{「求值顺序」}里的观察。@racket[let] 脱糖为 @racket[lambda] 调用，@tech{延续}藏在 @racket[let] 里面：等待结果的那个 @racket[λ] 不用我们写，绑定的语法替我们写了。@tech{CPS 变换}把@tech{延续}拉出来变成显式参数，这个 @racket[λ] 就得亲手写。能不能反过来：用 @racket[let] 语法把 @tech[#:key "延续传递风格"]{CPS} 的@tech{延续}再藏回去？

@section[#:tag "02:hide-again"]{再次隐藏延续}

绑定的语法替我们写的，正是那个等待结果的 @racket[λ]。照它的样子，给手写的延续也造一个绑定。

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

@examples[#:eval ev #:no-result
(define-syntax-rule (anf:let ([v e]) b)
  (λ (k) (e (λ (v) (b k)))))]

@defsym["anf:eval" "运行一段计算：交进终结延续 a->⊥，由 ⊥->a 接住答案"]@racket[anf:let] 自己也交出一段计算，收到@tech{延续}后才开始运行。展开出来的，除了程序员写下的箭头，只有 @racket[λ] 和函数调用。@racket[cps:] 箭头加上绑定的语法，就成了一门嵌在宿主里的小语言（宿主，就是运行它的 Racket 本身）：宏充当编译器，把类似 @tech[#:key "A-范式"]{ANF} 的写法翻译成 @math{¬¬} 编码的 @tech[#:key "延续传递风格"]{CPS}。编译出来的程序还要有人运行，这门语言还缺一个解释器：交给程序@tech{终结延续} @racket[a->⊥]，再用 @racket[⊥->a] 接住答案：

@examples[#:eval ev #:no-result
(define (anf:eval kka) (⊥->a (kka a->⊥)))]

重跑例子：

@examples[#:eval ev #:label #f
(anf:eval (anf:let ([v (cps:mul1 1)]) (cps:mul2 v)))]

@section[#:tag "02:early-return"]{提前返回}

手写的 @tech[#:key "延续传递风格"]{CPS} 版 @racket[mul] 有两处要程序员亲自动手：正常路径上，每一步都要写出新的@tech{延续} @racket[(λ (v) (k (* v r)))]；遇到零时，要手动改调 @racket[a->⊥]。不写@tech{延续}，用宿主自己的 @racket[let/cc]、@racket[let*]、@racket[if] 和原语，@racket[mul] 可以这样写：

@examples[#:eval ev #:no-result
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

@examples[#:eval ev #:no-result
(define cps:*         (cps *))
(define cps:zero?     (cps zero?))
(define cps:car       (cps car))
(define cps:cdr       (cps cdr))
(define cps:null?     (cps null?))
(define cps:display   (cps display))
(define cps:displayln (cps displayln))]

它们都收值、交出计算，可以直接放进绑定。@racket[mul] 里的 @racket[let*]、@racket[if]、@racket[let/cc]，各要一样对应的语法，都照 @racket[anf:let] 的套路来。

几个绑定依次接起来，就是一层层嵌套的 @racket[anf:let]：

@examples[#:eval ev #:no-result
(define-syntax anf:let*
  (syntax-rules ()
    [(_ () b) b]
    [(_ ([v e] [v* e*] ...) b)
     (anf:let ([v e]) (anf:let* ([v* e*] ...) b))]))]

分支也一样：测试那一段算出的计算，收到一条等测试结果的@tech{延续}；它拿到测试的值，选一支分支，再把 @racket[k] 交给它：

@examples[#:eval ev #:no-result
(define-syntax-rule (anf:if test conseq alt)
  (λ (k) (test (λ (b) ((if b conseq alt) k)))))]

遇零跳出，要用 @racket[cps:call/cc] 交来的@tech{延续}。@racket[anf:let/cc] 给它起个名字：

@examples[#:eval ev #:no-result
(define-syntax-rule (anf:let/cc cps:k b* ...)
  (cps:call/cc (λ (cps:k) b* ...)))]

照上面的 @racket[mul] 一行行改写，它本身也收值、交出计算：

@examples[#:eval ev #:no-result
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

@racket[(cps:mul 1 2 3 4)] 交回的是一段等待@tech{延续}的计算，交给 @racket[anf:eval] 运行。宏在展开时把程序编译成等待@tech{延续}的计算，@racket[anf:eval] 在运行时交入@tech{终结延续}。这和操作系统运行程序是同一种分工：程序是一个 @math{¬¬@ty{Byte}}，退出通道由操作系统在启动时交给它。@racket[anf:eval] 扮演的就是操作系统：

@examples[#:eval ev #:label #f
(anf:eval (cps:mul 1 2 3 4))
(anf:eval (cps:mul 1 2 0 3 4))]

@racket[cps:loop] 和 @racket[cps:car] 一样收值、交出计算，所以它的递归调用也写在 @racket[anf:let*] 里。@racket[anf:let/cc] 把当前@tech{延续}交给程序，名字叫 @racket[cps:return]。遇零时调用它，和@xref["02:k-in-hand"]{「手中的延续」}里的 @racket[cps:proc2] 一样，计算改走保存的@tech{延续}，还没做完的乘法全部跳过。其余每一步的@tech{延续}都由 @racket[anf:let*] 接好，程序员不需要触碰。最后一步同时用到 @racket[res] 和更早的 @racket[r]：宏把后面的代码嵌进前面绑定的函数体，@racket[r] 一路看得见，所以照样能写。

@section[#:tag "02:yin-yang"]{阴阳谜题}

@racket[cps:return] 只用来跳出循环。@xref["01:yin-yang"]{阴阳谜题}对@tech{延续}要求更多：被捕获的@tech{延续}要作为值传来传去，再被调用。

先把@xref["01:label-from-call-cc"]{「从 call/cc 定义标签」}里的 @racket[label] 写进嵌入语言。它可以写成 @racket[(let/cc k k)]：捕获当前@tech{延续}，再把它作为结果返回。@racket[let/cc] 换成 @racket[anf:let/cc]；返回照@xref["02:cps"]{「延续与 CPS」}的办法，不交回给调用者，而是交给@tech{延续}参数 @racket[k]。于是 @racket[(let/cc k k)] 写成：

@racketblock[
(anf:let/cc cps:k (λ (k) (k cps:k)))]

展开 @racket[anf:let/cc]：

@racketblock[
#,(hspace 2)(anf:let/cc cps:k (λ (k) (k cps:k)))
= (cps:call/cc (λ (cps:k) (λ (k) (k cps:k))))]

@defsym["cps:id" "(cps id)：CPS 箭头的单位元，p → ¬¬p 即 DNI"]交给 @racket[cps:call/cc] 的这个函数，收下一个值 @racket[v]，交出 @racket[(λ (k) (k v))]：一段计算，收到@tech{延续}就把 @racket[v] 原样交给它。这正是 @racket[((cps id) v)]。所以这个函数就是 @racket[(cps id)]，记作 @racket[cps:id]，@racket[label] 写作：

@examples[#:eval ev #:no-result
(define cps:id (cps id))
(define (cps:label) (cps:call/cc cps:id))]

@racket[(cps:label)] 交出一段计算。收到@tech{延续} @racket[k] 后，@racket[cps:call/cc] 把提升过的 @racket[(cps k)] 交给 @racket[cps:id]，@racket[cps:id] 再把它原样交给 @racket[k]，也就是 @racket[(k (cps k))]。直接风格里是 @racket[(k k)]：@xref["01:rules"]{「读出规律」}里改了名的谜题，@racket[(let/cc k0 (k0 k0))] 就是把 @racket[k0] 交给它自己。这里交给 @racket[k] 的，是换成了嵌入语言接口、提升过的它自己。绑定得到的 @racket[cps:yin]、@racket[cps:yang]，就是这样的值。

谜题写进 @racket[anf:let*]。中间还有打印：打印也是一步计算，只是结果用不着。一串计算依次做下去、只留最后一个的结果，就是 @racket[anf:begin]：把前面的结果绑定到一个用不着的变量 @racket[_] 上，忽略掉。

@examples[#:eval ev #:no-result
(define-syntax anf:begin
  (syntax-rules ()
    [(_ b) b]
    [(_ e b* ...) (anf:let ([_ e]) (anf:begin b* ...))]))]

谜题于是照原来的样子写：

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

