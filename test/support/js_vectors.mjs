import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const M = require('../../reference/mesh-core.js');
const H = M.toHex;
const out = {};
const netKey = '00112233445566778899aabbccddeeff', appKey = '0f1e2d3c4b5a69788796a5b4c3d2e1f0';
const net = await M.deriveNet(netKey, appKey);
out.net = { nid: net.nid, encKey: H(net.encKey), privKey: H(net.privKey), networkId: H(net.networkId), aid: net.aid };
// app-key unsegmented access (CTL set)
let s = 1000;
const a1 = await M.buildAccessSegments(net, { seqs: () => s++, src: 1, dst: 0x10, iv: 0, access: M.hex('825f3412c8150000 07'.replace(/ /g,'')) });
out.appAccess = a1.pdus.map(p => ({ seq: p.seq, transport: H(p.transport) }));
out.appNet = H(await M.buildNetworkPdu(net, { ctl:0, ttl:7, seq:a1.pdus[0].seq, src:1, dst:0x10, transport:a1.pdus[0].transport, iv:0 }));
// dev-key segmented (AppKey Add)
const devKey = M.hex('a1a2a3a4a5a6a7a8a9aaabacadaeafb0');
s = 5000;
const a2 = await M.buildAccessSegments({ devKey }, { seqs: () => s++, src: 1, dst: 0x10, iv: 0x12345678, access: M.cat([0,0,0,0], M.hex(appKey)) });
out.devSeg = a2.pdus.map(p => ({ seq: p.seq, transport: H(p.transport) }));
out.devSegResend = a2.resend().map(p => ({ seq: p.seq, transport: H(p.transport) }));
out.devSegNet = [];
for (const p of a2.pdus) out.devSegNet.push(H(await M.buildNetworkPdu(net, { ctl:0, ttl:7, seq:p.seq, src:1, dst:0x10, transport:p.transport, iv:0x12345678 })));
// proxy config
out.proxyCfg = H(await M.buildNetworkPdu(net, { ctl:1, ttl:0, seq:42, src:1, dst:0, transport:M.hex('0001'), iv:0, proxy:true }));
// provisioning math
const secret = M.hex('ab'.repeat(32)), inputs = M.hex('05' + '01'.repeat(11) + '00'.repeat(5) + '11'.repeat(64) + '22'.repeat(64));
const ck = await M.Prov.confirmationKey(secret, inputs);
const randP = M.hex('33'.repeat(16)), randD = M.hex('44'.repeat(16));
const ses = await M.Prov.session(secret, ck.salt, randP, randD);
out.prov = { salt: H(ck.salt), key: H(ck.key), conf: H(await M.Prov.confirmation(ck.key, randP, new Uint8Array(16))),
  sessionKey: H(ses.key), nonce: H(ses.nonce), devKey: H(ses.devKey),
  data: H(await M.ccmEncrypt(ses.key, ses.nonce, M.cat(M.hex(netKey), [0,0],[0], M.be(0,4), M.be(0x10,2)), 8)) };
out.chunks = M.proxyChunks(3, M.hex('03' + '55'.repeat(64)), 20).map(H);
console.log(JSON.stringify(out, null, 1));
