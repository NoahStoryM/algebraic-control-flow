((skip
  (("# 边界的两侧" "(ans-a (loop r* (*)))") "只展示前一节局部表达式，loop 不是顶层绑定")
  (("# 边界的两侧" "(define-type Realᵃ (∪ Real ⊥ᵃ))") "含省略号的概念类型，不是可运行定义")
  (("# 逃逸与丢弃" "(1 2 0 3 4)") "参数列表的示意数据，不是调用")
  (("# 边界中的边界" "(1 2 0 3 4)") "参数列表的示意数据，不是调用")
  (("# 定界延续" "(anf:eval") "尚未实现的调用示意")
  (("# 定界延续" "(define neg²:abort (cps->neg² cps:abort))") "带省略号的类型草图")
  (("# 定界延续" "(define-syntax-rule (let/lc k body ...)") "带省略号的宏签名")
  (("# 完整代码参考" "#lang typed/racket/no-check") "完整模块引用块含 #lang；code.rkt 原样运行")
)
 (skip
  (("# 局部延续" "(∘ a->⊥ᵃ mul1 mul2 mul3 mul4)") "未绑定 mul1…mul4 的组合示意，不是本节的独立程序")
)


 (skip
  (("# 定界延续" "(shift k (k 3))     ; 主体对应 (λ (k) (k 3))") "单独的 shift 会逃出核对器；作为规约式由 code.rkt 验证")
)

 (skip
  (("# 定界延续" "(reset val)") "reset/shift 规约元规则，val 和 E 是占位符")
  (("# 元延续" "> (reset") "阴阳谜题无限输出，由 code.rkt 限时核对前缀")
)
 (value
  (("# 返回答案" "(: mul (→ Real * Real))")
   examples ("(mul 1 2 3 4)" 24) ("(mul 1 2 0 3 4)" 0))
  (("# 局部延续" "(: mul (→ Real * Real))")
   examples ("(mul 1 2 3 4)" 24) ("(mul 1 2 0 3 4)" 0))
  (("# 否定翻译与 A-翻译" "(: mul (→ Real * Real))")
   examples ("(mul 1 2 3 4)" 24) ("(mul 1 2 0 3 4)" 0))
 )
)
