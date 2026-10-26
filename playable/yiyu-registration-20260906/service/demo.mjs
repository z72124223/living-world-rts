// Standalone development simulation. Never import server.mjs or call localVault.
import { createServer } from 'node:http';
import { createHash, randomBytes } from 'node:crypto';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { Registration } from './core.mjs';
import { Fault, insist, MODEL } from './providers.mjs';
import { Vault } from './vault.mjs';

const SEX = 'F'; // Fictional fixture identity; never selected or inferred from a player.
const NOTICE = '開發測試：僅虛構記憶體資料；模擬查核與 AI，未連接 Persona／OpenAI，不收費。';
const SIMULATION_KEY = 'sk-demo-simulation-only-not-a-real-key';
const SESSION_MS = 12 * 3600000;
const MAX_RUNS = 32;
const digest = token => createHash('sha256').update(token).digest('hex');

// Parents already named these fictional children. Extra rows exercise pool exclusions.
const CHILDREN = [
  ['demo-public-lin', '林', '知遠', 'F', 'public', null, null, 1, 'settlement-female-01'],
  ['demo-public-ouyang', '歐陽', '映禾', 'F', 'public', null, null, 1, 'settlement-female-01'],
  ['demo-reserved', '陳', '靜禾', 'F', 'reserved', 'demo-fictional-parent', null, 1, 'arrival-female'],
  ['demo-public-reserved', '許', '映竹', 'F', 'public', 'demo-fictional-parent', null, 1, 'arrival-female'],
  ['demo-other-sex', '江', '行舟', 'M', 'public', null, null, 1, 'arrival-male'],
  ['demo-occupied', '周', '清禾', 'F', 'public', null, 'demo-fictional-occupant', 1, 'arrival-female'],
  ['demo-unreviewed', '吳', '安寧', 'F', 'public', null, null, 0, 'arrival-female'],
];

function fields(input, allowed) {
  insist(Object.keys(input).every(key => allowed.includes(key)), 'DEMO_FIELDS', '測試模式不接受此欄位，請勿輸入真實個資、金鑰或外貌／性別選項。');
}

class DemoRegistration extends Registration {
  constructor() {
    const simulation = { identity: false };
    super({
      path: ':memory:',
      vault: new Vault(randomBytes(32)),
      persona: {
        configured: false, // No real identity provider is configured.
        async start(id) {
          insist(simulation.identity, 'DEMO_IDENTITY_REQUIRED', '請明確啟用模擬身分查核。', 403);
          return { inquiryId: `demo-inquiry-${id}`, url: '' };
        },
        async check(id, inquiry) {
          insist(simulation.identity && inquiry === `demo-inquiry-${id}`, 'DEMO_IDENTITY_REQUIRED', '請先明確啟用模擬身分查核。', 403);
          return { status: 'verified', sex: SEX, fingerprintInput: `FICTIONAL-DEMO-ONLY:${id}` };
        },
      },
      ai: {
        async call(key, purpose, payload = {}) {
          insist(key === SIMULATION_KEY, 'DEMO_KEY', '測試模式只使用內部模擬標記，不接受真實金鑰。');
          if (purpose === 'suggest') return {
            surname: payload.surname || '林', given: '知遠',
            explanation: '固定虛構取名建議；未呼叫 AI，仍須另按姓名審核。',
          };
          if (purpose === 'connect') return { approved: true, reason: '已啟用模擬 AI；未連接 OpenAI，不收費。' };
          insist(purpose === 'review', 'DEMO_PURPOSE', '不支援此模擬操作。');
          // A deterministic test double, not an imitation of a real semantic judgment.
          const rejected = ['廣告', '皇帝', '客服', '管理', '白痴'].some(word => `${payload.surname}${payload.given}`.includes(word));
          return { approved: !rejected, reason: rejected
            ? '模擬審核拒絕：命中固定測試反例；未呼叫真實 AI。'
            : '模擬審核通過：僅供測試流程，未經真實 AI 判斷。' };
        },
      },
    });
    this.simulation = simulation;
    for (const child of CHILDREN) this.db.prepare('INSERT INTO children VALUES (?,?,?,?,?,?,?,?,?)').run(...child);
  }

