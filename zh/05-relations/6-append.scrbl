#lang acf/scribble

@title[#:tag "05:6-append"]{把两种情形并起来}

前面借来的 @racket[betweenᵒ] 和 @racket[pythᵒ] 都靠宿主函数算出值来，只能顺着输入算输出。现在手里已经有了 @racket[≡]、@racket[∧]、@racket[∨] 和 @racket[∃]。如果只用关系语言本身，不用宿主函数，能写出什么？

@section[#:tag "05:equation"]{用关系写出 appendᵒ}

看看这一章在 @racket[append-map] 里反复用到的列表拼接函数 @racket[append]：它只拆装空表与 @racket[cons]，却因为写成函数，只能把左边两张列表接成右边一张，答不出「哪两张列表接起来是 @racket['(1 2 3)]」。把 @racket[append] 的两种情形写成关系：

@itemlist[
@item{@racket[l] 是空的，@racket[out] 就等于 @racket[t]；}
@item{@racket[l] 有头一个元素 @racket[a] 和剩下的 @racket[d]，@racket[out] 的头一个元素也是 @racket[a]，剩下的部分 @racket[res] 是 @racket[d] 接上 @racket[t]。}]

一落笔就碰到一个新情况：第二条要写 @racket[(≡ l (cons a d))]，@tech{未知项} @racket[a] 和 @racket[d] 藏在了序对里面。前面的 @racket[Term] 是 @racket[(∪ Data Var)]，一个@tech{项}要么是完整的 @racket[Data]，要么是单个@tech{未知项}，装不下带@tech{未知项}的序对。先把 @racket[Term] 扩成允许序对内部也放@tech{项}的递归类型：

@(define ev-append (make-acf-eval))
@examples[#:eval ev-append #:hidden
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
(define-type Literal (∪ Boolean Number Char Bytes String Keyword Null Symbol))
(define-type Data (∪ Literal (Pair Data Data)))
(define (var=? u v) (eq? u v))
(define empty-s '())
(define (size-s s) (length s))
(define (ext-s x t s) (cons (cons x t) s))
(define (walk t s)
  (define p (and (var? t) (assq t s)))
  (if p (walk (cdr p) s) t))
(define (unify u v s)
  (let ([u (walk u s)] [v (walk v s)])
    (cond
      [(and (var? u) (var? v) (var=? u v)) s]
      [(var? u) (ext-s u v s)]
      [(var? v) (ext-s v u s)]
      [(equal? u v) s]
      [else (amb)])))
(define (value-of t s)
  (let ([t (walk t s)])
    (if (var? t)
        (error 'value-of "~a 的值还不知道" (var-name t))
        t)))
(define (⊤ s) s)
(define (⊥ s) (amb))
(define ((∨ . g*) s) ((list->amb g*) s))
(define (∧ . g*) (apply ∘ℬ (reverse g*)))
(define-syntax-rule (∃ (x ...) g)
  (λ (s) (let ([x (var 'x)] ...) (g s))))
(define ((≡ u v) s) (unify u v s))
(define-syntax-rule (run* (x ...) g)
  (let ([x (var 'x)] ...)
    (in-amb
     (let ([s (g empty-s)])
       (list (value-of x s) ...)))))]
@examples[#:eval ev-append #:no-result
(define-type Term (∪ Literal Var (Pair Term Term)))]

拿上一节的 @racket[unify] 试着把 @racket['(1 2)] 和 @racket[(cons a d)] @tech{合一}：

@examples[#:eval ev-append #:label #f
(define a (var 'a))
(define b (var 'b))
(define d (var 'd))
(in-amb (unify '(1 2) (cons a d) empty-s))]

一张@tech{代换}也没有。两边最外层都是序对，既不是@tech{未知项}，用 @racket[equal?] 比也不相等，直接落进了失败分支。给 @racket[unify] 补上序对分支，两边都是序对时先@tech{合一} @racket[car]，再用得到的@tech{代换}去@tech{合一} @racket[cdr]：

@examples[#:eval ev-append #:no-result
(: unify (→ Term Term Substitution Substitution))
(define (unify u v s)
  (let ([u (walk u s)] [v (walk v s)])
    (cond
      [(and (var? u) (var? v) (var=? u v)) s]
      [(var? u) (ext-s u v s)]
      [(var? v) (ext-s v u s)]
      [(and (pair? u) (pair? v))
       (unify (cdr u) (cdr v) (unify (car u) (car v) s))]
      [(equal? u v) s]
      [else (amb)])))]

再试一次，顺带拿两张各缺一个元素的列表试一试：

@examples[#:eval ev-append #:label #f
(in-amb (unify '(1 2) (cons a d) empty-s))
(in-amb (unify (list a 2) (list 1 b) empty-s))]

第二例里两张列表逐个去对，@racket[a] 对上 1，@racket[b] 对上 2：两边都从对面得到了自己缺的那个值。把它和前面用过的 @racket[match-λ] 对照：那里用一个带空位的模式去匹配给定的值；这里两边都能留空位，任一边遇到还没绑定的@tech{未知项}，都用 @racket[ext-s] 把它和对面那一项记成等式，相当于双向的模式匹配。

现在把 @racket[append] 的两种情形用 @racket[∨] 并起来，每种情形里的几条等式用 @racket[∧] 连起来，中间用到的@tech{未知项} @racket[a]、@racket[d]、@racket[res] 用 @racket[∃] 造出，就得到三个位置的@tech{关系} @racket[appendᵒ]：

@examples[#:eval ev-append #:no-result
(define (appendᵒ l t out)
  (∨ (∧ (≡ l '()) (≡ t out))
     (∃ (a d res)
       (∧ (≡ l (cons a d))
          (≡ out (cons a res))
          (appendᵒ d t res)))))]

@racket[appendᵒ] 在第二支里调用自己。要是 @racket[∃] 一上来就运行里面的条件，构造@tech{目标}时就会一层层调用下去，停不下来；等到收到@tech{代换}才运行，正向的例子每层消耗左表的一个 @racket[cons]，反向的例子每层消耗结果表的一个 @racket[cons]，列表有限，递归就会停下。

正着问一下：

@examples[#:eval ev-append #:label #f
(run* (z) (appendᵒ '(1 2) '(3) z))]

@racket[z] 最外层已经是一个序对，可里面装的仍是求解途中造出的@tech{未知项} @racket[a] 与 @racket[res]：上一节的 @racket[value-of] 只查最外层，进不到序对里面。@racket[Term] 扩成递归类型后，@racket[value-of] 也要跟着往序对里面读；走到头还剩@tech{未知项}才报错，这样交出的仍然是完整的 @racket[Data]：

@examples[#:eval ev-append #:no-result
(: value-of (→ Term Substitution Data))
(define (value-of t s)
  (let ([t (walk t s)])
    (cond
      [(var? t) (error 'value-of "~a 的值还不知道" (var-name t))]
      [(pair? t) (cons (value-of (car t) s) (value-of (cdr t) s))]
      [else t])))]

再正着问，就和 @racket[append] 一样了：

@examples[#:eval ev-append #:label #f
(run* (z) (appendᵒ '(1 2) '(3) z))]

反过来，给出接好的那一张，问前两个位置：

@examples[#:eval ev-append #:label #f
(run* (x y) (appendᵒ x y '(1 2 3)))]

四种拆法都找到了。定义 @racket[appendᵒ] 的时候，没有哪一行写过「拆」：每一行都是等式，没有哪个位置是输入，哪个是输出。这是@tech{关系}不分输入输出的样子。

@section[#:tag "05:reify"]{未定下来的答案}

如果只给左边这一张 @racket['(1)]，另外两个位置能看出什么？用现在的 @racket[run*] 问一下：

@examples[#:eval ev-append #:label #f
(eval:error (run* (x y) (appendᵒ '(1) x y)))]

程序又停在了 @racket[value-of] 那里。@racket[⊥] 一张@tech{代换}也没交出来；这次这一支已经走通了，我们已经有了一张@tech{代换}，知道 @racket[y] 必须等于 @racket[(cons 1 x)]，但 @racket[x] 仍然可以取不同的值。一开始的@tech{谓词}要等一行填好才检查；现在我们虽还没把 @racket[x] 填定，却已经知道 @racket[y] 的尾部就是 @racket[x]，这样的答案也应该读得出来。

之前的 @racket[walk] 顺着@tech{代换}走到头时，遇到未绑定的@tech{未知项}本来就已经原样交回、不再报错；只是序对内部还可能藏着@tech{未知项}。再写一层 @racket[walk*]，顺着@tech{代换}递归展开每个序对，保留还自由的@tech{未知项}：

@examples[#:eval ev-append #:no-result
(: walk* (→ Term Substitution Term))
(define (walk* t s)
  (let ([t (walk t s)])
    (if (pair? t) (cons (walk* (car t) s) (walk* (cdr t) s)) t)))]

@racket[walk*] 会顺着@tech{代换}一直往序对里面展开。要是表里记进一条循环等式，比如 @racket[(≡ x (cons 1 x))]，@racket[walk*] 展开 @racket[x] 时就会停不下来。避免循环的办法是在 @racket[ext-s] 添记录前先查一遍 @racket[x] 有没有已经出现在 @racket[t] 里，有就放弃当前支路：

@examples[#:eval ev-append #:no-result
(: occurs? (→ Var Term Substitution Boolean))
(define (occurs? x t s)
  (let ([t (walk t s)])
    (cond
      [(var? t) (var=? x t)]
      [(pair? t) (or (occurs? x (car t) s) (occurs? x (cdr t) s))]
      [else #f])))

(: ext-s (→ Var Term Substitution Substitution))
(define (ext-s x t s)
  (when (occurs? x t s) (amb))
  (cons (cons x t) s))]

试一下循环等式，这条支路在添进@tech{代换}前就被拦住了：

@examples[#:eval ev-append #:label #f
(let ([x (var 'x)])
  (in-amb ((≡ x (cons 1 x)) empty-s)))]

最后还需要 @racket[reify]：@racket[(reify v)] 收下要读出的整行项 @racket[v]（例如 @racket[(list x ...)]），交出一个从@tech{代换}读出答案的函数。它内部先用 @racket[walk*] 把能展开的都展开，再用同一套@tech{代换}机制走一遍 @racket[reify-s]，借 @racket[size-s] 按出现顺序把还自由的@tech{未知项}依次记成 @tt{_.0}、@tt{_.1}，最后再做一次 @racket[walk*] 替换掉，既不泄露内部身份，又能保住同一未知项在不同位置上的共享关系：

@examples[#:eval ev-append #:no-result
(: reify-name (→ Natural Symbol))
(define (reify-name n)
  (string->symbol (format "_.~a" n)))

(: reify-s (→ Term Substitution Substitution))
(define (reify-s v r)
  (let ([v (walk v r)])
    (cond
      [(var? v) (ext-s v (reify-name (size-s r)) r)]
      [(pair? v) (reify-s (cdr v) (reify-s (car v) r))]
      [else r])))

(: reify (→ Term (→ Substitution Term)))
(define ((reify v) s)
  (let* ([v (walk* v s)]
         [r (reify-s v empty-s)])
    (walk* v r)))]

把整行一起交出去看结果：
@examples[#:eval ev-append #:label #f
(let ([x (var 'x)] [y (var 'y)])
  (in-amb ((reify (list x y)) ((appendᵒ '(1) x y) empty-s))))
(let ([x (var 'x)] [y (var 'y)])
  (in-amb ((reify (list x y)) ((≡ x y) empty-s))))]

第一行交出的 @racket['((_.0 (1 . _.0)))]，表示只要第二个位置是在第一个位置前面加上 @racket[1]，任何值都成立；第二行交出的 @racket['((_.0 _.0))]，正是两个自由却必须相等的位置。宿主包装里的 @racket[value-of] 仍负责读出函数与@tech{谓词}必须拿到的具体实参，出口处读答案的工作则可以完全交给 @racket[reify]。

@section[#:tag "05:minikanren"]{语法糖与内核}

写 @racket[appendᵒ] 时，@racket[∃] 和 @racket[∨] 的每一支里面都套了一层 @racket[∧]；回看@xref["05:wanted"]{「想要的写法」}，最外层的查询也常常同时接上几条用 @racket[∧] 连起的条件。把自动@tech{合取}包成 @racket[fresh] 和 @racket[condᵉ]，给两个零元@tech{目标}分别起上常用的名字 @racket[succeed] 和 @racket[fail]，再把 @racket[reify] 读出、自动@tech{合取}以及「最多取前几组答案」的限制收进标准的 @racket[run]（第一个参数写个数，写 @racket[#f] 表示全部；本章的 @racket[in-amb] 会先收齐有限搜索的答案，@racket[run] 再取前 @racket[n] 行）：

@margin-note{直接定义带限制参数的 @racket[run]，可以避免重定义前面只收单个@tech{目标}的 @racket[run*]；在@xref["05:appendix"]{附录}的完整库里，@racket[run*] 就是 @racket[(run #f (x ...) g ...)] 这层语法糖。}

@examples[#:eval ev-append #:no-result
(define-syntax-rule (run n (x ...) g ...)
  (let ([limit n])
    (let ([x (var 'x)] ...)
      (define ans*
        (in-amb ((reify (list x ...)) ((∧ g ...) empty-s))))
      (if limit (take ans* (min limit (length ans*))) ans*))))

(define-syntax-rule (fresh (x ...) g ...)
  (∃ (x ...) (∧ g ...)))

(define-syntax-rule (condᵉ [g ...] ...)
  (∨ (∧ g ...) ...))

(: succeed Goal)
(: fail Goal)
(define succeed ⊤)
(define fail ⊥)]

用这三样重写 @racket[appendᵒ]，试跑取前两组、取全部拆法，以及刚才未定下来的查询：

@examples[#:eval ev-append #:label #f
(define (appendᵒ l t out)
  (condᵉ
    [(≡ l '()) (≡ t out)]
    [(fresh (a d res)
       (≡ l (cons a d))
       (≡ out (cons a res))
       (appendᵒ d t res))]))

(run 2 (x y) (appendᵒ x y '(1 2 3)))
(run #f (x y) (appendᵒ x y '(1 2 3)))
(run #f (x y) (appendᵒ '(1) x y))]

到这里，这门语言里的三种运算和它们的@tech{单位}都齐了：在@tech{代换}层，@tech{合取} @racket[∧] 的@tech{单位}是 @racket[⊤]，@tech{析取} @racket[∨] 的@tech{单位}是 @racket[⊥]；在@tech{关系}层，按外面两列的解看，@tech{二元关系}复合 @racket[∘ᵒ] 的@tech{单位}正是@tech{合一} @racket[≡]（@tech{合一}可能往@tech{代换}里添等式，@racket[⊤] 总是原样交回）。

我们为了把@tech{关系}直接写下来，一步步添上了 @racket[≡]、@racket[∧]、@racket[∨]、@racket[∃] 和两个@tech{单位} @racket[⊤]、@racket[⊥]，再包上 @racket[run]、@racket[fresh]、@racket[condᵉ]、@racket[succeed]、@racket[fail] 这层表面语法。整个语言实现不到一百行，这就是本章用有限搜索搭出来的一个 microKanren 内核，上面那层语法正是@defterm[#:en "relational programming"]{关系式编程}（@defterm[#:en "logic programming"]{逻辑式编程}的一个分支）语言 miniKanren 的极小内核。

@margin-note{和常见的实现相比，还有几处不同：@tech{未知项}按身份区分，不编号；@tech{合取}是直接复合，何时推迟一步计算、怎样取用答案，写法也不一样，交出答案的顺序因此可能不同。}

在那里，@tech{未知项}叫@defterm[#:en "logic variable"]{逻辑变量}，底层的六个记号常写作 @racket[==]、@racket[conj]、@racket[disj]、@racket[fresh]、@racket[succeed]、@racket[fail]。常见的实现用流来@tech{回溯}，@tech{目标}交出一串@tech{代换}，@tech{合取}与@tech{析取}都要自己写出怎样接、怎样并。这里用 @racket[amb] @tech{回溯}，@racket[∧] 就是 ℬ 的复合，@racket[∨] 就是 @racket[amb]，这两样都是现成的；剩下要写的，主要是@tech{合一}。
