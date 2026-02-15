package main

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/pem"
	"math/big"
	"fmt"
	"io"
	"log"
	"net"
	"os"
	"os/exec"
	"strings"
	"sync"
	"syscall"
	"unsafe"

	"crypto/x509"

	"github.com/creack/pty"
	"github.com/gliderlabs/ssh"
	"github.com/pkg/sftp"
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
		SubsystemHandlers: map[string]ssh.SubsystemHandler{
			"sftp": handleSFTP,
		},
		ConnCallback: func(ctx ssh.Context, conn net.Conn) net.Conn {
			log.Printf("[conn] new connection from %s", conn.RemoteAddr())
			return conn
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

	// checkPassword is used by both password and keyboard-interactive auth.
	checkPassword := func(ctx ssh.Context, pass string) bool {
		userOk := user == "" || ctx.User() == user
		ok := userOk && pass == password
		if ok {
			log.Printf("[auth] password accepted for user=%s", ctx.User())
		} else {
			log.Printf("[auth] password rejected for user=%s", ctx.User())
		}
		return ok
	}

	if password != "" {
		srv.PasswordHandler = func(ctx ssh.Context, pass string) bool {
			return checkPassword(ctx, pass)
		}

		// Many SSH clients (including OpenSSH and Claude Code) prefer
		// keyboard-interactive auth over plain password auth.
		srv.KeyboardInteractiveHandler = func(ctx ssh.Context, challenger gossh.KeyboardInteractiveChallenge) bool {
			answers, err := challenger("", "", []string{"Password: "}, []bool{false})
			if err != nil || len(answers) == 0 {
				log.Printf("[auth] keyboard-interactive failed for user=%s: %v", ctx.User(), err)
				return false
			}
			return checkPassword(ctx, answers[0])
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
						log.Printf("[auth] public key accepted for user=%s", ctx.User())
						return true
					}
				}
				log.Printf("[auth] public key rejected for user=%s", ctx.User())
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

// sshServerVars are environment variables used by the server itself that
// should not leak into spawned shell sessions.
var sshServerVars = map[string]bool{
	"SSH_PORT":            true,
	"SSH_SHELL":           true,
	"SSH_USER":            true,
	"SSH_PASSWORD":        true,
	"SSH_AUTHORIZED_KEYS": true,
	"SSH_HOST_KEY":        true,
}

// buildEnv constructs the environment for a spawned shell process.
// It starts with the server process's own environment (which includes
// sandbox-provided PATH, HOME, XDG_* etc.), filters out server-internal
// variables, then overlays any variables sent by the SSH client, and
// finally adds server-set overrides.
func buildEnv(base []string, overrides ...string) []string {
	env := make(map[string]string, len(base)+len(overrides))
	for _, e := range base {
		if k, v, ok := strings.Cut(e, "="); ok {
			if !sshServerVars[k] {
				env[k] = v
			}
		}
	}
	for _, e := range overrides {
		if k, v, ok := strings.Cut(e, "="); ok {
			env[k] = v
		}
	}
	result := make([]string, 0, len(env))
	for k, v := range env {
		result = append(result, k+"="+v)
	}
	return result
}

func handleSession(s ssh.Session, shell string) {
	cmd := s.Command()

	log.Printf("[session] new session: user=%s cmd=%v subsystem=%s env=%v",
		s.User(), cmd, s.Subsystem(), s.Environ())

	// Start with the server's environment (sandbox-provided PATH, HOME, etc.),
	// then overlay SSH client env vars so the client can still override.
	serverEnv := os.Environ()

	ptyReq, winCh, isPty := s.Pty()
	log.Printf("[session] pty=%v", isPty)
	if isPty {
		// PTY session: spawn shell with pseudo-terminal
		args := []string{"-l"}
		c := exec.Command(shell, args...)
		c.Env = buildEnv(serverEnv, append(s.Environ(),
			"TERM="+ptyReq.Term,
			"SHELL="+shell,
		)...)

		ptmx, err := pty.Start(c)
		if err != nil {
			fmt.Fprintf(s.Stderr(), "failed to start pty: %v\n", err)
			s.Exit(1)
			return
		}

		// Handle window resize
		go func() {
			for win := range winCh {
				setWinsize(ptmx, win.Width, win.Height)
			}
		}()

		// Set initial window size
		setWinsize(ptmx, ptyReq.Window.Width, ptyReq.Window.Height)

		// Copy data between SSH session and PTY.
		// Only wait on the output (pty→session) goroutine. The input
		// goroutine (session→pty) blocks on s.Read() which won't return
		// until the SSH client closes the channel. Waiting on it causes a
		// deadlock: the client waits for exit-status, but we can't send it
		// until wg.Wait() returns, which never happens because the client
		// hasn't closed stdin. Fire-and-forget the input side; it cleans up
		// when the session closes or the pty is closed.
		var wg sync.WaitGroup
		wg.Add(1)
		go func() {
			io.Copy(ptmx, s) // stdin -> pty (fire-and-forget)
		}()
		go func() {
			defer wg.Done()
			io.Copy(s, ptmx) // pty -> stdout
		}()

		exitCode := 0
		if err := c.Wait(); err != nil {
			if exitErr, ok := err.(*exec.ExitError); ok {
				exitCode = exitErr.ExitCode()
			}
		}

		// Close the pty master so the output goroutine gets EOF and flushes
		// remaining data to the SSH session.
		ptmx.Close()
		wg.Wait()
		s.Exit(exitCode)
	} else {
		// Non-PTY session: execute command directly
		var c *exec.Cmd
		if len(cmd) > 0 {
			c = exec.Command(shell, "-c", strings.Join(cmd, " "))
		} else {
			c = exec.Command(shell, "-l")
		}
		c.Env = buildEnv(serverEnv, append(s.Environ(),
			"SHELL="+shell,
		)...)

		// Use StdinPipe so Go's Wait() doesn't track the stdin copy
		// goroutine. Otherwise Wait() deadlocks: it waits for the
		// stdin goroutine which blocks on s.Read(), but the SSH client
		// won't close stdin until it receives exit-status from us.
		stdinPipe, err := c.StdinPipe()
		if err != nil {
			fmt.Fprintf(s.Stderr(), "failed to create stdin pipe: %v\n", err)
			s.Exit(1)
			return
		}
		c.Stdout = s
		c.Stderr = s.Stderr()

		if err := c.Start(); err != nil {
			fmt.Fprintf(s.Stderr(), "failed to start command: %v\n", err)
			s.Exit(1)
			return
		}

		go func() {
			io.Copy(stdinPipe, s)
			stdinPipe.Close()
		}()

		exitCode := 0
		if err := c.Wait(); err != nil {
			if exitErr, ok := err.(*exec.ExitError); ok {
				exitCode = exitErr.ExitCode()
			}
		}
		s.Exit(exitCode)
	}
}

func handleSFTP(s ssh.Session) {
	log.Printf("[sftp] starting SFTP subsystem for user=%s", s.User())
	server, err := sftp.NewServer(s)
	if err != nil {
		log.Printf("[sftp] failed to create server: %v", err)
		s.Exit(1)
		return
	}
	if err := server.Serve(); err != nil && err != io.EOF {
		log.Printf("[sftp] server exited with error: %v", err)
	}
	s.Exit(0)
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
