#!/usr/bin/env python3
"""扫描仓库中可能泄露个人隐私/内部信息的文本内容。

用法:
    python tools/check-privacy.py            # 扫描仓库（默认）
    python tools/check-privacy.py --root .   # 指定目录

退出码 0 = 未发现敏感信息；1 = 发现（并列出位置）。

CI 会运行此脚本，防止把本机路径、机器名、内网域名、邮箱、手机号等误提交进仓库。
注意：这是启发式检查，不能代替人工检查截图等非文本内容。
"""

import argparse
import os
import re
import sys

# 只扫描文本类文件，二进制（.png/.qm/.exe/.dll/.msi）跳过
TEXT_EXT = {
    '.md', '.ts', '.txt', '.json', '.yml', '.yaml', '.ps1', '.bat', '.cmd',
    '.python', '.py', '.cs', '.manifest', '.config', '.xml', '.html', '.csv',
    '.gitignore', '.gitattributes', '', '.editorconfig',
}

SKIP_DIRS = {'.git', 'dist', 'bin', 'obj', '__pycache__', 'node_modules', '.vs'}

# 扫描脚本自身包含检测用的正则字符串，跳过以免自我命中
SKIP_FILES = {'check-privacy.py'}

# (正则, 说明)  —— 只放高信号模式，避免把应用自身字符串（Personal/Shares 等）误判
PATTERNS = [
    (r'[A-Za-z]:\\Users\\[^\\\s]+',              'Windows 用户目录路径（含用户名）'),
    (r'C:/Users/[^/\s]+',                        'Windows 用户目录路径（含用户名）'),
    (r'\bDESKTOP-[A-Z0-9]{5,}\b',                '计算机名'),
    (r'[A-Za-z0-9][A-Za-z0-9.-]*\.lab\b',        '内部域名'),
    (r'\bdefault-workspace\b',                   '开发工作区路径'),
    (r'\b(?:10|192\.168|172\.(?:1[6-9]|2\d|3[01]))\.\d{1,3}\.\d{1,3}\b', '内网 IP'),
    (r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}', '邮箱地址'),
    (r'(?<!\d)1[3-9]\d{9}(?!\d)',                '中国大陆手机号'),
    (r'\b[A-Za-z]:\\[A-Za-z0-9_.-]+\\(?:Users|Documents|Desktop)\b', '本机绝对路径'),
]


def walk(root):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            if name in SKIP_FILES:
                continue
            ext = os.path.splitext(name)[1].lower()
            if ext in SKIP_DIRS:
                continue
            if ext not in TEXT_EXT and name not in ('.gitignore', '.gitattributes'):
                continue
            yield os.path.join(dirpath, name)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', default=os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    args = ap.parse_args()

    root = os.path.abspath(args.root)
    findings = []
    scanned = 0
    current_repo = os.path.basename(os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')))
    for path in walk(root):
        scanned += 1
        rel = os.path.relpath(path, root)
        try:
            text = open(path, 'r', encoding='utf-8', errors='ignore').read()
        except OSError:
            continue
        for lineno, line in enumerate(text.split('\n'), 1):
            for pattern, desc in PATTERNS:
                for m in re.finditer(pattern, line):
                    hit = m.group(0)
                    # 允许仓库自身的名字出现在路径中
                    if hit.strip('/\\').lower() == current_repo.lower():
                        continue
                    findings.append((rel, lineno, desc, hit))

    print('扫描文件数: %d' % scanned)
    if not findings:
        print('OK: 未发现个人隐私/内部信息模式')
        return 0

    print('FAIL: 发现 %d 处疑似敏感信息' % len(findings))
    for rel, lineno, desc, hit in findings[:100]:
        print('  %s:%d  [%s]  %s' % (rel, lineno, desc, hit))
    print('\n请移除或脱敏后重新提交；截图等非文本内容需要人工检查。')
    return 1


if __name__ == '__main__':
    sys.exit(main())
