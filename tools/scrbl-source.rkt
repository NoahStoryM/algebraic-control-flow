#lang racket
;; 从 .scrbl 源文件取出正文代码块，供 run-blocks.rkt 与 cmp-forms.rkt 使用。
;;
;; 不执行文档，只用 Scribble 的 @-读取器把源文件读成数据，按文档顺序找：
;;   @title / @section     分节（核对按 @section 分节，和 .md 的「# 」一节对应）
;;   @include-section[…]   跟着读进被包含的文件（相对路径），篇的 main.scrbl 由此串起各小篇
;;   @code-block @repl-block @eq-block @out-block   四种代码块（写法见 lib/acf.rkt）
;; 代码块的关键字参数就是核对配置，含义与 blocks.rktd 相同：
;;   #:skip "原因"  #:reset #t  #:stdout '(exact "…")  #:value '(equal v)
;;   #:error "正则"  #:exit 0
(require scribble/reader)
(provide (struct-out sblock) scrbl-sections)

;; kind：'code 'repl 'eq 'out；opts：配置名 -> 参数表（与 blocks.rktd 每项的参数相同）
(struct sblock (kind source opts file) #:transparent)

(define block-kinds
  (hash 'code-block 'code 'repl-block 'repl 'eq-block 'eq 'out-block 'out))
(define section-heads '(section))
(define option-kinds '(skip reset stdout value error exit))

(define (read-scrbl path)
  (define text (file->string path))
  (define body (regexp-replace #px"^#lang[^\n]*\n" text ""))
  (define in (open-input-string body))
  (port-count-lines! in)
  (read-inside in))

;; 去掉关键字参数，返回 (values 关键字表 其余参数)
(define (split-keywords args)
  (let loop ([args args] [kws '()] [rest '()])
    (match args
      ['() (values (reverse kws) (reverse rest))]
      [(list (? keyword? k) v more ...) (loop more (cons (cons k v) kws) rest)]
      [(list x more ...) (loop more kws (cons x rest))])))

(define (flatten-text x)
  (cond [(string? x) x]
        [(and (pair? x) (symbol? (car x)))
         (define-values (_ args) (split-keywords (cdr x)))
         (string-append* (map flatten-text args))]
        [(list? x) (string-append* (map flatten-text x))]
        [else ""]))

(define (unquote-datum v)
  (match v [(list 'quote d) d] [d d]))

(define (block-options kws file)
  (for/hash ([kw kws])
    (define name (string->symbol (keyword->string (car kw))))
    (unless (memq name option-kinds)
      (error 'scrbl "~a：未知的核对配置 #:~a" file name))
    (define v (unquote-datum (cdr kw)))
    (values name
            (case name
              [(reset) (if (eq? v #t) '() (error 'scrbl "~a：#:reset 只接受 #t" file))]
              [(stdout value) (if (list? v) v (error 'scrbl "~a：#:~a 要写成列表" file name))]
              [else (list v)]))))

;; 返回 (listof (cons 节标题 (listof sblock)))，按文档顺序；跨文件连续。
(define (scrbl-sections main)
  (define sections '())          ; 倒序
  (define current-title #f)
  (define current-blocks '())
  (define (flush!)
    (when (or current-title (pair? current-blocks))
      (set! sections (cons (cons (or current-title "") (reverse current-blocks)) sections)))
    (set! current-blocks '()))
  (define (walk-file path)
    (define dir (path-only (path->complete-path path)))
    (for ([x (read-scrbl path)]) (walk x dir path)))
  (define (walk x dir file)
    (when (and (pair? x) (symbol? (car x)))
      (define head (car x))
      (define-values (kws args) (split-keywords (cdr x)))
      (cond
        [(eq? head 'title)
         (flush!) (set! current-title (flatten-text args))]
        [(memq head section-heads)
         (flush!) (set! current-title (flatten-text args))]
        [(eq? head 'include-section)
         (walk-file (build-path dir (car args)))]
        [(hash-ref block-kinds head #f)
         => (λ (kind)
              (unless (andmap string? args)
                (error 'scrbl "~a：代码块里只能是原样文字，请用 |{…}|：~s" file x))
              (set! current-blocks
                    (cons (sblock kind (string-append* args) (block-options kws file) file)
                          current-blocks)))]
        [else (for ([y (cdr x)]) (walk y dir file))])))
  (walk-file main)
  (flush!)
  (reverse sections))
