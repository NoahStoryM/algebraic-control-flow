#lang acf/scribble

@title[#:tag "01:1-labels"]{从标签到 call/cc}

C 的@tech{标签}钉死在代码里。要是能把它拔下来，拿在手里，传来传去呢？

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(require racket/undefined)
(define-type ⊥ (∪))
(define primitive-call/cc call/cc)
(define (goto l) (l l))
(define (label) (primitive-call/cc goto))
(define-syntax-rule (let/cc k body ...) (call/cc (λ (k) body ...)))]

@section[#:tag "01:first-class"]{一等标签}

设想我们有一等的@tech{标签}：

@examples[#:eval ev #:label #f #:no-prompt
(define-type ⊥ (∪))  (code:comment "空类型：没有构造子，没有元素")
(: goto  (→ Label ⊥))
(: label (→ Label))]

@racket[(label)] 捕获程序中的当前位置，返回一个 @racket[Label] 值。@racket[(goto l)] 跳回 @racket[l] 被创建的地方，让当初那次 @racket[(label)] 调用再返回一次，交出的仍是这个 @racket[l]。@racket[goto] 的返回类型是
@defsym["⊥" "空类型，没有元素；读作假"]@racket[⊥]（bottom），一个没有元素的@defterm[#:en "empty type"]{空类型}：@racket[goto] 永远不会回到调用它的地方，控制转移到了别处。

「一等」说的是两件事。@tech{标签}和数、字符串一样是值，可以存进变量，传给函数，作为返回值。而且创建它的函数返回以后，它仍然有效，@racket[goto] 还能跳回那个函数里面去。标准 C 的@tech{标签}两件都做不到。

先拿它写一个循环：

@examples[#:eval ev #:label #f
(let ([x 0])
  (define loop (label))
  (set! x (add1 x))
  (when (< x 7) (goto loop))
  (displayln x))]

我们在循环体顶部捕获一个@tech{标签}。每次 @racket[(goto loop)]，执行回到 @racket[(label)]，它再次返回同一个@tech{标签}，@racket[loop] 重新绑定到它，循环体从头再走一遍。可变变量 @racket[x] 记下已经走了几遍。

再写一个提前返回的函数：把一串实数乘起来，遇到零就立即交出零。

@examples[#:eval ev #:label #f #:no-prompt
(define (mul . r*)
  (define first? #t)
  (define result (*))       (code:comment "乘法单位元 = 1")
  (define ret (label))
  (when first?
    (set! first? #f)
    (for ([r (in-list r*)])
      (when (zero? r)
        (set! result r)
        (goto ret))
            (set! result (* result r))))
  result)]

@examples[#:eval ev #:label #f
(mul 2 3 4)
(mul 2 0 3)]

这里的 @racket[ret] 是一个「返回@tech{标签}」。遇到零时，@racket[(goto ret)] 并不直接跳到函数末尾。@racket[ret] 是在 @racket[when] 之前创建的，控制回到 @racket[(define ret (label))]，@racket[(label)] 再次返回。这时 @racket[first?] 已经是 @racket[#f]，整个 @racket[when] 被跳过，函数交出 @racket[result]，也就是刚存进去的零。布尔标志 @racket[first?] 就是用来分辨这是第一次进入，还是经 @racket[goto] 跳回来的。

@section[#:tag "01:cc"]{从标签到延续：cc 操作符}

两个例子都依赖@bold{修改可变状态}（@racket[set!]）来在跳转之间传递信息。@racket[goto] 是一张单程票，@tech{标签}本身不携带任何数据，所以我们不得不通过副作用来进入正确的状态。第二个例子中的标志 @racket[first?] 与乘法无关：它存在的唯一目的就是区分「我们是第一次运行，还是刚刚跳回来？」

要避免修改状态，跳回去时得能捎上一个值。设想一个新的操作符，像 @racket[(label)] 那样捕获当前位置。它第一次被求值时，返回一个「回调」：一个以后可以调用的函数，带着一个值跳回去。调用这个回调时，它「再次返回」，这次交出的就是传入的那个值。这个回调，就叫@defterm[#:en "continuation"]{延续}。

于是这个操作符的返回值有两种可能：

@itemlist[
  @item{类型为 @math{p → ⊥} 的@tech{延续}：接受类型为 @math{p} 的值且永不返回的函数（它跳回捕获点）。}
  @item{类型为 @math{p} 的值，在@tech{延续}被调用时收到。}]
用的人得分得清拿到的是哪一种。我们给每种可能打上一个@defterm[#:en "tag"]{标记}：值配上 @racket[0]，@tech{延续}配上 @racket[1]，用 @racket[cons] 配成一对。这样合起来的类型，叫@defterm[#:en "tagged union"]{带标记的联合}，写作
@defsym["p ∐ q" "带标记的联合：每支配上标记再并起来"]@racket[∐]：

@examples[#:eval ev #:label #f #:no-prompt
(define-type (∐ p0 p1 ...) (∪ (Pair p0 0) (Pair p1 1) ...))]

第 @math{i} 支的值配上@tech{标记} @math{i}。一支也没有的 @racket[(∐)]，就是 @racket[(∪)]，也就是 @racket[⊥]。

@margin-note{这一步回不去。同一个元素出现在几支里，配上不同的@tech{标记}，在 @racket[∐] 里就有几个，@racket[untag] 以后就成了一个，再也说不清它来自哪一支：@racket[∐] 比 @racket[∪] 多记着来源。}

把@tech{标记}丢掉，就回到普通的并集：

@examples[#:eval ev #:label #f #:no-prompt
(: untag (∀ (p ...) (→ (∐ p ...) (∪ p ...))))
(define untag car)]

我们把这个操作符叫做 @racket[cc]（@racket[current-continuation] 的缩写）：

@examples[#:eval ev #:label #f #:no-prompt
(: cc (∀ (p) (→ (∐ p (→ p ⊥)))))
(define (cc)
  (define first? #t)
  (define u undefined)
  (define l (label))
  (cond
    [first? (set! first? #f)
     (cons (λ (v) (set! u v) (goto l)) 1)]
    [else (cons u 0)]))]

@margin-note{@racket[cc] 的内部仍然使用了 @racket[label]、@racket[goto] 和 @racket[set!]，但它们被封装起来了，@racket[cc] 的使用者不必再碰可变状态。}

@racket[first?] 和 @racket[u]，就是上面那版 @racket[mul] 里的 @racket[first?] 和 @racket[result]：@racket[first?] 分辨第一次进入还是跳回来，@racket[u] 存下跳回来时带的值。按时间顺序看。第一次调用 @racket[(cc)] 时，@racket[first?] 是 @racket[#t]，@racket[(label)] 捕获当前位置，@racket[cond] 走第一支，把 @racket[first?] 改成 @racket[#f]，交出一个配着 @racket[1] 的函数，这就是@tech{延续}。@racket[(cc)] 就此返回。

后来某处调用这个@tech{延续}，它把参数存进 @racket[u]，再 @racket[(goto l)] 跳回 @racket[cc] 里面。此时 @racket[cc] 早已返回过，@tech{标签}仍然能跳回去，用的正是一等@tech{标签}的第二项能力。@racket[(label)] 再次返回，控制又来到 @racket[cond]。这一回 @racket[first?] 是 @racket[#f]，走 @racket[else]，@racket[(cc)] 第二次返回，交出配着 @racket[0] 的 @racket[u]。

有了 @racket[cc]，@racket[mul] 可以再写一次：

@examples[#:eval ev #:label #f #:no-prompt
(define (mul . r*)
  (match (cc)
    [(cons r 0) r]
    [(cons return 1)
     (for/fold ([res (*)] #:result (return res))
               ([r (in-list r*)])
              (if (zero? r)
           (return r)
           (* res r)))]))]

@examples[#:eval ev #:label #f
(mul 2 3 4)
(mul 2 0 3)]

@racket[match] 按@tech{标记}分两支。@racket[for/fold] 一边遍历 @racket[r*]，一边累积 @racket[res]；@racket[#:result] 指定遍历结束后交出什么。

第一次求值 @racket[(cc)] 时，交出的配着 @racket[1]，是一个@tech{延续}，绑定到 @racket[return]，开始折叠。如果遇到零，调用 @racket[(return r)]，触发@tech{延续}：控制跳回求值 @racket[(cc)] 的位置，这一回交出的配着 @racket[0]，就是 @racket[r]，第一支立即返回。如果没有遇到零，@racket[for/fold] 的 @racket[#:result] 子句在折叠结束后调用 @racket[(return res)]，同样跳回，交出累积乘积 @racket[res]。两条路径都通过@tech{延续} @racket[return] 汇合，不需要可变状态，也不需要标志。

@section[#:tag "01:call-cc"]{消除分支：call/cc}

@racket[cc] 消除了可变状态，但带来了新的要求：@bold{分支}。每次调用 @racket[(cc)] 的返回值都有两种可能，程序员必须用 @racket[match] 区分收到的是哪一支。这行得通，只是程序员又多了一件要操心的事。能不能把分支也一并消除？

不再返回@tech{带标记的联合}让调用者去分支，而是让调用者传入一个函数 @racket[proc]，直接把@tech{延续}作为参数交给它。分支挪进操作符内部，对用户不可见：

@examples[#:eval ev #:label #f #:no-prompt
(: call/cc (∀ (p) (→ (→ (→ p ⊥) p) p)))
(define (call/cc proc)
  (match (cc)
    [(cons v 0) v]
    [(cons k 1) (proc k)]))]

第一次，@racket[(cc)] 交出配着 @racket[1] 的@tech{延续} @racket[k]，交给 @racket[proc]。@racket[proc] 若在某处调用 @racket[(k v)]，@racket[(cc)] 再次返回，这回交出配着 @racket[0] 的 @racket[v]，@racket[call/cc] 把它交给调用者，@racket[proc] 里剩下的工作被跳过。@racket[proc] 若不调用@tech{延续}而正常返回，它的返回值就是 @racket[call/cc] 的结果。

有了 @racket[call/cc]，@racket[mul] 可以再写一次：

@margin-note{@racket[let/cc] 是 @racket[call/cc] 的语法糖：@racket[(let/cc k body ...)] 就是 @racket[(call/cc (λ (k) body ...))]，给当前@tech{延续}起个名字 @racket[k]。}

@examples[#:eval ev #:label #f #:no-prompt
(define (mul . r*)
  (let/cc return
    (for/fold ([res (*)])
              ([r (in-list r*)])
      (if (zero? r)
          (return r)
          (* res r)))))]

@examples[#:eval ev #:label #f
(mul 2 3 4)
(mul 2 0 3)]

标志、可变状态、@racket[match] 的分支都不见了。没有遇到零，@racket[for/fold] 正常结束，乘积作为 @racket[proc] 的返回值交出；遇到零，@racket[(return r)] 把零直接交给 @racket[mul] 的调用者。@tech{延续}有了一个名字，叫 @racket[return]。许多语言里内建的那个 @racket[return]，在这里是一个普通的值，由 @racket[call/cc] 交到我们手上。

@section[#:tag "01:label-from-call-cc"]{从 call/cc 定义标签}

从@tech{标签}出发，我们写出了 @racket[cc]，又由 @racket[cc] 写出了 @racket[call/cc]。再走一步，能不能由 @racket[call/cc] 写回@tech{标签}，绕成一个圈？这一步要把 @racket[call/cc] 当作原语：手上只有它，没有@tech{标签}。Racket 自带的 @racket[call/cc] 就是这样一个原语。

先看@tech{标签}是什么样的函数。@racket[(goto l)] 就是 @racket[(l l)]：@tech{标签}接受一个@tech{标签}，而且永不返回。它的类型
@defsym[@ty{Label} "标签的类型：Label = Label → ⊥"]@ty{Label} 因此是一个递归类型：

@mm{@ty{Label} = @ty{Label} → ⊥}

再看 @racket[call/cc] 交给 @racket[proc] 的@tech{延续}，类型是 @math{p → ⊥}。令 @math{p = @ty{Label}}，两者就一样了：@racket[call/cc] 交出的@tech{延续}，恰好可以当作一个@tech{标签}。于是：

@(define ev1 (make-acf-eval))
@examples[#:eval ev1 #:label #f #:no-prompt
(define-type Label (→ Label ⊥))
(define (goto l) (l l))
(define (label) (call/cc goto))]

@racket[(label)] 做了什么，一步步展开来看。把 @racket[call/cc] 交给 @racket[goto] 的@tech{延续}记作 @racket[k]，它通向 @racket[(label)] 被调用的地方：

@racketblock[
#,(hspace 2)(label)
= (call/cc goto)
= (goto k)
= (k k)]

@margin-note{@racket[goto] 返回 @racket[⊥]，却能交给要返回 @math{p} 的 @racket[call/cc]，为什么无妨，见@xref["01:call-cc-types"]{「call/cc 的几种类型」}。}

@racket[(call/cc goto)] 拿捕获的@tech{延续}当@tech{标签}，原地跳一次，又回到这里。@racket[goto] 并不正常返回，返回类型是 @racket[⊥] 也无妨：它把 @racket[k] 交给 @racket[k] 自己。@racket[(k k)] 跳回 @racket[(label)] 被调用的地方，让 @racket[call/cc] 带着 @racket[k] 再返回一次，所以 @racket[(label)] 的结果就是 @racket[k] 本身。以后 @racket[(goto l)] 跳回同一处，@racket[(label)] 又一次返回 @racket[l]，正是开头为一等@tech{标签}描述的行为。

跳回去再交出 @racket[k]，和直接交出 @racket[k] 并没有分别。用 @racket[let/cc] 写出来：

@racketblock[
(let/cc k (k k))  =  (let/cc k k)]

左边原地跳一次，带着 @racket[k] 回到这里；右边直接交出 @racket[k]。结果都是 @racket[k]。

圈也可以反过来绕。以@tech{标签}为原语，先写出 @racket[call/cc]，再由它写出 @racket[cc]，最后把 @racket[cc] 当作原语，写回@tech{标签}：

@(define ev2 (make-acf-eval))
@examples[#:eval ev2 #:hidden
(require racket/undefined)
(define primitive-call/cc call/cc)
(define (goto l) (l l))
(define (label) (primitive-call/cc goto))
(define-syntax-rule (let/cc k body ...) (call/cc (λ (k) body ...)))
(define untag car)]
@examples[#:eval ev2 #:label #f #:no-prompt
(define (call/cc proc)
  (define first? #t)
  (define u undefined)
  (define l (label))
  (cond
    [first? (set! first? #f)
     (proc (λ (v) (set! u v) (goto l)))]
    [else u]))]

@examples[#:eval ev2 #:label #f #:no-prompt
(define (cc)
  (let/cc k
    (cons (λ (v) (k (cons v 0))) 1)))]

这个 @racket[call/cc] 的写法和 @racket[cc] 一样，只是把@tech{延续}交给 @racket[proc]，而不是交给调用者。由它写 @racket[cc]，只要给交出的@tech{延续}配上 @racket[1]，再让它跳回来时配上 @racket[0]。

最后以 @racket[cc] 为原语，写回@tech{标签}。@racket[(cc)] 第一次交出的，是配着 @racket[1] 的@tech{延续} @racket[k]。把它当作@tech{标签}，跳回来靠的是 @racket[(goto k)]，也就是 @racket[(k k)]：@racket[k] 带回来的正是它自己。于是 @racket[(cc)] 第二次交出的，是配着 @racket[0] 的 @racket[k]。两支装的是同一个@tech{标签}，@tech{标记}没有什么要分辨的，丢掉就是：

@examples[#:eval ev2 #:label #f #:no-prompt
(define label (compose untag cc))
(define (goto l) (l l))]

无论从哪一个出发，另外两个都写得出来：三种表述在@bold{表达能力上等价}。

@section[#:tag "01:compare"]{比较}

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list ""
         @elem{一等@tech{标签} (@racket[goto] + @racket[label])}
         @elem{值与@tech{延续}的@tech{带标记的联合} (@racket[cc])}
         @elem{高阶回调 (@racket[call/cc])})
   (list @elem{@bold{涉及的类型}}
         @elem{只有 @racket[Label]}
         @elem{带@tech{标记}的联合 @math{p ∐ (p → ⊥)}}
         @elem{高阶：@math{((p → ⊥) → p) → p}})   (list @elem{@bold{使用者需要可变状态？}}
         @elem{是：要在跳转间带值，就得用 @racket[set!]}
         @elem{否}
         @elem{否})
   (list @elem{@bold{要分辨返回值？}}
         @elem{否}
         @elem{是：必须区分 @math{p} 和 @math{p → ⊥}}
         @elem{否}))]

三种风格力量的来源是同一个：跳转目标成为了值。之后的一切都是易用性的取舍，每种风格为管理同一种能力，付出不同的代价：可变状态、分支、高阶类型。
