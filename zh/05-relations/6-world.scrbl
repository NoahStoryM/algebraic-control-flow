#lang acf/scribble

@title[#:tag "05:6-world"]{关系的世界}

有了 @racket[≡]、@racket[∧]、@racket[∨]、@racket[∃] 和两个单位 @racket[⊤]、@racket[⊥]，关系语言已经能写等式、接条件、并分支、复合关系。只靠这些，能不借函数和谓词，直接写出一个递归的关系吗？

@section[#:tag "05:equation"]{直接写等式}

@racket[append] 把两张列表接成一张。它是函数，只能从左边两张算出右边一张。照它的定义写一个三个位置的关系 @racket[(appendᵒ l t out)]：@racket[l] 是空的，@racket[out] 就等于 @racket[t]；或者 @racket[l] 有头一项 @racket[a] 和剩下的 @racket[d]，@racket[out] 的头一项也是 @racket[a]，剩下的部分 @racket[res] 是 @racket[d] 接上 @racket[t]。

两种情形用 @racket[∨] 并起来，每种情形里的几条等式用 @racket[∧] 连起来，中间用到的未知项 @racket[a]、@racket[d]、@racket[res] 用 @racket[∃] 造出。@racket[appendᵒ] 照上面那句话逐字写下来：

@(define ev-world (make-acf-eval))
@examples[#:eval ev-world #:hidden
(require racket/control)
(define ∘ compose)
(define id (∘))
(define (choose p*) (shift k (append-map k p*)))
(define-syntax-rule (amb e ...) ((choose (list (λ () e) ...))))
(define-syntax-rule (for/amb clauses body ...) ((choose (for/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))
(define ∘ℬ ∘)
(define (list->amb v*) (for/amb ([v (in-list v*)]) v))
(struct var ([name : Symbol]) #:type-name Var #:transparent)
(define (walk t s)
  (define p (and (var? t) (assq t s)))
  (if p (walk (cdr p) s) t))
(define (⊤ s) s)
(define (⊥ s) (amb))
(define (∧ . g*) (apply ∘ℬ (reverse g*)))
(define ((∨ . g*) s) ((list->amb g*) s))
(define (unify u v s)
  (let ([u (walk u s)] [v (walk v s)])
    (cond [(and (var? u) (eq? u v)) s]
          [(var? u) (cons (cons u v) s)]
          [(var? v) (cons (cons v u) s)]
          [(and (pair? u) (pair? v))
           (unify (cdr u) (cdr v) (unify (car u) (car v) s))]
          [(equal? u v) s]
          [else (amb)])))
(define (value-of t s)
  (let ([t (walk t s)])
    (cond [(var? t) (error 'value-of "~a 的值还不知道" (var-name t))]
          [(pair? t) (cons (value-of (car t) s) (value-of (cdr t) s))]
          [else t])))
(define (((function->relation f) . t*) s)
  (define-values (in* out*) (split-at-right t* 1))
  (unify (car out*) (apply f (for/list ([t in*]) (value-of t s))) s))
(define ((≡ u v) s) (unify u v s))
(define-syntax-rule (∃ (x ...) g)
  (λ (s) (let ([x (var 'x)] ...) (g s))))
(define-syntax-rule (run* (x ...) g)
  (let ([x (var 'x)] ...)
    (in-amb
     (let ([s (g '())])
       (list (value-of x s) ...)))))]

@examples[#:eval ev-world #:no-result
(define (appendᵒ l t out)
  (∨ (∧ (≡ l '()) (≡ t out))
     (∃ (a d res)
       (∧ (≡ l (cons a d))
          (≡ out (cons a res))
          (appendᵒ d t res)))))]

@racket[appendᵒ] 在第二支里调用自己。要是 @racket[∃] 一上来就运行里面的条件，构造目标时就会一层层调用下去，停不下来；等到收到代换才运行，递归走几层，看的是代换里的列表有多长。

正着问，它和 @racket[append] 一样：

@examples[#:eval ev-world #:label #f
(run* (z) (appendᵒ '(1 2) '(3) z))]

反过来，给出接好的那一张，问前两个位置：

@examples[#:eval ev-world #:label #f
(run* (x y) (appendᵒ x y '(1 2 3)))]

四种拆法都找到了。定义 @racket[appendᵒ] 的时候，没有哪一行写过「拆」：每一行都是等式，没有哪个位置是输入，哪个是输出。这是关系不分输入输出的样子。

@section[#:tag "05:reify"]{读出还不知道的项}

等式两边都可以不知道，答案里也就可能有不知道的项：

@examples[#:eval ev-world #:label #f
(eval:error (run* (x y) (≡ x y)))]

@racket[(≡ x y)] 成立，代换里只有一条等式：@racket[x] 等于 @racket[y]。两个都没有值，@racket[value-of] 读不出来。可这组答案并不是空的，它说的是：@racket[x] 与 @racket[y] 是同一个数，至于是几，都可以。

答案里要写得出「同一个，是几都行」，就给换不动的未知项起名字，@tt{_.0}、@tt{_.1}，依次排下去；同一个未知项用同一个名字。把还不知道的项写成看得见的名字，这一步叫 @racket[reify]：

@(define ev-reify (make-acf-eval))
@examples[#:eval ev-reify #:hidden
(require racket/control)
(define ∘ compose)
(define id (∘))
(define (choose p*) (shift k (append-map k p*)))
(define-syntax-rule (amb e ...) ((choose (list (λ () e) ...))))
(define-syntax-rule (for/amb clauses body ...) ((choose (for/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))
(define ∘ℬ ∘)
(define (list->amb v*) (for/amb ([v (in-list v*)]) v))
(struct var ([name : Symbol]) #:type-name Var #:transparent)
(define (walk t s)
  (define p (and (var? t) (assq t s)))
  (if p (walk (cdr p) s) t))
(define (⊤ s) s)
(define (⊥ s) (amb))
(define (∧ . g*) (apply ∘ℬ (reverse g*)))
(define ((∨ . g*) s) ((list->amb g*) s))
(define (unify u v s)
  (let ([u (walk u s)] [v (walk v s)])
    (cond [(and (var? u) (eq? u v)) s]
          [(var? u) (cons (cons u v) s)]
          [(var? v) (cons (cons v u) s)]
          [(and (pair? u) (pair? v))
           (unify (cdr u) (cdr v) (unify (car u) (car v) s))]
          [(equal? u v) s]
          [else (amb)])))
(define (value-of t s)
  (let ([t (walk t s)])
    (cond [(var? t) (error 'value-of "~a 的值还不知道" (var-name t))]
          [(pair? t) (cons (value-of (car t) s) (value-of (cdr t) s))]
          [else t])))
(define (((function->relation f) . t*) s)
  (define-values (in* out*) (split-at-right t* 1))
  (unify (car out*) (apply f (for/list ([t in*]) (value-of t s))) s))
(define ((≡ u v) s) (unify u v s))
(define-syntax-rule (∃ (x ...) g)
  (λ (s) (let ([x (var 'x)] ...) (g s))))
(define idᵒ ≡)
(define ((∘ᵒ Qᵒ Pᵒ) x z)
  (∃ (y) (∧ (Pᵒ x y) (Qᵒ y z))))
(define (appendᵒ l t out)
  (∨ (∧ (≡ l '()) (≡ t out))
     (∃ (a d res)
       (∧ (≡ l (cons a d))
          (≡ out (cons a res))
          (appendᵒ d t res)))))]
@examples[#:eval ev-reify #:no-result
(: walk* (→ Term Substitution Term))
(define (walk* t s)
  (let ([t (walk t s)])
    (if (pair? t) (cons (walk* (car t) s) (walk* (cdr t) s)) t)))

(: reify (→ Term Data))
(define (reify t)
  (define (name-unknowns t s)
    (let ([t (walk t s)])
      (cond [(var? t)
             (cons (cons t (string->symbol (format "_.~a" (length s)))) s)]
            [(pair? t) (name-unknowns (cdr t) (name-unknowns (car t) s))]
            [else s])))
  (walk* t (name-unknowns t '())))]

@racket[walk*] 顺着代换把项里能换的都换掉，换不动的未知项留在原处。@racket[reify] 里起名用的也是一张代换，把留下来的未知项换成符号，交出不含未知项的 @racket[Data]。@racket[run*] 改成这样读出答案。要读的几个未知项放在一张列表里一起读，共用一套名字：

@examples[#:eval ev-reify #:no-result
(define-syntax-rule (run* (x ...) g)
  (let ([x (var 'x)] ...)
    (in-amb (reify (walk* (list x ...) (g '()))))))]

再试刚才报错的那一句，顺便看另外两例：

@examples[#:eval ev-reify #:label #f
(run* (x y) (≡ x y))
(run* (x y) ⊤)
(run* (x y) (appendᵒ '(1) x y))]

第一组是 @tt{(_.0 _.0)}：两个位置相等，都可以是任何项。第二组是 @tt{(_.0 _.1)}：什么条件也没有，两个位置各自任取。两组答案里都没有一个具体的数，差别全在名字是否相同上。第三组说，@racket[y] 是 @racket[1] 接上 @racket[x]，@racket[x] 是什么都行。

@margin-note{等式 @racket[(≡ x (cons 1 x))] 说 @racket[x] 是一张以 @racket[1] 开头、剩下部分又是它自己的列表，这样的项只能无穷无尽地写下去；完整的实现在添等式之前会先检查这个未知项是否出现在另一边，附录里的代码带着这一步。另外，@tt{_.0} 是沿用惯例的显示记号，如果项里本来就含有符号 @racket['_.0]，读出后会撞名。}

代换里 @racket[x] 对着 @racket[y] 的那一行，现在读得出来了。它没有说 @racket[x] 是几，所以一张代换不是一组答案：它说的是未知项之间要满足的关系，凡是满足这些等式的取值都算数。一组带名字的答案也就不是表里的一行，它代表许多行：@tt{(_.0 _.0)} 代表所有两个位置相等的行，在项上有无穷多。用到 @racket[value-of] 的那一版里，答案都是具体的值，一组就是一行，那只是未知项都有了值的特例。

有了 @racket[reify]，也可以检验 @racket[idᵒ] 在未知输入上当不当得了单位。拿一个只看第二个位置的 @racket[Pᵒ]，在右边分别接上 @racket[(function->relation id)] 和 @racket[idᵒ]：

@examples[#:eval ev-reify #:label #f
(define (Pᵒ x y) (≡ y 1))
(run* (q) (Pᵒ q 1))
(eval:error (run* (q) ((∘ᵒ Pᵒ (function->relation id)) q 1)))
(run* (q) ((∘ᵒ Pᵒ idᵒ) q 1))]

@racket[Pᵒ] 自己答得出来：@racket[q] 是什么都行。接上 @racket[(function->relation id)] 仍然报错；换成 @racket[idᵒ]，答案和 @racket[Pᵒ] 自己的一样。到这里，这门语言里三种运算的单位都齐了：在代换层，合取 @racket[∧] 的单位是 @racket[⊤]，析取 @racket[∨] 的单位是 @racket[⊥]；在关系层，在 @racket[run*] 读出结果的意义下，二元关系复合 @racket[∘ᵒ] 的单位就是合一 @racket[≡]。特征函数写不出复合，因为缺少 @racket[∃]；函数的 @racket[id] 当不了关系的单位，因为分了输入输出；@racket[∃] 与 @racket[≡] 正好补齐了这两样。

@margin-note{和常见的实现相比，还有几处不同：未知项按身份区分，不编号；合取是直接复合，何时推迟一步计算、怎样取用答案，写法也不一样，交出答案的顺序因此可能不同。}

到这里，这门小语言已经造齐了：只有等式 @racket[≡]、@racket[∧]、@racket[∨]、@racket[∃] 和两个单位 @racket[⊤]、@racket[⊥]，整个实现不到一百行。它的骨架就是 microKanren，@defterm[#:en "relational programming"]{关系式编程}（@defterm[#:en "logic programming"]{逻辑式编程}的一个分支）语言 miniKanren 的一个极小内核。在那里，未知项叫@defterm[#:en "logic variable"]{逻辑变量}，这六个记号常写作 @racket[==]、@racket[conj]、@racket[disj]、@racket[fresh]、@racket[succeed]、@racket[fail]，而 @racket[run*] 与 @racket[fresh] 也常添上一层语法糖，把多行目标自动包进 @racket[conj]。常见的实现用流来回溯：目标交出一串代换，合取与析取都要自己写出怎样接、怎样并。这里用 @racket[amb] 回溯，@racket[∧] 就是 ℬ 的复合，@racket[∨] 就是 @racket[amb]，这两样都是现成的；剩下要写的，主要是合一。

@section[#:tag "05:worlds"]{更大的世界}

前面在 ℬ 与 ℒ 之间用 @racket[gather] 与 @racket[scatter] 来回搬，来回一趟回到原处；用 @racket[function->relation] 也能把 ℬ 里带 @racket[amb] 的函数搬进这门关系语言（从 ℒ 出发，先用 @racket[scatter] 搬到 ℬ），照原来的方向问，六组照样出来。

可是反过来，把关系语言里的关系搬回 ℬ 或 ℒ，一般做不到。ℒ 的箭头收到一个输入，交出一张列表，列出表里与它同在一行的每一项。看一个最简单的二元关系，全关系 @racket[Uᵒ]，任何两个项都满足它：

@examples[#:eval ev-reify #:label #f
(define (Uᵒ x y) ⊤)
(run* (y) (Uᵒ 1 y))
(run* (x) (Uᵒ x 1))]

无论固定哪一列当作输入，答案都是 @tt{(_.0)}：另一列是什么都行。同一个输入对着无穷多行，无法一般地写成枚举同一外延关系全部具体输出的有限列表；ℬ 的箭头要为每一行返回一次，同样走不完。@xref["05:compose"]{「二元关系的复合」}说过，带 @racket[amb] 的函数表示的是每个输入只占有限多行的二元关系。关系语言里的关系不受这个限制：@tt{_.0} 这一个名字，就代表了那无穷多行。
