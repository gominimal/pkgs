// lib/Probe.java: the JDK probe. Compiled once per run with javac.
//   java Probe live    URL TIMEOUT_S
//   java Probe offline CHAIN.pem EPOCH_S [ROOTS.pem]
//
// offline runs the JDK's own PKIX CertPathBuilder against the default JSSE
// trust store (javax.net.ssl.trustStore, else jssecacerts, else cacerts), at a
// pinned instant, revocation off. The builder applies lib/security/blocked.certs
// (UntrustedCertificates) and jdk.certpath.disabledAlgorithms, the same checks
// the TLS trust manager runs. It does not apply jdk.security.caDistrustPolicies,
// which are TLS-only date cut-offs (none is used for this incident).
// With ROOTS.pem the trust anchors are exactly that file, which isolates
// blocked.certs (the java-blocklist row).
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
      p = new PKIXBuilderParameters(defaultTrustStore(), target);
    }
    p.setRevocationEnabled(false);
    p.setDate(new Date(epoch * 1000));
    p.addCertStore(CertStore.getInstance("Collection", new CollectionCertStoreParameters(chain)));
    try {
      PKIXCertPathBuilderResult r = (PKIXCertPathBuilderResult) CertPathBuilder.getInstance("PKIX").build(p);
      System.out.println("@@ACCEPTED@@ anchored at " + r.getTrustAnchor().getTrustedCert().getSubjectX500Principal());
    } catch (CertPathBuilderException e) {
      String why = causes(e);
      System.out.println(why);
      // Expiry or a malformed chain is not a trust decision.
      if (!why.matches("(?is).*(expired|not yet valid|validity|parsing).*")) System.out.println("@@REJECTED@@");
    }
  }

  // The JSSE default: javax.net.ssl.trustStore, else jssecacerts, else cacerts.
  static KeyStore defaultTrustStore() throws Exception {
    String sep = File.separator, home = System.getProperty("java.home");
    String path = System.getProperty("javax.net.ssl.trustStore");
    if (path == null) {
      File jsse = new File(home + sep + "lib" + sep + "security" + sep + "jssecacerts");
      path = jsse.exists() ? jsse.getPath() : home + sep + "lib" + sep + "security" + sep + "cacerts";
    }
    KeyStore ks = KeyStore.getInstance(new File(path), (char[]) null);
    System.out.println("trust store: " + path + " (" + ks.size() + " entries)");
    return ks;
  }

  static String causes(Throwable e) {
    StringBuilder sb = new StringBuilder();
    for (Throwable x = e; x != null; x = x.getCause()) sb.append(x.getClass().getName()).append(": ").append(x.getMessage()).append(" | ");
    return sb.toString();
  }
}
