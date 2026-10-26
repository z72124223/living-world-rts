// Independent QA contract checks. Synthetic identity and AI adapters only.
// HTTP binds to 127.0.0.1:0; no production service, credentials, or external API.
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { Registration } from '../core.mjs';
import { Vault } from '../vault.mjs';
import { createHTTP } from '../server.mjs';
import { Fault, Persona, POLICY, chineseName } from '../providers.mjs';

const PASSWORD = 'qa-synthetic-password-only';
const KEY = 'sk-qa-synthetic-not-a-real-api-key';
const creation = extra => ({ entry: 'arrival', surname: '司馬', given: '知遠', policy: POLICY, acceptPolicy: true, ...extra });

function fixture(t, sex = 'F') {
  const persona = { configured: true,
    async start(id) { return { inquiryId: `inq_qa_${id}`, url: '' }; },
    async check(id) { return { status: 'verified', sex, fingerprintInput: `SYNTHETIC-QA:${id}` }; } };
  const ai = { calls: [], async call(_key, purpose, payload) {
    this.calls.push({ purpose, payload });
    return purpose === 'suggest' ? { surname: '司馬', given: '知遠', explanation: '虛構測試' } : { approved: true, reason: '虛構測試' };
  } };
  const service = new Registration({ path: ':memory:', vault: new Vault(randomBytes(32)), persona, ai });
  t.after(() => service.close());
  return { service, ai };
}

async function ready(service, name = 'qa_account', review = true) {
  const result = await service.account(name, PASSWORD, true);
  const id = service.authenticate(result.token);
  await service.startIdentity(id, true);
  await service.checkIdentity(id);
  await service.connectAI(id, { key: KEY, consent: true, dailyMax: 20 });
  if (review) await service.name(id, { surname: '司馬', given: '知遠', consent: true }, false);
  return { id, token: result.token };
}

function child(service, id, overrides = {}) {
  const c = { surname: '歐陽', given: '若川', sex: 'F', access: 'public', reserved: null, occupied: null, approved: 1, appearance: 'qa-child-female', ...overrides };
  service.db.prepare('INSERT INTO children VALUES (?,?,?,?,?,?,?,?,?)').run(id, c.surname, c.given, c.sex, c.access, c.reserved, c.occupied, c.approved, c.appearance);
}

test('QA name format accepts compound/rare Han names and rejects non-name input without an AI call', () => {
  for (const name of [['歐陽', '若川'], ['司馬', '懿'], ['林', '𠮷']]) assert.equal(chineseName(...name), true);
  for (const name of [['', '明'], ['林', ''], ['ABC', '明'], ['林', 'A'], ['林', '明明明'], ['林', '🙂'], ['林 ', '明']]) assert.equal(chineseName(...name), false);
});

test('QA no vacancy and ineligible children never create a character or consume a child', async t => {
  const { service } = fixture(t); const a = await ready(service);
  child(service, 'reserved', { access: 'reserved', reserved: a.id });
  child(service, 'public-but-reserved', { reserved: a.id });
  child(service, 'occupied', { occupied: 'synthetic-existing-owner' });
  child(service, 'male', { sex: 'M' });
  child(service, 'unreviewed', { approved: 0 });
  assert.equal(service.state(a.id).availableChildren, 0);
  await assert.rejects(service.createCharacter(a.id, creation({ entry: 'reincarnation', child: 'reserved' })), { code: 'NO_CHILD' });
  assert.equal(service.db.prepare('SELECT COUNT(*) AS n FROM characters').get().n, 0);
  assert.equal(service.db.prepare('SELECT COUNT(*) AS n FROM children WHERE occupied_by=?').get(a.id).n, 0);
});

test('QA both registered sexes inherit the eligible child name and appearance despite forged client fields', async t => {
  for (const sex of ['F', 'M']) {
    const { service } = fixture(t, sex); const a = await ready(service, 'qa_' + sex, false);
    child(service, 'eligible', { sex, appearance: 'qa-child-' + sex });
    const state = await service.createCharacter(a.id, creation({ entry: 'reincarnation', surname: '假', given: '改名', sex: sex === 'F' ? 'M' : 'F', child: 'not-the-child', appearance: 'forged', items: ['weapon'] }));
    assert.deepEqual([state.character.surname, state.character.given, state.character.sex, state.character.appearance], ['歐陽', '若川', sex, 'qa-child-' + sex]);
    assert.equal(state.character.items, undefined);
    assert.equal(service.db.prepare("SELECT occupied_by FROM children WHERE id='eligible'").get().occupied_by, a.id);
    assert.equal(state.availableChildren, 0);
  }
});

