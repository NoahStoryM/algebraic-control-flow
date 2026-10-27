#lang acf/scribble

@title[#:tag "01:3-fixed-point"]{否定的不动点}

还有一个类型我们早就认识，却一直没拿来代入：@racket[Label]。
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

@section[#:tag "01:label-sub"]{代入 @racket[Label]}

把 @racket[Label] 代入@tech{排中律} @math{p ∨ ¬p}。
按定义，@math{¬@ty{Label}} 就是 @racket[Label]，
两个分支成了同一个类型：

@mm{@ty{Label} ∨ ¬@ty{Label} = @ty{Label} ∨ @ty{Label}}

一真一假的两支，在这里分不出真假。@xref["01:types-to-logic"]{「从类型
到逻辑」}说过，Typed Racket 的 @racket[∪] 是普通的并集，
不记录值从哪一边来；两边既然是同一个类型，并起来就只剩它自己：

@mm{@ty{Label} ∪ @ty{Label} = @ty{Label}}

要是换成不相交的联合，每个值都记着自己来自哪一支，两支就不会并成一支。
坍缩，是因为分支的记号被忘掉了。

既然两支是同一个类型，也就不必再分。@racket[mul] 当初要用
@racket[real?] 分辨 @racket[(cc)] 交出的是值还是@tech{延续}；在
@racket[Label] 上，不管交出哪一支，拿到的都是一个@tech{标签}，
既能当值存着，也能当@tech{延续}去调
用。@xref["01:label-from-call-cc"]{「从 call/cc 定义标签」}里那句
@racket[(define (label) (cc))]，就是这样一个不分支的 @racket[cc]。

@racket[Label] 是@defterm{否定的不动点}：它的反驳就是它自己。连
@racket[goto] 也是一个@tech{标签}：

@mm{@ty{Label} → ⊥ = ¬@ty{Label} = @ty{Label}}

之前的例子里，我们总是先用 @racket[(label)] 造一个@tech{标签}，
存进变量，再交给 @racket[goto] 跳回去。省掉中间的变量，就是：

@racketblock[
(goto (label))]

@tech{标签}在这里只当跳转的目标。但既然每个 @racket[Label]
同时也是一个合法的 @math{¬@ty{Label}}，没有什么能阻止我们把@italic{任
意}@tech{标签}传给任何其他@tech{标签}：

@racketblock[
((label) (label))]

再数一数层数。假如给@tech{标签}定一个层号，比如第 @math{n} 层；可
@math{@ty{Label} = ¬@ty{Label}}，它同时也在第 @math{n+1} 层，
再往上又在第 @math{n+2} 层……层号还数得出来，
可数出来的层号分不出任何东西。可以把它想成一座无穷高的否定塔，
每一层都是同一个 @racket[Label]；层数在这里不再能区分角色，
分不清一个@tech{标签}是被调用的那个，还是交出去的那个。

代价是，「有类型的程序就是证明」这个读法也失效了。有了
@racket[Label]，只用 @racket[λ] 和函数调用的有类型程序，
也不再保证终止。把 @racket[goto] 交给它自己，

@racketblock[
(goto goto)]

类型是 @racket[⊥]，却永远算不完。

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

要回答这个问题，得看清每一步跳向了谁。给每个@tech{延续}起一个名
字：@racket[k0]、@racket[k1]、@racket[k2]……先写一个插桩版的
@racket[cc]，每捕获一个@tech{延续}，就给它配上一个新编号：

@examples[#:eval ev #:label #f #:no-prompt
(define n -1)
(define (cc)
  (set! n (+ n 1))
  (let/cc kn    (define ln (cons kn n))
    (apply-cont ln ln)))]

这里的 @racket[let/cc] 是 @racket[call/cc] 的简
写：@racket[(let/cc kn body ...)] 就是
@racket[(call/cc (λ (kn) body ...))]，给当前@tech{延续}起个名字
@racket[kn]。这样的@tech{延续}是一个 @racket[cons] 对，
不再是能直接调用的函数，调用它的办法得我们自己规定。这也是当初单独给
@racket[apply-cont] 起名字的用意：「向@tech{延续}传一个值」
是一个独立的操作，@tech{延续}换一种表示，它就不再只是函数调
用。@racket[apply-cont] 拆开两个对，印出谁跳向谁，再调用里面的函数：
@examples[#:eval ev #:label #f #:no-prompt
(define (apply-cont ln lm)
  (match-define (cons kn n) ln)
  (match-define (cons km m) lm)
  (display (format "  (k~a k~a)" n m))
  (kn lm))]插桩版的 @racket[cc] 交出新@tech{延续}之前，先用 @racket[apply-cont]
拿它调用它自己，所以每个@tech{延续}第一次出现，都是 @racket[(kn kn)]
这样一项。

把谜题里的 @racket[label] 换成 @racket[cc]，调用换成
@racket[apply-cont]，打印照旧：

@examples[#:eval ev #:label #f
(eval:alts
 (let ([kn (cc)])
   (displayln #\@)
   (let ([kn+1 (cc)])
     (display #\*)
     (apply-cont kn kn+1)))
 (show-lines 4
  (λ ()
    (let ([kn (cc)])
      (displayln #\@)
      (let ([kn+1 (cc)])
        (display #\*)
        (apply-cont kn kn+1))))))]

每一项是一对名字，前一个是被跳向的目标，后一个是交给它的参数。程序里的
@racket[kn]、@racket[kn+1] 只是变量名；印出来的
@racket[k0]、@racket[k1]、@racket[k2]……才是一条条具体的@tech{延
续}。@racket[k0] 由第一处 @racket[(cc)] 捕获，
只有这一条；@racket[k1]、@racket[k2]……都由第二处捕获。

@subsubsection[#:tag "01:rules"]{读出规律}

规律就在每一对名字里。右边是交出去的参数，总是最近捕获的那条@tech{延
续}，记作 @racket[km]；左边是当前被调用的那条。调用的若是
@racket[(kn+1 km)]，打印一个 @racket[*]，下一步就是 @racket[(kn km)]，
把同一个 @racket[km] 交给前一条：@racket[kn+1] 被捕获时，@racket[yin]
绑的正是 @racket[kn]，它记下的就是这一条。调用的若是
@racket[(k0 km)]，打印 @c|{@}|，下一步捕获一条新的 @racket[km+1]，从
@racket[(km+1 km+1)] 开始。每到一次 @racket[k0]，就多一条@tech{延续}，
下一行就要多退一步，多打印一个 @racket[*]。

这条规律只说@tech{延续}之间谁调用谁、交出的是什么，照着写成函数就行：
跳向一条@tech{延续}，就是调用它；捕获一条新@tech{延续}，
就是定义一个新函数。

@examples[#:eval ev #:label #f
(define (k0 kn)
  (displayln #\@)
  (define (kn+1 km)
    (display #\*)
    (kn km))
  (kn+1 kn+1))
(eval:alts (k0 k0) (show-lines 5 (λ () (k0 k0))))]

输出和原版谜题一模一样。

这段代码里没有 @racket[label]、@racket[cc]，也没有 @racket[set!]。
原来由 @racket[cc] 捕获的@tech{延续}，现在都成了显式传递的参
数：@racket[k0] 收到 @racket[kn]，@racket[kn+1] 收到 @racket[km]，
每一次跳转都是把@tech{延续}交给下一个函数的尾调用。
这种把@tech{延续}作为参数传递的写法，叫
做@defterm[#:en "Continuation-Passing Style" #:abbr "CPS"]{延续传递风
格}；把程序改写成这种写法，就是 @defterm{CPS 变换}。

反过来看，原来的谜题就是这组@bold{互递归调用}，只是其中的@tech{延续}由
@racket[(label)] 在运行时捕获，而不是作为参数传进来。回忆我们说过的
@math{@ty{Label} = ¬@ty{Label}}，它是@tech{说谎者悖论}，
一个既不能判真也不能判假的命题。阴阳谜题就是那个悖论运行起来的样子：
同一个@tech{标签}一会儿被调用，一会儿被交出去，永远落不了地。
