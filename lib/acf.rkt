#lang racket/base
;; 「控制流的代数本质」Scribble 底本的共享写法。用法见 lib/README.md。
;;
;; 正文里的代码块原样写在 |{ … }| 里，核对工具（tools/run-blocks.rkt、tools/cmp-forms.rkt）
;; 直接读 .scrbl 源文件取出这些字符串，和 .md 时代一样按原样执行。这里只负责排版。
;;
;; 写法参照 ctp（Noah 10/26）：术语用 @deftech/@tech，公式用 Scribble 自带的 math，
;; 旁注用 @margin-note，练习写成「@bold{练习}：」开头的段落。
;; define-tech、tech/guide、tech/refer 取自 ctp 的 scribblings/ctp-utils.rkt（amb 的 utils.rkt 里也有同样的一份）。
(require (for-syntax racket/base syntax/parse)
         racket/list
         racket/match
         racket/string
         scribble/core
         scribble/decode
         scribble/html-properties
         (only-in scribble/manual typeset-code seclink tech deftech math margin-note)
         (only-in scribble/base linebreak hspace)
         scriblib/footnote
         (only-in scribble/example make-base-eval)
         (only-in racket/sandbox sandbox-eval-limits sandbox-memory-limit)
         racket/runtime-path)

(provide make-acf-eval
         out-block
         c m mm ty
         define-tech tech/guide tech/refer
         defterm defsym glossary-table symbol-table
         xref also-in language-links
         (rename-out [note fn])
         acf-style chapter-style)

(define-runtime-path css-file "acf.css")