test('QA suggestions do not grant name approval, and AI rejection never freezes or deletes an account', async t => {
  const { service, ai } = fixture(t); const a = await ready(service, 'qa_suggest', false);
  await service.name(a.id, { surname: '司馬', consent: true }, true);
  await assert.rejects(service.createCharacter(a.id, creation()), { code: 'NAME_REVIEW_REQUIRED' });
  ai.call = async () => ({ approved: false, reason: '虛構拒絕' });
  await service.name(a.id, { surname: '司馬', given: '知遠', consent: true }, false);
  await assert.rejects(service.createCharacter(a.id, creation()), { code: 'NAME_REVIEW_REQUIRED' });
  assert.equal(service.authenticate(a.token), a.id);
  assert.equal(service.get(a.id).state, 'active');
  assert.equal(service.db.prepare('SELECT COUNT(*) AS n FROM identity_blocks').get().n, 0);
});

test('QA an expired AI connection blocks creation even while the exact name review is current', async t => {
  const { service } = fixture(t); const a = await ready(service);
  service.db.prepare('UPDATE accounts SET ai_checked=? WHERE id=?').run(Date.now() - 16 * 60000, a.id);
  assert.equal(service.state(a.id).review.approved, true);
  assert.equal(service.state(a.id).aiConnected, false);
  await assert.rejects(service.createCharacter(a.id, creation()), { code: 'AI_REQUIRED' });
});

test('QA failed AI attempts consume the daily limit and do not call a provider again after exhaustion', async t => {
  const { service, ai } = fixture(t); const a = await ready(service, 'qa_limit', false);
  service.db.prepare('UPDATE accounts SET daily_max=2 WHERE id=?').run(a.id);
  let attempts = 0;
  ai.call = async () => { attempts++; throw new Fault('AI_LIMIT', '虛構供應商拒絕', 429); };
  const request = { surname: '司馬', given: '知遠', consent: true };
  await assert.rejects(service.name(a.id, request, false), { code: 'AI_LIMIT' });
  await assert.rejects(service.name(a.id, request, false), { code: 'DAILY_LIMIT' });
  assert.equal(attempts, 1);
  assert.equal(service.state(a.id).callsToday, 2);
  assert.equal(service.state(a.id).aiConnected, false);
});

test('QA HTTP register/login to creation obeys server-owned identity/name and protects session data', async t => {
  const { service } = fixture(t);
  const server = createHTTP(service);
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const port = server.address().port;
  assert.ok(![8787, 8788].includes(port));
  t.diagnostic(`loopback random port: ${port}`);
  const base = `http://127.0.0.1:${port}`;
  let token;
  async function request(path, body, method = 'POST') {
    const response = await fetch(base + path, { method, headers: {
      'X-Yiyu-Client': 'native-v1', 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {})
    }, ...(method === 'GET' ? {} : { body: JSON.stringify(body) }) });
    return { status: response.status, data: await response.json() };
  }
  const registered = await request('/v1/register', { username: 'qa_http', password: PASSWORD, acceptAccount: true });
  assert.equal(registered.status, 200); token = registered.data.token;
  await request('/v1/logout', {});
  assert.equal((await request('/v1/me', {}, 'GET')).status, 401);
  const login = await request('/v1/login', { username: 'qa_http', password: PASSWORD });
  assert.equal(login.status, 200); token = login.data.token;
  assert.equal((await request('/v1/identity/start', { consent: true })).status, 200);
  assert.equal((await request('/v1/identity/check', {})).data.state.sex, 'F');
  assert.equal((await request('/v1/ai/connect', { key: KEY, consent: true, dailyMax: 20 })).status, 200);
  await request('/v1/names/review', { surname: '司馬', given: '知遠', consent: true });
  assert.equal((await request('/v1/characters', creation({ acceptPolicy: false }))).data.error.code, 'POLICY_REQUIRED');
  const created = await request('/v1/characters', creation({ sex: 'M', appearance: 'custom', items: ['food'] }));
  assert.equal(created.status, 200);
  assert.deepEqual([created.data.state.character.surname, created.data.state.character.sex, created.data.state.character.appearance], ['司馬', 'F', 'arrival-female']);
  const me = await request('/v1/me', {}, 'GET');
  assert.equal(me.status, 200);
  const publicState = JSON.stringify(me.data);
  for (const secret of [KEY, PASSWORD, token, 'SYNTHETIC-QA:']) assert.equal(publicState.includes(secret), false);
  for (const path of ['/v1/moderate', '/v1/demo/start']) assert.equal((await request(path, {})).status, 404);
});

