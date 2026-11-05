#lang acf/scribble

@title[#:tag "03:7-from-call-cc"]{用 call/cc 造定界延续}

@xref["03:meta"]{「元延续」}把@tech{延续}拆成两段：@tech{元延续} ∘ @tech{局部延续}。编码里，@tech{局部延续}是显式的参数，@tech{元延续}藏在宿主的栈上。反过来，把@tech{元延续}从栈上请出来，放进一个变量。这一章剩下的部分，以宿主的 @racket[call/cc] 和 @racket[set!] 为原语，重新造出 @racket[reset]、@racket[abort]、@racket[call/lc] 和 @racket[shift]。

@(define ev (make-acf-eval))

@section[#:tag "03:meta-k"]{元延续成了变量}

@racket[abort] 把值交给当前的@tech{元延续}。那就把@tech{元延续}存进一个变量，让 @racket[abort] 调用它：

@examples[#:eval ev #:no-result
(define meta-k exit)
(define (abort . v*) (apply meta-k v*))]

一开始，@racket[meta-k] 是 @racket[exit]：没有任何边界时，@racket[abort] 就结束整个程序。程序就是最外面那一段局部计算，@xref["03:stack-slice"]{「栈的切片」}说过。

@racket[reset] 划出一条边界。它先存下当前的@tech{元延续}，再用 @racket[let/cc] 捕获自己返回的地方，然后换上一条新的@tech{元延续}：先把旧的那条换回来，再跳回返回的地方。最后运行主体，主体算完，结果交给 @racket[abort]：

@examples[#:eval ev #:no-result
(define (call/prompt thk)
  (define k0 meta-k)
  (let/cc k1
    (set! meta-k (λ v* (set! meta-k k0) (apply k1 v*)))
    (call-with-values thk abort)))

(define-syntax-rule (reset b b* ...)
  (call/prompt (λ () b b* ...)))]

主体后面接的那个 @racket[abort]，就是编码里的 @racket[a->⊥ᵃ]：正常算完，也是调用@tech{元延续}，把答案交出边界。

@margin-note{这里用 @racket[set!]，不用 @racket[parameterize]：跳回一条捕获过的@tech{延续}时，@racket[parameterize] 的绑定会回到捕获时的样子，而 @racket[meta-k] 的更新要经得起跳转。}

@xref["01:cc"]{「从标签到延续：cc 操作符」}用@tech{标签}加 @racket[set!] 造出 @racket[cc]：交出去的@tech{延续}先 @racket[(set! u v)] 存好要带回的值，再 @racket[(goto l)] 跳回去。这里的新@tech{元延续}是同一个做法：先 @racket[(set! meta-k k0)] 把旧的@tech{元延续}换回来，再跳回 @racket[k1]。

@section[#:tag "03:local-k-from-call-cc"]{取出局部延续}

@racket[let/cc] 捕获的是完整的@tech{延续}，捕获时的@tech{元延续}也在里面。可@tech{局部延续}被调用时，要接上的是调用处的@tech{元延续}，不是捕获时的那一条。所以交给程序之前，给它包一层：

@examples[#:eval ev #:no-result
(define (call/lc proc)
  (let/cc k
    (define (local-k . v*)
      (reset (apply k v*)))
    (proc local-k)))]

@racket[local-k] 被调用时，先用 @racket[reset] 存下调用处的@tech{元延续}，再跳进 @racket[k]。@racket[k] 做完局部的工作，走到原来那个 @racket[reset] 的末尾，碰到 @racket[abort]；这时 @racket[meta-k] 已经是 @racket[local-k] 里那个 @racket[reset] 换上的，答案就回到了调用 @racket[local-k] 的地方。这层 @racket[reset] 就是编码里的 @racket[⊥ᵃ->a]：@xref["03:nested"]{「边界中的边界」}里，结构体表示下的 @racket[cps:call/lc] 也是用 @racket[⊥ᵃ->a] 把捕获的@tech{局部延续}包了一层。

@racket[shift] 和 @racket[anf:shift] 同形，@racket[call/lc] 加上 @racket[abort]：

@examples[#:eval ev #:no-result
(define-syntax-rule (shift k b b* ...)
  (call/lc (λ (k) (call-with-values (λ () b b* ...) abort))))]

拿@xref["03:four-examples"]{「四个例子」}试一试，写成直接风格：

@examples[#:eval ev #:label #f
(let ([v (reset (let* ([x 3]
                       [y (+ 2 x)])
                  (abort y)))])
  (+ 10 v))
(let ([v (reset (let* ([x (shift k 3)]
                       [y (+ 2 x)])
                  (abort y)))])
  (+ 10 v))
(let ([v (reset (let* ([x (shift k (k 3))]
                       [y (+ 2 x)])
                  (abort y)))])
  (+ 10 v))
(let ([v (reset (let* ([x (shift k (let ([r (k 3)]) (k r)))]
                       [y (+ 2 x)])
                  (abort y)))])
  (+ 10 v))]

@racket[15]、@racket[13]、@racket[15]、@racket[17]，和嵌入语言里的结果一样。

两种做法，两段@tech{延续}的位置正好对调。嵌入语言里，@tech{局部延续}是显式的参数，由 @racket[anf:let*] 一环环接出来；@tech{元延续}藏在宿主的栈上，靠 @racket[anf:reset] 那次非尾调用记着。这里，@tech{局部延续}藏在 @racket[let/cc] 捕获的@tech{延续}里；@tech{元延续}成了变量 @racket[meta-k]，由 @racket[set!] 记着。@racket[abort] 两边都是 @racket[(cps* a->⊥ᵃ)] 那个角色，只是一边丢掉的是参数里的当前@tech{延续}，一边调用的是变量里的@tech{元延续}。

@xref["03:meta"]{「元延续」}用 @racket[let/lc] 和 @racket[abort] 定义了 @racket[call/cc]；这里反过来，用 @racket[call/cc] 和 @racket[set!] 定义了 @racket[reset] 与 @racket[shift]。