  state(id) {
    const state = super.state(id);
    return {
      ...state, mode: 'demo', hasKey: false, identityServiceConfigured: false,
      demo: {
        notice: NOTICE, dataStorage: 'memory', fictionalAccount: true, fixedRegisteredSex: SEX,
        identitySimulated: state.identity === 'verified', aiSimulated: state.aiConnected,
        realIdentityVerified: false, realAIConnected: false, chargeable: false,
        nameReview: 'deterministic-fixture',
      },
    };
  }

  async enableIdentity(id, input) {
    fields(input, ['consent']);
    insist(input.consent === true, 'DEMO_CONSENT', '請先同意啟用虛構測試身分，不會執行真實查核。');
    this.simulation.identity = true;
    await super.startIdentity(id, true);
    return super.checkIdentity(id);
  }

  async enableAI(id, input) {
    fields(input, ['consent', 'dailyMax']);
    insist(input.consent === true, 'DEMO_CONSENT', '請先同意啟用模擬 AI；不輸入金鑰，不收費。');
    return super.connectAI(id, { key: SIMULATION_KEY, model: MODEL, dailyMax: input.dailyMax ?? 20, consent: true });
  }

  async name(id, input, suggest) {
    fields(input, suggest ? ['surname', 'consent'] : ['surname', 'given', 'consent']);
    insist(input.consent === true, 'DEMO_CONSENT', '請明確執行模擬 AI 操作；此操作不收費。');
    return super.name(id, input, suggest);
  }
}

export class DemoService {
  constructor() {
    this.runs = new Map();
    this.pending = 0;
    this.closed = false;
  }

  close() {
    this.closed = true;
    for (const run of this.runs.values()) run.service.close();
    this.runs.clear();
  }

  authenticate(token) {
    insist(typeof token === 'string' && /^[a-f0-9]{64}$/.test(token), 'AUTH_REQUIRED', '請先開始開發測試。', 401);
    const run = this.runs.get(digest(token));
    insist(run && run.expires > Date.now(), 'SESSION_EXPIRED', '測試已結束或逾時，請重開測試。', 401);
    run.service.authenticate(token);
    return run;
  }

  async withRun(token, operation) {
    const run = this.authenticate(token);
    return run.service.exclusive(run.id, () => operation(run));
  }

  async start(input, token) {
    fields(input, []);
    if (token !== undefined) return this.withRun(token, run => this.newRun(run));
    return this.newRun();
  }

  async newRun(previous) {
    insist(!this.closed, 'DEMO_CLOSED', '測試服務已關閉。', 503);
    for (const [key, run] of this.runs) {
      if (run.expires <= Date.now() && !run.service.locks.size) {
        run.service.close(); this.runs.delete(key);
      }
    }
    insist(this.runs.size + this.pending - (previous ? 1 : 0) < MAX_RUNS, 'DEMO_CAPACITY', '測試工作階段已滿，請登出舊測試或重新啟動 demo 服務。', 429);
    this.pending++;
    let service;
    try {
      service = new DemoRegistration();
      const result = await service.account(`demo_${randomBytes(8).toString('hex')}`, randomBytes(32).toString('hex'), true);
      insist(!this.closed, 'DEMO_CLOSED', '測試服務已關閉。', 503);
      const key = digest(result.token);
      const run = { key, service, id: service.authenticate(result.token), expires: Date.now() + SESSION_MS };
      this.runs.set(key, run);
      if (previous) { this.runs.delete(previous.key); previous.service.close(); }
      return result;
    } catch (error) {
      service?.close(); throw error;
    } finally { this.pending--; }
  }

  logout(run) {
    this.runs.delete(run.key);
    run.service.close();
    return { ok: true };
  }
}

export function createDemoService() { return new DemoService(); }

