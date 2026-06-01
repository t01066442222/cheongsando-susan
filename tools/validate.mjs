#!/usr/bin/env node
/* index.html 무결성 검증기 — 일일 갱신 후 배포 전에 실행.
   1) 필수 마커/요소 존재  2) <script> JS 문법  3) 런타임(DOM 스텁) 실행으로 FUNDS/렌더 오류 차단.
   실패 시 exit 1 → update.sh 가 백업 복원하고 배포 중단. */
import fs from 'fs';
import { execSync } from 'child_process';

const FILE = process.argv[2] || 'index.html';
const fail = (m) => { console.error('[validate] ✗ ' + m); process.exit(1); };

let s;
try { s = fs.readFileSync(FILE, 'utf8'); } catch (e) { fail('파일 읽기 실패: ' + FILE); }

// 1) 필수 마커
const need = [
  'id="tlBody"', 'id="alertText"', 'id="weeklyChecklist"', 'id="todayDate"',
  'FUND_DATA_START', 'FUND_DATA_END', 'const FUNDS', 'const META',
  'function computeRows', 'function renderTimeline', 'function renderAll'
];
for (const n of need) if (!s.includes(n)) fail('필수 마커 누락: ' + n);

// 2) <script> 문법
const m = s.match(/<script>([\s\S]*?)<\/script>/);
if (!m) fail('<script> 블록 없음');
const js = m[1];
fs.writeFileSync('/tmp/_cs_chk.js', js);
try { execSync('node --check /tmp/_cs_chk.js', { stdio: 'pipe' }); }
catch (e) { fail('JS 문법 오류: ' + (e.stderr ? e.stderr.toString() : e.message)); }

// 3) 런타임 실행 (DOM 스텁) — FUNDS 파싱/렌더 오류 잡기
const store = {};
globalThis.document = {
  getElementById: (id) => (store[id] = store[id] || { textContent: '', innerHTML: '', style: {} }),
  querySelectorAll: () => []
};
globalThis.window = { addEventListener: () => {} };
try {
  // 파일 스코프에서 함수/const 가 보이도록 분리 eval 대신 직접 실행
  const runner = new Function(js + '\n;return {FUNDS, rows: computeRows(), store: arguments[0]};');
  const out = runner(store);
  if (!Array.isArray(out.FUNDS) || out.FUNDS.length === 0) fail('FUNDS 비어있음');
  if (!Array.isArray(out.rows) || out.rows.length !== out.FUNDS.length) fail('computeRows 행 수 불일치');
  // 메인 타임라인 = 오늘부터 신청 가능(마감 안 지남 + tbd 아님)
  const applyCount = out.rows.filter(r => r.tr !== 'closed' && r.f && r.f.status !== 'tbd').length;
  const tlRows = (store['tlBody'].innerHTML.match(/tl-row/g) || []).length;
  if (tlRows === 0) fail('타임라인에 신청 가능 공고가 0건');
  if (tlRows !== applyCount) fail('타임라인 렌더 행 수 불일치 (' + tlRows + '/신청가능 ' + applyCount + ')');
  // 각 항목 필수 필드
  for (const f of out.FUNDS) {
    for (const k of ['id', 'cat', 'name', 'org', 'amount', 'status', 'when', 'links', 'action']) {
      if (!(k in f)) fail('FUNDS 항목 필드 누락: ' + (f.id || f.name || '?') + '.' + k);
    }
    if (!['op', 'fac', 'grant'].includes(f.cat)) fail('잘못된 cat: ' + f.name + ' = ' + f.cat);
    if (!['date', 'fixed', 'window', 'monthly', 'milestone', 'always', 'tbd', 'rolling', 'estimated'].includes(f.status)) fail('잘못된 status: ' + f.name + ' = ' + f.status);
  }
  console.log('[validate] ✓ OK — FUNDS ' + out.FUNDS.length + '건, 타임라인 ' + tlRows + '행 렌더 정상');
} catch (e) {
  fail('런타임 실행 오류: ' + e.message);
}
process.exit(0);
