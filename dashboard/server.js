import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { createReadStream, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const port = Number(process.env.CLAUDE_HARK_DASHBOARD_PORT || 7842);
let lastValidState = { sessions: {} };

export function resolveStatePath(env = process.env, cwd = process.cwd()) {
  if (env.CLAUDE_HARK_HOME && env.CLAUDE_HARK_HOME.trim()) {
    return path.join(env.CLAUDE_HARK_HOME, 'state.json');
  }
  const base = env.CLAUDE_HARK_CWD && env.CLAUDE_HARK_CWD.trim() ? env.CLAUDE_HARK_CWD : cwd;
  return path.join(base, '.claude-hark', 'state.json');
}

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

function contentType(filePath) {
  if (filePath.endsWith('.js')) return 'text/javascript; charset=utf-8';
  if (filePath.endsWith('.css')) return 'text/css; charset=utf-8';
  if (filePath.endsWith('.svg')) return 'image/svg+xml';
  if (filePath.endsWith('.json')) return 'application/json; charset=utf-8';
  return 'text/html; charset=utf-8';
}

async function handleApiState(response) {
  const state = await readState();
  response.writeHead(200, { 'content-type': 'application/json; charset=utf-8' });
  response.end(JSON.stringify({ ...state, statePath: resolveStatePath() }));
}

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
