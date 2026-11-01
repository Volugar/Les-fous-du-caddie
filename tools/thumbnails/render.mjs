import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
import { spawn } from 'child_process';
const server = spawn('python3', ['-m', 'http.server', '8765'], { cwd: '/tmp/thumbs', stdio: 'ignore' });
await new Promise(r => setTimeout(r, 800));
const jobs = (process.argv[2] || 'office,warehouse,hq,lobby,icon').split(',');
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
for (const name of jobs) {
  const [w, h] = name === 'icon' ? [512, 512] : [1920, 1080];
  const page = await browser.newPage({ viewport: { width: w, height: h } });
  page.on('console', m => { if (m.type() === 'error') console.log('console:', m.text()); });
  page.on('pageerror', e => console.log('pageerror:', e.message));
  const t0 = Date.now();
  await page.goto(`http://localhost:8765/page.html?scene=${name}&w=${w}&h=${h}`);
  await page.waitForFunction(() => document.title === 'done' || document.title.startsWith('error'), null, { timeout: 600000 });
  console.log(name, await page.title(), (Date.now() - t0) / 1000 + 's');
  await page.screenshot({ path: `/tmp/thumbs/out_${name}.png` });
  await page.close();
}
await browser.close();
server.kill();
