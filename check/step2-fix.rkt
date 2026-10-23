#lang racket
;; 用修补版 cps-fix.rkt 重跑文中例子和指控 a/b/c
(require "harness.rkt" (prefix-in fix: "cps-fix.rkt"))
(current-cps fix:cps)
(displayln "######## 文中例子（修补版）")
(dynamic-require "step1-article-examples.rkt" #f)
(displayln "######## 指控 a/b/c（修补版）")
(dynamic-require "step2-claims.rkt" #f)
