# Midscene CLI 源码调试指南

## 原理

通过 VS Code 调试器加载 CLI 的 CJS 编译产物（`dist/lib/index.js`），配合 source map 将断点映射回 TypeScript 源文件。

## 一次性准备

### 1. 安装 tsx（已完成，写入了 package.json）

```bash
pnpm add -Dw tsx
```

### 2. 构建 CLI 包（生成 dist + source map）

```bash
npx nx build cli
```

> 每次修改 TS 源码后都需要重新构建，否则 dist 不会更新。

### 3. 复制 .env 到项目根目录

CLI 需要 AI 模型的环境变量，从你的 YAML 测试目录复制：

```bash
cp /path/to/your/midscene自动化/.env .
```

### 4. 复制 launch.json 到 .vscode/

```bash
cp debug-config/launch.json .vscode/launch.json
```

## 使用方法

1. 在 VS Code 中打开 TS 源文件（见下方关键文件列表）
2. 在行号左侧点击，打断点（红点）
3. 按 **F5**，选择 **"Debug midscene YAML"** 启动
4. 调试器会在断点处暂停，可单步执行、查看变量、调用栈

## 需要修改的路径

`launch.json` 中只有一处需要根据你的电脑调整：

```json
"args": [
  "/your/path/to/test.yaml",   // ← 改成你的 YAML 文件绝对路径
  "--headed"
]
```

如果想调试其他 YAML 文件或去掉 `--headed`（无头模式），直接改 `args` 即可。

## 调试调用链

```
packages/cli/src/index.ts          ← CLI 主入口，参数解析
  → packages/cli/src/batch-runner.ts   ← 文件调度，浏览器启动
    → packages/cli/src/create-yaml-player.ts  ← 创建 ScriptPlayer + Agent
      → packages/core/src/yaml/player.ts       ← YAML 任务执行核心
        → packages/web-integration/src/puppeteer/agent-launcher.ts  ← 浏览器实际启动
```

## 关键断点文件

| 文件 | 作用 |
|------|------|
| `packages/cli/src/index.ts` | 主入口 |
| `packages/cli/src/cli-utils.ts` | 参数解析（--headed 等） |
| `packages/cli/src/config-factory.ts` | 配置合并 |
| `packages/cli/src/batch-runner.ts` | YAML 文件调度执行 |
| `packages/cli/src/create-yaml-player.ts` | 创建 Agent + ScriptPlayer |
| `packages/core/src/yaml/player.ts` | YAML 任务执行（aiAct/aiAssert 等） |
| `packages/web-integration/src/puppeteer/agent-launcher.ts` | 浏览器启动 |

## 工作流

```
修改 TS 源码 → npx nx build cli → F5 调试 → 查看结果
```

---

## 错误护栏：踩过的坑

### 1. 不要用 tsx 直接跑 TS 源码

**错误做法**：`program` 指向 `packages/cli/src/index.ts`，用 `tsx` 作为 runtimeExecutable。

**为什么不行**：
- 该项目是 pnpm monorepo，CLI 包通过 TypeScript project references 引用了 `core`、`web-integration`、`shared` 等包。
- `tsx` 无法正确处理跨包的 project references 和 workspace 依赖解析，运行时会在 import 阶段失败。
- 即使 `tsx` 本身支持 tsconfig paths（`@/*`），也无法穿透 monorepo 的符号链接结构正确找到所有依赖包的 TS 源码。

**正确做法**：用编译后的 CJS 产物 `dist/lib/index.js` 作为 `program`，通过 source map 映射回 TS 源码。

### 2. 本 monorepo 内不要用 ESM 产物调试

**错误现象**（monorepo 内用 tsx 加载 ESM bundle）：
```
ReferenceError: require is not defined in ES module scope
```

**为什么在本仓库会报错**：
- rslib 打包出的 ESM bundle 内部仍然包含 `require` 调用（来自 yargs 等依赖）。
- Node.js 的 ESM 模块作用域中没有 `require`，在本 monorepo 内用 tsx 加载会触发此错误。

**注意**：npm 安装的 midscene 在其他项目（如 Windows 环境）中调试 ESM 产物是可以正常工作的，因为那是一个独立的 node_modules 环境，模块解析路径不同。这个报错只在**本 monorepo 内部调试**时才会出现。

**正确做法**：本仓库内调试使用 CJS 产物 `dist/lib/index.js`。

### 3. 环境变量不会自动继承

**错误现象**：
```
Model configuration is incomplete: model name (MIDSCENE_MODEL_NAME) is required.
```

**为什么**：YAML 测试目录（如 `midscene自动化/`）里的 `.env` 文件不会被 CLI 自动发现，CLI 只从 `cwd`（项目根目录）读取 `.env`。

**正确做法**：
- 把 `.env` 复制到项目根目录，或
- 在 launch.json 中显式设置 `"envFile": "${workspaceFolder}/.env"`，或
- 在系统环境变量中配置。

### 4. 修改源码后必须重新构建

Source map 映射的是**构建时的源码快照**。如果你改了 TS 源码但没有重新 `npx nx build cli`，调试器跑的仍然是旧代码，断点位置和实际执行会对不上。

### 5. launch.json 中 tsx 不再需要

最初安装 `tsx` 是为了直接跑 TS 源码的方案，但最终方案用的是 CJS 产物 + source map，`tsx` 在调试流程中不再需要。保留它不影响项目，但不是调试的必要依赖。
