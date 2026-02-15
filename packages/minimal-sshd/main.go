package main

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/pem"
	"math/big"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"strings"
	"sync"
	"syscall"
	"unsafe"

	"crypto/x509"

	"github.com/creack/pty"
	"github.com/gliderlabs/ssh"
	gossh "golang.org/x/crypto/ssh"
)

const version = "0.1.0"

func main() {
	// Handle --help and --version before anything else to ensure clean exit codes
	for _, arg := range os.Args[1:] {
		switch arg {
		case "--help", "-h":
			fmt.Println("minimal-sshd - lightweight SSH server for dev sandboxes")
			fmt.Println()
			fmt.Println("Environment variables:")
			fmt.Println("  SSH_PORT            port to listen on (default: 2222)")
			fmt.Println("  SSH_SHELL           shell to spawn (default: /bin/sh)")
			fmt.Println("  SSH_USER            require username (auto-generated if unset)")
			fmt.Println("  SSH_PASSWORD        require password (auto-generated if unset)")
			fmt.Println("  SSH_AUTHORIZED_KEYS path to authorized_keys file for pubkey auth")
			fmt.Println("  SSH_HOST_KEY        path to PEM host key file (auto-generated if unset)")
			os.Exit(0)
		case "--version", "-v":
			fmt.Println("minimal-sshd", version)
			os.Exit(0)
		}
	}

	port := envOr("SSH_PORT", "2222")
	shell := envOr("SSH_SHELL", "/bin/sh")

	srv := &ssh.Server{
		Addr: ":" + port,
		Handler: func(s ssh.Session) {
			handleSession(s, shell)
		},
	}

	// Configure authentication
	user := os.Getenv("SSH_USER")
	password := os.Getenv("SSH_PASSWORD")
	authKeysPath := os.Getenv("SSH_AUTHORIZED_KEYS")

	// Auto-generate credentials if none configured
	if user == "" && password == "" && authKeysPath == "" {
		user = generateRandomString(6)
		password = generateRandomString(12)
		log.Printf("generated demo credentials — user: %s  password: %s", user, password)
	}

	if password != "" {
		srv.PasswordHandler = func(ctx ssh.Context, pass string) bool {
			userOk := user == "" || ctx.User() == user
			return userOk && pass == password
		}
	}

	if authKeysPath != "" {
		authorizedKeys := loadAuthorizedKeys(authKeysPath)
		if authorizedKeys != nil {
			srv.PublicKeyHandler = func(ctx ssh.Context, key ssh.PublicKey) bool {
				if user != "" && ctx.User() != user {
					return false
				}
				for _, ak := range authorizedKeys {
					if ssh.KeysEqual(key, ak) {
						return true
					}
				}
				return false
			}
		}
	}

	// Generate or load host key
	hostKeyPath := os.Getenv("SSH_HOST_KEY")
	if hostKeyPath != "" {
		data, err := os.ReadFile(hostKeyPath)
		if err != nil {
			log.Fatalf("failed to read host key %s: %v", hostKeyPath, err)
		}
		signer, err := gossh.ParsePrivateKey(data)
		if err != nil {
			log.Fatalf("failed to parse host key: %v", err)
		}
		srv.AddHostKey(signer)
	} else {
		signer := generateHostKey()
		srv.AddHostKey(signer)
	}

	log.Printf("minimal-sshd %s listening on :%s (shell=%s)", version, port, shell)
	if user != "" {
		log.Printf("ssh %s@localhost -p %s", user, port)
	}
	log.Fatal(srv.ListenAndServe())
}

func handleSession(s ssh.Session, shell string) {
	cmd := s.Command()

	ptyReq, winCh, isPty := s.Pty()
	if isPty {
		// PTY session: spawn shell with pseudo-terminal
		args := []string{"-l"}
		c := exec.Command(shell, args...)
		c.Env = append(s.Environ(),
			"TERM="+ptyReq.Term,
			"SHELL="+shell,
		)

		ptmx, err := pty.Start(c)
		if err != nil {
			fmt.Fprintf(s.Stderr(), "failed to start pty: %v\n", err)
			s.Exit(1)
			return
		}
		defer ptmx.Close()

		// Handle window resize
		go func() {
			for win := range winCh {
				setWinsize(ptmx, win.Width, win.Height)
			}
		}()

		// Set initial window size
		setWinsize(ptmx, ptyReq.Window.Width, ptyReq.Window.Height)

		// Copy data between SSH session and PTY
		var wg sync.WaitGroup
		wg.Add(2)
		go func() {
			defer wg.Done()
			io.Copy(ptmx, s) // stdin -> pty
		}()
		go func() {
			defer wg.Done()
			io.Copy(s, ptmx) // pty -> stdout
		}()

		if err := c.Wait(); err != nil {
			if exitErr, ok := err.(*exec.ExitError); ok {
				s.Exit(exitErr.ExitCode())
				return
			}
		}
		wg.Wait()
		s.Exit(0)
	} else {
		// Non-PTY session: execute command directly
		var c *exec.Cmd
		if len(cmd) > 0 {
			c = exec.Command(shell, "-c", strings.Join(cmd, " "))
		} else {
			c = exec.Command(shell, "-l")
		}
		c.Env = append(s.Environ(), "SHELL="+shell)

		c.Stdin = s
		c.Stdout = s
		c.Stderr = s.Stderr()

		if err := c.Run(); err != nil {
			if exitErr, ok := err.(*exec.ExitError); ok {
				s.Exit(exitErr.ExitCode())
				return
			}
			fmt.Fprintf(s.Stderr(), "failed to run command: %v\n", err)
			s.Exit(1)
			return
		}
		s.Exit(0)
	}
}

func generateHostKey() gossh.Signer {
	_, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		log.Fatalf("failed to generate host key: %v", err)
	}

	privBytes, err := x509.MarshalPKCS8PrivateKey(priv)
	if err != nil {
		log.Fatalf("failed to marshal host key: %v", err)
	}

	pemBlock := pem.EncodeToMemory(&pem.Block{
		Type:  "PRIVATE KEY",
		Bytes: privBytes,
	})

	signer, err := gossh.ParsePrivateKey(pemBlock)
	if err != nil {
		log.Fatalf("failed to parse generated host key: %v", err)
	}

	log.Printf("generated Ed25519 host key (fingerprint: %s)", gossh.FingerprintSHA256(signer.PublicKey()))
	return signer
}

func loadAuthorizedKeys(path string) []ssh.PublicKey {
	data, err := os.ReadFile(path)
	if err != nil {
		log.Printf("WARNING: failed to read authorized_keys %s: %v", path, err)
		return nil
	}

	var keys []ssh.PublicKey
	for len(data) > 0 {
		key, _, _, rest, err := gossh.ParseAuthorizedKey(data)
		if err != nil {
			break
		}
		keys = append(keys, key)
		data = rest
	}

	log.Printf("loaded %d authorized keys from %s", len(keys), path)
	return keys
}

func setWinsize(f *os.File, w, h int) {
	syscall.Syscall(syscall.SYS_IOCTL, f.Fd(), uintptr(syscall.TIOCSWINSZ),
		uintptr(unsafe.Pointer(&struct{ h, w, x, y uint16 }{uint16(h), uint16(w), 0, 0})))
}

const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

func generateRandomString(length int) string {
	b := make([]byte, length)
	for i := range b {
		n, err := rand.Int(rand.Reader, big.NewInt(int64(len(charset))))
		if err != nil {
			log.Fatalf("failed to generate random string: %v", err)
		}
		b[i] = charset[n.Int64()]
	}
	return string(b)
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
