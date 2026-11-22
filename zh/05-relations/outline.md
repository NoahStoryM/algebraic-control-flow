# 第五篇大纲

记录正文现在怎么走，不记论证，不抄代码。每节只写三样：回应什么问题，造了什么、认出了什么，第一次出现的名字。改叙事的 PR 先改这里，再改正文；只改措辞的 PR 不用动它。

> **现状（11/22 定稿，正文、附录与 code.rkt 已按此版同步）**：全章分为上下两半。上半部（1–3 节）从搜索表出发，经 `amb` 走到 `𝒞`、`ℬ`、`ℒ` 三个世界，在 3.2 以 `flat-map = (curry append-map)` 和 `𝒞 ──inj──→ ℬ ⇄ ℒ ──flat-map──→ 𝒞` 方形图表收尾（外圈绕回 `map`），为第六章抽象通用结构铺路。下半部（4–5 节）进入「关系式编程」：4.2 按 `∧ → ⊤ → ⊥ → ∨` 收齐代换层运算与单位；5.1 先讲二元复合 `∘ᵒ`（多参数留作练习，附录给完整版），再通过尝试 `(function->relation id)` 与 `(predicate->relation equal?)` 双双碰壁统一揭示借来函数与谓词的单向限制，引出 5.2 合一 `≡`（复合的单位）；5.3 一气呵成写 `appendᵒ`（正反问），收束三大运算与单位、揭晓 microKanren / miniKanren（`walk*`/`reify` 与 `occurs?`/`ext-s` 移入附录，旁注说明）。

标题：歧路何从：表里的平行世界

主线：表是全篇的线索，遍历搜索是贯穿的例子。从暴力搜索加缓存看出我们一直在处理表；表就是关系，函数是特殊的二元关系；把循环里藏着的局部延续写出来得到 `choose/k`，按第四篇的办法擦除延续参数得到 `choose`，再收成 `amb`；有了 `amb`，函数的复合就是关系的复合；纯宿主里，关系是交出列表的函数，复合由 `append-map` 接起来，柯里化后的 `flat-map` 把 `ℒ` 送回 `𝒞` 并闭合三个世界的图表；后半把集合语言逐字翻译成关系式编程（用 `amb` 实现的 microKanren），用 `∃` 写出关系复合 `∘ᵒ`，用合一 `≡` 补齐复合的单位。

## 配乐（Noah 11/2 定）

题记用 `@music`，只写曲名，紧接在章或节的标题下面（`lib/README.md`）。选曲的理由不写在这个仓库。

- 篇首：特里·赖利《In C》。

## 0 开头

- 列出前四篇标题（短开头，不逐篇回顾）。
- 接第四篇：`if` 把剩余工作写了两次、运行一次；没有替我们选择的值时，同一份剩余工作要为每个备选各运行一次，即**搜索树**，一棵不止一条时间线的树。
- 嵌套循环走的就是搜索树；只讨论纯的、有限的搜索。剩余工作藏在哪里先放一放，先看搜索交出了什么。

## 1 表

### 1.1 遍历搜索

- 问题：给定边长范围，找出所有直角三角形。
- 造：`ℕ⁺`、`Triangle`、`pyth?`；`for*/list` 版 `right-triangles`；1 到 20 的六组结果；试了 1540 组。
- 造：纯函数可以缓存：`Dictionary`、`Bounds`、`cache`、`right-triangles/cached`；三次调用后的 `cache`（点出序对的点）。
- 认：键不重复，值是装着全部答案的列表；把所有边界都算过，`cache` 是一张巨大的表，`right-triangles` 只剩查表（`dictionary->function`）；任何纯函数都可以看作以输入为键的表。
- 名字：表（不加英文，Noah 10/4）、缓存、`dictionary->function`。

### 1.2 关系

- 问题：`Dictionary` 的类型并不要求键唯一；放开限制，把表摊开。
- 造：`rows`：每组答案各配上边界，`(1 20)` 占六行，`(1 4)` 一行也没有。
- 认：行的先后无关，换成集合；用集合的写法描述 $R$，它是笛卡尔积的子集，即关系；纯函数对应的关系；N 元关系、二元关系。
- 造：`rows/5`，同一张表摊成五列，是五元关系；一元关系是子集；零元关系只有 {} 与 {()}。
- 认：谓词把这几种关系连在一起：作为函数是二元关系，让它交出 `#t` 的输入构成 N 元关系；在数学里，这种只回答输入在不在子集里的函数叫**特征函数**（characteristic function）；零参谓词对应两个零元关系。
- 名字：**关系**（relation）、**N 元关系**（N-ary relation）、**二元关系**（binary relation）、**谓词**（predicate）、**特征函数**（characteristic function）。

