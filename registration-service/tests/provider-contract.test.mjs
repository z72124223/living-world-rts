import test from 'node:test';
import assert from 'node:assert/strict';
import { OpenAI, Persona, Fault, MODEL } from '../providers.mjs';

// Offline HTTP contract fixtures only; fetch is replaced in every test that calls a provider.
// These assertions do not establish real identity, template configuration or paid API access.
const KEY = 'test-only-provider-secret';
const ACCOUNT = 'contract-account';
const INQUIRY = 'inq_contract';
const config = { apiKey: `persona_production_${KEY}`, templateId: 'itmpl_contract', environment: 'production' };
const decision = { approved: true, reason: '離線契約測試' };
const suggestion = { surname: '歐陽', given: '若川', explanation: '離線契約測試' };
const clone = value => structuredClone(value);
const fail = (code, status) => error => error instanceof Fault && error.code === code && error.status === status && !error.message.includes(KEY);
const message = result => ({ type: 'message', role: 'assistant', status: 'completed', content: [{ type: 'output_text', text: JSON.stringify(result) }] });
const aiResponse = result => ({ status: 'completed', output: [message(result)] });

function aiFixture(t, data, status = 200) {
  t.mock.method(globalThis, 'fetch', async (url, options) => {
    assert.equal(url, 'https://api.openai.com/v1/responses');
    assert.equal(options.method, 'POST');
    assert.equal(options.headers.Authorization, `Bearer ${KEY}`);
    assert.ok(options.signal instanceof AbortSignal);
    const body = JSON.parse(options.body);
    assert.equal(body.model, MODEL);
    assert.equal(body.store, false);
    assert.equal(body.max_output_tokens, 300);
    assert.deepEqual(body.reasoning, { effort: 'none' });
    assert.equal(body.text.format.strict, true);
    assert.equal(body.text.format.schema.additionalProperties, false);
    return data instanceof Response ? data : Response.json(data, { status });
  });
  return new OpenAI();
}

test('OpenAI parses one assistant result even after a reasoning item', async t => {
  const data = aiResponse(decision);
  data.output.unshift({ type: 'reasoning', summary: [] });
  assert.deepEqual(await aiFixture(t, data).call(KEY, 'review'), decision);
});
test('OpenAI preserves an explicit rejection and a complete name suggestion', async t => {
  const data = aiResponse({ approved: false, reason: '姓名需調整' });
  const ai = aiFixture(t, data);
  assert.deepEqual(await ai.call(KEY, 'review'), { approved: false, reason: '姓名需調整' });
  data.output = [message(suggestion)];
  assert.deepEqual(await ai.call(KEY, 'suggest'), suggestion);
});

