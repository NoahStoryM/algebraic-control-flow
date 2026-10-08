#lang typed/racket/no-check
;;; 第五篇正文代码（按正文出现顺序；全篇九节，v5.1）
;;; 依据：art5-plan.md v5.1（2026-10-02）、定稿中文第一至四篇
;;; 运行：raco test art5-code.rkt
;;; 第六篇（单子）的代码在 art6-code.rkt。
;;;
;;; 约定
;;; ・每段代码前的标题行写作「§节-编号〔用途〕 标题」：
;;;     〔正文〕       读者会看到的代码
;;;     〔正文·数据〕 正文里展示的数据；算出它的代码不进正文
;;;     〔正文·数学〕 正文以公式块给出，不是代码；紧跟其后的检查验证它
;;;     〔正文·等式〕 正文里的代码等式，本身不运行；紧跟其后的检查验证它
;;;     〔正文·伪代码〕 §3、§4 假想语言的代码；以注释写出，§8 用同样的文本真的运行
;;;                   （test 子模块逐个比对两处读成的 S 表达式；不是逐字比对，也不检查 Markdown 正文）
;;;     〔验证〕       只用于验证，不进正文
;;;     〔前文〕       前四篇的原样定义，正文不重复展示
;;;   每节开头的「带走」抄自大纲：读者在这一节带走的认识，不超过三条。
;;;   「步骤」标出它在「问题 → 代码 → 现象 → 概念」中的位置；
;;;   「回指」标出前文对应处（只列正文可能用到的，最终取舍写散文时定）。
;;; ・〔正文〕块写成 (check-equal? 表达式 结果) 时，正文取第一个参数，
;;;   第二个参数就是正文里 ;; => 注释给出的结果。
;;; ・类型标注只作设计说明，不经类型检查（与前四篇一致）。
;;; ・本篇只讨论纯的、有限的搜索（整个搜索过程能够完成）。
;;; ・同名函数在正文里出现多次（right-triangles）时，本文件按出现顺序加下标（₁ 到 ₈），正文仍用原名。
;;; ・用词（大纲「用词规则」）：「表」只指关系的表；程序交出的是「列表」；
;;;   缓存「记下每个 (l h) 对应的答案列表」，不叫它表。注释也照此写。

(require rackunit
         (except-in racket/control abort))   ; abort 用第三篇自己的定义


;;; ═══════════════════════════════════════════════════════════════════
;;; §0〔前文〕 前四篇的原样定义（第五篇只用到这两个）
;;; ═══════════════════════════════════════════════════════════════════
;;; 第二篇「完整代码参考」与第三篇「定界延续」，逐字。其余前文定义随第六篇移到 art6-code.rkt。

(define ∘ compose)

;; match-λ：第四篇用过。新版本的 racket/match 自带；这个环境是 Racket 8.10，还没有，这里补一个同义的写法。
(define-syntax-rule (match-λ clause ...) (match-lambda clause ...))

(define (abort . v*) (shift _ (apply values v*)))

