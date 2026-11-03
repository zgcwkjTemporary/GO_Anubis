#!/usr/bin/env bash
# 编译 Anubis Windows x64 可执行文件
# 用法: ./build_windows_exe.sh

set -euo pipefail
cd "$(dirname "$0")"

# 工具链路径
export PATH="$HOME/go-toolchain/go/bin:$HOME/node/bin:$PWD/node_modules/.bin:$PATH"
export GOROOT="$HOME/go-toolchain/go"

# 1. 构建前端资源(生成嵌入所需的 static/app.js)
if [ ! -f lib/challenge/preact/static/app.js ]; then
    echo "==> 构建前端资源 (preact app.js)..."
    (cd lib/challenge/preact && bash build.sh)
fi

# 编译输出目录
OUT_DIR="build"
mkdir -p "$OUT_DIR"

# 2. 编译 Windows x64 exe
echo "==> 编译 Windows amd64 exe..."
GOOS=windows GOARCH=amd64 go build -trimpath -o "$OUT_DIR/anubis-windows-amd64.exe" ./cmd/anubis

echo "==> 完成: $OUT_DIR/anubis-windows-amd64.exe"
