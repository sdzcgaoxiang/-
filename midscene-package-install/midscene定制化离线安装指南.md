# midscene 定制化离线安装指南

本文档指导你从源码构建 midscene 定制化版本，并分发给其他用户离线安装。

---

## 前置条件

### 构建（改源码的人）

- Node.js >= 18.19.0
- pnpm（通过 corepack 自动安装）
- 网络连接

### 安装（使用的人）

- Node.js >= 18.19.0（只需要这一个）
- 网络连接（安装第三方依赖时需要）

---

## 第一步：获取源码

```sh
git clone https://github.com/sdzcgaoxiang/midscene.git
cd midscene
```

## 第二步：修改源码

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

## 第三步：构建

```sh
corepack enable          # 首次需要，激活 pnpm
pnpm install             # 安装依赖 + 自动构建全部 33 个包
```

> 如果 `corepack enable` 报错，确保 PATH 里包含 `/opt/homebrew/bin`（macOS）或 Node.js 安装目录。

等待构建完成，看到 `Successfully ran target build for 33 projects` 即为成功。

## 第四步：打包

```sh
node scripts/pack-all-tgz.mjs
```

产物在 `tgz-output/` 目录下，共 26 个 `.tgz` 文件。

> 打包脚本会自动从 `package.json` 读取版本号。如果版本号变了，安装脚本里的 `VERSION` 变量也要同步修改（在 `scripts/install-bundle.sh` 第 14 行）。

## 第五步：分发

将以下两个东西一起给用户：

1. `tgz-output/` 目录（26 个 tgz 文件）
2. `scripts/install-bundle.sh` 安装脚本

## 第六步：用户安装

用户在自己的电脑上执行（只需要 Node.js，不需要 pnpm）：

```sh
./install-bundle.sh /path/to/tgz-output ~/midscene-bundle
```

脚本会自动完成所有配置和安装。

安装完成后使用：

```sh
cd ~/midscene-bundle
npx midscene test.yaml
```

如果希望全局可用 `midscene` 命令：

```sh
npm install -g ~/midscene-bundle
midscene test.yaml
```

---

## 脚本做了什么

### pack-all-tgz.mjs（打包脚本）

1. 扫描 `packages/` 和 `apps/` 下所有非 private 的 `@midscene/*` 包
2. 对每个包执行 `pnpm pack`，输出到 `tgz-output/` 目录

### install-bundle.sh（安装脚本）

1. 创建安装目录
2. 生成 `package.json`，内容如下：
   - `dependencies` 声明 `@midscene/cli` 指向本地 tgz
   - `overrides` 把所有 `@midscene/*` 包指向本地 tgz
3. 执行 `npm install`，npm 会：
   - 所有 `@midscene/*` 包从本地 tgz 安装（你的定制代码）
   - 第三方依赖（puppeteer、sharp 等）从 npm registry 安装原版
4. 验证安装结果

生成的 `package.json` 示例：

```json
{
  "name": "midscene-bundle",
  "private": true,
  "version": "1.0.0",
  "dependencies": {
    "@midscene/cli": "file:/path/to/tgz-output/midscene-cli-1.8.3.tgz"
  },
  "overrides": {
    "@midscene/core": "file:/path/to/tgz-output/midscene-core-1.8.3.tgz",
    "@midscene/shared": "file:/path/to/tgz-output/midscene-shared-1.8.3.tgz",
    "@midscene/web": "file:/path/to/tgz-output/midscene-web-1.8.3.tgz",
    "@midscene/android": "file:/path/to/tgz-output/midscene-android-1.8.3.tgz",
    "@midscene/ios": "file:/path/to/tgz-output/midscene-ios-1.8.3.tgz",
    "@midscene/computer": "file:/path/to/tgz-output/midscene-computer-1.8.3.tgz"
  }
}
```

---

## 为什么不用单文件 bundle

esbuild 等 JS 打包工具无法处理 native 二进制模块（`.node` 文件），包括：

- sharp（图片处理，依赖 libvips 原生库）
- libnut（键鼠控制）
- node-mac-permissions（macOS 权限管理）

打 bundle 后这些模块变成 stub，运行时行为和原版完全不同。多 tgz + npm overrides 是唯一能保证行为一致的方案。

---

## 版本号管理

每次改了源码重新打包前，需要升版本号。修改仓库根目录 `package.json` 的 `version` 字段：

```json
{
  "version": "1.8.3-custom.1"
}
```

然后同步修改所有子包的版本号（它们的 version 应和根目录一致）。同时修改 `scripts/install-bundle.sh` 第 14 行的 `VERSION` 变量。

> 不升版本号的话，用户装过旧版后不会更新。

---

## 护栏

**不要：**

- 改 monorepo 根目录的 `pnpm-workspace.yaml`、`nx.json` 等配置文件
- 在 `pnpm install` 之后手动删改 `node_modules` 或其他包的 `dist/`
- 用 `npm install -g` 安装多个 tgz（依赖关系会乱）
- 把 tgz 发到公共 npm registry（包名还是 `@midscene/*`，会冲突）
- 把 tgz 提交进 git 仓库（应由 CI 生成）
