#lang acf/scribble

@title[#:tag "05:5-unify"]{复合与合一}

@racket[id] 是函数复合的单位。换到关系语言里，先看两个关系怎样复合，再看这个复合需要怎样的单位。

@section[#:tag "05:compose-o"]{在关系语言里复合}

@xref["05:compose"]{「二元关系的复合」}里，四步都是带 @racket[amb] 的函数，用 @racket[∘] 就接成了 @racket[right-triangle]。关系语言里的关系不是函数：@racket[(Pᵒ x y)] 交出的是目标，@racket[x] 与 @racket[y] 只是两个位置，@racket[∘] 接不上。

@xref["05:compose"]{「二元关系的复合」}用集合的语言写过二元关系的复合：@math{(x, z)} 在 @math{Q ∘ P} 里，当且仅当存在这样的 @math{y}，@math{(x, y)} 在 @math{P} 里，并且 @math{(y, z)} 在 @math{Q} 里。

如果只用@tech{谓词}（也就是@tech{特征函数}）来表示二元关系，照这句话去复合两个二元谓词 @racket[P?] 与 @racket[Q?]，会直接卡在「存在这样的 @math{y}」上：@racket[P?] 与 @racket[Q?] 只负责检查给定的一对值在不在关系里，除非把 @math{y} 所在集合的全部元素列出来逐个试一遍（而且这个集合还得有限），否则单靠特征函数写不出复合。

换到刚造出的关系语言，「并且」已经是 @racket[∧]，只差「存在这样的 @math{y}」。@racket[run*] 会在查询开头造出未知项；复合两个关系时，也需要一个只在里面用到的中间未知项：

@(define ev-comp (make-acf-eval))
@examples[#:eval ev-comp #:hidden
(require racket/control)
(define ∘ compose)
(define id (∘))
(define (pyth? a b c) (= (+ (* a a) (* b b)) (* c c)))
(define (choose p*) (shift k (append-map k p*)))
(define-syntax-rule (amb e ...) ((choose (list (λ () e) ...))))
(define-syntax-rule (for/amb clauses body ...) ((choose (for/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))
(define (between lo hi) (for/amb ([n (inclusive-range lo hi)]) n))
(define (check ok?) (unless ok? (amb)))
(define ∘ℬ ∘)
(define pick-a (match-λ [(list l   h) (list (between l h)   h)]))
(define pick-b (match-λ [(list a   h) (list a (between a h) h)]))
(define pick-c (match-λ [(list a b h) (list a b (between b h))]))
(define (check-right t) (check (apply pyth? t)) t)
(struct var ([name : Symbol]) #:type-name Var #:transparent)
(define (value-of t s)
  (cond [(not (var? t)) t]
        [(assq t s) => cdr]
        [else (error 'value-of "~a 的值还不知道" (var-name t))]))
(define (∧ . g*) (apply ∘ℬ (reverse g*)))
(define (((function->relation f) . t*) s)
  (define-values (in* out*) (split-at-right t* 1))
  (cons (cons (car out*) (apply f (for/list ([t in*]) (value-of t s)))) s))
(define-syntax-rule (run* (x ...) g)
  (let ([x (var 'x)] ...)
    (in-amb
     (let ([s (g '())])
       (list (value-of x s) ...)))))
(define idᵒ (function->relation id))]
@examples[#:eval ev-comp #:no-result
(define-syntax-rule (∃ (x ...) g)
  (λ (s) (let ([x (var 'x)] ...) (g s))))]

@racket[∃] 交出的也是目标。它等收到代换时才造未知项，再运行里面的条件：每用一次，造出的都是新的。集合里的那句话于是可以逐字翻译过来：

@racketblock[
(∃ (y)
  (∧ (Pᵒ x y)
     (Qᵒ y z)))]

「存在这样的 @math{y}」就是 @racket[∃]，未知项 @racket[y] 替我们占住中间那一列，用不着穷举全集；「并且」就是 @racket[∧]。在代换层，@racket[∧] 是目标的复合 @racket[∘ℬ]；在答案表上，@racket[∧] 把两张表按共有的列拼起来，中间的 @racket[y] 就是两张表首尾相连时的那一列，@racket[run*] 只读出 @racket[x] 与 @racket[z]，中间那一列被遮住了。

把两个关系的复合写成函数 @racket[∘ᵒ]：

@examples[#:eval ev-comp #:no-result
(: ∘ᵒ (→ (→ Term Term Goal) (→ Term Term Goal) (→ Term Term Goal)))
(define ((∘ᵒ Qᵒ Pᵒ) x z)
  (∃ (y) (∧ (Pᵒ x y) (Qᵒ y z))))]

@defsym["Qᵒ ∘ᵒ Pᵒ" "关系语言里的复合：∃ 造出中间的未知项"]@racket[∘ᵒ] 和 @racket[∘] 一样从右往左写：两个关系复合时，中间的 @racket[y] 把它们连起来，右边的关系说 @racket[x] 与 @racket[y]，左边的说 @racket[y] 与 @racket[z]。

拿 @racket[right-triangle] 的四步试一试。四步都是带 @racket[amb] 的函数，用 @racket[function->relation] 各搬成一个关系，再用 @racket[∘ᵒ] 接起来：

@examples[#:eval ev-comp #:no-result
(define pick-aᵒ      (function->relation pick-a))
(define pick-bᵒ      (function->relation pick-b))
(define pick-cᵒ      (function->relation pick-c))
(define check-rightᵒ (function->relation check-right))
(define right-triangleᵒ
  (∘ᵒ check-rightᵒ (∘ᵒ pick-cᵒ (∘ᵒ pick-bᵒ pick-aᵒ))))]

从 1 到 20 跑一遍：

@examples[#:eval ev-comp #:label #f
(run* (t) (right-triangleᵒ '(1 20) t))]

@margin-note{每组外面多了一层括号：@racket[run*] 只读了一个未知项 @racket[t]，一组答案是只有一项的列表。}

还是那六组。@racket[pick-a] 里面用了 @racket[amb]，@racket[function->relation] 照样把它搬过来：它交出几个值，目标就交出几张代换。

接四步的写法，到这里有了三种。@xref["05:two-ways"]{「关系的两种写法」}末尾并排了两行，这里添上第三行：

@racketblock[
(let*      ([y (f x)] [z (g y)]) z)  =  ((∘ℬ g f) x)
(for*/list ([y (f x)] [z (g y)]) z)  =  ((∘ℒ g f) x)
(∃ (y) (∧ (Pᵒ x y) (Qᵒ y z)))        =  ((∘ᵒ Qᵒ Pᵒ) x z)]

前两行的右边交出 @racket[z]；第三行没有谁交出什么，@racket[x] 与 @racket[z] 都只是位置。三种都是复合，中间结果 @racket[y] 在前两行由绑定命名，在第三行由 @racket[∃] 造出。

不过四步是从函数搬来的，里面的函数仍然只算已经知道的值。倒过来问哪组边界能得到 @racket[(3 4 5)]：

@examples[#:eval ev-comp #:label #f
(eval:error (run* (b) (right-triangleᵒ b '(3 4 5))))]

@racket[pick-aᵒ] 要读出边界 @racket[b] 的值，可边界正是要问的东西。

现在回头看 @racket[∘ᵒ] 的单位。前面把 @racket[id] 搬成了 @racket[(function->relation id)]，可只要左边是未知项，它立刻报错。哪怕写成两条简单的等式，@racket[x] 等于 @racket[y]、@racket[y] 等于 5，它也走不下去：

@examples[#:eval ev-comp #:label #f
(eval:error (run* (x y) (∧ (idᵒ x y) (idᵒ y 5))))]

@racket[idᵒ] 要先读出 @racket[x] 的值，可 @racket[x] 的值要等第二行才定下来；换成 @racket[equalᵒ] 也一样，两边都得先知道。「交出原样的值」和「检查两边相等」都分了已知与未知；关系的单位说的是两个位置相等，两边都可以暂时不知道。

@section[#:tag "05:unify-step"]{合一}

不借 @racket[id]，照手写 @racket[g] 的办法，直接把这两行等式记进表里：@racket[x] 等于 @racket[y]，@racket[y] 等于 5。然后问 @racket[x] 的值：

@(define ev-unify (make-acf-eval))
@examples[#:eval ev-unify #:hidden
(require racket/control)
(define ∘ compose)
(define (choose p*) (shift k (append-map k p*)))
(define-syntax-rule (amb e ...) ((choose (list (λ () e) ...))))
(define-syntax-rule (for/amb clauses body ...) ((choose (for/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))
(define (between lo hi) (for/amb ([n (inclusive-range lo hi)]) n))
(define ∘ℬ ∘)
(define (list->amb v*) (for/amb ([v (in-list v*)]) v))
(struct var ([name : Symbol]) #:type-name Var #:transparent)
(define (value-of t s)
  (cond [(not (var? t)) t]
        [(assq t s) => cdr]
        [else (error 'value-of "~a 的值还不知道" (var-name t))]))
(define (∧ . g*) (apply ∘ℬ (reverse g*)))
(define-syntax-rule (∃ (x ...) g)
  (λ (s) (let ([x (var 'x)] ...) (g s))))
(define-syntax-rule (run* (x ...) g)
  (let ([x (var 'x)] ...)
    (in-amb
     (let ([s (g '())])
       (list (value-of x s) ...)))))]
@examples[#:eval ev-unify #:label #f
(define x (var 'x))
(define y (var 'y))
(define s (list (cons x y) (cons y 5)))
(value-of x s)]

表记下来了，值却读不对。@racket[x] 对着 @racket[y]，@racket[value-of] 只查了一次，交出的是一个未知项；可 @racket[y] 的值，表里明明有。值可以是另一个未知项的时候，查表要顺着查下去，查到一个不在表里的项为止：

@examples[#:eval ev-unify #:no-result
(: walk (→ Term Substitution Term))
(define (walk t s)
  (define p (and (var? t) (assq t s)))
  (if p (walk (cdr p) s) t))]

用刚才那张代换试一试：

@examples[#:eval ev-unify #:label #f
(walk x s)]

添一行也不能照旧了。比如表里已经记着 @racket[x] 等于 5，再来一行等式说 @racket[x] 等于 6，直接添上，@racket[x] 就占了两行；等式要是写成 6 等于 @racket[x]，键还成了一个数。添之前，两边都要先顺着表查到底，再对称地比：有一边是未知项，就添上一行；两边都是序对，逐项去对；否则相等才走得通：

@examples[#:eval ev-unify #:no-result
(: unify (→ Term Term Substitution Substitution))
(define (unify u v s)
  (let ([u (walk u s)] [v (walk v s)])
    (cond [(and (var? u) (eq? u v)) s]
          [(var? u) (cons (cons u v) s)]
          [(var? v) (cons (cons v u) s)]
          [(and (pair? u) (pair? v))
           (unify (cdr u) (cdr v) (unify (car u) (car v) s))]
          [(equal? u v) s]
          [else (amb)])))]

试三组不同的情况：

@examples[#:eval ev-unify #:label #f
(define a (var 'a))
(define b (var 'b))
(in-amb (unify x y '()))
(in-amb (unify (list a 2) (list 1 b) '()))
(in-amb (unify 6 x (list (cons x 5))))]

头一例两边都不知道，添的一行记着 @racket[x] 等于 @racket[y]。第二例是两张各缺一项的列表，逐项去对，@racket[a] 对上 1，@racket[b] 对上 2：两边都从对面得到了自己缺的那一项。第三例里 @racket[x] 查到 5，与 6 对不上，这条时间线走不通，@racket[in-amb] 一张代换也没有收到。

让两个项相等，必要时往代换里添一行，这件事叫@defterm[#:en "unification"]{合一}。添的总是一个还没在表里的未知项，所以键不会重复。代换也跟着变了样：一行记的不再是某个未知项的值，而是一条等式。

把合一本身做成一个关系：@racket[(≡ u v)] 说的是两个项相等，交出的目标让它们合一。

@examples[#:eval ev-unify #:no-result
(: ≡ (→ Term Term Goal))
(define ((≡ u v) s) (unify u v s))]

@racket[value-of] 也改成顺着查，项是序对就逐项读；走到头还剩未知项就报错，所以它交出的都是不含未知项的 @racket[Data]：

@examples[#:eval ev-unify #:no-result
(: value-of (→ Term Substitution Data))
(define (value-of t s)
  (let ([t (walk t s)])
    (cond [(var? t) (error 'value-of "~a 的值还不知道" (var-name t))]
          [(pair? t) (cons (value-of (car t) s) (value-of (cdr t) s))]
          [else t])))]

用 @racket[≡] 和 @racket[run*] 试一试：

@examples[#:eval ev-unify #:label #f
(run* (x y) (∧ (≡ x y) (≡ y 5)))
(run* (x y) (∧ (≡ x 1) (≡ 2 y)))
(run* (x) (∧ (≡ x 5) (≡ 6 x)))]

未知项写在等式的哪一边都可以，两边都是未知项也可以。@racket[∘ᵒ] 一直在找的单位，正是合一 @racket[≡] 本身：

@examples[#:eval ev-unify #:no-result
(: idᵒ (→ Term Term Goal))
(define idᵒ ≡)]

无论哪边是未知项，它都能接得住：

@examples[#:eval ev-unify #:label #f
(run* (q) (idᵒ q 5))
(run* (q) (idᵒ 5 q))]

回头看 @racket[function->relation]：原先默认最后一个位置是还没有值的未知项，直接添一行。现在让它与函数交出的值合一：没有值就添一行，有值就成了核对。

@examples[#:eval ev-unify #:no-result
(: function->relation (∀ (a ... b) (→ (→ℬ a ... b) (→ Term ... Term Goal))))
(define (((function->relation f) . t*) s)
  (define-values (in* out*) (split-at-right t* 1))
  (unify (car out*) (apply f (for/list ([t in*]) (value-of t s))) s))]

前面直接添一行时坏掉的那两例，现在都走得通了：

@examples[#:eval ev-unify #:hidden
(define betweenᵒ (function->relation between))]
@examples[#:eval ev-unify #:label #f
(run* (a) (∧ (betweenᵒ 1 2 a) (betweenᵒ 2 3 a)))
(run* () (betweenᵒ 1 3 2))
(run* () (betweenᵒ 1 3 5))]
