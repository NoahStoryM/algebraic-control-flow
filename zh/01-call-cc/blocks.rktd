((skip
  (("# 消除分支：`call/cc`" "(call/cc proc)") "这是程序转换的并列写法，proc 尚未给出")
  (("# 代入排中律" "(goto (label))") "goto (label) 故意无限跳转")
  (("# 代入排中律" "((label) (label))") "同一无限跳转的展开")
  (("# 代入排中律" "> (let ([yin (label)])") "阴阳谜题无限输出，未加跟踪的对应谜题由 code.rkt 限时检查")
  (("# 代入排中律" "> (let ([kn (cc)])") "阴阳谜题带跟踪的无限输出，未加跟踪的对应谜题由 code.rkt 限时检查")
  (("# 代入排中律" "(define (k0 kn)") "阴阳谜题函数展开无限输出，未加跟踪的对应谜题由 code.rkt 限时检查")
  (("# 代入排中律" "(call/cc (λ (exit) ...程序体...))") "含省略号的示意程序")
)
 (reset
  (("# 从 `call/cc` 定义标签" "(define-type Label (→ Label ⊥))"))
  (("# 从 `call/cc` 定义标签" "(define (call/cc proc)"))
  (("# 深层的逻辑" "(: cc      (∀ (p)   (→ (∪ p (→ p ⊥)))))"))
)

 (reset
  (("# 代入排中律" "(define-type (¬¬ q) (¬ (¬ q)))"))
)

 (stdout
  (("# 代入排中律" ";; 时刻 1：在上下文 C1 中，冻结最内层计算") exact "C1: enter\nC1: exit\nC2: enter\nC2: exit\n")
  (("# 代入排中律" "> (displayln (call/cc W2))") exact "C2: enter\nC2: exit\nC1: enter\nreached the frozen context C1\nC1: exit\nhello\n")
)
)
