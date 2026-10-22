// CVE-2026-111943 (eMudhra intermediate key compromise): build-time helper for the JDK
// packages, run by cve-2026-111943.sh with the JDK being packaged (single-file source
// launch, JDK 17+). Upstream OpenJDK and Temurin have not shipped a fix yet.
//
//   remove-anchors <cacerts> <sha256>...  delete every trusted entry whose certificate has one
//                                         of these SHA-256 fingerprints (selected by
//                                         fingerprint, not alias: Temurin and OpenJDK name
//                                         the same root differently), rewrite the store
//                                         password-less as it was, reload it and require it to
//                                         equal the original minus exactly those entries.
//   check pre|post <fixtures.pem> <state> validate each compromised-intermediate fixture
//                                         against its issuer with PKIX. `pre` runs on the stock
//                                         blocked.certs and requires the encodings a verifier
//                                         accepts to VALIDATE, so the harness is known to work;
//                                         `post` runs after the append and requires every one
//                                         to be rejected, and the ones that validated in `pre`
//                                         to be rejected as "Untrusted certificate" (that is,
//                                         by lib/security/blocked.certs and nothing else).
//                                         Both phases also validate an unrelated control chain,
//                                         and `post` checks the default trust manager no
//                                         longer offers the removed roots.
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyStore;
import java.security.MessageDigest;
import java.security.cert.CertPath;
import java.security.cert.CertPathValidator;
import java.security.cert.CertificateFactory;
import java.security.cert.PKIXParameters;
import java.security.cert.TrustAnchor;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.Base64;
import java.util.Collections;
import java.util.Date;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.Set;
import javax.net.ssl.TrustManager;
import javax.net.ssl.TrustManagerFactory;
import javax.net.ssl.X509TrustManager;

public class JdkDistrust {
    static final String AAA_ROOT = "D7A7A0FB5D7E2731D771E9484EBCDEF71D5F0C3E0A2948782BC83EE0EA699EF4";
    static final String ECC_G3 = "86A1ECBA089C4A8D3BBE2734C612BA341D813E043CF9E8A862CD5C57A36BBE6B";
    // emSign Root TLS CA - G3 cross-certified by emSign ECC Root CA - G3 (not revoked, not blocked)
    static final String CROSS = "3094025792039A68AF6E553686410BDAB7C0D4A36B9084CBA64202E35D6EBBDD";

    // EM DV TLS CA - G3C, both certificates of the key, in every blocked encoding:
    // { fingerprint, issuer anchor, label }
    static final String[][] COMPROMISED = {
        {"62B7F9868263F72F6911FC78CEAF72C1979158B7368BF648683BB2AA39B02E72", AAA_ROOT, "aaa-signed"},
        {"D8A50FA0068E9558E6C3BEE18CDB03B7EECBC3C56C1B2336B98AEE11644994B8", AAA_ROOT, "aaa-signed-algnull"},
        {"0164D7CEAE5BB909C272AF151FF44B1177AE9B47D9424B94F1D9558C30934D19", CROSS, "emsign-signed"},
        {"A4B72DBD37256324B557B9176F8CBA4310DDFFBCC4609977E2463F3504A716C8", CROSS, "emsign-signed-malleated"},
        {"59CC5FD35A737B84682EDA26AD23F5ADE8AA847D5BEB3B38AB6CD62347925A66", CROSS, "emsign-signed-algnull"},
        {"A0ED2032C5249EE1A653F1F88005D9E779E385DF533B5C521137CEE5176CD7FC", CROSS, "emsign-signed-algnull-malleated"},
    };
    // The encodings that must validate on a stock JDK (OpenSSL 3 accepts these three too; it
    // rejects the algnull ones, whose outer signatureAlgorithm no longer matches the TBS).
    static final Set<String> MUST_VALIDATE_BEFORE = Set.of(COMPROMISED[0][0], COMPROMISED[2][0], COMPROMISED[3][0]);

    // Fixed validation time: the builder's clock must not decide whether a fixture expired.
    static final Date AT = new Date(1792454400000L); // 2026-10-20T00:00:00Z

