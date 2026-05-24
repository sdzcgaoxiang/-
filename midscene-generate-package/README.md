# midscene 定制化打包工具

这个目录包含从 midscene 源码构建定制化安装包所需的脚本和文档。

---

## 你需要做什么

### 前置条件

- Node.js >= 18.19.0
- 网络连接

### 第一步：获取源码

```sh
git clone https://github.com/sdzcgaoxiang/midscene.git
cd midscene
```

### 第二步：修改源码

在仓库中修改你需要的包。主要目录：

| 目录 | 包名 | 说明 |
|---|---|---|
| `packages/core` | @midscene/core | AI 代理执行、规划、模型集成 |
| `packages/web-integration` | @midscene/web | Playwright/Puppeteer 集成 |
| `packages/shared` | @midscene/shared | 共享工具库 |
| `packages/cli` | @midscene/cli | CLI 命令行工具 |
| `packages/android` | @midscene/android | Android 平台 |
| `packages/ios` | @midscene/ios | iOS 平台 |
| `packages/computer` | @midscene/computer | 桌面控制 |

### 第三步：构建

```sh
corepack enable          # 首次需要，激活 pnpm
pnpm install             # 安装依赖 + 自动构建全部 33 个包
```

> 如果 `corepack enable` 报错，确保 PATH 里包含 `/opt/homebrew/bin`（macOS）或 Node.js 安装目录。
> 等待看到 `Successfully ran target build for 33 projects` 即为成功。

### 第四步：打包

将本目录的 `pack-all-tgz.mjs` 复制到 midscene 仓库的 `scripts/` 下，然后执行：

```sh
cp /path/to/midscene-generate-package/pack-all-tgz.mjs scripts/
node scripts/pack-all-tgz.mjs
```

产物在 `tgz-output/` 目录下，共 26 个 `.tgz` 文件。

> 脚本会逐个重新构建每个包并验证关键导出，确保产物完整。

### 第五步：分发

将以下两个东西一起给用户：

1. `tgz-output/` 目录（26 个 tgz 文件）
2. 本目录的 `install-bundle.sh` 安装脚本

### 第六步：用户安装

用户在自己的电脑上执行（只需要 Node.js，不需要 pnpm）：

```sh
./install-bundle.sh ./tgz-output
```

安装完成后直接使用：

```sh
midscene test.yaml
```

卸载：

```sh
npm uninstall -g @midscene/cli && rm -rf ~/.midscene-bundle
```

---

## 文件说明

| 文件 | 用途 |
|---|---|
| `pack-all-tgz.mjs` | 打包脚本，复制到 midscene 仓库的 `scripts/` 下使用 |
| `install-bundle.sh` | 安装脚本，和 tgz-output 一起分发给用户 |
| `README.md` | 本文档 |

## 版本号管理

每次改了源码重新打包前，需要升版本号：

1. 修改仓库根目录 `package.json` 的 `version` 字段
2. 同步修改所有子包的版本号（应和根目录一致）
3. 修改 `install-bundle.sh` 第 14 行的 `VERSION` 变量

> 不升版本号的话，用户装过旧版后不会更新。

## 护栏

- 不要改 monorepo 的 `pnpm-workspace.yaml`、`nx.json` 等配置文件
- 不要在 `pnpm install` 之后手动删改 `node_modules` 或其他包的 `dist/`
- 不要用 `npm install -g` 直接安装多个 tgz（依赖关系会乱）
- 不要把 tgz 发到公共 npm registry（包名还是 `@midscene/*`，会冲突）
- 不要删除用户电脑上的 `~/.midscene-bundle` 目录（全局 midscene 依赖它）
