import json, sys, re
import xml.etree.ElementTree as ET
src=sys.argv[1]; out=sys.argv[2]
arr=json.load(open(src,encoding='utf-8'))
xml=None
for item in arr:
    t=item.get('text','')
    try:
        j=json.loads(t)
        xml=j['data']['xml']; rev=j['data']['rev']
    except Exception:
        continue
assert xml
root=ET.fromstring(xml)
def inline(p):
    s=''
    for t in p:
        if t.tag!='text': 
            s+=inline(t); continue
        if len(t)==0:
            s+=(t.text or '')
        else:
            for c in t:
                txt=''.join(c.itertext())
                if c.tag=='code':
                    s+=('`` '+txt+' ``') if '`' in txt else ('`'+txt+'`')
                elif c.tag=='bold': s+='**'+txt+'**'
                elif c.tag=='link': s+='['+txt+']('+c.get('href','')+')'
                else: s+=txt
                s+=(c.tail or '')
            s=(t.text or '')+s if False else s
    return s
def merge_code(s):
    # adjacent code runs like `a``b` -> `ab`
    prev=None
    while prev!=s:
        prev=s
        s=re.sub(r'`([^`\n]+)``([^`\n]+)`', r'`\1\2`', s)
    return s
lines=[]
def block(b):
    if b.tag=='paragraph':
        h=b.get('heading')
        txt=merge_code(inline(b))
        lines.append(('#'*int(h)+' ' if h else '')+txt); lines.append('')
    elif b.tag=='codeBlock':
        lines.append('```'+(b.get('language') or '')); lines.append(''.join(b.itertext())); lines.append('```'); lines.append('')
    elif b.tag=='horizontalRule':
        lines.append('---'); lines.append('')
    elif b.tag=='table':
        rows=b.findall('row')
        for i,r in enumerate(rows):
            cells=[merge_code(' '.join(inline(p) for p in c.findall('paragraph'))) for c in r.findall('cell')]
            lines.append('| '+' | '.join(cells)+' |')
            if i==0: lines.append('|'+' --- |'*len(cells))
        lines.append('')
    elif b.tag=='list':
        for it in b.findall('listItem'):
            lines.append('- '+merge_code(' '.join(inline(p) for p in it.findall('paragraph'))))
        lines.append('')
    else:
        lines.append('<!-- '+b.tag+' -->'); lines.append('')
for b in root: block(b)
open(out,'w',encoding='utf-8').write('\n'.join(lines))
print('rev',rev,'blocks',len(root),'chars',len('\n'.join(lines)))
