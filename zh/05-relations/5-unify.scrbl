#lang acf/scribble

@title[#:tag "05:5-unify"]{复合与合一}

在函数世界里，把两步接起来用 @racket[∘]；带 @racket[amb] 的函数和交出列表的函数，也各自有了 @racket[∘ℬ] 与 @racket[∘ℒ]。换到刚造出的关系语言，两个二元关系怎样复合？

@section[#:tag "05:compose-o"]{在关系语言里复合}

@xref["05:compose"]{「二元关系的复合」}里，四步都是带 @racket[amb] 的函数，用 @racket[∘] 就接成了 @racket[right-triangle]。关系语言里的关系不是函数：@racket[(Pᵒ x y)] 交出的是目标，@racket[x] 与 @racket[y] 只是两个位置，@racket[∘] 接不上。

@xref["05:compose"]{「二元关系的复合」}用集合的语言写过二元关系的复合：@math{(x, z)} 在 @math{Q ∘ P} 里，当且仅当存在这样的 @math{y}，@math{(x, y)} 在 @math{P} 里，并且 @math{(y, z)} 在 @math{Q} 里。

如果只用@tech{谓词}（也就是@tech{特征函数}）来表示二元关系，照这句话去复合两个二元谓词 @racket[P?] 与 @racket[Q?]，会直接卡在「存在这样的 @math{y}」上：@racket[P?] 与 @racket[Q?] 只负责检查给定的一对值在不在关系里，只给 @racket[P?] 与 @racket[Q?]，能检查一个给定的 @math{y}，却没有一般办法找出这样的 @math{y}，或判定一个也没有。

换到刚造出的关系语言，「并且」已经是 @racket[∧]，只差「存在这样的 @math{y}」。@racket[run*] 会在查询开头造出未知项；复合两个关系时，也需要一个只在里面用到的中间未知项：

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
(define pick-c (match-λ [(list a b h) (list a b (between b h))]))
(define (check-right t) (check (apply pyth? t)) t)
(struct var ([name : Symbol]) #:type-name Var #:transparent)
(define (value-of t s)
  (cond [(not (var? t)) t]
        [(assq t s) => cdr]
        [else (error 'value-of "~a 的值还不知道" (var-name t))]))
(define (⊤ s) s)
(define (⊥ s) (amb))
(define (∧ . g*) (apply ∘ℬ (reverse g*)))
(define ((∨ . g*) s) ((list->amb g*) s))
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
(define-syntax-rule (∃ (x ...) g)
  (λ (s) (let ([x (var 'x)] ...) (g s))))]

@racket[∃] 交出的也是目标。它等收到代换时才造未知项，再运行里面的条件：每用一次，造出的都是新的。集合里的那句话于是可以逐字翻译过来：

@racketblock[
(∃ (y)
  (∧ (Pᵒ x y)
     (Qᵒ y z)))]

「存在这样的 @math{y}」就是 @racket[∃]，未知项 @racket[y] 替我们占住中间那一列，用不着穷举全集；「并且」就是 @racket[∧]。在代换层，@racket[∧] 是目标的复合 @racket[∘ℬ]；在答案表上，@racket[∧] 把两张表按共有的列拼起来，中间的 @racket[y] 就是两张表首尾相连时的那一列，@racket[run*] 只读出 @racket[x] 与 @racket[z]，中间那一列被遮住了。

把两个关系的复合写成函数 @racket[∘ᵒ]：

@examples[#:eval ev-comp #:no-result
(: ∘ᵒ (→ (→ Term Term Goal) (→ Term Term Goal) (→ Term Term Goal)))
(define ((∘ᵒ Qᵒ Pᵒ) x z)
  (∃ (y) (∧ (Pᵒ x y) (Qᵒ y z))))]

@defsym["Qᵒ ∘ᵒ Pᵒ" "关系语言里的复合：∃ 造出中间的未知项"]@racket[∘ᵒ] 和 @racket[∘] 一样从右往左写：两个关系复合时，中间的 @racket[y] 把它们连起来，右边的关系说 @racket[x] 与 @racket[y]，左边的说 @racket[y] 与 @racket[z]。

@bold{练习}：上面的 @racket[∘ᵒ] 一次只接两个关系。把它扩充成可以接收一个或多个二元关系的版本：只给一个时原样交出，给多个时从右往左依次用二元复合接起来。后面的代码直接用这个多参数版本（@xref["05:appendix"]{附录}里收有完整定义）。

@examples[#:eval ev-comp #:hidden
(define ∘ᵒ
  (case-λ
    [(Pᵒ) Pᵒ]
    [(Qᵒ . Pᵒ*)
     (define Pᵒ (apply ∘ᵒ Pᵒ*))
     (λ (x z) (∃ (y) (∧ (Pᵒ x y) (Qᵒ y z))))]))]
拿 @racket[right-triangle] 的四步试一试。四步都是带 @racket[amb] 的函数，用 @racket[function->relation] 各搬成一个关系，再用 @racket[∘ᵒ] 接起来：

@examples[#:eval ev-comp #:no-result
(define pick-aᵒ      (function->relation pick-a))
(define pick-bᵒ      (function->relation pick-b))
(define pick-cᵒ      (function->relation pick-c))
(define check-rightᵒ (function->relation check-right))
(define right-triangleᵒ
  (∘ᵒ check-rightᵒ pick-cᵒ pick-bᵒ pick-aᵒ))]

从 1 到 20 跑一遍：

@examples[#:eval ev-comp #:label #f
(run* (t) (right-triangleᵒ '(1 20) t))]

@margin-note{每组外面多了一层括号：@racket[run*] 只读了一个未知项 @racket[t]，一组答案是只有一项的列表。}

还是那六组。@racket[pick-a] 里面用了 @racket[amb]，@racket[function->relation] 照样把它搬过来：它交出几个值，目标就交出几张代换。

接四步的写法，到这里有了三种。@xref["05:two-ways"]{「关系的两种写法」}末尾并排了两行，这里添上第三行：

@racketblock[
(let*      ([y (f x)] [z (g y)]) z)  =  ((∘ℬ g f) x)
(for*/list ([y (f x)] [z (g y)]) z)  =  ((∘ℒ g f) x)
(∃ (y) (∧ (Pᵒ x y) (Qᵒ y z)))        =  ((∘ᵒ Qᵒ Pᵒ) x z)]

第一行每走通一次交出一个 @racket[z]，第二行把这些 @racket[z] 收成一张列表。第三行的 @racket[x] 与 @racket[z] 都是关系的位置，调用交出的是目标。三种都是复合，中间结果 @racket[y] 在前两行由绑定命名，在第三行由 @racket[∃] 造出。

有了复合，自然要问：@racket[∘ᵒ] 的单位是什么？函数的复合 @racket[∘] 有恒等函数 @racket[id]，@racket[∘ℒ] 有 @racket[(λ (x) (list x))]。作为二元关系，复合的单位说的是两个位置完全一样：无论接在哪个二元关系的左边还是右边，都不改变原来的关系。

手头已经有了 @racket[function->relation] 和 @racket[predicate->relation]，不妨各试一次。从函数的角度看，输入和输出完全一样的函数正是 @racket[id]，把它搬成关系：

@examples[#:eval ev-comp #:label #f
(define idᵒ (function->relation id))
(run* (y) (idᵒ 5 y))
(eval:error (run* (x) (idᵒ x 5)))]

左边已知、右边留给它填写时行得通，右边已知、左边未知就报错。哪怕写成两条简单的等式，@racket[x] 等于 @racket[y]、@racket[y] 等于 5，它也走不下去：

@examples[#:eval ev-comp #:label #f
(eval:error (run* (x y) (∧ (idᵒ x y) (idᵒ y 5))))]

@racket[idᵒ] 要先读出 @racket[x] 的值，可 @racket[x] 的值要等第二行才定下来。

再换从谓词的角度看：两个位置完全一样，对应的二元谓词是 @racket[equal?]。用 @racket[predicate->relation] 把它搬成关系：

@examples[#:eval ev-comp #:label #f
(define equalᵒ (predicate->relation equal?))
(run* () (equalᵒ 5 5))
(eval:error (run* (y) (equalᵒ 5 y)))
(eval:error (run* (x) (equalᵒ x 5)))]

这一次两边都必须先知道，哪一头换成未知项都会报错。毛病出在同一处：两个包装都先用 @racket[value-of] 读出宿主要用的参数，借来的函数与谓词骨子里仍然分输入和输出，只能算已经知道的值。@racket[id] 要读左边，@racket[equal?] 要读两边；同样的限制也挡在倒问 @racket[right-triangleᵒ] 面前：

@examples[#:eval ev-comp #:label #f
(eval:error (run* (b) (right-triangleᵒ b '(3 4 5))))]

把 @racket[pythᵒ] 挪到 @racket[right-triangles] 的最前面，也会在 @racket[value-of] 处报一样的错。无论借函数还是借谓词，都造不出真正对称的单位。关系复合的单位说的是两个位置相等，两边都可以暂时不知道，这没法借来，得在关系语言里自己做。

@section[#:tag "05:unify-step"]{合一}

不借 @racket[id] 和 @racket[equal?]，照手写 @racket[g] 的办法，直接把这两行等式记进表里：@racket[x] 等于 @racket[y]，@racket[y] 等于 5。然后问 @racket[x] 的值：

@(define ev-unify (make-acf-eval))
@examples[#:eval ev-unify #:hidden
(require racket/control)
(define ∘ compose)
(define (choose p*) (shift k (append-map k p*)))
(define-syntax-rule (amb e ...) ((choose (list (λ () e) ...))))
(define-syntax-rule (for/amb clauses body ...) ((choose (for/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))
(define (between lo hi) (for/amb ([n (inclusive-range lo hi)]) n))
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
(define ((∨ . g*) s) ((list->amb g*) s))
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

表记下来了，值却读不对。@racket[x] 对着 @racket[y]，@racket[value-of] 只查了一次，交出的是一个未知项；可 @racket[y] 的值，表里明明有。值可以是另一个未知项的时候，查表要顺着查下去，查到一个不在表里的项为止：

@examples[#:eval ev-unify #:no-result
(: walk (→ Term Substitution Term))
(define (walk t s)
  (define p (and (var? t) (assq t s)))
  (if p (walk (cdr p) s) t))]

用刚才那张代换试一试：

@examples[#:eval ev-unify #:label #f
(walk x s)]

添一行也不能照旧了。比如表里已经记着 @racket[x] 等于 5，再来一行等式说 @racket[x] 等于 6，直接添上，@racket[x] 就占了两行；等式要是写成 6 等于 @racket[x]，键还成了一个数。添之前，两边都要先顺着表查到底，再对称地比：有一边是未知项，就添上一行；两边都是序对，逐项去对；否则相等才走得通：

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

头一例两边都不知道，添的一行记着 @racket[x] 等于 @racket[y]。第二例是两张各缺一项的列表，逐项去对，@racket[a] 对上 1，@racket[b] 对上 2：两边都从对面得到了自己缺的那一项。第三例里 @racket[x] 查到 5，与 6 对不上，这条时间线走不通，@racket[in-amb] 一张代换也没有收到。

让两个项相等，必要时往代换里添一行，这件事叫@defterm[#:en "unification"]{合一}。添的总是一个还没在表里的未知项，所以键不会重复。代换也跟着变了样：一行记的不再是某个未知项的值，而是一条等式。

把合一本身做成一个关系：@racket[(≡ u v)] 说的是两个项相等，交出的目标让它们合一。

@examples[#:eval ev-unify #:no-result
(: ≡ (→ Term Term Goal))
(define ((≡ u v) s) (unify u v s))]

@racket[value-of] 也改成顺着查，项是序对就逐项读；走到头还剩未知项就报错，所以它交出的都是不含未知项的 @racket[Data]：

@examples[#:eval ev-unify #:no-result
(: value-of (→ Term Substitution Data))
(define (value-of t s)
  (let ([t (walk t s)])
    (cond [(var? t) (error 'value-of "~a 的值还不知道" (var-name t))]
          [(pair? t) (cons (value-of (car t) s) (value-of (cdr t) s))]
          [else t])))]

用 @racket[≡] 和 @racket[run*] 试一试：

@examples[#:eval ev-unify #:label #f
(run* (x y) (∧ (≡ x y) (≡ y 5)))
(run* (x y) (∧ (≡ x 1) (≡ 2 y)))
(run* (x) (∧ (≡ x 5) (≡ 6 x)))]

未知项写在等式的哪一边都可以，两边都是未知项也可以。@racket[∘ᵒ] 一直在找的单位，正是合一 @racket[≡] 本身：

@examples[#:eval ev-unify #:no-result
(: idᵒ (→ Term Term Goal))
(define idᵒ ≡)]

无论哪边是未知项，它都能接得住：

@examples[#:eval ev-unify #:label #f
(run* (q) (idᵒ q 5))
(run* (q) (idᵒ 5 q))]

把相等接在 @racket[Pᵒ] 的后面，条件是「存在 @racket[y]，@racket[(Pᵒ x y)] 成立，而且 @racket[y] 等于 @racket[z]」；这恰好就是 @racket[(Pᵒ x z)]。接在前面同理，「存在 @racket[y]，@racket[x] 等于 @racket[y]，而且 @racket[(Pᵒ y z)] 成立」也恰好是 @racket[(Pᵒ x z)]。只看外面两列允许哪些取值，@racket[≡] 就是二元关系复合的单位。实际求解还要照书写顺序运行，借来的谓词仍然要求参数先有值。

顺手回头看 @racket[function->relation]：它原先默认最后一个位置永远是还没值的未知项，直接往代换里添一行。要是同一个未知项出现在两行的最后一列，比如找同时在 1 到 2 之间、又在 2 到 3 之间的数，或者干脆在最后一列填进一个已知的数，直接添一行就坏了：

@examples[#:eval ev-unify #:hidden
(define (((function->relation f) . t*) s)
  (define-values (in* out*) (split-at-right t* 1))
  (cons (cons (car out*) (apply f (for/list ([t in*]) (value-of t s)))) s))
(define betweenᵒ (function->relation between))]
@examples[#:eval ev-unify #:label #f
(run* (a) (∧ (betweenᵒ 1 2 a) (betweenᵒ 2 3 a)))
(in-amb ((betweenᵒ 1 3 2) '()))]

头一例里 3 明明不在 1 到 2 之间，却跟着出来了，2 还出了两次：第二行直接把新的一行盖在了前面。第二例更怪，代换的键成了数 2。现在把直接添一行换成与函数交出的值合一：没有值就添一行，有值就成了核对。

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

@section[#:tag "05:equation"]{直接写等式}

有了 @racket[≡]、@racket[∧]、@racket[∨]、@racket[∃] 和两个单位 @racket[⊤]、@racket[⊥]，关系语言已经能写等式、接条件、并分支、复合关系。只靠这些，不借函数和谓词，能不能直接写出一个递归的关系？

@racket[append] 把两张列表接成一张。它是函数，只能从左边两张算出右边一张。照它的定义写一个三个位置的关系 @racket[(appendᵒ l t out)]：@racket[l] 是空的，@racket[out] 就等于 @racket[t]；或者 @racket[l] 有头一项 @racket[a] 和剩下的 @racket[d]，@racket[out] 的头一项也是 @racket[a]，剩下的部分 @racket[res] 是 @racket[d] 接上 @racket[t]。

两种情形用 @racket[∨] 并起来，每种情形里的几条等式用 @racket[∧] 连起来，中间用到的未知项 @racket[a]、@racket[d]、@racket[res] 用 @racket[∃] 造出。@racket[appendᵒ] 照上面那句话逐字写下来：

@examples[#:eval ev-unify #:no-result
(define (appendᵒ l t out)
  (∨ (∧ (≡ l '()) (≡ t out))
     (∃ (a d res)
       (∧ (≡ l (cons a d))
          (≡ out (cons a res))
          (appendᵒ d t res)))))]

@racket[appendᵒ] 在第二支里调用自己。要是 @racket[∃] 一上来就运行里面的条件，构造目标时就会一层层调用下去，停不下来；等到收到代换才运行，正向的例子每层消耗左表的一个 @racket[cons]，反向的例子每层消耗结果表的一个 @racket[cons]，列表有限，递归就会停下。

正着问，它和 @racket[append] 一样：

@examples[#:eval ev-unify #:label #f
(run* (z) (appendᵒ '(1 2) '(3) z))]

反过来，给出接好的那一张，问前两个位置：

@examples[#:eval ev-unify #:label #f
(run* (x y) (appendᵒ x y '(1 2 3)))]

四种拆法都找到了。定义 @racket[appendᵒ] 的时候，没有哪一行写过「拆」：每一行都是等式，没有哪个位置是输入，哪个是输出。这是关系不分输入输出的样子。

@margin-note{如果答案里还留着未绑定的未知项（比如 @racket[(run* (x y) (≡ x y))] 或 @racket[(run* (x y) (appendᵒ '(1) x y))]），@racket[value-of] 读不出来；另外，像 @racket[(≡ x (cons 1 x))] 这样的循环等式也需要在添等式前拦截。@xref["05:appendix"]{附录}的完整库代码补上了这两步：用 @racket[walk*] 与 @racket[reify] 把未绑定未知项打印成 @tt{_.0}、@tt{_.1}，并用 @racket[occurs?] 与 @racket[ext-s] 做循环检查。}

到这里，这门语言里的三种运算和它们的单位都齐了：在代换层，合取 @racket[∧] 的单位是 @racket[⊤]，析取 @racket[∨] 的单位是 @racket[⊥]；在关系层，按外面两列的解看，二元关系复合 @racket[∘ᵒ] 的单位正是合一 @racket[≡]。

@margin-note{和常见的实现相比，还有几处不同：未知项按身份区分，不编号；合取是直接复合，何时推迟一步计算、怎样取用答案，写法也不一样，交出答案的顺序因此可能不同。}

我们为了把关系直接写下来，一步步添上了 @racket[≡]、@racket[∧]、@racket[∨]、@racket[∃] 和两个单位 @racket[⊤]、@racket[⊥]。整个语言只有这六样，实现不到一百行，它的骨架正是 microKanren，@defterm[#:en "relational programming"]{关系式编程}（@defterm[#:en "logic programming"]{逻辑式编程}的一个分支）语言 miniKanren 的极小内核。

在那里，未知项叫@defterm[#:en "logic variable"]{逻辑变量}，这六个记号常写作 @racket[==]、@racket[conj]、@racket[disj]、@racket[fresh]、@racket[succeed]、@racket[fail]，@racket[run*] 与 @racket[fresh] 也常添上一层语法糖，把多条目标自动包进 @racket[conj]。常见的实现用流来回溯，目标交出一串代换，合取与析取都要自己写出怎样接、怎样并。这里用 @racket[amb] 回溯，@racket[∧] 就是 ℬ 的复合，@racket[∨] 就是 @racket[amb]，这两样都是现成的；剩下要写的，主要是合一。
