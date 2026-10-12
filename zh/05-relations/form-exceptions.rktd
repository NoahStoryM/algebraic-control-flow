(((define ((∘ℒ g* ... f) . x*)
  (foldr append-map (apply f x*) g*))
"参数表 g* ... f 是示意写法，Racket 的剩余参数只能放在最后；code.rkt 用 split-at-right 取出最右边的箭头"))
