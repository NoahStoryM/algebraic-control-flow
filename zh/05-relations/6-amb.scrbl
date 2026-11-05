#lang acf/scribble

@title[#:tag "05:6-amb"]{不确定运算符 amb}

把专为搜索写的那两处拿掉，程序就该是这个样子：

@racketblock[
(let* ([a (between l h)]
       [b (between a h)]
       [c (between b h)])
  (check (pyth? a b c))
  (list a b c))]

它读起来像是一段普通的程序：三条边各从范围里取一个数，检查是不是直角，是就交出这一组边。可是普通的函数做不到里面的两件事。@racket[(between l h)] 只交出一个数，后面的代码却要为范围里的每个数各走一遍：它得「返回许多次」。@racket[check] 在条件不成立时要让这条时间线到此为止，什么也不留下：它得「不返回」。此外还要有一层，把走通的各条时间线交出的结果收到一起。

一次调用可以返回许多次，也可以不返回，这样的计算叫@defterm[#:en "nondeterministic computation"]{不确定计算}。McCarthy 的@defterm[#:en "ambiguous operator"]{不确定运算符} @racket[amb] 就是为它准备的：@racket[(amb 1 2 3)] 返回三次，每次交出一个备选，后面的计算各走一遍；一个备选也不写的 @racket[(amb)] 不返回，这条时间线到此为止。再用 @racket[in-amb] 圈出一次不确定计算，把走通的结果收成一张列表：

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(require racket/control)
(define-type ℕ⁺ Positive-Integer)
(define (pyth? a b c) (= (+ (* a a) (* b b)) (* c c)))
(define (choose p*) (shift k (append-map k p*)))
(define-syntax-rule (amb e ...) ((choose (list (λ () e) ...))))
(define-syntax-rule (for/amb  clauses body ...) ((choose (for/list  clauses (λ () body ...)))))
(define-syntax-rule (for*/amb clauses body ...) ((choose (for*/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))]
@examples[#:eval ev #:label #f
(in-amb (amb 1 2 3))
(in-amb (let* ([x (amb 1 2 3)]
               [y (amb 10 20)])
          (+ x y)))
(in-amb (let ([n (amb 1 2 3 4 5)])
          (unless (odd? n) (amb))
          (* n n)))]

@racket[for/amb] 是 @racket[amb] 的循环写法，每一轮是一个备选。伪代码里缺的两个函数，用它们各写一行就有了；收集结果的那一层就是 @racket[in-amb]：

@examples[#:eval ev #:label #f #:no-prompt
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

@examples[#:eval ev #:label #f
(right-triangles 1 20)]

@racket[in-amb] 里面就是开头的那段程序，一个字也没有改。

最后把 @racket[amb] 做出来。@racket[choose] 从一张列表里选一个，@racket[shift] 取得的 @racket[k] 为每个备选各运行一遍，这已经是 @racket[amb] 的行为了。四个名字各用一行：

@examples[#:eval ev #:label #f #:no-prompt
(define-syntax-rule (amb e ...) ((choose (list (λ () e) ...))))
(define-syntax-rule (for/amb  clauses body ...) ((choose (for/list  clauses (λ () body ...)))))
(define-syntax-rule (for*/amb clauses body ...) ((choose (for*/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))]

备选是表达式，选中了才求值，所以各包一层 λ，选出来以后再调用。@racket[(amb)] 是从零个备选里选，@racket[k] 一次也不调用，原来那一行 @racket['()] 做的就是这件事。@racket[in-amb] 是最外面那层 @racket[reset]，连同把结果包成列表的那一步。专为搜索写的两处，就这样收进了这几个名字里。
