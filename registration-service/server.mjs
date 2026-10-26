import { createServer } from 'node:http';
import { existsSync, readFileSync, mkdirSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { Registration } from './core.mjs';
import { Persona, OpenAI, Fault, insist, MODEL } from './providers.mjs';
import { localVault } from './vault.mjs';

export function createHTTP(service) {
  const limits = new Map();
  const server = createServer(async (req, res) => {
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.setHeader('Cache-Control', 'no-store'); res.setHeader('X-Content-Type-Options', 'nosniff');
    const send = (status, data) => { res.writeHead(status); res.end(JSON.stringify(data)); };
    try {
      const port = server.address().port;
      insist(req.headers.host === `127.0.0.1:${port}`, 'HOST', '拒絕非預期的服務來源。', 403);
      insist(!req.headers.origin && !req.headers['sec-fetch-site'], 'BROWSER', '此服務僅接受原生遊戲連線。', 403);
      if (req.url === '/health' && req.method === 'GET') return send(200, { service: 'yiyu-registration', version: 1, model: MODEL, personaConfigured: service.persona.configured });
      insist(req.headers['x-yiyu-client'] === 'native-v1', 'CLIENT', '請使用異域遊戲連線。', 403);
      const ip = req.socket.remoteAddress;
      const attempts = (limits.get(ip) || []).filter(t => t > Date.now() - 60000);
      insist(attempts.length < 90, 'RATE_LIMIT', '操作過於頻繁，請稍候。', 429);
      limits.set(ip, [...attempts, Date.now()]);
      const isGet = req.method === 'GET';
      insist(isGet || req.method === 'POST', 'METHOD', '不支援此操作。', 405);
      let input = {};
      if (!isGet) {
        insist(req.headers['content-type']?.split(';')[0] === 'application/json', 'CONTENT_TYPE', '請求格式錯誤。', 415);
        let size = 0; const chunks = [];
        for await (const chunk of req) { size += chunk.length; insist(size <= 8192, 'BODY_LIMIT', '請求過大。', 413); chunks.push(chunk); }
        try { input = JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch { throw new Fault('JSON', '請求格式錯誤。'); }
        insist(input && typeof input === 'object' && !Array.isArray(input), 'JSON', '請求格式錯誤。');
      }
      if (!isGet && ['/v1/register', '/v1/login'].includes(req.url)) {
        insist(input.acceptAccount === true || req.url === '/v1/login', 'ACCOUNT_CONSENT', '請先閱讀帳號與實名說明。');
        return send(200, await service.account(input.username, input.password, req.url === '/v1/register'));
      }
      const token = req.headers.authorization?.replace(/^Bearer /, '');
      const id = service.authenticate(token);
      if (isGet && req.url === '/v1/me') return send(200, { state: service.state(id) });
      insist(!isGet, 'NOT_FOUND', '沒有此操作。', 404);
      const routes = {
        '/v1/logout': () => service.logout(token),
        '/v1/identity/start': () => service.startIdentity(id, input.consent),
        '/v1/identity/check': async () => ({ state: await service.checkIdentity(id) }),
        '/v1/ai/connect': async () => ({ state: await service.connectAI(id, input) }),
        '/v1/ai/remove': () => ({ state: service.disconnectAI(id) }),
        '/v1/names/suggest': () => service.name(id, input, true),
        '/v1/names/review': () => service.name(id, input, false),
        '/v1/characters': async () => ({ state: await service.createCharacter(id, input) })
      };
      insist(routes[req.url], 'NOT_FOUND', '沒有此操作。', 404);
      send(200, await service.exclusive(id, routes[req.url]));
    } catch (e) {
      // Never return provider bodies, headers, credentials, document fields or raw exceptions.
      send(e instanceof Fault ? e.status : 500, { error: { code: e instanceof Fault ? e.code : 'INTERNAL', message: e instanceof Fault ? e.message : '服務暫時無法完成操作，請稍後再試。' } });
    }
  });
  server.requestTimeout = 45000; server.headersTimeout = 10000;
  return server;
}

export function createLocalService() {
  const directory = process.env.YIYU_DATA_DIR || join(process.env.LOCALAPPDATA || '', 'Yiyu', 'registration');
  mkdirSync(directory, { recursive: true });
  const vault = localVault(directory);
  const settingsPath = join(directory, 'persona.encrypted');
  const config = existsSync(settingsPath) ? JSON.parse(vault.open(readFileSync(settingsPath, 'utf8'), 'persona-operator')) : {};
  return new Registration({ path: join(directory, 'accounts.sqlite'), vault, persona: new Persona(config), ai: new OpenAI() });
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const service = createLocalService();
  const server = createHTTP(service);
  server.on('error', error => { console.error(error.code === 'EADDRINUSE' ? '異域帳號服務埠已被使用。' : '異域帳號服務啟動失敗。'); service.close(); process.exitCode = 1; });
  server.listen(8787, '127.0.0.1', () => console.log('異域帳號服務已啟動：127.0.0.1:8787；Persona：' + (service.persona.configured ? '已設定，待正式驗收' : '未設定')));
}
