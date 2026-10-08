;; 第一篇已经给出的记号；这里不重新展示它们。
(define-type ⊥ (U))
(define-type (¬ p) (→ p ⊥))
(define-type (¬¬ p) (¬ (¬ p)))
(define (list->values v*) (apply values v*))
