#lang acf/scribble

@title[#:tag "05:7-logic"]{与逻辑的对应}

写 @racket[∘ᵒ] 的时候，集合写法里的「存在」成了 @racket[fresh]，「并且」成了写在一起的两行条件。这门语言里的其余几样呢？

@section[#:tag "05:logic-table"]{一张对照表}

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list @elem{关系语言} @elem{逻辑} @elem{表})
   (list @racket[succeed] @math{⊤} @elem{零元关系 {()}})
   (list @racket[fail] @math{⊥} @elem{零元关系 {}})
   (list @racket[(== t1 t2)] @math{t₁ = t₂} @elem{使两项相等的那些取值})
   (list @racket[(conj g1 g2)] @math{g₁ ∧ g₂} @elem{按共有的列拼起来})
   (list @racket[(disj g1 g2)] @math{g₁ ∨ g₂} @elem{两张表并起来})
   (list @racket[(fresh (x) g)] @math{∃x. g} @elem{遮住一列})
   (list @racket[(run* (x) g)] @math{{x ∣ g}} @elem{读出整张表}))]

表这一列说的是答案，不是代换。拿@xref["05:wanted"]{「想要的写法」}的头两行来看，边界取 1 和 3：

@(define ev-logic (make-acf-eval))
@examples[#:eval ev-logic #:hidden
(require racket/control)
(define ∘ compose)
(define (choose p*) (shift k (append-map k p*)))
(define-syntax-rule (amb e ...) ((choose (list (λ () e) ...))))
(define-syntax-rule (for/amb clauses body ...) ((choose (for/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))
(define (between lo hi) (for/amb ([n (inclusive-range lo hi)]) n))
(define ∘ℬ ∘)
(struct var ([name : Symbol]) #:type-name Var #:transparent)
(define (walk t s)
  (define p (and (var? t) (assq t s)))
  (if p (walk (cdr p) s) t))
(define (conj . g*) (apply ∘ℬ (reverse g*)))
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
(define (walk* t s)
  (let ([t (walk t s)])
    (if (pair? t) (cons (walk* (car t) s) (walk* (cdr t) s)) t)))
(define (reify t)
  (define (name-unknowns t s)
    (let ([t (walk t s)])
      (cond [(var? t) (cons (cons t (string->symbol (format "_.~a" (length s)))) s)]
            [(pair? t) (name-unknowns (cdr t) (name-unknowns (car t) s))]
            [else s])))
  (walk* t (name-unknowns t '())))
(define-syntax-rule (run* (x ...) g ...)
  (let ([x (var 'x)] ...)
    (in-amb (reify (walk* (list x ...) ((conj g ...) '()))))))
(define betweenᵒ (function->relation between))]
@examples[#:eval ev-logic #:label #f
(run* (a b)
  (betweenᵒ 1 3 a)
  (betweenᵒ a 3 b))]

@racket[(betweenᵒ 1 3 a)] 的答案是只有 @racket[a] 一列的表，三行。@racket[(betweenᵒ a 3 b)] 说的是 @racket[a]、@racket[b] 两列：@racket[b] 在 @racket[a] 与 3 之间的那些行。两张表共有 @racket[a] 这一列，@racket[a] 相同的行拼在一起，就是上面的六行。没有共有的列时，是每一行与每一行配对。在代换上，合取是目标的复合，前一个交出的代换交给后一个；在答案上，合取是两张表按共有的列拼起来。析取在两层都是并。

@xref["05:relation"]{「关系」}一节数过，零元关系只有两个。在这里它们有了名字：@racket[succeed] 与 @racket[fail] 是不提任何未知项的条件，一个总成立，一个总不成立；落到实现，是代换上的恒等关系与空关系，合取与析取的单位。

最后一行说得满了。@racket[run*] 交出的是一张答案的列表，有先后，可能重复，答案里还可能有 @tt{_.0} 这样的名字。答案都是具体的值、搜索走完、去掉重复以后，它才是那张表。

@section[#:tag "05:microkanren"]{这门语言的名字}

@margin-note{和常见的实现相比，还有几处不同：未知项按身份区分，不编号；何时推迟一步计算、怎样取用答案，写法也不一样，交出答案的顺序因此可能不同。}

只有等式、合取、析取、存在和两个单位，这门小语言的骨架就是 microKanren：@defterm[#:en "logic programming"]{逻辑式编程}语言 miniKanren 的一个极小的内核。常见的实现用流来回溯：目标交出一串代换，合取与析取要自己写出怎样接、怎样并。这里用 @racket[amb] 回溯，合取就是 ℬ 的复合，析取就是 @racket[amb]，这两样都是现成的；剩下要写的，主要是合一。

整个实现收在附录里，不到一百行。
