#lang acf/scribble

@title[#:tag "05:5-unify"]{复合与合一}

到这里，直角三角形的集合写法已经逐字翻成了能运行的程序。前面还用集合的语言写过不少别的表，把它们也一一翻进这门关系语言里，手头的这套写法够不够用？

@section[#:tag "05:zero-ary"]{零列的表}

先从最简单的表开始。@xref["05:relation"]{「关系」}数过，零列的表只有两张，@math{{()}} 与 @math{{}}，对应两个零参@tech{谓词} @racket[(λ () #t)] 与 @racket[(λ () #f)]。照集合语言写成竖线两边的形式，左边是空元组 @math{()}，右边分别是恒真条件 @math{⊤} 与恒假条件 @math{⊥}：

@mm{{() | ⊤} = {()} @hspace[4] {() | ⊥} = {}}

用上一节刚写出的 @racket[predicate->relation] 把它们包装成零元@tech{关系}，再无参调用一次，就得到两个@tech{目标}。把 @racket[predicate->relation] 与 @racket[check] 的定义展开，看看这两个@tech{目标}到底是什么。先看 @racket[(λ () #t)]：

@racketblock[
  ((predicate->relation (λ () #t)))
= (λ (s) (check (apply (λ () #t) '())) s)
= (λ (s) (check #t) s)
= (λ (s) (unless #t (amb)) s)
= (λ (s) s)]

再看 @racket[(λ () #f)]：

@racketblock[
  ((predicate->relation (λ () #f)))
= (λ (s) (check (apply (λ () #f) '())) s)
= (λ (s) (check #f) s)
= (λ (s) (unless #f (amb)) s)
= (λ (s) (amb) s)
= (λ (s) (amb))]

最后一步里，@racket[(amb)] 直接放弃当前分支，后面的 @racket[s] 永远走不到，所以它与 @racket[(λ (s) (amb))] 行为相同。作为@tech{代换}之间的@tech{二元关系}，前者把任意@tech{代换}原样交回一次，是@defterm[#:en "identity relation"]{恒等关系}，总成立、总是成功，记作 @racket[⊤]；后者一次也不交，是一行也没有的@defterm[#:en "empty relation"]{空关系}，总不成立、总是失败，记作 @racket[⊥]：

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
(define pick-a (match-λ [(list l   h) (list (between l h)   h)]))
(define pick-b (match-λ [(list a   h) (list a (between a h) h)]))
(struct var ([name : Symbol]) #:type-name Var #:transparent)
(define (value-of t s)
  (cond [(not (var? t)) t]
        [(assq t s) => cdr]
        [else (error 'value-of "~a 的值还不知道" (var-name t))]))
(define (∧ . g*) (apply ∘ℬ (reverse g*)))
(define (((function->relation f) . t*) s)
  (define-values (in* out*) (split-at-right t* 1))
  (cons (cons (car out*) (apply f (for/list ([t in*]) (value-of t s)))) s))
(define (((predicate->relation p?) . t*) s)
  (check (apply p? (for/list ([t t*]) (value-of t s))))
  s)
(define-syntax-rule (run* (x ...) g)
  (let ([x (var 'x)] ...)
    (in-amb
     (let ([s (g '())])
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

@bold{练习}：上面的 @racket[∘ᵒ] 一次只接两个@tech{关系}。把它扩充成可以接收一个或多个@tech{二元关系}的版本：只给一个时原样交出，给多个时从右往左依次用二元复合接起来（@xref["05:appendix"]{附录}里收有完整定义）。

到这里，复合的写法有了三种。@xref["05:compose-l"]{「列表箭头的复合」}并排写过两行，这里添上第三行：

@racketblock[
(let*      ([y (f x)] [z (g y)]) z)  =  ((∘ℬ g f) x)
(for*/list ([y (f x)] [z (g y)]) z)  =  ((∘ℒ g f) x)
(∃ (y) (∧ (Pᵒ x y) (Qᵒ y z)))        =  ((∘ᵒ Qᵒ Pᵒ) x z)]

第一行每走通一次交出一个 @racket[z]，第二行把这些 @racket[z] 收成一张列表，第三行的 @racket[x] 与 @racket[z] 都是@tech{关系}的位置，调用交出的是@tech{目标}。三种都是复合，中间的 @racket[y] 在前两行由绑定命名，在第三行由 @racket[∃] 造出。

有了复合，自然要问它的@tech{单位}。@xref["05:compose"]{「二元关系的复合」}里，这张@tech{单位}表已经有了两种现成的宿主写法：恒等函数 @racket[id] 与二元@tech{谓词} @racket[equal?]。把它们翻进关系语言，手头的两个包装够不够用？

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

这一次干脆两边都必须先知道，哪一头换成@tech{未知项}都会报错。毛病出在同一处：两个包装都先用 @racket[value-of] 读出宿主要用的参数，借来的函数与@tech{谓词}骨子里只能算已经知道的值。同样的限制也挡在把 @racket[pythᵒ] 挪到 @racket[right-triangles] 最前面、或者倒过来问边界的时候。无论借函数还是借@tech{谓词}，都造不出真正对称的@tech{单位}：两个位置相等，两边都可以暂时不知道，这得在关系语言里自己做。

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
(define (value-of t s)
  (cond [(not (var? t)) t]
        [(assq t s) => cdr]
        [else (error 'value-of "~a 的值还不知道" (var-name t))]))
(define (⊤ s) s)
(define (⊥ s) (amb))
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

表记下来了，值却读不对。@racket[x] 对着 @racket[y]，@racket[value-of] 只查了一次，交出的是一个@tech{未知项}；可 @racket[y] 的值，表里明明有。值可以是另一个@tech{未知项}的时候，查表要顺着查下去，查到一个不在表里的项为止：

@examples[#:eval ev-unify #:no-result
(: walk (→ Term Substitution Term))
(define (walk t s)
  (define p (and (var? t) (assq t s)))
  (if p (walk (cdr p) s) t))]

用刚才那张@tech{代换}试一试：

@examples[#:eval ev-unify #:label #f
(walk x s)]

添一行也不能照旧了。比如表里已经记着 @racket[x] 等于 5，再来一行等式说 @racket[x] 等于 6，直接添上，@racket[x] 就占了两行；等式要是写成 6 等于 @racket[x]，键还成了一个数。添之前，两边都要先顺着表查到底，再对称地比：有一边是@tech{未知项}，就添上一行；两边都是序对，逐个去对；否则相等才走得通：

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

头一例两边都不知道，添的一行记着 @racket[x] 等于 @racket[y]。第二例是两张各缺一个元素的列表，逐个去对，@racket[a] 对上 1，@racket[b] 对上 2：两边都从对面得到了自己缺的那个值。第三例里 @racket[x] 查到 5，与 6 对不上，这条时间线走不通，@racket[in-amb] 一张@tech{代换}也没有收到。

让两个项相等，必要时往@tech{代换}里添一行，这件事叫@defterm[#:en "unification"]{合一}。添的总是一个还没在表里的@tech{未知项}，所以键不会重复。@tech{代换}也跟着变了样：一行记的不再是某个@tech{未知项}的值，而是一条等式。

把@tech{合一}本身做成一个@tech{关系}：@racket[(≡ u v)] 说的是两个项相等，交出的@tech{目标}让它们@tech{合一}。

@examples[#:eval ev-unify #:no-result
(: ≡ (→ Term Term Goal))
(define ((≡ u v) s) (unify u v s))]

@racket[value-of] 也改成顺着查，遇到序对就两边各读；走到头还剩@tech{未知项}就报错，所以它交出的都是不含@tech{未知项}的 @racket[Data]：

@examples[#:eval ev-unify #:no-result
(: value-of (→ Term Substitution Data))
(define (value-of t s)
  (let ([t (walk t s)])
    (cond [(var? t) (error 'value-of "~a 的值还不知道" (var-name t))]
          [(pair? t) (cons (value-of (car t) s) (value-of (cdr t) s))]
          [else t])))]

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

把相等接在 @racket[Pᵒ] 的后面，条件是「存在 @racket[y]，@racket[(Pᵒ x y)] 成立，而且 @racket[y] 等于 @racket[z]」，遮掉中间一列恰好就是 @racket[(Pᵒ x z)]；接在前面同理。只看外面两列允许哪些取值，@racket[≡] 就是@tech{二元关系}复合的@tech{单位}。实际求解还要照书写顺序运行，借来的@tech{谓词}仍然要求参数先有值。

顺手回头修好 @racket[function->relation]：它原先默认最后一个位置永远是还没值的@tech{未知项}，直接往@tech{代换}里添一行。要是同一个@tech{未知项}出现在两行的最后一列，比如找同时在 1 到 2 之间、又在 2 到 3 之间的数，或者干脆在最后一列填进一个已知的数，直接添一行就坏了：

@examples[#:eval ev-unify #:hidden
(define (((function->relation f) . t*) s)
  (define-values (in* out*) (split-at-right t* 1))
  (cons (cons (car out*) (apply f (for/list ([t in*]) (value-of t s)))) s))
(define betweenᵒ (function->relation between))]
@examples[#:eval ev-unify #:label #f
(run* (a) (∧ (betweenᵒ 1 2 a) (betweenᵒ 2 3 a)))
(in-amb ((betweenᵒ 1 3 2) '()))]

头一例里 3 明明不在 1 到 2 之间，却跟着出来了，2 还出了两次：第二行直接把新的一行盖在了前面。第二例更怪，@tech{代换}的键成了数 2。现在把直接添一行换成与函数交出的值@tech{合一}：没有值就添一行，有值就成了核对。

@examples[#:eval ev-unify #:no-result
(: function->relation (∀ (a ... b) (→ (→ℬ a ... b) (→ Term ... Term Goal))))
(define (((function->relation f) . t*) s)
  (define-values (in* out*) (split-at-right t* 1))
  (unify (car out*) (apply f (for/list ([t in*]) (value-of t s))) s))]

两例立刻都走得通了：

@examples[#:eval ev-unify #:hidden
(define betweenᵒ (function->relation between))]
@examples[#:eval ev-unify #:label #f
(run* (a) (∧ (betweenᵒ 1 2 a) (betweenᵒ 2 3 a)))
(run* () (betweenᵒ 1 3 2))
(run* () (betweenᵒ 1 3 5))]

@section[#:tag "05:equation"]{把两种情形并起来}

有了 @racket[≡]、@racket[∧] 和 @racket[∃]，不借函数和@tech{谓词}，能不能直接写出一个递归的@tech{关系}？

@racket[append] 把两张列表接成一张。它是函数，只能从左边两张算出右边一张。照它的定义写一个三个位置的@tech{关系} @racket[(appendᵒ l t out)]：@racket[l] 是空的，@racket[out] 就等于 @racket[t]；或者 @racket[l] 有头一个元素 @racket[a] 和剩下的 @racket[d]，@racket[out] 的头一个元素也是 @racket[a]，剩下的部分 @racket[res] 是 @racket[d] 接上 @racket[t]。

这里有两种情形，只要有一种成立就算走通。每条支路都从收到的那张@tech{代换}出发，@racket[list->amb] 会让每个@tech{目标}各运行一次；只看能走通的@tech{代换}对，就是把各@tech{目标}的表并起来（@xref["05:compose"]{「二元关系的复合」}里的取并随 @math{P(x)} 产生的中间值一份份地并，这里两份@tech{目标}已经写在眼前）。几个条件里只要有一个成立，叫@tech{析取}，照集合语言里的记号写成 @racket[∨]：

@margin-note{@tech{目标}写成 ℒ 的箭头时，@tech{析取}是把几张@tech{代换}的列表接起来。}

@examples[#:eval ev-unify #:no-result
(: ∨ (→ Goal ... Goal))
(define ((∨ . g*) s) ((list->amb g*) s))]

两种情形用 @racket[∨] 并起来，每种情形里的几条等式用 @racket[∧] 连起来，中间用到的@tech{未知项} @racket[a]、@racket[d]、@racket[res] 用 @racket[∃] 造出。@racket[appendᵒ] 照上面那句话逐字写下来：

@examples[#:eval ev-unify #:no-result
(define (appendᵒ l t out)
  (∨ (∧ (≡ l '()) (≡ t out))
     (∃ (a d res)
       (∧ (≡ l (cons a d))
          (≡ out (cons a res))
          (appendᵒ d t res)))))]

@racket[appendᵒ] 在第二支里调用自己。要是 @racket[∃] 一上来就运行里面的条件，构造@tech{目标}时就会一层层调用下去，停不下来；等到收到@tech{代换}才运行，正向的例子每层消耗左表的一个 @racket[cons]，反向的例子每层消耗结果表的一个 @racket[cons]，列表有限，递归就会停下。

正着问，它和 @racket[append] 一样：

@examples[#:eval ev-unify #:label #f
(run* (z) (appendᵒ '(1 2) '(3) z))]

反过来，给出接好的那一张，问前两个位置：

@examples[#:eval ev-unify #:label #f
(run* (x y) (appendᵒ x y '(1 2 3)))]

@margin-note{如果答案里还留着未绑定的@tech{未知项}（比如 @racket[(run* (x y) (≡ x y))] 或 @racket[(run* (x y) (appendᵒ '(1) x y))]），@racket[value-of] 读不出来；另外，像 @racket[(≡ x (cons 1 x))] 这样的循环等式也需要在添等式前拦截。@xref["05:appendix"]{附录}的完整库代码补上了这两步：用 @racket[walk*] 与 @racket[reify] 把未绑定@tech{未知项}打印成 @tt{_.0}、@tt{_.1}，并用 @racket[occurs?] 与 @racket[ext-s] 做循环检查。}

四种拆法都找到了。定义 @racket[appendᵒ] 的时候，没有哪一行写过「拆」：每一行都是等式，没有哪个位置是输入，哪个是输出。这是@tech{关系}不分输入输出的样子。

到这里，把条件接起来的 @racket[∧] 和把支路并起来的 @racket[∨] 都用上了。回头看它们的零参边界，会正好撞上本节开头由零列的表翻出来的那两个@tech{目标}：@racket[(∧)] 一步也不接，把原@tech{代换}原样交回一次，正是 @racket[⊤]，前后接上它，原@tech{目标}照走；@racket[(∨)] 造出一个没有支路可试的@tech{目标}，收到@tech{代换}后执行 @racket[(amb)]，一张也不交，正是 @racket[⊥]，在任一侧并上它，答案列表照旧。

于是这门语言里的三种运算和它们的@tech{单位}都齐了：在@tech{代换}层，@tech{合取} @racket[∧] 的@tech{单位}是 @racket[⊤]，@tech{析取} @racket[∨] 的@tech{单位}是 @racket[⊥]；在@tech{关系}层，按外面两列的解看，@tech{二元关系}复合 @racket[∘ᵒ] 的@tech{单位}正是@tech{合一} @racket[≡]（@tech{合一}可能往@tech{代换}里添等式，@racket[⊤] 总是原样交回）。

我们为了把@tech{关系}直接写下来，一步步添上了 @racket[≡]、@racket[∧]、@racket[∨]、@racket[∃] 和两个@tech{单位} @racket[⊤]、@racket[⊥]。整个语言只有这六样，实现不到一百行，它的骨架正是 microKanren，@defterm[#:en "relational programming"]{关系式编程}（@defterm[#:en "logic programming"]{逻辑式编程}的一个分支）语言 miniKanren 的极小内核。

@margin-note{和常见的实现相比，还有几处不同：@tech{未知项}按身份区分，不编号；@tech{合取}是直接复合，何时推迟一步计算、怎样取用答案，写法也不一样，交出答案的顺序因此可能不同。}

在那里，@tech{未知项}叫@defterm[#:en "logic variable"]{逻辑变量}，这六个记号常写作 @racket[==]、@racket[conj]、@racket[disj]、@racket[fresh]、@racket[succeed]、@racket[fail]，@racket[run*] 与 @racket[fresh] 也常添上一层语法糖，把多条@tech{目标}自动包进 @racket[conj]。常见的实现用流来@tech{回溯}，@tech{目标}交出一串@tech{代换}，@tech{合取}与@tech{析取}都要自己写出怎样接、怎样并。这里用 @racket[amb] @tech{回溯}，@racket[∧] 就是 ℬ 的复合，@racket[∨] 就是 @racket[amb]，这两样都是现成的；剩下要写的，主要是@tech{合一}。
