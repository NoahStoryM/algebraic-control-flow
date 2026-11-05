#lang acf/scribble

@title[#:tag "05:8-two-ways"]{关系的两种写法}

有了 @racket[amb]，函数就是二元关系，函数的复合就是二元关系的复合。可是这份方便是借来的：@racket[amb] 不是宿主原有的运算，它靠 @racket[shift] 和 @racket[reset] 做出来，@racket[between] 也算不上纯函数。纯的宿主里没有 @racket[amb]，那里的二元关系是什么样子？

@xref["02:5-where"]{第二章}问过同样的问题，那里借的是 @racket[call/cc]。回答是另一种箭头：把类型从 @math{p → q} 改成 @math{p → ¬¬q}，再给它配上自己的复合，纯的宿主程序就写得出原来要靠 @racket[call/cc] 的控制。这里照样做。纯的宿主记作 𝒞，添上 @racket[amb] 的宿主记作 ℬ，@defsym["p →ℬ q" "添上 amb 的宿主里的箭头：仍是普通的函数类型"]要找的是 𝒞 里与 ℬ 的箭头对应的那种箭头。

ℬ 比 𝒞 只多了 @racket[amb]，原来的都还在。纯函数是每个输入恰好占一行的二元关系，放进 ℬ 里同样合法；箭头还是普通的函数类型，复合还是普通的 @racket[∘]：

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(require racket/control)
(define ∘ compose)
(define (choose p*) (shift k (append-map k p*)))
(define-syntax-rule (for/amb clauses body ...) ((choose (for/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))]
@examples[#:eval ev #:label #f #:no-prompt
(define-type (→𝒞 p q) (→ p q))
(define-type (→ℬ p q) (→ p q))

(: inj (∀ (p q) (→ (→𝒞 p q) (→ℬ p q))))
(define (inj f) f)

(: ∘ℬ (∀ (p ...) (→ (→ℬ pn-1 pn) ... (→ℬ p1 p2) (→ℬ p1 pn))))
(define ∘ℬ ∘)]

要找的箭头不用另造，它早就有了，我们也不陌生：交出列表的函数。@racket[right-triangles] 是，@racket[inclusive-range] 也是，我们从一开始就是这样模拟关系的，只是列表多记了结果的先后和重复，表不记这些。一个输入对应的结果不分几次返回，而是装进一张列表，一次交出来；箭头的类型从 @math{p → q} 改成 @math{p → (@ty{Listof} q)}。这种箭头@defsym["p →ℒ q" "交出列表的函数：纯宿主里的二元关系"]记作 @math{→@subscript{ℒ}}，都是纯函数。

@examples[#:eval ev #:label #f #:no-prompt
(define-type (→ℒ p q) (→ p (Listof q)))]

ℬ 与 ℒ 的箭头模拟的是同一样东西，二元关系，两种箭头也可以来回搬。从 ℒ 到 ℬ，把交出的列表交给 @racket[amb]，散成几条时间线，叫 @racket[scatter]；从 ℬ 到 ℒ，用 @racket[in-amb] 把各条时间线的结果收成一张列表，叫 @racket[gather]：

@examples[#:eval ev #:label #f #:no-prompt
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

@examples[#:eval ev #:label #f #:no-prompt
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

纯的宿主里没有 @racket[amb]，二元关系在那里就是这个样子：交出列表的函数，用 @racket[append-map] 接起来。这正是@xref["05:7-compose"]{「二元关系的复合」}一节那个取并的式子，集合换成了列表，⋃ 换成了 @racket[append-map]。

化简途中的两行还可以并排着看。@racket[in-amb] 里的那段 @racket[let*] 是 @racket[∘ℬ] 展开得来的，@racket[for*/list] 的循环化简下去就是 @racket[∘ℒ]：

@racketblock[
(let*      ([y (f x)] [z (g y)]) z)  =  ((∘ℬ g f) x)
(for*/list ([y (f x)] [z (g y)]) z)  =  ((∘ℒ g f) x)]

第一行的 @racket[f]、@racket[g] 是 ℬ 的箭头，第二行的是 ℒ 的箭头。两种箭头各有一种绑定的写法，写出来的都是复合，多出来的只是中间结果的名字。

@bold{练习}：化简里有一步，@racket[in-amb] 展开成 @racket[reset] 与 @racket[list]，@racket[list->amb] 则直接换成了 @racket[choose]，这暗示两者的行为相同。展开 @racket[for/amb] 的定义，验证 @racket[list->amb] 与 @racket[choose] 是同一个函数。提示：@racket[for/amb] 交给 @racket[choose] 的是一张 λ 的列表，选出来以后还要调用一次。
