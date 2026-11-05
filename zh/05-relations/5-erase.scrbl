#lang acf/scribble

@title[#:tag "05:5-erase"]{擦除延续参数}

摊开后的 @racket[right-triangles] 是一段 @tech[#:key "延续传递风格"]{CPS} 程序：每一层的剩余工作都写成 λ，作为参数交给 @racket[choose/k]。@xref["04:3-erase"]{第四章}的编译器也是这个形状，那里擦掉延续参数的办法，是让 @racket[shift] 在原来的位置把它取出来。对每个调用点照样做一遍：

@racketblock[
#,(hspace 2)((choose/k p*) (λ (v) body))
= (let ([k (λ (v) body)]) ((choose/k p*) k))
= (let ([k (λ (v) body)]) (append-map k p*))
= (reset (let ([v (shift k (append-map k p*))]) body))]

前三行只是换写法：给@tech{延续}起名 @racket[k]，再按 @racket[choose/k] 的定义把 @racket[((choose/k p*) k)] 换成 @racket[(append-map k p*)]。最后一行才是擦除：@racket[body] 不再包进 λ 交出去，而是留在原处；@racket[shift] 从里面取得的 @racket[k]，是 @racket[reset] 之内、它自己之后的那段代码，就是原来的 @racket[(λ (v) body)]，只是主体外面多带了一层 @racket[reset]；下面会看到这一层无害。

@racket[(shift k (append-map k p*))] 在每个调用点都会出现，给它起名 @racket[choose]。三层照这个样子逐一改写，每层一个 @racket[reset]，一个 @racket[choose]：

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(require racket/control)
(define (pyth? a b c) (= (+ (* a a) (* b b)) (* c c)))]
@examples[#:eval ev #:label #f #:no-prompt
(: choose (∀ (p) (→ (Listof p) p)))
(define (choose p*) (shift k (append-map k p*)))

(define (right-triangles l h)
  (reset
   (let ([a (choose (inclusive-range l h))])
     (reset
      (let ([b (choose (inclusive-range a h))])
        (reset
         (let ([c (choose (inclusive-range b h))])
           (if (pyth? a b c) (list (list a b c)) '()))))))))]

三个 @racket[reset] 层层相套，里面的两个是多余的。源码里它们并不紧挨着，中间隔着 @racket[let]，要看运行的时候。最外层的 @racket[choose] 取得的 @racket[k]，按@xref["03:rules"]{第三章的规约规则}是 @racket[(λ (v) (reset (let ([a v]) (reset …))))]，自带一层 @racket[reset]。拿一个备选，比如 3，调用它：

@racketblock[
#,(hspace 2)(k 3)
= (reset (let ([a 3]) (reset (let ([b (choose (inclusive-range a h))]) …))))
= (reset (reset (let ([b (choose (inclusive-range 3 h))]) …)))
= (reset (let ([b (choose (inclusive-range 3 h))]) …))]

@racket[a] 绑定好，@racket[let] 就不在了，@racket[k] 自带的那层 @racket[reset] 与源码里的第二层紧挨在一起，两层等于一层，@racket[(reset (reset e))] = @racket[(reset e)]。@xref["04:simplify"]{第四章化简编译器}时，内层的 @racket[reset] 也是这样去掉的。第三层同理。只留最外面一层，三个 @racket[let] 合成一个 @racket[let*]：

@examples[#:eval ev #:label #f #:no-prompt
(define (right-triangles l h)
  (reset
   (let* ([a (choose (inclusive-range l h))]
          [b (choose (inclusive-range a h))]
          [c (choose (inclusive-range b h))])
     (if (pyth? a b c) (list (list a b c)) '()))))]

只剩一层 @racket[reset] 以后，再算一遍：

@examples[#:eval ev #:label #f
(right-triangles 1 20)]

主体已经是普通的 @racket[let*]，@racket[a]、@racket[b]、@racket[c] 各是一个数，读起来是一次只有一个值的普通计算。这要归功于 @racket[choose] 的类型：收进一张列表，交出其中的一个元素。从调用处看，它只返回了一个值，后面的代码照常往下走；@racket[shift] 取得的 @racket[k] 却在 @racket[append-map] 里为每个元素各运行了一遍。「为每个备选各运行一遍」并没有消失，只是不用再写成 λ 交出去。

不过它还有两处是专为搜索写的。最后一行不能直接交出 @racket[(list a b c)]：成立时要再包一层，成为只装着一行的列表，不成立时要交出空列表，这样 @racket[append-map] 才接得起来。最外面还要放一层 @racket[reset]，标出这次搜索到哪里为止。