### 1.3 写不完的表

- 问题：谓词只能检查一行在不在表里，读不出数据；要按键查表。
- 造：自己写 `dict-ref`（`for/first`）与 `dict-ref*`（`for/list`）；`dictionary->function` 与 `table->relation`；在 `rows` 上试。
- 认：`(table->relation rows)` 的类型正是 `right-triangles` 的类型；摊开与收拢来回转换。
- 认：二元关系 $R ⊆ A × B$ 与函数 $A → P(B)$ 一一对应；程序里用列表代替集合，只能表示每个输入的行能有限列出的关系；字典与表来回转换但不是同构（`(1 4)` 这条「已查过但无答案」的记录，PR #151）。
- 认：表可能有无穷多行，程序只需问到哪行算哪行；**惰性**；在程序里表示关系靠函数。
- 名字：**幂集**（power set）$P(B)$、`table->relation`、**惰性**（lazy）。

## 2 循环里的时间线

### 2.1 藏在循环里的局部延续

- 问题（接开头放下的那件事）：循环里没有哪行写着剩余工作，它在哪里，怎样运行了许多次？
- 认：`let*` 与 `for*/list` 并排，每个绑定后面跟着一份剩余工作；区别在可归约式算出一个值还是一个序列。
- 认：与第四篇 `if` 相反，这里剩余工作写了一次运行二十次，一次搜索不止一条时间线。
- 造：三种写法并排：`let` 是 `(k e)`，`for/list` 是 `(map k e*)`，`for*/list` 是 `(append-map k e*)`；抽出 `choose/k`；用它摊开三层循环，结果相同。
- 认：最外层同一个 `k` 运行二十次；参数从左到右求值，一条路走到头再退回：回溯；同一组边界占几行，就有几条走通的时间线。
- 名字：`choose/k`、**回溯**（backtracking）。

### 2.2 擦除延续参数

- 认：摊开后的 `right-triangles` 是 CPS 程序，照第四篇编译器的办法，用 `shift` 在原处取出延续。
- 造：四行改写推导到 `(reset (let ([v (shift k (append-map k p*))]) body))`；起名 `choose`；三层 `reset` 的版本。
- 认：内层两个 `reset` 多余：按第三篇规约规则展开 `(k 3)`，用 `(reset (reset e)) = (reset e)`（回指第四篇化简时同样去掉内层 `reset`）。
- 造：只留一层 `reset` 的 `let*` 版，结果相同。
- 认：主体读起来是一次只有一个值的普通计算，归功于 `choose` 的类型；还剩两处专为搜索写的（包成单行列表或空列表、外层 `reset`）。
- 名字：`choose`。

### 2.3 不确定运算符 amb

- 造：拿掉那两处后想要的伪代码：`between`、`check`。
- 认：`between` 要返回许多次，`check` 要不返回，还要一层收集结果。
- 名字：**不确定计算**（nondeterministic computation）、**不确定运算符**（ambiguous operator）`amb`（McCarthy）、`in-amb`。
- 造：`amb`、`in-amb` 的三个交互例子；`for/amb`；用它们写出 `between`、`check`；`in-amb` 版 `right-triangles`，伪代码一字未改。
- 造：`amb`、`for/amb`、`for*/amb`、`in-amb` 各一行，由 `choose` 与 `reset` 定义；备选包 λ；`(amb)` 一次也不调用 `k`。
- 名字：`for/amb`、`for*/amb`。

## 3 关系成为箭头

### 3.1 二元关系的复合

- 认：`inclusive-range` 与 `right-triangles` 都是交出列表的函数，表示二元关系；`(inclusive-range l h) = (in-amb (between l h))`；有了 `amb`，普通写法的函数能表示每个输入只占有限多行的二元关系。
- 造：`pick-a`、`pick-b`、`pick-c`、`check-right` 用 `∘` 接成 `right-triangle`；四步逐条说明；`(right-triangles l h) = (in-amb (right-triangle (list l h)))`。
- 认：每一步是一张两列的表，表也能复合：首尾相连，遮住中间一列；`(1 2)` 的三行示例表。
- 认：二元关系复合的集合写法；「存在这样的 $y$」由 `amb` 兑现：有了 `amb`，函数的复合就是二元关系的复合；交出集合的函数写法 $(Q ∘ P)(x) = ⋃ \{Q(y) \mid y ∈ P(x)\}$。
- 名字：二元关系的复合。

