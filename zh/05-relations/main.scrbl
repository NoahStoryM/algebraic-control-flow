#lang acf/scribble

@title[#:tag "05"
  #:style chapter-style]{歧路何从：表里的平行世界}

@music{特里·赖利《In C》}

@xref["04:4-named"]{第四章}的编译器处理 @racket[if] 时，把同一份剩余工作写进了两个分支，运行时却只走其中一个：测试值在分支之前算出，替我们做了选择。未来写了两次，运行了一次。如果没有这样一个值，每个备选都要走到，同一份剩余工作为每个备选各运行一次呢？@xref["04:open-threads"]{第四章结尾}给这样的树起了名字：@bold{搜索树}，一棵拥有不止一条时间线的树。

这样的树其实并不陌生。每当我们用几层嵌套循环把所有可能挨个试一遍，走的就是一棵搜索树。本章只讨论纯的、有限的搜索。

这份剩余工作藏在哪里，先放一放。我们先看看搜索交出了什么。

@table-of-contents[]

@include-section["1-table.scrbl"]
@include-section["2-timelines.scrbl"]
@include-section["3-arrows.scrbl"]
@include-section["4-language.scrbl"]
