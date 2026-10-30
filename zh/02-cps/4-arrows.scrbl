#lang acf/scribble

@title[#:tag "02:4-arrows"]{两种箭头与命题}

嵌入语言里，每一次绑定都把两段计算接了起来。接法有没有规律，写下的类型又说了什么？@racket[cps:call/cc] 只用 @racket[λ] 就写成了，第一篇的@xref["01:watershed"]{「分水岭」}却说当前@tech{延续}凭空拿不到，两者怎么对得上，也要从这些类型里看。

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define-type ⊥ (∪))
(define-type (¬ p) (→ p ⊥))
(define-type (¬¬ p) (¬ (¬ p)))
(define-type (← q p) (→ p q))
(define ∘ compose)
(define id (∘))
(define (⨾ . f*) (apply ∘ (reverse f*)))
(struct (r) ans ([a* : (Listof r)]) #:type-name Ans)
(define (list->values v*) (apply values v*))
(define (a->⊥ . a*) (raise (ans a*)))
(define-syntax-rule (⊥->a exp)
  (with-handlers ([ans? (∘ list->values ans-a*)]) exp))
(define (((cps f) . p*) kq) (kq (apply f p*)))
(define ((neg f) kq) (∘ kq f))
(define (((flip f) . y*) . x*) (apply (apply f x*) y*))
(define ((cps:call/cc cps:proc) kp) ((cps:proc (cps kp)) kp))
(define ((neg:call/cc kp) neg:proc) ((neg:proc kp) (neg kp)))
(define cps:id (cps id))
(define-syntax-rule (anf:let ([v e]) b)
  (λ (k) (e (λ (v) (b k)))))
(define (anf:eval kka) (⊥->a (kka a->⊥)))
(define cps:mul1 (cps (λ (v) (* 1 v))))
(define cps:mul2 (cps (λ (v) (* 2 v))))
(code:comment "无限输出只看前 n 行，后面印出 ...")
(define (show-lines n thunk)
  (define out (open-output-string))
  (define t (parameterize ([current-output-port out]) (thread thunk)))
  (let loop ()
    (define s (get-output-string out))
    (cond [(>= (length (regexp-match* #rx"\n" s)) n)
           (kill-thread t)
           (define lines (string-split s "\n" #:trim? #f))
           (for ([l (in-list (take lines n))])
             (displayln l))
           (display "...")]
          [(thread-dead? t) (display s)]
          [else (sleep 0.01) (loop)])))]

@section[#:tag "02:two-arrows"]{两种箭头}

@xref["02:early-return"]{「提前返回」}里的 @racket[anf:let*]，一个绑定套着一个绑定。@racket[anf:let] 的写法和 @racket[let] 一样，也就碰上@xref["02:laws"]{「结合律与单位律」}同样的问题：几步可以嵌在 @racket[b] 里，也可以先接成一段，嵌进 @racket[e]；还可以插一个只换名的绑定。三步嵌在 @racket[b] 里：

@racketblock[
(anf:let ([y (cps:f x)])
  (anf:let ([z (cps:g y)])
    (cps:h z)))]

先把前两步接成一段，嵌进 @racket[e]：

@racketblock[
(anf:let ([z (anf:let ([y (cps:f x)])
               (cps:g y))])
  (cps:h z))]

只换名的绑定也有。@racket[anf:let] 的右边得是一段计算，只换名，用的就是阴阳谜题里那段什么也不做的计算 @racket[cps:id]。两种只换名的写法，都该和直接写 @racket[(cps:f x)] 一样：

@racketblock[
(anf:let ([y (cps:id x)]) (cps:f y))
(anf:let ([y (cps:f x)]) (cps:id y))]

两种嵌套交出的，是同一段计算吗？只换名的绑定，真的可有可无吗？

@subsection[#:tag "02:bind-compose"]{绑定就是复合}

问题一样，解法也可以借来。那里把 @racket[let] 看成复合，问题就成了复合是否满足@tech{结合律}与@tech{单位律}。这里也把一次绑定看成一次复合：照 @racket[anf:let] 的样子，先 @racket[cps:f] 再 @racket[cps:g]，接成一支新的箭头，记作@defsym["g ∘𝒦 f" "CPS 箭头的复合，由 anf:let 给出"] @racket[∘𝒦]（取 continuation 的字母）：

@examples[#:eval ev #:label #f #:no-prompt
(define ((∘𝒦 cps:g cps:f) x)
  (anf:let ([y (cps:f x)])
    (cps:g y)))]

和宿主里 @racket[let] 的那条等式并排：

@racketblock[
(let     ([y     (f x)])     (g y))  =  ((∘      g     f) x)
(anf:let ([y (cps:f x)]) (cps:g y))  =  ((∘𝒦 cps:g cps:f) x)]

@margin-note{这些等式说的是行为相同，用的是@xref["02:split-k"]{「延续独占一层」}里的那个前提：两层参数之间不做别的事。比如 @racket[cps:f] 一收到参数就打印，@racket[(∘𝒦 cps:id cps:f)] 就会把打印推迟到收到@tech{延续}之后。}

@racket[let] 是 @racket[∘] 的另一种写法，@racket[anf:let] 是 @racket[∘𝒦] 的另一种写法，多出来的是中间结果的名字。嵌在 @racket[b] 里，写成复合是 @racket[(∘𝒦 (∘𝒦 cps:h cps:g) cps:f)]；嵌进 @racket[e] 里，是 @racket[(∘𝒦 cps:h (∘𝒦 cps:g cps:f))]；两种换名，是在 @racket[cps:f] 的两头接上 @racket[cps:id]。想让这几种写法行为一样，@racket[∘𝒦] 就得像 @racket[∘] 一样，满足@tech{结合律}与@tech{单位律}：

@racketblock[
(∘𝒦 cps:h (∘𝒦 cps:g cps:f))  =  (∘𝒦 (∘𝒦 cps:h cps:g) cps:f)
(∘𝒦 cps:f cps:id)  =  cps:f
(∘𝒦 cps:id cps:f)  =  cps:f]


@subsection[#:tag "02:via-contrapositive"]{借道逆否复合}

@racket[∘𝒦] 满足这两条运算律吗？先拿例子试试。再提升一支 @racket[mul3]，用 @racket[(fact/k 3 k)] 的三步乘法比较两种分组：

@examples[#:eval ev #:label #f
(define cps:mul3 (cps (λ (v) (* 3 v))))
(anf:eval ((∘𝒦 cps:mul3 (∘𝒦 cps:mul2 cps:mul1)) 1))
(anf:eval ((∘𝒦 (∘𝒦 cps:mul3 cps:mul2) cps:mul1) 1))]

两种分组算得一样。一般也是这样吗？不必逐条展开，可以借已有的运算律：把它搬到一种已经认识的复合上，运算律就一起跟过来。先给两种写法的箭头起名：照 @racket[cps] 写法的叫@defterm[#:en "CPS arrow"]{CPS 箭头}，记作@defsym["p →𝒦 q" "CPS 箭头：p → ¬¬q；𝒦 取 continuation"] @math{→@subscript{𝒦}}；照 @racket[neg] 写法的叫@defterm[#:en "contrapositive arrow"]{逆否箭头}，记作@defsym["p →𝒰 q" "逆否箭头：¬q → ¬p；𝒰 取掉头转弯（U-turn）"] @math{→@subscript{𝒰}}（U 取掉头转弯的意思：箭头的方向倒了过来）。前面名字以 @racket[cps:]、@racket[neg:] 开头的函数，就分别是这两种箭头：

@examples[#:eval ev #:label #f #:no-prompt
(define-type (→𝒦 p q) (→    p (¬¬ q)))
(define-type (→𝒰 p q) (← (¬ p) (¬ q)))]

@math{p →@subscript{𝒦} q} 收到 @math{p}，交出等着 @math{q} 的计算。@math{p →@subscript{𝒰} q} 用的是反向箭头 @racket[←]：它从 @math{p} 写到 @math{q}，函数却从 @math{¬q} 指向 @math{¬p}。有了名字，前面几个函数的类型可以重写；@xref["02:early-return"]{「提前返回」}里 @racket[cps:loop] 的类型，也就是 @racket[(→𝒦 (Listof Real) Real)]：

@examples[#:eval ev #:label #f #:no-prompt
(: neg  (∀ (p q) (→ (→ p q) (→𝒰 p q))))
(: cps  (∀ (p q) (→ (→ p q) (→𝒦 p q))))
(: flip (∀ (p q) (case→ (→ (→𝒰 p q) (→𝒦 p q))
                        (→ (→𝒦 p q) (→𝒰 p q)))))
(: cps:id (∀ (q) (→𝒦 q q)))
(: ∘𝒦 (∀ (p1 p2 p3) (→ (→𝒦 p2 p3) (→𝒦 p1 p2) (→𝒦 p1 p3))))]

@racket[case→] 列出同一个函数的几种类型，调用时按交给它的参数取用其中一种：这两行是 @racket[flip] 同一段代码的两种读法，第一行从 𝒰 搬到 𝒦，第二行搬回来。普通函数经 @racket[neg] 变成@tech{逆否箭头}，经 @racket[cps] 变成 @tech{CPS 箭头}，@racket[flip] 在两种箭头之间来回。沿用@xref["02:split-k"]{「延续独占一层」}的前提，来回一趟，什么也不丢。

@tech{逆否箭头}也能复合吗？@racket[flip] 把它们一一对到 @tech{CPS 箭头}，那就把 @racket[∘𝒦] 原样搬过去：两支各 @racket[flip] 成 @tech{CPS 箭头}，用 @racket[∘𝒦] 接起来，再 @racket[flip] 回来：

@examples[#:eval ev #:label #f #:no-prompt
(define (∘𝒰       neg:g        neg:f)
  (flip (∘𝒦 (flip neg:g) (flip neg:f))))]

搬过来的复合是什么？把 @racket[(flip neg:g)]、@racket[(flip neg:f)] 记作 @racket[cps:g]、@racket[cps:f]，交齐@tech{延续} @racket[k] 和输入 @racket[x]，展开：

@racketblock[
#,(hspace 2)(((∘𝒰 neg:g neg:f) k) x)
= (((∘𝒦 cps:g cps:f) x) k)
= ((cps:f x) (λ (y) ((cps:g y) k)))
= ((neg:f (λ (y) ((neg:g k) y))) x)
= ((neg:f (neg:g k)) x)
= (((∘ neg:f neg:g) k) x)
= (((⨾ neg:g neg:f) k) x)]

第一步照 @racket[∘𝒰] 和 @racket[flip] 的定义展开，第二步展开 @racket[∘𝒦]，第三步把 @racket[cps:f]、@racket[cps:g] 换回 @racket[flip] 之前的 @racket[neg:f]、@racket[neg:g]。第四步把 @racket[(λ (y) ((neg:g k) y))] 化简成 @racket[(neg:g k)]，靠的是@xref["02:split-k"]{「延续独占一层」}的那个前提：@racket[neg:g] 收到 @racket[k] 时只造出一个函数，什么别的也不做。最后两步是 @racket[∘] 与 @racket[⨾] 的定义。

搬过来的，原来就是反向复合 @racket[⨾]：先用 @racket[neg:g]，再用 @racket[neg:f]。@xref["02:position"]{「计算的位置」}用几次 @racket[neg] 接出@tech{闭包链}，也是这样接的。于是@tech{逆否箭头}的复合@defsym["g ∘𝒰 f" "逆否箭头的复合，就是 ⨾"]直接取 @racket[⨾]，单位元取 @racket[id]，记作 @racket[neg:id]：

@examples[#:eval ev #:label #f #:no-prompt
(: ∘𝒰 (∀ (p1 p2 p3) (→ (→𝒰 p2 p3) (→𝒰 p1 p2) (→𝒰 p1 p3))))
(define ∘𝒰 ⨾)

(: neg:id (∀ (q) (→𝒰 q q)))
(define neg:id id)]

@racket[⨾] 有@tech{结合律}与@tech{单位律}，@racket[∘𝒰] 也就有：分组无关紧要，@racket[neg:id] 接在哪一头都不改变什么。@racket[id] 搬回 @tech{CPS 箭头}这边，正是 @racket[cps:id]。@racket[flip] 来回一趟什么也不丢，@racket[∘𝒦] 搬过去是 @racket[∘𝒰]，两条运算律也就跟着搬了回来：两种嵌套的 @racket[anf:let] 交出同样的计算，只换名的绑定可有可无。

@bold{练习}：反过来，只用 @racket[∘𝒰] 和 @racket[flip] 写出 @racket[∘𝒦]，验证它与由 @racket[anf:let] 给出的定义行为相同。

@section[#:tag "02:propositions"]{读出命题}

第一篇的 @racket[call/cc] 要靠宿主捕获@tech{延续}；@xref["02:k-in-hand"]{「手中的延续」}里的 @racket[cps:call/cc] 却只用了 @racket[λ] 和函数调用，什么也没有捕获。两者做的是同一件事：把当前@tech{延续}交给 @racket[proc]。它们究竟是同一个什么？@xref["01:call-cc-types"]{「call/cc 的几种类型」}把 @racket[call/cc] 的类型读成了命题，其中一种是 @tech{Clavius 律}。照这个办法，把这一篇写下的类型也读成命题。

先读最早的两个。@racket[neg] 和 @racket[cps] 的类型，按照 Curry-Howard 对应，是两条直觉主义定理：

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list @elem{命题} @elem{定理})
   (list @elem{@math{(p → q) → (¬q → ¬p)}}
         @elem{@defterm[#:en "law of contraposition"]{逆否律}})
   (list @elem{@math{(p → q) → (p → ¬¬q)}}
         @elem{DNI 的推广形式}))]

用在 @racket[id] 上，@racket[cps:id] 的类型就是 @math{p → ¬¬p}，第一篇的 DNI 本身。@racket[flip] 的两行读法 @math{(¬q → ¬p) → (p → ¬¬q)} 和 @math{(p → ¬¬q) → (¬q → ¬p)}，也都是直觉主义定理。

两种新箭头有了名字，宿主里普通的函数也给一个，叫@defterm[#:en "host arrow"]{宿主箭头}，记作@defsym["p →𝒞 q" "宿主箭头：普通的函数 p → q；𝒞 取 classical"] @math{→@subscript{𝒞}}（𝒞 取 classical：宿主里有 @racket[call/cc]，经典的控制就在这里），好和它们并排：

@examples[#:eval ev #:label #f #:no-prompt
(define-type (→𝒞 p q) (→ p q))]

三种箭头，各是一种命题形状：

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list @elem{箭头} @elem{类型})
   (list @elem{宿主箭头} @elem{@math{p →@subscript{𝒞} q = p → q}})
   (list @elem{CPS 箭头} @elem{@math{p →@subscript{𝒦} q = p → ¬¬q}})
   (list @elem{逆否箭头} @elem{@math{p →@subscript{𝒰} q = ¬q → ¬p}}))]

@subsection[#:tag "02:clavius"]{新箭头下的 Clavius 律}

回到那个问题。两个新 @racket[call/cc] 的类型，可以从定义里读出来。拿 @racket[cps:call/cc] 来看。把它交出的结果的类型记作 @racket[p]。@racket[kp] 是这次调用的当前@tech{延续}，等的就是这个结果，类型是 @racket[(¬ p)]。@racket[cps] 把它提升成 @racket[(→𝒦 p ⊥)]，这是用 @tech{CPS 箭头}写的否定，记作 @defsym["¬𝒦 p" "用 CPS 箭头写的否定：p →𝒦 ⊥，展开是 p → ¬¬⊥"]@racket[¬𝒦]；用@tech{逆否箭头}写的否定同样记作 @defsym["¬𝒰 p" "用逆否箭头写的否定：p →𝒰 ⊥，展开是 ¬⊥ → ¬p"]@racket[¬𝒰]：

@examples[#:eval ev #:label #f #:no-prompt
(define-type (¬𝒦 p) (→𝒦 p ⊥))
(define-type (¬𝒰 p) (→𝒰 p ⊥))]

它们是新箭头下的新类型，不是 @math{¬} 换了一种写法：展开到宿主，@math{¬@subscript{𝒦} p} 是 @math{p → ¬¬⊥}。@racket[cps:proc] 收到的是 @racket[(¬𝒦 p)]；它交回的计算又交给了 @racket[kp]，所以是 @racket[(¬¬ p)]。@racket[cps:proc] 因此是 @racket[(→𝒦 (¬𝒦 p) p)]。@racket[cps:call/cc] 先收 @racket[cps:proc]，再收 @racket[kp]，结果是 @racket[⊥]，它的类型就出来了。@racket[neg:call/cc] 同理：

@examples[#:eval ev #:label #f #:no-prompt
(: cps:call/cc (∀ (p) (→𝒦 (→𝒦 (¬𝒦 p) p) p)))
(: neg:call/cc (∀ (p) (→𝒰 (→𝒰 (¬𝒰 p) p) p)))]

@bold{练习}：照推出 @racket[cps:call/cc] 类型的办法，推出 @racket[neg:call/cc] 的类型：@racket[kp] 仍是 @racket[(¬ p)]，留意 @racket[neg:proc] 先收的是哪一个。展开时，@racket[(→𝒰 (¬𝒰 p) p)] 是 @racket[(→ (¬ p) (¬ (¬𝒰 p)))]。@racket[(neg kp)] 的类型是 @math{¬⊥ → ¬p}，也就是 @racket[(¬𝒰 p)]。

把宿主 𝒞 里的否定记作 @racket[¬𝒞]，第一篇的 @racket[call/cc] 的类型是：

@examples[#:eval ev #:label #f #:no-prompt
(define-type (¬𝒞 p) (→𝒞 p ⊥))

(: call/cc (∀ (p) (→𝒞 (→𝒞 (¬𝒞 p) p) p)))]

读作 @math{(¬p → p) → p}，@tech{Clavius 律}。两个新 @racket[call/cc] 的类型是同一条定律，只是 @math{→@subscript{𝒞}} 换成了 @math{→@subscript{𝒦}}、@math{→@subscript{𝒰}}：它们是 @tech{Clavius 律}用这两种箭头写出来的样子。外形和宿主里的那条一样，只是箭头的种类换了；展开到宿主的箭头，就是另一条命题。

可@xref["01:watershed"]{「分水岭」}说过：@racket[call/cc] 要先凭空造出一个 @math{¬p} 交给 @racket[proc]，只用 @racket[λ] 和函数调用写不出来，必须捕获。@racket[cps:call/cc] 却只用了 @racket[λ]。把 @math{→@subscript{𝒦}} 展开成宿主的箭头：

@mm{(¬@subscript{𝒦} p →@subscript{𝒦} p) →@subscript{𝒦} p = (¬@subscript{𝒦} p → ¬¬p) → ¬p → ⊥}

@math{¬p} 在箭头左边，是参数，就是 @racket[kp]。宿主的 @tech{Clavius 律}只收 @racket[proc] 一个输入，手里没有否定，只能凭空去造；用 @tech{CPS 箭头}写，这个否定作为参数交了进来。交给 @racket[cps:proc] 的 @math{¬@subscript{𝒦} p}，是 @racket[cps] 从 @racket[kp] 加工出来的。

这个 @math{¬@subscript{𝒦} p} 能不能凭空造出来？@math{¬@subscript{𝒦} p} 展开是 @math{p → ¬¬⊥}；手里若有一个 @math{¬¬⊥} 的值，把类型为 @math{⊥ → ⊥} 的 @racket[id] 交给它，就得到 @math{⊥} 的值，所以 @math{¬¬⊥} 和 @math{⊥} 一样空。对非空的 @math{p}，同样凭空造不出 @math{¬@subscript{𝒦} p}。

@racket[cps:call/cc] 做的，是@xref["01:watershed"]{「分水岭」}构造性那一侧的事：消耗交到手里的否定。

所以展开后的这条公式，已经不是宿主里的 @tech{Clavius 律}，而是一条直觉主义定理：按照 Curry-Howard，它有闭合的、有类型的纯 @racket[λ] 项，就是 @racket[cps:call/cc]。@racket[neg:call/cc] 也一样。同一条经典定律，换用 @tech{CPS 箭头}或@tech{逆否箭头}来写，就成了直觉主义定理。经典的控制并没有消失，宿主要捕获的那条@tech{延续}，成了显式的参数。

三种箭头之间，@racket[cps] 和 @racket[neg] 都从宿主出发，@racket[flip] 在后两种之间来回。还缺一个方向：嵌入语言写出的 @tech{CPS 箭头}，怎样回到宿主？
