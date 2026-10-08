# 控制流的代数本质 / The Algebraic Essence of Control Flow

用 Racket 与 Typed Racket，从 `goto` 与 `label` 出发，一步步造出延续、CPS、定界延续、关系、单子与代数效应。中文先写，在[知乎](https://zhuanlan.zhihu.com/p/2019516690904401803)连载；英文版等中文定稿后再译。

A series on continuations, CPS, delimited control, relations, monads and algebraic effects, built step by step in Racket. The Chinese edition comes first; an English translation will follow once it is frozen.

## 各篇

| 篇 | 标题 | 状态 | 目录 |
| --- | --- | --- | --- |
| 一 | 标签成为逻辑之时：揭开 call/cc 的神秘面纱 | [已发表](https://zhuanlan.zhihu.com/p/2019516690904401803) | [zh/01-call-cc](zh/01-call-cc) |
| 二 | 箭头指向何方：CPS 与否定翻译 | [已发表](https://zhuanlan.zhihu.com/p/2024852076593694078) | [zh/02-cps](zh/02-cps) |
| 三 | 世界尽头有何物：我们早已熟知的边界 | [已发表](https://zhuanlan.zhihu.com/p/2032178684895946051) | [zh/03-delimited](zh/03-delimited) |
| 四 | 前沿回望之时：机器中的镜子 | [已发表](https://zhuanlan.zhihu.com/p/2049638709486735603) | [zh/04-compiler](zh/04-compiler) |
| 五 | 歧路何从：表里的平行世界 | 写作中 | [zh/05-relations](zh/05-relations) |

## 分支

- `main`：知乎上已经发出的版本。
- `dev`：写作与修订在这里推进；成熟后合入 `main`，并打标签（如 `zh-02-v2`）。

## 核对

代码在 `#lang typed/racket/no-check` 下运行，针对最新版 Racket 编写。

```sh
export LC_ALL=C.UTF-8   # 否则 Racket 读不了中文路径与参数
racket tools/run-blocks.rkt zh/01-call-cc/article.md
racket tools/run-blocks.rkt zh/02-cps/article.md
racket tools/run-blocks.rkt zh/03-delimited/article.md
racket tools/run-blocks.rkt zh/04-compiler/article.md
racket tools/run-blocks.rkt zh/05-relations/article.md 描述关系的语言   # 照原样执行正文代码块，核对每处结果
for n in 01-call-cc 02-cps 03-delimited 04-compiler; do
  racket tools/cmp-forms.rkt zh/$n/article.md zh/$n/code.rkt
done
racket tools/cmp-forms.rkt zh/05-relations/article.md zh/05-relations/code.rkt   # 正文的定义是否都在代码文件里
raco test zh/*/code.rkt
```

第一至四篇的 `blocks.rktd` 按「节标题 + 代码块开头」唯一定位例子，逐项写明不能直接执行的块及原因；`prelude.rkt` 提供前文定义，`code.rkt` 对循环定义、无限输出和编译器做隔离测试。配置的 `stdout` 以原始打印（含换行）比较，`value` 比较结果，`exit` 捕获 `exit` 而不终止核对器。第四篇逐步构造的局部 `match` 分支和未组装的中间版本在配置中标出，最终编译器在 `code.rkt` 与 `check/` 中测试。

`cmp-forms.rkt` 核对正文定义是否逐式出现在对应的 `code.rkt`，找不到时返回非零状态。推导中只有省略号而没有可执行函数体的三处定义，在各篇的 `form-exceptions.rktd` 中以**完整表达式和原因**逐条列出；正文改动使排除项过期时核对会报错。同名函数在 `code.rkt` 的不同子模块中保留各阶段版本。

参与方式见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 协议

正文 CC BY 4.0（见 [LICENSE-TEXT](LICENSE-TEXT)），代码 MIT（见 [LICENSE](LICENSE)）。
