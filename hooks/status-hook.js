const fs = require('fs');
const path = require('path');

const CONFIG_FILE = path.resolve(__dirname, '..', 'config.json');
let STATUS_FILE = 'D:/Tools/ClaudeMonitor/status/status.json';
let STATUS_DIR = path.dirname(STATUS_FILE);

try {
  const config = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
  if (config.statusFilePath) {
    STATUS_FILE = path.resolve(path.dirname(CONFIG_FILE), config.statusFilePath);
    STATUS_DIR = path.dirname(STATUS_FILE);
  }
} catch (_) {
  // fall back to default path above
}

function main() {
  let input = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', (chunk) => { input += chunk; });
  process.stdin.on('end', () => {
    try {
      const event = JSON.parse(input);
      processEvent(event);
    } catch (e) {
      logError('parse error: ' + e.message);
    }
  });
}

function processEvent(event) {
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

  switch (tool) {
    case 'Read':
      status.currentAction = { type: 'reading', detail: event.tool_input?.file_path || '' };
      break;
    case 'Write':
    case 'Edit':
      status.currentAction = { type: 'editing', detail: event.tool_input?.file_path || '' };
      break;
    case 'Bash':
      status.currentAction = { type: 'running', detail: (event.tool_input?.description || event.tool_input?.command || '').substring(0, 100) };
      break;
    case 'Grep':
    case 'Glob':
      status.currentAction = { type: 'searching', detail: event.tool_input?.pattern || '' };
      break;
    case 'TodoWrite':
      if (event.tool_input?.todos) {
        status.todos = event.tool_input.todos.map(t => ({
          content: t.content || '',
          status: t.status || 'pending'
        }));
      }
      status.currentAction = { type: 'editing', detail: '更新任务列表' };
      break;
    case 'Agent':
      status.currentAction = { type: 'thinking', detail: event.tool_input?.description || '启动子代理' };
      break;
    default:
      status.currentAction = { type: 'idle', detail: tool };
  }

  const now = new Date().toLocaleTimeString('zh-CN', { hour12: false });
  const actItem = {
    time: now,
    action: toolToAction(tool),
    file: event.tool_input?.file_path || undefined,
    detail: event.tool_input?.description || undefined,
  };
  status.recentActivity.unshift(actItem);
  if (status.recentActivity.length > 50) {
    status.recentActivity = status.recentActivity.slice(0, 50);
  }

  return status;
}

function applyPostToolUse(status, event) {
  const tool = event.tool_name || '';

  switch (tool) {
    case 'Read':
      status.stats.readCount = (status.stats.readCount || 0) + 1;
      break;
    case 'Write':
    case 'Edit':
      status.stats.editCount = (status.stats.editCount || 0) + 1;
      break;
    case 'Bash':
      status.stats.commandCount = (status.stats.commandCount || 0) + 1;
      break;
  }

  if (event.tool_output && typeof event.tool_output === 'string' && event.tool_output.toLowerCase().includes('error')) {
    status.stats.errorCount = (status.stats.errorCount || 0) + 1;
    status.errors.push(`${tool}: ${event.tool_output.substring(0, 100)}`);
    if (status.errors.length > 20) {
      status.errors = status.errors.slice(-20);
    }
  }

  if (event.thinking && typeof event.thinking === 'string') {
    status.thinking = event.thinking.substring(0, 200);
  }

  status.currentAction = null;
  return status;
}

function toolToAction(tool) {
  switch (tool) {
    case 'Read': return 'read';
    case 'Write':
    case 'Edit': return 'edit';
    case 'Bash': return 'command';
    case 'Grep':
    case 'Glob': return 'search';
    default: return 'idle';
  }
}

function readStatus() {
  try {
    if (fs.existsSync(STATUS_FILE)) {
      const raw = fs.readFileSync(STATUS_FILE, 'utf8');
      if (raw.trim()) {
        return JSON.parse(raw);
      }
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
    if (!fs.existsSync(STATUS_DIR)) {
      fs.mkdirSync(STATUS_DIR, { recursive: true });
    }
    const tmp = STATUS_FILE + '.tmp';
    fs.writeFileSync(tmp, JSON.stringify(status, null, 2), 'utf8');
    fs.renameSync(tmp, STATUS_FILE);
  } catch (_) {}
}

function calcElapsed(status) {
  if (!status.startedAt) return 0;
  const start = new Date(status.startedAt).getTime();
  const now = Date.now();
  return Math.max(0, Math.floor((now - start) / 1000));
}

function logError(msg) {
  try {
    const logFile = path.join(STATUS_DIR, 'error.log');
    fs.appendFileSync(logFile, `[${new Date().toISOString()}] ${msg}\n`);
  } catch (_) {}
}

main();
