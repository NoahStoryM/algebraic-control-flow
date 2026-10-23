;; 最初的标签以 Racket 原生 call/cc 为底层实现；后文会重新定义 call/cc。
(define primitive-call/cc call/cc)
(define-syntax-rule (case-λ clause ...) (case-lambda clause ...))
(define (goto l) (l l))
(define (label) (primitive-call/cc goto))
(define (cc) (primitive-call/cc values))
