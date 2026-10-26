import test from 'node:test';
import assert from 'node:assert/strict';
import { request as httpRequest } from 'node:http';
import { once } from 'node:events';
import { mkdtemp, writeFile, readFile, readdir, rm } from 'node:fs/promises';
import { join, resolve, dirname, basename } from 'node:path';
import { tmpdir } from 'node:os';
import { createDemoService, createDemoHTTP } from '../demo.mjs';
import { POLICY, OpenAI, Persona } from '../providers.mjs';

// Every client request uses node:http. This lets the provider-isolation test
// trap global fetch without trapping its own HTTP traffic.
async function fixture(t) {
  const service = createDemoService();
  const server = createDemoHTTP(service);
  t.after(async () => {
    if (server.listening) await new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
    service.close();
  });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const port = server.address().port;
  assert.notEqual(port, 8788);

  async function request(path, { method = 'POST', token, body = {}, raw, headers = {} } = {}) {
    const payload = method === 'GET' ? undefined : raw ?? JSON.stringify(body);
    const outgoing = {
      Host: `127.0.0.1:${port}`,
      'X-Yiyu-Client': 'native-v1',
      ...(payload === undefined ? {} : { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload) }),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...headers
    };
    for (const key of Object.keys(outgoing)) if (outgoing[key] === undefined) delete outgoing[key];
    const response = await new Promise((resolve, reject) => {
      const req = httpRequest({ hostname: '127.0.0.1', port, path, method, headers: outgoing, agent: false }, res => {
        const chunks = [];
        res.on('data', chunk => chunks.push(chunk));
        res.on('error', reject);
        res.on('end', () => {
          try { resolve({ status: res.statusCode, headers: res.headers, body: JSON.parse(Buffer.concat(chunks).toString('utf8')) }); }
          catch (error) { reject(error); }
        });
      });
      req.on('error', reject);
      req.setTimeout(5000, () => req.destroy(new Error('Demo HTTP test timed out')));
      req.end(payload);
    });
    assert.equal(response.body.mode, 'demo', `${path} must identify all replies as demo`);
    assert.equal(response.headers['cache-control'], 'no-store');
    if (response.body.state) {
      assert.equal(response.body.state.mode, 'demo');
      assert.equal(response.body.state.hasKey, false);
      assert.equal(response.body.state.identityServiceConfigured, false);
      assert.equal(response.body.state.demo.dataStorage, 'memory');
      assert.equal(response.body.state.demo.realIdentityVerified, false);
      assert.equal(response.body.state.demo.realAIConnected, false);
      assert.equal(response.body.state.demo.chargeable, false);
    }
    return response;
  }

  async function start() {
    const result = await request('/v1/demo/start');
    assert.equal(result.status, 200);
    assert.match(result.body.token, /^[a-f0-9]{64}$/);
    return result.body;
  }
  async function ready() {
    const run = await start();
    assert.equal((await request('/v1/demo/identity', { token: run.token, body: { consent: true } })).status, 200);
    assert.equal((await request('/v1/demo/ai', { token: run.token, body: { consent: true, dailyMax: 20 } })).status, 200);
    return run.token;
  }
  return { service, server, port, request, start, ready };
}

function rejected(response, code) {
  assert.ok(response.status >= 400 && response.status < 500, `expected client rejection, got ${response.status}`);
  assert.equal(typeof response.body.error?.message, 'string');
  assert.equal(typeof response.body.error?.code, 'string');
  if (code) assert.equal(response.body.error.code, code);
}
const arrival = { entry: 'arrival', surname: '林', given: '知遠', policy: POLICY, acceptPolicy: true };
const reincarnation = { entry: 'reincarnation', policy: POLICY, acceptPolicy: true };
const review = { surname: '林', given: '知遠', consent: true };

