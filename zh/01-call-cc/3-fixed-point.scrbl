#lang acf/scribble

@title[#:tag "01:3-fixed-point"]{否定的不动点}

还有一个类型我们早就认识，却一直没拿来代入：@math{@ty{Label}}。
它是它自己的否定，层数还数得下去吗？

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define-type ⊥ (∪))
(define primitive-call/cc call/cc)
(define (goto l) (l l))
(define (label) (primitive-call/cc goto))
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

@section[#:tag "01:label-sub"]{代入 @math{@ty{Label}}}

把 @math{@ty{Label}} 代入@tech{排中律} @math{p ∨ ¬p}。
按定义，@math{¬@ty{Label}} 就是 @math{@ty{Label}}，
两个分支成了同一个类型：

@mm{@ty{Label} ∨ ¬@ty{Label} = @ty{Label} ∨ @ty{Label}}

一真一假的两支，在这里分不出真假。@xref["01:types-to-logic"]{「从类型
到逻辑」}说过，Typed Racket 的 @racket[∪] 是普通的并集，
不记录值从哪一边来；两边既然是同一个类型，并起来就只剩它自己：

@mm{@ty{Label} ∪ @ty{Label} = @ty{Label}}

要是换成带标签的和，记下每个值来自哪一
支，@math{@ty{Label} + @ty{Label}} 并不会坍缩成 @math{@ty{Label}}。
坍缩，是因为分支的记号被忘掉了。

既然两支是同一个类型，也就不必再分。@racket[mul] 当初要用
@racket[real?] 分辨 @racket[(cc)] 交出的是值还是@tech{延续}；在
@math{@ty{Label}} 上，不管交出哪一支，拿到的都是一个@tech{标签}，
既能当值存着，也能当@tech{延续}去调
用。@xref["01:label-from-call-cc"]{「从 call/cc 定义标签」}里那句
@racket[(define (label) (cc))]，就是这样一个不分支的 @racket[cc]。

@math{@ty{Label}} 是@defterm{否定的不动点}：它的反驳就是它自己。连
@racket[goto] 也是一个@tech{标签}：

@mm{@ty{Label} → ⊥ = ¬@ty{Label} = @ty{Label}}

之前所有的例子中，我们都是 @racket[goto] 配 @racket[label] 使用：

@racketblock[
(goto (label))]

但既然每个 @math{@ty{Label}} 同时也是一个合法的 @math{¬@ty{Label}}，
没有什么能阻止我们把@italic{任意}@tech{标签}传给任何其他@tech{标签}：

@racketblock[
((label) (label))]

用层数来数，@math{@ty{Label} = ¬@ty{Label} = ¬¬@ty{Label} = …}：
同一个类型，既能放在参数的位置，也能放在它的否定的位置。
层数分不清这两个角色了。这不是说@tech{标签}有了一个无穷大的层号，
而是根本没法给它一个与否定相容的有限层号。可以把它想成一座无穷高的否定
塔，每一层都是同一个 @math{@ty{Label}}；计数在这里失效了。

代价是，「有类型的程序就是证明」这个读法也失效了。有了
@math{@ty{Label}}，只用 @racket[λ] 和函数调用的有类型程序，
也不再保证终止：@racket[goto] 是一个 @math{@ty{Label}}，
把它交给它自己，

@racketblock[
(goto goto)]

类型是 @math{⊥}，却永远算不完。这并不是说用到 @math{@ty{Label}}
的程序都会循环。一个程序停不停，要看它自己怎样调用。

@subsection[#:tag "01:yin-yang"]{阴阳谜题}

把@tech{标签}直接交给@tech{标签}，就得到 David Madore 的阴阳谜题：

@examples[#:eval ev #:label #f
(eval:alts
 (let ([yin (label)])
   (displayln #\@)
   (let ([yang (label)])
     (display #\*)
     (yin yang)))
 (show-lines 5
  (λ ()
    (let ([yin (label)])
      (displayln #\@)
      (let ([yang (label)])
        (display #\*)
        (yin yang))))))]

两次 @racket[(label)] 交出的都是@tech{标签}。@racket[(yin yang)]
就是一次函数调用：同一个类型，@racket[yin] 当作@tech{延
续}，@racket[yang] 当作交给它的值。

程序里没有循环，没有计数器，也没有 @racket[set!]：只有两次
@racket[(label)]、两次打印和一次调用。输出却是一道无限增长的阶梯，
每一轮都比上一轮多打印一个 @racket[*]。多出来的那个 @racket[*]，
记在了哪里？

@subsubsection[#:tag "01:trace"]{追踪谜题}

给每个@tech{延续}一个唯一的名字
（@racket[k0]、@racket[k1]、@racket[k2]……），让每次
@racket[apply-cont] 都记录哪个@tech{延续}被应用于哪个：

@examples[#:eval ev #:label #f #:no-prompt
(define n -1)
(define (cc)
  (set! n (+ n 1))
  (let/cc k
    (define l
      (cons k (string->symbol
               (string-append "k" (number->string n)))))
    (apply-cont l l)))
(define (apply-cont kl l)
  (display (list (cdr kl) (cdr l)))
  (display #\tab)
  ((car kl) l))]

这里的 @racket[let/cc] 借的是 Racket 自带的那一个。前文的
@racket[let/cc]、@racket[call/cc]、@racket[cc] 是互相定义的，
插桩时需要一个现成的起点。

这里的@tech{延续}是函数和名字的 @racket[cons] 对，不能再直接调用。
「向@tech{延续}传递一个值」也就不再只是函数调用：@racket[apply-cont]
先拆开这个对，记下名字，再调用里面的函数。@racket[cc]
构造@tech{延续}，@racket[apply-cont] 消费@tech{延续}。插桩版的
@racket[cc] 在交回新@tech{延续}时，先把它交给它自己，
所以追踪里每个@tech{延续}第一次出现都是 @racket[(kn kn)] 这样的一行。
谜题改用这两个函数来写：

@examples[#:eval ev #:label #f
(eval:alts
 (let ([kn (cc)])
   (displayln #\@)
   (let ([kn+1 (cc)])
     (displayln #\*)
     (apply-cont kn kn+1)))
 (show-lines 10
  (λ ()
    (let ([kn (cc)])
      (displayln #\@)
      (let ([kn+1 (cc)])
        (displayln #\*)
        (apply-cont kn kn+1))))))]

追踪的每一项是一对名字：前一个是被跳向的目标，后一个是交给它的参数。
名字 @racket[kn]、@racket[kn+1] 只是程序里的占位；追踪里出现的
@racket[k0]、@racket[k1]、@racket[k2]……才是具体的@tech{延
续}。@racket[k0] 由第一处 @racket[(cc)] 捕获，而且只捕获这一次；之后的
@racket[k1]、@racket[k2]……都由第二处捕获。

@subsubsection[#:tag "01:matrix"]{读矩阵}

把追踪排列成矩阵：每一项 @c{(目标 参数)}，按参数放进行，按目标放进列，
越往左的列越新：

@out-block|{
      ...  k3   k2   k1   k0
k0                        @
k1                   *    @
k2              *    *    @
k3         *    *    *    @
...
}|

矩阵的每一行对应追踪输出中的一段，到 @racket[k0] 被调用为止。
每行从左往右读，就是执行的先后：追踪里的
@c{(k3 k3)*}、@c{(k2 k3)*}、@c{(k1 k3)*}、@c|{(k0 k3)@}| 正是第
@racket[k3] 行的 @racket[*]、@racket[*]、@racket[*]、@c|{@}|。
每一行正是原版谜题打印出的一行（插桩版为了配合追踪，
每个字符各占一行）。每行 @math{n} 打印 @math{n} 个 @racket[*] 和一个
@c|{@}|。这个模式来自：

@itemlist[#:style 'ordered
  @item{@bold{@racket[k0] 打印 @c|{@}|} 并捕获一个新的@tech{延续}
  @racket[kn+1]。}
  @item{@bold{@racket[kn+1] 打印 @racket[*]} 并跳向 @racket[kn]。}
  @item{@bold{每个 @racket[kn]} 被调用时，收到最近捕获的@tech{延续}
  @racket[k] 作为参数。}]
之所以能级联，是因为每个@tech{延续}都「记得」下一步要跳向哪个
@racket[kn]，形成一条链，每经过一次 @racket[k0] 就多一个链节。

@subsubsection[#:tag "01:rewrite"]{用函数重写}

这三条规律只涉及@tech{延续}之间谁调用谁、传的是什么。回到原来的谜题，
看第二处 @racket[(label)] 捕获的那条@tech{延续}：它收到一个值以后，
要做的就是这个捕获点后面剩下的程序，打印一个 @racket[*]，
再把收到的值交给 @racket[yin]。这件事写成函数，就是一个收 @racket[k]
的 @racket[kn+1]：打印 @racket[*]，再调用 @racket[(kn k)]。
第一处捕获的 @racket[k0] 也一样：它收到 @racket[kn] 以后，打印
@c|{@}|，捕获一条新的 @racket[kn+1]，再把 @racket[kn+1] 交给
@racket[kn+1]。跳向一个@tech{延续}，就是调用它；
捕获一个新@tech{延续}，就是定义一个新函数。

@racketblock[
(define (k0 kn)
  (displayln #\@)
  (define (kn+1 k)
    (display #\*)
    (kn k))
  (kn+1 kn+1))
(k0 k0)]

@racket[k0] 打印 @c|{@}|，定义一个新函数 @racket[kn+1] 打印 @racket[*]
并委托给 @racket[kn]，然后用自身调用 @racket[kn+1]：

@itemlist[
  @item{第一次调用时，@c{kn = k0}。打印 @c|{@}| 后，创建一个新闭包
  @racket[kn+1]（我们叫它 @racket[k1]），它打印 @racket[*] 并委托给
  @racket[k0]。然后 @racket[(kn+1 kn+1)] 用自身调用
  @racket[k1]：@racket[k1] 打印 @racket[*] 并调用 @racket[(k0 k1)]。}
  @item{现在回到 @racket[k0]，此时 @c{kn = k1}：打印 @c|{@}|，
  创建另一个新闭包 @racket[k2]，它打印 @racket[*] 并委托给
  @racket[k1]，然后调用 @racket[(k2 k2)]。@racket[k2] 打印 @racket[*]
  并调用 @racket[(k1 k2)]；@racket[k1] 打印 @racket[*] 并调用
  @racket[(k0 k2)]。}
  @item{以此类推：每次经过 @racket[k0] 都给委托链多加一环。}]
运行它，输出和前面一样。

这段代码里没有 @racket[label]、@racket[cc]，也没有 @racket[set!]。
原来由 @racket[cc] 捕获的@tech{延续}，现在都成了显式传递的参
数：@racket[k0] 收到 @racket[kn]，@racket[kn+1] 收到 @racket[k]，
每一次跳转都是把@tech{延续}交给下一个函数的尾调用。
这种把@tech{延续}作为参数传递的写法，叫
做@defterm[#:en "Continuation-Passing Style" #:abbr "CPS"]{延续传递风
格}；把程序改写成这种写法，就是 @defterm{CPS 变换}。

反过来看，原来的谜题就是这组@bold{互递归调用}，只是其中的@tech{延续}由
@racket[(label)] 在运行时捕获，而不是作为参数传进来。回忆我们说过的
@math{@ty{Label} = ¬@ty{Label}}，它是@tech{说谎者悖论}，
一个既不能判真也不能判假的命题。阴阳谜题就是那个悖论作为程序运行起来的
样子：永不终止地振荡，永远无法落定为真或为假。
