import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { Registration } from '../core.mjs';
import { Vault } from '../vault.mjs';
import { Persona, OpenAI, Fault, MODEL, POLICY } from '../providers.mjs';
import { createHTTP } from '../server.mjs';
import { request as nativeRequest } from 'node:http';

const PASSWORD = 'test-only-password-456';
const KEY = 'sk-test-only-not-a-real-api-key';
function fixture(t, overrides = {}) {
  const persona = { configured: true,
    async start(id) { return { inquiryId: 'inq_' + id, url: '' }; },
    async check(id) { return { status: 'verified', sex: 'M', fingerprintInput: 'TEST-DOCUMENT:' + id }; }, ...overrides };
  const ai = { calls: [], async call(key, task) { this.calls.push({ key, task }); return task === 'suggest' ? { surname: '林', given: '知遠', explanation: '測試' } : { approved: true, reason: '測試通過' }; } };
  const service = new Registration({ path: ':memory:', vault: new Vault(randomBytes(32)), persona, ai });
  t.after(() => service.close());
  return { service, persona, ai };
}
async function account(service, username = 'player_one') {
  const result = await service.account(username, PASSWORD, true);
  return { id: service.authenticate(result.token), token: result.token };
}
async function ready(service, username = 'player_one') {
  const a = await account(service, username);
  await service.startIdentity(a.id, true); await service.checkIdentity(a.id);
  await service.connectAI(a.id, { key: KEY, dailyMax: 20, consent: true });
  await service.name(a.id, { surname: '林', given: '知遠', consent: true }, false);
  return a;
}
const creation = (more = {}) => ({ entry: 'arrival', surname: '林', given: '知遠', policy: POLICY, acceptPolicy: true, ...more });

