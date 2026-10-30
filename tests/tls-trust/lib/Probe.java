// lib/Probe.java: the JDK probe. Compiled once per run with javac.
//   java Probe live    URL TIMEOUT_S
//   java Probe offline CHAIN.pem EPOCH_S [ROOTS.pem]
//
// offline runs the JDK's own PKIX CertPathBuilder against the default JSSE
// trust store (javax.net.ssl.trustStore, else jssecacerts, else cacerts), at a
// pinned instant, revocation off. The builder applies lib/security/blocked.certs
// (UntrustedCertificates) and jdk.certpath.disabledAlgorithms, the same checks
// the TLS trust manager runs. It does not apply jdk.security.caDistrustPolicies,
// which are TLS-only date cut-offs (none is used for this response).
// With ROOTS.pem the trust anchors are exactly that file, which isolates
// blocked.certs (the java-blocklist row).
//
// REJECTED is a TRUST refusal, never "the builder found no path". The builder
// reduces every failed candidate path to "unable to find valid certification
// path to requested target", whatever the reason, so on a builder failure the
// captured chain is re-run through the PKIX CertPathValidator with the same
// anchors and date, and only NO_TRUST_ANCHOR or blocked.certs' "Untrusted
// certificate" mark REJECTED. Algorithm constraints, expiry and basic
// constraints are ERR, as in the Go probe and lib/common.sh.
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.net.URI;
import java.security.KeyStore;
import java.security.cert.*;
import java.util.*;
import javax.net.ssl.HttpsURLConnection;

public class Probe {
  public static void main(String[] a) throws Exception {
    if (a[0].equals("live")) live(a[1], Double.parseDouble(a[2]));
    else offline(a[1], Long.parseLong(a[2]), a.length > 3 ? a[3] : null);
  }

  static void live(String url, double t) {
    try {
      HttpsURLConnection c = (HttpsURLConnection) new URI(url).toURL().openConnection();
      c.setConnectTimeout((int) (t * 1000)); c.setReadTimeout((int) (t * 1000));
      System.out.println("@@CONNECTED@@ HTTP " + c.getResponseCode());
    } catch (Throwable e) { System.out.println("FAIL " + causes(e)); }
  }

  static List<X509Certificate> load(String file) throws Exception {
    List<X509Certificate> out = new ArrayList<>();
    try (InputStream in = new FileInputStream(file)) {
      for (Certificate c : CertificateFactory.getInstance("X.509").generateCertificates(in)) out.add((X509Certificate) c);
    }
    return out;
  }

  static void offline(String chainFile, long epoch, String rootsFile) throws Exception {
    List<X509Certificate> chain = load(chainFile);
    X509CertSelector target = new X509CertSelector();
    target.setCertificate(chain.get(0));
    PKIXBuilderParameters p;
    if (rootsFile != null) {
      Set<TrustAnchor> anchors = new HashSet<>();
      for (X509Certificate r : load(rootsFile)) anchors.add(new TrustAnchor(r, null));
      System.out.println("trust anchors: " + rootsFile + " (" + anchors.size() + ")");
      p = new PKIXBuilderParameters(anchors, target);
    } else {
      p = new PKIXBuilderParameters(defaultTrustStore(true), target);
    }
    p.setRevocationEnabled(false);
    p.setDate(new Date(epoch * 1000));
    p.addCertStore(CertStore.getInstance("Collection", new CollectionCertStoreParameters(chain)));
    try {
      PKIXCertPathBuilderResult r = (PKIXCertPathBuilderResult) CertPathBuilder.getInstance("PKIX").build(p);
      System.out.println("@@ACCEPTED@@ anchored at " + r.getTrustAnchor().getTrustedCert().getSubjectX500Principal());
    } catch (CertPathBuilderException e) {
      System.out.println(causes(e));
      String verdict = validatorVerdict(chain, rootsFile, epoch);
      System.out.println("validator: " + verdict);
      if (verdict.startsWith("TRUST")) System.out.println("@@REJECTED@@");
    }
  }

  // Why the chain fails, from the validator: "TRUST ..." for a trust refusal
  // (no trust anchor, or a blocked.certs entry), "OTHER ..." for anything else.
  static String validatorVerdict(List<X509Certificate> chain, String rootsFile, long epoch) {
    try {
      List<X509Certificate> path = new ArrayList<>(chain);
      X509Certificate last = path.get(path.size() - 1);
      // A CertPath excludes the trust anchor: drop a trailing self-signed root.
      if (path.size() > 1 && last.getSubjectX500Principal().equals(last.getIssuerX500Principal())) {
        path.remove(path.size() - 1);
      }
      PKIXParameters p;
      if (rootsFile != null) {
        Set<TrustAnchor> anchors = new HashSet<>();
        for (X509Certificate r : load(rootsFile)) anchors.add(new TrustAnchor(r, null));
        p = new PKIXParameters(anchors);
      } else {
        p = new PKIXParameters(defaultTrustStore(false));
      }
      p.setRevocationEnabled(false);
      p.setDate(new Date(epoch * 1000));
      CertPath cp = CertificateFactory.getInstance("X.509").generateCertPath(path);
      CertPathValidator.getInstance("PKIX").validate(cp, p);
      return "OTHER the builder failed but the captured chain validates";
    } catch (CertPathValidatorException v) {
      CertPathValidatorException.Reason r = v.getReason();
      String msg = String.valueOf(v.getMessage());
      if (r == PKIXReason.NO_TRUST_ANCHOR || msg.contains("Untrusted certificate")) {
        return "TRUST " + r + ": " + msg;
      }
      return "OTHER " + r + ": " + msg;
    } catch (Exception x) {
      return "OTHER " + causes(x);
    }
  }

  // The JSSE default: javax.net.ssl.trustStore, else jssecacerts, else cacerts.
  static KeyStore defaultTrustStore(boolean announce) throws Exception {
    String sep = File.separator, home = System.getProperty("java.home");
    String path = System.getProperty("javax.net.ssl.trustStore");
    if (path == null) {
      File jsse = new File(home + sep + "lib" + sep + "security" + sep + "jssecacerts");
      path = jsse.exists() ? jsse.getPath() : home + sep + "lib" + sep + "security" + sep + "cacerts";
    }
    KeyStore ks = KeyStore.getInstance(new File(path), (char[]) null);
    if (announce) System.out.println("trust store: " + path + " (" + ks.size() + " entries)");
    return ks;
  }

  static String causes(Throwable e) {
    StringBuilder sb = new StringBuilder();
    for (Throwable x = e; x != null; x = x.getCause()) sb.append(x.getClass().getName()).append(": ").append(x.getMessage()).append(" | ");
    return sb.toString();
  }
}
