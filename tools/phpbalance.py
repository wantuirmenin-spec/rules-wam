"""Checagem aproximada de balanceamento de {} () [] nos trechos PHP (ignora strings, comentários e HTML)."""
import sys


def check(path):
    src = open(path, encoding="utf-8").read()
    i, n = 0, len(src)
    in_php = src.startswith("<?php") is False and False
    stack = []
    line = 1
    pairs = {")": "(", "]": "[", "}": "{"}
    # começa fora do PHP; entra em <?php / <?=, sai em ?>
    mode = "html"
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
        if mode == "html":
            if src.startswith("<?php", i):
                mode = "php"; i += 5; continue
            if src.startswith("<?=", i):
                mode = "php"; i += 3; continue
            i += 1; continue
        # modo php
        if src.startswith("?>", i):
            mode = "html"; i += 2; continue
        if src.startswith("//", i) or c == "#":
            while i < n and src[i] != "\n" and not src.startswith("?>", i):
                i += 1
            continue
        if src.startswith("/*", i):
            j = src.find("*/", i + 2)
            line += src.count("\n", i, j)
            i = j + 2; continue
        if c in "'\"":
            q = c; i += 1
            while i < n and src[i] != q:
                if src[i] == "\\":
                    i += 1
                if i < n and src[i] == "\n":
                    line += 1
                i += 1
            i += 1; continue
        if src.startswith("<<<", i):  # heredoc
            j = src.find("\n", i)
            tag = src[i + 3:j].strip().strip("'\"")
            k = src.find("\n" + tag, j)
            line += src.count("\n", i, k)
            i = k + 1 + len(tag); continue
        if c in "({[":
            stack.append((c, line))
        elif c in ")}]":
            if not stack or stack[-1][0] != pairs[c]:
                print(f"{path}: '{c}' inesperado na linha {line} (topo: {stack[-1] if stack else None})")
                return False
            stack.pop()
        i += 1
    if stack:
        print(f"{path}: não fechados: {stack[-5:]}")
        return False
    print(f"{path}: OK")
    return True


ok = all([check(p) for p in sys.argv[1:]])
sys.exit(0 if ok else 1)