test('demo health and new run expose explicit mode with no identity, AI or stored key', async t => {
  const f = await fixture(t);
  const health = await f.request('/health', { method: 'GET', headers: { 'X-Yiyu-Client': undefined } });
  assert.equal(health.status, 200);
  assert.equal(health.body.personaConfigured, false);
  assert.equal(health.body.openaiConnected, false);
  assert.equal(health.body.chargeable, false);
  assert.equal(health.body.dataStorage, 'memory');
  const { state, token } = await f.start();
  assert.equal(state.identity, 'unverified');
  assert.equal(state.sex, null);
  assert.equal(state.aiConnected, false);
  assert.equal(state.hasKey, false);
  assert.equal(state.availableChildren, 0);
  assert.equal(state.character, null);
  assert.equal(state.review, null);
  assert.equal(state.policy, POLICY);
  assert.equal(typeof state.account, 'string');
  const me = await f.request('/v1/me', { method: 'GET', token });
  assert.equal(me.status, 200);
  assert.deepEqual(me.body.state, state);
});

test('identity and mock AI require separate explicit consent and preserve the fixed fictional sex', async t => {
  const f = await fixture(t);
  const { token } = await f.start();
  rejected(await f.request('/v1/demo/ai', { token, body: { consent: true, dailyMax: 20 } }), 'IDENTITY_REQUIRED');
  for (const consent of [undefined, false, 'true', 1]) {
    rejected(await f.request('/v1/demo/identity', { token, body: { consent } }));
  }
  const identity = await f.request('/v1/demo/identity', { token, body: { consent: true } });
  assert.equal(identity.status, 200);
  assert.equal(identity.body.state.identity, 'verified');
  assert.equal(identity.body.state.sex, 'F');
  assert.equal(identity.body.state.availableChildren, 2);
  assert.equal(identity.body.state.aiConnected, false);
  for (const consent of [undefined, false, 'true']) {
    rejected(await f.request('/v1/demo/ai', { token, body: { consent, dailyMax: 20 } }));
  }
  const connected = await f.request('/v1/demo/ai', { token, body: { consent: true, dailyMax: 20 } });
  assert.equal(connected.status, 200);
  assert.equal(connected.body.state.aiConnected, true);
  assert.equal(connected.body.state.hasKey, false);
  assert.equal(connected.body.state.sex, 'F');
});

test('name suggestions retain compound surnames and still require a separate exact-name review', async t => {
  const f = await fixture(t);
  const token = await f.ready();
  const suggestion = await f.request('/v1/names/suggest', { token, body: { surname: '', consent: true } });
  assert.equal(suggestion.status, 200);
  assert.equal(suggestion.body.suggestion.surname, '林');
  assert.equal(suggestion.body.suggestion.given, '知遠');
  assert.equal(suggestion.body.state.review, null);
  rejected(await f.request('/v1/characters', { token, body: arrival }), 'NAME_REVIEW_REQUIRED');
  const compound = await f.request('/v1/names/suggest', { token, body: { surname: '歐陽', consent: true } });
  assert.equal(compound.status, 200);
  assert.equal(compound.body.suggestion.surname, '歐陽');
  rejected(await f.request('/v1/names/review', { token, body: { ...review, consent: false } }));
  assert.equal((await f.request('/v1/names/review', { token, body: review })).body.approved, true);
  rejected(await f.request('/v1/characters', { token, body: { ...arrival, given: '映禾' } }), 'NAME_REVIEW_REQUIRED');
  const created = await f.request('/v1/characters', { token, body: arrival });
  assert.equal(created.status, 200);
  assert.equal(created.body.state.character.surname, '林');
  assert.equal(created.body.state.character.given, '知遠');
  rejected(await f.request('/v1/characters', { token, body: arrival }), 'CHARACTER_EXISTS');
});

test('mock review rejects the documented bad example and core rejects invalid name format and policy', async t => {
  const f = await fixture(t);
  const token = await f.ready();
  const bad = await f.request('/v1/names/review', { token, body: { surname: '王', given: '廣告', consent: true } });
  assert.equal(bad.status, 200);
  assert.equal(bad.body.approved, false);
  assert.equal(bad.body.state.review.approved, false);
  rejected(await f.request('/v1/characters', { token, body: { ...arrival, surname: '王', given: '廣告' } }), 'NAME_REVIEW_REQUIRED');
  for (const [surname, given] of [['Lin', '遠'], ['林', ''], ['林', '知遠人']]) {
    rejected(await f.request('/v1/names/review', { token, body: { surname, given, consent: true } }), 'NAME_FORMAT');
  }
  assert.equal((await f.request('/v1/names/review', { token, body: review })).status, 200);
  rejected(await f.request('/v1/characters', { token, body: { ...arrival, policy: 'untrusted-policy' } }), 'POLICY_REQUIRED');
  rejected(await f.request('/v1/characters', { token, body: { ...arrival, acceptPolicy: false } }), 'POLICY_REQUIRED');
  assert.equal((await f.request('/v1/me', { method: 'GET', token })).body.state.character, null);
});