for (const [label, task, result] of [
  ['null JSON', 'review', null], ['array JSON', 'review', []],
  ['boolean encoded as text', 'review', { approved: 'true', reason: 'x' }],
  ['missing reason', 'review', { approved: true }],
  ['extra approval field', 'review', { ...decision, injected: true }],
  ['missing explanation', 'suggest', { surname: '林', given: '知遠' }],
  ['non-string explanation', 'suggest', { ...suggestion, explanation: {} }],
  ['extra suggestion field', 'suggest', { ...suggestion, approved: true }],
  ['invalid Han name', 'suggest', { ...suggestion, given: 'test' }],
]) {
  test(`OpenAI rejects ${label}`, async t => {
    await assert.rejects(aiFixture(t, aiResponse(result)).call(KEY, task), fail('AI_INVALID_RESPONSE', 502));
  });
}
for (const [label, change] of [
  ['non-array output', d => { d.output = {}; }],
  ['null output item', d => { d.output = [null]; }],
  ['non-array content', d => { d.output[0].content = {}; }],
  ['non-assistant output', d => { d.output[0].role = 'user'; }],
  ['non-message output', d => { d.output[0].type = 'reasoning'; }],
  ['unfinished message', d => { d.output[0].status = 'incomplete'; }],
  ['refusal only', d => { d.output[0].content = [{ type: 'refusal', refusal: KEY }]; }],
  ['refusal with approval text', d => { d.output[0].content.unshift({ type: 'refusal', refusal: KEY }); }],
  ['separate messages concatenated into JSON', d => { d.output = [message(decision), message(decision)]; d.output[0].content[0].text = '{"approved":'; d.output[1].content[0].text = 'true,"reason":"x"}'; }],
]) {
  test(`OpenAI rejects ${label}`, async t => {
    const data = aiResponse(decision); change(data);
    await assert.rejects(aiFixture(t, data).call(KEY, 'review'), fail('AI_INVALID_RESPONSE', 502));
  });
}
test('OpenAI null envelope is a controlled failure', async t => {
  await assert.rejects(aiFixture(t, null).call(KEY, 'connect'), fail('AI_INCOMPLETE', 502));
});
for (const [status, code, publicStatus] of [[403, 'AI_MODEL_UNAVAILABLE', 422], [404, 'AI_MODEL_UNAVAILABLE', 422], [500, 'AI_SERVICE_ERROR', 503]]) {
  test(`OpenAI maps HTTP ${status} without disclosing the provider body`, async t => {
    await assert.rejects(aiFixture(t, { error: { message: KEY } }, status).call(KEY, 'connect'), fail(code, publicStatus));
  });
}
test('OpenAI malformed HTTP JSON is a controlled failure', async t => {
  await assert.rejects(aiFixture(t, new Response('<html>not JSON</html>')).call(KEY, 'connect'), fail('AI_INCOMPLETE', 502));
});
test('provider network failure is sanitized', async t => {
  t.mock.method(globalThis, 'fetch', async () => { throw new Error(KEY); });
  await assert.rejects(new OpenAI().call(KEY, 'connect'), fail('PROVIDER_UNREACHABLE', 503));
  await assert.rejects(new Persona(config).check(ACCOUNT, INQUIRY), fail('PROVIDER_UNREACHABLE', 503));
});

