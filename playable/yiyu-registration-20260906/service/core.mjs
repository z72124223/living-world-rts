import { DatabaseSync } from 'node:sqlite';
import { randomBytes, randomUUID, createHash, scrypt, timingSafeEqual, randomInt } from 'node:crypto';
import { promisify } from 'node:util';
import { Fault, insist, chineseName, MODEL, POLICY } from './providers.mjs';

const derive = promisify(scrypt);
const hash = value => createHash('sha256').update(value).digest('hex');
const now = () => Date.now();
const DAY = 86400000;
const AI_TTL = 15 * 60000;

export class Registration {
  constructor({ path, vault, persona, ai }) {
    this.vault = vault; this.persona = persona; this.ai = ai;
    this.db = new DatabaseSync(path);
    this.db.exec(`PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;
      CREATE TABLE IF NOT EXISTS accounts (
        id TEXT PRIMARY KEY, username TEXT UNIQUE NOT NULL, salt TEXT NOT NULL, password TEXT NOT NULL,
        state TEXT NOT NULL DEFAULT 'active', identity_status TEXT NOT NULL DEFAULT 'unverified',
        sex TEXT, fingerprint TEXT UNIQUE, inquiry TEXT, ai_key TEXT, ai_checked INTEGER NOT NULL DEFAULT 0,
        daily_max INTEGER NOT NULL DEFAULT 20, created INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS sessions (token TEXT PRIMARY KEY, account TEXT NOT NULL REFERENCES accounts(id), expires INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS name_reviews (account TEXT PRIMARY KEY REFERENCES accounts(id), surname TEXT, given TEXT, policy TEXT, approved INTEGER, checked INTEGER);
      CREATE TABLE IF NOT EXISTS calls (id TEXT PRIMARY KEY, account TEXT NOT NULL REFERENCES accounts(id), purpose TEXT NOT NULL, at INTEGER NOT NULL);
      CREATE INDEX IF NOT EXISTS calls_account_time ON calls(account,at);
      CREATE TABLE IF NOT EXISTS characters (id TEXT PRIMARY KEY, owner TEXT UNIQUE NOT NULL REFERENCES accounts(id), surname TEXT NOT NULL, given TEXT NOT NULL, sex TEXT NOT NULL, appearance TEXT NOT NULL, entry TEXT NOT NULL, child TEXT UNIQUE, state TEXT NOT NULL DEFAULT 'active', created INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS children (id TEXT PRIMARY KEY, surname TEXT NOT NULL, given TEXT NOT NULL, sex TEXT NOT NULL CHECK(sex IN ('M','F')), access TEXT NOT NULL CHECK(access IN ('public','reserved')), reserved_for TEXT, occupied_by TEXT UNIQUE, name_approved INTEGER NOT NULL DEFAULT 0, appearance TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS identity_blocks (fingerprint TEXT PRIMARY KEY, reason TEXT NOT NULL, at INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS audit (id TEXT PRIMARY KEY, account TEXT, event TEXT NOT NULL, reason TEXT, at INTEGER NOT NULL);
    `);
    this.locks = new Set(); this.authAttempts = new Map();
  }
  close() { this.db.close(); }
  get(id) { return this.db.prepare('SELECT * FROM accounts WHERE id=?').get(id); }
  audit(id, event, reason = '') { this.db.prepare('INSERT INTO audit VALUES (?,?,?,?,?)').run(randomUUID(), id, event, reason, now()); }
  async exclusive(id, operation) {
    insist(!this.locks.has(id), 'BUSY', '上一項操作尚未結束，請稍候。', 409);
    this.locks.add(id);
    try { return await operation(); } finally { this.locks.delete(id); }
  }
  async account(username, password, create = false) {
    insist(typeof username === 'string' && /^[a-zA-Z0-9_]{4,32}$/.test(username), 'USERNAME', '帳號請使用 4–32 個英數字或底線。');
    insist(typeof password === 'string' && password.length >= 12 && password.length <= 128, 'PASSWORD', '密碼長度須為 12–128 個字元。');
    username = username.toLowerCase();
    const recent = (this.authAttempts.get(username) || []).filter(x => x > now() - 60000);
    insist(recent.length < 5, 'LOGIN_RATE', '嘗試次數過多，請一分鐘後再試。', 429);
    this.authAttempts.set(username, [...recent, now()]);
    if (this.authAttempts.size > 1000) this.authAttempts.delete(this.authAttempts.keys().next().value);
    let account = this.db.prepare('SELECT * FROM accounts WHERE username=?').get(username);
    if (create) {
      insist(!account, 'ACCOUNT_EXISTS', '此帳號已使用，請登入或改用其他帳號。', 409);
      const salt = randomBytes(16).toString('hex');
      const digest = (await derive(password, salt, 64)).toString('hex');
      const id = randomUUID();
      try { this.db.prepare('INSERT INTO accounts(id,username,salt,password,created) VALUES (?,?,?,?,?)').run(id, username, salt, digest, now()); }
      catch (e) { if (String(e.code).startsWith('ERR_SQLITE')) throw new Fault('ACCOUNT_EXISTS', '此帳號已使用。', 409); throw e; }
      account = this.get(id); this.audit(id, 'account_created');
    } else {
      const digest = await derive(password, account?.salt || 'missing-account-salt', 64);
      insist(account && timingSafeEqual(digest, Buffer.from(account.password, 'hex')), 'LOGIN_FAILED', '帳號或密碼錯誤。', 401);
    }
    this.active(account);
    const token = randomBytes(32).toString('hex');
    this.db.prepare('DELETE FROM sessions WHERE expires<?').run(now());
    this.db.prepare('INSERT INTO sessions VALUES (?,?,?)').run(hash(token), account.id, now() + 12 * 3600000);
    return { token, state: this.state(account.id) };
  }
  active(account) {
    insist(account && account.state === 'active', 'ACCOUNT_FROZEN', '此帳號已凍結，請聯絡營運方申覆。', 403);
    insist(!account.fingerprint || !this.db.prepare('SELECT 1 FROM identity_blocks WHERE fingerprint=?').get(account.fingerprint), 'IDENTITY_BLOCKED', '此身分已受限制，請聯絡營運方申覆。', 403);
  }
  authenticate(token) {
    insist(typeof token === 'string' && /^[a-f0-9]{64}$/.test(token), 'AUTH_REQUIRED', '請先登入帳號。', 401);
    const session = this.db.prepare('SELECT account FROM sessions WHERE token=? AND expires>?').get(hash(token), now());
    insist(session, 'SESSION_EXPIRED', '登入已逾時，請重新登入。', 401);
    const account = this.get(session.account); this.active(account); return account.id;
  }
  logout(token) { this.db.prepare('DELETE FROM sessions WHERE token=?').run(hash(token)); return { ok: true }; }
  eligibleChildren(sex) {
    return this.db.prepare("SELECT * FROM children WHERE sex=? AND access='public' AND reserved_for IS NULL AND occupied_by IS NULL AND name_approved=1").all(sex)
      .filter(child => chineseName(child.surname, child.given) && typeof child.appearance === 'string' && child.appearance.trim().length > 0);
  }
  state(id) {
    const a = this.get(id); this.active(a);
    const review = this.db.prepare('SELECT surname,given,approved,checked FROM name_reviews WHERE account=? AND policy=?').get(id, POLICY);
    const character = this.db.prepare('SELECT id,surname,given,sex,appearance,entry,state FROM characters WHERE owner=?').get(id);
    const available = a.identity_status === 'verified' ? this.eligibleChildren(a.sex).length : 0;
    const used = this.db.prepare('SELECT COUNT(*) AS count FROM calls WHERE account=? AND at>=?').get(id, Math.floor(now() / DAY) * DAY).count;
    return { account: a.username, identity: a.identity_status, sex: a.identity_status === 'verified' ? a.sex : null, identityServiceConfigured: this.persona.configured,
      model: MODEL, aiConnected: Boolean(a.ai_key && a.ai_checked > now() - AI_TTL), hasKey: Boolean(a.ai_key), dailyMax: a.daily_max, callsToday: used,
      review: review && review.checked > now() - AI_TTL ? { surname: review.surname, given: review.given, approved: Boolean(review.approved) } : null,
      availableChildren: available, character: character || null, policy: POLICY };
  }
  requireIdentity(id) {
    const a = this.get(id); this.active(a);
    insist(a.identity_status === 'verified' && ['M', 'F'].includes(a.sex), 'IDENTITY_REQUIRED', '請先完成實名驗證。', 403); return a;
  }
  async startIdentity(id, consent) {
    insist(consent === true, 'IDENTITY_CONSENT', '請先閱讀並同意實名查核說明。');
    const a = this.get(id);
    const result = await this.persona.start(id, a.inquiry);
    this.db.prepare("UPDATE accounts SET inquiry=?, identity_status='pending' WHERE id=?").run(result.inquiryId, id);
    this.audit(id, 'identity_started');
    return { url: result.url, state: this.state(id) };
  }
  async checkIdentity(id) {
    const a = this.get(id);
    insist(a.inquiry, 'IDENTITY_NOT_STARTED', '尚未開始實名查核。', 409);
    const result = await this.persona.check(id, a.inquiry);
    if (result.status !== 'verified') {
      this.db.prepare('UPDATE accounts SET identity_status=? WHERE id=?').run(result.status, id);
      return this.state(id);
    }
    insist(['M', 'F'].includes(result.sex) && result.fingerprintInput, 'IDENTITY_ATTRIBUTES', '證件資料不完整，須由營運方複查。', 409);
    const fingerprint = this.vault.fingerprint(result.fingerprintInput);
    if (this.db.prepare('SELECT 1 FROM identity_blocks WHERE fingerprint=?').get(fingerprint)) {
      this.db.prepare("UPDATE accounts SET identity_status='blocked' WHERE id=?").run(id);
      throw new Fault('IDENTITY_BLOCKED', '此身分已受限制，請聯絡營運方申覆。', 403);
    }
    const duplicate = this.db.prepare('SELECT id FROM accounts WHERE fingerprint=? AND id<>?').get(fingerprint, id);
    insist(!duplicate, 'IDENTITY_DUPLICATE', '此證件已綁定另一個帳號，請聯絡營運方復原原帳號。', 409);
    insist(!a.fingerprint || a.fingerprint === fingerprint, 'IDENTITY_CHANGED', '已綁定帳號不得換用其他人的身分。', 409);
    this.db.prepare("UPDATE accounts SET fingerprint=?,sex=?,identity_status='verified' WHERE id=?").run(fingerprint, result.sex, id);
    this.audit(id, 'identity_verified');
    return this.state(id);
  }
  async paidCall(id, purpose, payload, consent, keyOverride) {
    const a = this.requireIdentity(id);
    insist(consent === true, 'FEE_CONSENT', '請同意由自己的 OpenAI 帳戶支付本次 AI 使用費用。');
    const key = keyOverride || (a.ai_key ? this.vault.open(a.ai_key, id) : null);
    insist(key, 'AI_KEY_REQUIRED', '請先設定自己的 OpenAI 金鑰。');
    const used = this.db.prepare('SELECT COUNT(*) AS count FROM calls WHERE account=? AND at>=?').get(id, Math.floor(now() / DAY) * DAY).count;
    insist(used < a.daily_max, 'DAILY_LIMIT', '已達今日遊戲 AI 請求次數上限；可在智慧服務中調整。', 429);
    this.db.prepare('INSERT INTO calls VALUES (?,?,?,?)').run(randomUUID(), id, purpose, now());
    try {
      const result = await this.ai.call(key, purpose, payload);
      if (a.ai_key && !keyOverride) this.db.prepare('UPDATE accounts SET ai_checked=? WHERE id=?').run(now(), id);
      return result;
    } catch (error) {
      if (!keyOverride) this.db.prepare('UPDATE accounts SET ai_checked=0 WHERE id=?').run(id);
      throw error;
    }
  }
  async connectAI(id, input) {
    this.requireIdentity(id);
    insist(input.model === undefined || input.model === MODEL, 'MODEL_LOCKED', `此版本只支援 ${MODEL}。`);
    const limit = input.dailyMax;
    insist(Number.isInteger(limit) && limit >= 1 && limit <= 100, 'DAILY_MAX', '每日請求上限須為 1–100 次。');
    const existing = this.get(id);
    const key = input.key || (existing.ai_key ? this.vault.open(existing.ai_key, id) : '');
    insist(typeof key === 'string' && /^sk-[\x21-\x7E]{16,512}$/.test(key), 'AI_KEY_FORMAT', '請輸入完整的 OpenAI 金鑰。');
    insist(input.consent === true, 'FEE_CONSENT', '請先同意 AI 費用說明。');
    // An explicit reconnect supersedes the previous connection proof even when
    // the saved key is reused or the new provider response fails. Keep the old
    // encrypted key for retry, but never retain authorization from that attempt.
    this.db.prepare('UPDATE accounts SET daily_max=?,ai_checked=0 WHERE id=?').run(limit, id);
    this.db.prepare('DELETE FROM name_reviews WHERE account=?').run(id);
    const result = await this.paidCall(id, 'connect', {}, input.consent, key);
    insist(result.approved === true, 'AI_CONNECT_RESPONSE', 'OpenAI 未完成連線確認。', 502);
    this.db.prepare('UPDATE accounts SET ai_key=?,ai_checked=? WHERE id=?').run(this.vault.seal(key, id), now(), id);
    this.audit(id, 'ai_key_connected');
    return this.state(id);
  }
  disconnectAI(id) {
    this.db.prepare('UPDATE accounts SET ai_key=NULL,ai_checked=0 WHERE id=?').run(id);
    this.db.prepare('DELETE FROM name_reviews WHERE account=?').run(id);
    this.audit(id, 'ai_key_removed'); return this.state(id);
  }
  async name(id, input, suggest) {
    const a = this.requireIdentity(id);
    if (suggest) {
      insist(input.surname === '' || /^\p{Script=Han}{1,2}$/u.test(input.surname || ''), 'NAME_FORMAT', '姓氏須為一或兩個漢字。');
      const result = await this.paidCall(id, 'suggest', { surname: input.surname, sex: a.sex }, input.consent);
      insist(chineseName(result.surname, result.given), 'NAME_FORMAT', 'AI 回覆的姓名格式不符。');
      insist(!input.surname || result.surname === input.surname, 'NAME_FORMAT', 'AI 未保留指定姓氏，請重試。');
      return { suggestion: result, state: this.state(id) };
    }
    insist(chineseName(input.surname, input.given), 'NAME_FORMAT', '姓與名各需一到兩個漢字。');
    this.db.prepare('DELETE FROM name_reviews WHERE account=?').run(id);
    const result = await this.paidCall(id, 'review', { surname: input.surname, given: input.given }, input.consent);
    this.db.prepare('INSERT OR REPLACE INTO name_reviews VALUES (?,?,?,?,?,?)').run(id, input.surname, input.given, POLICY, result.approved ? 1 : 0, now());
    return { approved: result.approved, reason: String(result.reason).slice(0, 240), state: this.state(id) };
  }
  async createCharacter(id, input) {
    insist(input.policy === POLICY && input.acceptPolicy === true, 'POLICY_REQUIRED', '請先閱讀並同意命名規範。');
    insist(['arrival', 'reincarnation'].includes(input.entry), 'ENTRY', '請選擇入世方式。');
    await this.checkIdentity(id); // Provider recheck; no trust in client flags or old redirects.
    const a = this.requireIdentity(id);
    insist(a.ai_key && a.ai_checked > now() - AI_TTL, 'AI_REQUIRED', '智慧服務連線已逾時，請重新確認金鑰。', 403);
    if (input.entry === 'arrival') {
      const review = this.db.prepare('SELECT * FROM name_reviews WHERE account=?').get(id);
      insist(review?.approved === 1 && review.policy === POLICY && review.checked > now() - AI_TTL && review.surname === input.surname && review.given === input.given,
        'NAME_REVIEW_REQUIRED', '目前姓名尚未通過 AI 審核，或審核已逾時。', 403);
    }
    this.db.exec('BEGIN IMMEDIATE');
    try {
      this.active(this.get(id));
      insist(!this.db.prepare('SELECT 1 FROM characters WHERE owner=?').get(id), 'CHARACTER_EXISTS', '此帳號已有角色，不能重複建立。', 409);
      let child;
      if (input.entry === 'reincarnation') {
        const candidates = this.eligibleChildren(a.sex);
        insist(candidates.length, 'NO_CHILD', '目前沒有符合性別與開放條件的子女。', 409);
        child = candidates[randomInt(candidates.length)];
        this.db.prepare('UPDATE children SET occupied_by=? WHERE id=? AND occupied_by IS NULL').run(id, child.id);
      }
      const characterId = randomUUID();
      this.db.prepare('INSERT INTO characters(id,owner,surname,given,sex,appearance,entry,child,created) VALUES (?,?,?,?,?,?,?,?,?)')
        .run(characterId, id, child ? child.surname : input.surname, child ? child.given : input.given, a.sex, child ? child.appearance : (a.sex === 'M' ? 'arrival-male' : 'arrival-female'), input.entry, child?.id || null, now());
      this.audit(id, 'character_created', POLICY);
      this.db.exec('COMMIT');
      return this.state(id);
    } catch (e) { this.db.exec('ROLLBACK'); throw e; }
  }
}
