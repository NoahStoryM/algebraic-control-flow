#lang acf/scribble

@title[#:tag "03:2-local"]{局部延续}

全局的 @math{⊥} 从来不需要 @racket[⊥?] 这样的检查。分支能藏起来，靠的是什么？

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define ∘ compose)
(define id (∘))
(struct (r) ans ([a : r]) #:type-name Ans)
(define-type ⊥ᵃ (Ans Real))
(define ⊥ᵃ?   ans?)
(define a->⊥ᵃ ans)
(define ⊥ᵃ->a ans-a)
(define-syntax anf:let*-values
  (syntax-rules ()
    [(_ () b* ...)
     (anf:begin b* ...)]
    [(_ ([v* e]) b* ...)
     (λ (k) (e (λ v* ((anf:begin b* ...) k))))]
    [(_ ([v* e] [v** e*] ...) b* ...)
     (anf:let*-values ([v* e])
       (anf:let*-values ([v** e*] ...)
         b* ...))]))
(define-syntax anf:begin
  (syntax-rules ()
    [(_ b) b]
    [(_ b b* ...) (anf:let*-values ([_ b]) b* ...)]))
(define-syntax-rule (anf:let* ([v e] ...) b* ...)
  (anf:let*-values ([(v) e] ...) b* ...))
(define-syntax-rule (anf:if test conseq alt)
  (λ (k) (test (λ b* ((if (equal? b* '(#f)) alt conseq) k)))))]

@section[#:tag "03:local-k"]{局部延续}

@xref["02:first-class-control"]{「一等控制」}里 @tech[#:key "延续传递风格"]{CPS} 版的 @racket[mul] 也会提前返回，代码里却没有一处检查。它用到的只有四样东西：@math{⊥}、@math{¬p = p → ⊥}、@racket[a->⊥]、@racket[⊥->a]。把这四样全换成局部的版本，@racket[⊥ᵃ?] 大概也就用不着了。@math{⊥ᵃ}、@racket[a->⊥ᵃ]、@racket[⊥ᵃ->a] 已经有了，再补上否定：

@examples[#:eval ev #:no-result
(define-type (¬ₐ p ...) (→ p ... ⊥ᵃ))]

@defsym["¬ₐp" "局部否定：p → ⊥ᵃ，局部延续的类型"]@math{¬ₐp} 收下 @math{p}，交出局部答案 @math{⊥ᵃ}。这样的函数叫@defterm[#:en "local continuation"]{局部延续}。和 @racket[¬] 一样，它不限参数的个数，值域是 @math{⊥ᵃ} 的箭头从此都写成 @racket[¬ₐ]。代入 @tech[#:key "延续传递风格"]{CPS} 版的 @racket[mul]：

@examples[#:eval ev #:no-result
(: mul (→ Real * Real))
(define (mul . r*)
  (: loop/kₐ (¬ₐ (Listof Real) (¬ₐ Real)))
  (define (loop/kₐ r* kₐ)
    (if (null? r*)
        (kₐ (*))
        (let ([r (car r*)])
          (if (zero? r)
              (a->⊥ᵃ r)
              (loop/kₐ (cdr r*) (λ (v) (kₐ (* v r))))))))
  (⊥ᵃ->a (loop/kₐ r* a->⊥ᵃ)))]

四样东西都换成了局部的版本，代码里仍然没有一处 @racket[⊥ᵃ?]。还是那两组输入：

@examples[#:eval ev #:label #f
(mul 1 2 3 4)
(mul 1 2 0 3 4)]

照@xref["02:cps"]{「延续与 CPS」}的办法，把@tech{闭包链}写出来。把 @racket[(λ (v) (* v 3))] 记作 @racket[mul3]，其余类推。@racket[(mul 1 2 3 4)] 走到列表末尾时，手里的@tech{局部延续}是：

@racketblock[
(∘ a->⊥ᵃ mul1 mul2 mul3 mul4)]

原来写在 @racket[∘] 最左边、最后才调用的，是@tech{终结延续} @racket[a->⊥]；@racket[a->⊥ᵃ] 在这里是同一个角色：@tech{闭包链}的底，一个空栈。不同的是，@racket[a->⊥ᵃ] 只是一个普通的构造函数，不借用语言的跳转，所以整条@tech{闭包链}也都是普通的函数，算的是这段局部计算的答案。它们是局部计算里还没做完的工作，叫@tech{局部延续}，名副其实。

前一版的 @racket[loop] 每一步都要检查 @racket[(⊥ᵃ? result)]，因为累加器 @racket[result] 里可能装着提前拿到的答案。在这里，这个检查消失了：遇零就把零交给@tech{局部终结延续}，等着做乘法的@tech{延续}没有被调用，答案根本不经过后面的步骤。@racket[loop/kₐ] 的递归调用，以及每步向下一条@tech{延续}的调用，都在尾位置；待做的乘法保存在闭包里，宿主的栈不必替它们留帧。@racket[(mul 1 2 0 3 4)] 遇到零时，手里的@tech{局部延续}是 @racket[(∘ a->⊥ᵃ mul1 mul2)]。程序没有调用它，而是越过 @racket[mul1]、@racket[mul2]，直接调用写在最左边的 @racket[a->⊥ᵃ]：@racket[(a->⊥ᵃ r)] 交出答案，原路返回就是了。

回头看这次替换。四样东西里，@math{⊥} 是另外三样共同的落点：@math{¬p} 指向它，@racket[a->⊥] 把值送进它，@racket[⊥->a] 从它那里取回答案。把这个落点从 @math{⊥} 换成 @math{⊥ᵃ}，另外三样跟着换成局部的版本，代码的结构一点没变，@tech{闭包链}也只换了最左边的那一个。所有@tech{延续}都落在同一个终点上，这个终点可以叫作它们的@defterm[#:en "base"]{基}；这次替换，就是一次@defterm[#:en "change of base"]{换基}。

@section[#:tag "03:escape-discard"]{逃逸与丢弃}

@tech[#:key "延续传递风格"]{CPS} 版的 @racket[mul] 换上@tech{局部延续}，照常工作。嵌入语言呢？把@xref["02:split-k"]{「延续独占一层」}的 @racket[cps]、@xref["02:k-in-hand"]{「手中的延续」}的 @racket[cps:call/cc] 和@xref["02:hide-again"]{「再次隐藏延续」}的 @racket[anf:eval] 也换成局部的版本：

@examples[#:eval ev #:no-result
(define (((cps f) . p*) kₐq) (kₐq (apply f p*)))
(define ((cps:call/cc cps:proc) kₐp) ((cps:proc (cps kₐp)) kₐp))
(define (anf:eval kₐkₐa) (⊥ᵃ->a (kₐkₐa a->⊥ᵃ)))]

@examples[#:eval ev #:hidden
(define cps:id        (cps id))
(define cps:+         (cps +))
(define cps:*         (cps *))
(define cps:zero?     (cps zero?))
(define cps:car       (cps car))
(define cps:cdr       (cps cdr))
(define cps:null?     (cps null?))
(define cps:displayln (cps displayln))]

简单的算术照常运行：

@examples[#:eval ev #:label #f
(anf:eval
 (anf:let* ([v (cps:+ 1 2)]
            [w (cps:* v 3)])
   (cps:+ w 100)))]

用 @racket[cps:call/cc] 提前退出，就出事了。这回的循环把遇零的那一步写进一个绑定：遇零就 @racket[cps:return]，否则原样交出，后面的循环都写在它之后。这样，调用 @racket[cps:return] 以后还有没做的工作，看得出它有没有被丢掉：

@examples[#:eval ev #:label #f
(eval:error
 (anf:eval
  (cps:call/cc
   (λ (cps:return)
     (: cps:loop (→ (Listof Real) (¬ₐ (¬ₐ Real))))
     (define (cps:loop r*)
       (anf:begin
        (cps:displayln r*)
        (anf:if (cps:null? r*)
                (cps:*)
                (anf:let* ([r (cps:car r*)]
                           [r (anf:if (cps:zero? r) (cps:return r) (cps:id r))]
                           [r* (cps:cdr r*)]
                           [res (cps:loop r*)])
                  (cps:* res r)))))
     (cps:loop '(1 2 0 3 4))))))]

乘法收到的是一个 @racket[ans] 结构体，不是数。答案漏到了不该去的地方。

问题出在 @racket[cps:call/cc] 交给 @racket[cps:proc] 的那条逃逸用的@tech{延续} @racket[(cps kₐp)] 上。展开 @racket[cps]，看它做了什么：

@racketblock[
(((cps kₐp) . p*) kₐq)  =  (kₐq (kₐp . p*))]

@racket[(cps kₐp)] 收下参数，调用 @racket[kₐp]，再把结果交给当前@tech{延续} @racket[kₐq]。@racket[(kₐp . p*)] 不在尾位置：外面还有 @racket[kₐq] 等着它返回。可在原来以 @math{⊥} 为终点的版本里，等着的 @racket[kq] 从来没有被调用过。@xref["02:k-in-hand"]{「手中的延续」}里，@racket[cps:proc2] 后面那一步加 1「再也轮不到」：@racket[kp] 一路走到@tech{终结延续} @racket[a->⊥]，一调用就 @racket[raise] 走了，不再回来，等着它的 @racket[kq] 也就永远轮不到。@xref["01:pairing"]{「两种配对」}要 @racket[kp] 不回来，为的也是这一点：直接调用它以后，后面剩下的工作走不到。宿主的跳转一直在替我们丢掉 @racket[kq]，只是我们没有注意到。

@tech{局部延续}不会跳走。@racket[(kₐp . p*)] 交出一个 @racket[ans]，正常返回，@racket[(kₐq …)] 第一次真的运行了。报错说的就是这件事：@racket[kₐq] 把答案当作中间结果交给了乘法，乘法不认识它。

@defsym["cps*" "把局部延续提升成丢弃当前延续的 CPS 箭头"]既然 @racket[(kₐp . p*)] 已经得到了答案，直接交出就行，不必理会 @racket[kₐq]：

@examples[#:eval ev #:no-result
(define (((cps* kₐp) . p*) kₐq) (apply kₐp p*))
(define ((cps:call/cc cps:proc) kₐp) ((cps:proc (cps* kₐp)) kₐp))]

@racket[cps*] 收下当前@tech{延续} @racket[kₐq]，却不用它，用保存的 @racket[kₐp] 直接交出答案。对 @racket[kₐp] 的调用也回到了尾位置，再没有谁等它返回。跳转就是替换当前@tech{延续}：@racket[goto] 和 @racket[call/cc] 靠语言内置的机制替换，@racket[cps*] 亲手做了同样的事。

换上修好的 @racket[cps:call/cc]，再跑一遍前面的例子，遍历在遇到零的那一步停了下来：

@examples[#:eval ev #:label #f
(anf:eval
 (cps:call/cc
  (λ (cps:return)
    (define (cps:loop r*)
      (anf:begin
       (cps:displayln r*)
       (anf:if (cps:null? r*)
               (cps:*)
               (anf:let* ([r (cps:car r*)]
                          [r (anf:if (cps:zero? r) (cps:return r) (cps:id r))]
                          [r* (cps:cdr r*)]
                          [res (cps:loop r*)])
                 (cps:* res r)))))
    (cps:loop '(1 2 0 3 4)))))]

@section[#:tag "03:nested"]{边界中的边界}

@tech[#:key "延续传递风格"]{CPS} 的代码里用不到 @racket[⊥ᵃ?]。那么在整段局部计算里，和 @math{⊥ᵃ} 打交道的只剩 @racket[a->⊥ᵃ] 和 @racket[⊥ᵃ->a] 这一对：值放进去，同一个值取出来。中间既然没有谁查看 @racket[Ans] 的内部，结构体这层包装就什么也没做，可以取@defterm[#:en "trivial representation"]{平凡表示}：

@examples[#:eval ev #:no-result
(define-type ⊥ᵃ Real)
(define a->⊥ᵃ id)
(define ⊥ᵃ->a id)]

@tech{局部延续} @math{¬ₐp} 成了 @math{p → @ty{Real}}，一个普通的函数，没有结构体，也没有跳转。@tech{闭包链}的底成了 @racket[id]，写不写都一样：

@racketblock[
#,(hspace 2)(∘ a->⊥ᵃ mul1 mul2 mul3 mul4)
= (∘ id     mul1 mul2 mul3 mul4)
= (∘        mul1 mul2 mul3 mul4)]

链上只剩那一串乘法。

回到刚才报错的 @racket[(kₐq (kₐp . p*))]：@racket[(kₐp . p*)] 现在交出 @math{⊥ᵃ}，在这里就是 @racket[Real]；调用 @racket[(cps kₐp)] 的地方，等的正是一个 @math{⊥ᵃ}（例子里它在乘法的位置上，等一个实数），类型对得上：不丢掉 @racket[kₐq]，也不再报错。可控制的行为变了：调用捕获的函数，做完以后会回到调用处，接着做 @racket[kₐq] 的工作。于是原来那个 @racket[cps:call/cc] 的定义本来就有意义，只是捕获的不再是会跳走的@tech{延续}，而是一个普通函数，@tech{局部延续}：

@examples[#:eval ev #:no-result
(define ((cps:call/lc cps:proc) kₐp) ((cps:proc (cps kₐp)) kₐp))]

@defsym["cps:call/lc" "以当前局部延续调用（call with local continuation），交给程序的是 (cps kₐp)"]@racket[cps:call/lc]（call with local continuation），和最初的 @racket[cps:call/cc] 逐字相同。可 @racket[(cps kₐp)] 的行为变了：@racket[kₐp] 这条@tech{闭包链}的底不再是 @racket[ans]，而是 @racket[id]，那个空栈什么也不做，调用它，做完局部的工作就正常返回，@racket[kₐq] 接着运行。调用被捕获的@tech{延续}不再是跳转，而是复合，一次普通的函数调用。

把前面例子里的 @racket[cps:call/cc] 换成 @racket[cps:call/lc]：

@examples[#:eval ev #:label #f
(anf:eval
 (cps:call/lc
  (λ (cps:return)
    (define (cps:loop r*)
      (anf:begin
       (cps:displayln r*)
       (anf:if (cps:null? r*)
               (cps:*)
               (anf:let* ([r (cps:car r*)]
                          [r (anf:if (cps:zero? r) (cps:return r) (cps:id r))]
                          [r* (cps:cdr r*)]
                          [res (cps:loop r*)])
                 (cps:* res r)))))
    (cps:loop '(1 2 0 3 4)))))]

@racket[(cps:return r)] 没有跳出循环。和修好的 @racket[cps:call/cc] 相比，多出来的三行，正是 @racket[cps*] 丢掉的那部分工作：遇到零没有跳走，循环接着往下，把零乘进了后面的每一步，结果仍然是零。

这一切成立，前提是 @math{⊥ᵃ} 取了@tech{平凡表示}。@racket[cps:call/lc] 用的是最初 @racket[cps:call/cc] 的定义，换回结构体表示，就会出前面那个错。要在结构体表示下也能用 @racket[cps:call/lc]，就得把@tech{平凡表示}里藏起来的那一步转换亲手写出来，用 @racket[⊥ᵃ->a] 取出答案：

@racketblock[
(define ((cps:call/lc cps:proc) kₐp)
  (define (kp p) (⊥ᵃ->a (kₐp p)))
  ((cps:proc (cps kp)) kₐp))]

交给 @racket[cps:proc] 的函数 @racket[(λ (p) (⊥ᵃ->a (kₐp p)))] 收下一个值，沿 @racket[kₐp] 的@tech{闭包链}做完局部的工作，在链底碰到 @racket[a->⊥ᵃ]，再由外面的 @racket[⊥ᵃ->a] 取出答案。这和 @racket[anf:eval] 是同一个结构：

@racketblock[
(define (anf:eval kₐkₐa) (⊥ᵃ->a (kₐkₐa a->⊥ᵃ)))]

@racket[a->⊥ᵃ] 和 @racket[⊥ᵃ->a] 划出的那条边界，出现在了 @racket[cps:call/lc] 的内部。里面有自己的 @racket[⊥ᵃ->a]，划出自己的@tech{界桩}；外面只看到一个正常返回的值。局部计算里，有了局部计算。

这个结构在 @racket[cps:call/lc] 的内部自然地出现了。程序员要是也能显式地做同样的事，在局部计算里划出新的边界，用新的 @racket[a->⊥ᵃ] 开始一段子计算，@racket[cps:call/lc] 捕获的@tech{闭包链}就到那个新的起点为止：边界限定了捕获的范围。

怎样在一段局部计算里开启另一段？@racket[anf:eval] 已经能运行一段计算，只是它本身还是一个普通函数。用 @racket[cps] 把它提升成一支 @tech{CPS 箭头}：

@examples[#:eval ev #:no-result
(define anf:reset (cps anf:eval))]

@defsym["anf:reset" "(cps anf:eval)：在当前局部计算里开启一段新的局部计算"]@racket[anf:reset] 调用 @racket[anf:eval] 运行里面的计算。@racket[anf:eval] 交给它一条新的@defterm[#:en "local terminal continuation"]{局部终结延续}；里面得出答案以后，@racket[cps] 再把答案交给外面的@tech{延续}。于是里面有了自己的起点，外面只看到一个正常返回的值。每次 @racket[anf:reset] 都开启一段新的局部计算，在当前的边界里再划出一条边界。里面的世界尽头，从外面看，只是一次子计算返回了。

在这条新边界里提前返回，该怎么写？被它丢下的那段工作，又能不能交给程序？