;;; ─── §0′〔验证〕 期望结果与参照实现（各节的验证块共用） ───
(define triples '((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20)))

;; 用集合写的关系，作独立的参照：关系 r 表示成「元素 → 它关联到的元素集合」。
(define ((rel∘ s r) x) (for*/set ([y (in-set (r x))] [z (in-set (s y))]) z))
(define (rel:id x) (list->set (list x)))
(define ((as-rel f) x) (list->set (f x)))       ; 列表世界的箭头读作关系
(define (forget p*) (list->set p*))             ; 忘掉顺序与重数
;; 验证用的样例箭头（divisors 只用于验证，不进正文）
(define (divisors n)
  (filter (λ (d) (zero? (remainder n d))) (range 1 (add1 n))))
(check-equal? (divisors 4) '(1 2 4))


;;; ═══════════════════════════════════════════════════════════════════
;;; §1 遍历搜索
;;; ═══════════════════════════════════════════════════════════════════
;;; 带走：1. 三层循环逐个生成候选，条件筛掉不成立的组合。
;;;       2. 子句之后的代码只写了一次，却为每个备选各运行一次，也可以一次都不运行（过滤）。
;;;          一次搜索里有不止一条时间线。
;;;       3. 所有答案接成一张列表。
;;; 只讲现象：剩余工作 k 到 §6 才取出来。第 2 条是系列的钩子，不能删。
;;; v5.1（10/2，Noah 提出，Claude 定）：let* 与 for* 的类比不放在开头，搬到 §6 作「认出剩余工作」的入口；
;;;       §1 的钩子改为与开篇 if 的对照：那里「未来写了两次，运行了一次」，这里写了一次，运行了许多次。

;;; ─── §1-a〔正文〕 嵌套循环枚举勾股数：给定边长范围，交出所有直角三角形 ───
;;; 步骤：问题 → 代码
;;; 回指：第四篇「未解的线索」的「搜索树」；第二篇 fact / fib 的类型写法
;;; 写成函数 (right-triangles l h)，边界 l、h 作参数；范围用 inclusive-range（列表，含两端）。
;; 10/3（Noah）：Triangle 的定义放在第一个代码块，right-triangles 的类型随之写短；Bounds 到用到它的第二个代码块才定义。
;; 10/3 傍晚（Noah）：给 Positive-Integer 起名 ℕ⁺，类型读起来就是笛卡尔积：(List ℕ⁺ ℕ⁺ ℕ⁺) 即 ℕ⁺×ℕ⁺×ℕ⁺。
(define-type ℕ⁺ Positive-Integer)
(define-type Triangle (List ℕ⁺ ℕ⁺ ℕ⁺))

(: pyth? (→ ℕ⁺ ℕ⁺ ℕ⁺ Boolean))
(define (pyth? a b c) (= (+ (* a a) (* b b)) (* c c)))

;; 边长的上下界取正整数（9/30：下界为 0 会收进 (0 1 1) 这类退化三角形）
(: right-triangles (→ ℕ⁺ ℕ⁺ (Listof Triangle)))
(define (right-triangles l h)
  (for*/list ([a (inclusive-range l h)]
              [b (inclusive-range a h)]
              [c (inclusive-range b h)]
              #:when (pyth? a b c))
    (list a b c)))

(check-equal? (right-triangles 1 20)
              '((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20)))

;;; ─── §1-b〔验证〕 正文散文说到的现象（不展示代码） ───
;;; 步骤：现象（子句之后的代码写了一次，为每个备选各运行一次）
;;; 回指：第四篇 if 分支「未来写了两次、运行了一次」（对照：这里每个备选都运行）
;; let* 之后的代码运行一次（§6-a 的对照用）
(let ([n 0])
  (let* ([a 3] [b 4] [c 5])
    (set! n (add1 n)))
  (check-equal? n 1))
;; [a …] 之后的代码运行 20 次，[b …] 之后的运行 210 次
(let ([after-a 0] [after-b 0])
  (for ([a (inclusive-range 1 20)])
    (set! after-a (add1 after-a))
    (for ([b (inclusive-range a 20)])
      (set! after-b (add1 after-b))))
  (check-equal? after-a 20)
  (check-equal? after-b 210))
;; [c …] 之后的代码为每组候选各运行一次：1 到 20 试了 1540 组，条件留下六组，拦下 1534 组
(let ([tried 0] [kept 0])
  (for* ([a (inclusive-range 1 20)]
         [b (inclusive-range a 20)]
         [c (inclusive-range b 20)])
    (set! tried (add1 tried))
    (when (pyth? a b c) (set! kept (add1 kept))))
  (check-equal? tried 1540)
  (check-equal? kept 6)
  (check-equal? (- tried kept) 1534))
;; 正文的算式（v5.4，Noah 定）：C(20+3-1, 3) = 1540，从 20 个数里可重复地取 3 个（a ≤ b ≤ c）。
;; 按循环的顺序数：最短边 a 取 1 到 20 时各试 210、190、171、…、1 组，合计也是 1540。
(let ([per-a (for/list ([a (inclusive-range 1 20)])
               (for*/sum ([b (inclusive-range a 20)]
                          [c (inclusive-range b 20)])
                 1))])
  (check-equal? (take per-a 3) '(210 190 171))
  (check-equal? (last per-a) 1)
  (check-equal? (apply + per-a) 1540)
  (check-equal? (/ (* 22 21 20) (* 3 2 1)) 1540))                ; C(22, 3)
;; 也可以一次都不运行：范围是空的，或者 #:when 一组也没有放过
(check-equal? (right-triangles 5 4) '())
(check-equal? (right-triangles 1 4) '())
;; 先把 a = 1 下面的 b、c 试完，才轮到 a = 2（深度优先）
(check-equal? (for*/list ([a (inclusive-range 1 2)]
                          [b (inclusive-range a 2)]
                          [c (inclusive-range b 2)])
                (list a b c))
              '((1 1 1) (1 1 2) (1 2 2) (2 2 2)))


;;; ═══════════════════════════════════════════════════════════════════
;;; §2 关系
;;; ═══════════════════════════════════════════════════════════════════
;;; 带走：1. 同样的边界总得到同一张列表，所以结果可以按边界记下来（缓存）。
;;;       2. 把记下的列表摊开，每组答案配上它的边界，得到一行行的表；
;;;          同一个边界可以出现多次，也可以不出现。
;;;       3. 表里的每一行满足同一组条件。这样的表，数学上叫做关系。
;;; 措辞：「纯函数可以用表来表示，也因此可以缓存」，不说「纯函数就是查表」，不谈性能。
;;; 开场保留 Noah 改过的那段（right-triangles 交出的是装有全部答案的容器；它仍是一个函数）。
;;; 本节没有伪代码；不出现「单子」，不提 miniKanren。

;;; v5.4（10/3，Noah）：§2-a（带缓存的版本、缓存的内容）在正文里属于第一节后半，第一节到「任何纯函数都可以看作
;;;       一张以输入为键的表」为止；§2-b（摊开）起属于第二节：摊开、认出二元关系、函数是特例、多元关系、共同条件、
;;;       集合记号。代码的编号暂不动，合并时再统一。

;;; ─── §2-a〔正文〕 带缓存的版本：缓存是一张关联列表，每行是一个序对（边界 . 答案列表） ───
;;; 步骤：动机（每调用一次都要重试 1540 组；同样的边界总得到同一张列表）→ 代码 → 运行 → 看缓存
;;; v5.4（10/3 下午，Noah）：缓存的代码进正文，用关联列表（不用哈希表）：打印出来就是一行行的表；
;;;       缓存是一张「列表」，装着函数那张「表」里算过的几行。
;;;       每行用序对（不用两个元素的列表）：(Pair a (List b c)) 就是 (List a b c)，02 靠它从二元关系引出多元关系。
;;;       类型构造子 Dict（14:22，Noah）：关联列表在 racket/dict 里就是字典，键不重复；用 dict-has-key?、dict-set、dict-ref、
;;;       in-dict，不手写 assoc 与 cons。dict-set 把新的一项添在末尾，所以 cache 按调用的先后排列。
;;;       racket/dict 在 typed/racket/no-check 下直接可用；真的 #lang typed/racket 里它没有类型。
;;;       正文展示结果时把序对的点写出来（((1 5) . ((3 4 5)))），读进来是同一个值；Racket 实际打印时没有点，02 再揭开。
(define-type (Dict k v) (Listof (Pair k v)))
(define-type Bounds (List ℕ⁺ ℕ⁺))

(: cache (Dict Bounds (Listof Triangle)))
(define cache '())

;; 10/3 傍晚（Noah）：试过把参数写成 . l×h，19:05 又改回 (l h) 加 (define l×h (list l h))。
(: right-triangles/cached (→ ℕ⁺ ℕ⁺ (Listof Triangle)))
(define (right-triangles/cached l h)
  (define l×h (list l h))
  (unless (dict-has-key? cache l×h)
    (set! cache (dict-set cache l×h (right-triangles l h))))
  (dict-ref cache l×h))

;; 〔正文〕依次用三组边界调用，再看缓存（期望值照正文的写法带点）
(check-equal? (right-triangles/cached 1 4) '())
(check-equal? (right-triangles/cached 1 5) '((3 4 5)))
(check-equal? (right-triangles/cached 1 20)
              '((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20)))

(check-equal? cache
              '(((1 4)  . ())
                ((1 5)  . ((3 4 5)))
                ((1 20) . ((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20)))))

;;; §2-a′〔验证〕 带缓存的版本对外仍是同一个函数；找得到就不再添，所以每个边界恰好占一行（边界是键）
(check-equal? (right-triangles/cached 1 20) (right-triangles 1 20))
(check-equal? (right-triangles/cached 1 5)  (right-triangles 1 5))
(check-equal? (length cache) 3)
(check-equal? (length (remove-duplicates (map car cache))) 3)
(check-eq?    (right-triangles/cached 1 20) (right-triangles/cached 1 20))   ; 第二次是取出来的，没有重算
(check-true   (dict? cache))                                                 ; 关联列表就是字典
;; 摊开以后边界不再是键：库仍把 rows 当字典收下，但 dict-ref 只取得到第一行（检查在 §2-b″）

;;; ─── §2-a″〔正文〕 第一节的结尾：字典变回函数，调用就是按键查表（10/3 傍晚，Noah 改写） ───
;;; 正文里写的是 (define right-triangles (dictionary->function cache))，重新定义了同名函数；文件里记作 right-triangles₀。
;;; 类型：函数体用了 . key（各个参数合起来才是键），所以是 (∀ (v k ...) (→ (Dict (List k ... k) v) (→ k ... k v)))；
;;;       这个写法在真的 #lang typed/racket 里验证过，Noah 19:05 采用。
(: dictionary->function (∀ (v k ...) (→ (Dict (List k ... k) v) (→ k ... k v))))
(define ((dictionary->function dict) . key) (dict-ref dict key))

(define right-triangles₀ (dictionary->function cache))

;; 〔验证〕算过的三组与 right-triangles 一致；没算过的查不到
(for ([l×h '((1 4) (1 5) (1 20))])
  (check-equal? (apply right-triangles₀ l×h) (apply right-triangles l×h)))
(check-exn exn:fail? (λ () (right-triangles₀ 1 13)))

;;; ─── §2-b〔正文〕 摊开：每组答案配上它的边界，值里的那层 Listof 分到了各行 ───
;;; 步骤：代码 → 数据（缓存里边界不重复；摊开以后同一个边界可以占好几行，也可以一行不占：边界不再是键）
(: rows (Listof (Pair Bounds Triangle)))
(define rows
  (for*/list ([(l×h t*) (in-dict cache)]
              [t t*])
    (cons l×h t)))

(check-equal? rows
              '(((1 5)  . (3 4 5))
                ((1 20) . (3 4 5))
                ((1 20) . (5 12 13))
                ((1 20) . (6 8 10))
                ((1 20) . (8 15 17))
                ((1 20) . (9 12 15))
                ((1 20) . (12 16 20))))

;;; §2-b″〔验证，02 用〕 (x . (y z)) 就是 (x y z)：同一行，读成序对是二元，读成四项的元组是多元
(check-equal? (cons '(1 20) '(3 4 5)) (list '(1 20) 3 4 5))
(check-equal? rows '(((1 5) 3 4 5) ((1 20) 3 4 5) ((1 20) 5 12 13) ((1 20) 6 8 10)
                     ((1 20) 8 15 17) ((1 20) 9 12 15) ((1 20) 12 16 20)))
;; rows 里同一个键占了好几行，dict-ref 只取得到第一行
(check-equal? (dict-ref rows '(1 20)) '(3 4 5))
;; 02 正文（19:17 版）只用一句话说：((1 20) . (3 4 5)) 打印出来是 ((1 20) 3 4 5)
(check-equal? (format "~s" '((1 20) . (3 4 5))) "((1 20) 3 4 5)")
(check-equal? '(a . (b c)) '(a b c))
;; Racket 实际打印时没有点（15:40 到 19:05 的几稿把 rows 不带点再展示一次；19:17 起正文不再展示）
(check-equal? (format "~s" rows)
              (string-append "(((1 5) 3 4 5) ((1 20) 3 4 5) ((1 20) 5 12 13) ((1 20) 6 8 10) "
                             "((1 20) 8 15 17) ((1 20) 9 12 15) ((1 20) 12 16 20))"))
(check-equal? (format "~s" (first rows))  "((1 5) 3 4 5)")
(check-equal? (format "~s" (first cache)) "((1 4))")
(check-equal? (format "~s" (second cache)) "((1 5) (3 4 5))")
;; 笛卡尔积的结合律是「一一对应」：((l h) . (a b c)) 对应 (l h a b c)，R 也是五元关系。
;; Racket 里只有向右加括号是字面相等（列表就是这样的序对）；左边的边界仍是一项，五个数一行要真的转换
(check-equal? (map (λ (r) (append (car r) (cdr r))) rows)
              '((1 5 3 4 5) (1 20 3 4 5) (1 20 5 12 13) (1 20 6 8 10)
                (1 20 8 15 17) (1 20 9 12 15) (1 20 12 16 20)))

;;; ─── §2-b‴〔验证；19:30 起不进正文〕 把列一列一列填上，项数降到一元、零元 ───
;;; 15:52 到 19:25 的几稿把这一块放在第二节结尾；Noah 19:30 决定删去，正文只用一句话提一元、零元关系。
;;; fill：把每行读成序对，只留下左边等于 v 的行，再去掉左边这一项。交出的 (Listof b) 里，b 往往又是序对，
;;;       所以还能接着填：四元 → 三元 → 二元 → 一元 → 零元。零元关系只有两张表：'(())（是）与 '()（否）。
(: fill (∀ (a b) (→ (Listof (Pair a b)) a (Listof b))))
(define (fill table v)
  (for/list ([row table] #:when (equal? (car row) v))
    (cdr row)))

(check-equal? (fill rows '(1 20))
              '((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20)))
(check-equal? (fill (fill rows '(1 20)) 3) '((4 5)))
(check-equal? (fill (fill (fill rows '(1 20)) 3) 4) '((5)))
(check-equal? (fill (fill (fill (fill rows '(1 20)) 3) 4) 5) '(()))
(check-equal? (fill (fill (fill (fill rows '(1 20)) 3) 4) 6) '())
;; 〔验证〕填上边界，正是 right-triangles 交出的列表；没有对得上的行就是空表
(check-equal? (fill rows '(1 20)) (right-triangles 1 20))
(check-equal? (fill rows '(1 5))  (right-triangles 1 5))
(check-equal? (fill rows '(1 4))  '())

;;; §2-b′〔验证〕 (1 4) 一行也没有，(1 20) 出现六次
(check-equal? (count (λ (r) (equal? (car r) '(1 4)))  rows) 0)
(check-equal? (count (λ (r) (equal? (car r) '(1 5)))  rows) 1)
(check-equal? (count (λ (r) (equal? (car r) '(1 20))) rows) 6)

;;; ─── §2-c〔正文·数学〕 这些行的共同条件：集合记号（正文为公式块；放 §2 还是 §3 开头见待定 3） ───
;;; 步骤：概念（表里的每一行满足同一组条件；这样一张表，数学上叫做关系）
;;;   right-triangles(l, h) = { (a, b, c) ∣ l ≤ a ≤ h ∧ a ≤ b ≤ h ∧ b ≤ c ≤ h ∧ a² + b² = c² }
;;; 散文：「暂且不计列表的顺序和重复」；四个条件与 §1 for*/list 的三个子句加 #:when 一一对应；
;;;       pyth? 只说它检查三个数满不满足最后一个条件。
;;; 节尾：缓存只记下算过的边界，没算过的还得跑那三层循环。
;;;       能不能只写下这些行要满足的条件，让语言去把行找出来？
;; 每一行都满足这四个条件
(for ([r rows])
  (match-define (list (list l h) a b c) r)                         ; 每行读成四项的元组
  (check-true (and (<= l a h) (<= a b h) (<= b c h) (pyth? a b c))))
;; 反过来，满足条件的也都在交出的列表里（多组边界，每组汇总成一次比较）
(for* ([l (in-range 1 4)] [h (in-range 1 21)])
  (check-equal? (for*/set ([a (in-inclusive-range 0 (add1 h))]
                           [b (in-inclusive-range 0 (add1 h))]
                           [c (in-inclusive-range 0 (add1 h))]
                           #:when (and (<= l a h) (<= a b h) (<= b c h) (pyth? a b c)))
                  (list a b c))
                (forget (right-triangles l h))))


;;; ═══════════════════════════════════════════════════════════════════
;;; §3 描述关系的语言
;;; ═══════════════════════════════════════════════════════════════════
;;; 带走：1. 在这门语言里，关系的参数可以暂时未知；关系作用在参数上得到一个目标，
;;;          条件留下来，和其他条件一起求解。
;;;       2. 数学记号与这门语言的写法逐项对上（四行）。
;;;       3. 第一版程序：run* 找出满足所有目标的行，收进列表。
;;; 10/3 21:54 起的写法（Noah）：从谓词的限制说起（函数只能按键查，找行是反过来查）→ 把 Boolean 换成 Goal
;;;       （pyth? 与 pythᵒ 的类型并排）→ 对照表三行（关系作用在项上、∧、run*）→ 把 §2 的 R 给定边界后的三元式子
;;;       照表翻译成第一版。直接点名 miniKanren。程序在 §8-e 原样运行，正文说明结果是实现以后跑出来的。
;;; （旧）尽早给出第一版。目标只在这里完整解释一次（一两句）。以「一门假想的语言」介绍，§8 之前不点名 miniKanren。
;;; 伪代码不在本节运行；§8 用同样的文本真的运行（结果注释取自 §8）。
;;; 不放：零元、一元关系与「填列」的推导（创作者笔记；素材在文末「附」）。

;;; ─── §3-0〔正文〕 谓词的表（Noah 10/3 21:12、21:15） ───
;;; 步骤：概念（集合记号里竖线右边的条件，写成代码就是谓词；谓词是纯函数，所以也是一张以输入为键的表：
;;;       笛卡尔积里每个元素占一行，值是布尔值）→ 现象（值为 #t 的行是一个 N 元关系，值为 #f 的行是它的补，
;;;       合起来是整个笛卡尔积）→ 问题（谓词只回答是或否，找行要自己列候选：§1 的三层循环）
;; 10/4（Noah）：正文 02 末尾的例子换成 Bit 上的 one?：表只有两行，可以整张列出来；
;; 类型里的 : One 说的是「结果为真，当且仅当输入属于 One」，正是子集的视角。
;; 注意：函数体不能写 (= b 1)。带检查的 Typed Racket（8.10）拒绝它：= 只给出「为真时 b 是 One」，
;; 给不出「为假时 b 不是 One」（expected ((: b One) | (! b One))，given ((: b One) | Top)）；eq? 同样被拒。
;; eqv?、equal?、(not (zero? b))、(positive? b)、(make-predicate One) 都能通过。8.10 的 Typed Racket 里 ∪ 没有绑定，
;; 核对时写的是 U；Noah 的 demo.rkt 用的就是 ∪，他那边的版本有。
(define-type Bit (∪ Zero One))

;; 09:35（Noah）：类型把真假两头都写出来，与正文里的 One ≔ {1}、Zero ≔ {0} 对照。
;; 带检查的 Typed Racket（8.10）接受它配 eqv?、equal?、(not (zero? b))；配 (= b 1) 仍然被拒。
(: one? (→ Bit Boolean : #:+ One #:- Zero))
(define (one? b) (eqv? b 1))

(check-equal? (for/list ([b '(0 1)])
                (cons b (one? b)))
              '((0 . #f)
                (1 . #t)))

;; 旧例子（10/3 的正文；现在只作验证）：pyth? 的表里取四行
(define pyth?-rows
  (for/list ([c (inclusive-range 4 7)])
    (cons (list 3 4 c) (pyth? 3 4 c))))
(check-equal? pyth?-rows
              '(((3 4 4) . #f)
                ((3 4 5) . #t)
                ((3 4 6) . #f)
                ((3 4 7) . #f)))

;;; §3-0′〔验证〕 真的行与假的行各是一个三元关系，合起来是整个笛卡尔积（取 1..12 这一块）
(let* ([product (for*/set ([a (in-inclusive-range 1 12)]
                           [b (in-inclusive-range 1 12)]
                           [c (in-inclusive-range 1 12)])
                  (list a b c))]
       [table   (for/list ([t product]) (cons t (apply pyth? t)))]   ; 每个元素恰好占一行
       [yes     (for/set ([r table] #:when (cdr r))       (car r))]
       [no      (for/set ([r table] #:when (not (cdr r))) (car r))])
  (check-equal? (length table) (* 12 12 12))
  (check-equal? (set-union yes no) product)
  (check-true   (set-empty? (set-intersect yes no)))
  (check-equal? yes (list->set '((3 4 5) (4 3 5) (6 8 10) (8 6 10)))))

;;; §3-0″〔验证〕 零个参数的谓词只有两个，对应两个零元关系 {()} 与 {}；一个参数的谓词对应子集
;;; 不带参数的函数，它的表只有一行，键是空的元组 ()：值为 #t 时真的行是 '(())，值为 #f 时是 '()。
(check-equal? ((λ () #t)) #t)
(check-equal? ((λ () #f)) #f)
(check-equal? ((dictionary->function '((() . #t)))) #t)              ; §2-a″ 的表与函数：零个参数
(check-equal? ((dictionary->function '((() . #f)))) #f)
(check-equal? (for/list ([r '((() . #t))] #:when (cdr r)) (car r)) '(()))
(check-equal? (for/list ([r '((() . #f))] #:when (cdr r)) (car r)) '())
(check-equal? (for/set ([n (in-inclusive-range 1 10)] #:when (even? n)) n)
              (list->set '(2 4 6 8 10)))                                    ; 一元：谓词 even? 与 1..10 的子集

;;; ─── §3-a〔正文·伪代码〕 第一版：照着集合记号逐项翻译 ───
;;; 步骤：问题（§2 节尾：只写条件，让语言去找）→ 代码（对照表四行：
;;;         l ≤ a ≤ h        ↔ (betweenᵒ l a h)
;;;         a² + b² = c²     ↔ (pythᵒ a b c)
;;;         并列的条件 ∧      ↔ 并列的几个目标
;;;         {(a, b, c) ∣ …}  ↔ (run* (a b c) …)，交出时排成列表）
;;;       → 现象（run* 找出所有满足目标的行，收进列表，与 §1 交出同一张列表）
;;; 散文：这门语言里的关系，名字都以 o 结尾。pythᵒ 与 pyth? 参数完全相同，
;;;       交出的不是 Boolean 而是目标（是否并排给一行类型见待定 2）。
;;;       不承诺单个关系能反向求解（§8 的 pythᵒ 要求三个数已确定）。
;;;       至多一句「熟悉 SQL 的读者会觉得眼熟」（待定 7）。
;;; 22:17（Noah）：链不拆，直接写 (≤ᵒ l a b c h)；pythᵒ 不给定义，直接用。≡ 仍是合一，不做算术。
;; 〔验证〕 谓词的写法只能检查给定的一行：<= 本来就是变参的
(check-true  (and (<= 1 3 4 5 20) (pyth? 3 4 5)))
(check-false (and (<= 1 3 4 6 20) (pyth? 3 4 6)))
;;; 10/4（Noah）：关系名的后缀照《The Reasoned Schemer》的排印写成上标：-o → ᵒ，-e → ᵉ，-u → ᵘ。
;;;   ≤ → ≤ᵒ，pytho → pythᵒ；列表世界与关系模块里的 pick-aᵒ、pick-bᵒ、pick-cᵒ、rightᵒ、right-triangleᵒ、betweenᵒ、swapᵒ 一并改名。
;;;   以后：关系的复合写 ∘ᵒ（现在代码里还是 ∘ℛ），conde 若用到写 condᵉ。
;;; ┌伪代码 a
;;; (define (right-triangles l h)
;;;   (run* (a b c)
;;;     (≤ᵒ l a b c h)      ; l ≤ a ≤ b ≤ c ≤ h
;;;     (pythᵒ a b c)))     ; a² + b² = c²
;;; └
;;; (right-triangles 1 20)
;;; ;; => ((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20))


;;; ═══════════════════════════════════════════════════════════════════
;;; §4 关系的复合
;;; ═══════════════════════════════════════════════════════════════════
;;; 带走：1. 要把关系接起来，得分清哪头接哪头：把列分成两组，就是二元关系；
;;;          函数是每个输入恰好对应一个输出的特例。
;;;       2. 复合的定义是「存在中间项」。只给两个谓词写不出通用的复合；这门语言写得出（fresh）。
;;;       3. 第二版程序是四段二元关系的复合，展开以后回到第一版。
;;; 准确性：right-triangleᵒ 是四个关系的复合，right-triangles 是外面那个查询函数；
;;;         不说「right-triangleᵒ 不分输入输出」（当前实现不能反向查询）。
;;; 收尾：run* 把答案收进列表，外面的 right-triangles 接收边界、交出列表。这样的函数怎样复合？（交给 §5）

;;; §4-0〔验证〕 分组与方向的素材（斜边 25 若用，只作举例）
;; 把 (a b c) 分成 (a b) 与 c 两组：从 (a b) 看，有解时斜边唯一
(for* ([a (in-range 1 40)] [b (in-range a 40)])
  (check-true (<= (length (for/list ([c (in-range 1 60)] #:when (pyth? a b c)) c)) 1)))
;; 从 c 看：斜边 25 对应两组直角边，不是函数
(check-equal? (for*/list ([a (in-range 1 25)] [b (in-range a 25)] #:when (pyth? a b 25)) (list a b))
              '((7 24) (15 20)))

;;; ─── §4-a〔正文〕 谓词形式的二元关系 ───
;;; 步骤：问题（选定一条边就确定了下一个选择的范围：按挑边的顺序拆成四个二元关系，再接起来）
;;;       → 概念（二元关系：把列分成两组；谓词给齐两组，回答这一行在不在表里）→ 代码
(define-type (→ℛ? x y) (→ x y Boolean))

(: right-triangle? (→ℛ? (List Positive-Integer Positive-Integer)
                        (List Positive-Integer Positive-Integer Positive-Integer)))
(define (right-triangle? l×h a×b×c)
  (match-define (list l h)   l×h)
  (match-define (list a b c) a×b×c)
  (and (<= l a b c h) (pyth? a b c)))

(check-equal? (right-triangle? '(1 20) '(3 4 5)) #t)
(check-equal? (right-triangle? '(1 20) '(4 3 5)) #f)   ; 不满足 a ≤ b
(check-equal? (right-triangle? '(1 4)  '(3 4 5)) #f)   ; 超出上界

;;; §4-a′〔验证〕 谓词与 right-triangles 描述同一个关系
;; §2-b 摊开的每一行都通过谓词
(for ([r rows]) (check-true (right-triangle? (car r) (cdr r))))
;; 通过谓词的行，恰是 right-triangles 交出的那些（每组边界汇总成一次比较）
(for* ([l (in-range 1 4)] [h (in-range 1 21)])
  (check-equal? (for*/list ([a (in-inclusive-range 0 (add1 h))]
                            [b (in-inclusive-range 0 (add1 h))]
                            [c (in-inclusive-range 0 (add1 h))]
                            #:when (right-triangle? (list l h) (list a b c)))
                  (list a b c))
                (right-triangles l h)))
;; 由交出列表的函数得到谓词，只需一次 member（创作者笔记：反过来还缺候选从哪里来）
(for* ([t '((3 4 5) (4 3 5) (5 12 13) (6 8 10))])
  (check-equal? (right-triangle? '(1 12) t) (and (member t (right-triangles 1 12)) #t)))

;;; ─── §4-b〔正文·类型〕 谓词的复合：只有类型，写不出 ───
;;; 步骤：概念（复合的定义：x 与 z 相关，当且仅当存在某个 y；函数能复合，关系也应当能）
;;;       → 现象（只给两个谓词，写不出通用的复合程序）
;;; 论证（Astra 收紧）：两个谓词都只接收中间项、不产生它，没有现成的办法把候选列出来；
;;;       有限范围里可以逐个试，但那是写程序的人在承担搜索（§1 的循环）。
;;   (: ∘ℛ? (∀ (x y z) (→ (→ℛ? y z) (→ℛ? x y) (→ℛ? x z))))

;;; ─── §4-c〔正文·伪代码〕 这门语言里的二元关系与复合：二元等式 ───
;;; 步骤：概念（关系作用在两组参数上得到目标；∃ 写作 fresh）
;;; 散文：fresh 只引入中间项，如何找到它交给目标的运行（fresh 本身不搜索）。
;;;       对照表补两行：∃y ↔ (fresh (y) …)；t₁ = t₂ ↔ (== t₁ t₂)。
;;;       == 只说「要求两个项相等」；「合一」到 §8 才出现。
;;; (define-type (→ℛ x y) (→ x y Goal))           ; 关系作用在参数上得到目标
;;; (: ∘ℛ (∀ (x y z) (→ (→ℛ y z) (→ℛ x y) (→ℛ x z))))
;;; ((∘ℛ go fo) x z) = (fresh (y) (fo x y) (go y z))   ; 〔等式〕二元情形；结合律允许连写多个

;;; ─── §4-d〔正文·伪代码〕 第二版：四段二元关系的复合 ───
;;; 步骤：代码（选一条边，就确定了下一个选择的范围）
;;; 只示范 pick-bᵒ；pick-aᵒ、pick-cᵒ 形状相同，rightᵒ 只让直角三角形原样通过（§8-f 有全部四段）。
;;; ┌伪代码 pick-bᵒ
;;; (define (pick-bᵒ a×h a×b×h)
;;;   (fresh (a b h)
;;;     (== a×h   `(,a ,h))
;;;     (== a×b×h `(,a ,b ,h))
;;;     (betweenᵒ a b h)))
;;; └
;;; ┌伪代码 b
;;; (define right-triangleᵒ (∘ℛ rightᵒ pick-cᵒ pick-bᵒ pick-aᵒ))
;;;
;;; (define (right-triangles l h)
;;;   (run* (a b c)
;;;     (right-triangleᵒ `(,l ,h) `(,a ,b ,c))))
;;; └
;;; (right-triangles 1 20)
;;; ;; => ((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20))
;;;
;;; 名字：rightᵒ 是 (a b c) 与 (a b c) 之间的关系，与 (a) 里三个参数的 pythᵒ 区分开。

;;; ─── §4-e〔正文·伪代码〕 展开回到第一版 ───
;;; 步骤：现象（中间元组被 fresh 藏起来；换成模式即回到 (a)）
;;;       → 概念（复合是把条件接成一条链；为了接成链，后面要用的边得打包带下去，中间元组由此而来）
;;; ┌伪代码 c
;;; (define (right-triangleᵒ l×h triangle)
;;;   (fresh (a×h a×b×h a×b×c)
;;;     (pick-aᵒ l×h   a×h)
;;;     (pick-bᵒ a×h   a×b×h)
;;;     (pick-cᵒ a×b×h a×b×c)
;;;     (rightᵒ  a×b×c triangle)))
;;; └


;;; ═══════════════════════════════════════════════════════════════════
;;; §5 列表世界的复合
;;; ═══════════════════════════════════════════════════════════════════
;;; 带走：1. 普通 ∘ 接不上：上一段交出的是一整张列表。
;;;       2. ∘ℒ：对列表里的每一行调用下一段，再把结果接起来（append-map）。
;;;       3. 作为关系没有区别的两个程序，作为列表程序还记着答案的顺序和次数。
;;; 开场问题（§4 收尾）：接收输入、交出列表的函数，怎样复合？
;;; 只按写出的顺序、从已知推出未知。
;;; 正文顺序（草稿已写）：箭头的类型与前三段 → 报错 → 小例子 → ℒ:id 与 ∘ℒ → rightᵒ 与四段的复合 → 规则 → pick-aᵒ↓。

;;; ─── 正文 04 开头（10/4，Noah）：表 → 交出列表的函数，与 §2-a″ 的 dictionary->function 并排 ───
;;; 10:28 的写法：把查表也并排写出来。dict-ref 取第一行（for/first），dict-ref* 取全部（for/list）；
;;;   (define (dict-ref  dict key) (for/first ([(k v) (in-dict dict)] #:when (equal? key k)) v))
;;;   (define (dict-ref* dict key) (for/list  ([(k v) (in-dict dict)] #:when (equal? key k)) v))
;;;   (define ((dictionary->function dict) . key) (dict-ref  dict key))
;;;   (define ((table->relation      dict) . key) (dict-ref* dict key))
;;; dict-ref 是 racket/dict 里的函数，§1 一直在用；正文是「把它自己写出来」。模块顶层不重定义它
;;; （免得改动前面几节用到的库函数），自己写的那一版放在子模块 lookup 里，并核对它与库函数在找得到键时一致。
;;; 差别：找不到键时库函数报错，for/first 的写法交出 #f；值本身是 #f 时两者都交出 #f（如 one? 的表）。
(: dict-ref* (∀ (k v) (→ (Listof (Pair k v)) k (Listof v))))
(define (dict-ref* dict key) (for/list  ([(k v) (in-dict dict)] #:when (equal? key k)) v))

(: table->relation (∀ (v k ...) (→ (Listof (Pair (List k ... k) v)) (→ k ... k (Listof v)))))
(define ((table->relation      dict) . key) (dict-ref* dict key))

(check-equal? ((table->relation rows) 1 20)
              '((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20)))
(check-equal? ((table->relation rows) 1 4) '())
;; 〔验证〕 对缓存里算过的三组边界，与 right-triangles 逐字相同；没算过的边界交出空表（表里没有它的行）
(for ([b '((1 4) (1 5) (1 20))])
  (check-equal? (apply (table->relation rows) b) (apply right-triangles b)))
(check-equal? ((table->relation rows) 1 13) '())
(check-not-equal? ((table->relation rows) 1 13) (right-triangles 1 13))
;; 〔验证，正文 03〕 收拢是摊开的逆操作：对 cache 记着的三组边界，从 rows 收拢回来的正是 cache 原来记着的那张列表
(for ([b '((1 4) (1 5) (1 20))])
  (check-equal? (apply (table->relation rows) b) (dict-ref cache b)))
;; 〔验证〕 用在字典上（键不重复），每个键交出单元素列表，与 dictionary->function 的结果对应
(for ([b '((1 4) (1 5) (1 20))])
  (check-equal? (apply (table->relation cache) b) (list (apply (dictionary->function cache) b))))

(module* lookup #f
  (require rackunit (only-in racket/dict [dict-ref lib:dict-ref]))
  ;; 正文 04 的四行，原样
  (define (dict-ref  dict key) (for/first ([(k v) (in-dict dict)] #:when (equal? key k)) v))
  (define (dict-ref* dict key) (for/list  ([(k v) (in-dict dict)] #:when (equal? key k)) v))

  (define ((dictionary->function dict) . key) (dict-ref  dict key))
  (define ((table->relation      dict) . key) (dict-ref* dict key))
  ;; 自己写的 dict-ref 与库函数：找得到键时一致（字典 cache；键重复的 rows 上两者都取第一行）
  (for ([b '((1 4) (1 5) (1 20))])
    (check-equal? (dict-ref cache b) (lib:dict-ref cache b))
    (check-equal? (apply (dictionary->function cache) b) (lib:dict-ref cache b)))
  (check-equal? (dict-ref rows '(1 20)) (lib:dict-ref rows '(1 20)))
  (check-equal? (dict-ref rows '(1 20)) '(3 4 5))
  ;; 找不到键：库函数报错，这里交出 #f
  (check-exn exn:fail? (λ () (lib:dict-ref cache '(1 13))))
  (check-equal? (dict-ref cache '(1 13)) #f)
  ;; 正文展示的两次调用
  (check-equal? ((table->relation rows) 1 20)
                '((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20)))
  (check-equal? ((table->relation rows) 1 4) '())
  ;; for/first 与 for/list 的关系：键不重复时，全部就是那唯一的一个
  (for ([b '((1 4) (1 5) (1 20))])
    (check-equal? (dict-ref* cache b) (list (dict-ref cache b)))))

;;; ─── §5-a〔正文〕 列表世界的箭头；前三个关系各是一支箭头 ───
;;; 步骤：概念（接收一头的值、交出另一头所有相关值的列表；数学上是集合，这里用列表）→ 代码
;;; 名字沿用 §4 的（说的是同一个关系，换了一种表示）。
;;; betweenᵒ 在列表世界里只是一个普通函数：给定 lo、hi，交出其间所有的数。
(define-type (→ℒ p q) (→ p (Listof q)))

(: betweenᵒ (→ Natural Natural (Listof Natural)))
(define (betweenᵒ lo hi) (inclusive-range lo hi))

;; v5.5（正文 04）：每一步写成一层 for/list，范围与 §1 循环里的子句相同；一步收到什么、交出什么见正文的表。
(define (pick-aᵒ t)
  (match-define (list l h) t)
  (for/list ([a (inclusive-range l h)]) (list a h)))

(define (pick-bᵒ t)
  (match-define (list a h) t)
  (for/list ([b (inclusive-range a h)]) (list a b h)))

(define (pick-cᵒ t)
  (match-define (list a b h) t)
  (for/list ([c (inclusive-range b h)]) (list a b c)))
;; 〔验证〕 与旧写法（map 加 betweenᵒ）逐项相同
(for* ([l (in-range 1 5)] [h (in-range 0 9)])
  (check-equal? (pick-aᵒ (list l h)) (map (λ (a) (list a h)) (betweenᵒ l h)))
  (for ([a (in-range l (add1 h))])
    (check-equal? (pick-bᵒ (list a h)) (map (λ (b) (list a b h)) (betweenᵒ a h)))
    (for ([b (in-range a (add1 h))])
      (check-equal? (pick-cᵒ (list a b h)) (map (λ (c) (list a b c)) (betweenᵒ b h))))))

;;; ─── §5-b〔正文〕 普通 ∘ 接不上 ───
;;; 步骤：现象（第二段收到的是整张部分解的列表，不是一个部分解）
(check-exn #rx"match-define: no matching clause"
           (λ () ((∘ pick-bᵒ pick-aᵒ) '(1 20))))
;; 注意：边界取 (1 2) 时 pick-aᵒ 交出两项，恰好被 (list a h) 这个模式匹配上，报错的地方变成 inclusive-range。
;; 所以正文说「接不上」时不引用具体的报错文字，也不用 (1 2) 作报错的例子。
(check-exn #rx"contract violation"
           (λ () ((∘ pick-bᵒ pick-aᵒ) '(1 2))))
;; 正文：((∘ pick-bᵒ pick-aᵒ) '(1 20))
;; ;; match-define: no matching clause for '((1 20) (2 20) … (20 20))

;;; ─── §5-c〔正文·v5.0 新增〕 足够小的例子：map 留下嵌套，append-map 接成一张 ───
;;; 步骤：代码 → 现象（对列表里的每一行调用下一段：map 交出列表的列表，第三段又接不上；
;;;       append-map 把各行的结果接成一张列表，可以继续往下接）
;;; 大纲 §5：「用一个足够小的例子讲 map 与 append-map 的区别」。取代旧 §2-a 的结果树（那一串空列表）。
(check-equal? (pick-aᵒ '(1 2))
              '((1 2) (2 2)))
(check-equal? (map pick-bᵒ (pick-aᵒ '(1 2)))
              '(((1 1 2) (1 2 2)) ((2 2 2))))
(check-equal? (append-map pick-bᵒ (pick-aᵒ '(1 2)))
              '((1 1 2) (1 2 2) (2 2 2)))

;;; ─── §5-d〔正文〕 单位与复合 ───
;;; 步骤：概念（复合：对上一段交出的每一行调用下一段，再把结果接起来；单位：包成单元素列表）
(: ℒ:id (∀ (p) (→ℒ p p)))
(: ∘ℒ   (∀ (p ...) (→ (→ℒ pn-1 pn) ... (→ℒ p1 p2) (→ℒ p1 pn))))
(define (ℒ:id v) (list v))
(define ((∘ℒ . f*) x) (foldr append-map (list x) f*))   ; 从最右边的箭头起，逐个用 append-map 接上
;; 9/30 改为变参（与第二篇的 ∘𝒦 一致）；一个箭头也不给时就是 ℒ:id。规则仍按二元陈述，结合律保证变参无歧义。

;;; §5-d′〔验证〕 两段的 ∘ℒ 就是 §5-c 那次 append-map
(check-equal? ((∘ℒ pick-bᵒ pick-aᵒ) '(1 2)) (append-map pick-bᵒ (pick-aᵒ '(1 2))))

;;; ─── §5-e〔正文〕 第四段 rightᵒ；四段箭头接成 right-triangleᵒ ───
;;; 步骤：代码 → 现象（与 §1 结果相同）
;;; rightᵒ：谓词读作关系，只让满足它的三元组原样通过，交出零行或一行。
;;; 正文里叫 right-triangles；与 §1 同名的函数不能在同一模块定义两次，这里叫 right-triangles₁。
(: rightᵒ (→ℒ (List Natural Natural Natural) (List Natural Natural Natural)))
(define (rightᵒ t)
  (if (apply pyth? t) (list t) '()))

(define right-triangleᵒ (∘ℒ rightᵒ pick-cᵒ pick-bᵒ pick-aᵒ))
(define (right-triangles₁ l h) (right-triangleᵒ (list l h)))

(check-equal? (right-triangles₁ 1 20)
              '((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20)))

(check-equal? (right-triangleᵒ '(1 20))                 ; 正文 04 直接这样调用
              '((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20)))

;; 候选全集（正文可选）：去掉 rightᵒ
(define sides (∘ℒ pick-cᵒ pick-bᵒ pick-aᵒ))
(check-equal? (length (sides '(1 20))) 1540)

;;; §5-e″〔验证〕 ∘ℒ 逐层展开：先交出一整张 (a h) 的列表，再整张变成 (a b h) 的列表……（与 §7-g‴ 的深度优先对照）
(let ([log '()])
  (define (note! x) (set! log (cons x log)))
  (define (pick-aᵒ* t) (match-define (list l h) t) (note! 'A) (pick-aᵒ t))
  (define (pick-bᵒ* t) (match-define (list a h) t) (note! (list 'B a)) (pick-bᵒ t))
  (define (pick-cᵒ* t) (match-define (list a b h) t) (note! (list 'C a b)) (pick-cᵒ t))
  (check-equal? ((∘ℒ pick-cᵒ* pick-bᵒ* pick-aᵒ*) '(1 2)) '((1 1 1) (1 1 2) (1 2 2) (2 2 2)))
  (check-equal? (reverse log) '(A (B 1) (B 2) (C 1 1) (C 1 2) (C 2 2))))

;;; §5-e′〔验证〕
;; 候选全集恰是 l ≤ a ≤ b ≤ c ≤ h
(for* ([l (in-range 1 6)] [h (in-range 0 16)])
  (check-equal? (sides (list l h))
                (for*/list ([a (inclusive-range l h)] [b (inclusive-range a h)] [c (inclusive-range b h)])
                  (list a b c))))
;; 与 §1 的结果相同（多组边界）
(for* ([l (in-range 1 8)] [h (in-range 0 31)])
  (check-equal? (right-triangles₁ l h) (right-triangles l h)))
;; 结合方式不影响结果（逐字相等）：变参与两种二元结合方式一致；零个箭头即单位
(check-equal? ((∘ℒ rightᵒ (∘ℒ pick-cᵒ (∘ℒ pick-bᵒ pick-aᵒ))) '(1 20)) (right-triangleᵒ '(1 20)))
(check-equal? ((∘ℒ (∘ℒ (∘ℒ rightᵒ pick-cᵒ) pick-bᵒ) pick-aᵒ) '(1 20)) (right-triangleᵒ '(1 20)))
(for ([x '(0 5 (1 2))]) (check-equal? ((∘ℒ) x) (ℒ:id x)))
(for* ([x '(1 4 6 12)])
  (check-equal? ((∘ℒ divisors) x) (divisors x)))
;; 函数的逆不一定是函数：平方的逆关系交出零个或一个（正文可选的旁证）
(define (sqrt-rel m) (let ([c (integer-sqrt m)]) (if (= (* c c) m) (list c) '())))
(check-equal? (map sqrt-rel '(25 26 0 144)) '((5) () (0) (12)))
;; 直角三角形自动满足三角形不等式
(for ([t triples]) (match-define (list a b c) t) (check-true (> (+ a b) c)))

;;; ─── §5-f〔正文·等式〕 关系的规则，列表实现逐字满足（保留多少见待定 5） ───
;;; 步骤：概念（关系的复合满足结合律、以相等关系为单位；函数是一种关系，嵌进来以后复合方式不变）
;;;       → 检查（列表的实现：即使把答案的顺序和重复次数也算进去，这些等式仍然成立）
;;; 说法（Astra）：不说「从关系世界继承，所以逐字成立」。忘掉顺序与重数的映射看不见这些差别，
;;;       推不出列表侧逐字成立；依据是 list、append-map 的定义，关系侧给的是设计要求与解释。
;;; 分层：前三条是任何世界都要满足的规则；第四条是模拟特有的要求。
;;; 字母：h 全篇留给宿主函数；结合律的三支箭头写作 f₁ f₂ f₃。
;;
;; (∘ℒ g ℒ:id)          = g
;; (∘ℒ ℒ:id f)          = f
;; (∘ℒ f₃ (∘ℒ f₂ f₁))   = (∘ℒ (∘ℒ f₃ f₂) f₁)
;; (∘ℒ f (∘ ℒ:id h))    = (∘ f h)          ; h 是宿主函数
;;
;;; §5-f′〔验证〕 列表世界逐字成立（equal? 比较列表，不经 forget）
(define (tens x) (list x (* 10 x)))
(define (pm x) (list x (- x)))
(define (twice n) (list n (* 2 n)))
(define ℒ-arrows (list divisors tens pm twice ℒ:id))
(define hosts (list add1 - (λ (x) (* x x))))
(for* ([x '(1 4 6 12)] [g ℒ-arrows] [f ℒ-arrows])
  (check-equal? ((∘ℒ g ℒ:id) x) (g x))
  (check-equal? ((∘ℒ ℒ:id f) x) (f x))
  (for ([f₃ ℒ-arrows])
    (check-equal? ((∘ℒ f₃ (∘ℒ g f)) x) ((∘ℒ (∘ℒ f₃ g) f) x))))
(for* ([x '(1 4 6 12)] [f ℒ-arrows] [h hosts])
  (check-equal? ((∘ℒ f (∘ ℒ:id h)) x) ((∘ f h) x)))
;; 勾股程序里的箭头同样满足（部分解作输入）
(define tri-arrows (list pick-cᵒ rightᵒ ℒ:id))
(for ([t '((3 4 5) (5 5 5) (1 2 3))])
  (for* ([g tri-arrows] [f tri-arrows])
    (check-equal? ((∘ℒ g ℒ:id) t) (g t))
    (check-equal? ((∘ℒ ℒ:id f) t) (f t))))

;;; §5-f″〔验证〕 同样的四条在关系世界（集合）里成立：这是设计要求的来处
(define rel-arrows (map as-rel ℒ-arrows))
(for* ([x '(1 4 6 12)] [r rel-arrows] [s rel-arrows])
  (check-equal? ((rel∘ r rel:id) x) (r x))
  (check-equal? ((rel∘ rel:id s) x) (s x))
  (for ([t rel-arrows])
    (check-equal? ((rel∘ t (rel∘ r s)) x) ((rel∘ (rel∘ t r) s) x))))
;; 普通函数是一种特殊的关系：抬进关系世界后照常复合
(for* ([x '(1 4 6 12)] [r rel-arrows] [h hosts])
  (check-equal? ((rel∘ r (∘ rel:id h)) x) ((∘ r h) x)))

;;; ─── §5-g〔正文〕 §5 收尾：作为关系没有区别，作为列表还记着顺序 ───
;;; 步骤：现象（倒过来列出最短边，关系没变，列表的顺序反了）
;;;       → 概念「作为关系，它们没有区别；作为列表程序，它们还记着答案以什么顺序、出现了几次。」
;;; 不说「模拟得过于忠实」。重数在正文只用一句话说（(x x) 的例子随第六篇移走）。
(define (pick-aᵒ↓ t) (match-define (list l h) t) (map (λ (a) (list a h)) (reverse (betweenᵒ l h))))

(check-equal?
 ((∘ℒ rightᵒ pick-cᵒ pick-bᵒ pick-aᵒ↓) '(1 20))
 '((12 16 20) (9 12 15) (8 15 17) (6 8 10) (5 12 13) (3 4 5)))

;;; §5-g′〔验证〕 忘掉顺序与重数，列表世界的复合就是关系的复合
(check-equal?
 (forget ((∘ℒ rightᵒ pick-cᵒ pick-bᵒ pick-aᵒ↓) '(1 20)))
 (forget (right-triangles₁ 1 20)))
(for* ([x '(4 6 12)] [g ℒ-arrows] [f ℒ-arrows])
  (check-equal? (forget ((∘ℒ g f) x)) ((rel∘ (as-rel g) (as-rel f)) x)))
;; 重数 = 到达方式的计数
(check-equal? ((∘ℒ divisors divisors) 4) '(1 1 2 1 2 4))
(check-equal? (length (filter (λ (d) (= d 1)) ((∘ℒ divisors divisors) 4))) 3)
(check-equal? (forget ((∘ℒ divisors divisors) 4))
              ((rel∘ (as-rel divisors) (as-rel divisors)) 4))
;; 倒序的 divisors↓
(define (divisors↓ n) (reverse (divisors n)))
(check-not-equal? (divisors 12) (divisors↓ 12))
(check-equal? (forget (divisors 12)) (forget (divisors↓ 12)))
(check-not-equal? ((∘ℒ twice divisors) 6) ((∘ℒ twice divisors↓) 6))
(check-equal? (forget ((∘ℒ twice divisors) 6)) (forget ((∘ℒ twice divisors↓) 6)))


;;; ═══════════════════════════════════════════════════════════════════
;;; §6 认出剩余工作
;;; ═══════════════════════════════════════════════════════════════════
;;; 带走：1. append-map 的那个函数参数就是「剩余工作」k，它为每个备选各运行一次。
;;;          §1 的现象在这里有了机制。
;;;       2. let 是 (k e)，for/list 是 (map k e*)，for*/list 是 (append-map k e*)；
;;;          把 (λ (k) (append-map k e*)) 里的序列抽成参数，就是 choose/k。
;;; 动机：§5 的 ∘ℒ 能复合，但每段函数都得自己交出列表，普通 ∘ 接不上。
;;; v5.1：大纲 v5.0 的 §6 在正文里拆成两节（本节与 §7）。let* 与 for* 的类比（原 §1 草稿的第二、三段）
;;;       是本节的入口；原 §1 草稿后半（Noah 审过的十二个块）整体搬到这里。

(define-syntax-rule (same-as-§1 f)                       ; 〔验证〕多组边界上与 §1 一致
  (for* ([l (in-range 1 6)] [h (in-range 0 26)])
    (check-equal? (f l h) (right-triangles l h))))

;;; ─── §6-a〔正文·等式〕 认出 k：let 是 (k e)，for/list 是 (map k e*)，for*/list 是 (append-map k e*) ───
;;; 步骤：问题（§5 的 append-map 收到的那个函数是什么？）→ 概念（它就是绑定之后的全部代码：剩余工作）
;;; 回指：第二篇「求值顺序与 ANF」：let 的每个绑定配对了可归约式和等待结果的延续；
;;;       第三篇「局部延续」
;;; 这三行原在 §1 草稿的散文里（行内代码）；Astra：把三种调用方式摆成独立代码，让读者停一下。
;;
;; (let ([v e]) body)            = ((λ (k) (k e))            (λ (v) body))
;; (for/list ([v e*]) body)      = ((λ (k) (map k e*))        (λ (v) body))
;; (for*/list ([v e*] …) body)   = ((λ (k) (append-map k e*)) (λ (v) body*))   ; body* 交出一张列表
;;
;;; v5.7（10/5）：这一节现在是正文 04，排在 ∘ℒ 之前（∘ℒ 挪到 06）。正文只并排 let 与 for*/list 两行，
;;;       不经过 for/list 与 map（map 与 append-map 的对比留在 06）；开头把 for*/list 与一段 let* 并排。
;; 04 开头并排的那段 let*
(check-equal? (let* ([a 3]
                     [b (+ a 1)]
                     [c (+ b 1)])
                (list a b c))
              '(3 4 5))
;; 04 开头并排的那段 for*/list：边界直接写成 1 和 20
(check-equal? (for*/list ([a (inclusive-range 1 20)]
                          [b (inclusive-range a 20)]
                          [c (inclusive-range b 20)]
                          #:when (pyth? a b c))
                (list a b c))
              (right-triangles 1 20))
;; 04 的第二行等式取一个实例：其余的子句连同 body 交出一张列表
(check-equal? ((λ (k) (append-map k '(1 2)))
               (λ (a) (for*/list ([b (inclusive-range a 2)]) (list a b))))
              (for*/list ([a '(1 2)] [b (inclusive-range a 2)]) (list a b)))

;;; §6-a′〔验证〕 三条等式各取一个实例
(check-equal? ((λ (k) (k (+ 1 2))) (λ (v) (* v v)))
              (let ([v (+ 1 2)]) (* v v)))
(check-equal? ((λ (k) (map k '(1 2 3))) (λ (v) (* v v)))
              (for/list ([v '(1 2 3)]) (* v v)))
;; 嵌套的 for/list：外层的 map 收起来是列表的列表
(check-equal? ((λ (k) (map k '(1 2)))
               (λ (a) ((λ (k) (map k (inclusive-range a 2)))
                       (λ (b) (list a b)))))
              (for/list ([a '(1 2)])
                (for/list ([b (inclusive-range a 2)])
                  (list a b))))
(check-equal? (for/list ([a '(1 2)])
                (for/list ([b (inclusive-range a 2)])
                  (list a b)))
              '(((1 1) (1 2)) ((2 2))))
;; for*/list：外层换成 append-map，把内层交出的列表接成一张
(check-equal? ((λ (k) (append-map k '(1 2)))
               (λ (a) ((λ (k) (map k (inclusive-range a 2)))
                       (λ (b) (list a b)))))
              (for*/list ([a '(1 2)] [b (inclusive-range a 2)])
                (list a b)))
(check-equal? (for*/list ([a '(1 2)] [b (inclusive-range a 2)])
                (list a b))
              '((1 1) (1 2) (2 2)))

;;; §6-a″〔验证〕 旧 §2-a 的结果树：嵌套的 for/list 保留分支层次，压平就是 §1 的列表
;;; 正文不展示（v5.0）。它已经执行了 #:when，是「保留了分支层次的结果树」，不是整个搜索过程的记录。
(define (right-triangles/tree l h)
  (for/list ([a (inclusive-range l h)])
    (for/list ([b (inclusive-range a h)])
      (for/list ([c (inclusive-range b h)]
                 #:when (pyth? a b c))
        (list a b c)))))

(check-equal? (right-triangles/tree 1 5)
              '((() () () () ()) (() () () ()) (() ((3 4 5)) ()) (() ()) (())))
(check-equal? (right-triangles 1 5) '((3 4 5)))
(for* ([l (in-range 1 6)] [h (in-range 0 26)])
  (check-equal? (append* (append* (right-triangles/tree l h))) (right-triangles l h)))

;;; ─── §6-b〔正文〕 给 (λ (k) (append-map k e*)) 起名 choose/k；把 for*/list 摊开 ───
;;; 步骤：代码 → 现象（输出与 §1 逐字相同；k 对每个备选各跑一次）
;;; 回指：第四篇 rand* 的兄弟各有各的延续（对照：这里的备选共享同一个 k）；
;;;       第三篇「局部延续」：k 的答案类型是列表，即 ¬ₐp 取 a = (Listof q)
;;; 散文（原 §1 草稿后半，Noah 审过）：(append-map k p*) 站在了 let 里 (k e) 的位置上；
;;;       最外层摊开就是 (append (k 1) (k 2) … (k 20))，同一个 k 运行了二十次。
(: choose/k (∀ (p q) (→ (Listof p) (→ (→ p (Listof q)) (Listof q)))))
(define ((choose/k p*) k) (append-map k p*))

;; 正文里仍叫 right-triangles（「摊开后的同一个函数」）；同一模块不能定义两次，这里叫 right-triangles₂。
(define (right-triangles₂ l h)
  ((choose/k (inclusive-range l h))
   (λ (a)
     ((choose/k (inclusive-range a h))
      (λ (b)
        ((choose/k (inclusive-range b h))
         (λ (c)
           (if (pyth? a b c) (list (list a b c)) '()))))))))

(check-equal? (right-triangles₂ 1 20)
              '((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20)))
;; 〔验证〕两种写法在多组边界上一致
(for* ([l (in-range 1 8)] [h (in-range 0 31)])
  (check-equal? (right-triangles₂ l h) (right-triangles l h)))

;;; §6-b′〔验证〕 过去只算一次，未来每个备选各跑一遍（显式 k 版）
;;; 正文只指着 (append-map k p*) 说这件事，不展示这份日志；日志放在 §7-g。
(let ([log '()])
  (define (note! x) (set! log (cons x log)))
  (note! 'before)
  ((choose/k '(1 2 3)) (λ (x) (note! (list 'after x)) (list x)))
  (check-equal? (reverse log) '(before (after 1) (after 2) (after 3))))
;; (append-map k p*) 摊开就是 (append (k 1) (k 2) (k 3))；一个备选也没有时只剩 (append)，即 '()
(let ([k (λ (a) (list a (* a a)))])
  (check-equal? ((choose/k '(1 2 3)) k) (append (k 1) (k 2) (k 3))))
(check-equal? (append) '())

;;; §6-b″〔验证〕 过滤就是零个备选：#:when、返回 '() 的分支、零个备选是同一件事
;;; fail 这个名字到 §7-d 与定义一起出现。
;;; 过滤条件改写成「从零个或一个备选里选」，结果不变；零个备选时 k 不被调用。
(check-equal?
 ((choose/k (inclusive-range 1 20))
  (λ (a)
    ((choose/k (inclusive-range a 20))
     (λ (b)
       ((choose/k (inclusive-range b 20))
        (λ (c)
          ((choose/k (if (pyth? a b c) '(ok) '()))
           (λ (_) (list (list a b c))))))))))
 (right-triangles 1 20))
(check-equal? ((choose/k '()) (λ (x) (error 'k "不应被调用"))) '())

;;; ─── §6-c〔正文·等式〕 ∘ℒ 的 append-map 只收到下一段；换一种括法，函数才承载全部剩余工作 ───
;;; Astra（初稿审阅，必须改）：∘ℒ = (foldr append-map (list x) f*) 是逐段做的，pick-bᵒ 只是下一段，
;;;       不含随后挑 c、检查勾股条件的工作；CPS 版的 k 则包含整个后续计算。两者由结合律相连。
;;; 步骤：概念（把后面的段一起包进函数，这个函数才是一行的全部剩余工作）
;;; 两种括法交出同一张列表，干活的先后不同（日志见 §5-e″ 与 §7-g‴）。
;;
;; (append-map g (append-map f xs))
;; =
;; (append-map (λ (x) (append-map g (f x))) xs)
;;
;;; §6-c′〔验证〕
(for ([xs (list (pick-aᵒ '(1 5)) (pick-aᵒ '(2 2)) '())])
  (check-equal? (append-map pick-cᵒ (append-map pick-bᵒ xs))
                (append-map (λ (x) (append-map pick-cᵒ (pick-bᵒ x))) xs)))
(for* ([xs '((1 4 6) (12) ())] [g ℒ-arrows] [f ℒ-arrows])
  (check-equal? (append-map g (append-map f xs))
                (append-map (λ (x) (append-map g (f x))) xs)))
;; 整条链：逐段的 ∘ℒ 与「每段把后面所有的段包进函数」交出同一张列表
(check-equal? (append-map (λ (ah) (append-map (λ (abh) (append-map rightᵒ (pick-cᵒ abh))) (pick-bᵒ ah)))
                          (pick-aᵒ '(1 20)))
              (right-triangleᵒ '(1 20)))


;;; ═══════════════════════════════════════════════════════════════════
;;; §7 擦除延续参数
;;; ═══════════════════════════════════════════════════════════════════
;;; 带走：1. 按第四篇的办法擦除延续参数，得到 choose；内层 reset 坍缩；再整理出 fail、collect。
;;;       2. choose 之前的代码运行一次，之后的代码为每个备选各运行一遍；k 的调用不在尾位置。
;;;       3. 每段函数直接交出一个值；遇到备选列表就交给 choose，所有分支的结果由外面的 collect 收起来。
;;;          普通 ∘ 又接上了。
;;; 正文展示的程序是 ₃（三层 reset）、₄（坍缩）、₆（fail 与 collect）、₇（普通 ∘）；₅ 只作验证。

;;; ─── §7-a〔正文〕 给「用 shift 取得 k」起名：choose ───
;;; 步骤：代码（choose/k 本身是 CPS 程序，逐点做第四篇的擦除）
;;; 回指：第四篇「查表」(define (anf0 exp) (shift ctx (anf1 exp ctx)))，
;;;       以及模式 1：(anf1 sub (λ (w) body)) 变成 (reset (let ([w (anf0 sub)]) body))
;;; 正文先写未化简的一行，再按 choose/k 的定义化简：
;;;   (define (choose p*) (shift k ((choose/k p*) k)))
;;;   (define (choose p*) (shift k (append-map k p*)))
;;; 同一模块不能定义两次，这里只留化简后的；未化简的一行以 choose₀ 验证。
;;; 散文：同一个 k 被反复调用是实现前提（一次性延续做不到），一句带过，不点具体语言。
(: choose (∀ (p) (→ (Listof p) p)))
(define (choose p*) (shift k (append-map k p*)))

(define (choose₀ p*) (shift k ((choose/k p*) k)))   ; 〔验证〕
;; 正文 05 的等式（Noah 10/5 13:35 整理成四行）：
;;   ((choose/k p*) (λ (v) body))
;;   = (let ([k (λ (v) body)]) ((choose/k p*) k))
;;   = (let ([k (λ (v) body)]) (append-map k p*))
;;   = (reset (let ([v (shift k (append-map k p*))]) body))
;; 〔验证〕四行各取一个实例（body 交出一张列表）
(for ([p* '(() (1) (1 2 3))])
  (define r1 ((choose/k p*) (λ (v) (list v (* v v)))))
  (check-equal? (let ([k (λ (v) (list v (* v v)))]) ((choose/k p*) k)) r1)
  (check-equal? (let ([k (λ (v) (list v (* v v)))]) (append-map k p*)) r1)
  (check-equal? (reset (let ([v (shift k (append-map k p*))]) (list v (* v v)))) r1))

;;; ─── §7-b〔正文〕 原样程序：三层嵌套的 reset，主体自己返回列表 ───
;;; 步骤：代码 → 现象（与 §1 相同）
;;; 回指：§6-b 的 choose/k 程序，逐层按模式 1 改写
(define (right-triangles₃ l h)
  (reset
   (let ([a (choose (inclusive-range l h))])
     (reset
      (let ([b (choose (inclusive-range a h))])
        (reset
         (let ([c (choose (inclusive-range b h))])
           (if (pyth? a b c) (list (list a b c)) '()))))))))

(check-equal? (right-triangles₃ 1 20)
              '((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20)))

;;; §7-b′〔验证〕 多组边界；未化简的 choose₀
(same-as-§1 right-triangles₃)
(check-equal?
 (reset
  (let ([a (choose₀ (inclusive-range 1 20))])
    (reset
     (let ([b (choose₀ (inclusive-range a 20))])
       (reset
        (let ([c (choose₀ (inclusive-range b 20))])
          (if (pyth? a b c) (list (list a b c)) '())))))))
 triples)

;;; ─── §7-c〔正文〕 内层 reset 坍缩 ───
;;; 步骤：代码 → 现象（仍相同）
;;; 回指：第四篇「化简」：(reset (reset e)) = (reset e)，内层 reset 坍缩的理由
(define (right-triangles₄ l h)
  (reset
   (let* ([a (choose (inclusive-range l h))]
          [b (choose (inclusive-range a h))]
          [c (choose (inclusive-range b h))])
     (if (pyth? a b c) (list (list a b c)) '()))))

(check-equal? (right-triangles₄ 1 20)
              '((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20)))
(same-as-§1 right-triangles₄)                            ; 〔验证〕

;;; ─── §7-d〔正文〕 整理第一步：'() 认作 (fail) ───
;;; 步骤：代码（零个备选在这里得名 fail，名字与定义一起首次出现）
;;; 回指：§1「也可以一次都不运行（过滤）」
(: fail (∀ (p) (→ p)))
(define (fail) (choose '()))

(define (right-triangles₅ l h)
  (reset
   (let* ([a (choose (inclusive-range l h))]
          [b (choose (inclusive-range a h))]
          [c (choose (inclusive-range b h))])
     (if (pyth? a b c) (list (list a b c)) (fail)))))

(check-equal? (right-triangles₅ 1 20)
              '((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20)))
(same-as-§1 right-triangles₅)                            ; 〔验证〕

;;; ─── §7-e〔正文〕 整理第二步：每个结果上的 list 移进 collect ───
;;; 步骤：代码 → 现象（主体只剩普通的 let* 与 if）
;;; 散文：把所有走通的时间线并排摆出来，得到的是答案列表；不计顺序和重复，它装的是表里的行。
(: collect (∀ (q) (→ (→ q) (Listof q))))
(define (collect thunk) (reset (list (thunk))))

(define (right-triangles₆ l h)
  (collect
   (λ ()
     (let* ([a (choose (inclusive-range l h))]
            [b (choose (inclusive-range a h))]
            [c (choose (inclusive-range b h))])
       (if (pyth? a b c) (list a b c) (fail))))))

(check-equal? (right-triangles₆ 1 20)
              '((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20)))

;;; §7-e′〔验证〕 多组边界；define / unless 写法同样成立
(same-as-§1 right-triangles₆)
(check-equal?
 (collect (λ ()
            (define a (choose (inclusive-range 1 20)))
            (define b (choose (inclusive-range a 20)))
            (define c (choose (inclusive-range b 20)))
            (unless (pyth? a b c) (fail))
            (list a b c)))
 triples)

;;; ─── §7-e″〔正文〕（v5.8，正文 06「不确定运算符 amb」）amb 的三行宏；between；直接风格的三角形 ───
;;; Noah 10/5 13:21、13:23：05 只到 reset 坍缩（§7-c），amb 单独一节；正文不再出现 fail、collect，
;;;   '() 一行认作 (amb)，reset 加 list 认作 in-amb；choose/k 与 choose 保留作推导里的两个名字。
;;;   between 在 06 用 for/amb 定义；list->amb 按他的写法留到 07（关系的世界）定义。
;;; 步骤：概念（choose 做的事早有名字：McCarthy 的 amb）→ 代码（三行宏）→ 现象（两个小例子，取自 amb 包的 README）
;;;       → 代码（between，三角形）→ 现象（与 §1 相同；between 的同一组输入有三个结果）
;;; 这里的 in-amb 交出列表，一次算完；Noah 的 amb 包里它交出惰性的流（正文点明这一处差别）。
(define-syntax-rule (amb e ...) ((choose (list (λ () e) ...))))
(define-syntax-rule (for/amb clauses body ...) ((choose (for/list clauses (λ () body ...)))))
(define-syntax-rule (for*/amb clauses body ...) ((choose (for*/list clauses (λ () body ...)))))   ; 10/5 18:44 Noah：补上，凑齐 amb 包的接口
(define-syntax-rule (in-amb e) (reset (list e)))
;; for*/amb 的核对：嵌套的循环，与两个 amb 的 let* 交出同样的结果；#:when 也能用
(check-equal? (in-amb (for*/amb ([x '(1 2 3)] [y '(10 20)]) (+ x y)))
              (in-amb (let* ([x (amb 1 2 3)] [y (amb 10 20)]) (+ x y))))
(check-equal? (in-amb (for*/amb ([a (inclusive-range 1 20)] [b (inclusive-range a 20)] [c (inclusive-range b 20)]
                                 #:when (pyth? a b c))
                        (list a b c)))
              '((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20)))
(check-equal? (in-amb (for*/amb ([x '()] [y '(1 2)]) y)) '())

(check-equal? (in-amb (amb 1 2 3)) '(1 2 3))
(check-equal? (in-amb (let ([n (amb 1 2 3 4 5)])
                        (unless (odd? n) (amb))
                        (* n n)))
              '(1 9 25))

(: between (→ ℕ⁺ ℕ⁺ ℕ⁺))
(define (between lo hi) (for/amb ([n (inclusive-range lo hi)]) n))

;; check（Noah 10/5 13:53 的伪代码里的名字）：条件不成立就 (amb)。
;; 这个辅助函数在 SICP 4.3 里叫 require（Racket 里 require 是模块的导入形式，用不了）。
(: check (→ Boolean Void))
(define (check ok?) (unless ok? (amb)))

(define (right-triangles₈ l h)
  (in-amb
   (let* ([a (between l h)]
          [b (between a h)]
          [c (between b h)])
     (check (pyth? a b c))
     (list a b c))))
;; 06 演示 amb 行为的三个例子（正文先演示、节末才给三行宏）
(check-equal? (in-amb (let* ([x (amb 1 2 3)]
                             [y (amb 10 20)])
                        (+ x y)))
              '(11 21 12 22 13 23))
;; 〔验证〕check 与直接写 unless … (amb) 相同
(check-equal? (in-amb (let ([n (amb 1 2 3 4 5)]) (check (odd? n)) (* n n))) '(1 9 25))

(check-equal? (right-triangles₈ 1 20)
              '((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20)))
(same-as-§1 right-triangles₈)                            ; 〔验证〕
;; 06 结尾展示：between 的同一组输入有三个结果
(check-equal? (in-amb (between 1 3)) '(1 2 3))
(check-equal? (in-amb (between 3 1)) '())                ; 〔验证〕空的范围：一个结果也没有
;; 〔验证〕(amb) 就是从零个备选里选；旧写法（collect / fail）交出同样的结果
(check-equal? (in-amb (amb)) (reset (list (choose '()))))
(check-equal? (right-triangles₈ 1 20) (right-triangles₆ 1 20))

;;; §7-e‴〔正文·07 用〕 list->amb（Noah 10/5 13:21 的定义）；它与 choose 是同一个函数；between 就是 (∘ list->amb inclusive-range)
(: list->amb (∀ (p) (→ (Listof p) p)))
(define (list->amb v*) (for/amb ([v (in-list v*)]) v))
(for ([v* '(() (1) (1 2 3) (a b))])
  (check-equal? (in-amb (list->amb v*)) v*)
  (check-equal? (in-amb (list->amb v*)) (in-amb (choose v*))))
(for* ([lo (in-range 1 5)] [hi (in-range 0 7)])
  (check-equal? (in-amb ((∘ list->amb inclusive-range) lo hi)) (in-amb (between lo hi))))

;;; ─── §7-f〔正文·等式〕 fail 就是 (abort '()) ───
;;; 步骤：概念（不调用剩余工作，'() 原样交出）
;;; 回指：第三篇「定界延续」(shift _ e) = (abort e)，abort 的定义
;;
;; (fail) = (choose '()) = (shift k (append-map k '())) = (shift _ '()) = (abort '())
;;
;;; §7-f′〔验证〕
(check-equal?
 (collect
  (λ ()
    (let* ([a (choose (inclusive-range 1 20))]
           [b (choose (inclusive-range a 20))]
           [c (choose (inclusive-range b 20))])
      (if (pyth? a b c) (list a b c) (abort '())))))
 triples)
(check-equal? (reset (+ 1 (shift _ 5))) (reset (+ 1 (abort 5))))

;;; ─── §7-g〔正文〕 共享与重放：过去只算一次，未来每个备选各跑一遍 ───
;;; 步骤：现象（直接风格里 before 只写了一次、after 出现三次）
;;; 散文：k 的调用不在尾位置，其余备选在 append-map 里等着（§9 的局部诊断回到这里）。
;;; 回指：§6-b 的 (append-map k p*)；§1 的「循环之后的代码为每个备选各运行一次」
(let ([log '()])
  (define (note! x) (set! log (cons x log)))
  (check-equal?
   (collect
    (λ ()
      (note! 'before)
      (let ([x (choose '(1 2 3))])
        (note! (list 'after x))
        x)))
   '(1 2 3))
  (check-equal? (reverse log) '(before (after 1) (after 2) (after 3))))

;;; §7-g‴〔验证〕 choose 沿路径深度优先：与 §5-e″ 交出同样的行、同样的顺序，干活的顺序不同
(let ([log '()])
  (define (note! x) (set! log (cons x log)))
  (check-equal?
   (collect
    (λ ()
      (let* ([a (begin (note! 'A) (choose (inclusive-range 1 2)))]
             [b (begin (note! (list 'B a)) (choose (inclusive-range a 2)))]
             [c (begin (note! (list 'C a b)) (choose (inclusive-range b 2)))])
        (list a b c))))
   '((1 1 1) (1 1 2) (1 2 2) (2 2 2)))
  (check-equal? (reverse log) '(A (B 1) (C 1 1) (C 1 2) (B 2) (C 2 2))))

;;; §7-g′〔验证〕 各条时间线在宿主上按深度优先依次跑完，不是并行
(let ([log '()])
  (define (note! x) (set! log (cons x log)))
  (collect
   (λ ()
     (let* ([x (choose '(1 2))]
            [y (choose '(a b))])
       (note! (list x y))
       (list x y))))
  (check-equal? (reverse log) '((1 a) (1 b) (2 a) (2 b))))

;;; ─── §7-h〔正文〕 函数又能当关系用：普通的 ∘ 重新接上 ───
;;; 步骤：问题（§5-b 普通 ∘ 接不上）→ 代码（四段都写成普通函数，直接交出一个值）
;;;       → 现象（普通 ∘ 复合，外面一层 collect，结果与 §1 相同）
;;; 回指：§5-a 的 pick-aᵒ（map 进列表）与这里的 pick-a（choose 一个值），差别只在一处
;;; 散文：choose / fail 就是 McCarthy 的 amb（名字在现象之后出现）。
;;;       措辞（Astra 第二轮）：「每段函数现在直接交出一个值。遇到备选列表，就交给 choose；
;;;       所有分支的结果，由外面的 collect 收起来。」不说「装答案的容器交给了 choose」。
;; v5.8（10/5，正文 07）：四步改用 06 的 between 与 check（行为与原来的 choose / fail 写法相同）。
;; 15:32 Noah：用 match-λ 代替 match-define；最后一步改名 check-right。
(define pick-a (match-λ [(list l h)   (list   (between l h) h)]))
(define pick-b (match-λ [(list a h)   (list a (between a h) h)]))
(define pick-c (match-λ [(list a b h) (list a b (between b h))]))
(define (check-right t) (check (apply pyth? t)) t)

(define right-triangle (∘ check-right pick-c pick-b pick-a))   ; 普通的 ∘
(define (right-triangles₇ l h) (in-amb (right-triangle (list l h))))   ; 正文 07（Noah 10/5 15:48 的写法）

(check-equal? (right-triangles₇ 1 20)
              '((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20)))

;;; §7-h′〔验证〕 多组边界；collect 收回来的就是 §5 的列表箭头
(same-as-§1 right-triangles₇)
(for ([t '((1 5) (2 2) (3 20))])
  (check-equal? (collect (λ () (pick-a t))) (pick-aᵒ t)))
(for ([t '((3 5) (4 4))])
  (check-equal? (collect (λ () (pick-b t))) (pick-bᵒ t)))
(for ([t '((3 4 5) (3 3 5) (5 12 13) (1 2 3))])
  (check-equal? (collect (λ () (check-right t))) (rightᵒ t)))
;; 整条链：collect 之后等于 §5 的 ∘ℒ 版本
(check-equal? (collect (λ () (right-triangle '(1 20)))) (right-triangleᵒ '(1 20)))

;;; §7-h″〔核对正文 07 的三列表〕 Noah 10/5 16:17 的评论：二元关系是两列的表；两张表并排，首尾相连的行连成一行；
;;;   遮住中间一列就是复合的表。正文的表是手写的，这里核对每一行。边界取 (1 2)。
(check-equal? (in-amb (pick-a '(1 2))) '((1 2) (2 2)))                 ; pick-a 的表：两行
(check-equal? (in-amb (pick-b '(1 2))) '((1 1 2) (1 2 2)))             ; pick-b 用得上的三行
(check-equal? (in-amb (pick-b '(2 2))) '((2 2 2)))
(check-equal? (in-amb (let* ([x '(1 2)] [y (pick-a x)] [z (pick-b y)]) (list x y z)))   ; 连成的三行（三列）
              '(((1 2) (1 2) (1 1 2))
                ((1 2) (1 2) (1 2 2))
                ((1 2) (2 2) (2 2 2))))
(check-equal? (in-amb ((∘ pick-b pick-a) '(1 2))) '((1 1 2) (1 2 2) (2 2 2)))   ; 遮住中间一列

;;; ─── §7-k〔正文 08「关系的世界」（10/5 15:54 从 07 拆出）〕 ℬ 与 ℒ 之间的搬运；复合对得上；来回是恒等 ───
;;; Noah 10/5 14:28、14:32：照第二篇的三个世界再演示一遍。14:40：带 amb 的宿主改叫 ℬ（binary relation），
;;;   与第二篇的 𝒟、𝒞 排成 𝒟 𝒞 ℬ，模拟它们的世界是 𝒦、ℒ；ℛ 留给关系语言（miniKanren）的世界。
;;;  𝒟 纯的宿主，ℒ 交出列表的函数，ℬ 带 amb 的宿主。
;;; 正文的等式（把 ℬ 里两步的复合放进 in-amb，问出 ℒ 的复合）：
;;;   (in-amb (g (f x)))  =  (append-map (λ (y) (in-amb (g y))) (in-amb (f x)))
(check-equal? (in-amb (right-triangle '(1 20)))
              '((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20)))
(for* ([fgx (list (list pick-a pick-b '((1 3) (2 2) (3 6)))
                  (list pick-b pick-c '((1 3) (2 2) (3 6)))
                  (list pick-c check-right  '((1 2 3) (3 4 5) (3 4 6))))]
       [x (third fgx)])
  (define f (first fgx)) (define g (second fgx))
  (check-equal? (in-amb (g (f x)))
                (append-map (λ (y) (in-amb (g y))) (in-amb (f x)))))

;; 10/5 19:44 Noah 定名：gather（ℬ 到 ℒ，把各条时间线的结果收成列表）、scatter（ℒ 到 ℬ，把列表散成时间线）；此前暂名 ℬ->ℒ、ℒ->ℬ。
;; 10/5 19:34 Noah：两个搬运的类型照本系列的写法摆出来（函子 F : 𝒞 → 𝒟 写作 (→ (→𝒞 a b) (→𝒟 (F a) (F b)))，这里对象不变）
(define-type (→𝒟 p q) (→ p q))
(define-type (→ℬ p q) (→ p q))
;; 10/5 20:05 Noah：照第二篇的 inj（𝒟 进 𝒞），这里是 𝒟 进 ℬ；ℬ 的复合起名 ∘ℬ
(: inj (∀ (p q) (→ (→𝒟 p q) (→ℬ p q))))
(define (inj f) f)
(: ∘ℬ (∀ (p ...) (→ (→ℬ pn-1 pn) ... (→ℬ p1 p2) (→ℬ p1 pn))))
(define ∘ℬ ∘)
(: scatter (∀ (p q) (→ (→ℒ p q) (→ℬ p q))))
(define (scatter f) (∘ list->amb f))   ; 10/5 19:25：写成复合，与第二篇的 uncps = (∘ call/cc cps:f) 同一个形状
(: gather (∀ (p q) (→ (→ℬ p q) (→ℒ p q))))
(define ((gather g) . x*) (in-amb (apply g x*)))

;; between 与 inclusive-range 互为对方搬过来的样子
(for* ([lo (in-range 1 5)] [hi (in-range 0 7)])
  (check-equal? (in-amb ((scatter inclusive-range) lo hi)) (in-amb (between lo hi)))
  (check-equal? ((gather between) lo hi) (inclusive-range lo hi)))
;; 来回是恒等：ℒ → ℬ → ℒ 逐项相同；ℬ → ℒ → ℬ 在 in-amb 里看相同
(for ([t '((1 5) (2 2) (3 20))])
  (check-equal? ((gather (scatter pick-aᵒ)) t) (pick-aᵒ t))
  (check-equal? (in-amb ((scatter (gather pick-a)) t)) (in-amb (pick-a t))))
;; 先复合再搬，与先搬再复合，结果相同（正文展示）
(check-equal? ((gather right-triangle) '(1 20))
              '((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20)))
(check-equal? ((∘ℒ (gather check-right) (gather pick-c) (gather pick-b) (gather pick-a)) '(1 20))
              '((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20)))
(for* ([l (in-range 1 5)] [h (in-range 0 12)])
  (check-equal? ((∘ℒ (gather check-right) (gather pick-c) (gather pick-b) (gather pick-a)) (list l h))
                ((gather right-triangle) (list l h)))
  (check-equal? ((gather right-triangle) (list l h)) (right-triangles l h)))
;; 搬过来的四步就是 §5 手写的列表版本
(for ([t '((1 5) (2 2) (3 20))]) (check-equal? ((gather pick-a) t) (pick-aᵒ t)))
(for ([t '((3 4 5) (3 3 5) (1 2 3))]) (check-equal? ((gather check-right) t) (rightᵒ t)))

;;; §7-e⁗〔核对正文 08 的练习〕 Noah 10/5 21:43：list->amb 与 choose 是同一个函数（留作练习）。
;;;   (list->amb v*)
;;;   = (for/amb ([v (in-list v*)]) v)
;;;   = ((choose (for/list ([v (in-list v*)]) (λ () v))))
;;;   = ((shift k (append-map k (map (λ (v) (λ () v)) v*))))
;;;   = (shift k (append-map (λ (t) (k (t))) (map (λ (v) (λ () v)) v*)))      ; 「调用一次」并进延续
;;;   = (shift k (append-map k v*))
;;;   = (choose v*)
(for ([v* '(() (1) (1 2 3) (3 1 3 2) ((1 2) (3 4)) (a a a))])
  (define-syntax-rule (E e) (in-amb (list 'x e 'y)))
  (define l1 (E (list->amb v*)))
  (for ([l (list (E (for/amb ([v (in-list v*)]) v))
                 (E ((choose (for/list ([v (in-list v*)]) (λ () v)))))
                 (E ((shift k (append-map k (map (λ (v) (λ () v)) v*)))))
                 (E (shift k (append-map (λ (t) (k (t))) (map (λ (v) (λ () v)) v*))))
                 (E (shift k (append-map k v*)))
                 (E (choose v*)))])
    (check-equal? l l1))
  (check-equal? (in-amb (list->amb v*)) v*)
  (for ([w* '(() (1 2) (x y z))])
    (check-equal? (in-amb (let* ([a (list->amb v*)] [b (choose w*)]) (cons a b)))
                  (in-amb (let* ([a (choose v*)] [b (list->amb w*)]) (cons a b))))))
(check-equal? (in-amb (let ([n (list->amb '(1 2 3 4 5 6))]) (check (even? n)) (* n n)))
              (in-amb (let ([n (choose    '(1 2 3 4 5 6))]) (check (even? n)) (* n n))))

;;; §7-k′〔核对正文 08 的推导〕 Noah 10/5 19:25：照第二篇的 ∘𝒦，先绕道 ℬ 定义 ∘ℒ，再化简成 append-map。
;;;   (∘ℒ g f) = (gather (∘ (scatter g) (scatter f)))
;;;   ((∘ℒ g f) x)
;;;   = ((gather (∘ (scatter g) (scatter f))) x)
;;;   = (in-amb (list->amb (g (list->amb (f x)))))
;;;   = (append-map (λ (y) (in-amb (list->amb (g y)))) (f x))
;;;   = (append-map g (f x))
;; （绕道 ℬ 的定义见本小节末尾的 let：正文 08 先用它定义 ∘ℒ，再化简成 foldr append-map 的那一版）
;; 搬过去再搬回来：(in-amb (list->amb v*)) = v*
(for ([v* '(() (1) (1 2 3) ((1 2) (3 4)))])
  (check-equal? (in-amb (list->amb v*)) v*)
  (check-equal? (in-amb (list->amb v*)) (append-map list v*)))
;; 推导的每一行，在列表版的各步上逐行相等
(for* ([fgx (list (list pick-aᵒ pick-bᵒ '((1 3) (2 2) (3 6) (5 4)))
                  (list pick-bᵒ pick-cᵒ '((1 3) (2 2) (3 6)))
                  (list pick-cᵒ rightᵒ  '((1 2 3) (3 4 5) (3 4 6))))]
       [x (third fgx)])
  (define f (first fgx)) (define g (second fgx))
  (define line1 ((∘ℒ g f) x))
  (define line2 ((gather (∘ℬ (scatter g) (scatter f))) x))
  (define line3 (in-amb (list->amb (g (list->amb (f x))))))
  (define line4 (append-map (λ (y) (in-amb (list->amb (g y)))) (f x)))
  (define line5 (append-map g (f x)))
  (check-equal? line2 line1) (check-equal? line3 line1) (check-equal? line4 line1) (check-equal? line5 line1))
;; 10/5 20:43 Noah 的推演（正文 08 采用）：沿着 05、04 的来路走回去，九行逐行相等
;;     ((∘ℒ g f) x)
;;   = ((gather (∘ℬ (scatter g) (scatter f))) x)
;;   = ((gather (∘ list->amb g list->amb f)) x)
;;   = (in-amb (let* ([y (list->amb (f x))] [z (list->amb (g y))]) z))
;;   = (reset (let* ([y (choose (f x))] [z (choose (g y))]) (list z)))
;;   = (for*/list ([y (f x)] [z (g y)]) z)                       ; 21:00 添
;;   = ((choose/k (f x)) (λ (y) ((choose/k (g y)) list)))
;;   = (append-map (λ (y) (append-map list (g y))) (f x))
;;   = (append-map (λ (y) (g y)) (f x))
;;   = (append-map g (f x))
(for* ([fgx (list (list pick-aᵒ pick-bᵒ '((1 3) (2 2) (3 6) (5 4)))
                  (list pick-bᵒ pick-cᵒ '((1 3) (2 2) (3 6)))
                  (list pick-cᵒ rightᵒ  '((1 2 3) (3 4 5) (3 4 6))))]
       [x (third fgx)])
  (define f (first fgx)) (define g (second fgx))
  (define l1 ((∘ℒ g f) x))
  (define l2 ((gather (∘ℬ (scatter g) (scatter f))) x))
  (define l3 ((gather (∘ list->amb g list->amb f)) x))
  (define l4 (in-amb
              (let* ([y (list->amb (f x))]
                     [z (list->amb (g y))])
                z)))
  (define l5 (reset
              (let* ([y (choose (f x))]
                     [z (choose (g y))])
                (list z))))
  (define l5′ (for*/list ([y (f x)]
                          [z (g y)])
                z))                                   ; 10/5 21:00 Noah 添的一行：出现过的四种写法里的第三种
  (define l6 ((choose/k (f x)) (λ (y) ((choose/k (g y)) list))))
  (define l7 (append-map (λ (y) (append-map list (g y))) (f x)))
  (define l8 (append-map (λ (y) (g y)) (f x)))
  (define l9 (append-map g (f x)))
  (define l6′ ((choose/k (f x))                     ; Noah 21:10 前后改的排版：嵌套写开，list 写成 (λ (z) (list z))
               (λ (y)
                 ((choose/k (g y))
                  (λ (z)
                    (list z))))))
  (for ([l (list l2 l3 l4 l5 l5′ l6 l6′ l7 l8 l9)]) (check-equal? l l1))
  ;; 第五行到第六行用了 05 的等式两次：先得到每个 choose 各带一层 reset 的样子，多的一层可以省
  (check-equal? (reset (let ([y (choose (f x))]) (reset (let ([z (choose (g y))]) (list z))))) l1))

;; 变参：零步、一步、四步，绕道 ℬ 的定义与 foldr append-map 的定义一致
(let ([∘ℒ₀ ∘ℒ])                                              ; 外面那一版：foldr append-map
  (define (∘ℒ . f*) (gather (apply ∘ℬ (map scatter f*))))     ; 正文 08 先给的定义（Noah 10/5 20:05），用到 amb
  (for ([t '((1 5) (2 2) (1 20))])
    (check-equal? ((∘ℒ) t) ((∘ℒ₀) t))
    (check-equal? ((∘ℒ pick-aᵒ) t) ((∘ℒ₀ pick-aᵒ) t))
    (check-equal? ((∘ℒ pick-bᵒ pick-aᵒ) t) ((∘ℒ₀ pick-bᵒ pick-aᵒ) t))
    (check-equal? ((∘ℒ rightᵒ pick-cᵒ pick-bᵒ pick-aᵒ) t) ((∘ℒ₀ rightᵒ pick-cᵒ pick-bᵒ pick-aᵒ) t))
    ;; 正文的演示在这一版定义下也成立
    (check-equal? ((∘ℒ (gather check-right) (gather pick-c) (gather pick-b) (gather pick-a)) t)
                  ((gather right-triangle) t))))
;; 10/6 17:09 Noah 同意在 08 末尾添的两行并排（回扣第二篇的 let* 与 anf:let*，正文不提第二篇）：
;;   (let*      ([y (f x)] [z (g y)]) z)  =  ((∘ℬ g f) x)     ; f、g 是 ℬ 的箭头
;;   (for*/list ([y (f x)] [z (g y)]) z)  =  ((∘ℒ g f) x)     ; f、g 是 ℒ 的箭头
(for* ([fgx (list (list pick-a pick-b      '((1 3) (2 2) (3 6) (5 4)))
                  (list pick-b pick-c      '((1 3) (2 2) (3 6)))
                  (list pick-c check-right '((1 2 3) (3 4 5) (3 4 6) (3 4 4))))]
       [x (third fgx)])
  (define f (first fgx)) (define g (second fgx))
  (check-equal? (in-amb (let* ([y (f x)] [z (g y)]) z))
                (in-amb ((∘ℬ g f) x))))
(for* ([fgx (list (list pick-aᵒ pick-bᵒ '((1 3) (2 2) (3 6) (5 4)))
                  (list pick-bᵒ pick-cᵒ '((1 3) (2 2) (3 6)))
                  (list pick-cᵒ rightᵒ  '((1 2 3) (3 4 5) (3 4 6))))]
       [x (third fgx)])
  (define f (first fgx)) (define g (second fgx))
  (check-equal? (for*/list ([y (f x)] [z (g y)]) z) ((∘ℒ g f) x))
  ;; 两行说的是同一件事：把 ℒ 的箭头搬到 ℬ，第一行收回来就是第二行
  (check-equal? (in-amb (let* ([y ((scatter f) x)] [z ((scatter g) y)]) z))
                (for*/list ([y (f x)] [z (g y)]) z)))
;; inj 不改变函数；纯函数经 inj、gather 搬到 ℒ，就是把结果包成一项的列表；零步的 ∘ℒ 是 list
(check-eq? (inj add1) add1)
(check-equal? ((gather (inj add1)) 41) '(42))
(check-equal? ((∘ℒ) 7) '(7))
(check-equal? (in-amb ((∘ℬ pick-b pick-a) '(1 3))) (in-amb ((∘ pick-b pick-a) '(1 3))))

;;; ─── §7-i〔正文〕 amb：同一组操作的 Racket 式写法（v5.2，Noah 10/2 晚提出） ───
;;; 步骤：概念（先造后认：choose / fail / collect 就是 McCarthy 的 amb）
;;;       → 代码（照 for/list 与 in-list 的样子，给 amb 配一对 for/amb 与 in-amb）
;;; 散文：amb 的备选是表达式，选中了才求值，所以各包一层 λ，选出来以后再调用。
;;;       这里的 in-amb 交出列表，一次算完；Noah 的 amb 包里它交出惰性的流（正文点明这一处差别）。
;;;       正文其余部分仍用 choose / fail / collect；这三行只在本小节与点名处出现。
;; v5.8（10/5）：这三行宏挪到了 §7-e″（正文 06），in-amb 直接写成 (reset (list e))。
;; 〔验证〕新的 in-amb 与 collect 交出同样的列表
(check-equal? (in-amb (amb 1 2 3)) (collect (λ () (choose '(1 2 3)))))

;;; ─── §7-j〔正文·等式〕 两种写法互相得到 ───
;;; 步骤：现象（§5 交出列表的 pick-aᵒ 与本节直接交出一个值的 pick-a，用 in-amb 与 for/amb 互相转换）
;;; 这就是创作者笔记里的往返（附-d）；第二条等式在 collect 的边界上观察。
;;
;; (pick-aᵒ t) = (for/list ([s (in-amb  (pick-a t))])  s)
;; (pick-a t)  = (for/amb  ([s (in-list (pick-aᵒ t))]) s)
;;
;;; §7-j′〔验证〕
(for ([t '((1 5) (2 2) (3 20))])
  (check-equal? (for/list ([s (in-amb (pick-a t))]) s) (pick-aᵒ t))
  (check-equal? (in-amb (for/amb ([s (in-list (pick-aᵒ t))]) s)) (in-amb (pick-a t)))
  ;; 放进更长的计算里也一样
  (check-equal? (in-amb (pick-b (for/amb ([s (in-list (pick-aᵒ t))]) s)))
                (in-amb (pick-b (pick-a t)))))
;; amb 的几个小例子（期望值与 amb 包的文档相同）
(check-equal? (in-amb (amb 1 2 3)) '(1 2 3))
(check-equal? (in-amb (amb)) '())
(check-equal? (in-amb (amb 1 (amb 2 3) (amb 4 5 6) 7 8)) '(1 2 3 4 5 6 7 8))
(check-equal? (in-amb (let ([n (amb 1 2 3 4 5)]) (unless (odd? n) (amb)) (* n n))) '(1 9 25))
(check-equal? (for/list ([c (in-amb (for/amb ([c "hello"]) c))]) c) '(#\h #\e #\l #\l #\o))


;;; ═══════════════════════════════════════════════════════════════════
;;; §8 让关系语言跑起来
;;; ═══════════════════════════════════════════════════════════════════
;;; 带走：1. 把同一个未知项拆成彼此独立的选择，会丢掉约束；两个目标要能共享一个还不知道值的项，
;;;          之后找到的信息对它们同时生效。这就是代换。
;;;       2. 目标是「代换 → 代换」：==、conj（依次应用）、disj（用 choose 选一个）、
;;;          fresh（收到代换时才分配新的未知项）、run*（用 collect 收集）。
;;;       3. §3、§4 的两版程序原样运行；swapᵒ 倒着跑。
;;; 代码放在子模块 relational 里：§5 的 betweenᵒ、pick-aᵒ 等名字在这里换成关系语言的版本。
;;; 正文展示的答案都已确定，不重整未确定的变量。末尾一句点名 miniKanren。

;;; ─── §8-a〔正文〕 同一个未知项，不能各选各的 ───
;;; 步骤：问题（(a) 里的 a 同时出现在两个约束里；若每次出现各自 choose，两个 a 互不相干）→ 现象（答案错且重复）
;;; 散文（Astra 第二轮收紧）：它证明的是「把同一个未知项拆成彼此独立的选择，会丢掉原来的约束」；
;;;       具体拆开的是两处用途，不说成严格模拟了「每次出现都独立选择」。光靠它还不足以说明为什么要代换
;;;       （用 let* 绑定一次就能共享）；真正新增的需求是：两个目标先共享一个尚不知道值的项，之后找到的
;;;       信息要对它们共同生效（§8-c″ 的 (== x y) (== y 3)）。
(define independent
  (collect
   (λ ()
     (let* ([a₁ (choose (inclusive-range 1 20))]    ; (betweenᵒ l a h) 里的 a
            [a₂ (choose (inclusive-range 1 20))]    ; (betweenᵒ a b h) 里的 a，各选各的
            [b  (choose (inclusive-range a₂ 20))]
            [c  (choose (inclusive-range b 20))])
       (if (pyth? a₁ b c) (list a₁ b c) (fail))))))

(check-equal? (take independent 7)
              '((3 4 5) (3 4 5) (3 4 5) (3 4 5) (4 3 5) (4 3 5) (4 3 5)))
(check-equal? (length independent) 110)
;; 〔验证〕去掉重复后有 12 组，每组直角三角形都多出一个两条直角边对调的版本
(check-equal? (length (remove-duplicates independent)) 12)
(check-equal? (forget (filter (λ (t) (<= (car t) (cadr t))) independent)) (forget triples))

(module* relational #f
  (provide (all-defined-out))

  ;;; ─── §8-b〔正文〕 未知项与代换 ───
  ;;; 步骤：代码（代换记下每个未知项已知的值；walk 顺着代换找到当前的值）
  ;;; 完整的序对合一：伪代码 (b) 的 (== a×h `(,a ,h)) 需要拆结构。「合一」这个词在这里首次出现。
  ;;; occurs 检查：不让未知项等于含有它自己的项。
  (struct var ([name : Symbol]) #:type-name Var)   ; 未知项，按 eq? 区分
  (define-type Term (∪ Var Number Symbol Null (Pair Term Term)))
  (define-type Substitution (Immutable-HashTable Var Term))

  (define empty-s (hasheq))

  (define (walk t s)
    (if (and (var? t) (hash-has-key? s t))
        (walk (hash-ref s t) s)
        t))

  (define (occurs? x t s)
    (let ([t (walk t s)])
      (or (eq? x t)
          (and (pair? t)
               (or (occurs? x (car t) s) (occurs? x (cdr t) s))))))

  (define (ext-s x t s)
    (if (occurs? x t s) (fail) (hash-set s x t)))

  (define (unify u v s)
    (let ([u (walk u s)] [v (walk v s)])
      (cond [(eq? u v) s]
            [(var? u) (ext-s u v s)]
            [(var? v) (ext-s v u s)]
            [(and (pair? u) (pair? v))
             (unify (cdr u) (cdr v) (unify (car u) (car v) s))]
            [(equal? u v) s]
            [else (fail)])))

  (define (walk* t s)
    (let ([t (walk t s)])
      (if (pair? t)
          (cons (walk* (car t) s) (walk* (cdr t) s))
          t)))

  ;;; ─── §8-c〔正文〕 目标：代换 → 代换 ───
  ;;; 步骤：代码 → 概念
  ;;; 散文：conj 依次应用，与 §7 的普通 ∘ 是同一件事；disj 用 choose 选一个目标；
  ;;;       fresh 在收到代换时才分配新的未知项（Astra 审阅）；run* 用 collect 收集。
  ;;;       「每条分支带着自己的代换往下走；一条分支失败，不会改动其他分支手里的代换。」
  ;;;       conj 与 ∧：前一个目标交出满足自身条件的代换，后一个在这些代换上继续求解；
  ;;;       最后留下的答案，就同时满足两个条件。
  ;;;       对应表：(conj) 是 ⊤，(disj) 是 ⊥；fail 不是目标，不进表。
  (define-type Goal (→ Substitution Substitution))
  (define-type (→ℛ x y) (→ x y Goal))                   ; §4-c

  (define ((== u v) s) (unify u v s))
  (define ((conj . g*) s) (foldl (λ (g s) (g s)) s g*))
  (define ((disj . g*) s) ((choose g*) s))

  (define-syntax-rule (fresh (x ...) g ...)
    (λ (s)
      (let ([x (var 'x)] ...)
        ((conj g ...) s))))

  (define-syntax-rule (run* (x ...) g ...)
    (let ([x (var 'x)] ...)
      (collect (λ () (walk* (list x ...) ((conj g ...) empty-s))))))

  ;;; ─── §8-c″〔正文〕 未知时也要能共享 ───
  ;;; 步骤：现象（两个目标先共享一个尚不知道值的项，之后找到的信息对它们共同生效）
  ;;; 散文（Astra 第二轮）：§8-a 说明「独立选择为什么不够」；这里说明代换真正新增的能力。
  (check-equal? (run* (x y)
                  (== x y)
                  (== y 3))
                '((3 3)))

  ;;; §8-c′〔验证〕 小例子与边界
  (check-equal? (run* (x) (disj (== x 1) (== x 2))) '((1) (2)))
  (check-equal? (run* (x y) (== `(,x 2) `(1 ,y))) '((1 2)))
  (check-equal? (run* (x) (== 1 2)) '())
  ;; 每条分支带着自己的代换
  (check-equal? (run* (x y) (disj (== x 1) (== x 2)) (== y x)) '((1 1) (2 2)))
  ;; fresh 每次运行都分配新的未知项：同一目标用两次，是两次独立的二选一
  (check-equal? (run* () (let ([g (fresh (x) (disj (== x 1) (== x 2)))]) (conj g g)))
                '(() () () ()))
  ;; occurs 检查：循环项无解
  (check-equal? (run* () (fresh (q) (== q (cons 'a q)))) '())
  ;; 对应表：空合取是 ⊤，空析取是 ⊥；列表层面保留重数
  (check-equal? (run* () (conj)) '(()))
  (check-equal? (run* () (disj)) '())
  (check-equal? (run* () (disj (== 1 1) (== 2 2))) '(() ()))
  ;; conj 按解集是 ∧：交换顺序，答案的集合不变（只含 == 的目标）
  (check-equal? (forget (run* (x y) (disj (== x 1) (== x 2)) (disj (== y x) (== y 3))))
                (forget (run* (x y) (disj (== y x) (== y 3)) (disj (== x 1) (== x 2)))))
  ;; 不同的时间线可以交出相同的答案：收集到的是答案列表，不计顺序和重复才是关系的表（Astra，初稿审阅）
  (check-equal? (run* (x) (disj (== x 1) (== x 1))) '((1) (1)))
  ;; 列表层面 disj 是有序追加：不交换
  (check-not-equal? (run* (x) (disj (== x 1) (== x 2))) (run* (x) (disj (== x 2) (== x 1))))

  ;;; ─── §8-d〔正文〕 两个只认数的目标 ───
  ;;; 限制：上下界、三条边必须已经确定，所以目标的顺序有关系；它们不是完全关系式的。
  ;;; 伪代码里的顺序恰好满足。§3 不承诺 pythᵒ 反向求解。
  ;;; 散文可加一句：数据库交给查询优化器，这门语言按写出的顺序深度优先地找。
  (: betweenᵒ (→ Term Term Term Goal))
  (define ((betweenᵒ lo x hi) s)
    ((== x (choose (inclusive-range (walk lo s) (walk hi s)))) s))

  ;; (≤ᵒ l a b c h)：一条链。两头已知，中间的项从左到右依次选：a 在 l 与 h 之间，b 在 a 与 h 之间，c 在 b 与 h 之间。
  ;; 与谓词 (<= l a b c h) 参数相同；§3 正文只用不定义，实现留到 §8。
  (: ≤ᵒ (→ Term Term * Goal))
  (define (≤ᵒ lo . rest)
    (cond
      [(null? rest) (conj)]                                ; 只有一项：恒成立，同 (<= x)
      [else
       (define hi  (last rest))
       (define mid (drop-right rest 1))
       (if (null? mid)
           (betweenᵒ lo lo hi)                             ; 没有中间项：只检查 lo ≤ hi（Astra 10/4 ⑥）
           (apply conj (for/list ([prev (cons lo mid)] [x mid])
                         (betweenᵒ prev x hi))))]))
  ;; 〔验证，Astra 10/4 ⑥〕 原来没有中间项时构造出空合取，(≤ᵒ 2 1) 错误地成功。
  (check-equal? (run* () (≤ᵒ 2 1)) '())
  (check-equal? (run* () (≤ᵒ 1 2)) '(()))
  (check-equal? (run* () (≤ᵒ 1 1)) '(()))
  (check-equal? (run* () (≤ᵒ 5))   '(()))
  ;; 各项都已确定时，≤ᵒ 成功恰好一次当且仅当 <= 为真（两项、三项、四项，取 0..3）
  (for* ([a 4] [b 4])
    (check-equal? (run* () (≤ᵒ a b)) (if (<= a b) '(()) '()))
    (for ([c 4])
      (check-equal? (run* () (≤ᵒ a b c)) (if (<= a b c) '(()) '()))
      (for ([d 4])
        (check-equal? (run* () (≤ᵒ a b c d)) (if (<= a b c d) '(()) '())))))

  (: pythᵒ (→ Term Term Term Goal))                    ; §3 正文并排给出：pyth? 交出 Boolean，pythᵒ 交出 Goal
  (define ((pythᵒ a b c) s)
    (if (pyth? (walk a s) (walk b s) (walk c s)) s (fail)))

  ;;; §8-d′〔验证〕 pythᵒ 遇到未知的 c 会出错（§3 因此不作反向承诺）
  (check-exn exn:fail? (λ () (run* (c) (pythᵒ 3 4 c))))

  ;;; ─── §8-e〔正文〕 第一版原样运行 ───
  ;;; §3-a 的伪代码逐字（test 子模块比对）。
  (module* a #f
    (provide right-triangles)
    ;; ┌正文 a
    (define (right-triangles l h)
      (run* (a b c)
        (≤ᵒ l a b c h)      ; l ≤ a ≤ b ≤ c ≤ h
        (pythᵒ a b c)))     ; a² + b² = c²
    ;; └
    (check-equal? (right-triangles 1 20)
                  '((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20)))
    ;; 〔验证〕 拆成三段 betweenᵒ 的旧写法交出同样的列表、同样的顺序（多组边界）
    (for* ([l (in-range 1 4)] [h (in-range 1 21)])
      (check-equal? (right-triangles l h)
                    (run* (a b c)
                      (betweenᵒ l a h)
                      (betweenᵒ a b h)
                      (betweenᵒ b c h)
                      (pythᵒ a b c)))))

  ;;; ─── §8-f〔正文〕 复合，以及第二版原样运行 ───
  ;;; ∘ℛ 按 §4-c 的二元等式写成变参函数：每接一段，fresh 一个中间项；零段是相等关系。
  (: ∘ℛ (∀ (p ...) (→ (→ℛ pn-1 pn) ... (→ℛ p1 p2) (→ℛ p1 pn))))
  (define ((∘ℛ . r*) x z)
    (match r*
      ['() (== x z)]
      [(list r ... f) (fresh (y) (f x y) ((apply ∘ℛ r) y z))]))

  (check-equal? (run* (q) ((∘ℛ) 7 q)) '((7)))            ; 〔验证〕零段

  (module* b #f
    (provide pick-aᵒ pick-bᵒ pick-cᵒ rightᵒ)
    (define (pick-aᵒ l×h a×h)
      (fresh (l a h)
        (== l×h `(,l ,h))
        (== a×h `(,a ,h))
        (betweenᵒ l a h)))
    ;; ┌正文 pick-bᵒ
    (define (pick-bᵒ a×h a×b×h)
      (fresh (a b h)
        (== a×h   `(,a ,h))
        (== a×b×h `(,a ,b ,h))
        (betweenᵒ a b h)))
    ;; └
    (define (pick-cᵒ a×b×h a×b×c)
      (fresh (a b c h)
        (== a×b×h `(,a ,b ,h))
        (== a×b×c `(,a ,b ,c))
        (betweenᵒ b c h)))

    (define (rightᵒ a×b×c triangle)
      (fresh (a b c)
        (== a×b×c  `(,a ,b ,c))
        (== triangle a×b×c)
        (pythᵒ a b c)))

    ;; ┌正文 b
    (define right-triangleᵒ (∘ℛ rightᵒ pick-cᵒ pick-bᵒ pick-aᵒ))

    (define (right-triangles l h)
      (run* (a b c)
        (right-triangleᵒ `(,l ,h) `(,a ,b ,c))))
    ;; └
    (check-equal? (right-triangles 1 20)
                  '((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20)))
    ;; 〔验证〕多组边界上与 §1 一致
    (for* ([l (in-range 1 4)] [h (in-range 1 16)])
      (check-equal? (right-triangles l h) (right-triangles₆ l h))))

  ;;; §8-f′〔验证〕 展开的版本（§4-e 的伪代码 c）同样成立
  (module* c #f
    (require (submod ".." b))
    ;; ┌正文 c
    (define (right-triangleᵒ l×h triangle)
      (fresh (a×h a×b×h a×b×c)
        (pick-aᵒ l×h   a×h)
        (pick-bᵒ a×h   a×b×h)
        (pick-cᵒ a×b×h a×b×c)
        (rightᵒ  a×b×c triangle)))
    ;; └
    (check-equal? (run* (a b c) (right-triangleᵒ '(1 20) `(,a ,b ,c))) triples))

  ;;; ─── §8-g〔正文〕 倒着跑 ───
  ;;; 步骤：现象（只用 == 写成的关系，给定输出求输入）
  ;;; 散文：betweenᵒ、pythᵒ 做不到，因为它们要求数已确定。§8 末尾一句：这门语言是 miniKanren 的一个精简版。
  (define (swapᵒ p q)
    (fresh (x y)
      (== p (list x y))
      (== q (list y x))))

  (check-equal? (run* (q) (swapᵒ '(1 2) q)) '(((2 1))))
  (check-equal? (run* (p) (swapᵒ p '(2 1))) '(((1 2))))

  ;;; §8-g′〔验证〕 递归关系正反都能跑（appendᵒ 不进正文）
  (define (appendᵒ l s out)
    (disj (conj (== l '()) (== s out))
          (fresh (a d res)
            (== l (cons a d))
            (== out (cons a res))
            (appendᵒ d s res))))
  (check-equal? (run* (q) (appendᵒ '(1) '(2) q)) '(((1 2))))
  (check-equal? (run* (x y) (appendᵒ x y '(1 2))) '((() (1 2)) ((1) (2)) ((1 2) ())))


  ;;; ═════════════════════════════════════════════════════════════════
  ;;; §9 只要第一组答案（run 1：退出了当前备选，没退出搜索）
  ;;; ═════════════════════════════════════════════════════════════════
  ;;; 带走：1. 只想要第一组答案，最直接的写法是拿到第一个答案就 abort；
  ;;;          结果六组全来了，去掉 abort 也一模一样。
  ;;;       2. 它结束了当前备选的计算，却没有丢弃等待其他备选的 append-map。
  ;;;          现有接口没有区分这两种退出。
  ;;; 结尾停在问句：怎样退出整个搜索？不说「必须用多个边界」。未解的线索从简，不列「单子」等词。
  ;;; 公平性至多一两句（append-map 要等当前备选的后续全部完成才处理下一个，无限的分支会饿死别的分支）。

  ;;; ─── §9-a〔正文〕 找一组就够了 ───
  ;;; 步骤：问题（用户只要第一组）→ 代码（最直接的写法：拿到第一个答案就 abort）→ 现象（六组全来了，不报错）
  ;;; 与 run* 并排：run* 是 (collect (λ () …))，即 (reset (list …))；run1 只多一个 abort。
  ;;; 回指：第三篇 abort；§7-g「其余备选在 append-map 里等着」
  (define-syntax-rule (run1 (x ...) g ...)
    (let ([x (var 'x)] ...)
      (reset (abort (list (walk* (list x ...) ((conj g ...) empty-s)))))))

  (define (first-triangle l h)
    (run1 (a b c)
      (betweenᵒ l a h)
      (betweenᵒ a b h)
      (betweenᵒ b c h)
      (pythᵒ a b c)))

  (check-equal? (first-triangle 1 20)
                '((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20)))

  ;;; ─── §9-b〔正文〕 去掉 abort，结果一模一样 ───
  ;;; 步骤：现象（abort 已在局部计算的尾位置，它根本没碰到想丢弃的工作）
  ;;; 局部诊断（散文）：它结束了当前备选的计算，却没有丢弃等待其他备选的 append-map。
  ;;; 一般结论只说「现有接口没有区分这两种退出目标」；不说「必须用多个边界」。
  (define (all-triangles l h)
    (run* (a b c)
      (betweenᵒ l a h)
      (betweenᵒ a b h)
      (betweenᵒ b c h)
      (pythᵒ a b c)))

  (check-equal? (first-triangle 1 20) (all-triangles 1 20))

  ;;; ─── §9-c〔正文〕 最小例子：abort 之后的错误被跳过，其他备选照常运行 ───
  ;;; 步骤：现象（abort 只结束了它所在的那一个备选）
  (check-equal? (reset (let ([x (choose '(1 2 3))])
                         (abort (list x))
                         (error 'unreachable)))
                '(1 2 3))
  ;;; §9-c′〔验证〕
  (check-equal? (first-triangle 3 5) '((3 4 5))))


;;; ════════════════════════════════════════════════════════════════
;;; v5.9 的后半篇（10/5 22:20 起）：最小的关系语言，建在 06 的 amb 接口上；不做合一。
;;; 正文 09「描述关系的语言」只用不定义（伪代码）；内核的定义属于后面讲实现的几节，
;;; 现在这一版是照 notes/kanren-skeleton-1005.rkt 放进来的，写到实现那几节时再定稿。
;;; 旧的内核（上面的 relational 子模块，带合一）只为旧测试留着，收尾时清理。
;;; ════════════════════════════════════════════════════════════════
(module* rel-min #f
  (require racket/dict)
  (provide (all-defined-out))

  ;; ── 内核（暂定，实现各节定稿时再整理）──
  (struct var ([name : Symbol]))                        ; 未知项，按身份区分
  (define (value-of t s)                                ; 项现在的值；未知项还没有记录就报错
    (cond [(not (var? t)) t]
          [(dict-has-key? s t) (dict-ref s t)]
          [else (error 'value-of "~a 还没有确定" (var-name t))]))
  (define (record x v s)                                ; 记下 x 是 v；已有记录或本身是值，就核对
    (cond [(not (var? x)) (check (equal? x v)) s]
          [(dict-has-key? s x) (check (equal? (dict-ref s x) v)) s]
          [else (dict-set s x v)]))
  (define (((function->relation f) . t*) s)             ; 最后一个位置是结果
    (define-values (in* out*) (split-at-right t* 1))
    (record (car out*) (apply f (for/list ([t in*]) (value-of t s))) s))
  (define (((predicate->relation p?) . t*) s)
    (check (apply p? (for/list ([t t*]) (value-of t s)))) s)
  (define (conj . g*) (apply ∘ (reverse g*)))           ; 合取：目标的复合
  (define-syntax-rule (run* (x ...) g ...)
    (let ([x (var 'x)] ...)
      (in-amb (let ([s ((conj g ...) '())]) (list (value-of x s) ...)))))

  ;; ── §9〔正文 09〕 描述关系的语言：伪代码，在这里原样运行 ──
  (define betweenᵒ (function->relation  between))
  (define pythᵒ    (predicate->relation pyth?))

  (define (right-triangles l h)
    (run* (a b c)
      (betweenᵒ l h a)     ; l ≤ a ≤ h
      (betweenᵒ a h b)     ; a ≤ b ≤ h
      (betweenᵒ b h c)     ; b ≤ c ≤ h
      (pythᵒ a b c)))      ; a² + b² = c²

  (check-equal? (right-triangles 1 20)
                '((3 4 5) (5 12 13) (6 8 10) (8 15 17) (9 12 15) (12 16 20)))
  ;; 多组边界，与 06 的 amb 版逐组相同
  (for* ([l (in-range 1 5)] [h (in-range 0 14)])
    (check-equal? (right-triangles l h) (right-triangles₈ l h)))
  ;; 条件的先后有讲究：未知项要先有值，后面的条件才读得到
  (check-exn #rx"还没有确定"
             (λ () (run* (a b c) (pythᵒ a b c) (betweenᵒ 1 20 a) (betweenᵒ a 20 b) (betweenᵒ b 20 c)))))

;;; ═══════════════════════════════════════════════════════════════════
;;; 附〔验证〕 创作者笔记的素材（v5.0 不进正文；除非某一节真的用得上）
;;; ═══════════════════════════════════════════════════════════════════

;;; 附-a 填列就是部分应用（若用，候选位置是 §8 讲空合取、空析取处；只在数学层面说）
;; 填两个参数，剩一个：一元关系 {c ∣ 3² + 4² = c²}，只有一行 5
(check-equal? (filter (λ (c) (pyth? 3 4 c)) (inclusive-range 1 100)) '(5))
;; 三个参数全填，一个不剩：零元关系，类型 (→ Boolean)，纯的只有两种
(check-equal? ((λ () (pyth? 3 4 5))) #t)
(check-equal? ((λ () (pyth? 3 4 6))) #f)

;;; 附-b 1 到 20：8000 个组合 → 1540 个候选 → 六个答案（1540 见 §1-b、§5-e；六个见 §1-a）
(check-equal? (length (for*/list ([a (inclusive-range 1 20)] [b (inclusive-range 1 20)] [c (inclusive-range 1 20)])
                        (list a b c)))
              8000)

;;; 附-c 顺序：§6-a″ 那棵树的叶子都在同一层，深度优先与逐层展开交出的顺序相同（§5-e″、§7-g‴）；
;;; 叶子深度不齐时两种走法的顺序才不同
(let ([ragged '(1 (2 3) 4)])
  (check-equal? (flatten ragged) '(1 2 3 4))                       ; 深度优先
  (check-equal? (let loop ([level ragged])                          ; 逐层
                  (if (null? level)
                      '()
                      (append (filter (negate list?) level)
                              (loop (append* (filter list? level))))))
                '(1 4 2 3)))

;;; 附-d 两种表示之间的往返（创作者笔记「范畴论侧」：Host_amb 与 Kl(List)；Noah 10/2 的 in-amb / for/amb）
;;; 列表箭头 f : a → (Listof b) 与用 choose 写的函数 g : a → b 互相得到：
;;;   g = (λ (a) (choose (f a)))            ; 把列表交给 choose（for/amb）
;;;   f = (λ (a) (collect (λ () (g a))))    ; 用 collect 收回列表（in-amb）
;;; 只在受限意义下互逆：有限终止、无其他效应、延续可多次调用、按 collect 的列表观察、一阶数据。
(let ()
  (define ((reflect-arrow f) a) (choose (f a)))
  (define ((reify-arrow g) a) (collect (λ () (g a))))
  ;; 列表 → choose → 列表：逐字相同（顺序与重复都保留）
  (for* ([f (list divisors (λ (x) (list x (* 10 x) x)) (λ (x) '()))]
         [a '(1 4 12)])
    (check-equal? ((reify-arrow (reflect-arrow f)) a) (f a)))
  (check-equal? ((reify-arrow (reflect-arrow pick-aᵒ↓)) '(1 5)) (pick-aᵒ↓ '(1 5)))
  ;; choose → 列表 → choose：放回任何一个 collect 里，观察到的列表不变
  (define (g a) (let ([x (choose (list a (+ a 1)))]) (if (odd? x) (* x x) (fail))))
  (for ([a '(1 2 3 10)])
    (check-equal? (collect (λ () (+ 100 ((reflect-arrow (reify-arrow g)) a))))
                  (collect (λ () (+ 100 (g a))))))
  ;; 保持复合与单位：收回两段的普通复合，就是两段各自收回以后的 ∘ℒ
  (check-equal? ((reify-arrow (∘ pick-b pick-a)) '(1 5))
                ((∘ℒ (reify-arrow pick-b) (reify-arrow pick-a)) '(1 5)))
  (check-equal? ((reify-arrow values) 7) (ℒ:id 7)))


;;; ═══════════════════════════════════════════════════════════════════
;;; test 子模块：运行关系语言的子模块，并核对 §3、§4 的伪代码与 §8 的代码读成的 S 表达式相同
;;; ═══════════════════════════════════════════════════════════════════
(module+ test
  (require (only-in (submod ".." lookup))
           (only-in (submod ".." relational))
           (only-in (submod ".." relational a))
           (only-in (submod ".." relational c))
           (only-in (submod ".." rel-min)))

  (define src (variable-reference->module-source (#%variable-reference)))
  (define lines (file->lines src))
  ;; 取出以 open 开头、以 close 结尾之间的行，去掉前缀 strip，读成 S 表达式
  (define (block open close strip)
    (define body
      (let loop ([ls lines] [in? #f] [acc '()])
        (cond [(null? ls) (reverse acc)]
              [(and (not in?) (string-prefix? (string-trim (car ls)) open)) (loop (cdr ls) #t acc)]
              [(and in? (string-prefix? (string-trim (car ls)) close)) (reverse acc)]
              [in? (loop (cdr ls) #t (cons (car ls) acc))]
              [else (loop (cdr ls) #f acc)])))
    (define text
      (string-join (for/list ([l body])
                     (let ([t (string-trim l #:right? #f)])
                       (if (string-prefix? t strip) (substring t (string-length strip)) t)))
                   "\n"))
    (with-input-from-string text
      (λ () (for/list ([e (in-port read)]) e))))
  (for ([name '("a" "pick-bᵒ" "b" "c")])
    (define pseudo (block (string-append ";;; ┌伪代码 " name) ";;; └" ";;;"))
    (define real   (block (string-append ";; ┌正文 " name) ";; └" ""))   ; 正文原样读取，不剥注释（Astra 第二轮）
    (check-true (pair? pseudo) name)
    (check-equal? pseudo real name)))