test('QA failed reconnect of the saved AI key must revoke connected status and block creation', async t => {
  const { service, ai } = fixture(t); const a = await ready(service);
  ai.call = async () => { throw new Fault('AI_KEY_REJECTED', '虛構的已撤銷金鑰', 422); };
  await assert.rejects(service.connectAI(a.id, { key: '', consent: true, dailyMax: 20 }), { code: 'AI_KEY_REJECTED' });
  const connectedAfterFailure = service.state(a.id).aiConnected;
  let createOutcome;
  try { await service.createCharacter(a.id, creation()); createOutcome = 'CREATED'; }
  catch (error) { createOutcome = error.code; }
  const actual = { connectedAfterFailure, createOutcome };
  t.diagnostic(JSON.stringify(actual));
  assert.deepEqual(actual, { connectedAfterFailure: false, createOutcome: 'AI_REQUIRED' });
});

test('QA saved-key, replacement-key, incomplete and disapproved reconnects all invalidate old authority', async t => {
  const variants = [
    { label: 'saved key rejected', key: '', failure: 'AI_KEY_REJECTED' },
    { label: 'replacement key rejected', key: 'sk-qa-replacement-synthetic-only', failure: 'AI_KEY_REJECTED' },
    { label: 'incomplete provider response', key: '', failure: 'AI_INCOMPLETE' },
    { label: 'negative connection response', key: '', failure: 'AI_CONNECT_RESPONSE', negative: true }
  ];
  for (const variant of variants) {
    const { service, ai } = fixture(t); const a = await ready(service);
    ai.call = async () => {
      if (variant.negative) return { approved: false, reason: '虛構未通過' };
      throw new Fault(variant.failure, '虛構失敗', 422);
    };
    await assert.rejects(service.connectAI(a.id, { key: variant.key, consent: true, dailyMax: 20 }), { code: variant.failure });
    const state = service.state(a.id);
    assert.equal(state.aiConnected, false, variant.label);
    assert.equal(state.review, null, variant.label);
    assert.equal(state.hasKey, true, 'Keep the encrypted saved key only for a later retry');
    assert.equal(service.vault.open(service.get(a.id).ai_key, a.id), KEY);
    await assert.rejects(service.createCharacter(a.id, creation()), { code: 'AI_REQUIRED' });
  }
  t.diagnostic('4 reconnect failure variants verified with synthetic provider responses');
});

test('QA Persona incomplete trusted document fields must remain under review', async t => {
  const cases = [
    ['missing document type', { 'id-class': undefined }],
    ['blank document number', { 'identification-number': '   ' }],
    ['blank issuing country', { 'country-code': '   ' }]
  ];
  const outcomes = [];
  for (const [label, overrides] of cases) {
    const persona = new Persona();
    // Replace only transport with synthetic data; exercise the production parser.
    persona.request = async path => {
      if (path.startsWith('inquiries/')) return { data: { id: 'inq_qa', attributes: { status: 'approved', 'reference-id': 'qa-account' }, relationships: { verifications: { data: [
        { type: 'verification/government-id', id: 'ver_qa_id' },
        { type: 'verification/selfie', id: 'ver_qa_selfie' }
      ] } } } };
      const document = path.includes('government-ids/');
      const attributes = document ? {
        status: 'passed', sex: 'F', 'id-class': 'id', 'identification-number': 'SYNTHETIC-QA-NUMBER', 'country-code': 'TW',
        checks: [{ name: 'document_check', status: 'passed', requirement: 'required' }], ...overrides
      } : { status: 'passed', checks: [
        { name: 'selfie_id_comparison', status: 'passed', requirement: 'required' },
        { name: 'selfie_liveness_detection', status: 'passed', requirement: 'required' }
      ] };
      return { data: { attributes, relationships: { inquiry: { data: { id: 'inq_qa' } } } } };
    };
    outcomes.push({ label, status: (await persona.check('qa-account', 'inq_qa')).status });
  }
  t.diagnostic(JSON.stringify(outcomes));
  assert.deepEqual(outcomes.map(x => x.status), ['needs_review', 'needs_review', 'needs_review']);
});

test('QA malformed future child records cannot fall back to the incoming player name', async t => {
  const { service } = fixture(t); const a = await ready(service, 'qa_bad_child', false);
  child(service, 'bad-parent-name', { surname: '', given: '' });
  let result = null;
  try { result = await service.createCharacter(a.id, creation({ entry: 'reincarnation', surname: '任', given: '意名' })); }
  catch (error) { t.diagnostic(`rejected malformed record: ${error.code}`); }
  t.diagnostic(JSON.stringify({ created: Boolean(result?.character), storedName: result?.character ? result.character.surname + result.character.given : null }));
  assert.equal(service.state(a.id).character, null, 'An approved marker alone must not turn a blank parent name into player renaming authority');
});
