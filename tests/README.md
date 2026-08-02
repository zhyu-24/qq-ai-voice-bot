# Isolated regression tests

These tests use generated directories, simulated secrets, tiny text placeholders for weights/audio, and no live bot services.

Run from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-Regression.ps1
```

Covered:

- strict UTF-8 reads and Chinese round trips;
- atomic `cmd_config.json` replacement and backup creation;
- malformed JSON / invalid UTF-8 rejection without secret leakage;
- failed validation preserving the original file;
- isolated fake voice-pack and persona-pack imports;
- repeated voice import refusal;
- unrelated configuration preservation;
- status-check redaction and nonzero exit;
- Setup Center parameter-bearing button wiring remaining unchanged.

The Windows-only locked-file replacement case runs only on Windows because Linux does not implement Windows file-sharing locks. No test reads the user's real `chatQQ` directory or imports real model/persona assets.
