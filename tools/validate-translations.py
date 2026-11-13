#!/usr/bin/env python3
"""校验 translations/client_zh_CN.ts 的完整性与占位符一致性。

用法:
    python tools/validate-translations.py [path/to/client_zh_CN.ts]

退出码 0 = 全部通过；1 = 有错误。CI 会运行此脚本。
"""

import os
import re
import sys
import xml.etree.ElementTree as ET

PH = re.compile(
    r'%(?:\d+|n|L\d+|%)'          # %1 %n %L1 %%
    r'|<[a-zA-Z/][^>]*>'          # <a href=...> </p> <br/>
    r'|\[[A-Za-z0-9_.#:/-]+\]'    # [Property]
    r'|&[a-zA-Z#0-9]+;'           # &amp;
)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, '..', 'translations', 'client_zh_CN.ts')
    path = os.path.abspath(path)
    errors = []

    try:
        tree = ET.parse(path)
    except Exception as ex:
        print('FAIL: 无法解析 %s: %s' % (path, ex))
        return 1

    root = tree.getroot()
    if root.tag != 'TS':
        errors.append('根元素不是 <TS>')
    lang = root.get('language')
    if lang != 'zh_CN':
        errors.append('language 属性应为 zh_CN，实际为 %r' % lang)

    contexts = root.findall('context')
    messages = root.findall('.//message')
    seen = set()
    unfinished = 0
    empty = 0
    ph_bad = 0

    for ctx in contexts:
        name_el = ctx.find('name')
        ctx_name = (name_el.text or '') if name_el is not None else ''
        for msg in ctx.findall('message'):
            src_el = msg.find('source')
            tr_el = msg.find('translation')
            source = (src_el.text or '') if src_el is not None else ''
            trans = (tr_el.text or '') if tr_el is not None else ''
            key = (ctx_name, source)
            if key in seen:
                errors.append('重复消息: context=%r source=%r' % key)
            seen.add(key)
            if tr_el is None or tr_el.get('type') == 'unfinished':
                unfinished += 1
                continue
            if not trans.strip():
                empty += 1
                continue
            if sorted(PH.findall(source)) != sorted(PH.findall(trans)):
                ph_bad += 1
                errors.append('占位符不一致: context=%r source=%r translation=%r' % (ctx_name, source, trans))

    qm = os.path.join(os.path.dirname(path), 'client_zh_CN.qm')
    print('文件      : %s' % path)
    print('上下文    : %d' % len(contexts))
    print('消息总数  : %d' % len(messages))
    print('未完成    : %d' % unfinished)
    print('空翻译    : %d' % empty)
    print('占位符错  : %d' % ph_bad)
    if os.path.exists(qm):
        print('语言包    : %s (%d 字节)' % (qm, os.path.getsize(qm)))
    else:
        errors.append('缺少 client_zh_CN.qm（运行 tools/rebuild-qm.ps1 生成）')

    if errors:
        print('\nFAIL: %d 个问题' % len(errors))
        for e in errors[:40]:
            print('  - ' + e)
        return 1
    print('\nOK: 翻译文件校验通过')
    return 0


if __name__ == '__main__':
    sys.exit(main())
