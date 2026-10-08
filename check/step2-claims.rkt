#lang racket
;; 步骤 2：逐条测试指控 a、b、c
(require "harness.rkt")

(displayln "######## a. 内建函数换名后调用")
(show "a1" '(let ([f add1]) (f 41)))
(show "a2" '(let ([g add1]) (g 1)))
(show "a3 reset 内" '(reset (let ([f add1]) (+ 1 (f 41)))))
(show "a4 对照：用户函数换名" '(let ([f (λ (x) (add1 x))]) (f 41)))
(show "a5 对照：文中的绕法，手动包成 lambda" '(let ([f (λ (x) (add1 x))]) (+ 1 (f 41))))

(displayln "######## b. 高阶：内建函数作为值传给函数")
(show "b1" '((λ (h) (h 1)) add1))
(show "b2 多参 lambda" '((λ (h x) (h x)) add1 1))
(show "b3 传给用户定义的高阶函数" '(let ([twice (λ (h x) (h (h x)))]) (twice add1 1)))
(show "b4 对照：传用户函数" '(let ([twice (λ (h x) (h (h x)))]) (twice (λ (y) (add1 y)) 1)))
;; map 不在平凡集合里，被当成用户函数；源语言没有 quote/列表字面量，用自由变量 xs
(displayln "b5: (map add1 xs)，目标程序里 xs = '(1 2)")
(require "cps.rkt")
(let ([c (cps '(map add1 xs))])
  (printf "编译输出: ~s\n" c)
  (define ns (make-base-namespace))
  (parameterize ([current-namespace ns]) (eval '(define xs '(1 2))))
  (printf "目标运行: ~s\n\n"
          (with-handlers ([exn:fail? (lambda (e) (list 'error (exn-message e)))])
            (parameterize ([current-namespace ns]) (eval c)))))

(displayln "######## c. reset 作为参数时的求值顺序")
(show "c1 trivial 调用，reset 在前" '(eq? (reset (display 1)) (display 2)))
(show "c2 trivial 调用，reset 在后（对照）" '(eq? (display 1) (reset (display 2))))
(show "c3 用户函数调用" '(let ([f (λ (a b) a)]) (f (reset (display 1)) (display 2))))
(show "c4 带值的版本" '(+ (reset (let ([a (display 1)]) 1)) (let ([b (display 2)]) 2)))
(show "c5 rator 位置" '((reset (let ([a (display 1)]) add1)) (let ([b (display 2)]) 2)))
(show "c6 reset 里有 shift" '(+ (reset (+ 10 (shift k (let ([a (display 1)]) (k 1))))) (let ([b (display 2)]) 2)))
