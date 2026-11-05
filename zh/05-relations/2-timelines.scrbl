#lang acf/scribble

@title[#:tag "05:2-timelines"]{循环里的时间线}

上一节只看了搜索交出什么。这一节回到开头放下的问题：搜索里的剩余工作藏在哪里，又怎样为每个备选各运行一次。

@section[#:tag "05:hidden-k"]{藏在循环里的局部延续}

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

@(define ev-loop (make-acf-eval))
@examples[#:eval ev-loop #:hidden
(define (pyth? a b c) (= (+ (* a a) (* b b)) (* c c)))]
@examples[#:eval ev-loop #:label #f #:no-prompt
(: choose/k (∀ (p q) (→ (Listof p) (→ (→ p (Listof q)) (Listof q)))))
(define ((choose/k p*) k) (append-map k p*))]

用 @racket[choose/k] 把 @racket[right-triangles] 的三层循环摊开，每一层的剩余工作都成了一个写出来的 λ。每层交出的都得是列表，最内层也一样：直角成立，交出只装着一行的列表；不成立，交出空列表。

@examples[#:eval ev-loop #:label #f #:no-prompt
(define (right-triangles l h)
  ((choose/k (inclusive-range l h))
   (λ (a)
     ((choose/k (inclusive-range a h))
      (λ (b)
        ((choose/k (inclusive-range b h))
         (λ (c)
           (if (pyth? a b c) (list (list a b c)) '()))))))))]

和开头的 @racket[for*/list] 版本比一比：

@examples[#:eval ev-loop #:label #f
(right-triangles 1 20)]

交出的列表与循环的一模一样。

剩余工作有了名字，它运行了几次就数得出来。最外层的 @racket[(append-map k (inclusive-range 1 20))] 摊开是 @racket[(append (k 1) (k 2) … (k 20))]，同一个 @racket[k] 运行了二十次。参数从左到右求值，@racket[(k 1)] 连同它下面所有的 @racket[b]、@racket[c] 试完，才轮到 @racket[(k 2)]：一条路走到头，退回最近一处还有备选的地方，换下一个再走。这就是@defterm[#:en "backtracking"]{回溯}。

走到最里面，直角成立的时间线交出一行，不成立的什么也不交出，@racket[append] 把交出的行接成一张列表。表里的行就是这样来的：同一组边界在表里占几行，搜索里就有几条走通的时间线。函数的输入恰好占一行，一条时间线就够了；关系的输入可以占许多行，也可以一行不占。

@section[#:tag "05:erase"]{擦除延续参数}

摊开后的 @racket[right-triangles] 是一段 @tech[#:key "延续传递风格"]{CPS} 程序：每一层的剩余工作都写成 λ，作为参数交给 @racket[choose/k]。@xref["04:3-erase"]{第四章}的编译器也是这个形状，那里擦掉延续参数的办法，是让 @racket[shift] 在原来的位置把它取出来。对每个调用点照样做一遍：

@racketblock[
#,(hspace 2)((choose/k p*) (λ (v) body))
= (let ([k (λ (v) body)]) ((choose/k p*) k))
= (let ([k (λ (v) body)]) (append-map k p*))
= (reset (let ([v (shift k (append-map k p*))]) body))]

前三行只是换写法：给@tech{延续}起名 @racket[k]，再按 @racket[choose/k] 的定义把 @racket[((choose/k p*) k)] 换成 @racket[(append-map k p*)]。最后一行才是擦除：@racket[body] 不再包进 λ 交出去，而是留在原处；@racket[shift] 从里面取得的 @racket[k]，是 @racket[reset] 之内、它自己之后的那段代码，就是原来的 @racket[(λ (v) body)]，只是主体外面多带了一层 @racket[reset]；下面会看到这一层无害。

@racket[(shift k (append-map k p*))] 在每个调用点都会出现，给它起名 @racket[choose]。三层照这个样子逐一改写，每层一个 @racket[reset]，一个 @racket[choose]：

@(define ev-erase (make-acf-eval))
@examples[#:eval ev-erase #:hidden
(require racket/control)
(define (pyth? a b c) (= (+ (* a a) (* b b)) (* c c)))]
@examples[#:eval ev-erase #:label #f #:no-prompt
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

@examples[#:eval ev-erase #:label #f #:no-prompt
(define (right-triangles l h)
  (reset
   (let* ([a (choose (inclusive-range l h))]
          [b (choose (inclusive-range a h))]
          [c (choose (inclusive-range b h))])
     (if (pyth? a b c) (list (list a b c)) '()))))]

只剩一层 @racket[reset] 以后，再算一遍：

@examples[#:eval ev-erase #:label #f
(right-triangles 1 20)]

主体已经是普通的 @racket[let*]，@racket[a]、@racket[b]、@racket[c] 各是一个数，读起来是一次只有一个值的普通计算。这要归功于 @racket[choose] 的类型：收进一张列表，交出其中的一个元素。从调用处看，它只返回了一个值，后面的代码照常往下走；@racket[shift] 取得的 @racket[k] 却在 @racket[append-map] 里为每个元素各运行了一遍。「为每个备选各运行一遍」并没有消失，只是不用再写成 λ 交出去。

不过它还有两处是专为搜索写的。最后一行不能直接交出 @racket[(list a b c)]：成立时要再包一层，成为只装着一行的列表，不成立时要交出空列表，这样 @racket[append-map] 才接得起来。最外面还要放一层 @racket[reset]，标出这次搜索到哪里为止。

@section[#:tag "05:amb"]{不确定运算符 amb}

把专为搜索写的那两处拿掉，程序就该是这个样子：

@racketblock[
(let* ([a (between l h)]
       [b (between a h)]
       [c (between b h)])
  (check (pyth? a b c))
  (list a b c))]

它读起来像是一段普通的程序：三条边各从范围里取一个数，检查是不是直角，是就交出这一组边。可是普通的函数做不到里面的两件事。@racket[(between l h)] 只交出一个数，后面的代码却要为范围里的每个数各走一遍：它得「返回许多次」。@racket[check] 在条件不成立时要让这条时间线到此为止，什么也不留下：它得「不返回」。此外还要有一层，把走通的各条时间线交出的结果收到一起。

一次调用可以返回许多次，也可以不返回，这样的计算叫@defterm[#:en "nondeterministic computation"]{不确定计算}。McCarthy 的@defterm[#:en "ambiguous operator"]{不确定运算符} @racket[amb] 就是为它准备的：@racket[(amb 1 2 3)] 返回三次，每次交出一个备选，后面的计算各走一遍；一个备选也不写的 @racket[(amb)] 不返回，这条时间线到此为止。再用 @racket[in-amb] 圈出一次不确定计算，把走通的结果收成一张列表：

@(define ev-amb (make-acf-eval))
@examples[#:eval ev-amb #:hidden
(require racket/control)
(define-type ℕ⁺ Positive-Integer)
(define (pyth? a b c) (= (+ (* a a) (* b b)) (* c c)))
(define (choose p*) (shift k (append-map k p*)))
(define-syntax-rule (amb e ...) ((choose (list (λ () e) ...))))
(define-syntax-rule (for/amb  clauses body ...) ((choose (for/list  clauses (λ () body ...)))))
(define-syntax-rule (for*/amb clauses body ...) ((choose (for*/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))]
@examples[#:eval ev-amb #:label #f
(in-amb (amb 1 2 3))
(in-amb (let* ([x (amb 1 2 3)]
               [y (amb 10 20)])
          (+ x y)))
(in-amb (let ([n (amb 1 2 3 4 5)])
          (unless (odd? n) (amb))
          (* n n)))]

@racket[for/amb] 是 @racket[amb] 的循环写法，每一轮是一个备选。伪代码里缺的两个函数，用它们各写一行就有了；收集结果的那一层就是 @racket[in-amb]：

@examples[#:eval ev-amb #:label #f #:no-prompt
(: between (→ ℕ⁺ ℕ⁺ ℕ⁺))
(define (between lo hi) (for/amb ([n (inclusive-range lo hi)]) n))

(: check (→ Boolean Void))
(define (check ok?) (unless ok? (amb)))

(define (right-triangles l h)
  (in-amb
   (let* ([a (between l h)]
          [b (between a h)]
          [c (between b h)])
     (check (pyth? a b c))
     (list a b c))))]

走到末尾的 @racket[(list a b c)] 由 @racket[in-amb] 收下：

@examples[#:eval ev-amb #:label #f
(right-triangles 1 20)]

@racket[in-amb] 里面就是开头的那段程序，一个字也没有改。

最后把 @racket[amb] 做出来。@racket[choose] 从一张列表里选一个，@racket[shift] 取得的 @racket[k] 为每个备选各运行一遍，这已经是 @racket[amb] 的行为了。四个名字各用一行：

@examples[#:eval ev-amb #:label #f #:no-prompt
(define-syntax-rule (amb e ...) ((choose (list (λ () e) ...))))
(define-syntax-rule (for/amb  clauses body ...) ((choose (for/list  clauses (λ () body ...)))))
(define-syntax-rule (for*/amb clauses body ...) ((choose (for*/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))]

备选是表达式，选中了才求值，所以各包一层 λ，选出来以后再调用。@racket[(amb)] 是从零个备选里选，@racket[k] 一次也不调用，原来那一行 @racket['()] 做的就是这件事。@racket[in-amb] 是最外面那层 @racket[reset]，连同把结果包成列表的那一步。专为搜索写的两处，就这样收进了这几个名字里。