### 3.2 关系的两种写法

- 问题：`amb` 是借来的，靠 `shift`、`reset` 做出，`between` 也不纯；纯的宿主里二元关系是什么样子？
- 认：回指第二篇借 `call/cc` 的同一个问题与回答（换箭头、配复合）。纯宿主记作 𝒞，添上 `amb` 的宿主记作 ℬ。
- 造：`→𝒞`、`→ℬ`、`inj`、`∘ℬ = ∘`。
- 认：要找的箭头早就有：交出列表的函数，记作 `→ℒ`。
- 造：`list->amb`、`scatter`（ℒ → ℬ）、`gather`（ℬ → ℒ）。
- 认：来回一趟回到原处，两种箭头同构（比的是列表，先后与重复算在内）；`inclusive-range = (gather between)`、`between = (scatter inclusive-range)`。
- 造：借同构把 ℬ 的复合搬过来定义 `∘ℒ`（回指第二篇借道逆否箭头搬运运算律）；两步情形逐行化简，依次经过本篇出现过的四种写法，到 `(append-map g (f x))`；不经 ℬ 直接在 𝒞 里定义 `∘ℒ`（`foldr append-map`；附录与 `code.rkt` 支持零支，一元上给出 `(λ (x) (list x))`）。
- 认：纯宿主里，二元关系是交出列表的函数，用 `append-map` 接起来，正是上一节取并的式子；`let*` 是 `∘ℬ`，`for*/list` 是 `∘ℒ`，两种箭头各有一种绑定写法。
- 造与认：将 `append-map` 柯里化得到 `(: flat-map (∀ (p q) (→ (→ℒ p q) (→𝒞 (Listof p) (Listof q)))))`（`(define flat-map (curry append-map))`），把 ℒ 的箭头搬回纯宿主 𝒞：`(∘ℒ g f) = (∘ (flat-map g) f)`，`(flat-map (∘ℒ g f)) = (∘ (flat-map g) (flat-map f))`，`(flat-map (λ (x) (list x))) = id`。
- 认（上半部收尾）：画出 𝒞、ℬ、ℒ 的方形图表（`𝒞 ──inj──→ ℬ ⇄ ℒ ──flat-map──→ 𝒞`），指出 ℬ 与 ℒ 之间是**交换图表**；纯函数 `f` 沿外圈经 `inj`、`gather`、`flat-map` 绕回 𝒞 正好得到 `(λ (xs) (map f xs))`。
- 练习：验证 `list->amb` 与 `choose` 是同一个函数。
- 名字：ℬ、ℒ、`→ℬ`、`→ℒ`、`inj`、`∘ℬ`、`∘ℒ`、`list->amb`、`scatter`、`gather`、`flat-map`、同构、图表、交换图表。

## 4 关系式编程

### 4.1 想要的写法

- 问题：`amb` 版里 `between` 是取、`pyth?` 是查，用法不同，描述的却是同一类东西；取与查的分别来自函数，不来自关系。1.2 用集合语言写过直角三角形，能不能把集合语言逐字翻译成能运行的程序？
- 造：先写出集合语言的描述 $\{(a, b, c) \mid \text{between}(l, h, a) \wedge \text{between}(a, h, b) \wedge \text{between}(b, h, c) \wedge \text{pyth}(a, b, c)\}$，再逐字翻译为想要的写法：`betweenᵒ`、`pythᵒ`（`function->relation`、`predicate->relation`，上标 ᵒ 照 TRS 命名）与 `run*` 版 `right-triangles`（`run*` 是花括号，`(a b c)` 是竖线左边的形状，下面四行用 `∧` 连起同时成立的条件）。
- 结尾留下两个问题：没有了绑定，`a`、`b`、`c` 是什么？一行 `(betweenᵒ l h a)` 写在那里，又交出了什么？
- 名字：`betweenᵒ`、`pythᵒ`、`function->relation`、`predicate->relation`、`run*`。

### 4.2 未知项、代换与目标

