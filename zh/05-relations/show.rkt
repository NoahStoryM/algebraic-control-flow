#lang racket/base
;; 正文展示表的时候把序对的点写出来：点的左边是键，右边是值；键按最长的那个补齐空格。
;; 只改打印的样子，数据仍是 Racket 算出来的那一份。
(require racket/string)
(provide dotted)

(struct shown (text)
  #:property prop:custom-write
  (λ (s port mode) (write-string (shown-text s) port)))

(define (dotted table)
  (define keys (for/list ([row (in-list table)]) (format "~s" (car row))))
  (define width (apply max 0 (map string-length keys)))
  (define lines
    (for/list ([row (in-list table)] [k (in-list keys)])
      (format "(~a~a . ~s)" k (make-string (- width (string-length k)) #\space) (cdr row))))
  (shown (string-append "'(" (string-join lines "\n  ") ")")))
