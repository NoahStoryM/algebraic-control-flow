#lang acf/scribble

@title[#:tag "01:appendix"]{附录：模拟不相交的联合}

正文读作「或」的，是@tech{不相交的联合}：拿到一个值，要分得清它来自哪一支。Typed
Racket 自带的 @racket[∪] 是普通的并集，不记来源。正文用标记做到不相交，
这不是唯一的办法。下面列出四种，用到的代码大多在文中出现过，
或者就是正文代码不打标记的写法。

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define-type ⊥ (∪))
(define-type (¬ p) (→ p ⊥))
(define-type (∐ p0 p1 ...) (∪ (Pair p0 0) (Pair p1 1) ...))
(define primitive-call/cc call/cc)
(define (goto l) (l l))
(define (label) (primitive-call/cc goto))]

@section[#:tag "01:disjoint-already"]{两边本来就不相交}

两边本来就不相交，又有现成的谓词能分辨，就可以直接用普通的并集。把 @racket[cc]
的返回类型换成普通的 @racket[∪]：

@margin-note{为了好读，这里的类型只用了一个类型变量 @math{p}；这个 @racket[cc]
和下面的 @racket[call/cc] 实际上也能交多个值，即 @racket[Values]：@racket[args]
收下全部参数，@c{apply values} 全部交出。}

@examples[#:eval ev #:label #f #:no-prompt
(: cc (∀ (p) (→ (∪ p (→ p ⊥)))))
(define (cc)
  (define saved #f)
  (define l (label))
  (if saved
      (apply values saved)
      (λ args (set! saved args) (goto l))))]

control-context 库（@racketmodname[control/context]）里的 @racket[cc]
就是这样定义的，另外还做了一些这里用不到的处理。@racket[(cc)]
交出的不是值就是@tech{延续}，没有标记。@racket[mul] 的结果是实数，@tech{延续}是
函数，用 @racket[real?] 就分得开：

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
值和@tech{延续}就未必分得清了。@racket[call/cc] 正碰上这种情况，
只好把传回来的结果一律收进一张列表，用的是 @xref["01:disjoint-struct"]{第四种办
法}：

@examples[#:eval ev #:label #f #:no-prompt
(: call/cc (∀ (p) (→ (→ (→ p ⊥) p) p)))
(define (call/cc proc)
  (define x (cc))
  (if (list? x)
      (apply values x)
      (proc (λ args (x args)))))]

不打标记，三种表述照样可以互相定义，每一步都把上一步当作原语。
最后一步和@xref["01:label-from-call-cc"]{正文}一样：

@racketblock[
(define (label) (call/cc goto))]

反过来，以@tech{标签}为原语写 @racket[call/cc]，再写 @racket[cc] 和@tech{标签}：

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

@examples[#:eval ev2 #:label #f #:no-prompt
(define (cc) (call/cc values))]

最后把 @racket[cc] 当作原语，写回@tech{标签}：

@examples[#:eval ev2 #:label #f #:no-prompt
(define (label) (cc))
(define (goto l) (l l))]

和正文相比，@racket[cc] 不用给两支配标记，写回@tech{标签}时也不用 @racket[car]：
两支直接并在一起，正是 @xref["01:label-sub"]{「代入 Label」}里的坍
缩，@math{@ty{Label} ∪ @ty{Label} = @ty{Label}}。

@section[#:tag "01:disjoint-tag"]{打标记}

这是正文的做法，见@xref["01:cc"]{「从标签到延续」}。看集合最清楚：集合
@math{X = {a, b}}、@math{Y = {b, c}} 的并集里，@math{b} 说不清来自哪一边。
每一边配上标记再并起来，

@mm{X ∐ Y = X × {0} ∪ Y × {1}}

两边就不相交了，检查标记就是一个谓词。@racket[∐] 用 @racket[cons]
把值和标记配成一对。反过来，丢掉标记，总有一个从 @math{X ∐ Y} 到 @math{X ∪ Y}
的映射：

@examples[#:eval ev #:label #f #:no-prompt
(: untag (∀ (p0 p1) (→ (∐ p0 p1) (∪ p0 p1))))
(define (untag x) (car x))]

@examples[#:eval ev #:label #f
(untag (cons 'b 0))
(untag (cons 'b 1))]

两个不同的元素，到这里成了同一个 @racket['b]。@math{X ∩ Y = {}} 时，
@racket[untag] 是一一对应，用不着标记，这就回到了上一种。

正文以 @racket[cc] 为原语写回@tech{标签}时，@racket[(car (cc))] 做的正是
@racket[(untag (cc))]。@math{p} 取 @ty{Label} 时，@math{¬@ty{Label}} 也是
@ty{Label}，丢掉标记以后，两支并成一支：

@mm{@ty{Label} ∐ ¬@ty{Label} → @ty{Label} ∪ ¬@ty{Label} = @ty{Label}}

@section[#:tag "01:disjoint-state"]{赋值修改变量}

分支的信息也可以不放在值里，而放在值外面的一个变量里。
@xref["01:first-class"]{「一等标签」}里提前返回的 @racket[mul]
就是这样：@racket[first?] 记着这是第一次进入，还是经 @racket[goto] 跳回来的。
正文 @racket[cc] 里的 @racket[first?]，@xref["01:disjoint-already"]{「两边本来就
不相交」}里 @racket[cc] 和 @racket[call/cc] 的 @racket[saved]，也是这样。

不打标记的 @racket[cc] 交出的两支都是函数时，就没有现成的谓词分得开了。下面的
@racket[wait/fc]（@italic{wait for future continuation}）
用的就是那一节不打标记的 @racket[cc]：

@examples[#:eval ev #:label #f #:no-prompt
(: wait/fc (∀ (q) (→ (¬ (¬ q)) (¬ (¬ q)))))
(define (wait/fc kk)
  (define first? #t)
  (: k (∪ (¬ q) (¬ (¬ q))))
  (define k (cc))
  (unless first? (kk k))
  (set! first? #f)
  k)]

第一次求值 @racket[(cc)]，@racket[k] 是 @racket[cc] 交出的@tech{延续}，
等的是一个 @math{¬q}，类型为 @math{¬¬q}。这时 @racket[first?] 还是 @racket[#t]，
跳过 @racket[unless]，改成 @racket[#f]，把 @racket[k] 交出去。以后有人把一个
@math{¬q} 交给它，控制跳回 @racket[(cc)]，@racket[k] 重新绑定为这个 @math{¬q}；
这一回 @racket[first?] 是 @racket[#f]，@racket[k] 交给了 @racket[kk]。@racket[k]
的两种情形都是函数，像 @racket[mul] 那样用 @racket[real?] 分不开，只好由
@racket[first?] 来记。

@racket[call/cc] 交给 @racket[proc] 的，是调用处已经有的@tech{延续}；
@racket[wait/fc] 交给 @racket[kk] 的，要等以后调用它的人交来。@racket[kk]
也总在第一次求值 @racket[(cc)] 的地方运行，而不在调用处：

@examples[#:eval ev #:label #f #:no-prompt
(define a (make-parameter 1))
(define b 111)
(define f (wait/fc (λ (k) (k (* (a) b)))))]

@examples[#:eval ev #:label #f
(call/cc f)
(set! b 222)
(call/cc f)
(parameterize ([a 2])
  (call/cc f))]

@racket[b] 是变量，每次读到的都是它此刻的值；@racket[(a)] 却总是 @racket[1]，
调用处的 @racket[parameterize] 看不见。

这一种和其它三种不同：值本身不带来源，类型上看不出两支，得靠可变状态才分得开。
正文从@tech{标签}走到 @racket[cc]，要摆脱的正是它。@racket[cc] 并没有消除它，
只是把它藏进了自己里面，交给使用者的是打好标记的值。

@section[#:tag "01:disjoint-struct"]{为分支定义专门的结构}

几支有公共的元素，又不想给每一支都打标记，可以留下一支原样不动，
把其余各支分别包进专门的结构，原样的那一支的元素永远不是这些结构。
@xref["01:disjoint-already"]{「两边本来就不相交」}里已经这样用过两
回。@racket[(λ args …)] 总把参数收成一张列表，哪怕参数本身是 @racket[#f]，存进
@racket[saved] 的列表都不是 @racket[#f]，标志和载荷就分开了；@racket[call/cc]
把传回来的结果收进列表，和@tech{延续}分开。

列表之外，也可以为每一支专门定义一种结构体。比如 @racket[a]、
@racket[b]、@racket[c] 三支，@racket[a] 原样不动，@racket[b]、@racket[c]
各包进一种结构体：

@racketblock[
(struct b (v))
(struct c (v))]

用的时候按结构体分支，两种结构体都不是的，就属于 @racket[a]：

@racketblock[
(match x
  [(b v) ... v ...]
  [(c v) ... v ...]
  [_     ... x ...])]

这一种和打标记本质相同：打标记时，标记是数据 @racket[0] 或 @racket[1]，
@racket[match] 认的是 @racket[(cons v 1)]；这里标记是结构本身，认的是
@racket[(b v)]。
