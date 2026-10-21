;; 第一篇已经给出的记号；这里不重新展示它们。
(define-type ⊥ (U))
(define-type (¬ p) (→ p ⊥))
(define-type (¬¬ p) (¬ (¬ p)))
(define (list->values v*) (apply values v*))
;; 「写成宏」的练习答案：正文用到 anf:if，定义留作练习。
(define-syntax-rule (anf:if test conseq alt)
  (let ([kkb test])
    (define (cps:kb b) (if b conseq alt))
    ((cps->neg² cps:kb) kkb)))
