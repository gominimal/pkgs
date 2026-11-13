// lib/probe.mjs: one probe for node, bun and deno (node: APIs only).
//   probe.mjs live    URL TIMEOUT_S
//   probe.mjs offline CHAIN.pem
//
// offline: no runtime exposes its TLS verifier without a handshake, so this
// proves the ROOT-STORE half only: does the runtime's default CA list
// (tls.getCACertificates('default') when present, else tls.rootCertificates)
// contain a certificate that anchors the chain? Links are checked with
// X509Certificate.checkIssued + verify (signature). It does not check time,
// name constraints, or SPKI blocklists that only fire inside a handshake
// (node's kBlockedSPKIs). It over-approximates trust (any store member counts
// as an anchor), so it can only err towards VULNERABLE.
import tls from 'node:tls';
import fs from 'node:fs';
import process from 'node:process';
import { X509Certificate } from 'node:crypto';

const [mode, a1, a2] = process.argv.slice(2);

if (mode === 'live') {
  try {
    const r = await fetch(a1, { signal: AbortSignal.timeout(Number(a2) * 1000) });
    console.log('@@CONNECTED@@ HTTP', r.status);
  } catch (e) {
    console.log('FAIL', String(e && e.message), '|',
      String((e && e.cause && (e.cause.code || e.cause.message)) || (e && e.code) || ''));
  }
} else if (mode === 'offline') {
  const pems = (s) => s.match(/-----BEGIN CERTIFICATE-----[\s\S]+?-----END CERTIFICATE-----/g) || [];
  let api = 'tls.rootCertificates', store = tls.rootCertificates;
  if (typeof tls.getCACertificates === 'function') {
    api = "tls.getCACertificates('default')"; store = tls.getCACertificates('default');
  }
  const roots = [];
  for (const p of store) { try { roots.push(new X509Certificate(p)); } catch { /* skip unparsable */ } }
  const inStore = new Set(roots.map((r) => r.fingerprint256));
  const chain = pems(fs.readFileSync(a1, 'utf8')).map((p) => new X509Certificate(p));
  const signedBy = (c, i) => { try { return c.checkIssued(i) && c.verify(i.publicKey); } catch { return false; } };
  console.log(`store: ${api} = ${roots.length} certs; chain = ${chain.length} certs`);
  if (roots.length === 0 || chain.length === 0) { console.log('empty store or chain'); process.exit(0); }
  let cur = chain[0], anchor = null;
  for (let depth = 0; depth < 8 && cur && !anchor; depth++) {
    if (inStore.has(cur.fingerprint256)) { anchor = cur; break; }
    anchor = roots.find((r) => signedBy(cur, r)) || null;
    if (anchor) break;
    cur = chain.find((i) => i !== cur && signedBy(cur, i));
  }
  if (anchor) console.log('@@ACCEPTED@@ anchored at', anchor.subject.replace(/\n/g, ', '));
  else console.log('@@REJECTED@@ no store certificate anchors this chain (unknown issuer)');
} else {
  console.log('usage: probe.mjs live URL TIMEOUT | offline CHAIN.pem');
}
