# Publish checklist

Run Check-Package.cmd before making a ZIP or publishing a repository.

Confirm all items:

- data, logs, state, release, models, reference-audio, outputs, and .tools are absent
- no audio files or model weight files are in the package
- config\local-runtime.psd1 is absent; only its example is included
- no AppSecret, API key, VPN token, or web hook is in documentation or screenshots
- no proprietary character visuals, scripts, recordings, or model weights are included
- the recipient understands that they need their own QQ bot, providers, and authorized assets
