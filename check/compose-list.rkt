#lang racket
;; Noah 发给 AI 的版本（五个 AI 引的都是这一行）
(define ((∘ℒ/sent . f*) . x*) (foldr append-map x* f*))
;; 10/7 凌晨本地版本
(define ((∘ℒ/local . f*) x) (foldr append-map (list x) f*))
;; 候选修法：第一个箭头收全部参数，其余照旧
(define ((∘ℒ/fix f . f*) . x*) (foldr append-map (apply f x*) (reverse f*)))
(define ((∘ℒ/fix2 . f*) . x*)
  (match (reverse f*)
    ['() (list x*)]
    [(cons f rest) (foldl (λ (g acc) (append-map g acc)) (apply f x*) rest)]))
(define (pairs l h) (for*/list ([a (in-inclusive-range l h)] [b (in-inclusive-range a h)]) (list a b)))
(define (sum p) (list (apply + p)))
(define (dbl n) (list n (* 10 n)))
(displayln (with-handlers ([exn? exn-message]) ((∘ℒ/sent sum pairs) 1 3)))
(displayln (with-handlers ([exn? exn-message]) ((∘ℒ/local sum pairs) 1 3)))
(displayln ((∘ℒ/fix2 sum pairs) 1 3))
(displayln ((∘ℒ/fix2 dbl sum pairs) 1 2))
(displayln ((∘ℒ/sent dbl sum) '(1 2)))
(displayln ((∘ℒ/fix2) 5))
(define ((∘ℒ/fix3 . f*) . x*)
  (define-values (g* f) (split-at-right f* 1))
  (foldr append-map (apply (car f) x*) g*))
(displayln ((∘ℒ/fix3 sum pairs) 1 3))
(displayln ((∘ℒ/fix3 dbl sum pairs) 1 2))
(displayln (equal? ((∘ℒ/fix3 dbl sum pairs) 1 3) ((∘ℒ/fix2 dbl sum pairs) 1 3)))