export function createDemoHTTP(service) {
  const limits = new Map();
  const server = createServer(async (req, res) => {
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Yiyu-Mode', 'demo');
    const send = (status, data) => { res.writeHead(status); res.end(JSON.stringify({ ...data, mode: 'demo' })); };
    try {
      const port = server.address().port;
      insist(req.headers.host === `127.0.0.1:${port}`, 'HOST', '拒絕非預期的服務來源。', 403);
      insist(req.headers.origin === undefined && req.headers['sec-fetch-site'] === undefined, 'BROWSER', '此服務僅接受原生遊戲連線。', 403);
      if (req.method === 'GET' && req.url === '/health') return send(200, {
        service: 'yiyu-registration-demo', version: 1, model: MODEL,
        personaConfigured: false, openaiConnected: false, chargeable: false, dataStorage: 'memory', notice: NOTICE,
      });
      insist(req.headers['x-yiyu-client'] === 'native-v1', 'CLIENT', '請使用異域原生開發測試連線。', 403);
      const ip = req.socket.remoteAddress;
      const attempts = (limits.get(ip) || []).filter(at => at > Date.now() - 60000);
      insist(attempts.length < 90, 'RATE_LIMIT', '操作過於頻繁，請稍候。', 429);
      limits.set(ip, [...attempts, Date.now()]);
      const isGet = req.method === 'GET';
      insist(isGet || req.method === 'POST', 'METHOD', '不支援此操作。', 405);
      let input = {};
      if (!isGet) {
        insist(req.headers['content-type']?.split(';')[0] === 'application/json', 'CONTENT_TYPE', '請求格式錯誤。', 415);
        let size = 0; const chunks = [];
        for await (const chunk of req) {
          size += chunk.length;
          insist(size <= 8192, 'BODY_LIMIT', '請求過大。', 413);
          chunks.push(chunk);
        }
        try { input = JSON.parse(Buffer.concat(chunks).toString('utf8')); }
        catch { throw new Fault('JSON', '請求格式錯誤。'); }
        insist(input && typeof input === 'object' && !Array.isArray(input), 'JSON', '請求格式錯誤。');
      }
      const authorization = req.headers.authorization;
      insist(authorization === undefined || /^Bearer [a-f0-9]{64}$/.test(authorization), 'AUTH_REQUIRED', '請使用有效的測試登入權杖。', 401);
      const token = authorization?.slice(7);
      if (!isGet && req.url === '/v1/demo/start') return send(200, await service.start(input, token));
      const result = await service.withRun(token, async run => {
        const { service: registration, id } = run;
        if (isGet && req.url === '/v1/me') return { state: registration.state(id) };
        insist(!isGet, 'NOT_FOUND', '沒有此操作。', 404);
        const routes = {
          '/v1/demo/identity': async () => ({ state: await registration.enableIdentity(id, input) }),
          '/v1/demo/ai': async () => ({ state: await registration.enableAI(id, input) }),
          '/v1/names/suggest': () => registration.name(id, input, true),
          '/v1/names/review': () => registration.name(id, input, false),
          '/v1/characters': async () => {
            fields(input, ['entry', 'surname', 'given', 'policy', 'acceptPolicy']);
            return { state: await registration.createCharacter(id, input) };
          },
          '/v1/ai/remove': () => { fields(input, []); return { state: registration.disconnectAI(id) }; },
          '/v1/logout': () => { fields(input, []); return service.logout(run); },
        };
        insist(Object.hasOwn(routes, req.url), 'NOT_FOUND', '測試模式沒有此操作；請使用模擬查核與模擬 AI。', 404);
        return routes[req.url]();
      });
      send(200, result);
    } catch (error) {
      // Never echo request values, tokens, keys, provider bodies, or raw exceptions.
      send(error instanceof Fault ? error.status : 500, { error: {
        code: error instanceof Fault ? error.code : 'INTERNAL',
        message: error instanceof Fault ? demoMessage(error) : '測試服務暫時無法完成操作，請稍後再試。',
      } });
    }
  });
  server.requestTimeout = 45000;
  server.headersTimeout = 10000;
  return server;
}

function demoMessage(error) {
  const messages = {
    IDENTITY_REQUIRED: '請先啟用模擬身分查核。',
    IDENTITY_NOT_STARTED: '請先啟用模擬身分查核。',
    AI_KEY_REQUIRED: '請先啟用模擬 AI；不需要真實金鑰。',
    AI_REQUIRED: '模擬 AI 尚未啟用或已逾時，請重新啟用。',
    DAILY_LIMIT: '已達今日模擬請求次數上限；可調整上限或重開測試，不收費。',
  };
  return messages[error.code] || error.message;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const service = createDemoService();
  const server = createDemoHTTP(service);
  const shutdown = () => { server.close(() => service.close()); server.closeIdleConnections(); };
  process.once('SIGINT', shutdown);
  process.once('SIGTERM', shutdown);
  server.on('error', error => {
    console.error(error.code === 'EADDRINUSE' ? '異域 demo 服務埠 8788 已被使用。' : '異域 demo 服務啟動失敗。');
    service.close(); process.exitCode = 1;
  });
  server.listen(8788, '127.0.0.1', () => console.log(`異域 demo 服務已啟動：127.0.0.1:8788；${NOTICE}`));
}
