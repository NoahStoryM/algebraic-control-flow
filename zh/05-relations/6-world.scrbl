#lang acf/scribble

@title[#:tag "05:6-world"]{关系的世界}

@xref["05:compose"]{「二元关系的复合」}里，四步都是带 @racket[amb] 的函数，用 @racket[∘] 就接成了 @racket[right-triangle]。关系语言里的关系不是函数：@racket[(P x y)] 交出的是目标，@racket[x] 与 @racket[y] 只是两个位置，@racket[∘] 接不上。两个这样的关系，怎样接起来？

@section[#:tag "05:compose-o"]{在关系语言里复合}

@xref["05:compose"]{「二元关系的复合」}用集合的语言写过二元关系的复合：@math{(x, z)} 在 @math{Q ∘ P} 里，当且仅当存在这样的 @math{y}，@math{(x, y)} 在 @math{P} 里，并且 @math{(y, z)} 在 @math{Q} 里。

如果只用@tech{谓词}（也就是@tech{特征函数}）来表示二元关系，照这句话去复合两个二元谓词 @racket[P?] 与 @racket[Q?]，会直接卡在「存在这样的 @math{y}」上：@racket[P?] 与 @racket[Q?] 只负责检查给定的一对值在不在关系里，除非把 @math{y} 所在集合的全部元素列出来逐个试一遍（而且这个集合还得有限），否则单靠特征函数写不出复合。

换到刚造出的关系语言，集合里的那句话可以逐字翻译过来：用 @racket[∃] 为中间那一项造一个未知项，再写下两行条件：

@racketblock[
(∃ (y)
  (∧ (P x y)
     (Q y z)))]

「存在这样的 @math{y}」就是 @racket[∃]，未知项 @racket[y] 替我们占住中间那一列，用不着穷举全集；「并且」就是 @racket[∧]。在代换层，@racket[∧] 是目标的复合 @racket[∘ℬ]；在答案表上，@racket[∧] 把两张表按共有的列拼起来，中间的 @racket[y] 就是两张表首尾相连时的那一列，@racket[run*] 只读出 @racket[x] 与 @racket[z]，中间那一列被遮住了。

关系多于两个时，一个一个这样接下去。零个关系的复合该是什么？零个函数的复合是恒等函数 @racket[id]，把它搬成关系试一试。拿一个只看第二个位置的 @racket[P]，在它右边接上 @racket[(function->relation id)]：

@(define ev-world (make-acf-eval))
@examples[#:eval ev-world #:hidden
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
(define (list->amb v*) (for/amb ([v (in-list v*)]) v))
(define pick-a (match-λ [(list l   h) (list (between l h)   h)]))
(define pick-b (match-λ [(list a   h) (list a (between a h) h)]))
(define pick-c (match-λ [(list a b h) (list a b (between b h))]))
(define (check-right t) (check (apply pyth? t)) t)
(define right-triangle (∘ check-right pick-c pick-b pick-a))
(struct var ([name : Symbol]) #:type-name Var #:transparent)
(define (walk t s)
  (define p (and (var? t) (assq t s)))
  (if p (walk (cdr p) s) t))
(define (⊤ s) s)
(define (∧ . g*) (apply ∘ℬ (reverse g*)))
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
(define ((≡ u v) s) (unify u v s))
(define-syntax-rule (∃ (x ...) g)
  (λ (s) (let ([x (var 'x)] ...) (g s))))
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
(define-syntax-rule (run* (x ...) g)
  (let ([x (var 'x)] ...)
    (in-amb (reify (walk* (list x ...) (g '()))))))]
@examples[#:eval ev-world #:label #f
(define (P x y) (≡ y 1))
(run* (q) (P q 1))
(eval:error
 (run* (q)
   (∃ (y)
     (∧ ((function->relation id) q y)
        (P y 1)))))]

@racket[P] 自己答得出来：@racket[q] 是什么都行。接上 @racket[(function->relation id)]，同样的问题就问不出来了：它要先读出 @racket[q] 的值，可 @racket[q] 正是要问的。「交出原样的值」是函数的说法，分了输入和输出。关系的说法是两个位置相等，而合一 @racket[≡] 正是这个关系本身：

@examples[#:eval ev-world #:no-result
(: idᵒ (→ Term Term Goal))
(define idᵒ ≡)]

换成 @racket[idᵒ] 再试：

@examples[#:eval ev-world #:label #f
(run* (q)
  (∃ (y)
    (∧ (idᵒ q y)
       (P y 1))))]

答案和 @racket[P] 自己的一样。@xref["05:goals"]{「未知项、代换与目标」}把目标与关系分成了两层，两层各有自己的恒等关系：在代换层，目标复合 @racket[∧] 的单位是 @racket[⊤]；在关系层，在 @racket[run*] 读出结果的意义下，二元关系复合的单位就是合一 @racket[≡]。特征函数写不出复合，因为缺少 @racket[∃]；函数的 @racket[id] 当不了关系的单位，因为分了输入输出；@xref["05:5-unify"]{「合一」}造出的 @racket[∃] 与 @racket[≡]，正好补齐了这两样。零个关系的复合就是 @racket[idᵒ]，复合可以按参数个数直接写出来：

@examples[#:eval ev-world #:no-result
(: ∘ᵒ (→ (→ Term Term Goal) ... (→ Term Term Goal)))
(define ∘ᵒ
  (case-λ
    [() idᵒ]
    [(P) P]
    [(Q P) (λ (x z) (∃ (y) (∧ (P x y) (Q y z))))]
    [(Q . P*) (∘ᵒ Q (apply ∘ᵒ P*))]))]

@defsym["Q ∘ᵒ P" "关系语言里的复合：∃ 造出中间的未知项"]@racket[∘ᵒ] 和 @racket[∘] 一样从右往左写：两个关系复合时，中间的 @racket[y] 把它们连起来，右边的关系说 @racket[x] 与 @racket[y]，左边的说 @racket[y] 与 @racket[z]。

@section[#:tag "05:four-steps-o"]{四步搬过来}

@racket[right-triangle] 的四步是带 @racket[amb] 的函数。用 @racket[function->relation] 各搬成一个关系，再用 @racket[∘ᵒ] 接起来，说的还是同一张表吗？

@examples[#:eval ev-world #:no-result
(define pick-aᵒ      (function->relation pick-a))
(define pick-bᵒ      (function->relation pick-b))
(define pick-cᵒ      (function->relation pick-c))
(define check-rightᵒ (function->relation check-right))
(define right-triangleᵒ (∘ᵒ check-rightᵒ pick-cᵒ pick-bᵒ pick-aᵒ))]

从 1 到 20 跑一遍：

@examples[#:eval ev-world #:label #f
(run* (t) (right-triangleᵒ '(1 20) t))]

@margin-note{每组外面多了一层括号：@racket[run*] 只读了一个未知项 @racket[t]，一组答案是只有一项的列表。}

还是那六组。@racket[pick-a] 里面用了 @racket[amb]，@racket[function->relation] 照样把它搬过来：它交出几个值，目标就交出几张代换。

接四步的写法，到这里有了三种。@xref["05:two-ways"]{「关系的两种写法」}末尾并排了两行，这里添上第三行：

@racketblock[
(let*      ([y (f x)] [z (g y)]) z)  =  ((∘ℬ g f) x)
(for*/list ([y (f x)] [z (g y)]) z)  =  ((∘ℒ g f) x)
(∃ (y) (∧ (P x y) (Q y z)))          =  ((∘ᵒ Q P) x z)]

前两行的右边交出 @racket[z]；第三行没有谁交出什么，@racket[x] 与 @racket[z] 都只是位置。三种都是复合，中间结果 @racket[y] 在前两行由绑定命名，在第三行由 @racket[∃] 造出。

关系语言不分输入输出，可四步是从函数搬来的，里面的函数仍然只算已经知道的值。倒过来问哪组边界能得到 @racket[(3 4 5)]：

@examples[#:eval ev-world #:label #f
(eval:error (run* (b) (right-triangleᵒ b '(3 4 5))))]

@racket[pick-aᵒ] 要读出边界 @racket[b] 的值，可边界正是要问的东西。

@section[#:tag "05:worlds"]{几个世界之间}

同一个二元关系，这一章有了三种写法：ℬ 里带 @racket[amb] 的函数，ℒ 里交出列表的函数，还有关系语言里的关系。前两种用 @racket[gather] 与 @racket[scatter] 来回搬，来回一趟回到原处。第三种所在的地方也起一个名字，记作 ℛ。它和前两种之间，搬得动吗？

@margin-note{来回一趟回到原处，比的是列表，先后与重复都算在内，搜索要能走完。搬到 ℛ 以后，核对的是输入已经知道的那些问法。从 ℒ 到 ℛ，先用 @racket[scatter] 搬到 ℬ。}

从 ℬ 到 ℛ，刚才搬过：@racket[function->relation] 把四步搬成关系，照原来的方向问，六组照样出来。

从 ℛ 往回搬，就不一定了。ℒ 的箭头收到一个输入，交出一张列表，列出表里与它同在一行的每一项。看一个最简单的二元关系，全关系 @racket[U]，任何两个项都满足它：

@examples[#:eval ev-world #:label #f
(define (U x y) ⊤)
(run* (y) (U 1 y))
(run* (x) (U x 1))]

无论固定哪一列当作输入，答案都是 @tt{(_.0)}：另一列是什么都行。同一个输入对着无穷多行，无法一般地写成枚举同一外延关系全部具体输出的有限列表；ℬ 的箭头要为每一行返回一次，同样走不完。@xref["05:compose"]{「二元关系的复合」}说过，带 @racket[amb] 的函数表示的是每个输入只占有限多行的二元关系。ℛ 里的关系不受这个限制：@tt{_.0} 这一个名字，就代表了那无穷多行。