- 问题：回答 4.1 结尾的两个问题，从类型的角度把语言核心逼出来。
- 造与认：
  - **未知项、数据、项与代换**：`var`（带 `#:type-name Var`）、`Literal`、`Data`、`Term`、`Substitution`（`(Dictionary Var Term)`）；只查一次表的 `(: value-of (→ Term Substitution Term))`，运行成功与报错两例，命名**代换**（substitution）；演示 `assq` 按身份找键。
  - **目标**：`(define-type Goal (→ℬ Substitution Substitution))`，是代换与代换之间的二元关系（旁注：也可写成 `→ℒ`，复合换 `∘ℒ`）。
  - **谓词与关系的类型对照**：`(→ Data ... Boolean)` vs `(→ Term ... Goal)`。
  - **代换层的运算与单位（按 `∧ → ⊤ → ⊥ → ∨` 顺序收齐）**：
    1. **合取 `∧`**：目标的复合 `∘ℬ`（倒序传入以按书写顺序运行）。
    2. **真 / 成功 `⊤`**：零个目标 `(∧)` 即恒等函数 `id`，作为二元关系是**恒等关系**，是合取的**单位**，对应零元关系 `{()}`。
    3. **假 / 失败 `⊥`**：另一个零元关系 `{}`，作为二元关系是**空关系**，带 `amb` 时即 `(amb)`（旁注：借用前四章的逻辑记号 `⊤`、`⊥` 表示 `Goal`）。
    4. **析取 `∨`**：两个目标都是同一笛卡尔积的子集，并集仍是子集，带 `amb` 时用 `list->amb` 合并分支（旁注：ℒ 箭头里是接起代换列表）；零个目标 `(∨)` 正好是 `⊥`，`⊥` 是析取的单位。
  - **写出 `run*`**：造未知项、从空代换开始运行目标 `g`、`in-amb` 收齐并用 `value-of` 读出。
- 名字：**未知项**、`Data`、**项**（term）、**代换**（substitution）、**目标**（goal）、`value-of`、`∧`、**恒等关系**（identity relation）、**单位**（unit）、`⊤`、**空关系**（empty relation）、`⊥`、`∨`。

### 4.3 跑起来

- 造：先手写单行目标 `g`，用 `in-amb` 看三张代换，再交给 `run*` 验证读出三组答案。
- 造：写出极简版 `function->relation`（默认最后一个位置是还没值的未知项，直接添一行）与 `predicate->relation`，内核对应 `code.rkt` 的 `rel-min` 子模块。
- 认：4.1 的伪代码原样跑通，还是那六组；直接看四行条件接成的目标交出的六张代换，收在「用 `value-of` 读出来」，不提前揭短。

## 5 复合与合一

### 5.1 在关系语言里复合

- 问题：函数世界有 `∘`，ℬ 与 ℒ 有 `∘ℬ` 与 `∘ℒ`，换到关系语言，两个二元关系怎样复合？
- 认：照集合复合 `{(x, z) | ∃y, (x, y) ∈ P ∧ (y, z) ∈ Q}` 去复合两个二元谓词（特征函数）`P?` 与 `Q?`，会卡在「存在这样的 `y`」上。
- 造：引入局部未知项宏 `(∃ (x ...) g)`，逐字翻译出二元复合 `(: ∘ᵒ (→ (→ Term Term Goal) (→ Term Term Goal) (→ Term Term Goal)))`。
- 练习：将二元 `∘ᵒ` 扩充成接收一个或多个二元关系的版本（下文直接使用多参数版本，附录收完整定义）。
- 造与认：把 `right-triangle` 的四步搬成 `pick-aᵒ`、`pick-bᵒ`、`pick-cᵒ`、`check-rightᵒ`，用 `∘ᵒ` 接成 `right-triangleᵒ` 并跑出六组；并排三种世界的复合与绑定写法（`let*`/`∘ℬ`、`for*/list`/`∘ℒ`、`∃`+`∧`/`∘ᵒ`）。
- 问题（引导寻找 `∘ᵒ` 的单位并引出合一）：
  - 复合的单位应表示「两个位置完全一样」。
  - 试 `(define idᵒ (function->relation id))`：左边已知行得通，`(idᵒ x 5)` 与 `(∧ (idᵒ x y) (idᵒ y 5))` 报错。
  - 试 `(define equalᵒ (predicate->relation equal?))`：`(equalᵒ 5 5)` 通过，两头任意换成未知项都报错。
  - 统一揭示根因：借来的函数与谓词骨子里仍分输入和输出，只能算已经知道的值；倒问 `(right-triangleᵒ b '(3 4 5))` 报错与把 `pythᵒ` 挪到前面报错同理。关系复合的单位没法借来，得在关系语言里自己做。
