#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# midscene 定制版全局安装脚本
# 用法:
#   ./install-bundle.sh <tgz目录>
#
# 示例:
#   ./install-bundle.sh ./tgz-output
# ============================================================

TGZ_DIR="$(cd "$1" && pwd)"
VERSION="1.8.3"
INSTALL_DIR="$HOME/.midscene-bundle"

echo "=== midscene 定制版全局安装 ==="
echo "tgz 目录: $TGZ_DIR"
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

# 清理：卸载旧版本
echo ""
echo "清理旧版本..."
npm uninstall -g @midscene/cli midscene 2>/dev/null || true
rm -rf "$INSTALL_DIR"

# 扫描所有 tgz，生成 overrides
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

# 写 package.json
mkdir -p "$INSTALL_DIR"
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

# 本地安装（解析所有依赖）
echo ""
echo "正在安装依赖..."
cd "$INSTALL_DIR"
npm install --no-audit --no-fund 2>&1

# 全局安装 cli（指向本地已解析的 cli 包）
echo ""
echo "正在全局安装 midscene..."
npm install -g "$INSTALL_DIR/node_modules/@midscene/cli" --no-audit --no-fund 2>&1

# 验证
echo ""
echo "=== 验证 ==="
VERSION_CHECK=$(midscene --version 2>&1 || true)
if echo "$VERSION_CHECK" | grep -q "$VERSION"; then
  echo "安装成功! midscene 版本: $VERSION_CHECK"
  echo ""
  echo "直接使用:"
  echo "  midscene test.yaml"
  echo ""
  echo "卸载:"
  echo "  npm uninstall -g @midscene/cli && rm -rf $INSTALL_DIR"
else
  echo "警告: 版本检查输出: $VERSION_CHECK"
fi
