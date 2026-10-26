#lang racket
;; 把 .scrbl 的正文折到每行不超过 70 栏（STYLE.md；Noah 10/26），中文字与全角标点算两栏。
;;
;; 用法：LC_ALL=C.UTF-8 racket tools/wrap-scrbl.rkt [--check] 文件 …
;;   不带 --check：就地改写；带 --check：只列出能折却没折的行，有这种行时返回非零状态。
;;
;; 在两处折行：半角空格处（空格换成换行），或两个中文字（含全角标点）之间。
;; Scribble 把行尾的换行排成一个空格；#lang acf/scribble 读入时去掉两侧都是中文字的换行
;; （lib/cjk-join.rkt），所以这两种折行都不改变排出来的文字。
;; 能在空格处或中文标点之后折，就不在一个词的中间折：离 70 栏不远时优先选这两种位置。
;; 改写时先把一段正文连成一行（两个中文字之间直接相连，其余用一个空格连接），再重新折。
;; 下面这些地方不动：
;;   @examples[…]、@racketblock[…]、@out-block|{…}|、@tabular[…]、标题行等整块；
;;   方括号里（@racket[…]、关键字参数）、字符串里、@math{…}/@mm{…}/@c{…} 里的空格。
;; 代码块里的长行要手工按 Racket 的缩进改。
(provide char-cols line-cols)

(define limit 70)

