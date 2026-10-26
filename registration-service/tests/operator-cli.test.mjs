import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { DatabaseSync } from 'node:sqlite';
import { localVault } from '../vault.mjs';
import { Registration } from '../core.mjs';
import { Persona, OpenAI } from '../providers.mjs';

test('operator CLI requires evidence, freezes only synthetic accounts, preserves tombstones and supports appeal restore', { skip: process.platform !== 'win32' }, async t => {
  const evidenceRoot = fileURLToPath(new URL('./evidence/', import.meta.url));
  mkdirSync(evidenceRoot, { recursive: true });
  const directory = mkdtempSync(join(evidenceRoot, 'operator-'));
  const path = join(directory, 'accounts.sqlite');
  const vault = localVault(directory);
  const service = new Registration({ path, vault, persona: new Persona(), ai: new OpenAI() });
  const account = await service.account('synthetic_operator_case', 'synthetic-operator-password', true);
  const id = service.authenticate(account.token);
  const fingerprint = vault.fingerprint('SYNTHETIC-OPERATOR-IDENTITY');
  service.db.prepare("UPDATE accounts SET fingerprint=?,identity_status='verified',sex='F' WHERE id=?").run(fingerprint, id);
  service.db.prepare('INSERT INTO characters(id,owner,surname,given,sex,appearance,entry,created) VALUES (?,?,?,?,?,?,?,?)')
    .run('synthetic-character', id, '林', '知遠', 'F', 'arrival-female', 'arrival', Date.now());
  service.close();
  const db = new DatabaseSync(path);
  t.after(() => db.close());
  const run = (file, args, input) => spawnSync(process.execPath, [fileURLToPath(new URL('../' + file, import.meta.url)), ...args], {
    env: { ...process.env, YIYU_DATA_DIR: directory }, input, encoding: 'utf8', windowsHide: true, timeout: 15000,
  });
  const act = action => {
    const result = run('moderate.mjs', [action, id, 'SYNTHETIC-CASE-001', 'Synthetic evidence and appeal only']);
    assert.equal(result.status, 0, `${action}: ${result.stderr}`);
  };
  const denied = run('moderate.mjs', ['freeze', id, 'x', 'short']);
  assert.notEqual(denied.status, 0);
  assert.equal(db.prepare('SELECT state FROM accounts WHERE id=?').get(id).state, 'active');
  act('delete-character');
  assert.equal(db.prepare('SELECT state FROM characters WHERE owner=?').get(id).state, 'deleted');
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM characters').get().n, 1);
  act('freeze');
  assert.equal(db.prepare('SELECT state FROM accounts WHERE id=?').get(id).state, 'frozen');
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM sessions WHERE account=?').get(id).n, 0);
  act('block-identity');
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM identity_blocks WHERE fingerprint=?').get(fingerprint).n, 1);
  act('restore');
  assert.equal(db.prepare('SELECT state FROM accounts WHERE id=?').get(id).state, 'active');
  assert.equal(db.prepare('SELECT state FROM characters WHERE owner=?').get(id).state, 'active');
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM identity_blocks').get().n, 0);
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM sessions WHERE account=?').get(id).n, 0, 'appeal does not resurrect revoked sessions');
  const events = db.prepare("SELECT event,reason FROM audit WHERE event LIKE 'manual_%'").all();
  assert.equal(events.length, 4);
  assert.ok(events.every(event => event.reason.startsWith('SYNTHETIC-CASE-001:')));

  const invalidConfig = run('configure-persona.mjs', [], JSON.stringify({ apiKey: 'persona_sandbox_test_only', templateId: 'itmpl_test', environment: 'production' }));
  assert.notEqual(invalidConfig.status, 0);
  assert.equal(existsSync(join(directory, 'persona.encrypted')), false);
  const config = { apiKey: 'persona_production_synthetic_not_real', templateId: 'itmpl_test', environment: 'production' };
  const configured = run('configure-persona.mjs', [], JSON.stringify(config));
  assert.equal(configured.status, 0, configured.stderr);
  const ciphertext = readFileSync(join(directory, 'persona.encrypted'), 'utf8');
  assert.equal(ciphertext.includes(config.apiKey), false);
  assert.deepEqual(JSON.parse(vault.open(ciphertext, 'persona-operator')), config);
  t.diagnostic('Only generated test directory used; synthetic settings are not real Persona activation; no network service started.');
});
