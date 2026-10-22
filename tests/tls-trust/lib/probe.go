// lib/probe.go: the Go probe. Built once per run with the box's go.
//
//	probe live    URL TIMEOUT_S
//	probe offline CHAIN.pem EPOCH_S [ROOTS.pem]
//
// offline calls x509.Certificate.Verify with Roots == nil (the system pool,
// exactly what crypto/tls uses), ServerAuth EKU and a pinned CurrentTime.
// That includes Go's built-in distrusted-SPKI list, so it proves the whole
// verifier, not just the store. With ROOTS.pem the pool is exactly that file,
// which isolates the distrusted-SPKI list (the go-blocklist row).
package main

import (
	"crypto/x509"
	"encoding/pem"
	"errors"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"time"
)

func main() {
	if os.Args[1] == "live" {
		s, _ := strconv.ParseFloat(os.Args[3], 64)
		c := &http.Client{Timeout: time.Duration(s * float64(time.Second))}
		r, err := c.Get(os.Args[2])
		if err != nil {
			fmt.Println("FAIL", err)
			return
		}
		r.Body.Close()
		fmt.Println("@@CONNECTED@@ HTTP", r.StatusCode)
		return
	}
	data, err := os.ReadFile(os.Args[2])
	if err != nil {
		fmt.Println("read:", err)
		return
	}
	epoch, _ := strconv.ParseInt(os.Args[3], 10, 64)
	var chain []*x509.Certificate
	for {
		var b *pem.Block
		if b, data = pem.Decode(data); b == nil {
			break
		}
		if c, err := x509.ParseCertificate(b.Bytes); err == nil {
			chain = append(chain, c)
		}
	}
	if len(chain) == 0 {
		fmt.Println("no certificates in chain file")
		return
	}
	inter := x509.NewCertPool()
	for _, c := range chain[1:] {
		inter.AddCert(c)
	}
	var roots *x509.CertPool
	if len(os.Args) > 4 {
		pemRoots, err := os.ReadFile(os.Args[4])
		if err != nil {
			fmt.Println("read roots:", err)
			return
		}
		roots = x509.NewCertPool()
		roots.AppendCertsFromPEM(pemRoots)
	}
	_, err = chain[0].Verify(x509.VerifyOptions{
		Roots:         roots,
		Intermediates: inter,
		CurrentTime:   time.Unix(epoch, 0),
		KeyUsages:     []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
	})
	if err == nil {
		fmt.Println("@@ACCEPTED@@")
		return
	}
	fmt.Println(err)
	// Decide on the error TYPE, never its text. Only two outcomes are trust
	// refusals (crypto/x509 verify.go, go1.27.3):
	//   - UnknownAuthorityError: no path to a root in the pool.
	//   - CertificateInvalidError{NoValidChains} with an EMPTY Detail: chains
	//     were built to a trusted root and every one was then dropped by
	//     containsDistrustedSPKIHash, the only filter that drops silently.
	//     Policy and EKU drops fill Detail (or return IncompatibleUsage), and a
	//     name-constraint drop returns CANotAuthorizedForThisName.
	// Everything else (expiry, EKU, policy, constraints, hostname, parse) is
	// not a trust decision and stays unmarked, so it classifies as ERR.
	var ua x509.UnknownAuthorityError
	var ci x509.CertificateInvalidError
	switch {
	case errors.As(err, &ua):
		fmt.Println("@@REJECTED@@ unknown authority")
	case errors.As(err, &ci) && ci.Reason == x509.NoValidChains && ci.Detail == "":
		fmt.Println("@@REJECTED@@ every built chain was dropped (distrusted SPKI)")
	case errors.As(err, &ci):
		fmt.Printf("not a trust decision (x509.InvalidReason %d)\n", ci.Reason)
	default:
		fmt.Println("not a trust decision")
	}
}