test('registration, password hashing, login, session expiry and logout', async t => {
  const { service } = fixture(t); const a = await account(service);
  assert.notEqual(service.get(a.id).password, PASSWORD);
  assert.equal(service.state(a.id).identity, 'unverified');
  await assert.rejects(service.account('player_one', 'wrong-password-value', false), { code: 'LOGIN_FAILED' });
  const again = await service.account('player_one', PASSWORD, false);
  assert.equal(service.authenticate(again.token), a.id);
  service.logout(again.token); assert.throws(() => service.authenticate(again.token), { code: 'SESSION_EXPIRED' });
  service.db.prepare('UPDATE sessions SET expires=0').run();
  assert.throws(() => service.authenticate(a.token), { code: 'SESSION_EXPIRED' });
});
test('unconfigured Persona never verifies; forged flags cannot create or bill AI', async t => {
  const { service, ai } = fixture(t); service.persona = new Persona();
  const a = await account(service);
  await assert.rejects(service.startIdentity(a.id, true), { code: 'IDENTITY_PROVIDER_NOT_CONFIGURED' });
  await assert.rejects(service.createCharacter(a.id, creation({ identity: 'verified', aiConnected: true, sex: 'F' })), { code: 'IDENTITY_NOT_STARTED' });
  await assert.rejects(service.connectAI(a.id, { key: KEY, dailyMax: 20, consent: true }), { code: 'IDENTITY_REQUIRED' });
  assert.equal(ai.calls.length, 0); assert.equal(service.state(a.id).identity, 'unverified');
});
test('duplicate identity and identity blacklist prevent binding', async t => {
  const { service, persona } = fixture(t, { async check() { return { status: 'verified', sex: 'M', fingerprintInput: 'TEST-SAME-ID' }; } });
  const a = await account(service); await service.startIdentity(a.id, true); await service.checkIdentity(a.id);
  const b = await account(service, 'player_two'); await service.startIdentity(b.id, true);
  await assert.rejects(service.checkIdentity(b.id), { code: 'IDENTITY_DUPLICATE' });
  service.db.prepare('INSERT INTO identity_blocks VALUES (?,?,?)').run(service.get(a.id).fingerprint, 'test manual evidence', Date.now());
  assert.throws(() => service.authenticate(a.token), { code: 'IDENTITY_BLOCKED' });
  await assert.rejects(service.checkIdentity(b.id), { code: 'IDENTITY_BLOCKED' });
  assert.equal(service.get(b.id).identity_status, 'blocked');
});
test('fees require consent, request limits are enforced and vault binds owner', async t => {
  const { service, ai } = fixture(t); const a = await account(service);
  await service.startIdentity(a.id, true); await service.checkIdentity(a.id);
  await assert.rejects(service.connectAI(a.id, { key: KEY, dailyMax: 1, consent: false }), { code: 'FEE_CONSENT' });
  assert.equal(ai.calls.length, 0);
  await service.connectAI(a.id, { key: KEY, dailyMax: 1, consent: true });
  assert.equal(service.state(a.id).callsToday, 1);
  assert.ok(!JSON.stringify(service.get(a.id)).includes(KEY));
  assert.equal(service.vault.open(service.get(a.id).ai_key, a.id), KEY);
  assert.throws(() => service.vault.open(service.get(a.id).ai_key, 'another-account'));
  await assert.rejects(service.name(a.id, { surname: '林', given: '知遠', consent: true }, false), { code: 'DAILY_LIMIT' });
  service.disconnectAI(a.id); assert.equal(service.get(a.id).ai_key, null);
});
test('exact name review, policy, TTL, immutable sex and duplicate character constraints', async t => {
  const { service } = fixture(t); const a = await ready(service);
  await assert.rejects(service.createCharacter(a.id, creation({ given: '無敵' })), { code: 'NAME_REVIEW_REQUIRED' });
  await assert.rejects(service.createCharacter(a.id, creation({ policy: 'old' })), { code: 'POLICY_REQUIRED' });
  const result = await service.createCharacter(a.id, creation({ sex: 'F', appearance: 'custom-face', items: ['sword'] }));
  assert.equal(result.character.sex, 'M'); assert.equal(result.character.appearance, 'arrival-male');
  assert.equal(result.character.given, '知遠'); assert.equal(result.character.items, undefined);
  await assert.rejects(service.createCharacter(a.id, creation()), { code: 'CHARACTER_EXISTS' });
  assert.equal(service.db.prepare('SELECT COUNT(*) AS n FROM characters').get().n, 1);
});
test('expired reviews and rejected AI results cannot grant creation', async t => {
  const { service, ai } = fixture(t); const a = await ready(service);
  service.db.prepare('UPDATE name_reviews SET checked=0').run();
  await assert.rejects(service.createCharacter(a.id, creation()), { code: 'NAME_REVIEW_REQUIRED' });
  ai.call = async () => ({ approved: false, reason: '測試拒絕網名' });
  await service.name(a.id, { surname: '林', given: '知遠', consent: true }, false);
  await assert.rejects(service.createCharacter(a.id, creation()), { code: 'NAME_REVIEW_REQUIRED' });
  assert.equal(service.get(a.id).state, 'active');
});
test('provider revocation prevents creation despite earlier verified status', async t => {
  const { service, persona } = fixture(t); const a = await ready(service);
  persona.check = async () => ({ status: 'declined' });
  await assert.rejects(service.createCharacter(a.id, creation()), { code: 'IDENTITY_REQUIRED' });
  assert.equal(service.state(a.id).identity, 'declined');
});
test('same-sex eligible public child is atomically claimed, reserved and occupied excluded', async t => {
  const { service } = fixture(t); const a = await ready(service); const b = await ready(service, 'player_two');
  const insert = service.db.prepare('INSERT INTO children VALUES (?,?,?,?,?,?,?,?,?)');
  insert.run('child-public', '歐陽', '若川', 'M', 'public', null, null, 1, 'child-male-01');
  insert.run('child-female', '王', '如月', 'F', 'public', null, null, 1, 'child-female-01');
  insert.run('child-reserved', '林', '明', 'M', 'reserved', a.id, null, 1, 'child-male-01');
  insert.run('child-occupied', '劉', '明', 'M', 'public', null, 'fixture-occupied', 1, 'child-male-01');
  assert.equal(service.state(a.id).availableChildren, 1);
  const results = await Promise.allSettled([service.createCharacter(a.id, creation({ entry: 'reincarnation', child: 'child-female' })), service.createCharacter(b.id, creation({ entry: 'reincarnation' }))]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal(results.find(r => r.status === 'rejected').reason.code, 'NO_CHILD');
  const child = service.db.prepare("SELECT * FROM children WHERE id='child-public'").get();
  const character = service.state(child.occupied_by).character;
  assert.equal(character.surname, '歐陽'); assert.equal(character.given, '若川'); assert.equal(character.sex, 'M');
  assert.equal(service.db.prepare("SELECT occupied_by FROM children WHERE id='child-reserved'").get().occupied_by, null);
});
test('HTTP host, browser, auth, forged status and JSON gates', async t => {
  const { service } = fixture(t); const server = createHTTP(service);
  await new Promise(r => server.listen(0, '127.0.0.1', r));
  t.after(() => new Promise(r => server.close(r)));
  const base = 'http://127.0.0.1:' + server.address().port;
  assert.equal((await fetch(base + '/health')).status, 200);
  assert.equal((await fetch(base + '/health', { headers: { Origin: 'https://example.com' } })).status, 403);
  const wrongHost = await new Promise(resolve => { const req = nativeRequest(base + '/health', { headers: { Host: 'evil.example' } }, response => { response.resume(); resolve(response.statusCode); }); req.end(); });
  assert.equal(wrongHost, 403);
  assert.equal((await fetch(base + '/v1/me', { headers: { 'X-Yiyu-Client': 'native-v1' } })).status, 401);
  const created = await fetch(base + '/v1/register', { method: 'POST', headers: { 'X-Yiyu-Client': 'native-v1', 'Content-Type': 'application/json' }, body: JSON.stringify({ username: 'http_player', password: PASSWORD, acceptAccount: true }) });
  assert.equal(created.status, 200);
  const body = await created.json(); assert.ok(body.token); assert.equal(body.state.identity, 'unverified');
  const forged = await fetch(base + '/v1/characters', { method: 'POST', headers: { 'X-Yiyu-Client': 'native-v1', 'Content-Type': 'application/json', Authorization: 'Bearer ' + body.token }, body: JSON.stringify(creation({ identity: 'verified' })) });
  assert.equal(forged.status, 409); assert.equal((await forged.json()).error.code, 'IDENTITY_NOT_STARTED');
});
test('OpenAI uses Luna Responses schema and rejects partial, quota and authorization failures', async t => {
  let mode = 'success';
  t.mock.method(globalThis, 'fetch', async (url, options) => {
    assert.equal(url, 'https://api.openai.com/v1/responses');
    const body = JSON.parse(options.body); assert.equal(body.model, MODEL); assert.equal(body.store, false); assert.equal(body.text.format.strict, true);
    if (mode === 'quota') return Response.json({ error: { message: KEY } }, { status: 429 });
    if (mode === 'auth') return Response.json({}, { status: 401 });
    return Response.json({ status: mode === 'partial' ? 'incomplete' : 'completed', output: [{ content: [{ type: 'output_text', text: JSON.stringify({ approved: true, reason: '測試成功' }) }] }] });
  });
  const ai = new OpenAI(); assert.equal((await ai.call(KEY, 'connect')).approved, true);
  mode = 'partial'; await assert.rejects(ai.call(KEY, 'connect'), { code: 'AI_INCOMPLETE' });
  mode = 'quota'; await assert.rejects(ai.call(KEY, 'connect'), e => e.code === 'AI_LIMIT' && !e.message.includes(KEY));
  mode = 'auth'; await assert.rejects(ai.call(KEY, 'connect'), { code: 'AI_KEY_REJECTED' });
});
test('Persona requires account binding, approved inquiry, document sex and live matching selfie', async t => {
  let status = 'approved', sex = 'F', liveness = true, reference = 'account-one';
  t.mock.method(globalThis, 'fetch', async url => {
    if (url.includes('/inquiries/')) return Response.json({ data: { id: 'inq_test', attributes: { status, 'reference-id': reference, fields: { sex: 'M' } }, relationships: { verifications: { data: [{ type: 'verification/government-id', id: 'ver_id' }, { type: 'verification/selfie', id: 'ver_selfie' }] } } } });
    const isID = url.includes('/government-ids/');
    return Response.json({ data: { attributes: { status: 'passed', sex, 'identification-number': 'TEST-NOT-REAL', 'id-class': 'id', 'country-code': 'TW', checks: isID ? [{ name: 'id_check', status: 'passed', requirement: 'required' }] : [ { name: 'selfie_id_comparison', status: 'passed', requirement: 'required' }, { name: 'selfie_liveness_detection', status: liveness ? 'passed' : 'failed', requirement: 'not_required' } ] }, relationships: { inquiry: { data: { id: 'inq_test' } } } } });
  });
  const persona = new Persona({ apiKey: 'test-persona', templateId: 'itmpl_test', environment: 'production' });
  assert.equal((await persona.check('account-one', 'inq_test')).sex, 'F');
  sex = null; assert.equal((await persona.check('account-one', 'inq_test')).status, 'needs_review');
  sex = 'F'; liveness = false; assert.equal((await persona.check('account-one', 'inq_test')).status, 'needs_review');
  liveness = true; status = 'completed'; assert.equal((await persona.check('account-one', 'inq_test')).status, 'pending');
  status = 'approved'; reference = 'wrong-account'; await assert.rejects(persona.check('account-one', 'inq_test'), { code: 'IDENTITY_BINDING' });
});
