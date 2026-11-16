#lang acf/scribble

@title[#:tag "05:6-world"]{关系的世界}

@xref["05:compose"]{「二元关系的复合」}把四步接成 @racket[right-triangle]，靠的是 @racket[amb]；@xref["05:two-ways"]{「关系的两种写法」}在纯的宿主里找到了交出列表的函数。两处的二元关系都是用函数模拟的。现在有了一门直接写关系的语言，这门语言里的关系所在的世界记作 ℛ。

@section[#:tag "05:compose-o"]{在关系语言里复合}

二元关系的复合，用集合的语言写是：@math{(x, z)} 在 @math{Q ∘ P} 里，当且仅当存在这样的 @math{y}，@math{(x, y)} 在 @math{P} 里，并且 @math{(y, z)} 在 @math{Q} 里。在关系语言里，「并且」是把两行条件写在一起，「存在这样的 @math{y}」是用 @racket[fresh] 造一个 @racket[y]。照着写，就是关系的复合：

@(define ev-world (make-acf-eval))
@examples[#:eval ev-world #:hidden
(require racket/control)
(define ∘ compose)
(define (pyth? a b c) (= (+ (* a a) (* b b)) (* c c)))
(define (choose p*) (shift k (append-map k p*)))
(define-syntax-rule (amb e ...) ((choose (list (λ () e) ...))))
(define-syntax-rule (for/amb clauses body ...) ((choose (for/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))
(define (between lo hi) (for/amb ([n (inclusive-range lo hi)]) n))
(define (check ok?) (unless ok? (amb)))
(define ∘ℬ ∘)
(define (list->amb v*) (for/amb ([v (in-list v*)]) v))
(define pick-a (match-λ [(list l   h) (list (between l h)   h)]))
(define pick-b (match-λ [(list a   h) (list a (between a h) h)]))
(define pick-c (match-λ [(list a b h) (list a b (between b h))]))
(define (check-right t) (check (apply pyth? t)) t)
(define right-triangle (∘ check-right pick-c pick-b pick-a))
(struct var ([name : Symbol]) #:transparent)
(define (walk t s)
  (define p (and (var? t) (assq t s)))
  (if p (walk (cdr p) s) t))
(define (succeed s) s)
(define (conj . g*) (apply ∘ℬ (reverse g*)))
(define (unify u v s)
  (let ([u (walk u s)] [v (walk v s)])
    (cond [(and (var? u) (eq? u v)) s]
          [(var? u) (cons (cons u v) s)]
          [(var? v) (cons (cons v u) s)]
          [(and (pair? u) (pair? v))
           (unify (cdr u) (cdr v) (unify (car u) (car v) s))]
          [(equal? u v) s]
          [else (amb)])))
(define (value-of t s)
  (let ([t (walk t s)])
    (cond [(var? t) (error 'value-of "~a 的值还不知道" (var-name t))]
          [(pair? t) (cons (value-of (car t) s) (value-of (cdr t) s))]
          [else t])))
(define (((function->relation f) . t*) s)
  (define-values (in* out*) (split-at-right t* 1))
  (unify (car out*) (apply f (for/list ([t in*]) (value-of t s))) s))
(define ((== u v) s) (unify u v s))
(define-syntax-rule (fresh (x ...) g ...)
  (λ (s) (let ([x (var 'x)] ...) ((conj g ...) s))))
(define (walk* t s)
  (let ([t (walk t s)])
    (if (pair? t) (cons (walk* (car t) s) (walk* (cdr t) s)) t)))
(define (reify t)
  (define (name-unknowns t s)
    (let ([t (walk t s)])
      (cond [(var? t) (cons (cons t (string->symbol (format "_.~a" (length s)))) s)]
            [(pair? t) (name-unknowns (cdr t) (name-unknowns (car t) s))]
            [else s])))
  (walk* t (name-unknowns t '())))
(define-syntax-rule (run* (x ...) g ...)
  (let ([x (var 'x)] ...)
    (in-amb (reify (walk* (list x ...) ((conj g ...) '()))))))]
@examples[#:eval ev-world #:no-result
(define (idᵒ x y) (== x y))
(define (∘ᵒ . r*)
  (if (null? r*)
      idᵒ
      (λ (x z)
        (fresh (y)
          ((apply ∘ᵒ (cdr r*)) x y)
          ((car r*) y z)))))]

@defsym["Q ∘ᵒ P" "关系语言里的复合：fresh 造出中间的未知项"]@racket[∘ᵒ] 和 @racket[∘] 一样从右往左读：最右边的关系先接 @racket[x]，交出的 @racket[y] 再交给左边的。零个关系的复合是 @racket[idᵒ]，就像零个函数的复合是恒等函数。

在表上，@racket[fresh] 造出的 @racket[y] 就是两张表首尾相连时中间那一列。@racket[run*] 只读出 @racket[x] 与 @racket[z]，@racket[y] 不在答案里：中间那一列被遮住了。

@racket[idᵒ] 是一条等式，不是 @racket[(function->relation values)]。后者看起来也是「交出原样的值」，可它要先读出输入的值，输入不知道就走不通。拿一个只看第二个位置的关系来比：

@examples[#:eval ev-world #:no-result
(define (P x y) (== y 1))]

@examples[#:eval ev-world #:label #f
(run* (q) (P q 1))
(run* (q) ((∘ᵒ P idᵒ) q 1))
(eval:error (run* (q) ((∘ᵒ P (function->relation values)) q 1)))]

接上 @racket[idᵒ]，答案和 @racket[P] 自己一样：@racket[q] 是什么都行。换成 @racket[(function->relation values)]，同样的问题就问不出来了。报错里的 @racket[y] 是 @racket[∘ᵒ] 在中间造出的未知项，它与 @racket[q] 相等，同样不知道值。在关系语言里，恒等关系是相等：两个位置相等，问哪个都可以。

@section[#:tag "05:four-steps-o"]{四步搬过来}

四步是 ℬ 的箭头，用 @racket[function->relation] 各搬成一个关系，再用 @racket[∘ᵒ] 接起来：

@examples[#:eval ev-world #:no-result
(define pick-aᵒ      (function->relation pick-a))
(define pick-bᵒ      (function->relation pick-b))
(define pick-cᵒ      (function->relation pick-c))
(define check-rightᵒ (function->relation check-right))
(define right-triangleᵒ (∘ᵒ check-rightᵒ pick-cᵒ pick-bᵒ pick-aᵒ))]

@examples[#:eval ev-world #:label #f
(run* (t) (right-triangleᵒ '(1 20) t))]

还是那六组，每组装在一张单元素的列表里，因为 @racket[run*] 只读了一个未知项 @racket[t]。@racket[pick-a] 里面用了 @racket[amb]，@racket[function->relation] 照样把它搬过来：它交出几个值，目标就交出几张代换。

接四步的写法，到这里有了三种。@xref["05:two-ways"]{「关系的两种写法」}末尾并排了两行，这里添上第三行：

@racketblock[
(let*      ([y (f x)] [z (g y)]) z)  =  ((∘ℬ g f) x)
(for*/list ([y (f x)] [z (g y)]) z)  =  ((∘ℒ g f) x)
(fresh (y) (P x y) (Q y z))          =  ((∘ᵒ Q P) x z)]

前两行的右边交出 @racket[z]；第三行没有谁交出什么，@racket[x] 与 @racket[z] 都只是位置。三种都是复合，中间结果 @racket[y] 在前两行由绑定命名，在第三行由 @racket[fresh] 造出。

关系语言不分输入输出，可四步是从函数搬来的，里面的函数仍然只算已经知道的值。倒过来问哪组边界能得到 @racket[(3 4 5)]，问不出来：

@examples[#:eval ev-world #:label #f
(eval:error (run* (b) (right-triangleᵒ b '(3 4 5))))]

@racket[pick-aᵒ] 要读出边界的值，可边界正是要问的东西。

@section[#:tag "05:worlds"]{几个世界之间}

同一个二元关系，这一章有了三种写法：ℬ 里带 @racket[amb] 的函数，ℒ 里交出列表的函数，ℛ 里关系语言的关系。它们之间的搬运，方向和条件不一样。

@itemlist[
@item{ℬ 与 ℒ 之间是 @racket[gather] 与 @racket[scatter]，来回一趟回到原处；比的是列表，先后与重复都算在内，搜索要能走完。}
@item{ℬ 到 ℛ 是 @racket[function->relation]：在输入已经知道的问法里，交出的答案和原来的函数一样。ℒ 到 ℛ 先 @racket[scatter] 到 ℬ，再这样搬。}
@item{ℛ 到另外两种，一般搬不回去。@tt{(_.0 _.0)} 这样的答案代表无穷多行，写不成一张列表。}]

三种写法里，只有 ℛ 是直接写关系的：一行条件说的就是项之间的关系，不分输入输出，复合是「存在」加「并且」，单位是相等。ℬ 与 ℒ 都是用函数模拟关系，函数分输入输出，所以它们各有一个方向。ℛ 本身也是用 ℬ 的箭头实现的：目标就是带 @racket[amb] 的函数。
