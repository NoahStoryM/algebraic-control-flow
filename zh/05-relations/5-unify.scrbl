#lang acf/scribble

@title[#:tag "05:5-unify"]{复合与合一}

到这里，直角三角形的集合写法已经逐字翻成了能运行的程序。前面还用集合的语言写过不少别的表，把它们也一一翻进这门关系语言里，手头的这套写法够不够用？

@section[#:tag "05:zero-ary"]{零列的表}

先从最简单的表开始。@xref["05:relation"]{「关系」}数过，零列的表只有两张，@math{{()}} 与 @math{{}}，对应两个零参@tech{谓词} @racket[(λ () #t)] 与 @racket[(λ () #f)]。照集合语言写成竖线两边的形式，左边是空元组 @math{()}，右边分别是恒真条件 @math{⊤} 与恒假条件 @math{⊥}：

@mm{{() | ⊤} = {()} @hspace[4] {() | ⊥} = {}}

用上一节刚写出的 @racket[predicate->relation] 把它们包装成零元@tech{关系}，再无参调用一次，就得到两个@tech{目标}。把 @racket[predicate->relation] 与 @racket[check] 的定义展开，看看这两个@tech{目标}到底是什么。先看 @racket[(λ () #t)]：

@racketblock[
#,(hspace 2)((predicate->relation (λ () #t)))
= (λ (s) (check #t) s)
= (λ (s) s)]

再看 @racket[(λ () #f)]：

@racketblock[
#,(hspace 2)((predicate->relation (λ () #f)))
= (λ (s) (check #f) s)
= (λ (s) (amb))]

@racket[check] 收到 @racket[#f] 时调用 @racket[(amb)] 放弃当前分支，后面的 @racket[s] 永远走不到。作为@tech{代换}之间的@tech{二元关系}，前者把任意@tech{代换}原样交回一次，是@defterm[#:en "identity relation"]{恒等关系}，总成立、总是成功，记作 @racket[⊤]；后者一次也不交，是一行也没有的@defterm[#:en "empty relation"]{空关系}，总不成立、总是失败，记作 @racket[⊥]：

@margin-note{前四章用 @racket[⊤] 与 @racket[⊥] 记单元类型与@tech{空类型}；这里借用同一对逻辑真假记号表示 @racket[Goal] 类型的值，一个是恒等@tech{目标}，一个是失败@tech{目标}。}

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
(define (list->amb v*) (for/amb ([v (in-list v*)]) v))
(define pick-a (match-λ [(list l   h) (list (between l h)   h)]))
(define pick-b (match-λ [(list a   h) (list a (between a h) h)]))
(struct var ([name : Symbol]) #:type-name Var #:transparent)
(define (var=? u v) (eq? u v))
(define empty-s '())
(define (ext-s x t s) (cons (cons x t) s))
(define (value-of t s)
  (cond
    [(not (var? t)) t]
    [(assq t s) => cdr]
    [else (error 'value-of "~a 的值还不知道" (var-name t))]))
(define (∧ . g*) (apply ∘ℬ (reverse g*)))
(define (((function->relation f) . t*) s)
  (define-values (in* out*) (split-at-right t* 1))
  (ext-s (car out*) (apply f (for/list ([t in*]) (value-of t s))) s))
(define (((predicate->relation p?) . t*) s)
  (check (apply p? (for/list ([t t*]) (value-of t s))))
  s)
(define-syntax-rule (run* (x ...) g)
  (let ([x (var 'x)] ...)
    (in-amb
     (let ([s (g empty-s)])
       (list (value-of x s) ...)))))]
@examples[#:eval ev-comp #:no-result
(: ⊤ Goal)
(define (⊤ s) s)

(: ⊥ Goal)
(define (⊥ s) (amb))]

现在把两张集合表逐字翻进关系语言，交给不读任何位置的 @racket[(run* () ...)]：

@examples[#:eval ev-comp #:label #f
(run* () ⊤)
(run* () ⊥)]

就算一个@tech{未知项}也不读，成功一次和一次也没成功，交出的列表仍然不同：第一行的 @racket['(())] 里有一行答案，行里有零个元素；第二行的 @racket['()] 里一行也没有。两张零列的表，用现有的包装就已经能翻出来。

@racket[⊤] 还是@tech{合取} @racket[∧] 的@tech{单位}。不给任何参数时，@racket[(∧)] 无参调用 @racket[∘ℬ]，交出 @racket[id]，也就是 @racket[(λ (s) s)]，正是 @racket[⊤]。把 @racket[⊤] 接在任意@tech{目标} @racket[g] 的前面或后面，复合上的都是 @racket[id]，@racket[(∧ g ⊤)] 与 @racket[(∧ ⊤ g)] 都还是 @racket[g]。

再看 @racket[⊥]：@racket[(λ (s) (amb))]。@racket[(amb)] 是零支的 @racket[amb]，不试任何支路，一张@tech{代换}也不交。与@tech{合取}相对的@tech{析取} @racket[∨] 把它放成多支：收到的几条@tech{目标}各自从同一张@tech{代换} @racket[s] 出发，逐个试过去，把各支路的结果并起来：

@margin-note{@tech{目标}写成 ℒ 的箭头时，@tech{析取}是把几张@tech{代换}的列表接起来。}

@examples[#:eval ev-comp #:no-result
(: ∨ (→ Goal ... Goal))
(define ((∨ . g*) s) ((list->amb g*) s))]

不给任何参数时，@racket[(∨)] 交出的@tech{目标}收到@tech{代换}后，用 @racket[list->amb] 从空列表里选，一张@tech{代换}也不交，正是 @racket[⊥]。在任一侧并上 @racket[⊥]，那一支不交出任何@tech{代换}，结果照旧。

@section[#:tag "05:compose-o"]{藏起中间一列}

上面是一列也不读。再看另一种情形：一个位置要参加求解，却不想让它出现在最后的答案里。

@xref["05:compose"]{「二元关系的复合」}画过 @racket[pick-a] 与 @racket[pick-b] 首尾相连的三列表：左边是边界 @racket[(1 2)]，右边是 @racket[(a b h)]，中间一列 @racket[(a h)] 用来把两张表对上，对上之后遮住不要。用集合的语言写，这是@tech{二元关系}的复合：

@mm{Q ∘ P = {(x, z) | ∃y, (x, y) ∈ P ∧ (y, z) ∈ Q}}

上一节写过，关系语言里@math{N}元@tech{关系}的类型是 @racket[(→ Term ... Goal)]，因此@tech{二元关系}的类型就是 @racket[(→ Term Term Goal)]。直接把这条公式逐字翻成复合函数 @racket[∘ᵒ]：

@racketblock[
(: ∘ᵒ (→ (→ Term Term Goal) (→ Term Term Goal) (→ Term Term Goal)))
(define ((∘ᵒ Qᵒ Pᵒ) x z)
  (∃ (y) (∧ (Pᵒ x y) (Qᵒ y z))))]

@defsym["Qᵒ ∘ᵒ Pᵒ" "关系语言里的复合：∃ 造出中间的未知项"]@racket[∘ᵒ] 和 @racket[∘] 一样从右往左写：右边的@tech{关系}说 @racket[x] 与 @racket[y]，左边的说 @racket[y] 与 @racket[z]。@racket[(Pᵒ x y)]、@racket[(Qᵒ y z)] 与 @racket[∧] 都已经有了，空下来的只有把 @racket[y] 藏在里面的 @racket[∃]。把 @racket[y] 与 @racket[z] 都写在 @racket[run*] 后面，能给两条条件共用一个 @racket[y]，答案却也会多出这一列；只写 @racket[z]，两条条件里又没有 @racket[y] 可用。需要一个只在内部用到的局部@tech{未知项}，借 @racket[run*] 造@tech{未知项}的那一步就能写出 @racket[∃]：

@examples[#:eval ev-comp #:no-result
(define-syntax-rule (∃ (x ...) g)
  (λ (s) (let ([x (var 'x)] ...) (g s))))]

@racket[∃] 交出的也是@tech{目标}。它等收到@tech{代换}时才造@tech{未知项}，再运行里面的条件：每用一次，造出的都是新的。把 @racket[pick-a] 与 @racket[pick-b] 搬成@tech{关系}，用 @racket[∘ᵒ] 把它们接起来，只读最右一列 @racket[z]：

@margin-note{每组外面多了一层括号：@racket[run*] 只读了一个@tech{未知项} @racket[z]，一组答案是只有一个元素的列表。}

@examples[#:eval ev-comp #:hidden
(define ((∘ᵒ Qᵒ Pᵒ) x z)
  (∃ (y) (∧ (Pᵒ x y) (Qᵒ y z))))]
@examples[#:eval ev-comp #:label #f
(define pick-aᵒ (function->relation pick-a))
(define pick-bᵒ (function->relation pick-b))
(run* (z) ((∘ᵒ pick-bᵒ pick-aᵒ) '(1 2) z))]

正是@xref["05:compose"]{「二元关系的复合」}三列表最右一列的那三行：@racket[(1 1 2)]、@racket[(1 2 2)]、@racket[(2 2 2)]。这里由 @racket[pick-aᵒ] 交出中间值 @racket[y]，@racket[pick-bᵒ] 接着用；如果只靠两个只会检查给定值的@tech{谓词}，仍然缺了提供候选的那一步。

@bold{练习}：上面的 @racket[∘ᵒ] 一次只接两个@tech{关系}。把它扩充成可以接收一个或多个@tech{二元关系}的版本：只给一个时原样交出，给多个时从右往左依次用二元复合接起来。

到这里，复合的写法有了三种。@xref["05:compose-l"]{「列表箭头的复合」}并排写过两行，这里添上第三行：

@racketblock[
(let*      ([y (f x)] [z (g y)]) z)  =  ((∘ℬ g f) x)
(for*/list ([y (f x)] [z (g y)]) z)  =  ((∘ℒ g f) x)
(∃ (y) (∧ (Pᵒ x y) (Qᵒ y z)))        =  ((∘ᵒ Qᵒ Pᵒ) x z)]

第一行每走通一次交出一个 @racket[z]，第二行把这些 @racket[z] 收成一张列表，第三行的 @racket[x] 与 @racket[z] 都是@tech{关系}的位置，调用交出的是@tech{目标}。三种都是复合，中间的 @racket[y] 在前两行由绑定命名，在第三行由 @racket[∃] 造出。

有了复合，自然要问它的@tech{单位}。@xref["05:two-ways"]{「关系的两种写法」}里，这张@tech{单位}表已经有了两种现成的宿主写法：恒等函数 @racket[id] 与二元@tech{谓词} @racket[equal?]。把它们翻进关系语言，手头的两个包装够不够用？

@section[#:tag "05:unify-step"]{合一}

先试从函数出发，用 @racket[function->relation] 包装 @racket[id]：

@examples[#:eval ev-comp #:label #f
(define idᵒ (function->relation id))
(run* (y) (idᵒ 5 y))
(eval:error (run* (x) (idᵒ x 5)))]

左边已知、右边未知时行得通，换到右边已知、左边未知就报错。哪怕写成两条简单的等式，@racket[x] 等于 @racket[y]、@racket[y] 等于 5，第一步还是会卡住：

@examples[#:eval ev-comp #:label #f
(eval:error (run* (x y) (∧ (idᵒ x y) (idᵒ y 5))))]

再试它对应的@tech{谓词}，用 @racket[predicate->relation] 包装 @racket[equal?]：

@examples[#:eval ev-comp #:label #f
(define equalᵒ (predicate->relation equal?))
(run* () (equalᵒ 5 5))
(eval:error (run* (y) (equalᵒ 5 y)))
(eval:error (run* (x) (equalᵒ x 5)))]

这一次两边都必须先知道，哪一头换成@tech{未知项}都会报错。毛病出在同一处：两个包装都先用 @racket[value-of] 读出参数，借来的函数与@tech{谓词}只能算已经知道的值。把 @racket[pythᵒ] 挪到 @racket[right-triangles] 最前面，或者倒过来问边界，挡在面前的也是同一件事。无论借函数还是借@tech{谓词}，都造不出对称的@tech{单位}：两个位置相等，两边都可以暂时不知道，这得在关系语言里自己做。

不借 @racket[id] 和 @racket[equal?]，照前面往@tech{代换}里添记录的办法，直接把刚才卡住的那两条等式记进表里：@racket[x] 等于 @racket[y]，@racket[y] 等于 5。然后问 @racket[x] 的值：

@(define ev-unify (make-acf-eval))
@examples[#:eval ev-unify #:hidden
(require racket/control)
(define ∘ compose)
(define (choose p*) (shift k (append-map k p*)))
(define-syntax-rule (amb e ...) ((choose (list (λ () e) ...))))
(define-syntax-rule (for/amb clauses body ...) ((choose (for/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))
(define (between lo hi) (for/amb ([n (inclusive-range lo hi)]) n))
(define (check ok?) (unless ok? (amb)))
(define ∘ℬ ∘)
(define (list->amb v*) (for/amb ([v (in-list v*)]) v))
(struct var ([name : Symbol]) #:type-name Var #:transparent)
(define (var=? u v) (eq? u v))
(define empty-s '())
(define (ext-s x t s) (cons (cons x t) s))
(define (value-of t s)
  (cond
    [(not (var? t)) t]
    [(assq t s) => cdr]
    [else (error 'value-of "~a 的值还不知道" (var-name t))]))
(define (⊤ s) s)
(define (⊥ s) (amb))
(define ((∨ . g*) s) ((list->amb g*) s))
(define (∧ . g*) (apply ∘ℬ (reverse g*)))
(define-syntax-rule (∃ (x ...) g)
  (λ (s) (let ([x (var 'x)] ...) (g s))))
(define-syntax-rule (run* (x ...) g)
  (let ([x (var 'x)] ...)
    (in-amb
     (let ([s (g empty-s)])
       (list (value-of x s) ...)))))]
@examples[#:eval ev-unify #:label #f
(define x (var 'x))
(define y (var 'y))
(define s (ext-s x y (ext-s y 5 empty-s)))
(value-of x s)]

表记下来了，值却读不对。@racket[x] 对着 @racket[y]，@racket[value-of] 只查了一次，交出的是一个@tech{未知项}；可 @racket[y] 的值，表里明明有。值可以是另一个@tech{未知项}的时候，查表要顺着查下去，查到一个不在表里的项为止：

@examples[#:eval ev-unify #:no-result
(: walk (→ Term Substitution Term))
(define (walk t s)
  (define p (and (var? t) (assq t s)))
  (if p (walk (cdr p) s) t))]

用刚才那张@tech{代换}试一试：

@examples[#:eval ev-unify #:label #f
(walk x s)]

添一行也不能照旧了。表里已经记着 @racket[x] 等于 5，再来一条等式说 @racket[x] 等于 6，直接添上，@racket[x] 就占了两行；等式要是写成 6 等于 @racket[x]，键还成了一个数。添之前，两边都要先顺着表查到底，再对称地比：是同一个@tech{未知项}就原样交回；有一边是@tech{未知项}，就添上一行；两边都不是@tech{未知项}，它们都是完整的 @racket[Data]，用 @racket[equal?] 相等才走得通：

@examples[#:eval ev-unify #:no-result
(: unify (→ Term Term Substitution Substitution))
(define (unify u v s)
  (let ([u (walk u s)] [v (walk v s)])
    (cond
      [(and (var? u) (var? v) (var=? u v)) s]
      [(var? u) (ext-s u v s)]
      [(var? v) (ext-s v u s)]
      [(equal? u v) s]
      [else (amb)])))]

试三组不同的情况：

@examples[#:eval ev-unify #:label #f
(in-amb (unify x y empty-s))
(in-amb (unify 5 x empty-s))
(in-amb (unify 6 x (ext-s x 5 empty-s)))]

头一例两边都不知道，添的一行记着 @racket[x] 等于 @racket[y]。第二例把数写在左边、@tech{未知项}写在右边，照样添上 @racket[x] 等于 5。第三例里 @racket[x] 查到 5，与 6 对不上，这条时间线走不通，@racket[in-amb] 一张@tech{代换}也没有收到。

让两个项相等，必要时往@tech{代换}里添一行，这件事叫@defterm[#:en "unification"]{合一}。添之前先用 @racket[walk] 查到底，交给 @racket[ext-s] 的总是一个还没在表里的@tech{未知项}，所以键不会重复。@tech{代换}也跟着变了样：一行记的不再是某个@tech{未知项}的值，而是一条等式。

把@tech{合一}本身柯里化成@tech{关系}：@racket[unify] 收两个@tech{项}和一张@tech{代换}，交出新的@tech{代换}；把@tech{代换}留到后面收，得到的 @racket[(≡ u v)] 说的是两个项相等，交出的@tech{目标}让它们@tech{合一}。

@examples[#:eval ev-unify #:no-result
(: ≡ (→ Term Term Goal))
(define ((≡ u v) s) (unify u v s))]

@racket[value-of] 也改成顺着查：查到底还是@tech{未知项}就报错；否则它已经是完整的 @racket[Data]，直接交回：

@examples[#:eval ev-unify #:no-result
(: value-of (→ Term Substitution Data))
(define (value-of t s)
  (let ([t (walk t s)])
    (if (var? t)
        (error 'value-of "~a 的值还不知道" (var-name t))
        t)))]

重跑刚才卡住的等式，再顺带试两组：

@examples[#:eval ev-unify #:label #f
(run* (x y) (∧ (≡ x y) (≡ y 5)))
(run* (x y) (∧ (≡ x 1) (≡ 2 y)))
(run* (x) (∧ (≡ x 5) (≡ 6 x)))]

@tech{未知项}写在等式的哪一边都可以，两边都是@tech{未知项}也可以。@racket[∘ᵒ] 一直在找的@tech{单位}，正是@tech{合一} @racket[≡] 本身：

@examples[#:eval ev-unify #:no-result
(: idᵒ (→ Term Term Goal))
(define idᵒ ≡)]

无论哪边是@tech{未知项}，它都能接得住：

@examples[#:eval ev-unify #:label #f
(run* (q) (idᵒ q 5))
(run* (q) (idᵒ 5 q))]

把相等接在 @racket[Pᵒ] 的后面，条件是「存在 @racket[y]，@racket[(Pᵒ x y)] 成立，而且 @racket[y] 等于 @racket[z]」，遮掉中间一列就是 @racket[(Pᵒ x z)]；接在前面同理。就表里的行而言，@racket[≡] 是@tech{二元关系}复合的@tech{单位}；借来的@tech{谓词}仍要求参数先有值，那是宿主的限制。

有了@tech{合一}，@racket[function->relation] 原先的隐患也能一起解决。它之前假设最后一个位置永远是尚未绑定的@tech{未知项}，直接交给 @racket[ext-s] 添一行。要是同一个@tech{未知项}出现在两行的最后一列，比如找同时在 1 到 2 之间、又在 2 到 3 之间的数，或者干脆在最后一列填进一个已知的数，直接添一行就坏了：

@examples[#:eval ev-unify #:hidden
(define (((function->relation f) . t*) s)
  (define-values (in* out*) (split-at-right t* 1))
  (ext-s (car out*) (apply f (for/list ([t in*]) (value-of t s))) s))
(define betweenᵒ (function->relation between))]
@examples[#:eval ev-unify #:label #f
(run* (a) (∧ (betweenᵒ 1 2 a) (betweenᵒ 2 3 a)))
(in-amb ((betweenᵒ 1 3 2) empty-s))]

头一例里 3 明明不在 1 到 2 之间，却跟着出来了，2 还出了两次：第二行直接把新的一行盖在了前面。第二例更怪，@tech{代换}的键成了数 2。

像上一节那样先手写 @racket[betweenᵒ]，只需把原先的 @racket[ext-s] 换成 @racket[unify]：没有值就添一行，有值就成了核对：

@examples[#:eval ev-unify #:no-result
(define ((betweenᵒ l h a) s)
  (unify a (between (value-of l s) (value-of h s)) s))]

两例立刻都走得通了：

@examples[#:eval ev-unify #:label #f
(run* (a) (∧ (betweenᵒ 1 2 a) (betweenᵒ 2 3 a)))
(run* () (betweenᵒ 1 3 2))
(run* () (betweenᵒ 1 3 5))]

把这一步放进 @racket[function->relation]，两版之间同样只差把 @racket[ext-s] 换成 @racket[unify]：输入端继续用 @racket[value-of] 读出宿主函数要用的值，输出端交给 @racket[unify] 既能添记录也能核对：

@examples[#:eval ev-unify #:no-result
(: function->relation (∀ (a ... b) (→ (→ℬ a ... b) (→ Term ... Term Goal))))
(define (((function->relation f) . t*) s)
  (define-values (in* out*) (split-at-right t* 1))
  (unify (car out*) (apply f (for/list ([t in*]) (value-of t s))) s))]

回头看前面试过的 @racket[(function->relation id)]：旧版先对输入做 @racket[value-of]，再把 @racket[ext-s] 柯里化成@tech{目标}；放开输入的 @racket[value-of]，再把单向的 @racket[ext-s] 换成双向的 @racket[unify]，得到的正是 @racket[≡]。