(define (wide? c)
  (let ([n (char->integer c)])
    (or (<= #x1100 n #x115F) (<= #x2E80 n #xA4CF) (<= #xAC00 n #xD7A3)
        (<= #xF900 n #xFAFF) (<= #xFE30 n #xFE4F) (<= #xFF00 n #xFF60)
        (<= #xFFE0 n #xFFE6) (<= #x20000 n #x3FFFD))))
(define (cjk? c) (and (char? c) (wide? c)))
(define punct (string->list "，。：；！？、）」』》"))
;; 禁则：这些字不放在行首，那些字不放在行尾
(define no-line-start (string->list "，。：；！？、）」』》…"))
(define no-line-end (string->list "（「『《"))
(define (char-cols c) (if (wide? c) 2 1))
(define (line-cols s) (for/sum ([c s]) (char-cols c)))

;; 整块跳过的形式：从开头一行起，到方括号或 |{ }| 配平为止
(define code-start
  #px"^\\s*(#lang|@\\(|@(examples|racketblock|racketblock0|interaction|out-block|tabular|title|section|subsection|subsubsection|include-section|table-of-contents|mm)\\b)")
;; 收尾一个块的行：之后的行不与它相连
(define block-end #px"(\\}\\]|^\\s*\\])\\s*$")
;; 不与上一行相连的行：块级形式的开头，或单独的收尾括号
(define block-start
  #px"^\\s*(@(itemlist|item|margin-note|nested|centered|para|defsym)\\b|[\\]}])")

(define (bracket-delta line)
  ;; 粗略地数方括号与 |{ }|，用来找代码块的结尾
  (- (+ (length (regexp-match* #rx"\\[" line)) (length (regexp-match* #rx"\\|\\{" line)))
     (+ (length (regexp-match* #rx"\\]" line)) (length (regexp-match* #rx"\\}\\|" line)))))

;; 一行里可以折行的位置：(cons 位置 种类)。'space：删去该空格；'cjk：在该字之前折
(define (break-points line)
  (define n (string-length line))
  (let loop ([i 0] [bracket 0] [braces '()] [in-string? #f] [acc '()])
    (cond
      [(>= i n) (reverse acc)]
      [else
       (define c (string-ref line i))
       (cond
         [in-string?
          (define end? (and (char=? c #\") (not (char=? (string-ref line (sub1 i)) #\\))))
          (loop (add1 i) bracket braces (not end?) acc)]
         [(and (char=? c #\") (> bracket 0)) (loop (add1 i) bracket braces #t acc)]
         [(char=? c #\[) (loop (add1 i) (add1 bracket) braces in-string? acc)]
         [(and (char=? c #\]) (> bracket 0)) (loop (add1 i) (sub1 bracket) braces in-string? acc)]
         [(char=? c #\{)
          (define code? (or (memq 'code braces)
                            (regexp-match? #px"@(math|mm|c|tt|ty)$" (substring line 0 i))))
          (loop (add1 i) bracket (cons (if code? 'code 'text) braces) in-string? acc)]
         [(and (char=? c #\}) (pair? braces)) (loop (add1 i) bracket (cdr braces) in-string? acc)]
         [(or (> bracket 0) (memq 'code braces)) (loop (add1 i) bracket braces in-string? acc)]
         [(and (char=? c #\space) (> i 0) (< (add1 i) n)
               (not (char=? (string-ref line (sub1 i)) #\space)))
          (loop (add1 i) bracket braces in-string? (cons (cons i 'space) acc))]
         [(and (> i 0) (cjk? c) (cjk? (string-ref line (sub1 i)))
               (not (memv c no-line-start))
               (not (memv (string-ref line (sub1 i)) no-line-end)))
          (loop (add1 i) bracket braces in-string? (cons (cons i 'cjk) acc))]
         [else (loop (add1 i) bracket braces in-string? acc)])])))

(define (indent-of line) (car (regexp-match #px"^\\s*" line)))

;; 把一段连成一行：两个中文字之间直接相连；行尾的 @; 去掉且直接相连；其余用一个空格
(define (join-lines lines)
  (for/fold ([acc (car lines)]) ([next (cdr lines)])
    (define body (string-trim next #:right? #f))
    (cond [(regexp-match? #px"@;\\s*$" acc)
           (string-append (regexp-replace #px"@;\\s*$" acc "") body)]
          [(and (positive? (string-length acc)) (positive? (string-length body))
                (cjk? (string-ref acc (sub1 (string-length acc))))
                (cjk? (string-ref body 0)))
           (string-append acc body)]
          [else (string-append acc " " body)])))

;; 折行：每行不超过 limit；在 limit 之前 slack 栏以内有空格或中文标点之后的位置时，优先用它，
;; 否则用最靠右的位置。续行沿用首行的缩进。
(define slack 26)
(define (good? line bp)
  (or (eq? (cdr bp) 'space) (memv (string-ref line (sub1 (car bp))) punct)))
(define (wrap-line line)
  (define ind (indent-of line))
  (let loop ([line line] [acc '()])
    (if (<= (line-cols line) limit)
        (reverse (cons line acc))
        (let* ([bps (filter (λ (bp) (> (car bp) (string-length ind))) (break-points line))]
               [width (λ (bp) (line-cols (substring line 0 (car bp))))]
               [fit (filter (λ (bp) (<= (width bp) limit)) bps)]
               [nice (filter (λ (bp) (and (good? line bp) (>= (width bp) (- limit slack)))) fit)]
               [bp (cond [(pair? nice) (last nice)]
                         [(pair? fit) (last fit)]
                         [(pair? bps) (car bps)]   ; 开头一段本身超长：在第一个能折的地方折
                         [else #f])])
          (if bp
              (let ([head (substring line 0 (car bp))]
                    [tail (substring line (if (eq? (cdr bp) 'space) (add1 (car bp)) (car bp)))])
                (loop (string-append ind tail) (cons head acc)))
              (reverse (cons line acc)))))))

;; 把文件分成：原样保留的行，和要重排的正文段（连续的正文行）
(define (process lines)
  (let loop ([ls lines] [depth 0] [para '()] [acc '()])
    (define (flush)
      (if (null? para)
          acc
          (append (reverse (wrap-line (join-lines (reverse para)))) acc)))
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
          (printf "~a：折行与 wrap-scrbl 的结果不同\n" f)
          (display-lines-to-file out f #:exists 'truncate))))
  (printf "~a 个文件~a\n" changed (if check? "需要重新折行" "已重新折行"))
  (when (and check? (> changed 0)) (exit 1)))
