#lang racket
;; 把 .scrbl 的正文折到每行不超过 70 栏（STYLE.md；Noah 10/26），中文字与全角标点算两栏。
;;
;; 用法：LC_ALL=C.UTF-8 racket tools/wrap-scrbl.rkt [--check] 文件 …
;;   不带 --check：就地改写；带 --check：只报告超长的行，有超长行时返回非零状态。
;;
;; 只在两处折行：两个中文字（含全角标点）之间，或一个半角空格处（空格换成换行）。
;; #lang acf 读入时会去掉两个中文字之间的换行（lib/cjk-join.rkt），空格处的换行照常排成空格，
;; 所以折行不改变排出来的文字。下面这些地方不折：
;;   @examples[…]、@racketblock[…]、@out-block|{…}| 等代码块整块；
;;   方括号里（@racket[…]、关键字参数）、字符串里、@m{…}/@mm{…}/@c{…} 里。
;; 标题行也不折（标题里的换行会带进目录）。
;; 代码块里的超长行要手工按 Racket 的缩进改，--check 会把它们列出来。
;; 中文与代码（@racket 等）之间的折行会排成一个空格；不想要这个空格时，在行尾写 @; 接续。
(provide char-cols line-cols break-points wrap-line)

(define limit 70)

(define (wide? c)
  (let ([n (char->integer c)])
    (or (<= #x1100 n #x115F) (<= #x2E80 n #xA4CF) (<= #xAC00 n #xD7A3)
        (<= #xF900 n #xFAFF) (<= #xFE30 n #xFE4F) (<= #xFF00 n #xFF60)
        (<= #xFFE0 n #xFFE6) (<= #x20000 n #x3FFFD))))
(define (cjk? c) (and (char? c) (wide? c)))
(define (char-cols c) (if (wide? c) 2 1))
(define (line-cols s) (for/sum ([c s]) (char-cols c)))

;; 整块跳过的代码形式：从开头一行起，到方括号或 |{ }| 配平为止
(define code-start #px"^\\s*@(examples|racketblock|racketblock0|interaction|out-block|tabular|title|section|subsection|subsubsection|\\(define)")

;; 一行里可以折行的位置：返回 (listof (cons 位置 种类))，种类 'cjk 表示在位置前折，'space 表示删去该空格
(define (break-points line)
  (define n (string-length line))
  (let loop ([i 0] [bracket 0] [brace-stack '()] [in-string? #f] [acc '()])
    (cond
      [(>= i n) (reverse acc)]
      [else
       (define c (string-ref line i))
       (define protected? (or in-string? (> bracket 0) (memq 'code brace-stack)))
       (cond
         [in-string?
          (loop (add1 i) bracket brace-stack (not (and (char=? c #\") (not (char=? (string-ref line (sub1 i)) #\\)))) acc)]
         [(and (char=? c #\") (> bracket 0)) (loop (add1 i) bracket brace-stack #t acc)]
         [(char=? c #\[) (loop (add1 i) (add1 bracket) brace-stack in-string? acc)]
         [(and (char=? c #\]) (> bracket 0)) (loop (add1 i) (sub1 bracket) brace-stack in-string? acc)]
         [(char=? c #\{)
          ;; @m{ @mm{ @c{ 的花括号里不折
          (define code? (regexp-match? #px"@(m|mm|c|tt|ty)$" (substring line 0 i)))
          (loop (add1 i) bracket (cons (if (or code? (memq 'code brace-stack)) 'code 'text) brace-stack) in-string? acc)]
         [(and (char=? c #\}) (pair? brace-stack)) (loop (add1 i) bracket (cdr brace-stack) in-string? acc)]
         [protected? (loop (add1 i) bracket brace-stack in-string? acc)]
         [(and (char=? c #\space) (> i 0) (< (add1 i) n)
               (not (char=? (string-ref line (sub1 i)) #\space)))
          (loop (add1 i) bracket brace-stack in-string? (cons (cons i 'space) acc))]
         [(and (> i 0) (cjk? c) (cjk? (string-ref line (sub1 i))))
          (loop (add1 i) bracket brace-stack in-string? (cons (cons i 'cjk) acc))]
         [else (loop (add1 i) bracket brace-stack in-string? acc)])])))

(define (indent-of line) (car (regexp-match #px"^\\s*" line)))

;; 把一行折成若干行，续行沿用原行的缩进
(define (wrap-line line)
  (define ind (indent-of line))
  (let loop ([line line] [acc '()])
    (if (<= (line-cols line) limit)
        (reverse (cons line acc))
        (let* ([bps (break-points line)]
               [ok (filter (λ (bp) (<= (line-cols (substring line 0 (car bp))) limit)) bps)]
               [ok (filter (λ (bp) (> (car bp) (string-length ind))) ok)]
               ;; 开头一段本身就超长（不能折的公式、链接等）时，在第一个能折的地方折
               [late (filter (λ (bp) (> (car bp) (string-length ind))) bps)])
          (if (and (null? ok) (null? late))
              (reverse (cons line acc))         ; 没有可折的位置，留着让 --check 报出来
              (let* ([bp (if (null? ok) (car late) (last ok))]
                     [head (substring line 0 (car bp))]
                     [tail (substring line (if (eq? (cdr bp) 'space) (add1 (car bp)) (car bp)))])
                (loop (string-append ind tail) (cons head acc))))))))

(define (bracket-delta line)
  ;; 粗略地数方括号与 |{ }|，用来找代码块的结尾（代码里的字符串与字符字面量不会含未配平的方括号）
  (- (+ (length (regexp-match* #rx"\\[" line)) (length (regexp-match* #rx"\\|\\{" line)))
     (+ (length (regexp-match* #rx"\\]" line)) (length (regexp-match* #rx"\\}\\|" line)))))

(define (process lines)
  (let loop ([ls lines] [depth 0] [acc '()] [long '()] [n 1])
    (cond
      [(null? ls) (values (reverse acc) (reverse long))]
      [else
       (define line (car ls))
       (cond
         [(or (> depth 0) (regexp-match? code-start line) (regexp-match? #px"^#lang" line))
          (define d (+ depth (bracket-delta line)))
          (loop (cdr ls) (max d 0) (cons line acc)
                (if (> (line-cols line) limit) (cons (cons n line) long) long) (add1 n))]
         [else
          (define out (wrap-line line))
          (loop (cdr ls) 0 (append (reverse out) acc)
                (append (for/list ([l out] #:when (> (line-cols l) limit)) (cons n l)) long)
                (add1 n))])])))

(module+ main
  (define check? #f)
  (define files
    (command-line #:once-each [("--check") "只检查，不改写" (set! check? #t)]
                  #:args files files))
  (define bad 0)
  (for ([f files])
    (define lines (file->lines f))
    (define-values (out long) (process lines))
    (unless check? (display-lines-to-file out f #:exists 'truncate))
    (for ([l long])
      (set! bad (add1 bad))
      (printf "~a:~a: ~a 栏：~a\n" f (car l) (line-cols (cdr l))
              (let ([s (cdr l)]) (substring s 0 (min 40 (string-length s)))))))
  (printf "超过 ~a 栏的行：~a\n" limit bad)
  (when (and check? (> bad 0)) (exit 1)))
