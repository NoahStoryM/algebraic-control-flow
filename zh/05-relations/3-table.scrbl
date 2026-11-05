#lang acf/scribble

@title[#:tag "05:3-table"]{写不完的表}

谓词虽然能表示一张表，但它只能检查一行在不在这张表里，无法直接读出表里记着的数据。要读出数据，得按键查表。

像 @racket[cache] 这样的字典，键是唯一的，所以从头找下去，第一次找到就可以交出结果。@racket[rows] 没有这个限制，同一组边界可以出现在好几行里；那就把整张表走完，把找到的值都收进一张列表。

两种查法并排写出来，再各配一个把表变成函数的转换。@racket[dict-ref] 是库里的函数，这里只看查得到键的情形，把它自己写一遍：

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
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
@examples[#:eval ev #:label #f #:no-prompt
(define (dict-ref  dict key) (for/first ([(k v) (in-dict dict)] #:when (equal? key k)) v))
(define (dict-ref* dict key) (for/list  ([(k v) (in-dict dict)] #:when (equal? key k)) v))

(define ((dictionary->function dict) . key) (dict-ref  dict key))
(define ((table->relation      dict) . key) (dict-ref* dict key))]

两种查法只差在 @racket[for/first] 与 @racket[for/list]。在 @racket[rows] 上试一试：

@examples[#:eval ev #:label #f
((table->relation rows) 1 20)
((table->relation rows) 1 4)]

@racket[(table->relation rows)] 收到一组边界，交出一张三角形的列表，类型是 @racket[(→ ℕ⁺ ℕ⁺ (Listof Triangle))]，正是 @racket[right-triangles] 的类型。上一节把 @racket[cache] 里的列表摊开，得到了 @racket[rows]；这里按键把 @racket[rows] 收拢，@racket[cache] 里的每组边界又对上了原来那张列表。

函数是一个特殊的二元关系，对应一个字典；一般的二元关系对应一张表。一个输入对应的可以是一行、许多行，或者一行也没有，这些行的右边一列合起来，是 @math{B} 的一个子集。@math{B} 的所有子集也构成一个集合，叫 @math{B} 的@defterm[#:en "power set"]{幂集}，记作 @math{P(B)}。每个输入都对应 @math{P(B)} 的一个元素，所以二元关系 @math{R ⊆ A × B} 与函数 @math{A → P(B)} 一一对应：按输入收拢，就从关系得到函数；摊开，又从函数回到关系。

程序里用列表代替集合，@racket[(table->relation rows)] 就是这样一个交出列表的函数。列表比集合多记了先后与重复，也只能列出有限多项，所以只有每个输入对应的行能完整列出来的关系，才能这样表示。记着列表的字典，摊开就是一张表；一张表，按键收拢，又是一个记着列表的字典。不计先后与重复，二者可以来回转换，但不是@tech{同构}：记着空列表的键，摊开以后一行也不剩，收拢回来就找不到了。

不过表可能有无穷多行。@math{R} 就是这样，边界有无穷多组，整张表是写不完的，@racket[rows] 只记着算过的三组。好在程序用不着整张表，问到哪几行，算出哪几行就够了。@racket[right-triangles/cached] 正是这样做的：收到一组没算过的边界，现算，记进 @racket[cache]。表不是事先写好的，而是随着查找一点点长出来。

这种到用的时候才算的做法叫@defterm[#:en "lazy"]{惰性}。记下来只是为了不算第二遍；不记，每次现算，交出的也是同样的行。所以在程序里表示关系，靠的是函数：函数可以看作那张写不完的表，表里的行等到查的时候才算出来。
