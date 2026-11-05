#lang acf/scribble

@title[#:tag "05:1-table"]{表}

搜索交出的是一张列表。这一节从缓存看出，我们一直在和表打交道，而表就是关系。

@section[#:tag "05:search"]{遍历搜索}

给定边长的范围（上下界都取正整数），比如从 1 到 20，找出所有能构成直角三角形的三条边。最直接的办法是暴力搜索：最短边 @racket[a] 从下界试到上界，@racket[b] 从 @racket[a] 试到上界，@racket[c] 从 @racket[b] 试到上界，满足 @math{a² + b² = c²} 的留下。在大多数语言里，暴力搜索是三层嵌套循环；Racket 的 @racket[for*/list] 把三层写在一处。把它包进一个以上下界 @racket[l]、@racket[h] 为参数的函数：

@(define ev-search (make-acf-eval))
@examples[#:eval ev-search #:hidden
(require acf/zh/05-relations/show)]
@examples[#:eval ev-search #:no-result
(define-type ℕ⁺ Positive-Integer)
(define-type Triangle (List ℕ⁺ ℕ⁺ ℕ⁺))

(: pyth? (→ ℕ⁺ ℕ⁺ ℕ⁺ Boolean))
(define (pyth? a b c) (= (+ (* a a) (* b b)) (* c c)))

(: right-triangles (→ ℕ⁺ ℕ⁺ (Listof Triangle)))
(define (right-triangles l h)
  (for*/list ([a (inclusive-range l h)]
              [b (inclusive-range a h)]
              [c (inclusive-range b h)]
              #:when (pyth? a b c))
    (list a b c)))]

上下界取 1 和 20，交出的每一项是一组边长 @racket[(list a b c)]：

@examples[#:eval ev-search #:label #f
(right-triangles 1 20)]

三层循环逐个生成候选。@racket[a] 每取一个值，@racket[b] 就从 @racket[a] 试到上界；@racket[b] 每取一个值，@racket[c] 又从 @racket[b] 试到上界。@math{a = 1} 下面的 @racket[b]、@racket[c] 全部试完，才轮到 @math{a = 2}。每凑齐一组，@racket[#:when] 检查一次：满足条件的由 @racket[(list a b c)] 交出，不满足的什么也不留下。从 1 到 20 一共试了 @math{C(20 + 3 − 1, 3) = 1540} 组，留下六组，按找到的先后接成一张列表。

为了这六组边，循环试了 1540 组。用同样的边界再调用一次，这 1540 组还得从头试一遍，交出的却还是那六组：@racket[right-triangles] 是一个纯函数，输出只由输入决定。既然如此，算过的结果就可以记下来，下次遇到同样的边界直接取出。这就是缓存：

@examples[#:eval ev-search #:no-result
(define-type (Dict k v) (Listof (Pair k v)))
(define-type Bounds (List ℕ⁺ ℕ⁺))

(: cache (Dict Bounds (Listof Triangle)))
(define cache '())

(: right-triangles/cached (→ ℕ⁺ ℕ⁺ (Listof Triangle)))
(define (right-triangles/cached l h)
  (define l×h (list l h))
  (unless (dict-has-key? cache l×h)
    (set! cache (dict-set cache l×h (right-triangles l h))))
  (dict-ref cache l×h))]

@racket[cache] 是一张关联列表，每个元素是一个序对，记着一组边界和它的答案列表。Racket 把这样的列表当作字典：@racket[dict-has-key?] 看某个键在不在，@racket[dict-set] 添上一项，@racket[dict-ref] 按键取值。@racket[right-triangles/cached] 先看这组边界算过没有，没算过就跑一遍循环，把结果记进 @racket[cache]，最后按边界取出。从外面看，它和 @racket[right-triangles] 是同一个函数：

@examples[#:eval ev-search #:label #f
(right-triangles/cached 1 4)
(right-triangles/cached 1 5)
(right-triangles/cached 1 20)
(eval:alts cache (dotted cache))]

再看 @racket[cache] 里记下了什么：一共三行。为了看清每行的两项，这里把序对的点写了出来，点的左边是键，右边是值。键是边界，算过的不会再添，所以同一组边界只占一行。值是答案列表：一组边界对应的不是某一个答案，而是装着全部答案的一张列表，可能有六组，也可能一组都没有。

眼下 @racket[cache] 只记着三组边界。设想把所有的边界都算过一遍，它会是一张巨大的@defterm{表}，每组边界都是其中的键。到那时循环就用不着了，@racket[right-triangles] 只剩下一次查找，可以写成：

@examples[#:eval ev-search #:no-result
(: dictionary->function (∀ (v k ...) (→ (Dict (List k ... k) v) (→ k ... k v))))
(define ((dictionary->function dict) . key) (dict-ref dict key))

(define right-triangles (dictionary->function cache))]

调用函数求值，就是按键查表。从这个角度看，任何纯函数都可以看作一张以输入为键的表。

@section[#:tag "05:relation"]{关系}

我们把带键的表 @racket[(Dict k v)] 定义为 @racket[(Listof (Pair k v))]，可这个定义本身并没有要求 @racket[k] 是键：同一个 @racket[k] 出现几次，类型都不管。@racket[cache] 里的边界不重复，只是因为我们把同一组边界的答案都收进了一张列表。不如放开这个限制，把表摊开，让每组答案各自配上它的边界：

@(define ev-relation (make-acf-eval))
@examples[#:eval ev-relation #:hidden
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
@examples[#:eval ev-relation #:no-result
(: rows (Listof (Pair Bounds Triangle)))
(define rows
  (for*/list ([(l×h t*) (in-dict cache)]
              [t t*])
    (cons l×h t)))]

@racket[cache] 的三条记录，按每组边一行摊开：

@examples[#:eval ev-relation #:label #f
(eval:alts rows (dotted rows))]

@racket[(1 20)] 原来只占一行，现在占了六行；@racket[(1 4)] 记下的列表是空的，摊开以后一行也没有。

@racket[rows] 用列表记下表里的行。行的先后我们并不关心，所以不妨换用集合来记这张表；把所有满足同样条件的行都收进来，用数学的语言描述这个集合：

@mm{R = {((l, h), (a, b, c)) ∈ (ℕ⁺ × ℕ⁺) × (ℕ⁺ × ℕ⁺ × ℕ⁺) | l ≤ a ≤ b ≤ c ≤ h ∧ a² + b² = c²}}

竖线左边的笛卡尔积描述了行的形状，对应每一行的类型 @racket[(Pair Bounds Triangle)]；竖线右边是条件。@math{R} 里的行既符合这个形状，又满足条件，所以 @math{R} 是这个笛卡尔积的一个子集。这个子集完全描述了边界与边之间要满足的关系，因此从数学的角度看，它就是@defterm[#:en "relation"]{关系}。

纯函数可以看作一张以输入为键的表，所以它也是关系，条件是每个输入都有唯一的输出。任意纯函数 @math{f : A → B} 对应的关系是：

@mm{{(a, b) ∈ A × B | b = f(a)}}

表有 @math{N} 列，每一行就取自 @math{N} 个集合的笛卡尔积，对应的是 @defterm[#:en "N-ary relation"]{N 元关系}。@math{R} 和函数对应的关系都有两列，是@defterm[#:en "binary relation"]{二元关系}。

不过几列是看怎么分组。积里的集合本身也可以是积：@math{R} 的左列是一对边界，右列是三条边。把 @racket[rows] 的每一行展平：

@examples[#:eval ev-relation #:no-result
(: rows/5 (Listof (List ℕ⁺ ℕ⁺ ℕ⁺ ℕ⁺ ℕ⁺)))
(define rows/5
  (for/list ([row rows])
    (match-define (cons (list l h) (list a b c)) row)
    (list l h a b c)))]

同样的七行，每行变成五个数：

@examples[#:eval ev-relation #:label #f
rows/5]

同一张表，分成两组看，是边界与三角形之间的二元关系；摊成五列看，是 @math{ℕ⁺ × ℕ⁺ × ℕ⁺ × ℕ⁺ × ℕ⁺} 的子集，一个五元关系。特别地，一元关系就是某个集合的子集；零个集合的笛卡尔积只有一个元素，就是空的元组 @math{()}，所以零元关系只有两个：@math{{}} 和 @math{{()}}。

@defterm[#:en "predicate"]{谓词}把这几种关系连在了一起。谓词是交出布尔值的函数，@xref["05:search"]{「遍历搜索」}的 @racket[pyth?] 就是一个：

@examples[#:eval ev-relation #:label #f
(pyth? 3 4 5)
(pyth? 3 4 6)]

作为函数，@racket[pyth?] 是三条边与布尔值之间的二元关系：三条边合成一组占一列，布尔值占一列。让它交出 @racket[#t] 的输入构成 @math{ℕ⁺ × ℕ⁺ × ℕ⁺} 的一个子集 @math{{(a, b, c) | a² + b² = c²}}，这是一个三元关系。谓词判断的，就是输入在不在这个子集里。所以 @math{N} 个参数的谓词描述了一个 @math{N} 元关系。零个参数的谓词只有 @racket[(λ () #t)] 和 @racket[(λ () #f)]，正好对应两个零元关系 @math{{()}} 和 @math{{}}。

@section[#:tag "05:endless-table"]{写不完的表}

谓词虽然能表示一张表，但它只能检查一行在不在这张表里，无法直接读出表里记着的数据。要读出数据，得按键查表。

像 @racket[cache] 这样的字典，键是唯一的，所以从头找下去，第一次找到就可以交出结果。@racket[rows] 没有这个限制，同一组边界可以出现在好几行里；那就把整张表走完，把找到的值都收进一张列表。

两种查法并排写出来，再各配一个把表变成函数的转换。@racket[dict-ref] 是库里的函数，这里只看查得到键的情形，把它自己写一遍：

@(define ev-table (make-acf-eval))
@examples[#:eval ev-table #:hidden
(define (pyth? a b c) (= (+ (* a a) (* b b)) (* c c)))
(define (right-triangles l h)
  (for*/list ([a (inclusive-range l h)]
              [b (inclusive-range a h)]
              [c (inclusive-range b h)]
              #:when (pyth? a b c))
    (list a b c)))
(define rows
  (for*/list ([l×h '((1 4) (1 5) (1 20))]
              [t (apply right-triangles l×h)])
    (cons l×h t)))]
@examples[#:eval ev-table #:no-result
(define (dict-ref  dict key) (for/first ([(k v) (in-dict dict)] #:when (equal? key k)) v))
(define (dict-ref* dict key) (for/list  ([(k v) (in-dict dict)] #:when (equal? key k)) v))

(define ((dictionary->function dict) . key) (dict-ref  dict key))
(define ((table->relation      dict) . key) (dict-ref* dict key))]

两种查法只差在 @racket[for/first] 与 @racket[for/list]。在 @racket[rows] 上试一试：

@examples[#:eval ev-table #:label #f
((table->relation rows) 1 20)
((table->relation rows) 1 4)]

@racket[(table->relation rows)] 收到一组边界，交出一张三角形的列表，类型是 @racket[(→ ℕ⁺ ℕ⁺ (Listof Triangle))]，正是 @racket[right-triangles] 的类型。上一节把 @racket[cache] 里的列表摊开，得到了 @racket[rows]；这里按键把 @racket[rows] 收拢，@racket[cache] 里的每组边界又对上了原来那张列表。

函数是一个特殊的二元关系，对应一个字典；一般的二元关系对应一张表。一个输入对应的可以是一行、许多行，或者一行也没有，这些行的右边一列合起来，是 @math{B} 的一个子集。@math{B} 的所有子集也构成一个集合，叫 @math{B} 的@defterm[#:en "power set"]{幂集}，记作 @math{P(B)}。每个输入都对应 @math{P(B)} 的一个元素，所以二元关系 @math{R ⊆ A × B} 与函数 @math{A → P(B)} 一一对应：按输入收拢，就从关系得到函数；摊开，又从函数回到关系。

程序里用列表代替集合，@racket[(table->relation rows)] 就是这样一个交出列表的函数。列表比集合多记了先后与重复，也只能列出有限多项，所以只有每个输入对应的行能完整列出来的关系，才能这样表示。记着列表的字典，摊开就是一张表；一张表，按键收拢，又是一个记着列表的字典。不计先后与重复，二者可以来回转换，但不是@tech{同构}：记着空列表的键，摊开以后一行也不剩，收拢回来就找不到了。

不过表可能有无穷多行。@math{R} 就是这样，边界有无穷多组，整张表是写不完的，@racket[rows] 只记着算过的三组。好在程序用不着整张表，问到哪几行，算出哪几行就够了。@racket[right-triangles/cached] 正是这样做的：收到一组没算过的边界，现算，记进 @racket[cache]。表不是事先写好的，而是随着查找一点点长出来。

这种到用的时候才算的做法叫@defterm[#:en "lazy"]{惰性}。记下来只是为了不算第二遍；不记，每次现算，交出的也是同样的行。所以在程序里表示关系，靠的是函数：函数可以看作那张写不完的表，表里的行等到查的时候才算出来。
