#lang acf/scribble

@title[#:tag "03:6-a-translation"]{否定翻译与 A-翻译}

答案那一支，在没有@tech{延续}的 @racket[mul] 里看得见：@racket[real*] 交出的是 @math{@ty{Real}ᵃ}，普通的实数或者打了@tech{标记}的答案。

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define ∘ compose)
(define id (∘))
(define-type ⊥ᵃ a)
(define-type (¬ₐ p ...) (→ p ... ⊥ᵃ))
(define a->⊥ᵃ id)]

@section[#:tag "03:a-translation"]{A-翻译}

把一个普通结果的类型 @math{p} 当作一个整体，不拆开，这个变化可以写成 @math{pᵃ = p ∨ a}：普通的结果，或者提前到来的答案。@math{⊥} 没有普通的元素，@math{⊥ᵃ = ⊥ ∨ a} 就只剩答案那一支，打上@tech{标记}以后就是 @racket[(Ans a)]。整个类型照三条规则翻译：当作整体的普通类型 @math{p} 译作 @math{p ∨ a}；@math{⊥} 译作 @math{⊥ᵃ}，也就是只剩答案那一支；箭头按结构译，@math{(p → q)ᵃ = pᵃ → qᵃ}。比如 @math{@ty{Real} → @ty{Bool}} 译成 @math{(@ty{Real} ∨ a) → (@ty{Bool} ∨ a)}。这种以答案类型 @math{a} 为参数的翻译，叫作@defterm[#:en "A-translation"]{A-翻译}。

@xref["02:cps"]{「延续与 CPS」}以后，一段结果类型为 @math{p} 的计算，编码成双重否定 @math{(p → ⊥) → ⊥}，@tech{否定翻译}给类型裹上的也是这两层否定。对它做 @tech{A-翻译}，@math{p} 变成 @math{pᵃ}，@math{⊥} 变成 @math{⊥ᵃ}，两支箭头照结构译：

@mm{(p → ⊥) → ⊥ @hspace[2] ⟼ @hspace[2] (pᵃ → ⊥ᵃ) → ⊥ᵃ}

翻译以后的计算，等着一个 @math{pᵃ → ⊥ᵃ} 的函数。@math{pᵃ} 是 @math{p ∨ a}，交给这个函数的，可能是普通的值，也可能是提前到来的答案，两种情形都得有去处。处理一个「或」，就是两种情形各给一个函数，两种写法可以来回构造：

@mm{(p ∨ a) → ⊥ᵃ @hspace[2] ⇔ @hspace[2] (p → ⊥ᵃ) ∧ (a → ⊥ᵃ)}

所以翻译以后，计算等着的是两条@tech{局部延续}：一条 @math{¬ₐp} 接普通的值，一条 @math{¬ₐa} 接提前到来的答案。照这个样子写 @racket[mul]，前一条叫 @racket[kₐ]，后一条叫 @racket[iₐ]：

@examples[#:eval ev #:label #f #:no-prompt
(: mul (→ Real * Real))
(define (mul . r*)
  (: loop/ki (¬ₐ (Listof Real) (¬ₐ Real) (¬ₐ Real)))
  (define (loop/ki r* kₐ iₐ)
    (if (null? r*)
        (kₐ (*))
        (let ([r (car r*)])
          (if (zero? r)
              (iₐ r)
              (loop/ki (cdr r*) (λ (v) (kₐ (* v r))) iₐ)))))
  (loop/ki r* a->⊥ᵃ a->⊥ᵃ))]

起步时交进去的两条，是同一个 @racket[a->⊥ᵃ]。@tech{平凡表示}下 @racket[⊥ᵃ->a] 就是 @racket[id]，最后一行也就不必再包它。还是那两组输入：

@examples[#:eval ev #:label #f
(mul 1 2 3 4)
(mul 1 2 0 3 4)]

乘到头，结果交给 @racket[kₐ]；遇到零，答案交给 @racket[iₐ]。像这样同时收两条@tech{延续}的 @tech[#:key "延续传递风格"]{CPS}，叫作@defterm{double-barrelled CPS}。两条@tech{延续}的待遇不一样。@racket[kₐ] 每深入一层，就在前面接上一步乘法。@racket[iₐ] 原样传下去，从头到尾都是开始时交进来的那一个，也就是@tech{局部终结延续} @racket[a->⊥ᵃ]。@xref["02:cps"]{「延续与 CPS」}里尾递归的 @racket[fact/k]，也是这样原样传递 @racket[k] 的。

@section[#:tag "03:one-continuation"]{只传一个延续}

从不改变的参数，不必当参数传。去掉 @racket[iₐ]，把 @racket[(iₐ r)] 直接写成 @racket[(a->⊥ᵃ r)]，剩下的就是@xref["03:local-k"]{「局部延续」}里的 @racket[loop/kₐ]。翻译以后要两条@tech{延续}，这一章的代码却一直只传一条，原因就在这里：另一条是固定的。它在一段局部计算里不变；@racket[anf:reset] 开启新的一段局部计算，那一段就有它自己的这一条，值也是 @racket[id]，接住的却是新边界里的答案。

这一步是把 @racket[iₐ] 固定成 @racket[a->⊥ᵃ]，不是把两种写法说成一样：要是交进来的 @racket[iₐ] 真会变，不同的计算在这里可能被看成同一个。这一章的局部计算里，交进来的始终是那一个，所以可以这样做。

计算于是只等着 @math{kₐ : p → ⊥ᵃ}，类型成了 @math{(p → ⊥ᵃ) → ⊥ᵃ}。再取已经用过的@tech{平凡表示} @math{⊥ᵃ = a}，就得到 @math{(p → a) → a = ¬ₐ¬ₐp}，正是这一章用的局部编码。两条路分别落在 @racket[cps] 和 @racket[cps*] 上：@racket[cps] 把结果交给当前的@tech{延续}；@racket[cps*] 丢掉当前的@tech{延续}，改用手里存着的那一条。@racket[cps:abort] 就是 @racket[(cps* a->⊥ᵃ)]，把值交给被省掉的那条@tech{局部终结延续}。

开头不带@tech{延续}的 @racket[mul] 走的也是这两条路，只是合在了一个值里。把两条@tech{延续}合回一个处理 @math{pᵃ} 的函数；@racket[iₐ] 既然固定了，答案那一支就是原样交出：

@racketblock[
(λ (v) (if (ans? v) v (kₐ v)))]

@racket[loop] 正是这样做的：收到 @racket[ans] 就原样交出，否则接着算。

普通结果的类型也是 @math{a} 时，两条@tech{延续}的类型相同，都是 @math{a → a}，上面的 @racket[(loop/ki r* a->⊥ᵃ a->⊥ᵃ)] 交进去的就是同一个，也就是@xref["03:eval-boundary"]{「求值与边界」}里 @racket[anf:eval] 交进去的 @racket[id]。两种翻译加上对答案那一支的处理，就把原来的编码接到了这个可以直接求值的类型上。

这一章的边界，靠的是 @racket[anf:reset] 那次非尾调用：宿主栈上留着一帧，替我们记住外面等着的工作。手里只有不定界的 @racket[call/cc]，没有这样一次调用替我们记住外面，造得出 @racket[reset] 和 @racket[shift] 吗？