test('first arrival cannot receive client-selected sex, appearance, inventory or child', async t => {
  const f = await fixture(t);
  const token = await f.ready();
  assert.equal((await f.request('/v1/names/review', { token, body: review })).status, 200);
  const forged = await f.request('/v1/characters', { token, body: {
    ...arrival, sex: 'M', appearance: 'custom-face', items: ['weapon', 'food'], childId: 'reserved-child'
  } });
  rejected(forged, 'DEMO_FIELDS');
  assert.equal((await f.request('/v1/me', { method: 'GET', token })).body.state.character, null);
  const created = await f.request('/v1/characters', { token, body: arrival });
  assert.equal(created.status, 200);
  const character = created.body.state.character;
  assert.equal(character.sex, 'F');
  assert.equal(character.appearance, 'arrival-female');
  assert.equal(character.entry, 'arrival');
  assert.ok(character.items === undefined || (Array.isArray(character.items) && character.items.length === 0));
  assert.notEqual(character.childId, 'reserved-child');
});

test('random reincarnation uses only eligible fictional daughters and preserves parents names', async t => {
  const f = await fixture(t);
  const allowed = new Set(['林知遠', '歐陽映禾']);
  for (let run = 0; run < 6; run++) {
    const token = await f.ready();
    assert.equal((await f.request('/v1/me', { method: 'GET', token })).body.state.availableChildren, 2);
    const forged = await f.request('/v1/characters', { token, body: {
      ...reincarnation, surname: '王', given: '改名', childId: 'reserved-child', sex: 'M', appearance: 'custom-face'
    } });
    rejected(forged, 'DEMO_FIELDS');
    const created = await f.request('/v1/characters', { token, body: { ...reincarnation, surname: '王', given: '改名' } });
    assert.equal(created.status, 200);
    const { state } = created.body;
    assert.ok(allowed.has(state.character.surname + state.character.given));
    assert.equal(state.character.sex, 'F');
    assert.equal(state.character.appearance, 'arrival-female');
    assert.equal(state.character.entry, 'reincarnation');
    assert.equal(state.availableChildren, 1);
    assert.equal(state.review, null);
  }
});

test('restart resets only its own memory run and revokes the old bearer token', async t => {
  const f = await fixture(t);
  const tokenA = await f.ready();
  const tokenB = await f.ready();
  assert.equal((await f.request('/v1/characters', { token: tokenA, body: reincarnation })).status, 200);
  assert.equal((await f.request('/v1/characters', { token: tokenB, body: reincarnation })).status, 200);
  const beforeB = (await f.request('/v1/me', { method: 'GET', token: tokenB })).body.state;
  const restarted = await f.request('/v1/demo/start', { token: tokenA });
  assert.equal(restarted.status, 200);
  assert.notEqual(restarted.body.token, tokenA);
  assert.equal(restarted.body.state.identity, 'unverified');
  assert.equal(restarted.body.state.sex, null);
  assert.equal(restarted.body.state.aiConnected, false);
  assert.equal(restarted.body.state.hasKey, false);
  assert.equal(restarted.body.state.character, null);
  assert.equal(restarted.body.state.callsToday, 0);
  rejected(await f.request('/v1/me', { method: 'GET', token: tokenA }));
  rejected(await f.request('/v1/demo/start', { token: tokenA }));
  const afterB = (await f.request('/v1/me', { method: 'GET', token: tokenB })).body.state;
  assert.deepEqual(afterB, beforeB);
  const reverified = await f.request('/v1/demo/identity', { token: restarted.body.token, body: { consent: true } });
  assert.equal(reverified.body.state.availableChildren, 2);
});

