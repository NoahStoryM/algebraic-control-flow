#lang acf/scribble

@title[#:tag "05:2-relation"]{关系}

我们把带键的表 @racket[(Dict k v)] 定义为 @racket[(Listof (Pair k v))]，可这个定义本身并没有要求 @racket[k] 是键：同一个 @racket[k] 出现几次，类型都不管。@racket[cache] 里的边界不重复，只是因为我们把同一组边界的答案都收进了一张列表。不如放开这个限制，把表摊开，让每组答案各自配上它的边界：

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(require acf/zh/05-relations/show)
(define-type ℕ⁺ Positive-Integer)
(define-type Triangle (List ℕ⁺ ℕ⁺ ℕ⁺))
(define-type (Dict k v) (Listof (Pair k v)))
(define-type Bounds (List ℕ⁺ ℕ⁺))
(define (pyth? a b c) (= (+ (* a a) (* b b)) (* c c)))
(define (right-triangles l h)
  (for*/list ([a (inclusive-range l h)]
              [b (inclusive-range a h)]
              [c (inclusive-range b h)]
              #:when (pyth? a b c))
    (list a b c)))
(define cache
  (for/list ([l×h '((1 4) (1 5) (1 20))])
    (cons l×h (apply right-triangles l×h))))]
@examples[#:eval ev #:label #f #:no-prompt
(: rows (Listof (Pair Bounds Triangle)))
(define rows
  (for*/list ([(l×h t*) (in-dict cache)]
              [t t*])
    (cons l×h t)))]

@racket[cache] 的三条记录，按每组边一行摊开：

@examples[#:eval ev #:label #f
(eval:alts rows (dotted rows))]

@racket[(1 20)] 原来只占一行，现在占了六行；@racket[(1 4)] 记下的列表是空的，摊开以后一行也没有。

@racket[rows] 用列表记下表里的行。行的先后我们并不关心，所以不妨换用集合来记这张表；把所有满足同样条件的行都收进来，用数学的语言描述这个集合：

@mm{R = {((l, h), (a, b, c)) ∈ (ℕ⁺ × ℕ⁺) × (ℕ⁺ × ℕ⁺ × ℕ⁺) | l ≤ a ≤ b ≤ c ≤ h ∧ a² + b² = c²}}

竖线左边的笛卡尔积描述了行的形状，对应每一行的类型 @racket[(Pair Bounds Triangle)]；竖线右边是条件。@math{R} 里的行既符合这个形状，又满足条件，所以 @math{R} 是这个笛卡尔积的一个子集。这个子集完全描述了边界与边之间要满足的关系，因此从数学的角度看，它就是@defterm[#:en "relation"]{关系}。

纯函数可以看作一张以输入为键的表，所以它也是关系，条件是每个输入都有唯一的输出。任意纯函数 @math{f : A → B} 对应的关系是：

@mm{{(a, b) ∈ A × B | b = f(a)}}

表有 @math{N} 列，每一行就取自 @math{N} 个集合的笛卡尔积，对应的是 @defterm[#:en "N-ary relation"]{N 元关系}。@math{R} 和函数对应的关系都有两列，是@defterm[#:en "binary relation"]{二元关系}。

不过几列是看怎么分组。积里的集合本身也可以是积：@math{R} 的左列是一对边界，右列是三条边。把 @racket[rows] 的每一行展平：

@examples[#:eval ev #:label #f #:no-prompt
(: rows/5 (Listof (List ℕ⁺ ℕ⁺ ℕ⁺ ℕ⁺ ℕ⁺)))
(define rows/5
  (for/list ([row rows])
    (match-define (cons (list l h) (list a b c)) row)
    (list l h a b c)))]

同样的七行，每行变成五个数：

@examples[#:eval ev #:label #f
rows/5]

同一张表，分成两组看，是边界与三角形之间的二元关系；摊成五列看，是 @math{ℕ⁺ × ℕ⁺ × ℕ⁺ × ℕ⁺ × ℕ⁺} 的子集，一个五元关系。特别地，一元关系就是某个集合的子集；零个集合的笛卡尔积只有一个元素，就是空的元组 @math{()}，所以零元关系只有两个：@math{{}} 和 @math{{()}}。

@defterm[#:en "predicate"]{谓词}把这几种关系连在了一起。谓词是交出布尔值的函数，@xref["05:1-search"]{第一节}的 @racket[pyth?] 就是一个：

@examples[#:eval ev #:label #f
(pyth? 3 4 5)
(pyth? 3 4 6)]

作为函数，@racket[pyth?] 是三条边与布尔值之间的二元关系：三条边合成一组占一列，布尔值占一列。让它交出 @racket[#t] 的输入构成 @math{ℕ⁺ × ℕ⁺ × ℕ⁺} 的一个子集 @math{{(a, b, c) | a² + b² = c²}}，这是一个三元关系。谓词判断的，就是输入在不在这个子集里。所以 @math{N} 个参数的谓词描述了一个 @math{N} 元关系。零个参数的谓词只有 @racket[(λ () #t)] 和 @racket[(λ () #f)]，正好对应两个零元关系 @math{{()}} 和 @math{{}}。
