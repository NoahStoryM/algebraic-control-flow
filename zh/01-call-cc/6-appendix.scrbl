#lang acf/scribble

@title[#:tag "01:appendix"]{附录：模拟不相交的联合}

正文读作「或」的，是@tech{不相交的联合}：拿到一个值，
要分得清它来自哪一支。Typed Racket 自带的 @racket[∪] 是普通的并集，
不记来源。正文用标签做到不相交，这不是唯一的办法。下面列出四种，
用到的代码大多在文中出现过，或者就是正文代码不打标签的写法。

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define-type ⊥ (∪))
(define primitive-call/cc call/cc)
(define (goto l) (l l))
(define (label) (primitive-call/cc goto))]

@section[#:tag "01:disjoint-already"]{两边本来就不相交}

两个类型没有公共的元素，并集本身就是不相交的联合，用一个谓词就分得开。
把 @racket[cc] 的返回类型换成普通的 @racket[∪]：

@examples[#:eval ev #:label #f #:no-prompt
(: cc (∀ (p) (→ (∪ p (→ p ⊥)))))
(define (cc)
  (define saved #f)
  (define l (label))
  (if saved
      (apply values saved)
      (λ args (set! saved args) (goto l))))]

control-context 库里的 @racket[cc] 就是这样定义的，另外为了配合 prompt
tag 还做了一些处理。这个 @racket[cc] 还顺带处理了多值：@racket[args]
收下全部参数，@c{apply values} 全部交出。

@racket[(cc)] 交出的不是值就是@tech{延续}，没有标签。@racket[mul]
的结果是实数，@tech{延续}是函数，两者没有公共的元素，用 @racket[real?]
就分得开：

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

代价是分不分得开要由使用者负责：@math{p} 换成函数类型，
值和@tech{延续}就分不清了。用这个 @racket[cc] 写 @racket[call/cc]
正碰上这种情况：@racket[call/cc] 不知道结果会是什么，
结果也可能是一个函数。只好把传回来的结果一律收进一张列表，
@tech{延续}是函数，永远不是列表，两者就分开了。这用的是
@xref["01:disjoint-struct"]{第四种办法}：

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

不打标签，三种表述照样可以互相定义。
和@xref["01:label-from-call-cc"]{正文}一样，每一步都把上一步当作原语。
从@tech{标签}出发，经过上面的 @racket[cc] 和 @racket[call/cc]，
最后一步令 @math{p = @ty{Label}}：

@racketblock[
(define (label) (call/cc goto))]

反过来，先用@tech{标签}写 @racket[call/cc]。写法和上面的 @racket[cc]
一样，只是把@tech{延续}交给 @racket[proc]，不交给调用者：

@(define ev2 (make-acf-eval))
@examples[#:eval ev2 #:hidden
(define-type ⊥ (∪))
(define primitive-call/cc call/cc)
(define (goto l) (l l))
(define (label) (primitive-call/cc goto))]
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

@section[#:tag "01:disjoint-tag"]{打标签}

这是正文的做法，见@xref["01:cc"]{「从标签到延续」}。看集合最清楚：集合
@math{X = {a, b}}、@math{Y = {b, c}} 的并集里，@math{b}
说不清来自哪一边。每一边配上标签再并起来，

@mm{X + Y = X × {0} ∪ Y × {1}}

两边就不相交了，检查标签就是一个谓词。丢掉标签，总有一个从
@math{X + Y} 到 @math{X ∪ Y} 的映射；@math{X ∩ Y = {}}
时它是一一对应，用不着标签，这就回到了上一种。@racket[∐] 用
@racket[cons] 把值和标签配成一对。

@section[#:tag "01:disjoint-state"]{赋值修改变量}

分支的信息也可以不放在值里，而放在值外面的一个变量里。
@xref["01:first-class"]{「一等标签」}里提前返回的 @racket[mul]
就是这样：@racket[first?] 记着这是第一次进入，还是经 @racket[goto]
跳回来的。正文 @racket[cc] 里的 @racket[first?]，第一节 @racket[cc] 和
@racket[call/cc] 里的 @racket[saved]，也是这样。

这一种和其它三种不同：值本身不带来源，类型上看不出两支，
得靠可变状态才分得开。正文从@tech{标签}走到 @racket[cc]，
要摆脱的正是它。@racket[cc] 并没有消除它，只是把它藏进了自己里面，
交给使用者的是打好标签的值。

@section[#:tag "01:disjoint-struct"]{为分支定义专门的结构}

几支有公共的元素，又不想给每一支都打标签，可以留下一支原样不动，
把其余各支分别包进专门的结构，原样的那一支的元素永远不是这些结构。
第一节里已经这样用过两回。@racket[(λ args …)] 总把参数收成一张列表，
哪怕参数本身是 @racket[#f]，存进 @racket[saved] 的列表都不是
@racket[#f]，标志和载荷就分开了；@racket[call/cc]
把传回来的结果收进列表，和@tech{延续}分开。

列表之外，也可以为每一支专门定义一种结构体。比如 @racket[a]、
@racket[b]、@racket[c] 三支，@racket[a] 原样不动，@racket[b]、
@racket[c] 各包进一种结构体：

@racketblock[
(struct b (v))
(struct c (v))]

用的时候依次检查，两种结构体都不是的，就属于 @racket[a]：

@racketblock[
(cond
  [(b? x) ... (b-v x) ...]
  [(c? x) ... (c-v x) ...]
  [else   ... x ...])]

这一种和打标签本质相同，都是给值做记号。打标签时记号是数据，
@racket[0] 或 @racket[1]；这里记号是结构本身。
