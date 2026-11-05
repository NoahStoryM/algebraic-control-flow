#lang acf/scribble

@title[#:tag "05:1-search"]{遍历搜索}

给定边长的范围（上下界都取正整数），比如从 1 到 20，找出所有能构成直角三角形的三条边。最直接的办法是暴力搜索：最短边 @racket[a] 从下界试到上界，@racket[b] 从 @racket[a] 试到上界，@racket[c] 从 @racket[b] 试到上界，满足 @math{a² + b² = c²} 的留下。在大多数语言里，暴力搜索是三层嵌套循环；Racket 的 @racket[for*/list] 把三层写在一处。把它包进一个以上下界 @racket[l]、@racket[h] 为参数的函数：

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(require acf/zh/05-relations/show)]
@examples[#:eval ev #:label #f #:no-prompt
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

@examples[#:eval ev #:label #f
(right-triangles 1 20)]

三层循环逐个生成候选。@racket[a] 每取一个值，@racket[b] 就从 @racket[a] 试到上界；@racket[b] 每取一个值，@racket[c] 又从 @racket[b] 试到上界。@math{a = 1} 下面的 @racket[b]、@racket[c] 全部试完，才轮到 @math{a = 2}。每凑齐一组，@racket[#:when] 检查一次：满足条件的由 @racket[(list a b c)] 交出，不满足的什么也不留下。从 1 到 20 一共试了 @math{C(20 + 3 − 1, 3) = 1540} 组，留下六组，按找到的先后接成一张列表。

为了这六组边，循环试了 1540 组。用同样的边界再调用一次，这 1540 组还得从头试一遍，交出的却还是那六组：@racket[right-triangles] 是一个纯函数，输出只由输入决定。既然如此，算过的结果就可以记下来，下次遇到同样的边界直接取出。这就是缓存：

@examples[#:eval ev #:label #f #:no-prompt
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

@examples[#:eval ev #:label #f
(right-triangles/cached 1 4)
(right-triangles/cached 1 5)
(right-triangles/cached 1 20)
(eval:alts cache (dotted cache))]

再看 @racket[cache] 里记下了什么：一共三行。为了看清每行的两项，这里把序对的点写了出来，点的左边是键，右边是值。键是边界，算过的不会再添，所以同一组边界只占一行。值是答案列表：一组边界对应的不是某一个答案，而是装着全部答案的一张列表，可能有六组，也可能一组都没有。

眼下 @racket[cache] 只记着三组边界。设想把所有的边界都算过一遍，它会是一张巨大的@defterm{表}，每组边界都是其中的键。到那时循环就用不着了，@racket[right-triangles] 只剩下一次查找，可以写成：

@examples[#:eval ev #:label #f #:no-prompt
(: dictionary->function (∀ (v k ...) (→ (Dict (List k ... k) v) (→ k ... k v))))
(define ((dictionary->function dict) . key) (dict-ref dict key))

(define right-triangles (dictionary->function cache))]

调用函数求值，就是按键查表。从这个角度看，任何纯函数都可以看作一张以输入为键的表。
