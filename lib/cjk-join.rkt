#lang racket/base
;; 去掉中文段落里折行留下的换行：一个单独的换行（连同下一行的缩进），
;; 若前后紧挨的字都是中文字或全角标点，就删掉；段落之间的空行、代码块里的内容都不动。
;; 读入的结果可以是 S 表达式，也可以是语法对象（read-syntax），两种都处理。
(require racket/list)
(provide join-cjk-lines)

(define (cjk? c)
  (and (char? c)
       (let ([n (char->integer c)])
         (or (<= #x2E80 n #x9FFF)     ; 部首、标点、假名、汉字等
             (<= #xF900 n #xFAFF)     ; 兼容汉字
             (<= #xFE30 n #xFE4F)     ; 竖排标点
             (<= #xFF00 n #xFFEF)     ; 全角字符
             (<= #x20000 n #x2FFFF))))) ; 扩展汉字

;; 代码类的形式原样保留
(define code-heads
  '(out-block racketblock racketblock0 racket
    examples interaction c codeblock codeblock0 verbatim tt))

(define (unwrap x) (if (syntax? x) (syntax-e x) x))

;; @-形式 (head kw v ... body ...) 的正文部分
(define (body-of lst)
  (let loop ([l (cdr lst)])
    (cond [(null? l) '()]
          [(and (keyword? (unwrap (car l))) (pair? (cdr l))) (loop (cddr l))]
          [else l])))

;; 一个元素最前（side = 'first）或最后（'last）的字；看不出来时为 #f
(define (edge x side)
  (define v (unwrap x))
  (cond [(string? v)
         (and (positive? (string-length v))
              (string-ref v (if (eq? side 'first) 0 (sub1 (string-length v)))))]
        [(and (list? v) (pair? v) (symbol? (unwrap (car v))))
         (and (not (memq (unwrap (car v)) code-heads))
              (let ([body (body-of v)])
                (and (pair? body)
                     (edge (if (eq? side 'first) (car body) (last body)) side))))]
        [else #f]))

(define (newline? x) (equal? (unwrap x) "\n"))
(define (blank? x) (let ([v (unwrap x)]) (and (string? v) (regexp-match? #px"^[ \t]+$" v))))

(define (join-list items)
  (let loop ([l items] [prev #f] [acc '()])
    (cond
      [(null? l) (reverse acc)]
      [(and (newline? (car l)) prev
            (not (newline? prev))
            (pair? (cdr l)) (not (newline? (cadr l))))
       (define rest (if (and (blank? (cadr l)) (pair? (cddr l))) (cddr l) (cdr l)))
       (if (and (pair? rest) (not (newline? (car rest)))
                (cjk? (edge prev 'last)) (cjk? (edge (car rest) 'first)))
           (loop rest prev acc)
           (loop (cdr l) (car l) (cons (car l) acc)))]
      [else
       (define x (walk (car l)))
       (loop (cdr l) x (cons x acc))])))

(define (walk x)
  (define v (unwrap x))
  (cond
    [(and (list? v) (pair? v) (symbol? (unwrap (car v))) (memq (unwrap (car v)) code-heads)) x]
    [(and (list? v) (pair? v))
     (define new (join-list v))
     (if (syntax? x) (datum->syntax x new x x) new)]
    [else x]))

(define (join-cjk-lines body)
  (if (syntax? body)
      (let ([v (syntax-e body)])
        (if (list? v) (datum->syntax body (join-list v) body body) body))
      (join-list body)))
