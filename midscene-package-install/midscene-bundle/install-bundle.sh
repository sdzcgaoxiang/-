#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# midscene 离线安装脚本（npm 版，无需 pnpm）
# 用法:
#   ./install-bundle.sh <tgz目录> [安装目录]
#
# 示例:
#   ./install-bundle.sh ./tgz-output
#   ./install-bundle.sh ./tgz-output ~/my-project
# ============================================================

TGZ_DIR="$(cd "$1" && pwd)"
INSTALL_DIR="${2:-$(pwd)/midscene-bundle}"
VERSION="1.8.3"

echo "=== midscene 离线安装 ==="
echo "tgz 目录: $TGZ_DIR"
echo "安装目录: $INSTALL_DIR"
echo ""

# 检查 tgz 目录
if [ ! -d "$TGZ_DIR" ]; then
  echo "错误: tgz 目录不存在: $TGZ_DIR"
  exit 1
fi

TGZ_COUNT=$(ls "$TGZ_DIR"/midscene-*.tgz 2>/dev/null | wc -l | tr -d ' ')
if [ "$TGZ_COUNT" -eq 0 ]; then
  echo "错误: 目录中没有 midscene-*.tgz 文件: $TGZ_DIR"
  exit 1
fi
echo "找到 $TGZ_COUNT 个 tgz 包"

# 创建安装目录
mkdir -p "$INSTALL_DIR"

# 扫描所有 tgz，提取包名和路径，生成 overrides
generate_overrides() {
  local overrides=""
  for tgz in "$TGZ_DIR"/midscene-*.tgz; do
    local base=$(basename "$tgz" .tgz)
    local suffix=$(echo "$base" | sed "s/^midscene-//" | sed "s/-${VERSION}$//")
    local scoped="@midscene/${suffix}"

    if [ -n "$overrides" ]; then
      overrides="${overrides},"
    fi
    overrides="${overrides}\"${scoped}\": \"file:${tgz}\""
  done
  echo "$overrides"
}

OVERRIDES=$(generate_overrides)

# 写 package.json（用 npm 的 overrides，不需要 pnpm）
cat > "$INSTALL_DIR/package.json" << PKGJSON
{
  "name": "midscene-bundle",
  "private": true,
  "version": "1.0.0",
  "dependencies": {
    "@midscene/cli": "file:${TGZ_DIR}/midscene-cli-${VERSION}.tgz"
  },
  "overrides": {
    ${OVERRIDES}
  }
}
PKGJSON

echo ""
echo "=== package.json ==="
cat "$INSTALL_DIR/package.json"
echo ""
echo "====================="
echo ""

# 安装
echo "正在安装（npm）..."
cd "$INSTALL_DIR"
npm install --no-audit --no-fund 2>&1

# 验证
echo ""
echo "=== 验证 ==="
VERSION_CHECK=$(npx midscene --version 2>&1 || true)
if echo "$VERSION_CHECK" | grep -q "$VERSION"; then
  echo "安装成功! midscene 版本: $VERSION_CHECK"
else
  echo "警告: 版本检查输出: $VERSION_CHECK"
fi

# 提示用法
echo ""
echo "=== 使用方式 ==="
echo "1. 在安装目录下运行:"
echo "   cd $INSTALL_DIR"
echo "   npx midscene test.yaml"
echo ""
echo "2. 或者全局安装:"
echo "   npm install -g $INSTALL_DIR"
echo "   midscene test.yaml"
echo ""
echo "3. 或者在其他项目中使用:"
echo "   复制 tgz 目录到你的项目"
echo "   在 package.json 的 overrides 中指向 tgz 文件"
