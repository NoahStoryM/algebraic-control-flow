#lang acf/scribble

@title[#:tag "04:5-broken"]{镜子破裂}

到目前为止，对应表一直用在编译器自己的代码上：@racket[ctx] 由 @racket[shift] 取得，@racket[id] 写成 @racket[(reset (shift k k))]。源程序里也可以出现 @racket[reset] 和 @racket[shift]，同一张表也告诉我们该怎样编译它们。

@racket[reset] 开启一段新的局部计算，对编译器来说，就是从@tech{局部终结延续} @racket[id] 开始编译它的主体，再把得到的@tech{局部答案}命名后交给 @racket[ctx]。@racket[shift] 对源程序做的事，和@tech{命名延续}时 @racket[if] 分支对编译器做的事一样：把@tech{局部延续}写成一个 lambda，绑定到一个名字。区别在于 @racket[if] 的情况下编译器自己选了名字（从 @racket[fk] 得到 @racket[kn]），这里则由程序员提供名字（@racket[k]），@tech{局部延续}在源代码中可见：

@racketblock[
[`(reset ,body)
 (shift ctx
   (define vn (fv))
   `(let ([,vn ,(anf1 body id)])
      ,(ctx vn)))]
[`(shift ,k ,body)
 (shift ctx
    (define vn (fv))
    `(let ([,k (λ (,vn) ,(ctx vn))])
       ,(anf1 body id)))]]

@racket[shift] 分支里有两个 @racket[shift]。源程序的 @racket[shift] 是被编译的对象；编译器自己的 @racket[shift] 取得此刻的 @racket[ctx]，而 @racket[ctx] 要打印的，正是源程序中从这个 @racket[shift] 到最近 @racket[reset] 的剩余工作。编译器把它打印成 lambda，绑定给 @racket[k]。主体用 @racket[id] 编译：按@xref["03:rules"]{「规约规则」}，@racket[shift] 的主体在边界处运行，@tech{局部延续}是空的。

有了 @racket[reset]，@racket[let] 绑定的东西变了。此前每个 @racket[let] 绑定的都是一个 @racket[_atom]：一个值，或者一次调用。@racket[reset] 分支发射的 @racket[let]，绑定位置上是 @racket[(anf1 body id)]，主体编译出来的一整段 @racket[_anf]。文法必须演化来容纳这一点：

@racketgrammar*[
#:literals (λ if let)
[anf val if-form (let ([var anf]) anf) apply-proc]
[apply-proc (val val ...)]
[if-form anf-if (let ([kvar proc]) anf-if)]
[anf-if (if val anf anf)]
[kvar var]
[val var literal proc]
[proc (λ head anf)]
[head var (var ...) (var ... . var)]]

@racket[_atom] 消失了。有了定界之后，代码不再是单栈线性序列。@racket[let] 绑定现在可以绑定一个 @racket[_anf]，一个拥有自己栈的定界计算。

函数调用改叫 @racket[_apply-proc]，直接列进了 @racket[_anf]；它的参数仍然是 @racket[_val]。

先试两个简单的例子：

@(define ev-delim (make-acf-eval))
@examples[#:eval ev-delim #:hidden
(require (submod acf/zh/04-compiler/code stage-delimited))]