    static final Map<String, String> parseErrors = new LinkedHashMap<>();

    public static void main(String[] args) throws Exception {
        if (args.length >= 3 && args[0].equals("remove-anchors")) {
            removeAnchors(Path.of(args[1]), List.of(args).subList(2, args.length));
        } else if (args.length == 4 && args[0].equals("check") && (args[1].equals("pre") || args[1].equals("post"))) {
            check(args[1], Path.of(args[2]), Path.of(args[3]));
        } else {
            die("usage: remove-anchors <cacerts> <sha256>... | check pre|post <fixtures.pem> <state>");
        }
    }

    static void die(String m) {
        System.err.println("JdkDistrust: FAIL: " + m);
        System.exit(1);
    }

    static String fp(byte[] der) throws Exception {
        return HexFormat.of().withUpperCase().formatHex(MessageDigest.getInstance("SHA-256").digest(der));
    }

    static Map<String, String> entries(KeyStore ks) throws Exception {
        Map<String, String> m = new LinkedHashMap<>();
        for (String alias : Collections.list(ks.aliases())) {
            if (!ks.isCertificateEntry(alias)) die("cacerts entry is not a trusted certificate: " + alias);
            m.put(alias, fp(ks.getCertificate(alias).getEncoded()));
        }
        return m;
    }

    static void removeAnchors(Path cacerts, List<String> fps) throws Exception {
        for (String f : fps) if (!f.matches("[0-9A-F]{64}")) die("not an uppercase SHA-256 fingerprint: " + f);
        KeyStore ks = KeyStore.getInstance("PKCS12");
        try (InputStream in = Files.newInputStream(cacerts)) { ks.load(in, null); }
        Map<String, String> before = entries(ks);
        if (before.size() < 80) die("cacerts loaded only " + before.size() + " entries");
        Map<String, String> expected = new LinkedHashMap<>(before);
        for (String f : fps) {
            List<String> hit = new ArrayList<>();
            for (Map.Entry<String, String> e : before.entrySet()) if (e.getValue().equals(f)) hit.add(e.getKey());
            for (String alias : hit) {
                ks.deleteEntry(alias);
                expected.remove(alias);
                System.out.println("JdkDistrust: removed " + f + " (alias \"" + alias + "\")");
            }
            if (hit.isEmpty()) System.out.println("JdkDistrust: not present " + f);
        }
        Path tmp = cacerts.resolveSibling(cacerts.getFileName() + ".new");
        // Loaded password-less, so the store keeps certProtection/MAC = NONE: no salt, no
        // randomness, and the default trust manager still reads it without a password.
        try (OutputStream o = Files.newOutputStream(tmp)) { ks.store(o, null); }
        KeyStore re = KeyStore.getInstance("PKCS12");
        try (InputStream in = Files.newInputStream(tmp)) { re.load(in, null); }
        Map<String, String> after = entries(re);
        if (!after.equals(expected)) {
            die("rewritten cacerts is not the original minus the removed roots: " + before.size()
                + " before, " + after.size() + " after, " + expected.size() + " expected");
        }
        Files.write(cacerts, Files.readAllBytes(tmp)); // in place: keep the file's mode
        Files.delete(tmp);
        System.out.println("JdkDistrust: cacerts " + before.size() + " -> " + after.size() + " entries");
    }

    static Map<String, X509Certificate> readPem(Path p) throws Exception {
        CertificateFactory cf = CertificateFactory.getInstance("X.509");
        Map<String, X509Certificate> m = new LinkedHashMap<>();
        StringBuilder b = null;
        for (String line : Files.readAllLines(p, StandardCharsets.US_ASCII)) {
            if (line.equals("-----BEGIN CERTIFICATE-----")) { b = new StringBuilder(); continue; }
            if (line.equals("-----END CERTIFICATE-----")) {
                byte[] der = Base64.getMimeDecoder().decode(b.toString());
                String f = fp(der); // the bytes as committed: what blocked.certs has to match
                try {
                    m.put(f, (X509Certificate) cf.generateCertificate(new ByteArrayInputStream(der)));
                } catch (Exception e) {
                    m.put(f, null); // this JDK refuses the encoding outright: record why
                    parseErrors.put(f, e.toString());
                }
                b = null;
                continue;
            }
            if (b != null) b.append(line);
        }
        return m;
    }

