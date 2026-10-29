#lang acf/scribble

@title[#:tag "01:appendix"]{附录：不打标签的 cc}

正文里 @racket[cc] 交出带标签的联合 @math{p ∐ (p → ⊥)}。
要紧的是两支不相交，标签只是做到这一点的一种办法。
只要两支本来就分得开，直接用 @racket[∪] 也行，
分不分得开由使用者负责。control-context 库里的 @racket[cc]
就是这样定义的，另外为了配合 prompt tag 还做了一些处理。

下面给出不打标签的版本，并按两个方向各绕一圈：从@tech{标签}出发，经过
@racket[cc]、@racket[call/cc] 回到@tech{标签}；再经过
@racket[call/cc]、@racket[cc] 回到@tech{标签}。
和@xref["01:label-from-call-cc"]{正文}一样，每一步都把上一步当作原语。
这里的版本还顺带处理了多值。

@section[#:tag "01:appendix-forward"]{标签 → @racket[cc] → @racket[call/cc] → 标签}

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define-type ⊥ (∪))
(define primitive-call/cc call/cc)
(define (goto l) (l l))
(define (label) (primitive-call/cc goto))]

起点是一等@tech{标签} @racket[label] 和 @racket[goto]。用它们写
@racket[cc]：

@examples[#:eval ev #:label #f #:no-prompt
(: cc (∀ (p) (→ (∪ p (→ p ⊥)))))
(define (cc)
  (define saved #f)
  (define l (label))
  (if saved
      (apply values saved)
      (λ args (set! saved args) (goto l))))]

@racket[saved] 一身兼两职：@racket[#f] 表示@tech{延续}还没被调用过，
否则存着@tech{延续}收到的参数。两种职责不会混淆，因为
@racket[(λ args …)] 总把参数收成一张列表，哪怕参数本身是 @racket[#f]，
哪怕一个参数也没有，存进去的列表都不是 @racket[#f]。@racket[args]
收下全部参数，@c{apply values} 全部交出，这样@tech{延续}
也能接收多值。

@racket[(cc)] 交出的不是值就是@tech{延续}，没有标签。@racket[mul]
的结果是实数，@tech{延续}是函数，用 @racket[real?] 就分得开：

@examples[#:eval ev #:label #f #:no-prompt
(define (mul . r*)
  (define result (cc))
  (if (real? result)
      result
      (for/fold ([res (*)] #:result (result res))
                ([r (in-list r*)])
        (if (zero? r)
            (result r)
            (* res r)))))]

@examples[#:eval ev #:label #f
(mul 2 3 4)
(mul 2 0 3)]

@racket[call/cc] 却不知道结果会是什么，结果也可能是一个函数，
和@tech{延续} 分不开。这时只好自己造出不相交来：
把传回来的结果一律收进一张列表。@tech{延续}是函数，永远不是列表，
两者就分开了。这一层列表起的正是标签的作用：

@examples[#:eval ev #:label #f #:no-prompt
(: call/cc (∀ (p) (→ (→ (→ p ⊥) p) p)))
(define (call/cc proc)
  (define x (cc))
  (if (list? x)
      (apply values x)
      (proc (λ args (x args)))))]

@racket[proc] 拿到的@tech{延续}把参数收成列表 @racket[args]，交给
@racket[cc] 的@tech{延续} @racket[x]。@racket[(cc)]
再次返回时交出这张列表，@racket[(list? x)] 为真，@c{apply values}
把列表拆开交回。

最后一步和@xref["01:label-from-call-cc"]{正文}一样，令
@math{p = @ty{Label}}：

@racketblock[
(define (label) (call/cc goto))]

@section[#:tag "01:appendix-backward"]{标签 → @racket[call/cc] → @racket[cc] → 标签}

@(define ev2 (make-acf-eval))
@examples[#:eval ev2 #:hidden
(define-type ⊥ (∪))
(define primitive-call/cc call/cc)
(define (goto l) (l l))
(define (label) (primitive-call/cc goto))]

反过来，先用@tech{标签}写 @racket[call/cc]。写法和上一节的 @racket[cc]
一样，只是把@tech{延续}交给 @racket[proc]，不交给调用者：

@examples[#:eval ev2 #:label #f #:no-prompt
(define (call/cc proc)
  (define saved #f)
  (define l (label))
  (if saved
      (apply values saved)
      (proc (λ args (set! saved args) (goto l)))))]

@racket[cc] 就是把@tech{延续}原样交出来的 @racket[call/cc]：

@examples[#:eval ev2 #:label #f #:no-prompt
(define (cc) (call/cc values))]

第一次，@racket[values] 把@tech{延续}原样返回，@racket[(cc)]
交出@tech{延续}；@tech{延续}被调用后，@racket[(call/cc values)]
再次返回，交出传进来的值。两支之间没有标签。

以 @racket[cc] 为原语，@tech{标签}就是 @racket[(cc)] 交出的东西：

@examples[#:eval ev2 #:label #f #:no-prompt
(define (label) (cc))
(define (goto l) (l l))]

正文里这一步写成 @racket[(car (cc))]，要用 @racket[car] 丢掉标签。
这里本来就没有标签，两支直接并在一起，正是 @xref["01:label-sub"]{「代
入 Label」}里的坍缩：

@mm{@ty{Label} ∪ @ty{Label} = @ty{Label}}

@racket[p] 取 @racket[Label] 时，值和@tech{延续}都是@tech{标签}，这时
@racket[∪] 的两支完全重合，可也正好用不着分辨。