;; 挂在部的 @title 上：引入样式表。
(define acf-style
  (make-style #f (list (css-addition css-file))))
;; 挂在篇的 @title 上：每个小篇在 HTML 里单独成页。
(define chapter-style
  (make-style #f (list 'toc (css-addition css-file))))

;; ---------------------------------------------------------------------------
;; 代码里的链接
;;
;; 代码块与 @c 里的标识符按下面这些库的绑定排版：着色，并链接到它们的文档（Noah 10/26：
;; 代码层面的链接与高亮不算引用外部文档）。要链接新的库，在这里加。
;; 正文里重新定义过的名字（call/cc、label、cc……）也链接到库里对应的那一个。
(require (for-label racket/base
                    racket/control
                    (only-in typed/racket/base : ∀ ∪ U → case→ define-type Values)
                    control/context))
;; 同样的绑定也交给引用本模块的文档，正文里的 @racket[call/cc] 等因此能直接链接。
(provide (for-label (all-from-out racket/base racket/control control/context)
                    : ∀ ∪ U → case→ define-type Values))

(define label-context (quote-syntax here))

;; 引用其他文档的术语（取自 ctp）：@tech/refer{continuation}、@tech/guide{…}
(define-syntax (define-tech stx)
  (syntax-parse stx
    [(_ tech/name module-path)
     (syntax/loc stx
       (define (tech/name
                #:key          [key        #f]
                #:normalize?   [normalize? #t]
                #:tag-prefixes [prefixes   #f]
                #:indirect?    [indirect?  #f]
                .
                alt)
         (apply tech
                #:key          key
                #:normalize?   normalize?
                #:doc          module-path
                #:tag-prefixes prefixes
                #:indirect?    indirect?
                alt)))]))

(define-tech tech/guide '(lib "scribblings/guide/guide.scrbl"))
(define-tech tech/refer '(lib "scribblings/reference/reference.scrbl"))

;; ---------------------------------------------------------------------------
;; 求值器
;;
;; 正文的例子用 Scribble 的 @examples 写，构建文档时真的运行（照 amb 的 amb-examples）。
;; 每个小篇建自己的求值器：@(define ev (make-acf-eval))，前文假定已有的定义用
;; @examples[#:eval ev #:hidden …] 补上。代码在 typed/racket/no-check 下运行。
(define (make-acf-eval)
  (parameterize ([sandbox-eval-limits #f] [sandbox-memory-limit #f])
    (make-base-eval #:lang 'typed/racket/no-check)))

;; ---------------------------------------------------------------------------
;; 代码块
;;
;; 例子写 @examples[#:eval ev #:label #f …]：交互的例子带提示符，定义加 #:no-prompt；
;; 只排版、不求值的代码（推导、示意、不会停的程序）写 @racketblock[…]，
;; 注释写 (code:comment "…")。不带语言的输出（矩阵等）写 @out-block|{ … }|。

(define (racket-text str)
  (typeset-code #:context label-context #:keep-lang-line? #t str))

(define (body->string strs)
  (string-append* (map (λ (s) (if (string? s) s (format "~a" s))) strs)))

(define (out-block . strs)
  (nested-flow (make-style "AcfOut" '())
               (list (paragraph (make-style #f (list 'div))
                                (verbatim-lines (body->string strs))))))

(define (verbatim-lines str)
  (add-between (for/list ([line (string-split str "\n" #:trim? #f)])
                 (element 'tt (spaces->hspace line)))
               (element #f (list (linebreak)))))

(define (spaces->hspace s)
  (for/list ([piece (regexp-match* #px" +|[^ ]+" s)])
    (if (char=? (string-ref piece 0) #\space)
        (hspace (string-length piece))
        piece)))

;; ---------------------------------------------------------------------------
;; 行内

;; 行内代码：标识符与能读成一个 S 表达式的代码片段写 @racket[…]（Scribble 自带）；
;; 读不成的（如 #lang 行）写 @c{…}，按 Racket 着色并链接，和代码块一样。
(define (c . strs)
  (typeset-code #:context label-context #:block? #f #:indent 0 #:keep-lang-line? #t (body->string strs)))

;; 公式：用 Scribble 自带的 math，照 ctp 的写法只用 Unicode，例如 @m{p ∨ ¬p}。
;; 字母排成斜体；类型名用 @ty{Label} 排成正体；代码名用 @racket[cc]。
(define (m . content) (apply math content))
(define (mm . content)
  (paragraph (make-style "AcfDisplayMath" '()) (apply math content)))
(define (ty . content) (element (make-style "AcfType" '()) content))

;; ---------------------------------------------------------------------------
;; 术语与符号
;;
;; @defterm[#:en "continuation"]{延续}  第一次作为术语出现：加粗，注英文，登记进术语表
;; @defterm[#:en "Double Negation Introduction" #:abbr "DNI"]{双重否定引入}
;; 之后每次出现都写 @tech{延续}，链回定义处（照 ctp）。defterm 底下就是 Scribble 的 deftech。
;; @defsym["¬p" "说明"]  在符号定义处放一个不可见的锚，登记进符号表；类型名写 @defsym[@ty{Label} "说明"]

;; 收集阶段按文档顺序把条目登记进表里，解析阶段的 delayed-block 再读出来。
;; （Scribble 的 resolve-get-keys 不带 part 时只看外部文档，所以自己记。）
;; 每种语言一份文档，raco setup 可能在同一个进程里排几份文档，所以按文档的根 part 分开记。
(define entries (make-weak-hasheq))   ; 根 part -> kind -> (listof (cons key vector))，倒序
(define (root-of ci) (let ([ps (collect-info-parents ci)]) (and (pair? ps) (last ps))))
(define (register! ci kind key val)
  (define table (hash-ref! entries (root-of ci) make-hash))
  (define old (hash-ref table kind '()))
  (unless (assoc key old)
    (hash-set! table kind (cons (cons key val) old))))
(define (collected root kind)
  (reverse (hash-ref (hash-ref entries root (hash)) kind '())))

;; 中文的术语后面用全角括号注英文；英文文档里的术语本身就是英文，不注，缩写用半角括号。
(define (cjk-content? content)
  (for/or ([c (in-string (content->string content))]) (char<=? #\u4E00 c #\u9FFF)))

(define (content->key content)
  (string-normalize-spaces (content->string content)))

(define (defterm #:en [en #f] #:abbr [abbr #f] #:key [key #f] . content)
  (define k (or key (content->key content)))
  (list
   (collect-element #f '() (λ (ci) (register! ci 'term k (vector content en abbr))))
   (element 'bold (list (apply deftech #:key k #:style? #f content)))
   (cond [(not (cjk-content? content)) (if abbr (list " (" abbr ")") '())]
         [(and en abbr) (list "（" (element 'italic en) "，" abbr "）")]
         [en (list "（" (element 'italic en) "）")]
         [abbr (list "（" abbr "）")]
         [else '()])))

;; sym 可以是字符串，也可以是排版好的内容（如 @ty{Label}）；键取它的文字。
(define (defsym sym description)
  (define k (content->key (list sym)))
  (list
   (collect-element #f '() (λ (ci) (register! ci 'symbol k (cons sym description))))
   (target-element #f '() (sym-tag k))))

;; 锚的标签借用 'tech 这一类：raco setup 给每份文档的标签加前缀时只处理 part、tech、cite，
;; 别的标签各文档共用一个名字空间，中英两份文档的同一个符号就会相撞。
(define (sym-tag k) (list 'tech (list "acf-sym" k)))

;; 术语表与符号表按第一次出现的顺序排列，每项链回定义处。表头按 #:lang 用中文或英文。
;; 表前放一个空的 collect-element，记下这张表属于哪份文档。
(define headers
  (hash 'zh (hash 'term "术语" 'en "英文" 'abbr "缩写" 'symbol "符号" 'meaning "含义")
        'en (hash 'term "Term" 'en "English" 'abbr "Abbreviation" 'symbol "Symbol" 'meaning "Meaning")))
(define (header lang key) (paragraph plain (hash-ref (hash-ref headers lang) key)))

(define (table-for-root make-table)
  (define root (box #f))
  (list (paragraph plain (collect-element #f '() (λ (ci) (set-box! root (root-of ci)))))
        (delayed-block (λ (renderer part ri) (make-table (unbox root))))))

(define (glossary-table #:lang [lang 'zh])
  (table-for-root
   (λ (root)
     (define rows
       (for/list ([entry (collected root 'term)])
         (define k (car entry))
         (define v (cdr entry))
         (append
          (list (paragraph plain (apply tech #:key k (vector-ref v 0))))
          (if (eq? lang 'zh)
              (list (paragraph plain (if (vector-ref v 1) (element 'italic (vector-ref v 1)) "")))
              '())
          (list (paragraph plain (or (vector-ref v 2) ""))))))
     (table (make-style 'boxed '())
            (cons (if (eq? lang 'zh)
                      (list (header lang 'term) (header lang 'en) (header lang 'abbr))
                      (list (header lang 'term) (header lang 'abbr)))
                  rows)))))

(define (symbol-table #:lang [lang 'zh])
  (table-for-root
   (λ (root)
     (define rows
       (for/list ([entry (collected root 'symbol)])
         (define k (car entry))
         (define sym (cadr entry))
         (list (paragraph plain (link-element #f (m sym) (sym-tag k)))
               (paragraph plain (cddr entry)))))
     (table (make-style 'boxed '())
            (cons (list (header lang 'symbol) (header lang 'meaning)) rows)))))

;; ---------------------------------------------------------------------------
;; 引用
;;
;; 节的标签写成 "篇号:名字"，例如 @section[#:tag "01:compare"]{比较}。
;; 回指照正文原来的说法写，链接到那一节：@xref["01:compare"]{比较一节}。
;; 篇与篇之间同样用 @xref（整个第一部是一份文档）。外部链接用 @hyperlink。
;; 文献用 scriblib/autobib（见 lib/README.md），第一篇目前没有文献引用。
(define (xref tag . content)
  (apply seclink tag content))

;; 另一种语言的同一页：@also-in['zh "01:1-labels"] 链到中文文档里标签相同的那一节。
;; 两种语言的篇、小篇和带标签的节用同样的标签，这样两边能互相指到。
;; raco setup 自己给每份文档的节标签加上文档前缀，所以两份文档用同样的标签不会相撞。
(define translations
  (hash 'zh (cons "中文版" '(lib "acf/zh/main.scrbl"))
        'en (cons "English version" '(lib "acf/en/main.scrbl"))))
(define (also-in lang tag)
  (match-define (cons text doc) (hash-ref translations lang))
  (margin-note (seclink tag #:doc doc text)))

;; 系列前言里各语言的入口：@(language-links 'zh)。当前语言不加链接。
;; 右上角的「Racket language family」是 raco setup 给每份文档加的，指的是 Racket、Rhombus
;; 这样的程序语言家族，由文档页的脚本处理，借不来做自然语言的切换。
(define language-order '(zh en))
(define language-names (hash 'zh "中文" 'en "English"))
(define (language-links current)
  (paragraph (make-style "AcfLanguages" '())
             (add-between
              (for/list ([lang (in-list language-order)])
                (define name (hash-ref language-names lang))
                (if (eq? lang current)
                    (element 'bold name)
                    (seclink "top" #:doc (cdr (hash-ref translations lang)) name)))
              " · ")))

;; 脚注用 @fn{…}（scriblib/footnote 的 note）。旁注直接用 Scribble 的 @margin-note。