    static X509Certificate need(Map<String, X509Certificate> fx, String f) {
        X509Certificate c = fx.get(f);
        if (c == null) die("fixture missing or unparseable: " + f + " " + parseErrors.getOrDefault(f, ""));
        return c;
    }

    static String validate(X509Certificate anchor, X509Certificate target) {
        try {
            CertPath path = CertificateFactory.getInstance("X.509").generateCertPath(List.of(target));
            PKIXParameters p = new PKIXParameters(Set.of(new TrustAnchor(anchor, null)));
            p.setRevocationEnabled(false); // offline; the point is the static blocklist
            p.setDate(AT);
            CertPathValidator.getInstance("PKIX").validate(path, p);
            return null;
        } catch (Exception e) {
            return e.getClass().getSimpleName() + ": " + e.getMessage();
        }
    }

    static void check(String phase, Path fixtures, Path state) throws Exception {
        Map<String, X509Certificate> fx = readPem(fixtures);
        X509Certificate aaa = need(fx, AAA_ROOT), g3 = need(fx, ECC_G3), cross = need(fx, CROSS);
        String ctl = validate(g3, cross);
        if (ctl != null) die(phase + ": control chain (emSign Root TLS CA - G3 cross <- emSign ECC Root CA - G3) did not validate: " + ctl);
        System.out.println("JdkDistrust: " + phase + " control -> VALID");

        Properties before = new Properties();
        if (phase.equals("post")) try (InputStream in = Files.newInputStream(state)) { before.load(in); }
        Properties now = new Properties();
        for (String[] c : COMPROMISED) {
            if (!fx.containsKey(c[0])) die("fixture missing: " + c[2] + " " + c[0]);
            X509Certificate t = fx.get(c[0]);
            String r = t == null ? "unparseable: " + parseErrors.get(c[0]) : validate(c[1].equals(AAA_ROOT) ? aaa : cross, t);
            System.out.println("JdkDistrust: " + phase + " " + c[2] + " " + c[0] + " -> " + (r == null ? "VALID" : r));
            now.setProperty(c[0], r == null ? "VALID" : "REJECTED");
            if (phase.equals("pre")) {
                if (MUST_VALIDATE_BEFORE.contains(c[0]) && r != null) {
                    die("pre: " + c[2] + " must validate on the stock JDK (fixture or harness broken): " + r);
                }
            } else {
                if (r == null) die("post: " + c[2] + " still validates");
                String was = before.getProperty(c[0]);
                if (was == null) die("post: no pre-phase result for " + c[2]);
                if (was.equals("VALID") && !r.contains("Untrusted certificate")) {
                    die("post: " + c[2] + " rejected, but not by blocked.certs: " + r);
                }
            }
        }
        if (phase.equals("pre")) {
            try (OutputStream o = Files.newOutputStream(state)) { now.store(o, null); }
            return;
        }

        TrustManagerFactory tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
        tmf.init((KeyStore) null); // the JDK's own default: lib/security/cacerts
        X509TrustManager tm = null;
        for (TrustManager m : tmf.getTrustManagers()) if (m instanceof X509TrustManager x) tm = x;
        if (tm == null) die("post: no default X509TrustManager");
        X509Certificate[] issuers = tm.getAcceptedIssuers();
        if (issuers.length < 80) die("post: default trust manager offers only " + issuers.length + " roots");
        for (X509Certificate i : issuers) {
            String f = fp(i.getEncoded());
            if (f.equals(ECC_G3) || f.equals(AAA_ROOT)) die("post: default trust manager still trusts " + f);
        }
        System.out.println("JdkDistrust: post default trust manager: " + issuers.length + " roots, neither emSign ECC Root CA - G3 nor AAA Certificate Services");
    }
}
