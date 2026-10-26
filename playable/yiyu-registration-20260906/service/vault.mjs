import { randomBytes, createCipheriv, createDecipheriv, createHmac } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

// Only a protected master key reaches disk. Secrets never appear in child arguments.
function dpapi(bytes, decrypt = false) {
  if (process.platform !== 'win32') throw new Error('Windows DPAPI is required by the local build');
  const script = `Add-Type -AssemblyName System.Security; $b=[Convert]::FromBase64String([Console]::In.ReadToEnd()); $v=[Security.Cryptography.ProtectedData]::${decrypt ? 'Unprotect' : 'Protect'}($b,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser); [Console]::Out.Write([Convert]::ToBase64String($v))`;
  const p = spawnSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-EncodedCommand', Buffer.from(script, 'utf16le').toString('base64')], { input: bytes.toString('base64'), encoding: 'utf8', windowsHide: true, timeout: 15000 });
  if (p.status !== 0) throw new Error('Windows secret protection failed');
  return Buffer.from(p.stdout.trim(), 'base64');
}

export class Vault {
  constructor(key) {
    if (!Buffer.isBuffer(key) || key.length !== 32) throw new Error('Invalid vault key');
    this.key = key;
  }
  seal(value, owner) {
    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.key, iv);
    cipher.setAAD(Buffer.from(owner));
    const body = Buffer.concat([cipher.update(value, 'utf8'), cipher.final()]);
    return Buffer.concat([iv, cipher.getAuthTag(), body]).toString('base64');
  }
  open(value, owner) {
    const bytes = Buffer.from(value, 'base64');
    const decipher = createDecipheriv('aes-256-gcm', this.key, bytes.subarray(0, 12));
    decipher.setAAD(Buffer.from(owner));
    decipher.setAuthTag(bytes.subarray(12, 28));
    return Buffer.concat([decipher.update(bytes.subarray(28)), decipher.final()]).toString('utf8');
  }
  fingerprint(value) { return createHmac('sha256', this.key).update('identity:v1:' + value).digest('hex'); }
}

export function localVault(directory) {
  mkdirSync(directory, { recursive: true });
  const path = join(directory, 'master.dpapi');
  if (!existsSync(path)) writeFileSync(path, dpapi(randomBytes(32)), { flag: 'wx' });
  return new Vault(dpapi(readFileSync(path), true));
}
