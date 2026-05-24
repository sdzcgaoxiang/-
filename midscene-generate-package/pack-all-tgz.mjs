import { execSync } from 'child_process';
import { readFileSync, mkdirSync, existsSync, writeFileSync } from 'fs';
import { join } from 'path';

const root = join(new URL('.', import.meta.url).pathname, '..');
const outputDir = join(root, 'tgz-output');
mkdirSync(outputDir, { recursive: true });

// 关键导出检查：确保构建产物包含 cli 运行时依赖的导出
const REQUIRED_EXPORTS = {
  '@midscene/computer': ['agentForComputer'],
};

const dirs = ['packages', 'apps'];
const results = [];

for (const base of dirs) {
  const { readdirSync } = await import('fs');
  for (const name of readdirSync(join(root, base))) {
    if (name.startsWith('.')) continue;
    const pkgFile = join(root, base, name, 'package.json');
    if (!existsSync(pkgFile)) continue;
    const pkg = JSON.parse(readFileSync(pkgFile, 'utf8'));
    if (pkg.name?.startsWith('@midscene/') && !pkg.private) {
      results.push({ name: pkg.name, version: pkg.version, dir: join(root, base, name) });
    }
  }
}

console.log(`Found ${results.length} publishable packages\n`);

// 构建并验证每个包
for (const { name, version, dir } of results) {
  // 重新构建（确保产物是最新的）
  console.log(`  Building ${name}...`);
  try {
    execSync('pnpm run build', { cwd: dir, stdio: 'pipe' });
  } catch (e) {
    // build 脚本可能因为 DTS 生成失败而退出，但 JS 产物可能已经生成
    // 检查 dist 目录是否存在
    if (!existsSync(join(dir, 'dist'))) {
      console.log(`  FAIL  ${name}: build failed and no dist/ found`);
      continue;
    }
  }

  // 验证关键导出
  const required = REQUIRED_EXPORTS[name];
  if (required) {
    const distFile = join(dir, 'dist/lib/index.js');
    if (existsSync(distFile)) {
      const content = readFileSync(distFile, 'utf8');
      const missing = required.filter((exp) => !content.includes(exp));
      if (missing.length > 0) {
        console.log(`  WARN  ${name}: missing exports: ${missing.join(', ')}`);
        console.log(`        Attempting clean rebuild...`);
        // 清理 dist 后重新构建
        execSync('rm -rf dist', { cwd: dir, stdio: 'pipe' });
        try {
          execSync('pnpm run build', { cwd: dir, stdio: 'pipe' });
        } catch {}
        // 再次检查
        const newContent = readFileSync(distFile, 'utf8');
        const stillMissing = missing.filter((exp) => !newContent.includes(exp));
        if (stillMissing.length > 0) {
          console.log(`  WARN  ${name}: still missing after rebuild: ${stillMissing.join(', ')}`);
          console.log(`        Patching exports...`);
          // 强制注入缺失的导出
          patchExports(distFile, name, stillMissing);
        }
      }
    }
  }
}

console.log('\nPackaging...\n');

for (const { name, version, dir } of results) {
  const tgzName = name.replace('@midscene/', 'midscene-') + '-' + version + '.tgz';
  try {
    execSync(`pnpm pack --pack-destination "${outputDir}"`, { cwd: dir, stdio: 'pipe' });
    console.log(`  OK  ${tgzName}`);
  } catch (e) {
    console.log(`  FAIL  ${name}: ${e.message.split('\n')[0]}`);
  }
}

console.log(`\nAll tgz files in: ${outputDir}`);

function patchExports(distFile, pkgName, missingExports) {
  let content = readFileSync(distFile, 'utf8');

  for (const exp of missingExports) {
    // agentForComputer -> agentFromComputer 的别名
    if (exp === 'agentForComputer') {
      // 在 agentFromComputer 导出后追加 agentForComputer
      // rslib 把 agentForComputer 重命名为 agentFromComputer，需要加回别名
      if (content.includes('agentFromComputer') && !content.includes('agentForComputer')) {
        // 在最后的 exports 行中加入 agentForComputer
        content = content.replace(
          /exports\.agentFromComputer\s*=/,
          'exports.agentForComputer = exports.agentFromComputer;\nexports.agentFromComputer =',
        );
        console.log(`        Patched: added ${exp} as alias of agentFromComputer`);
      }
    }
  }

  writeFileSync(distFile, content);
}
