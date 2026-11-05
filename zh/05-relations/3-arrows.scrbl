#lang acf/scribble

@title[#:tag "05:3-arrows"]{关系成为箭头}

有了 @racket[amb]，普通写法的函数就能表示关系。这一节把关系接起来，再回到纯的宿主，看关系在那里是什么样子。

@section[#:tag "05:compose"]{二元关系的复合}

@racket[inclusive-range] 收到一组边界，交出其间所有的数；@racket[right-triangles] 收到一组边界，交出所有的直角三角形。两个都是交出列表的函数，表示的都是二元关系。

@racket[inclusive-range] 表示的关系，@racket[between] 也表示：把 @racket[between] 放进 @racket[in-amb]，交出的正是 @racket[inclusive-range] 的那张列表。

@racketblock[
(inclusive-range l h)  =  (in-amb (between l h))]

区别在写法。@racket[between] 写出来是个普通的函数，收到两个数，交出一个数；放在 @racket[in-amb] 里，同一组输入在表里占几行，它就返回几次。没有 @racket[amb] 的时候，函数只能表示每个输入恰好占一行的二元关系；有了 @racket[amb]，普通写法的函数可以表示每个输入只占有限多行的二元关系。

@racket[right-triangles] 也可以这样得到。分成四步，每一步都写成这样的函数，收到一项，交出一项，再用普通的 @racket[∘] 接起来：

@(define ev-compose (make-acf-eval))
@examples[#:eval ev-compose #:hidden
(require racket/control)
(define ∘ compose)
(define (pyth? a b c) (= (+ (* a a) (* b b)) (* c c)))
(define (choose p*) (shift k (append-map k p*)))
(define-syntax-rule (amb e ...) ((choose (list (λ () e) ...))))
(define-syntax-rule (for/amb clauses body ...) ((choose (for/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))
(define (between lo hi) (for/amb ([n (inclusive-range lo hi)]) n))
(define (check ok?) (unless ok? (amb)))]
@examples[#:eval ev-compose #:no-result
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

@section[#:tag "05:two-ways"]{关系的两种写法}

有了 @racket[amb]，函数就是二元关系，函数的复合就是二元关系的复合。可是这份方便是借来的：@racket[amb] 不是宿主原有的运算，它靠 @racket[shift] 和 @racket[reset] 做出来，@racket[between] 也算不上纯函数。纯的宿主里没有 @racket[amb]，那里的二元关系是什么样子？

@xref["02:5-where"]{第二章}问过同样的问题，那里借的是 @racket[call/cc]。回答是另一种箭头：把类型从 @math{p → q} 改成 @math{p → ¬¬q}，再给它配上自己的复合，纯的宿主程序就写得出原来要靠 @racket[call/cc] 的控制。这里照样做。纯的宿主记作 𝒞，添上 @racket[amb] 的宿主记作 ℬ，@defsym["p →ℬ q" "添上 amb 的宿主里的箭头：仍是普通的函数类型"]要找的是 𝒞 里与 ℬ 的箭头对应的那种箭头。

ℬ 比 𝒞 只多了 @racket[amb]，原来的都还在。纯函数是每个输入恰好占一行的二元关系，放进 ℬ 里同样合法；箭头还是普通的函数类型，复合还是普通的 @racket[∘]：

@(define ev-two-ways (make-acf-eval))
@examples[#:eval ev-two-ways #:hidden
(require racket/control)
(define ∘ compose)
(define (choose p*) (shift k (append-map k p*)))
(define-syntax-rule (for/amb clauses body ...) ((choose (for/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))]
@examples[#:eval ev-two-ways #:no-result
(define-type (→𝒞 p q) (→ p q))
(define-type (→ℬ p q) (→ p q))

(: inj (∀ (p q) (→ (→𝒞 p q) (→ℬ p q))))
(define (inj f) f)

(: ∘ℬ (∀ (p ...) (→ (→ℬ pn-1 pn) ... (→ℬ p1 p2) (→ℬ p1 pn))))
(define ∘ℬ ∘)]

要找的箭头不用另造，它早就有了，我们也不陌生：交出列表的函数。@racket[right-triangles] 是，@racket[inclusive-range] 也是，我们从一开始就是这样模拟关系的，只是列表多记了结果的先后和重复，表不记这些。一个输入对应的结果不分几次返回，而是装进一张列表，一次交出来；箭头的类型从 @math{p → q} 改成 @math{p → (@ty{Listof} q)}。这种箭头@defsym["p →ℒ q" "交出列表的函数：纯宿主里的二元关系"]记作 @math{→@subscript{ℒ}}，都是纯函数。

@examples[#:eval ev-two-ways #:no-result
(define-type (→ℒ p q) (→ p (Listof q)))]

ℬ 与 ℒ 的箭头模拟的是同一样东西，二元关系，两种箭头也可以来回搬。从 ℒ 到 ℬ，把交出的列表交给 @racket[amb]，散成几条时间线，叫 @racket[scatter]；从 ℬ 到 ℒ，用 @racket[in-amb] 把各条时间线的结果收成一张列表，叫 @racket[gather]：

@examples[#:eval ev-two-ways #:no-result
(: list->amb (∀ (p) (→ (Listof p) p)))
(define (list->amb v*) (for/amb ([v (in-list v*)]) v))

(: scatter (∀ (p q) (→ (→ℒ p q) (→ℬ p q))))
(define (scatter f) (∘ list->amb f))

(: gather (∀ (p q) (→ (→ℬ p q) (→ℒ p q))))
(define ((gather g) . x*) (in-amb (apply g x*)))]

搬过去再搬回来，得到的还是原来的箭头：@racket[(in-amb (list->amb v*))] 把 @racket[v*] 的每一项各包成一张列表，再接起来，还是 @racket[v*]；反过来，@racket[(list->amb (in-amb e))] 把 @racket[e] 的结果收齐了再逐个交出，后面的计算看到的还是那些结果。来回一趟都回到原处，所以两种箭头@tech{同构}，是同一组二元关系的两种写法；这里比的是 @racket[in-amb] 收到的列表，先后与重复都算在内。@racket[between] 与 @racket[inclusive-range] 就是同一个二元关系的两种写法：

@racketblock[
inclusive-range  =  (gather between)
between  =  (scatter inclusive-range)]

同构的两种箭头，复合也该对得上。可是 ℒ 的箭头不能用 @racket[∘] 接：前一个交出一张列表，后一个只收其中一项。ℬ 的箭头能接，那就借同构把 ℬ 的复合搬过来@defsym["g ∘ℒ f" "交出列表的函数的复合：借 ℬ 的复合定义，化简后是 append-map"]：先把 ℒ 的箭头搬到 ℬ，在那边接好，再搬回来。@xref["02:via-contrapositive"]{第二章借道逆否箭头}搬运 @racket[∘𝒦] 的运算律，用的也是这个办法。

@examples[#:eval ev-two-ways #:no-result
(: ∘ℒ (∀ (p ...) (→ (→ℒ pn-1 pn) ... (→ℒ p1 p2) (→ℒ p1 pn))))
(define (∘ℒ . f*) (gather (apply ∘ℬ (map scatter f*))))]

这个定义绕道 ℬ，用到了 @racket[amb]，而 ℒ 要住在纯的宿主里。拿两步的情形，展开 @racket[gather] 与 @racket[scatter]，再化简：

@racketblock[
#,(hspace 2)((∘ℒ g f) x)
= ((gather (∘ℬ (scatter g) (scatter f))) x)
= ((gather (∘ list->amb g list->amb f)) x)
= (in-amb
   (let* ([y (list->amb (f x))]
          [z (list->amb (g y))])
     z))
= (reset
   (let* ([y (choose (f x))]
          [z (choose (g y))])
     (list z)))
= ((choose/k (f x))
   (λ (y)
     ((choose/k (g y))
      (λ (z)
        (list z)))))
= (for*/list ([y (f x)]
              [z (g y)])
    z)
= (append-map (λ (y) (append-map list (g y))) (f x))
= (append-map (λ (y) (g y)) (f x))
= (append-map g (f x))]

展开之后原路往回走，依次是这一章出现过的四种写法：@racket[in-amb] 里的 @racket[let*]，@racket[reset] 里的 @racket[choose]，交给 @racket[choose/k] 的延续，@racket[for*/list] 的循环。循环摊开就是 @racket[append-map]；@racket[(append-map list v*)] 把每一项各包成一张列表再接起来，还是 @racket[v*]，里面那一层就化掉了。@racket[amb] 不见了，剩下的是纯函数：对前一步交出的每一项调用后一步，把结果接成一张。多于两步时也一样，从最右边的一步起，逐个用 @racket[append-map] 接上。最右边那一步收下全部参数。于是 @racket[∘ℒ] 可以不经过 ℬ，直接在 𝒞 里定义：

@racketblock[
(define ((∘ℒ g* ... f) . x*)
  (foldr append-map (apply f x*) g*))]

参数表是示意写法：最右边的箭头叫 @racket[f]，其余的收在 @racket[g*] 里。Racket 的剩余参数只能放在最后，完整代码里用 @racket[split-at-right] 取出 @racket[f]。

纯的宿主里没有 @racket[amb]，二元关系在那里就是这个样子：交出列表的函数，用 @racket[append-map] 接起来。这正是@xref["05:compose"]{「二元关系的复合」}一节那个取并的式子，集合换成了列表，⋃ 换成了 @racket[append-map]。

化简途中的两行还可以并排着看。@racket[in-amb] 里的那段 @racket[let*] 是 @racket[∘ℬ] 展开得来的，@racket[for*/list] 的循环化简下去就是 @racket[∘ℒ]：

@racketblock[
(let*      ([y (f x)] [z (g y)]) z)  =  ((∘ℬ g f) x)
(for*/list ([y (f x)] [z (g y)]) z)  =  ((∘ℒ g f) x)]

第一行的 @racket[f]、@racket[g] 是 ℬ 的箭头，第二行的是 ℒ 的箭头。两种箭头各有一种绑定的写法，写出来的都是复合，多出来的只是中间结果的名字。

@bold{练习}：化简里有一步，@racket[in-amb] 展开成 @racket[reset] 与 @racket[list]，@racket[list->amb] 则直接换成了 @racket[choose]，这暗示两者的行为相同。展开 @racket[for/amb] 的定义，验证 @racket[list->amb] 与 @racket[choose] 是同一个函数。提示：@racket[for/amb] 交给 @racket[choose] 的是一张 λ 的列表，选出来以后还要调用一次。
