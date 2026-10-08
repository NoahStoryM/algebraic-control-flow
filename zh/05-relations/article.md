# 歧路何从：表里的平行世界

大家好，

这是控制流系列的第五篇，前四篇是[《标签成为逻辑之时》](https://zhuanlan.zhihu.com/p/2019516690904401803)、[《箭头指向何方》](https://zhuanlan.zhihu.com/p/2024852076593694078)、[《世界尽头有何物》](https://zhuanlan.zhihu.com/p/2032178684895946051)和[《前沿回望之时》](https://zhuanlan.zhihu.com/p/2049638709486735603)。

第四篇的编译器处理 `if` 时，把同一份剩余工作写进了两个分支，运行时却只走其中一个：测试值在分支之前算出，替我们做了选择。未来写了两次，运行了一次。如果没有这样一个值，每个备选都要走到，同一份剩余工作为每个备选各运行一次呢？第四篇结尾给这样的树起了名字：**搜索树**，一棵拥有不止一条时间线的树。

这样的树其实并不陌生。每当我们用几层嵌套循环把所有可能挨个试一遍，走的就是一棵搜索树。本篇只讨论纯的、有限的搜索。

---

# 遍历搜索

给定边长的范围（上下界都取正整数），比如从 1 到 20，找出所有能构成直角三角形的三条边。最直接的办法是暴力搜索：最短边 `a` 从下界试到上界，`b` 从 `a` 试到上界，`c` 从 `b` 试到上界，满足 a² + b² = c² 的留下。在大多数语言里，暴力搜索是三层嵌套循环；Racket 的 `for*/list` 把三层写在一处。把它包进一个以上下界 `l`、`h` 为参数的函数：

```racket
(define-type ℕ⁺ Positive-Integer)
(define-type Triangle (List ℕ⁺ ℕ⁺ ℕ⁺))

(: pyth? (→ ℕ⁺ ℕ⁺ ℕ⁺ Boolean))
(define (pyth? a b c) (= (+ (* a a) (* b b)) (* c c)))

(: right-triangles (→ ℕ⁺ ℕ⁺ (Listof Triangle)))
(define (right-triangles l h)
  (for*/list ([a (inclusive-range l h)]
              [b (inclusive-range a h)]
              [c (inclusive-range b h)]
              #:when (pyth? a b c))
    (list a b c)))
```

```racket
> (right-triangles 1 20)
'((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20))
```

三层循环逐个生成候选。`a` 每取一个值，`b` 就从 `a` 试到上界；`b` 每取一个值，`c` 又从 `b` 试到上界。`a` = 1 下面的 `b`、`c` 全部试完，才轮到 `a` = 2。每凑齐一组，`#:when` 检查一次：满足条件的由 `(list a b c)` 交出，不满足的什么也不留下。从 1 到 20 一共试了 C(20+3-1, 3) = 1540 组，留下六组，按找到的先后接成一张列表。

为了这六组边，循环试了 1540 组。用同样的边界再调用一次，这 1540 组还得从头试一遍，交出的却还是那六组：`right-triangles` 是一个纯函数，输出只由输入决定。既然如此，算过的结果就可以记下来，下次遇到同样的边界直接取出。这就是缓存：

```racket
(define-type (Dict k v) (Listof (Pair k v)))
(define-type Bounds (List ℕ⁺ ℕ⁺))

(: cache (Dict Bounds (Listof Triangle)))
(define cache '())

(: right-triangles/cached (→ ℕ⁺ ℕ⁺ (Listof Triangle)))
(define (right-triangles/cached l h)
  (define l×h (list l h))
  (unless (dict-has-key? cache l×h)
    (set! cache (dict-set cache l×h (right-triangles l h))))
  (dict-ref cache l×h))
```

`cache` 是一张关联列表，每个元素是一个序对，记着一组边界和它的答案列表。Racket 把这样的列表当作字典：`dict-has-key?` 看某个键在不在，`dict-set` 添上一项，`dict-ref` 按键取值。`right-triangles/cached` 先看这组边界算过没有，没算过就跑一遍循环，把结果记进 `cache`，最后按边界取出。从外面看，它和 `right-triangles` 是同一个函数：

```racket
> (right-triangles/cached 1 4)
'()
> (right-triangles/cached 1 5)
'((3 4 5))
> (right-triangles/cached 1 20)
'((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20))
> cache
'(((1 4)  . ())
  ((1 5)  . ((3 4 5)))
  ((1 20) . ((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20))))
```

再看 `cache` 里记下了什么：一共三行。为了看清每行的两项，这里把序对的点写了出来，点的左边是键，右边是值。键是边界，算过的不会再添，所以同一组边界只占一行。值是答案列表：一组边界对应的不是某一个答案，而是装着全部答案的一张列表，可能有六组，也可能一组都没有。

眼下 `cache` 只记着三组边界。设想把所有的边界都算过一遍，它会是一张巨大的**表**，每组边界都是其中的键。到那时循环就用不着了，`right-triangles` 只剩下一次查找，可以写成：

```racket
(: dictionary->function (∀ (v k ...) (→ (Dict (List k ... k) v) (→ k ... k v))))
(define ((dictionary->function dict) . key) (dict-ref dict key))

(define right-triangles (dictionary->function cache))
```

调用函数求值，就是按键查表。从这个角度看，任何纯函数都可以看作一张以输入为键的表。

# 关系

我们把带键的表 `(Dict k v)` 定义为 `(Listof (Pair k v))`，可这个定义本身并没有要求 `k` 是键：同一个 `k` 出现几次，类型都不管。`cache` 里的边界不重复，只是因为我们把同一组边界的答案都收进了一张列表。不如放开这个限制，把表摊开，让每组答案各自配上它的边界：

```racket
(: rows (Listof (Pair Bounds Triangle)))
(define rows
  (for*/list ([(l×h t*) (in-dict cache)]
              [t t*])
    (cons l×h t)))
```

```racket
> rows
'(((1 5)  . (3 4 5))
  ((1 20) . (3 4 5))
  ((1 20) . (5 12 13))
  ((1 20) . (6 8 10))
  ((1 20) . (8 15 17))
  ((1 20) . (9 12 15))
  ((1 20) . (12 16 20)))
```

`(1 20)` 原来只占一行，现在占了六行；`(1 4)` 记下的列表是空的，摊开以后一行也没有。

`rows` 用列表记下表里的行。行的先后我们并不关心，所以不妨换用集合来记这张表；把所有满足同样条件的行都收进来，用数学的语言描述这个集合：

R = {((l, h), (a, b, c)) ∈ (ℕ⁺ × ℕ⁺) × (ℕ⁺ × ℕ⁺ × ℕ⁺) | l ≤ a ≤ b ≤ c ≤ h ∧ a² + b² = c²}

竖线左边的笛卡尔积描述了行的形状，对应每一行的类型 `(Pair Bounds Triangle)`；竖线右边是条件。$R$ 里的行既符合这个形状，又满足条件，所以 $R$ 是这个笛卡尔积的一个子集。这个子集完全描述了边界与边之间要满足的关系，因此从数学的角度看，它就是**关系**（relation）。

纯函数可以看作一张以输入为键的表，所以它也是关系，条件是每个输入都有唯一的输出。任意纯函数 $f : A → B$ 对应的关系是：

{(a, b) ∈ A × B | b = f(a)}

表有 N 列，每一行就取自 N 个集合的笛卡尔积，对应的是 **N 元关系**（N-ary relation）。$R$ 和函数对应的关系都有两列，是**二元关系**（binary relation）。同一个关系换个角度，可以看作不同的多元关系：把元组展平，$R$ 也可以看作 $ℕ⁺ × ℕ⁺ × ℕ⁺ × ℕ⁺ × ℕ⁺$ 的子集，一个五元关系。特别地，一元关系就是某个集合的子集；零个集合的笛卡尔积只有一个元素，就是空的元组 $()$，所以零元关系只有两个：{} 和 {()}。

**谓词**（predicate）把这几种关系连在了一起。谓词是交出布尔值的函数。先看一个极小的例子：

```racket
(define-type Bit (∪ Zero One))

(: one? (→ Bit Boolean : #:+ One #:- Zero))
(define (one? b) (eqv? b 1))
```

```racket
> (for/list ([b '(0 1)])
    (cons b (one? b)))
'((0 . #f)
  (1 . #t))
```

用集合来写，`Bit` ≔ {0, 1}，`Boolean` ≔ {`#t`, `#f`}。作为函数，`one?` 是这两个集合之间的二元关系 {(0, `#f`), (1, `#t`)}；上面的表列出的正是它的全部两行：`Bit` 的每个元素占一行，再加一列布尔值。让 `one?` 交出 `#t` 的输入构成 `Bit` 的一个子集 `One` ≔ {1}，这是一元关系；交出 `#f` 的输入则是它的补集 `Zero` ≔ {0}。类型里的 `#:+ One` 和 `#:- Zero` 说的正是这两个集合：结果为真，输入属于 `One`；结果为假，输入属于 `Zero`。

参数多于一个时也一样。关系说的是某种形状的元素满足某个条件，谓词的输入正是这种形状的元素，满足条件交出 `#t`，不满足交出 `#f`；把笛卡尔积整体看作一个集合，它仍然是在判断输入是不是某个子集的元素。所以 N 个参数的谓词描述了一个 N 元关系：第一节的 `pyth?` 接收三个参数，描述的是一个三元关系。零个参数的谓词只有 `(λ () #t)` 和 `(λ () #f)`，正好对应两个零元关系 {()} 和 {}。

# 写不完的表

谓词虽然能表示一张表，但它只能检查一行在不在这张表里，无法直接读出表里记着的数据。要读出数据，得按键查表。

像 `cache` 这样的字典，键是唯一的，所以从头找下去，第一次找到就可以交出结果。`rows` 没有这个限制，同一组边界可以出现在好几行里；那就把整张表走完，把找到的值都收进一张列表。

两种查法并排写出来，再各配一个把表变成函数的转换。`dict-ref` 是库里的函数，这里只看查得到键的情形，把它自己写一遍：

```racket
(define (dict-ref  dict key) (for/first ([(k v) (in-dict dict)] #:when (equal? key k)) v))
(define (dict-ref* dict key) (for/list  ([(k v) (in-dict dict)] #:when (equal? key k)) v))

(define ((dictionary->function dict) . key) (dict-ref  dict key))
(define ((table->relation      dict) . key) (dict-ref* dict key))
```

两种查法只差在 `for/first` 与 `for/list`。在 `rows` 上试一试：

```racket
> ((table->relation rows) 1 20)
'((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20))
> ((table->relation rows) 1 4)
'()
```

`(table->relation rows)` 收到一组边界，交出一张三角形的列表，类型是 `(→ ℕ⁺ ℕ⁺ (Listof Triangle))`，正是 `right-triangles` 的类型。上一节把 `cache` 里的列表摊开，得到了 `rows`；这里按键把 `rows` 收拢，`cache` 里的每组边界又对上了原来那张列表。

函数是一个特殊的二元关系，对应一个字典；一般的二元关系对应一张表，只要每个输入对应的行能完整地列出来，也可以表示为一个交出列表的函数。一个输入对应的可以是一行、许多行，或者一行也没有。记着列表的字典，摊开就是一张表；一张表，按键收拢，又是一个记着列表的字典。不计先后与重复，二者可以来回转换，但不是同构：记着空列表的键，摊开以后一行也不剩，收拢回来就找不到了。

不过表可能有无穷多行。$R$ 就是这样，边界有无穷多组，整张表是写不完的，`rows` 只记着算过的三组。好在程序用不着整张表，问到哪几行，算出哪几行就够了。`right-triangles/cached` 正是这样做的：收到一组没算过的边界，现算，记进 `cache`。表不是事先写好的，而是随着查找一点点长出来。

这种到用的时候才算的做法叫**惰性**（lazy）。记下来只是为了不算第二遍；不记，每次现算，交出的也是同样的行。所以在程序里表示关系，靠的是函数：函数可以看作那张写不完的表，表里的行等到查的时候才算出来。

# 藏在循环里的局部延续

开头说，搜索树上同一份剩余工作要为每个备选各运行一次，还说嵌套循环走的就是这样一棵树。可是循环里并没有哪一行写着「剩余工作」。它在哪里，又是怎样被运行了许多次的？

先看熟悉的 `let*`。它的绑定从上到下依次执行，每个绑定配对了两件东西：右边的可归约式，和等着它的结果的局部延续，也就是这个绑定之后的全部代码。`for*/list` 写出来几乎是同一个样子：

```racket
(let* ([a 3]
       [b (+ a 1)]
       [c (+ b 1)])
  (list a b c))

(for*/list ([a (inclusive-range 1 20)]
            [b (inclusive-range a 20)]
            [c (inclusive-range b 20)]
            #:when (pyth? a b c))
  (list a b c))
```

一串绑定从上到下排开，后面的绑定可以用前面的名字，计算的先后都写在了绑定的先后里。`for*/list` 的每个绑定后面，同样跟着一份等着结果的剩余工作。差别在可归约式算出了什么。`(+ a 1)` 算出一个值，剩余工作拿着它运行一次。`(inclusive-range 1 20)` 算出的是一个序列，`a` 要取遍其中每个值，剩余工作就为每个值各运行一次。

第四篇的 `if` 把剩余工作写了两次，只运行了一次。这里正相反：`[a (inclusive-range 1 20)]` 之后的全部代码只写了一次，却运行了二十次，每次拿到一个不同的 `a`，彼此互不相干。普通的计算里，剩余工作运行过就成为过去，一次计算只有一条时间线。这里同一份剩余工作运行了许多遍，一次搜索里有不止一条时间线。

这份被反复运行的剩余工作藏在 `for*/list` 的语法里，把它写出来。先看 `let`：`(let ([v e]) body)` 脱糖后是 `((λ (v) body) e)`，等着结果的延续 `(λ (v) body)` 就摆在眼前。给它起名 `k`，`k` 在 `e` 的值上调用一次。`for*/list` 也照这样写：`k` 要对序列 `e*` 里的每个值各调用一次，各次交出的列表再接成一张，这是 `append-map` 做的事。

```racket
(let ([v e]) body)            =  ((λ (k) (k e))             (λ (v) body))
(for*/list ([v e*] …) body)   =  ((λ (k) (append-map k e*)) (λ (v) body*))
```

`body*` 是其余的子句连同 `body`，它交出一张列表。

第二行里的 `(λ (k) (append-map k e*))` 只依赖序列 `e*`。把序列抽成参数，起名 `choose/k`：它收到一张备选的列表，等着剩余工作 `k`，把备选逐个交给 `k`，再把各次的结果接起来。

```racket
(: choose/k (∀ (p q) (→ (Listof p) (→ (→ p (Listof q)) (Listof q)))))
(define ((choose/k p*) k) (append-map k p*))
```

用 `choose/k` 把 `right-triangles` 的三层循环摊开，每一层的剩余工作都成了一个写出来的 λ。每层交出的都得是列表，最内层也一样：直角成立，交出只装着一行的列表；不成立，交出空列表。

```racket
(define (right-triangles l h)
  ((choose/k (inclusive-range l h))
   (λ (a)
     ((choose/k (inclusive-range a h))
      (λ (b)
        ((choose/k (inclusive-range b h))
         (λ (c)
           (if (pyth? a b c) (list (list a b c)) '()))))))))
```

```racket
> (right-triangles 1 20)
'((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20))
```

交出的列表与循环的一模一样。

剩余工作有了名字，它运行了几次就数得出来。最外层的 `(append-map k (inclusive-range 1 20))` 摊开是 `(append (k 1) (k 2) … (k 20))`，同一个 `k` 运行了二十次。参数从左到右求值，`(k 1)` 连同它下面所有的 `b`、`c` 试完，才轮到 `(k 2)`：一条路走到头，退回最近一处还有备选的地方，换下一个再走。这就是**回溯**（backtracking）。

走到最里面，直角成立的时间线交出一行，不成立的什么也不交出，`append` 把交出的行接成一张列表。表里的行就是这样来的：同一组边界在表里占几行，搜索里就有几条走通的时间线。函数的输入恰好占一行，一条时间线就够了；关系的输入可以占许多行，也可以一行不占。

# 擦除延续参数

摊开后的 `right-triangles` 是一段 CPS 程序：每一层的剩余工作都写成 λ，作为参数交给 `choose/k`。第四篇的编译器也是这个形状，那里擦掉延续参数的办法，是让 `shift` 在原来的位置把它取出来。对每个调用点照样做一遍：

```racket
  ((choose/k p*) (λ (v) body))
= (let ([k (λ (v) body)]) ((choose/k p*) k))
= (let ([k (λ (v) body)]) (append-map k p*))
= (reset (let ([v (shift k (append-map k p*))]) body))
```

前三行只是换写法：给延续起名 `k`，再按 `choose/k` 的定义把 `((choose/k p*) k)` 换成 `(append-map k p*)`。最后一行才是擦除：`body` 不再包进 λ 交出去，而是留在原处；`shift` 从里面取得的 `k`，是 `reset` 之内、它自己之后的那段代码，正是原来的 `(λ (v) body)`。

`(shift k (append-map k p*))` 在每个调用点都会出现，给它起名 `choose`。三层照这个样子逐一改写，每层一个 `reset`，一个 `choose`：

```racket
(: choose (∀ (p) (→ (Listof p) p)))
(define (choose p*) (shift k (append-map k p*)))

(define (right-triangles l h)
  (reset
   (let ([a (choose (inclusive-range l h))])
     (reset
      (let ([b (choose (inclusive-range a h))])
        (reset
         (let ([c (choose (inclusive-range b h))])
           (if (pyth? a b c) (list (list a b c)) '()))))))))
```

三个 `reset` 层层相套，里面的两个是多余的：`k` 每次调用都自带一层 `reset`，紧挨着再套一层，等于只套一层，`(reset (reset e)) = (reset e)`。第四篇化简编译器时，内层的 `reset` 也是这样去掉的。只留最外面一层，三个 `let` 合成一个 `let*`：

```racket
(define (right-triangles l h)
  (reset
   (let* ([a (choose (inclusive-range l h))]
          [b (choose (inclusive-range a h))]
          [c (choose (inclusive-range b h))])
     (if (pyth? a b c) (list (list a b c)) '()))))
```

```racket
> (right-triangles 1 20)
'((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20))
```

主体已经是普通的 `let*`，`a`、`b`、`c` 各是一个数，读起来是一次只有一个值的普通计算。这要归功于 `choose` 的类型：收进一张列表，交出其中的一个元素。从调用处看，它只返回了一个值，后面的代码照常往下走；`shift` 取得的 `k` 却在 `append-map` 里为每个元素各运行了一遍。「为每个备选各运行一遍」并没有消失，只是不用再写成 λ 交出去。

不过它还有两处是专为搜索写的。最后一行不能直接交出 `(list a b c)`：成立时要再包一层，成为只装着一行的列表，不成立时要交出空列表，这样 `append-map` 才接得起来。最外面还要放一层 `reset`，标出这次搜索到哪里为止。

# 不确定运算符 amb

把专为搜索写的那两处拿掉，程序就该是这个样子：

```racket
(let* ([a (between l h)]
       [b (between a h)]
       [c (between b h)])
  (check (pyth? a b c))
  (list a b c))
```

它读起来像是一段普通的程序：三条边各从范围里取一个数，检查是不是直角，是就交出这一组边。可是普通的函数做不到里面的两件事。`(between l h)` 只交出一个数，后面的代码却要为范围里的每个数各走一遍：它得「返回许多次」。`check` 在条件不成立时要让这条时间线到此为止，什么也不留下：它得「不返回」。此外还要有一层，把走通的各条时间线交出的结果收到一起。

一次调用可以返回许多次，也可以不返回，这样的计算叫**不确定计算**（nondeterministic computation）。McCarthy 的**不确定运算符**（ambiguous operator）`amb` 就是为它准备的：`(amb 1 2 3)` 返回三次，每次交出一个备选，后面的计算各走一遍；一个备选也不写的 `(amb)` 不返回，这条时间线到此为止。再用 `in-amb` 圈出一次不确定计算，把走通的结果收成一张列表：

```racket
> (in-amb (amb 1 2 3))
'(1 2 3)
> (in-amb (let* ([x (amb 1 2 3)]
                 [y (amb 10 20)])
            (+ x y)))
'(11 21 12 22 13 23)
> (in-amb (let ([n (amb 1 2 3 4 5)])
            (unless (odd? n) (amb))
            (* n n)))
'(1 9 25)
```

`for/amb` 是 `amb` 的循环写法，每一轮是一个备选。伪代码里缺的两个函数，用它们各写一行就有了；收集结果的那一层就是 `in-amb`：

```racket
(: between (→ ℕ⁺ ℕ⁺ ℕ⁺))
(define (between lo hi) (for/amb ([n (inclusive-range lo hi)]) n))

(: check (→ Boolean Void))
(define (check ok?) (unless ok? (amb)))

(define (right-triangles l h)
  (in-amb
   (let* ([a (between l h)]
          [b (between a h)]
          [c (between b h)])
     (check (pyth? a b c))
     (list a b c))))
```

```racket
> (right-triangles 1 20)
'((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20))
```

`in-amb` 里面就是开头的那段程序，一个字也没有改。

最后把 `amb` 做出来。`choose` 从一张列表里选一个，`shift` 取得的 `k` 为每个备选各运行一遍，这已经是 `amb` 的行为了。四个名字各用一行：

```racket
(define-syntax-rule (amb e ...) ((choose (list (λ () e) ...))))
(define-syntax-rule (for/amb  clauses body ...) ((choose (for/list  clauses (λ () body ...)))))
(define-syntax-rule (for*/amb clauses body ...) ((choose (for*/list clauses (λ () body ...)))))
(define-syntax-rule (in-amb e) (reset (list e)))
```

备选是表达式，选中了才求值，所以各包一层 λ，选出来以后再调用。`(amb)` 是从零个备选里选，`k` 一次也不调用，原来那一行 `'()` 做的就是这件事。`in-amb` 是最外面那层 `reset`，连同把结果包成列表的那一步。专为搜索写的两处，就这样收进了这几个名字里。

# 二元关系的复合

`inclusive-range` 收到一组边界，交出其间所有的数；`right-triangles` 收到一组边界，交出所有的直角三角形。两个都是交出列表的函数，表示的都是二元关系。

`inclusive-range` 表示的关系，`between` 也表示：把 `between` 放进 `in-amb`，交出的正是 `inclusive-range` 的那张列表。

```racket
(inclusive-range l h)  =  (in-amb (between l h))
```

区别在写法。`between` 写出来是个普通的函数，收到两个数，交出一个数；放在 `in-amb` 里，同一组输入在表里占几行，它就返回几次。没有 `amb` 的时候，函数只能表示每个输入恰好占一行的二元关系；有了 `amb`，普通写法的函数可以表示每个输入只占有限多行的二元关系。

`right-triangles` 也可以这样得到。分成四步，每一步都写成这样的函数，收到一项，交出一项，再用普通的 `∘` 接起来：

```racket
(define pick-a (match-λ [(list l   h) (list (between l h)   h)]))
(define pick-b (match-λ [(list a   h) (list a (between a h) h)]))
(define pick-c (match-λ [(list a b h) (list a b (between b h))]))
(define (check-right t) (check (apply pyth? t)) t)
(define right-triangle (∘ check-right pick-c pick-b pick-a))
```

开始时手里是一组边界 `(l h)`。

1. `pick-a` 在边界之间选最短边 `a`。后面的边不会比它短，`a` 就是新的下界，交出的还是两项，`(a h)`。
2. `pick-b` 在 `a` 与 `h` 之间选第二条边 `b`，交出三项，`(a b h)`。
3. `pick-c` 在 `b` 与 `h` 之间选最长边 `c`。上界用不着了，交出的正好是三条边，`(a b c)`。
4. `check-right` 检查这三条边是不是直角三角形，是才原样交出。

接起来的 `right-triangle` 表示的正是 `right-triangles` 的那个关系：把它放进 `in-amb`，交出的就是那张列表。

```racket
(right-triangles l h)  =  (in-amb (right-triangle (list l h)))
```

每一步都是一个二元关系，也就是一张两列的表：左边一列是收到的项，右边一列是交出的项。函数能复合，表也就能复合：把两张表并排放，前一张某一行的右边与后一张某一行的左边是同一项，这两行就首尾相连，连成一行。拿 `pick-a` 与 `pick-b` 来说，边界取 `(1 2)` 时连出三行：

| `(l h)` | `(a h)` | `(a b h)` |
|---------|---------|-----------|
| `(1 2)` | `(1 2)` | `(1 1 2)` |
| `(1 2)` | `(1 2)` | `(1 2 2)` |
| `(1 2)` | `(2 2)` | `(2 2 2)` |

每一行的左边两列是 `pick-a` 表里的一行，右边两列是 `pick-b` 表里的一行。遮住中间一列，剩下的两列就是 `(∘ pick-b pick-a)` 表里的三行。用集合的语言写，这是二元关系的复合：

Q ∘ P = {(x, z) | ∃y, (x, y) ∈ P ∧ (y, z) ∈ Q}

$y$ 就是被遮住的中间一列。「存在这样的 $y$」由 `amb` 兑现：`pick-a` 交出的每一项，`pick-b` 都会接着用。有了 `amb`，函数的复合就是二元关系的复合。

# 关系的世界

有了 `amb`，函数就是二元关系，函数的复合就是二元关系的复合。可是这份方便是借来的：`amb` 不是宿主原有的运算，它靠 `shift` 和 `reset` 做出来，`between` 也算不上纯函数。纯的宿主里没有 `amb`，那里的二元关系是什么样子？

第二篇问过同样的问题，那里借的是 `call/cc`。纯的宿主记作 𝒟，添上 `call/cc` 的宿主记作 $𝒞$；回答是在 𝒟 里另造一个世界 $𝒦$ 来模拟 $𝒞$：把箭头的类型从 $p → q$ 改成 $p → ¬¬q$，再给它配上自己的复合。这里照样做。添上 `amb` 的宿主记作 ℬ，要找的是 𝒟 里模拟 ℬ 的那个世界。

ℬ 比 𝒟 只多了 `amb`，原来的都还在。纯函数是每个输入恰好占一行的二元关系，放进 ℬ 里同样合法；箭头还是普通的函数类型，复合还是普通的 `∘`：

```racket
(define-type (→𝒟 p q) (→ p q))
(define-type (→ℬ p q) (→ p q))

(: inj (∀ (p q) (→ (→𝒟 p q) (→ℬ p q))))
(define (inj f) f)

(: ∘ℬ (∀ (p ...) (→ (→ℬ pn-1 pn) ... (→ℬ p1 p2) (→ℬ p1 pn))))
(define ∘ℬ ∘)
```

要找的世界不用另造，它早就有了，里面的箭头我们也不陌生：交出列表的函数。`right-triangles` 是，`inclusive-range` 也是，我们从一开始就是这样模拟关系的，只是列表多记了结果的先后和重复，表不记这些。一个输入对应的结果不分几次返回，而是装进一张列表，一次交出来；箭头的类型从 $p → q$ 改成 $p → (Listof q)$。把这个世界记作 ℒ，里面的箭头都是纯函数。

```racket
(define-type (→ℒ p q) (→ p (Listof q)))
```

ℬ 与 ℒ 模拟的是同一样东西，二元关系，两个世界的箭头也可以来回搬。从 ℒ 到 ℬ，把交出的列表交给 `amb`，散成几条时间线，叫 `scatter`；从 ℬ 到 ℒ，用 `in-amb` 把各条时间线的结果收成一张列表，叫 `gather`：

```racket
(: list->amb (∀ (p) (→ (Listof p) p)))
(define (list->amb v*) (for/amb ([v (in-list v*)]) v))

(: scatter (∀ (p q) (→ (→ℒ p q) (→ℬ p q))))
(define (scatter f) (∘ list->amb f))

(: gather (∀ (p q) (→ (→ℬ p q) (→ℒ p q))))
(define ((gather g) . x*) (in-amb (apply g x*)))
```

搬过去再搬回来，得到的还是原来的箭头：`(in-amb (list->amb v*))` 把 `v*` 的每一项各包成一张列表，再接起来，还是 `v*`；反过来，`(list->amb (in-amb e))` 把 `e` 的结果收齐了再逐个交出，后面的计算看到的还是那些结果。来回一趟都回到原处，所以两个世界同构，是同一个世界的两种写法；这里比的是 `in-amb` 收到的列表，先后与重复都算在内。`between` 与 `inclusive-range` 就是同一个二元关系的两种写法：

```racket
inclusive-range  =  (gather between)
between  =  (scatter inclusive-range)
```

同构的两个世界，复合也该对得上。可是 ℒ 的箭头不能用 `∘` 接：前一个交出一张列表，后一个只收其中一项。ℬ 的箭头能接，那就借同构把 ℬ 的复合搬过来：先把 ℒ 的箭头搬到 ℬ，在那边接好，再搬回来。第二篇的 `∘𝒦` 也是这样绕道另一个世界得来的。

```racket
(: ∘ℒ (∀ (p ...) (→ (→ℒ pn-1 pn) ... (→ℒ p1 p2) (→ℒ p1 pn))))
(define (∘ℒ . f*) (gather (apply ∘ℬ (map scatter f*))))
```

这个定义绕道 ℬ，用到了 `amb`，而 ℒ 要住在纯的宿主里。拿两步的情形，展开 `gather` 与 `scatter`，再化简：

```racket
  ((∘ℒ g f) x)
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
= (append-map g (f x))
```

展开之后原路往回走，依次是这一篇出现过的四种写法：`in-amb` 里的 `let*`，`reset` 里的 `choose`，交给 `choose/k` 的延续，`for*/list` 的循环。循环摊开就是 `append-map`；`(append-map list v*)` 把每一项各包成一张列表再接起来，还是 `v*`，里面那一层就化掉了。`amb` 不见了，剩下的是纯函数：对前一步交出的每一项调用后一步，把结果接成一张。多于两步时也一样，从最右边的一步起，逐个用 `append-map` 接上。于是 `∘ℒ` 可以不经过 ℬ，直接在 𝒟 里定义：

```racket
(define ((∘ℒ . f*) . x*) (foldr append-map x* f*))
```

纯的宿主里没有 `amb`，二元关系在那里就是这个样子：交出列表的函数，用 `append-map` 接起来。

化简途中的两行还可以并排着看。`in-amb` 里的那段 `let*` 是 `∘ℬ` 展开得来的，`for*/list` 的循环化简下去就是 `∘ℒ`：

```racket
(let*      ([y (f x)] [z (g y)]) z)  =  ((∘ℬ g f) x)
(for*/list ([y (f x)] [z (g y)]) z)  =  ((∘ℒ g f) x)
```

第一行的 `f`、`g` 是 ℬ 的箭头，第二行的是 ℒ 的箭头。两个世界各有一种绑定的写法，写出来的都是复合，多出来的只是中间结果的名字。

> **练习：** 化简里有一步，`in-amb` 展开成 `reset` 与 `list`，`list->amb` 则直接换成了 `choose`，这暗示两者的行为相同。展开 `for/amb` 的定义，验证 `list->amb` 与 `choose` 是同一个函数。提示：`for/amb` 交给 `choose` 的是一张 λ 的列表，选出来以后还要调用一次。

# 描述关系的语言

到这里，关系都是用函数模拟的：交出列表的函数，或者带 `amb` 的函数。可是在 `amb` 版的搜索里，两个关系的用法并不一样：

```racket
(let* ([a (between l h)]
       [b (between a h)]
       [c (between b h)])
  (check (pyth? a b c))
  (list a b c))
```

`between` 是交出结果的函数，写在绑定的右边，取出一个数来；`pyth?` 是谓词，只回答是或否，要靠 `check` 才用得上。一个取，一个查。它们描述的却是同一类东西：`between` 是边界与其间的数之间的关系，`pyth?` 是三条边之间的关系。取与查的分别来自函数，不来自关系。

设想有一门语言，直接写关系。`between` 和 `pyth?` 在其中各有对应的关系，名字后面添一个上标 ᵒ：

```racket
(define betweenᵒ (function->relation  between))
(define pythᵒ    (predicate->relation pyth?))
```

`(pythᵒ a b c)` 说的是 `a`、`b`、`c` 满足勾股定理。`between` 收两个数交出一个，`betweenᵒ` 就有三个位置，结果排在最后：`(betweenᵒ l h a)` 说的是 `a` 在 `l` 与 `h` 之间。两个关系的写法一样，不再分取与查。搜索写成：

```racket
(define (right-triangles l h)
  (run* (a b c)
    (betweenᵒ l h a)     ; l ≤ a ≤ h
    (betweenᵒ a h b)     ; a ≤ b ≤ h
    (betweenᵒ b h c)     ; b ≤ c ≤ h
    (pythᵒ a b c)))      ; a² + b² = c²
```

与 `amb` 版一行对一行：三个绑定成了三行 `betweenᵒ`，`check` 的一行成了 `pythᵒ`，最后交出的 `(list a b c)` 挪到了 `run*` 后面，`in-amb` 那一层也收进了 `run*`。它读起来更像集合的写法：`run*` 是花括号，`(a b c)` 是竖线左边的形状，下面四行是竖线右边的条件，要同时成立。

这还只是想要的写法，`function->relation`、`predicate->relation`、`run*` 都还没有。改写里有一处不只是换名字：`a`、`b`、`c` 原来由 `let*` 绑定，每一行右边算出一个值，交给左边的名字；现在它们列在 `run*` 后面，是三个还不知道的数，四行条件各说了一件关于它们的事。没有了绑定，这三个名字是什么？一行 `(betweenᵒ l h a)` 写在那里，又交出了什么？
