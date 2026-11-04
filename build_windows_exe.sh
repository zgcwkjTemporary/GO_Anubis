#!/usr/bin/env bash
# 编译 Anubis Windows x64 可执行文件
# 用法: ./build_windows_exe.sh
#
# 注意: cmd/anubis 会嵌入 web/static 等目录的**全部**内容，其中 wasm 模块
# (web/static/wasm/{simd128,baseline}/*.wasm)、前端 JS 和 xess 样式都是构建
# 产物，不在 Git 仓库里。跳过资源流水线直接 go build，编出的 exe 会缺少 wasm，
# 运行时在 "error setting up challenge method argon2id/hashx/sha256:
# open static/wasm/simd128/*.wasm: file does not exist" 处失败。
# 所以本脚本必须先把资源构建齐，再编译 exe。

set -euo pipefail
cd "$(dirname "$0")"

# 工具链路径(只有这些路径真实存在时才加入，避免覆盖掉系统自带的 GOROOT)
[ -x "$HOME/go-toolchain/go/bin/go" ] && export PATH="$HOME/go-toolchain/go/bin:$PATH"
[ -x "$HOME/go-toolchain/go/bin/go" ] && export GOROOT="$HOME/go-toolchain/go"
[ -d "$HOME/node/bin" ] && export PATH="$HOME/node/bin:$PATH"
export PATH="$PWD/node_modules/.bin:$PATH"

# Rust 工具链(用于编译 wasm 模块)。优先使用工作区内安装的版本。
if [ -d "$PWD/.buildtools/cargo/bin" ]; then
    export RUSTUP_HOME="${RUSTUP_HOME:-$PWD/.buildtools/rustup}"
    export CARGO_HOME="${CARGO_HOME:-$PWD/.buildtools/cargo}"
    export PATH="$CARGO_HOME/bin:$PATH"
fi

require() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "错误: 未找到 $1，请先安装($2)" >&2
        exit 1
    fi
}

require go "https://go.dev/dl/"
require node "https://nodejs.org/"
require cargo "https://rustup.rs/"
require rustup "https://rustup.rs/"

# 1. npm 依赖(esbuild/postcss 等)
if [ ! -d node_modules ] || [ ! -x node_modules/.bin/esbuild ]; then
    echo "==> 安装 npm 依赖..."
    npm ci --no-audit --no-fund --ignore-scripts
fi

# 2. wasm 模块。没有它 exe 启动时会报 "error setting up challenge method"。
echo "==> 构建 wasm 模块..."
rustup target add wasm32-unknown-unknown >/dev/null 2>&1 || true
bash ./wasm/scripts/build_wasm.sh

# 3. wasm2js 回退版本
echo "==> 构建 wasm2js 回退版本..."
bash ./wasm/scripts/build_wasm2js.sh

# 4. templ 代码生成 + preact/bootstrap 等前端资源
echo "==> 生成代码与前端资源..."
go generate ./...

# 5. web(JS/CSS)与 xess 样式
echo "==> 构建 web 与 xess 资源..."
./web/build.sh
./xess/build.sh

# 6. 编译 Windows x64 exe
# 编译输出目录
OUT_DIR="build"
mkdir -p "$OUT_DIR"

echo "==> 编译 Windows amd64 exe..."
GOOS=windows GOARCH=amd64 go build -trimpath -o "$OUT_DIR/anubis-windows-amd64.exe" ./cmd/anubis

echo "==> 完成: $OUT_DIR/anubis-windows-amd64.exe"