test('ineligible child fixtures cannot satisfy reincarnation when both eligible children are occupied', async t => {
  const f = await fixture(t);
  const token = await f.ready();
  const { service } = f.service.authenticate(token);
  // Occupy the two eligible fixtures; retain all five negative fixtures.
  service.db.prepare("UPDATE children SET occupied_by='test-occupied-' || id WHERE sex='F' AND access='public' AND reserved_for IS NULL AND occupied_by IS NULL AND name_approved=1").run();
  const me = await f.request('/v1/me', { method: 'GET', token });
  assert.equal(me.body.state.availableChildren, 0);
  rejected(await f.request('/v1/characters', { token, body: reincarnation }), 'NO_CHILD');
  assert.equal((await f.request('/v1/me', { method: 'GET', token })).body.state.character, null);
});

test('expired exact-name reviews and expired mock AI cannot authorize character creation', async t => {
  const f = await fixture(t);
  const token = await f.ready();
  assert.equal((await f.request('/v1/names/review', { token, body: review })).status, 200);
  const { service, id } = f.service.authenticate(token);
  const expired = Date.now() - 16 * 60 * 1000;
  service.db.prepare('UPDATE name_reviews SET checked=? WHERE account=?').run(expired, id);
  rejected(await f.request('/v1/characters', { token, body: arrival }), 'NAME_REVIEW_REQUIRED');
  assert.equal((await f.request('/v1/names/review', { token, body: review })).status, 200);
  service.db.prepare('UPDATE accounts SET ai_checked=? WHERE id=?').run(expired, id);
  const me = await f.request('/v1/me', { method: 'GET', token });
  assert.equal(me.body.state.aiConnected, false);
  rejected(await f.request('/v1/characters', { token, body: arrival }), 'AI_REQUIRED');
  assert.equal((await f.request('/v1/me', { method: 'GET', token })).body.state.character, null);
});

test('AI removal invalidates review and creation; logout invalidates authentication', async t => {
  const f = await fixture(t);
  const token = await f.ready();
  assert.equal((await f.request('/v1/names/review', { token, body: review })).status, 200);
  const removed = await f.request('/v1/ai/remove', { token });
  assert.equal(removed.status, 200);
  assert.equal(removed.body.state.aiConnected, false);
  assert.equal(removed.body.state.hasKey, false);
  assert.equal(removed.body.state.review, null);
  rejected(await f.request('/v1/characters', { token, body: arrival }), 'AI_REQUIRED');
  const logout = await f.request('/v1/logout', { token });
  assert.equal(logout.status, 200);
  rejected(await f.request('/v1/me', { method: 'GET', token }));
  rejected(await f.request('/v1/demo/start', { token }));
});

test('demo denies real registration, identity, key and moderation endpoints', async t => {
  const f = await fixture(t);
  const token = await f.ready();
  for (const path of ['/v1/register', '/v1/login', '/v1/identity/start', '/v1/identity/check', '/v1/ai/connect', '/v1/admin/freeze']) {
    const result = await f.request(path, { token });
    assert.equal(result.status, 404, `${path} must not expose the production route`);
  }
  const fakeKey = 'sk-TEST_ONLY_NOT_A_REAL_KEY_123456789';
  const keyAttempt = await f.request('/v1/demo/ai', { token, body: { consent: true, dailyMax: 20, key: fakeKey } });
  rejected(keyAttempt);
  assert.ok(!JSON.stringify(keyAttempt.body).includes(fakeKey));
  assert.equal((await f.request('/v1/me', { method: 'GET', token })).body.state.hasKey, false);
});

test('HTTP rejects wrong Host, browser headers and missing native client marker', async t => {
  const f = await fixture(t);
  for (const Host of [`localhost:${f.port}`, '127.0.0.1:8788', 'attacker.example']) {
    rejected(await f.request('/v1/demo/start', { headers: { Host } }));
  }
  for (const headers of [{ Origin: `http://127.0.0.1:${f.port}` }, { Origin: 'null' }, { 'Sec-Fetch-Site': 'same-origin' }, { 'Sec-Fetch-Site': 'none' }]) {
    rejected(await f.request('/v1/demo/start', { headers }));
  }
  rejected(await f.request('/v1/demo/start', { headers: { 'X-Yiyu-Client': undefined } }));
  rejected(await f.request('/v1/demo/start', { headers: { 'X-Yiyu-Client': 'browser' } }));
  assert.equal((await f.start()).state.identity, 'unverified');
});

