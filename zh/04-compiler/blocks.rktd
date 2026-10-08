((skip
  (("# 擦除延续参数" ";; 原始调用点：") "编译转换的推导，sub/body 是占位符")
  (("# 擦除延续参数" "(anf1 sub ctx)") "编译转换的推导，sub/ctx 是占位符")
  (("# 遍历语法树" "[`(,rator ,rand)") "match 分支片段，须放进函数体")
  (("# 擦除延续参数" "[(? (not/c pair?) x) (shift ctx (ctx x))]                   ; 等式 1 => x") "match 分支片段，须放进函数体")
  (("# 擦除延续参数" "[`(if ,test ,conseq ,alt)") "match 分支片段，须放进函数体")
  (("# 擦除延续参数" ";; 之前：\n[`(let ([,x ,e]) ,body)") "含省略号的对照草图")
  (("# 擦除延续参数" ";; 之前：\n[`(,rator ,rand)") "match 分支的对照草图")
  (("# 命名延续" "[`(if ,test ,conseq ,alt)\n(shift ctx\n(define t (anf0 test))") "match 分支片段，须放进函数体")
  (("# 命名延续" "[`(if ,test ,conseq ,alt)\n(shift ctx\n(define vn (fv))") "match 分支片段，须放进函数体")
  (("# 镜子破裂" "[`(reset ,body)") "match 分支片段；由 code.rkt 的 stage-delimited 与 stage-caller 核对")
  (("# 镜子破裂" ";; 定界之前：扁平的。每个 let 扩展同一个栈") "展示栈结构的伪代码")
  (("# 镜子破裂" "[`(let/lc ,k ,body)") "match 分支片段；由 code.rkt 的 stage-delimited 与 stage-caller 核对")
  (("# 调用者的延续" ";; 之前：") "对照草图，不是独立程序")
  (("# 调用者的延续" "[`(shift ,k ,body)") "带省略号的 match 分支草图")
  (("# 调用者的延续" "[`(,(? trivial? r) . ,rand*)") "match 分支片段；由 code.rkt 的 stage-caller 核对")
  (("# 教编译器做规范化" ";; Lambda 链：之前") "由 code.rkt 的 stage-caller 与最终 cps 核对 999 的脱糖结果、运行值与 lambda 个数；Lambda 链各版输出也有断言")
  (("# 教编译器做规范化" "(match `(λ (,vn) ,(ctx vn))") "含省略号的 match 分支草图")
  (("# 完整的变换器" "[`(,(? trivial? r) . ,rand*)") "match 分支片段；由 code.rkt 的最终 cps 核对两个调用分支及 reset 分支")
  (("# 完整的变换器" "[`(shift _ ,body)") "match 分支片段，须放进函数体")
  (("# 完整的变换器" "[`(if ,test ,conseq ,alt)") "match 分支片段，须放进函数体")
  (("# 完整的变换器" "[`(let ([,x* ,exp*] ...) ,body)") "match 分支片段，须放进函数体")
  (("# 完整的变换器" "['abort (cps0 '(λ (v) (shift _ v)))]") "match 分支片段，须放进函数体")
  (("# 完整的变换器" "[`(let/cc ,k ,body)") "match 分支片段，须放进函数体")
  (("# 完整代码参考" "(require racket/control)") "完整编译器由 code.rkt 执行，避免覆盖逐步定义")
)

 (skip
  (("# 擦除延续参数" "> (anf '(f (g a) (h b)))") "这一段组合展示多个期望结果；中间的 anf 版本尚不支持多参数，当前中间版未给完整可运行定义；最终变换器在 code.rkt 测试")
)

 (skip
  (("# 擦除延续参数" "(define (anf0 exp) (shift ctx (anf1 exp ctx)))") "定义后紧跟含 sub/body 自由变量的变换示意，不是一个可运行块")
)

 (skip
  (("# 命名延续" "(define fk (make-genvar 'k))") "新增命名延续的 match 分支片段，不能独立改写上一个 anf 定义")
  (("# 命名延续" "> (anf '(f (if a b c)))\n'(let ([k.0 (λ (v.1) (let ([v.0 (f v.1)]) v.0))])") "由 code.rkt 的 stage-delimited 核对命名 if 的编译输出")
)

 (skip
  (("# 镜子破裂" "> (anf '(reset (+ 1 (shift k (k 42)))))") "由 code.rkt 的 stage-delimited 核对两例编译输出与运行结果")
  (("# 镜子破裂" "(reset") "直接运行的阴阳谜题无穷输出，且 k0/kn+1 是示意名")
  (("# 镜子破裂" "> (anf '(reset\n(let* ([kn (let/lc k0 k0)]") "由 code.rkt 的 stage-delimited 核对编译输出")
  (("# 镜子破裂" "> (k0 k0)") "阴阳谜题无限输出，限时测试覆盖")
  (("# 镜子破裂" "(anf '(reset\n(let* ([label (λ () (let/lc k k))]") "由 code.rkt 的 stage-delimited 核对编译输出与运行打印 @*")
  (("# 镜子破裂" "> (anf '(reset (let ([f (λ (x) (shift k 999))]) (add1 (f 42)))))") "由 code.rkt 的 stage-delimited 核对编译输出与运行结果 1000")
  (("# 调用者的延续" "> (anf '(reset (let ([f (λ (x) (shift k 999))]) (add1 (f 42)))))") "由 code.rkt 的 stage-caller 核对编译输出；999 例同时核对运行结果 999")
  (("# 调用者的延续" "> (anf '(λ (n) (f (g n))))") "由 code.rkt 的 stage-caller 核对编译输出")
)


 (skip
  (("# 镜子破裂" "(let ([k0 (λ (kn)") "展开的阴阳谜题无限输出；最终编译器的相应无限输出在限时测试中核对前缀")
)

 (skip
  (("# 调用者的延续" "((f v.1) (λ (v.0) (k.0 v.0)))") "编译输出的子式，f/v.1/k.0 是示意变量")
  (("# 调用者的延续" "((λ (v.2) v.2) (add1 v.3))") "β 归约示意，v.3 是自由变量；由 code.rkt 的 stage-caller 归约测试核对")
)

 (skip
  (("# 再看阴阳谜题" "> (k0 (λ (v) (λ (k.0) (k.0 (k0 v)))))") "编译结果的阴阳谜题无限输出；限时核对前缀")
)
)
