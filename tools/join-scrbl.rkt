#lang racket
;; 把 .scrbl 的正文每段连成一行（Noah 10/30：审稿看编译后的 HTML，中文不再折行）。
;;
;; 用法：LC_ALL=C.UTF-8 racket tools/join-scrbl.rkt [--check] 文件 …
;;   不带 --check：就地改写；带 --check：只列出还没连成一行的段落，有这种段落时返回非零状态。
;;
;; 连接时：两个中文字（含全角标点）之间直接相连；全角标点后面不留空格（原先折在标点之后、
;; 下一行以 @racket 等开头时，排出来会多一个空格）；其余用一个空格连接。行尾的 @; 去掉且直接相连。
;; 下面这些地方不动：
;;   @examples[…]、@racketblock[…]、@out-block|{…}|、@codeblock|{…}|、@tabular[…]、标题行等整块。
;; 代码块里的长行仍按 Racket 的缩进手工排。

(define (wide? c)
  (let ([n (char->integer c)])
    (or (<= #x1100 n #x115F) (<= #x2E80 n #xA4CF) (<= #xAC00 n #xD7A3)
        (<= #xF900 n #xFAFF) (<= #xFE30 n #xFE4F) (<= #xFF00 n #xFF60)
        (<= #xFFE0 n #xFFE6) (<= #x20000 n #x3FFFD))))
(define (cjk? c) (and (char? c) (wide? c)))
(define punct (string->list "，。：；！？、）」』》"))

;; 整块跳过的形式：从开头一行起，到方括号或 |{ }| 配平为止
(define code-start
  #px"^\\s*(#lang|@\\(|@(examples|racketblock|racketblock0|interaction|out-block|codeblock|tabular|title|section|subsection|subsubsection|include-section|table-of-contents|mm)\\b)")
;; 收尾一个块的行：之后的行不与它相连
(define block-end #px"(\\}\\]|^\\s*\\])\\s*$")
;; 不与上一行相连的行：块级形式的开头，或单独的收尾括号
(define block-start
  #px"^\\s*(@(itemlist|item|margin-note|nested|centered|para|defsym)\\b|[\\]}])")

(define (bracket-delta line)
  ;; 粗略地数方括号与 |{ }|，用来找代码块的结尾
  (- (+ (length (regexp-match* #rx"\\[" line)) (length (regexp-match* #rx"\\|\\{" line)))
     (+ (length (regexp-match* #rx"\\]" line)) (length (regexp-match* #rx"\\}\\|" line)))))

(define (indent-of line) (car (regexp-match #px"^\\s*" line)))

;; 把一段连成一行：两个中文字之间、全角标点之后直接相连；行尾的 @; 去掉且直接相连；其余用一个空格
(define (join-lines lines)
  (for/fold ([acc (car lines)]) ([next (cdr lines)])
    (define body (string-trim next #:right? #f))
    (cond [(regexp-match? #px"@;\\s*$" acc)
           (string-append (regexp-replace #px"@;\\s*$" acc "") body)]
          [(and (positive? (string-length acc)) (positive? (string-length body))
                (or (memv (string-ref acc (sub1 (string-length acc))) punct)
                    (and (cjk? (string-ref acc (sub1 (string-length acc))))
                         (cjk? (string-ref body 0)))))
           (string-append acc body)]
          [else (string-append acc " " body)])))

;; 全角标点后面的空格去掉（方括号、花括号代码里的不动：那里不会有全角标点后接空格的写法）
(define (drop-punct-spaces line)
  (regexp-replace* #px"([，。：；！？、）」』》]) +(?=\\S)" line "\\1"))

;; 把文件分成：原样保留的行，和要重排的正文段（连续的正文行）
(define (process lines)
  (let loop ([ls lines] [depth 0] [para '()] [acc '()])
    (define (flush)
      (if (null? para)
          acc
          (cons (drop-punct-spaces (join-lines (reverse para))) acc)))
    (cond
      [(null? ls) (reverse (flush))]
      [else
       (define line (car ls))
       (cond
         [(or (> depth 0) (regexp-match? code-start line))
          (loop (cdr ls) (max 0 (+ depth (bracket-delta line))) '() (cons line (flush)))]
         [(string=? (string-trim line) "")
          (loop (cdr ls) 0 '() (cons line (flush)))]
         [(regexp-match? block-start line)
          (loop (cdr ls) 0 (list line) (flush))]
         ;; 上一行收尾了一个块（如 @itemlist 的 }]），这一行另起一段
         [(and (pair? para) (regexp-match? block-end (car para)))
          (loop (cdr ls) 0 (list line) (flush))]
         [else (loop (cdr ls) 0 (cons line para) acc)])])))

(module+ main
  (define check? #f)
  (define files
    (command-line #:once-each [("--check") "只检查，不改写" (set! check? #t)]
                  #:args files files))
  (define changed 0)
  (for ([f files])
    (define lines (file->lines f))
    (define out (process lines))
    (unless (equal? out lines)
      (set! changed (add1 changed))
      (if check?
          (printf "~a：有段落还没连成一行\n" f)
          (display-lines-to-file out f #:exists 'truncate))))
  (printf "~a 个文件~a\n" changed (if check? "需要连成一行" "已连成一行"))
  (when (and check? (> changed 0)) (exit 1)))
