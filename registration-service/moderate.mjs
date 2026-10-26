import { createLocalService } from './server.mjs';
import { insist } from './providers.mjs';

// Operator-only local command; no HTTP route can grant moderation authority.
const [action, accountId, evidence, ...reasonParts] = process.argv.slice(2);
const reason = reasonParts.join(' ');
insist(['delete-character', 'freeze', 'block-identity', 'restore'].includes(action), 'ACTION', '操作：delete-character | freeze | block-identity | restore');
insist(evidence?.length >= 4 && reason.length >= 8, 'EVIDENCE', '須提供人工審查案件編號與具體理由（至少八字）。');
const service = createLocalService();
try {
  const a = service.get(accountId); insist(a, 'ACCOUNT', '找不到帳號。');
  if (action === 'block-identity') insist(a.fingerprint, 'IDENTITY', '沒有已查核身分，不能建立實名黑名單。');
  service.db.exec('BEGIN IMMEDIATE');
  try {
    if (action === 'delete-character') service.db.prepare("UPDATE characters SET state='deleted' WHERE owner=?").run(accountId);
    if (action === 'freeze' || action === 'block-identity') {
      service.db.prepare("UPDATE accounts SET state='frozen' WHERE id=?").run(accountId);
      service.db.prepare('DELETE FROM sessions WHERE account=?').run(accountId);
    }
    if (action === 'block-identity') service.db.prepare('INSERT OR REPLACE INTO identity_blocks VALUES (?,?,?)').run(a.fingerprint, evidence + ': ' + reason, Date.now());
    if (action === 'restore') {
      service.db.prepare("UPDATE accounts SET state='active' WHERE id=?").run(accountId);
      if (a.fingerprint) service.db.prepare('DELETE FROM identity_blocks WHERE fingerprint=?').run(a.fingerprint);
      service.db.prepare("UPDATE characters SET state='active' WHERE owner=? AND state='deleted'").run(accountId);
    }
    service.audit(accountId, 'manual_' + action, evidence + ': ' + reason);
    service.db.exec('COMMIT');
    console.log('人工處置已保存，包含案件參照與申覆還原紀錄。');
  } catch (e) { service.db.exec('ROLLBACK'); throw e; }
} finally { service.close(); }
