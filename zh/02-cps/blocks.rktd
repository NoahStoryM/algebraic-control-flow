((skip
  (("# 把延续独立出来" "(define ((cps:call/cc cps:proc) kp) ...)") "只写出收到什么的骨架，函数体是省略号")
  (("# 再次隐藏延续" "(anf:let* ([v1 (cps:mul1 1)]") "想要的写法，宏在「写成宏」才定义；同一段程序在那里运行，跑出 6")
  (("# 完整代码参考" "#lang typed/racket/no-check") "完整模块引用块含 #lang，不在交互命名空间重放；code.rkt 原样运行")
)
 (skip
  (("# 嵌入语言" "> (anf:eval\n(anf:let* ([cps:yin (cps:label)])") "阴阳谜题无限输出；在 code.rkt 中限时核对前缀")
)

 (stdout
  (("# 延续与 CPS" "> (fact/k 5 (λ (ans) (displayln ans) (exit 0)))") exact "120\n")
)
 (exit
  (("# 延续与 CPS" "> (fact/k 5 (λ (ans) (displayln ans) (exit 0)))") 0)
)
 (value
  (("# 延续与 CPS" "(: mul (→ Real * Real))")
   examples ("(mul 1 2 3 4)" 24)
            ("(mul 1 2 0 3 4)" 0))
)
)
