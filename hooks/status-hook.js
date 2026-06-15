const fs = require('fs');
const path = require('path');
const http = require('http');

const CONFIG_FILE = path.resolve(__dirname, '..', 'config.json');
let STATUS_FILE = path.resolve(__dirname, '..', 'status', 'status.json');
let STATUS_DIR = path.dirname(STATUS_FILE);

try {
  const config = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
  if (config.statusFilePath) {
    STATUS_FILE = path.resolve(path.dirname(CONFIG_FILE), config.statusFilePath);
    STATUS_DIR = path.dirname(STATUS_FILE);
  }
} catch (_) {}

const HTTP_PORT = 9876;

// ─── Main ────────────────────────────────────────────

function main() {
  let input = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', (chunk) => { input += chunk; });
  process.stdin.on('end', () => {
    try {
      const event = JSON.parse(input);
      sendEvent(event);
    } catch (e) {
      logError('parse error: ' + e.message);
    }
  });
}

// ─── HTTP (primary: instant push) ─────────────────────

function sendEvent(event) {
  const body = JSON.stringify(event);

  const req = http.request({
    hostname: '127.0.0.1',
    port: HTTP_PORT,
    path: '/event',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(body),
    },
    timeout: 2000,
  }, (res) => {
    // HTTP succeeded – all done
    res.resume();
  });

  req.on('error', () => {
    // HTTP failed – fall back to file
    processEventFile(event);
  });

  req.on('timeout', () => {
    req.destroy();
    processEventFile(event);
  });

  req.write(body);
  req.end();
}

// ─── File fallback ────────────────────────────────────

function processEventFile(event) {
  let status = readStatus();
  switch (event.event) {
    case 'PreToolUse':
      status = applyPreToolUse(status, event);
      break;
    case 'PostToolUse':
      status = applyPostToolUse(status, event);
      break;
    case 'Stop':
      status.status = 'stopped';
      break;
  }
  status.stats.elapsedSeconds = calcElapsed(status);
  writeStatus(status);
}

function applyPreToolUse(status, event) {
  const tool = event.tool_name || '';
  status.status = 'running';

  const detail = event.tool_input?.file_path ||
      event.tool_input?.description ||
      event.tool_input?.pattern ||
      event.tool_input?.command || '';
  status.currentAction = {
    type: toolType(tool),
    detail: detail.length > 100 ? detail.substring(0, 100) + '...' : detail,
  };

  const now = new Date().toLocaleTimeString('zh-CN', { hour12: false });
  status.recentActivity.unshift({
    time: now,
    action: toolAction(tool),
    file: event.tool_input?.file_path || undefined,
    detail: event.tool_input?.description || undefined,
  });
  if (status.recentActivity.length > 50) {
    status.recentActivity = status.recentActivity.slice(0, 50);
  }

  if (tool === 'TodoWrite' && event.tool_input?.todos) {
    status.todos = event.tool_input.todos.map(t => ({
      content: t.content || '',
      status: t.status || 'pending',
    }));
  }

  return status;
}

function applyPostToolUse(status, event) {
  const tool = event.tool_name || '';
  switch (tool) {
    case 'Read': status.stats.readCount = (status.stats.readCount || 0) + 1; break;
    case 'Write':
    case 'Edit': status.stats.editCount = (status.stats.editCount || 0) + 1; break;
    case 'Bash': status.stats.commandCount = (status.stats.commandCount || 0) + 1; break;
  }

  if (event.tool_output && typeof event.tool_output === 'string' &&
      /error|fail/i.test(event.tool_output)) {
    status.stats.errorCount = (status.stats.errorCount || 0) + 1;
    status.errors.push(`${tool}: ${event.tool_output.substring(0, 100)}`);
    if (status.errors.length > 20) status.errors = status.errors.slice(-20);
  }

  if (event.thinking && typeof event.thinking === 'string') {
    status.thinking = event.thinking.substring(0, 200);
  }

  status.currentAction = null;
  return status;
}

function toolType(tool) {
  switch (tool) {
    case 'Read': return 'reading';
    case 'Write': case 'Edit': return 'editing';
    case 'Bash': return 'running';
    case 'Grep': case 'Glob': return 'searching';
    case 'Agent': return 'thinking';
    default: return 'idle';
  }
}

function toolAction(tool) {
  switch (tool) {
    case 'Read': return 'read';
    case 'Write': case 'Edit': return 'edit';
    case 'Bash': return 'command';
    case 'Grep': case 'Glob': return 'search';
    default: return 'idle';
  }
}

// ─── File helpers ─────────────────────────────────────

function readStatus() {
  try {
    if (fs.existsSync(STATUS_FILE)) {
      const raw = fs.readFileSync(STATUS_FILE, 'utf8');
      if (raw.trim()) return JSON.parse(raw);
    }
  } catch (_) {}
  return {
    sessionId: 'sess_' + Date.now(),
    startedAt: new Date().toISOString(),
    status: 'idle',
    currentAction: null,
    todos: [],
    recentActivity: [],
    thinking: null,
    stats: { readCount: 0, editCount: 0, commandCount: 0, errorCount: 0, elapsedSeconds: 0 },
    errors: [],
  };
}

function writeStatus(status) {
  try {
    if (!fs.existsSync(STATUS_DIR)) fs.mkdirSync(STATUS_DIR, { recursive: true });
    const tmp = STATUS_FILE + '.tmp';
    fs.writeFileSync(tmp, JSON.stringify(status, null, 2), 'utf8');
    fs.renameSync(tmp, STATUS_FILE);
  } catch (_) {}
}

function calcElapsed(status) {
  if (!status.startedAt) return 0;
  return Math.max(0, Math.floor((Date.now() - new Date(status.startedAt).getTime()) / 1000));
}

function logError(msg) {
  try {
    fs.appendFileSync(path.join(STATUS_DIR, 'error.log'),
      `[${new Date().toISOString()}] ${msg}\n`);
  } catch (_) {}
}

main();
