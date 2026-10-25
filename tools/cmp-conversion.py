"""核对一篇从 .md 转成 .scrbl 之后，正文文字与代码有没有走样（#47 的验收办法）。

用法：LC_ALL=C.UTF-8 python3 tools/cmp-conversion.py zh/01-call-cc/article.md zh/01-call-cc/main.scrbl

做法：用 `scribble --text` 把 .scrbl 排成纯文本，再把 .md 去掉标记，两边都删去所有空白后比较。
.md 按段落（空行分隔，代码块整块算一段）逐段到 .scrbl 的文本里找，找到就划掉，所以段落挪了位置不算差异。
最后报告两样东西：
  1. .md 里在 .scrbl 中找不到的段落（文字改了或丢了）；
  2. .scrbl 里没被划掉的剩余文字（新加的文字）。节号「1.2.1.」这类排版产物不报。
删空白比较看不出代码缩进的变化，所以代码块另外逐字比较：.md 的每个代码块
要和 .scrbl（跟着 @include-section）里某个 @…-block|{ … }| 的内容一字不差。
"""
import os, re, subprocess, sys, tempfile

def md_paragraphs(text):
    paras, cur, fence = [], [], None
    for line in text.split('\n'):
        if fence is not None:
            if line.startswith('```'):
                paras.append(('code', '\n'.join(fence))); fence = None
            else:
                fence.append(line)
            continue
        if line.startswith('```'):
            if cur: paras.append(('text', '\n'.join(cur))); cur = []
            fence = []
            continue
        if line.strip() == '':
            if cur: paras.append(('text', '\n'.join(cur))); cur = []
        else:
            cur.append(line)
    if cur: paras.append(('text', '\n'.join(cur)))
    return paras

def strip_md(p):
    out = []
    for line in p.split('\n'):
        if re.fullmatch(r'\s*\|?[\s|:-]+\|?\s*', line) and '-' in line:   # 表格分隔行
            continue
        if line.strip() == '---':
            continue
        line = re.sub(r'^#+ ', '', line)
        line = re.sub(r'^>\s?', '', line)          # 引用框（代码块外的 > 只会是它）
        bullet = ''
        m = re.match(r'^(\d+\.|-) ', line)
        if m:                                       # scribble --text 的列表项都以 * 开头
            bullet, line = '* ', line[m.end():]
        line = re.sub(r'\[([^\]]*)\]\([^)]*\)', r'\1', line)
        # 行内代码原样保留，其余部分去掉强调记号、公式记号与表格竖线
        parts = re.split(r'(`[^`]*`)', line)
        line = bullet + ''.join(x[1:-1] if x.startswith('`') else
                                x.replace('*', '').replace('$', '').replace('|', '')
                                for x in parts)
        out.append(line)
    return '\n'.join(out)

def squash(s):
    return re.sub(r'\s+', '', s)

def scribble_text(scrbl):
    with tempfile.TemporaryDirectory() as d:
        subprocess.run(['scribble', '--text', '--dest', d, scrbl], check=True,
                       stdout=subprocess.DEVNULL)
        name = os.path.splitext(os.path.basename(scrbl))[0] + '.txt'
        return open(os.path.join(d, name), encoding='utf-8').read()

def scrbl_code(path, seen=None):
    """按文档顺序取出 .scrbl 及其包含文件里的代码块内容。"""
    src = open(path, encoding='utf-8').read()
    out = []
    for m in re.finditer(r'@include-section\["([^"]+)"\]|@(?:code|repl|eq|out)-block(?:\[[^\]]*\])?\|\{\n(.*?)\n\}\|', src, re.S):
        if m.group(1):
            out += scrbl_code(os.path.join(os.path.dirname(path), m.group(1)))
        else:
            out.append(m.group(2))
    return out

def main(md, scrbl):
    text = scribble_text(scrbl)
    text = text.replace('\\(', '').replace('\\)', '').replace('\\[', '').replace('\\]', '')
    pool = squash(text)
    missing = []
    pool = re.sub(r'-{5,}', '', pool)  # 表头下的横线
    for kind, p in md_paragraphs(open(md, encoding='utf-8').read()):
        q = squash(p if kind == 'code' else strip_md(p))
        if not q:
            continue
        i = pool.find(q)
        if i < 0:
            missing.append(p)
        else:
            pool = pool[:i] + '\0' + pool[i + len(q):]
    left = [x for x in pool.split('\0')]
    left = [re.sub(r'^\d+(\.\d+)*\.?', '', x) for x in left]
    left = [x for x in left if x]
    codes = scrbl_code(scrbl)
    md_codes = [p for kind, p in md_paragraphs(open(md, encoding='utf-8').read()) if kind == 'code']
    code_missing = [c for c in md_codes if c not in codes]
    code_extra = [c for c in codes if c not in md_codes]
    print('代码块：md %d 个，scrbl %d 个；md 有而 scrbl 没有的 %d 个，scrbl 多出的 %d 个'
          % (len(md_codes), len(codes), len(code_missing), len(code_extra)))
    for c in code_missing + code_extra:
        print('  ! ' + c.replace('\n', '\n    '))
    missing += code_missing
    print('md 里找不到的段落：%d' % len(missing))
    for p in missing:
        print('  - ' + p.replace('\n', '\n    ')[:400])
    print('scrbl 里多出的文字：%d 处' % len(left))
    for x in left:
        print('  + ' + x[:400])
    return 1 if missing else 0

if __name__ == '__main__':
    sys.exit(main(sys.argv[1], sys.argv[2]))
