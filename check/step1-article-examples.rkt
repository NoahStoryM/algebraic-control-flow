#lang racket
;; 步骤 1：文中例子回归
(require "harness.rkt")

(show "if 顶层" '(if a b c))
(show "if 在 add1 下" '(add1 (if a b c)))
(show "if 在 f 下" '(f (if a b c)))
(show "lambda 链" '(λ (n) (f (g n))))
(show "999" '(reset (let ([f (λ (x) (shift k 999))]) (add1 (f 42)))))
(show "abort 一等值" '(reset (let ([f abort]) (+ 1 (f 5)))))
(show "let/cc" '(let ([k (reset (let ([x (let/cc k (abort k))]) (+ x 2)))])
                  (+ (reset (k 3)) 100)))
(show "例1" '(let ([v (reset (let* ([x 3] [y (+ 2 x)]) (abort y)))]) (+ 10 v)))
(show "例2" '(let ([v (reset (let* ([x (shift k 3)] [y (+ 2 x)]) (abort y)))]) (+ 10 v)))
(show "例3" '(let ([v (reset (let* ([x (shift k (k 3))] [y (+ 2 x)]) (abort y)))]) (+ 10 v)))
(show "例4" '(let ([v (reset (let* ([x (shift k (let ([r (k 3)]) (k r)))] [y (+ 2 x)]) (abort y)))]) (+ 10 v)))
(show "阴阳 label 版" '(reset
       (let* ([label (λ () (let/lc k k))]
              [yin   (label)]
              [_     (display #\@)]
              [yang  (label)]
              [_     (display #\*)])
         (yin yang))))
(show "id 裸延续" '(let ([id (reset (shift k k))]) (id (id 3))))
(show "id 包装" '(let ([id (reset (shift k (λ (v) (k v))))]) (id (id 3))))
(show "阴阳 包装版" '(reset
       (let* ([kn (let/lc k0   (λ (v) (k0   v)))]
              [_  (display #\@)]
              [k  (let/lc kn+1 (λ (v) (kn+1 v)))]
              [_  (display #\*)])
         (kn k))))