function records() {
  const verification = (id, type, checks) => ({ data: { id, type,
    attributes: { status: 'passed', checks }, relationships: { inquiry: { data: { type: 'inquiry', id: INQUIRY } } } } });
  const document = verification('ver_document', 'verification/government-id', [{ name: 'id_expired_detection', requirement: 'required', status: 'passed' }]);
  Object.assign(document.data.attributes, { 'identification-number': ' TEST-NOT-A-REAL-ID ', 'country-code': 'TW', 'id-class': 'id', sex: 'F', 'expiration-date': '2099-12-31' });
  return {
    inquiry: { data: { type: 'inquiry', id: INQUIRY, attributes: { status: 'approved', 'reference-id': ACCOUNT, fields: { sex: { value: 'M' } } }, relationships: {
      'inquiry-template': { data: { type: 'inquiry-template', id: config.templateId } },
      verifications: { data: [{ type: 'verification/government-id', id: 'ver_document' }, { type: 'verification/selfie', id: 'ver_selfie' }] },
    } } },
    document,
    selfie: verification('ver_selfie', 'verification/selfie', [
      { name: 'selfie_id_comparison', requirement: 'required', status: 'passed' },
      { name: 'selfie_liveness_detection', requirement: 'required', status: 'passed' },
    ]),
  };
}
function personaFixture(t, data = records()) {
  const calls = [];
  t.mock.method(globalThis, 'fetch', async (url, options) => {
    const path = url.replace('https://api.withpersona.com/api/v1/', '');
    assert.notEqual(path, url, 'all requests must stay on the official Persona origin');
    assert.equal(options.headers.Authorization, `Bearer ${config.apiKey}`);
    assert.equal(options.headers['Persona-Version'], '2025-12-08');
    calls.push({ path, options });
    if (path === 'inquiries') {
      assert.equal(options.method, 'POST');
      assert.deepEqual(JSON.parse(options.body), { data: { attributes: { 'inquiry-template-id': config.templateId, 'reference-id': ACCOUNT } } });
      return Response.json(data.created ?? data.inquiry);
    }
    if (path === `inquiries/${INQUIRY}/resume`) {
      assert.equal(options.method, 'POST');
      return Response.json(data.resumed ?? { ...data.inquiry, meta: { 'session-token': 'test token?&=' } });
    }
    assert.equal(options.method, 'GET');
    if (path === `inquiries/${INQUIRY}`) return Response.json(data.inquiry);
    if (path === 'verification/government-ids/ver_document') return Response.json(data.document);
    if (path === 'verification/government-ids/ver_document_other') return Response.json(data.otherDocument ?? { data: { ...data.document.data, id: 'ver_document_other' } });
    if (path === 'verification/selfies/ver_selfie') return Response.json(data.selfie);
    assert.fail(`unexpected request: ${path}`);
  });
  return { persona: new Persona(config), calls, data };
}
test('Persona returns a document-derived identity and canonical fingerprint input', async t => {
  const { persona, data } = personaFixture(t);
  assert.deepEqual(await persona.check(ACCOUNT, INQUIRY), { status: 'verified', sex: 'F', fingerprintInput: '["TW","id","TEST-NOT-A-REAL-ID"]' });
  data.document.data.attributes.sex = 'M';
  assert.equal((await persona.check(ACCOUNT, INQUIRY)).sex, 'M');
});
test('Persona unconfigured or sandbox credentials make no HTTP request', async t => {
  t.mock.method(globalThis, 'fetch', () => assert.fail('must not contact provider'));
  for (const input of [{}, { ...config, environment: 'sandbox' }, { ...config, apiKey: '   ' }, { ...config, apiKey: `persona_sandbox_${KEY}` }, { ...config, apiKey: {} }]) {
    await assert.rejects(new Persona(input).start(ACCOUNT), fail('IDENTITY_PROVIDER_NOT_CONFIGURED', 503));
  }
});
test('Persona create, reuse and resume preserve account binding and encode session tokens', async t => {
  const { persona, data, calls } = personaFixture(t);
  data.inquiry.data.attributes.status = 'created';
  assert.equal((await persona.start(ACCOUNT)).inquiryId, INQUIRY);
  assert.equal((await persona.start(ACCOUNT, INQUIRY)).url, `https://inquiry.withpersona.com/verify?inquiry-id=${INQUIRY}`);
  data.inquiry.data.attributes.status = 'pending';
  const resumed = await persona.start(ACCOUNT, INQUIRY);
  assert.equal(new URL(resumed.url).searchParams.get('session-token'), 'test token?&=');
  assert.equal(calls.filter(c => c.options.method === 'POST').length, 2);
});
for (const action of ['create', 'reuse', 'resume', 'check']) {
  for (const [label, change] of [
    ['wrong account', d => { d.attributes['reference-id'] = 'another-account'; }],
    ['wrong resource type', d => { d.type = 'account'; }],
    ['wrong template', d => { d.relationships['inquiry-template'].data.id = 'itmpl_other'; }],
  ]) {
    test(`Persona ${action} rejects ${label}`, async t => {
      const { persona, data } = personaFixture(t);
      data.inquiry.data.attributes.status = action === 'resume' ? 'pending' : 'created';
      if (action === 'resume') { data.resumed = clone(data.inquiry); data.resumed.meta = { 'session-token': 'test-token' }; change(data.resumed.data); }
      else change(data.inquiry.data);
      const request = action === 'check' ? persona.check(ACCOUNT, INQUIRY) : persona.start(ACCOUNT, action === 'create' ? undefined : INQUIRY);
      await assert.rejects(request, e => e instanceof Fault && ['IDENTITY_BINDING', 'IDENTITY_RESPONSE'].includes(e.code));
    });
  }
}
for (const action of ['reuse', 'resume', 'check']) {
  test(`Persona ${action} rejects a mismatched inquiry id`, async t => {
    const { persona, data } = personaFixture(t);
    data.inquiry.data.attributes.status = action === 'resume' ? 'pending' : 'created';
    if (action === 'resume') { data.resumed = clone(data.inquiry); data.resumed.meta = { 'session-token': 'test-token' }; data.resumed.data.id = 'inq_other'; }
    else data.inquiry.data.id = 'inq_other';
    await assert.rejects(action === 'check' ? persona.check(ACCOUNT, INQUIRY) : persona.start(ACCOUNT, INQUIRY), fail('IDENTITY_BINDING', 409));
  });
}
for (const [label, change] of [
  ['mismatched document id', d => { d.document.data.id = 'ver_other'; }],
  ['mismatched document type', d => { d.document.data.type = 'verification/selfie'; }],
  ['mismatched selfie id', d => { d.selfie.data.id = 'ver_other'; }],
  ['wrong verification inquiry', d => { d.document.data.relationships.inquiry.data.id = 'inq_other'; }],
  ['wrong inquiry relationship type', d => { d.selfie.data.relationships.inquiry.data.type = 'account'; }],
  ['null relationship entry', d => { d.inquiry.data.relationships.verifications.data = [null]; }],
  ['non-array relationships', d => { d.inquiry.data.relationships.verifications.data = {}; }],
  ['non-array checks', d => { d.document.data.attributes.checks = {}; }],
  ['null check', d => { d.document.data.attributes.checks.push(null); }],
  ['failed required check', d => { d.document.data.attributes.checks[0].status = 'failed'; }],
  ['failed check of unknown requirement', d => { delete d.document.data.attributes.checks[0].requirement; d.document.data.attributes.checks[0].status = 'failed'; }],
  ['blank identity number', d => { d.document.data.attributes['identification-number'] = '   '; }],
  ['object identity number', d => { d.document.data.attributes['identification-number'] = {}; }],
  ['numeric identity number', d => { d.document.data.attributes['identification-number'] = 123; }],
  ['missing id class', d => { delete d.document.data.attributes['id-class']; }],
  ['blank country', d => { d.document.data.attributes['country-code'] = '  '; }],
  ['invalid country type', d => { d.document.data.attributes['country-code'] = []; }],
  ['invalid expiration', d => { d.document.data.attributes['expiration-date'] = 'not-a-date'; }],
  ['nonexistent expiration day', d => { d.document.data.attributes['expiration-date'] = '2099-02-30'; }],
  ['expired document', d => { d.document.data.attributes['expiration-date'] = '2000-01-01'; }],
  ['unknown document sex despite inquiry prefill', d => { d.document.data.attributes.sex = null; }],
  ['missing liveness evidence', d => { d.selfie.data.attributes.checks.pop(); }],
  ['contradictory optional liveness evidence', d => { d.selfie.data.attributes.checks.push({ name: 'selfie_liveness_detection', requirement: 'not_required', status: 'failed' }); }],
  ['multiple passing documents', d => { d.inquiry.data.relationships.verifications.data.push({ type: 'verification/government-id', id: 'ver_document_other' }); }],
  ['multiple passing documents despite untrusted second-document checks', d => {
    d.inquiry.data.relationships.verifications.data.push({ type: 'verification/government-id', id: 'ver_document_other' });
    d.otherDocument = clone(d.document); d.otherDocument.data.id = 'ver_document_other';
    d.otherDocument.data.attributes.checks = [{ name: 'id_expired_detection', status: 'failed' }];
  }],
  ['failed retry-required check', d => { Object.assign(d.document.data.attributes.checks[0], { requirement: 'requires_retry', status: 'failed' }); }],
  ['oversized verification relationship list', d => { d.inquiry.data.relationships.verifications.data.push(...Array.from({ length: 29 }, () => ({ type: 'verification/other', id: 'ver_other' }))); }],
]) {
  test(`Persona holds ${label} for review`, async t => {
    const { persona, data } = personaFixture(t); change(data);
    assert.deepEqual(await persona.check(ACCOUNT, INQUIRY), { status: 'needs_review' });
  });
}
test('Persona null response fails without a raw TypeError', async t => {
  t.mock.method(globalThis, 'fetch', async () => Response.json(null));
  await assert.rejects(new Persona(config).check(ACCOUNT, INQUIRY), fail('IDENTITY_RESPONSE', 502));
});
test('Persona accepts passing checks when the optional requirement field is absent', async t => {
  const { persona, data } = personaFixture(t);
  for (const resource of [data.document, data.selfie]) for (const check of resource.data.attributes.checks) delete check.requirement;
  assert.equal((await persona.check(ACCOUNT, INQUIRY)).status, 'verified');
});
test('Persona accepts a passed requires_retry check', async t => {
  const { persona, data } = personaFixture(t);
  data.document.data.attributes.checks[0].requirement = 'requires_retry';
  assert.equal((await persona.check(ACCOUNT, INQUIRY)).status, 'verified');
});
test('Persona accepts absent expiry only with otherwise passing document evidence', async t => {
  const { persona, data } = personaFixture(t);
  data.document.data.attributes['expiration-date'] = null;
  assert.equal((await persona.check(ACCOUNT, INQUIRY)).status, 'verified');
});
test('Persona pending create includes the returned session token', async t => {
  const { persona, data } = personaFixture(t);
  data.inquiry.data.attributes.status = 'pending';
  data.inquiry.meta = { 'session-token': 'create token?&=' };
  const result = await persona.start(ACCOUNT);
  assert.equal(new URL(result.url).searchParams.get('session-token'), 'create token?&=');
});
for (const action of ['create', 'resume']) {
  test(`Persona pending ${action} rejects missing or blank token`, async t => {
    const { persona, data } = personaFixture(t);
    data.inquiry.data.attributes.status = 'pending';
    data.resumed = clone(data.inquiry);
    for (const token of [undefined, '', '   ', 123]) {
      data.inquiry.meta = { 'session-token': token }; data.resumed.meta = { 'session-token': token };
      await assert.rejects(persona.start(ACCOUNT, action === 'create' ? undefined : INQUIRY), fail('IDENTITY_RESUME', 409));
    }
  });
}
test('Persona non-JSON HTTP body and HTTP failure stay controlled and sanitized', async t => {
  let mode = 'body';
  t.mock.method(globalThis, 'fetch', async () => mode === 'body' ? new Response('<html>bad gateway</html>') : Response.json({ errors: [KEY] }, { status: 403 }));
  const persona = new Persona(config);
  await assert.rejects(persona.check(ACCOUNT, INQUIRY), fail('IDENTITY_RESPONSE', 502));
  mode = 'http';
  await assert.rejects(persona.check(ACCOUNT, INQUIRY), fail('IDENTITY_SERVICE_ERROR', 503));
});
test('Persona only replaces expired inquiries; terminal or completed inquiries make no new POST', async t => {
  const { persona, data, calls } = personaFixture(t);
  for (const status of ['completed', 'approved', 'declined', 'failed']) {
    data.inquiry.data.attributes.status = status;
    await assert.rejects(persona.start(ACCOUNT, INQUIRY), fail('IDENTITY_PENDING_REVIEW', 409));
  }
  assert.equal(calls.filter(c => c.options.method === 'POST').length, 0);
  data.created = clone(data.inquiry); data.created.data.attributes.status = 'created'; data.created.data.id = 'inq_replacement';
  data.inquiry.data.attributes.status = 'expired';
  assert.equal((await persona.start(ACCOUNT, INQUIRY)).inquiryId, 'inq_replacement');
});
