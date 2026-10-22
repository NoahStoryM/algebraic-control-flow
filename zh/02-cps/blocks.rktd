((skip
  (("# 把延续独立出来" "(define ((cps:call/cc cps:proc) kp) ...)") "只写出收到什么的骨架，函数体是省略号")
  (("# 再次隐藏延续" "(anf:let ([v (cps:+ 1 2)])") "anf:let 的示意程序，变量未绑定")
  (("# 再次隐藏延续" "(anf:let* ([y (cps:f x)]") "照 let* 读的示意程序，此时宏还没有定义，cps:f 等未绑定")
  (("# 再次隐藏延续" "(let ([kk3 (cps:+ 1 2)])") "具体例子的宏展开，交回一段计算，正文接着用 cps->neg² 与 anf:let 跑出结果")
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
