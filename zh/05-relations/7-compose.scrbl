#lang acf/scribble

@title[#:tag "05:7-compose"]{二元关系的复合}

@racket[inclusive-range] 收到一组边界，交出其间所有的数；@racket[right-triangles] 收到一组边界，交出所有的直角三角形。两个都是交出列表的函数，表示的都是二元关系。

@racket[inclusive-range] 表示的关系，@racket[between] 也表示：把 @racket[between] 放进 @racket[in-amb]，交出的正是 @racket[inclusive-range] 的那张列表。

@racketblock[
(inclusive-range l h)  =  (in-amb (between l h))]

区别在写法。@racket[between] 写出来是个普通的函数，收到两个数，交出一个数；放在 @racket[in-amb] 里，同一组输入在表里占几行，它就返回几次。没有 @racket[amb] 的时候，函数只能表示每个输入恰好占一行的二元关系；有了 @racket[amb]，普通写法的函数可以表示每个输入只占有限多行的二元关系。

@racket[right-triangles] 也可以这样得到。分成四步，每一步都写成这样的函数，收到一项，交出一项，再用普通的 @racket[∘] 接起来：

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(require racket/control)
(define ∘ compose)
(define (pyth? a b c) (= (+ (* a a) (* b b)) (* c c)))
(define (choose p*) (shift k (append-map k p*)))
(define-syntax-rule (amb e ...) ((choose (list (λ () e) ...))))
(define-syntax-rule (for/amb clauses body ...) ((choose (for/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))
(define (between lo hi) (for/amb ([n (inclusive-range lo hi)]) n))
(define (check ok?) (unless ok? (amb)))]
@examples[#:eval ev #:label #f #:no-prompt
(define pick-a (match-λ [(list l   h) (list (between l h)   h)]))
(define pick-b (match-λ [(list a   h) (list a (between a h) h)]))
(define pick-c (match-λ [(list a b h) (list a b (between b h))]))
(define (check-right t) (check (apply pyth? t)) t)
(define right-triangle (∘ check-right pick-c pick-b pick-a))]

开始时手里是一组边界 @racket[(l h)]。

@itemlist[#:style 'ordered
@item{@racket[pick-a] 在边界之间选最短边 @racket[a]。后面的边不会比它短，@racket[a] 就是新的下界，交出的还是两项，@racket[(a h)]。}
@item{@racket[pick-b] 在 @racket[a] 与 @racket[h] 之间选第二条边 @racket[b]，交出三项，@racket[(a b h)]。}
@item{@racket[pick-c] 在 @racket[b] 与 @racket[h] 之间选最长边 @racket[c]。上界用不着了，交出的正好是三条边，@racket[(a b c)]。}
@item{@racket[check-right] 检查这三条边是不是直角三角形，是才原样交出。}]

接起来的 @racket[right-triangle] 表示的正是 @racket[right-triangles] 的那个关系：把它放进 @racket[in-amb]，交出的就是那张列表。

@racketblock[
(right-triangles l h)  =  (in-amb (right-triangle (list l h)))]

每一步都是一个二元关系，也就是一张两列的表：左边一列是收到的项，右边一列是交出的项。函数能复合，表也就能复合：把两张表并排放，前一张某一行的右边与后一张某一行的左边是同一项，这两行就首尾相连，连成一行。拿 @racket[pick-a] 与 @racket[pick-b] 来说，边界取 @racket[(1 2)] 时连出三行：

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list @racket[(l h)] @racket[(a h)] @racket[(a b h)])
   (list @racket[(1 2)] @racket[(1 2)] @racket[(1 1 2)])
   (list @racket[(1 2)] @racket[(1 2)] @racket[(1 2 2)])
   (list @racket[(1 2)] @racket[(2 2)] @racket[(2 2 2)]))]

每一行的左边两列是 @racket[pick-a] 表里的一行，右边两列是 @racket[pick-b] 表里的一行。遮住中间一列，剩下的两列就是 @racket[(∘ pick-b pick-a)] 表里的三行。用集合的语言写，这是二元关系的复合：

@mm{Q ∘ P = {(x, z) | ∃y, (x, y) ∈ P ∧ (y, z) ∈ Q}}

@math{y} 就是被遮住的中间一列。「存在这样的 @math{y}」由 @racket[amb] 兑现：@racket[pick-a] 交出的每一项，@racket[pick-b] 都会接着用。有了 @racket[amb]，函数的复合就是二元关系的复合。

把 @math{P}、@math{Q} 看作交出集合的函数，@math{P(x)} 是 @math{P} 里与 @math{x} 同在一行的所有 @math{y}，同一个复合写作：

@mm{(Q ∘ P)(x) = ⋃ { Q(y) | y ∈ P(x) }}

「存在这样的 @math{y}」成了「@math{P(x)} 里的每个 @math{y} 各取一次 @math{Q(y)}，再并起来」。
