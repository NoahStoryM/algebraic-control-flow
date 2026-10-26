#lang info

(define license '(MIT AND CC-BY-4.0))   ; 代码 MIT，正文 CC BY 4.0
(define collection "acf")
(define version "0.1")

(define pkg-desc "The Algebraic Essence of Control Flow (控制流的代数本质)")

(define deps '("base"))
(define build-deps
  '("scribble-lib"
    "racket-doc"
    "typed-racket-lib"
    "typed-racket-doc"
    "rackunit-lib"
    "control-context"))

;; 每种语言一份文档，文档名带语言后缀：acf-zh，以后 acf-en（Noah 10/26）。
(define scribblings '(("zh/main.scrbl" (multi-page) (teaching -30) "acf-zh")))

;; prelude.rkt 不是模块（核对工具用 load 读入）；tools/ 是命令行脚本；check/ 是第四篇的核对材料。
(define compile-omit-paths
  '("tools" "check"
    "zh/02-cps/prelude.rkt"
    "zh/03-delimited/prelude.rkt" "zh/04-compiler/prelude.rkt"))
;; 只测各篇的 code.rkt，与 README 里的 raco test zh/*/code.rkt 一致。
(define test-omit-paths '(#px"^(?!.*code[.]rkt$)"))
(define clean '("compiled" "lib/compiled"))
