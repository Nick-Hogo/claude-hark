// 仪表板 HTTP 服务器：提供静态前端资源并暴露 /api/state 接口供前端轮询会话状态
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { createReadStream, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const port = Number(process.env.CLAUDE_HARK_DASHBOARD_PORT || 7842);
let lastValidState = { sessions: {} };

// 根据环境变量或当前工作目录解析 state.json 的绝对路径
export function resolveStatePath(env = process.env, cwd = process.cwd()) {
  if (env.CLAUDE_HARK_HOME && env.CLAUDE_HARK_HOME.trim()) {
    return path.join(env.CLAUDE_HARK_HOME, 'state.json');
  }
  const base = env.CLAUDE_HARK_CWD && env.CLAUDE_HARK_CWD.trim() ? env.CLAUDE_HARK_CWD : cwd;
  return path.join(base, '.claude-hark', 'state.json');
}

// 从磁盘读取 state.json，解析失败时回退到上次有效状态
async function readState() {
  try {
    const raw = await readFile(resolveStatePath(), 'utf8');
    if (!raw.trim()) {
      return { sessions: {} };
    }
    const parsed = JSON.parse(raw);
    lastValidState = parsed && typeof parsed === 'object' ? parsed : { sessions: {} };
    if (!lastValidState.sessions || typeof lastValidState.sessions !== 'object') {
      lastValidState.sessions = {};
    }
    return lastValidState;
  } catch {
    return lastValidState;
  }
}

// 根据文件扩展名返回对应的 MIME Content-Type 字符串
function contentType(filePath) {
  if (filePath.endsWith('.js')) return 'text/javascript; charset=utf-8';
  if (filePath.endsWith('.css')) return 'text/css; charset=utf-8';
  if (filePath.endsWith('.svg')) return 'image/svg+xml';
  if (filePath.endsWith('.json')) return 'application/json; charset=utf-8';
  return 'text/html; charset=utf-8';
}

// 处理 /api/state 请求，将当前会话状态以 JSON 格式返回给前端
async function handleApiState(response) {
  const state = await readState();
  response.writeHead(200, { 'content-type': 'application/json; charset=utf-8' });
  response.end(JSON.stringify({ ...state, statePath: resolveStatePath() }));
}

// 提供 dist/ 目录中的静态文件；路径不存在时回退到 index.html（SPA 路由支持）
function serveStatic(request, response) {
  const distRoot = path.join(__dirname, 'dist');
  const requestPath = decodeURIComponent(new URL(request.url, `http://${request.headers.host}`).pathname);
  const relativePath = requestPath === '/' ? 'index.html' : requestPath.slice(1);
  const candidate = path.normalize(path.join(distRoot, relativePath));
  const filePath = candidate.startsWith(distRoot) && existsSync(candidate) ? candidate : path.join(distRoot, 'index.html');

  if (!existsSync(filePath)) {
    response.writeHead(503, { 'content-type': 'text/plain; charset=utf-8' });
    response.end('Dashboard is not built yet. Run: cd dashboard && npm install && npm run build\n');
    return;
  }

  response.writeHead(200, { 'content-type': contentType(filePath) });
  createReadStream(filePath).pipe(response);
}

const server = createServer(async (request, response) => {
  if (request.url?.startsWith('/api/state')) {
    await handleApiState(response);
    return;
  }
  serveStatic(request, response);
});

server.listen(port, '127.0.0.1', () => {
  console.log(`Claude-Hark dashboard: http://127.0.0.1:${port}`);
  console.log(`State file: ${resolveStatePath()}`);
});
