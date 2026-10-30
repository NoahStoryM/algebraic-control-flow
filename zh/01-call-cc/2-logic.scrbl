#lang acf/scribble

@title[#:tag "01:2-logic"]{Curry-Howard 对应}

@(define ev (make-acf-eval))
@examples[#:eval ev #:hidden
(define-type ⊥ (∪))
(define primitive-call/cc call/cc)
(define (goto l) (l l))
(define (label) (primitive-call/cc goto))
(require racket/undefined)
(define (cc)
  (define first? #t)
  (define u undefined)
  (define l (label))
  (cond
    [first? (set! first? #f)
     (cons (λ (v) (set! u v) (goto l)) 1)]
    [else (cons u 0)]))]

上一小篇里，@racket[goto] 和@tech{延续}交出的类型都是 @racket[⊥]。交出 @racket[⊥]，说的是这段计算不会有结果交回来：一调用，控制流就切换到了别处。

这样的调用可以出现在任何位置。最后那版 @racket[mul] 里，@racket[(return r)] 和 @racket[(* res r)] 是 @racket[if] 的两个分支，一个交出 @racket[⊥]，一个交出实数，不考虑子类型的话，类型对不上；@racket[for/fold] 要的是实数，@racket[(return r)] 交不出实数，程序却照样运行。这是为什么？

@section[#:tag "01:call-cc-types"]{call/cc 的几种类型}

答案在 @racket[⊥] 本身。先造一个奇怪的函数：

@examples[#:eval ev #:label #f #:no-prompt
(: absurd (∀ (q) (→ ⊥ q)))
(define absurd (case-λ))]

@racket[case-λ] 按参数的个数分情形定义函数，每个子句对应一种调用方式。一个子句也没有的 @racket[(case-λ)]，没有任何调用方式能与它匹配，一调用就报错。这正合 @racket[⊥] 的情形：@racket[⊥] 类型没有元素，谁也交不出一个来给它，类型正确的程序里根本调用不到它。既然调用不到，说它交出什么类型都不会错，所以 @racket[absurd] 的类型是 @math{⊥ → q}，@math{q} 任意。

有了它，前面的疑问就解开了。@racket[(return r)] 交出 @racket[⊥]，接上 @racket[absurd]，@racket[(absurd (return r))] 就能当作实数用；@racket[absurd] 其实从来不会被调用，因为 @racket[(return r)] 根本不会交回来。交出 @racket[⊥] 的表达式，放在要什么类型的位置都行。

同样的道理，也能重新看 @racket[call/cc] 的类型。它原来的类型是：

@racketblock[
(: call/cc (∀ (p) (→ (→ (→ p ⊥) p) p)))]

先放宽。交给 @racket[proc] 的@tech{延续} @racket[k] 永不返回，后面接上 @racket[absurd]，@racket[(compose absurd k)] 的行为和 @racket[k] 一样，类型却是 @racket[(→ p q)]，@math{q} 任意。所以 @racket[call/cc] 也有这样的类型：

@racketblock[
(: call/cc (∀ (p q) (→ (→ (→ p q) p) p)))]

令 @math{q = ⊥}，就回到原来那一种。

再看另一头。假如 @racket[proc] 总会调用交给它的@tech{延续} @racket[k]，它自己就从不正常返回，返回类型是 @racket[⊥]，类型也就成了 @racket[(→ (→ p ⊥) ⊥)]。用同样的办法，后面接上 @racket[absurd]，@racket[(compose absurd proc)] 的类型就回到了 @racket[(→ (→ p ⊥) p)]，正好交得给 @racket[call/cc]。所以 @racket[call/cc] 也有这样的类型：

@racketblock[
(: call/cc (∀ (p) (→ (→ (→ p ⊥) ⊥) p)))]

交给它一个只等@tech{延续}的计算，它从中把结果取出来。

这样收紧，其实没有少掉什么。原来的类型允许 @racket[proc] 正常返回一个 @math{p}，最后那版 @racket[mul] 里的 @racket[λ] 就是这样，没遇到零，乘积是正常返回的。可调用 @racket[proc] 是 @racket[call/cc] 做的最后一件事，@racket[proc] 正常返回，返回值直接交到调用 @racket[call/cc] 的地方；交给 @racket[proc] 的@tech{延续} @racket[k]，通向的也正是那里。所以 @racket[proc] 正常返回 @racket[v]，和调用 @racket[(k v)] 原地跳一次，到的是同一个地方，交出的是同一个值。@xref["01:label-from-call-cc"]{「从 call/cc 定义标签」}里已经见过一次：@racket[(let/cc k (k k))] 和 @racket[(let/cc k k)] 没有分别。换成任何 @racket[proc] 都一样，下面两个表达式行为相同：

@racketblock[
(call/cc proc)
(call/cc (λ (k) (k (proc k))))]

第二行交给 @racket[call/cc] 的那整个 @racket[λ]，@racket[proc] 若正常返回，就再经 @racket[k] 交出结果，所以它从不正常返回，正是上面那种只等@tech{延续}的函数。@racket[proc] 取 @racket[(λ (k) k)]，这个 @racket[λ] 就是 @racket[(λ (k) (k k))]，也就是 @racket[goto]。

于是手里有了四个类型，@racket[absurd] 的一个，@racket[call/cc] 的三个，都只用 @math{→} 和 @math{⊥}。它们像在说些什么？

@section[#:tag "01:from-bottom"]{读成命题}

@math{⊥} 看上去像逻辑里的假，
@defsym["p → q" "蕴含；函数类型"]@math{→} 看上去像「如果……那么……」，也就是@defterm[#:en "implication"]{蕴含}。照这个样子，@math{p → ⊥} 说的是「如果 @math{p}，那么假」，也就是 @math{p} 不成立。这是@defterm[#:en "negation"]{否定}
@defsym["¬p" "p 的否定：p → ⊥，延续的类型"]@math{¬p}。@tech{延续}的类型正是 @math{p → ⊥}，每个@tech{延续}都是一个@tech{否定}：

@examples[#:eval ev #:label #f #:no-prompt
(define-type (¬ p ...) (→ p ... ⊥))]

@racket[¬] 和 @racket[→] 一样，参数可以不止一个：@racket[(¬ p q)] 就是 @racket[(→ p q ⊥)]。

用 @math{¬} 改写，四个类型都成了逻辑课本里有名字的定律：

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list @elem{程序} @elem{命题} @elem{定律})
   (list @elem{@racket[absurd]} @elem{@math{⊥ → q}}
         @elem{@defterm[#:en "principle of explosion"]{爆炸原理}})
   (list @elem{@racket[call/cc]} @elem{@math{(¬p → p) → p}}
         @elem{@defterm[#:en "Clavius's law"]{Clavius 律}})
   (list @elem{@racket[call/cc]} @elem{@math{((p → q) → p) → p}}
         @elem{@defterm[#:en "Peirce's law"]{Peirce 律}})
   (list @elem{@racket[call/cc]} @elem{@math{¬¬p → p}}
         @elem{@defterm[#:en "Double Negation Elimination" #:abbr "DNE"]{双重否定消除}}))]

四个程序，恰好对上四条有名的定律。这只是字面上的相像，还是真有其事？

检验起来并不费事。这些类型都由 @math{→} 和 @math{⊥} 搭起来，只要这两样最基本的对上了，搭出来的整体也就对上了。

@margin-note{这里先只看会终止的程序；会一直算下去的程序，留到@xref["01:where-fails"]{「对应关系在哪里失效」}再看。}

先看 @math{⊥}。它像假，凭什么？@math{⊥} 这个假命题没有证明；@tech{空类型} @math{⊥} 没有元素，给不出一个这样的值。@racket[(return r)] 的类型是 @racket[⊥]，那是借着手里现成的 @racket[return] 才写得出来；不依赖额外的假设，@racket[⊥] 类型的表达式一个也写不出来。两边说的是同一件事：没有证明，就是写不出表达式。反过来读，不依赖额外的假设写出一个类型的表达式，就像给出了对应命题的证明；写得出，命题就为真。拿这个读法验证一下：假的否定 @math{¬⊥} 该是真的，确实写得出 @math{⊥ → ⊥} 类型的表达式，恒等函数就是。@racket[absurd] 说的从假推出任何东西，在逻辑里也成立。@math{⊥} 对上了假。

再看 @math{→}。照这个读法，写出一个类型为 @math{p → q} 的函数，就是给出「如果 @math{p}，那么 @math{q}」的证明。函数 @racket[(λ (x) body)] 的形参 @racket[x] 是一个 @math{p}，函数体 @racket[body] 用到 @racket[x]，算出一个 @math{q}：假定有了 @math{p} 的证明，就造得出 @math{q} 的证明，逻辑里证明「如果……那么……」正是这样做的。反过来，手里有一个 @math{p → q} 和一个 @math{p}，调用它就得到一个 @math{q}，正是由「如果 @math{p}，那么 @math{q}」和 @math{p} 推出 @math{q}。比如 @racket[(→ Byte Natural)]：@racket[(λ (b) (+ b b))] 收下一个字节，交回它的两倍，一个自然数，这个命题为真。@math{→} 对上了蕴含。

@margin-note{写不出 @math{p}，不等于写得出 @math{¬p}：有的命题自己写不出，它的否定也写不出。}

两样合起来，否定也对得上。@math{p} 为假，就是它的否定 @math{¬p} 为真：写得出一个 @math{p → ⊥} 类型的表达式。反过来，@math{p} 为真，@math{¬p} 就该是假的，写不出来。试着写一个 @math{@ty{Real} → ⊥}：一个总会交出结果的函数，函数体最终要交出一个值，可 @racket[⊥] 类型没有元素，交不出来。

两样最基本的都对上了，四条定律就不是巧合。每个类型构造子都对应一个逻辑连接词：类型是命题，表达式是证明，构造程序就是构造证明。这个对应关系有一个名字：@defterm[#:en "Curry–Howard correspondence"]{Curry-Howard 对应}。

可这样一来，有件事说不通了。@tech{延续}的类型正是 @math{p → ⊥}，照这个对应，一条等实数的@tech{延续}本该不依赖任何假设就写不出来；我们却一直拿着，最后那版 @racket[mul] 里的 @racket[return] 就是。这些@tech{延续}都不是用 @racket[λ] 写出来的，是 @racket[cc]、@racket[call/cc] 在运行时捕获出来的。写不出的东西，@racket[cc] 凭什么交得出来？

@section[#:tag "01:types-to-logic"]{析取与合取}

@margin-note{这里把 @racket[cc] 当作现成的操作，按它的类型来用；它内部怎样用 @racket[label] 实现，不算在内，留到@xref["01:where-fails"]{「对应关系在哪里失效」}再说。}


等实数的@tech{延续}对应假，可 @racket[(cc)] 是一个合法的表达式，写得出来，它的类型就该是真的。倒回一步，看看 @racket[cc] 的类型。有了 @math{¬}，它可以写成：

@racketblock[
(: cc (∀ (p) (→ (∐ p (¬ p)))))]

@racket[(cc)] 交出的不是只有 @math{¬p}，而是 @math{p ∐ ¬p}。@math{∐} 看上去像「或」，也就是@defterm[#:en "disjunction"]{析取}
@defsym["p ∨ q" "析取；不相交的联合 p ∐ q"]@math{∨}。照这个样子，@math{p ∐ ¬p} 说的是「@math{p} 成立，或者 @math{p} 不成立」，这正是逻辑里的@defterm[#:en "law of excluded middle"]{排中律}。

@margin-note{两支分得开的联合，叫@defterm[#:en "disjoint union"]{不相交的联合}。打@tech{标记}是做到这一点的一种办法，其它办法见@xref["01:appendix"]{附录}。}

这回也检验一下。引入「@math{p} 或 @math{q}」有两种办法：由 @math{p} 的证明得到 @math{p} 或 @math{q}，或者由 @math{q} 的证明得到 @math{p} 或 @math{q}；两种办法都记明引入的是哪一支。这对应两种带@tech{标记}的构造：手里有一个 @math{p} 类型的 @racket[a]，@racket[(cons a 0)] 就是一个 @math{p ∐ q}；有一个 @math{q} 类型的 @racket[b]，@racket[(cons b 1)] 也是，@tech{标记}记着给的是哪一支。反过来，使用「@math{p} 或 @math{q}」要分情况：在 @math{p} 的假设下推得出 @math{r}，在 @math{q} 的假设下也推得出 @math{r}，就能从 @math{p} 或 @math{q} 推出 @math{r}。@racket[match] 正是这样分两支的，@racket[mul] 和 @racket[call/cc] 里的 @racket[match]，两支交出的是同一种类型的结果。@math{∐} 对上了析取。

单位元也对得上。一支也没有的 @racket[(∐)] 就是 @racket[⊥]。@math{p ∐ ⊥} 里，@math{⊥} 那一支没有元素，拿到的总是 @math{p} 那一支，去掉@tech{标记}就是一个 @math{p}；一个 @math{p} 配上@tech{标记}，也就成了 @math{p ∐ ⊥}。两边来回能换，@math{⊥ ∐ p} 也一样。逻辑里，假正是析取的单位元，
@defsym["p ⇔ q" "互推：p 推出 q，q 也推出 p"]@math{⇔} 读作互推：

@mm{p ⇔ p ∨ ⊥ ⇔ ⊥ ∨ p}

所以 @racket[(cc)] 写出的是 @math{p ∨ ¬p}，正是@tech{排中律}。前面那件说不通的事，也有了着落：@racket[(cc)] 并没有写出一个 @math{¬p}，@tech{延续}只是其中一支，而且以后可能经由它跳回来，换成另一支。拿到@tech{延续}那一支，得到的是一条和捕获点连着的出口：交给它一个 @math{p}，就跳回去，让 @racket[(cc)] 改交 @math{p} 那一支。这条出口不能从整个控制过程里摘出来，当作 @math{¬p} 的无条件证明。比如：

@examples[#:eval ev #:label #f
(match (cc)
  [(cons r 0) r]
  [(cons k 1) (k 5)])]

拿 @racket[k] 去「反驳」@racket[5]，并没有得到 @racket[⊥]：程序回到 @racket[(cc)]，改交出 @racket[5]。@racket[call/cc] 把这个分支挪进了操作符内部，它的类型里也就没有 @math{∐}，只用 @math{→} 和 @math{⊥} 就写得下。

前面说的都是 @racket[(cc)] 的类型为真。@racket[cc] 本身是一个不收参数的函数，也写得出来，它的类型当然也为真。逻辑里，从真
@defsym["⊤" "真，恰好有一个元素的类型"]@math{⊤} 推出 @math{p}，和 @math{p} 本身可以互推。程序里，表达式 @racket[e] 可以包成 @racket[thunk] @racket[(λ () e)]；调用这个 @racket[thunk]，才执行 @racket[e]，交出结果。所以 @racket[cc] 和 @racket[(cc)] 的类型在逻辑上等价，读出的都是@tech{排中律}。

@margin-note{这里的「零」说的是一次交出几个值，不是类型有几个元素。}

那 @math{⊤} 对应什么？@racket[thunk] 不收参数，调用时交给它的是零个实参。把一次交出的值整体看成一组，零个值就是空的一组，只有这一种可能。@racket[(values)] 交出的正是零个值，结果类型写作 @racket[(Values)]。照这样整体来读，它对应恰好有一个元素的 @math{⊤}，@racket[thunk] 也就对应 @math{⊤ → p}。不收参数有了着落，那收多个参数、交多个值，又对应什么？@math{⊤} 正是@defterm[#:en "conjunction"]{合取}
@defsym["p ∧ q" "合取；多个值 p × q"]@math{∧} 的单位元：

@mm{p ⇔ p ∧ ⊤ ⇔ ⊤ ∧ p}

空的一组并到别的值上，也没有多出任何值，正像这个单位元。这提示我们，@racket[(Values p q)] 该对应 @math{p ∧ q}，也就是笛卡尔积 @math{p × q}。检验一下。证明「@math{p} 且 @math{q}」，两个证明都要给出；@racket[(values a b)] 正是把 @racket[a] 和 @racket[b] 一起交出。使用「@math{p} 且 @math{q}」，两样都能拿来用；收下 @racket[(values a b)] 的地方，@racket[a] 和 @racket[b] 都在手里。@racket[Values] 对上了合取。函数的两个参数，也可以这样合起来，看成一个 @math{p × q}，读作 @math{p ∧ q}。

@section[#:tag "01:watershed"]{分水岭}

@racket[cc] 对上的@tech{排中律}，@racket[call/cc] 对上的 DNE，逻辑课本说都只在@defterm[#:en "classical logic"]{经典逻辑}中成立。不承认它们，只承认构造出来的证明，就是@defterm[#:en "intuitionistic logic"]{直觉主义逻辑}。在引入 @racket[cc] 和 @racket[call/cc] 之前，我们用到的函数、积、联合、@math{⊤}、@math{⊥}，都没有越出它的范围。

这两条经典定律，各有一条与之相对的定律，在直觉主义逻辑里照样成立。@tech{排中律}说 @math{p} 与 @math{¬p} 至少有一个成立；说两者不能同时成立，就是@defterm[#:en "law of non-contradiction"]{矛盾律} @math{¬(¬p ∧ p)}。DNE 从 @math{¬¬p} 推出 @math{p}；箭头反过来，从 @math{p} 推出 @math{¬¬p}，就是@defterm[#:en "Double Negation Introduction" #:abbr "DNI"]{双重否定引入}。

成立的命题，照 @tech{Curry-Howard 对应}应该写得出程序。前面是从程序读出命题，这回反过来，从命题出发找程序。

先看@tech{矛盾律}。@math{¬p ∧ p} 是一个 @math{¬p} 和一个 @math{p} 放在一起，对应函数的两个参数；整体取否定，结果是 @math{⊥}。所以要写的是这样一个函数：收下一个@tech{延续} @racket[kv] 和一个值 @racket[v]，得到 @math{⊥}。手里能产生 @math{⊥} 的只有 @racket[kv]，能交给它的只有 @racket[v]，写法几乎是被类型逼出来的：

@examples[#:eval ev #:label #f #:no-prompt
(: apply-cont (∀ (p) (¬ (¬ p) p)))
(define (apply-cont kv v) (kv v))]

类型写成 @racket[(¬ (¬ p) p)]，正好照着 @math{¬(¬p ∧ p)} 读。这就是调用@tech{延续}。最后那版 @racket[mul] 里的 @racket[(return r)]，就是一次 @racket[apply-cont]。

再看 DNI。给一个值 @racket[v]，要交出一个 @math{¬¬p}，也就是一个收下 @math{¬p}、结果为 @math{⊥} 的函数。理由和刚才一样，只能写成 @racket[(λ (kv) (kv v))]。做的还是调用，只是值先到，@tech{延续}后到。从 @racket[v] 得到这个函数，就是 @racket[(curryr apply-cont)]：先给定 @racket[apply-cont] 的第二个参数。

两个程序用到的@tech{延续}都是交进来的。这不是巧合：@xref["01:from-bottom"]{「读成命题」}里试过，只用 @racket[λ] 凭空写不出 @math{@ty{Real} → ⊥} 这样的否定，前面见到的@tech{延续}，都是控制操作符在运行时捕获出来的。结论里的每样东西都由交到手里的东西做成，这样的程序是@defterm[#:en "constructive"]{构造性}的。



用同样的办法试经典的两条。DNE 给一个等@tech{延续}的函数 @racket[kkp]，要交出一个 @math{p}。能对 @racket[kkp] 做的只有调用它，调用它却要一个 @math{¬p} 类型的 @racket[kp]：有了 @racket[kp]，调用 @racket[kkp] 得到 @math{⊥}，再交给 @racket[absurd] 就能当作 @math{p}。可是没有人交来 @racket[kp]，自己又构造不出，也就无法调用 @racket[kkp]。@tech{排中律}更彻底：什么也没给，要交出一个 @math{p} 或一个 @math{¬p}，两样都写不出。

@racket[call/cc] 和 @racket[cc] 补上的，正是这个缺口：它们凭空提供了一个@tech{延续}，就是当前@tech{延续}。@racket[call/cc] 把它交给等着的函数，从 @math{¬¬p} 得到 @math{p}。@racket[cc] 干脆把它交到我们手里；以后可能经由它跳回来，让 @racket[(cc)] 再返回一次，所以交出的东西得容得下两种情况：第一次是@tech{延续}，跳回来时是值，于是成了 @math{p ∨ ¬p}。凭空提供一个@tech{延续}，这是经典的。

排成一张表，每一行是一对相对的定律，每一列上下两格互相推得出：

@tabular[#:style 'boxed #:row-properties '(bottom-border ())
  (list
   (list "" @elem{构造性} @elem{经典})
   (list @elem{@math{p} 与 @math{¬p}}
         @elem{@bold{@tech{矛盾律}}：@racket[apply-cont]}
         @elem{@bold{@tech{排中律}}：@racket[cc]})
   (list @elem{@math{p} 与 @math{¬¬p}}
         @elem{@bold{DNI}：@racket[(curryr apply-cont)]}
         @elem{@bold{DNE}：@racket[call/cc]}))]

左边一列只差参数次序，@tech{矛盾律}和 DNI 互相推得出。右边一列都是提供当前@tech{延续}：@racket[cc] 可以由 @racket[call/cc] 写出，见@xref["01:label-from-call-cc"]{「从 call/cc 定义标签」}；反过来，@xref["01:call-cc"]{用 @racket[cc] 写出的 @racket[call/cc]} 先调用 @racket[(cc)]，拿到配着 @racket[0] 的值就交出，拿到配着 @racket[1] 的@tech{延续}就交给 @racket[proc]，这正是由@tech{排中律}推出 DNE。作为对任意类型都成立的原则，两者互相推得出。

可是，从 @math{¬¬p} 取出 @math{p}，非得凭空拿到一个@tech{延续}不可吗？
