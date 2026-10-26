#!/usr/bin/env python3
"""Refuse to replace an app bundle whose executable is still running.

Used immediately before build.sh removes its output bundle. Code-signing checks
of a live process can fail when the signed files beneath it are replaced.
"""
from pathlib import Path
import subprocess
import sys


def main():
    if len(sys.argv) != 2 or Path(sys.argv[1]).suffix != ".app":
        print("Build output must be an .app bundle path", file=sys.stderr)
        return 2
    app = Path(sys.argv[1]).resolve()
    executables = app / 'Contents/MacOS'
    processes = subprocess.check_output(['ps', '-ax', '-o', 'pid=,comm='], text=True)
    running = []
    for line in processes.splitlines():
        fields = line.strip().split(None, 1)
        if len(fields) != 2:
            continue
        pid, command = fields
        if Path(command).resolve().parent == executables:
            running.append(pid)
    if running:
        print(f'拒绝覆盖正在运行的应用：{app}（PID {", ".join(running)}）。'
              '请先退出应用再构建；发布构建应使用独立的 APP_OUTPUT 路径。', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
