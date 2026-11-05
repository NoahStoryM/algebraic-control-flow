#lang acf/scribble

@title[#:tag "05:4-hidden-k"]{藏在循环里的局部延续}

开头说，搜索树上同一份剩余工作要为每个备选各运行一次，还说嵌套循环走的就是这样一棵树。可是循环里并没有哪一行写着「剩余工作」。它在哪里，又是怎样被运行了许多次的？

先看熟悉的 @racket[let*]。它的绑定从上到下依次执行，每个绑定配对了两件东西：右边的@tech{可归约式}，和等着它的结果的@tech{局部延续}，也就是这个绑定之后的全部代码。@racket[for*/list] 写出来几乎是同一个样子：

@racketblock[
(let* ([a 3]
       [b (+ a 1)]
       [c (+ b 1)])
  (list a b c))

(for*/list ([a (inclusive-range 1 20)]
            [b (inclusive-range a 20)]
            [c (inclusive-range b 20)]
            #:when (pyth? a b c))
  (list a b c))]

一串绑定从上到下排开，后面的绑定可以用前面的名字，计算的先后都写在了绑定的先后里。@racket[for*/list] 的每个绑定后面，同样跟着一份等着结果的剩余工作。差别在可归约式算出了什么。@racket[(+ a 1)] 算出一个值，剩余工作拿着它运行一次。@racket[(inclusive-range 1 20)] 算出的是一个序列，@racket[a] 要取遍其中每个值，剩余工作就为每个值各运行一次。

@xref["04:4-named"]{第四章}的 @racket[if] 把剩余工作写了两次，只运行了一次。这里正相反：@racket[[a (inclusive-range 1 20)]] 之后的全部代码只写了一次，却运行了二十次，每次拿到一个不同的 @racket[a]，彼此互不相干。普通的计算里，剩余工作运行过就成为过去，一次计算只有一条时间线。这里同一份剩余工作运行了许多遍，一次搜索里有不止一条时间线。

这份被反复运行的剩余工作藏在 @racket[for*/list] 的语法里，把它写出来。先看 @racket[let]：@racket[(let ([v e]) body)] 脱糖后是 @racket[((λ (v) body) e)]，等着结果的@tech{延续} @racket[(λ (v) body)] 就摆在眼前。给它起名 @racket[k]，@racket[k] 在 @racket[e] 的值上调用一次。

@racket[for/list] 也能照样写出来。@racket[(for/list ([v e*]) body)] 里，@racket[k] 要对序列 @racket[e*] 的每个值各调用一次，再把各次的结果收成一张列表，这是 @racket[map] 做的事。

@racket[for*/list] 却不是嵌套的 @racket[for/list]。把 @racket[for/list] 一层层嵌套，外层 @racket[k] 的主体又是一个 @racket[for/list]，交出的是一张列表，外层的 @racket[map] 把它们收起来，就成了列表的列表。@racket[for*/list] 在每一层把内层交出的列表接成一张，也就是把 @racket[map] 换成 @racket[append-map]。三种写法并排：

@racketblock[
(let ([v e]) body)            =  ((λ (k) (k e))             (λ (v) body))
(for/list ([v e*]) body)      =  ((λ (k) (map k e*))        (λ (v) body))
(for*/list ([v e*] …) body)   =  ((λ (k) (append-map k e*)) (λ (v) body*))]

@racket[body*] 是其余的子句连同 @racket[body]，它交出一张列表。

第三行里的 @racket[(λ (k) (append-map k e*))] 只依赖序列 @racket[e*]。把序列抽成参数，起名 @racket[choose/k]：它收到一张备选的列表，等着剩余工作 @racket[k]，把备选逐个交给 @racket[k]，再把各次的结果接起来。

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define (pyth? a b c) (= (+ (* a a) (* b b)) (* c c)))]
@examples[#:eval ev #:label #f #:no-prompt
(: choose/k (∀ (p q) (→ (Listof p) (→ (→ p (Listof q)) (Listof q)))))
(define ((choose/k p*) k) (append-map k p*))]

用 @racket[choose/k] 把 @racket[right-triangles] 的三层循环摊开，每一层的剩余工作都成了一个写出来的 λ。每层交出的都得是列表，最内层也一样：直角成立，交出只装着一行的列表；不成立，交出空列表。

@examples[#:eval ev #:label #f #:no-prompt
(define (right-triangles l h)
  ((choose/k (inclusive-range l h))
   (λ (a)
     ((choose/k (inclusive-range a h))
      (λ (b)
        ((choose/k (inclusive-range b h))
         (λ (c)
           (if (pyth? a b c) (list (list a b c)) '()))))))))]

和开头的 @racket[for*/list] 版本比一比：

@examples[#:eval ev #:label #f
(right-triangles 1 20)]

交出的列表与循环的一模一样。

剩余工作有了名字，它运行了几次就数得出来。最外层的 @racket[(append-map k (inclusive-range 1 20))] 摊开是 @racket[(append (k 1) (k 2) … (k 20))]，同一个 @racket[k] 运行了二十次。参数从左到右求值，@racket[(k 1)] 连同它下面所有的 @racket[b]、@racket[c] 试完，才轮到 @racket[(k 2)]：一条路走到头，退回最近一处还有备选的地方，换下一个再走。这就是@defterm[#:en "backtracking"]{回溯}。

走到最里面，直角成立的时间线交出一行，不成立的什么也不交出，@racket[append] 把交出的行接成一张列表。表里的行就是这样来的：同一组边界在表里占几行，搜索里就有几条走通的时间线。函数的输入恰好占一行，一条时间线就够了；关系的输入可以占许多行，也可以一行不占。