- 名字：`∃`、`∘ᵒ`、`idᵒ`、`equalᵒ`。

### 5.2 合一

- 造与认：
  - **顺着查表 `walk`**：把 `x` 等于 `y`、`y` 等于 5 记进表里，`value-of` 只查一次读出未知项 `y`；造出 `walk` 顺着查到底。
  - **合一 `unify`**：两边先各自 `walk` 到底再对称比对（含序对逐项去对），实测三例后命名**合一**（unification）。代换的一行从「未知项的值」变成「一条等式」。
  - 造出 `(≡ u v)`；升级 `(: value-of (→ Term Substitution Data))` 为顺着查并递归读序对；实测三例。
  - 认出 `∘ᵒ` 的单位正是合一：`(: idᵒ (→ Term Term Goal)) (define idᵒ ≡)`，验证 `(idᵒ q 5)` 与 `(idᵒ 5 q)` 双向可问。
  - 现抓现修 `function->relation`：展示直接添一行在 `(∧ (betweenᵒ 1 2 a) (betweenᵒ 2 3 a))` 与 `(betweenᵒ 1 3 2)` 上出错，改用 `unify` 后两例与 `(betweenᵒ 1 3 5)` 全跑通。
- 名字：`walk`、`unify`、**合一**（unification）、`≡`。

### 5.3 直接写等式

- 问题：有了 `≡`、`∧`、`∨`、`∃` 和 `⊤`、`⊥`，不借函数和谓词，直接写出递归的关系。
- 造与认：一气呵成写出三元关系 `appendᵒ`（说明 `∃` 延迟构造未知项以保证递归停止）；正着问与 `append` 一样，反着问 `(run* (x y) (appendᵒ x y '(1 2 3)))` 拆出全部四种分法，展示关系不分输入输出。
- 旁注：答案含未绑定未知项时的打印（`walk*` 与 `reify`）和循环等式检查（`occurs?` 与 `ext-s`）收入附录。
- 认（收束与揭晓）：总结三种运算与单位（代换层 `∧`/`⊤`、`∨`/`⊥`，关系层 `∘ᵒ`/`≡`）；揭晓这六个记号与不到一百行的骨架就是 **microKanren**，**关系式编程**（**逻辑式编程**的一个分支）语言 **miniKanren** 的极小内核，未知项在那里叫**逻辑变量**（旁注：与常见流实现的差异）。
- 名字：**关系式编程**（relational programming）、**逻辑式编程**（logic programming）、**逻辑变量**（logic variable）、microKanren、miniKanren。

## 6 结论（`8-conclusion.scrbl`）

- 复盘整章路线：表 → `amb`（ℬ）与 `append-map`（ℒ）→ 关系式编程（用 ℬ 的箭头造出的语言，但描述的东西不再是函数）。
- 点题「平行世界」：搜索里同时展开的许多条时间线，也是 ℬ、ℒ 与关系语言这几个世界。
- 未解的线索：两问：
  1. 1.1 缓存的 `set!` 与本章未知项按身份区分的新名字都超出了纯函数范围，纯宿主里状态和新身份从哪里来？
  2. 第二章的 `𝒟`/`𝒦` 与本章的 `ℬ`/`ℒ` 走的是同一条路（换箭头、配复合、配绑定写法），背后是否藏着同一个结构？

## 附录：库代码（`9-appendix.scrbl`）

- 收正文造出的库代码，不收例子（直角三角形、`appendᵒ`）：
  - `amb` 一族：`choose`、`amb`、`for/amb`、`for*/amb`、`in-amb`、`check`；
  - 关系的两种写法：`→𝒞`、`→ℬ`、`→ℒ`、`inj`、`∘ℬ`、`list->amb`、`scatter`、`gather`、`∘ℒ`、`flat-map`（`(curry append-map)`）；
  - 关系语言：`var`、`Literal`、`Data`、`Term`、`Substitution`、`Goal`、`walk`、`walk*`、`occurs?`、`ext-s`、`unify`、`value-of`、`reify`、`⊤`、`⊥`、`≡`、`∧`、`∨`、`∃`、`run*`、`function->relation`、`predicate->relation`、`idᵒ`、`∘ᵒ`（多参数 `case-λ` 版）。