@examples[#:eval ev-delim #:label #f
(anf '(reset (+ 1 (shift k (k 42)))))
(anf '(+ 10 (reset (+ 1 (shift k 42)))))]

第二个输出里，外层 @racket[let] 把 @racket[v.1] 绑定到一整条 @racket[let] 链 @racket[(let ([k ...]) 42)]，加十排在它后面，用的是 @racket[v.1]。这就是 @racket[(let ([_var _anf]) _anf)] 产生式的实例。

定界之前，@racket[let] 绑定总是一个 @racket[_atom]，一次单独的操作。现在一个绑定可以是整个 @racket[_anf]，一个拥有自己栈的定界计算：

@racketblock[
(code:comment "定界之前：扁平的。每个 let 扩展同一个栈")
(let ([v.2 (g a)]) (let ([v.1 (f v.2)]) (let ([v.0 (h v.1)]) v.0)))
(code:comment "定界之后：嵌套的。内层 let 链运行、产出一个值、")
(code:comment "返回外层栈")
(let ([v.1 (let ([k ...]) 42)])
  (let ([v.0 (+ 10 v.1)]) v.0))]

简单情况没问题。再拿阴阳谜题来试。@xref["03:meta"]{「元延续」}把@xref["01:4-fixed-point"]{第一章}的 @racket[(label)] 写成了 @racket[(let/lc k k)]：谜题中的延续都只在 @racket[reset] 的尾位置调用，@tech{局部延续}就够用。

@racketblock[
(reset
 (let ([kn (let/lc k0 k0)])
   (displayln #\@)
   (let ([km (let/lc kn+1 kn+1)])
     (display #\*)
     (kn km))))]

@section[#:tag "04:inline-yin-yang"]{内联的阴阳谜题}

编译器还不认识 @racket[let/lc]。@xref["03:abort-shift"]{「从 return 到 shift」}说过，@racket[shift] 做两件事，捕获与跳转，也可以只留下一样。主体把结果交回给捕获的延续，跳转就被撤销了，剩下的只是捕获：@racket[(shift k (k e)) = (let/lc k e)]。第三章正是这样把 @racket[let/lc] 定义成 @racket[shift] 的宏，编译器也只需把它展开，交给已有的 @racket[shift] 分支。@racket[let*] 则展开成嵌套的单绑定 @racket[let]：

@racketblock[
[`(let/lc ,k ,body)
 (anf0 `(shift ,k (,k ,body)))]
[`(let* () ,body)
 (anf0 body)]
[`(let* ([,x ,e] . ,bind*) ,body)
 (anf0 `(let ([,x ,e]) (let* ,bind* ,body)))]]

先去掉 @racket[display]，只看控制结构：

@examples[#:eval ev-delim #:label #f
(anf '(reset
       (let* ([kn (let/lc k0 k0)]
              [km (let/lc kn+1 kn+1)])
         (kn km))))]

编译后的代码只包含别名绑定（@racket[kn = v.1]，@racket[km = v.2]）和两个真正的 lambda：两个被捕获的延续。两条清理规则就能恢复@xref["01:4-fixed-point"]{第一章}的互递归。传播别名：把每个 @racket[v.N] 替换为它被绑定的来源名字。消除尾绑定：@racket[(let ([v expr]) v)] 就是 @racket[expr]。结果是：

@racketblock[
(let ([k0 (λ (kn)
            (let ([kn+1 (λ (km) (kn km))])
              (kn+1 kn+1)))])
  (k0 k0))]

@(define ev-run (make-acf-eval))
@examples[#:eval ev-run #:hidden
(require racket/list racket/string)
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

插入打印 @c|{@}| 和 @racket[*] 的 @racket[display] 调用，改写为 @racket[define] 形式：

@examples[#:eval ev-run #:label #f #:no-prompt
(define (k0 kn)
  (displayln #\@)
  (define (kn+1 km)
    (display #\*)
    (kn km))
  (kn+1 kn+1))]

启动它和启动编译后的代码一样，@racket[k0] 拿到的参数是它自己：

@examples[#:eval ev-run #:label #f
(eval:alts (k0 k0) (show-lines 5 (λ () (k0 k0))))]

@xref["01:4-fixed-point"]{第一章}的互递归，逐行对应。那里我们读着追踪输出写出了它；这里编译器从源代码推导出了它。

不过@xref["03:meta"]{「元延续」}的写法和第一章并不完全相同。第一章的 @racket[label] 是一个函数，谜题里的 @racket[(label)] 是对它的调用；那里把调用处直接换成了 @racket[(let/lc k k)]。把 @racket[let/lc] 放回函数里，写回第一章的样子：

@examples[#:eval ev-delim #:label #f
(anf '(reset
       (let* ([label (λ () (let/lc k k))]
              [yin   (label)]
              [_     (displayln #\@)]
              [yang  (label)]
              [_     (display #\*)])
         (yin yang))))]

和上一个版本相比，唯一的差别是 @racket[let/lc] 被包进了一个 lambda。程序编译没有报错。运行它：

@examples[#:eval ev-delim #:label #f
(void (eval (anf '(reset
             (let* ([label (λ () (let/lc k k))]
                    [yin   (label)]
                    [_     (displayln #\@)]
                    [yang  (label)]
                    [_     (display #\*)])
               (yin yang))))))]

两个字符，然后程序就结束了。无穷阶梯在第一步之后就停了。

@section[#:tag "04:diagnosis"]{诊断}

看 @racket[label] 编译成了什么：

@racketblock[
(λ () (let ([k (λ (v.1) v.1)]) (let ([v.2 (k k)]) v.2)))]

@racket[k] 被绑定成了恒等函数。它本该是调用 @racket[(label)] 之后的剩余工作：绑定 @racket[yin]，打印 @c|{@}|，再调用一次 @racket[label]，一直到 @racket[(yin yang)]。可这些工作都在 lambda 外面。编译器处理 @racket[(λ () ...)] 时，用 @racket[(anf1 body id)] 编译主体，走到 @racket[shift] 分支时手上的 @racket[ctx] 是 @racket[id]，能打印的只有恒等函数。于是 @racket[(label)] 返回恒等函数，@racket[yin] 和 @racket[yang] 都是它，@racket[(yin yang)] 调用一次就结束了。

内联的版本里，@racket[reset] 和 @racket[shift] 之间的剩余工作都写在同一个表达式里。编译器从外往里走，走到 @racket[shift] 时，手上的 @racket[ctx] 就是完整的剩余工作。函数不同：lambda 的主体在定义处编译，调用处的剩余工作写在别的地方，编译主体时根本不在 @racket[ctx] 里。

主体用 @racket[id] 编译，是因为每次函数调用都从空栈开始；@racket[reset] 分支也用 @racket[id]，因为 @racket[reset] 开启一段新的局部计算。@xref["03:call"]{「函数调用」}说过：在函数里调用另一个函数，被调用者从自己的空栈开始执行；@racket[reset] 做的是同一件事。编译器把这个等同忠实地带进了代码，函数调用和 @racket[reset] 一样，都在定界。

两个特性分开时都能工作。没有 @racket[reset]/@racket[shift]，函数调用定界不会被察觉：每个 lambda 主体从 @racket[id] 开始，没有 @racket[shift] 需要看到调用处。没有函数，@racket[reset]/@racket[shift] 也能正确编译，内联的谜题就是证据。两者同时出现时，lambda 主体里的 @racket[shift] 要取得的@tech{局部延续}，应当越过函数调用，一直延伸到 @racket[reset]。函数调用和 @racket[reset] 在这里被要求表现不同：@racket[reset] 仍然定界，函数调用却不能再定界。

文法也说明了这一点。@racket[_proc] 产生式是 @racket[(λ _head _anf)]：lambda 的主体是一段完整的 @racket[_anf]，文法中没有任何东西让调用处的剩余工作进入主体。

再用一个更小的例子确认。一个函数，主体包含 @racket[shift]，在 @racket[reset] 内部、一个还有剩余工作的调用处被调用：

@examples[#:eval ev-delim #:label #f
(anf '(reset (let ([f (λ (x) (shift k 999))]) (add1 (f 42)))))]

我们期望 @racket[999]：@racket[f] 执行 @racket[shift]，丢弃捕获的延续，直接把 @racket[999] 交给 @racket[reset] 边界。追踪编译后的代码，@racket[k] 又被绑定成了恒等函数，lambda 主体自己的@tech{局部终结延续}，而不是调用处的剩余工作。@racket[f] 返回 @racket[999] 之后，外层代码绑定 @racket[v.3 = 999] 并计算 @racket[(add1 v.3) = 1000]。期望：@racket[999]。实际：@racket[1000]。

@racket[reset] 仍须定界，函数调用不能再定界；lambda 主体里的 @racket[shift] 要拿到调用处的剩余工作，从哪里拿？