test('HTTP strictly validates bearer authentication, method, media type and bounded JSON objects', async t => {
  const f = await fixture(t);
  const { token } = await f.start();
  for (const Authorization of [undefined, token, `bearer ${token}`, `Bearer  ${token}`, `Basic ${token}`, `Bearer ${token} extra`, `Bearer ${'a'.repeat(64)}`]) {
    rejected(await f.request('/v1/me', { method: 'GET', headers: { Authorization } }));
  }
  rejected(await f.request('/v1/demo/start', { headers: { Authorization: 'Bearer invalid' } }));
  rejected(await f.request('/v1/demo/start', { method: 'PUT' }));
  rejected(await f.request('/v1/demo/start', { headers: { 'Content-Type': 'text/plain' } }));
  for (const raw of ['{', 'null', '[]', '"string"', 'true']) {
    rejected(await f.request('/v1/demo/start', { raw }));
  }
  const oversized = await f.request('/v1/demo/start', { body: { padding: 'x'.repeat(9000) } });
  assert.equal(oversized.status, 413);
  assert.equal((await f.request('/v1/me', { method: 'GET', token })).status, 200);
});

test('demo keeps core simulated request limits and never stores a real key', async t => {
  const f = await fixture(t);
  const { token } = await f.start();
  assert.equal((await f.request('/v1/demo/identity', { token, body: { consent: true } })).status, 200);
  for (const dailyMax of [0, 101, 1.5, '20']) {
    rejected(await f.request('/v1/demo/ai', { token, body: { consent: true, dailyMax } }), 'DAILY_MAX');
  }
  const connected = await f.request('/v1/demo/ai', { token, body: { consent: true, dailyMax: 1 } });
  assert.equal(connected.status, 200);
  assert.equal(connected.body.state.callsToday, 1);
  assert.equal(connected.body.state.hasKey, false);
  rejected(await f.request('/v1/names/suggest', { token, body: { surname: '', consent: true } }), 'DAILY_LIMIT');
});

test('complete demo flow never calls real providers and leaves production-directory sentinels unchanged', async t => {
  let externalCalls = 0;
  const forbidden = () => { externalCalls++; throw new Error('Real provider call is forbidden in demo tests'); };
  t.mock.method(globalThis, 'fetch', forbidden);
  t.mock.method(OpenAI.prototype, 'call', forbidden);
  t.mock.method(Persona.prototype, 'start', forbidden);
  t.mock.method(Persona.prototype, 'check', forbidden);
  const directory = await mkdtemp(join(tmpdir(), 'yiyu-demo-isolation-'));
  const previous = process.env.YIYU_DATA_DIR;
  process.env.YIYU_DATA_DIR = directory;
  t.after(async () => {
    if (previous === undefined) delete process.env.YIYU_DATA_DIR;
    else process.env.YIYU_DATA_DIR = previous;
    const cleanupTarget = resolve(directory);
    assert.equal(dirname(cleanupTarget), resolve(tmpdir()));
    assert.ok(basename(cleanupTarget).startsWith('yiyu-demo-isolation-'));
    await rm(cleanupTarget, { recursive: true, force: true });
  });
  const sentinels = { 'accounts.sqlite': 'DEMO_TEST_INVALID_SQLITE_SENTINEL', 'persona.encrypted': 'DEMO_TEST_NOT_AN_ENCRYPTED_KEY', 'master.dpapi': 'DEMO_TEST_NOT_A_MASTER_KEY' };
  for (const [name, value] of Object.entries(sentinels)) await writeFile(join(directory, name), value);
  const f = await fixture(t);
  const token = await f.ready();
  assert.equal((await f.request('/v1/names/suggest', { token, body: { surname: '', consent: true } })).status, 200);
  assert.equal((await f.request('/v1/names/review', { token, body: review })).status, 200);
  assert.equal((await f.request('/v1/characters', { token, body: arrival })).status, 200);
  assert.equal((await f.request('/v1/demo/start', { token })).status, 200);
  assert.equal(externalCalls, 0);
  assert.deepEqual((await readdir(directory)).sort(), Object.keys(sentinels).sort());
  for (const [name, value] of Object.entries(sentinels)) assert.equal(await readFile(join(directory, name), 'utf8'), value);
});
