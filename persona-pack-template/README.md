# AstrBot text persona pack

This template is used by the publisher-side exporter to create a text-only AstrBot persona pack.

The generated ZIP has exactly four files:

- `manifest.json` — package identity, compatible persona ID and SHA-256 hash
- `assets/system-prompt.md` — the text system prompt
- `README.md` — recipient instructions
- `LICENSE-AND-AUTHORIZATION.md` — distribution notice

Recipients should import the ZIP from the base project's visual **人格包** page. The base project validates the package and does not execute code from the ZIP.
