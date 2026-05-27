# Security Policy

Thanks for helping keep Minimal and its users safe.

## Reporting a vulnerability

**Please do not file security issues as public GitHub issues, discussions, or pull requests.**

Instead, email **security@minimal.dev** with:

- A description of the issue and the impact you believe it has.
- Steps to reproduce, or a proof-of-concept, if you have one.
- The affected package(s), version(s), and commit SHA if known.
- Your name or handle if you'd like to be credited once the issue is resolved.

If you'd like to encrypt your report, mention that in your first email and we'll coordinate a key exchange.

## What to expect

- **Acknowledgement:** within 5 business days of your initial email.
- **Triage update:** we'll let you know whether we've reproduced the issue and our initial assessment of severity.
- **Fix and disclosure:** we'll work with you on a remediation timeline appropriate to severity, and coordinate public disclosure once a fix is available. We're happy to credit reporters in the disclosure unless you'd prefer to remain anonymous.

## Scope

This policy covers:

- The package build declarations in this repository (`packages/`, `harnesses/`).
- Repository configuration (CI workflows, issue templates, etc.).

Vulnerabilities in **upstream software** that Minimal merely packages should generally be reported to that project's maintainers first. If you believe a packaging choice we've made amplifies an upstream issue (e.g. a missing patch, an unsafe build flag, an outdated pinned version), that **is** in scope — please report it to us as described above.

## Safe harbor

We will not pursue or support legal action against researchers who:

- Make a good-faith effort to comply with this policy.
- Avoid privacy violations, destruction of data, and interruption or degradation of our services.
- Give us reasonable time to investigate and address a reported issue before any public disclosure.

Thanks again for taking the time to report responsibly.
