((skip
  (("# 否定的层次" "(define (+/k . args-and-k) ...)  ; 哪个参数是 k？") "含省略号的参数讨论，不是定义")
  (("# 再次隐藏延续" "(anf:let ([v (cps:+ 1 2)])") "anf:let 的示意程序，变量未绑定")
  (("# 再次隐藏延续" "(let ([kkv (cps:+ 1 2)])              ; kkv : ¬¬Nat") "等价改写示意，变量未绑定")
  (("# 嵌入语言" "(let* ([n-1 (- n 1)]") "ANF 片段示意，变量未绑定")
  (("# 完整代码参考" "#lang typed/racket/no-check") "完整模块引用块含 #lang，不在交互命名空间重放；code.rkt 原样运行")
)
 (skip
  (("# 嵌入语言" "(define (cps:label) (cps:call/cc cps:id))") "阴阳谜题无限输出；在 code.rkt 中限时核对前缀")
)

 (stdout
  (("# 延续与 CPS" "(fact/k 5 (λ (ans) (displayln ans) (exit 0)))") exact "120\n")
)
 (exit
  (("# 延续与 CPS" "(fact/k 5 (λ (ans) (displayln ans) (exit 0)))") 0)
)
 (value
  (("# 延续与 CPS" "(⊥->a (fact/k 5 a->⊥))   ; => 120")
   examples ("(⊥->a (fact/k 5 a->⊥))" 120)
            ("(⊥->a (fib/k 10 a->⊥))" 55))
  (("# 延续与 CPS" "(: mul (→ Real * Real))")
   examples ("(mul 1 2 3 4)" 24)
            ("(mul 1 2 0 3 4)" 0))
)
)
