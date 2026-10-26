import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { localVault } from './vault.mjs';
import { Persona } from './providers.mjs';
// Invoked by the operator's secure prompt; credentials arrive through stdin only.
const input = JSON.parse(readFileSync(0, 'utf8').replace(/^\uFEFF/, ''));
const directory = process.env.YIYU_DATA_DIR || join(process.env.LOCALAPPDATA, 'Yiyu', 'registration');
if (!new Persona(input).configured) throw new Error('需要正式 Persona 金鑰、itmpl_ 範本與 production 環境。');
const vault = localVault(directory);
writeFileSync(join(directory, 'persona.encrypted'), vault.seal(JSON.stringify(input), 'persona-operator'));
console.log('Persona 設定已加密保存。請重新啟動帳號服務，並完成供應商正式驗收。');
