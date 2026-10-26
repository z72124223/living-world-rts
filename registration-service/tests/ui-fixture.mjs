// Isolated native UI verification only. This file is never shipped in the playable bundle.
import { randomBytes } from 'node:crypto';
import { Registration } from '../core.mjs';
import { Vault } from '../vault.mjs';
import { Persona } from '../providers.mjs';
import { createHTTP } from '../server.mjs';
const fixture = process.argv.includes('--fixture-success');
const service = new Registration({ path: ':memory:', vault: new Vault(randomBytes(32)),
  persona: fixture ? { configured: true, async start(id) { return { inquiryId: 'inq_' + id, url: '' }; }, async check(id) { return { status: 'verified', sex: 'F', fingerprintInput: 'TEST-ONLY:' + id }; } } : new Persona(),
  ai: { async call(key, task) { return task === 'suggest' ? { surname: '林', given: '知遠', explanation: '測試資料' } : { approved: true, reason: '測試資料，未呼叫外部服務' }; } }
});
const server = createHTTP(service);
server.listen(8787, '127.0.0.1', () => console.log('UI_TEST_FIXTURE_READY ' + fixture));
