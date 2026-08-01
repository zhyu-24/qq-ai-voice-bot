# Optional local GPT-SoVITS

Use this module only with voice data and model weights you have the right to use.

1. Install your own GPT-SoVITS environment from its authorized source.
2. Copy config\local-runtime.psd1.example to config\local-runtime.psd1.
3. Set GsvRoot to the directory that contains api_v2.py and runtime\python.exe.
4. In AstrBot, create a self-hosted GPT-SoVITS TTS provider with base URL:
   http://host.docker.internal:9880
5. Enable TTS, select that provider as default, enable dual output, and set the trigger probability to 1.
6. Run Start-LocalBot.cmd. It starts the API before AstrBot and tries to preload the selected GPT and SoVITS weights.

Do not use 127.0.0.1 as the provider URL inside AstrBot Docker. From the container, use host.docker.internal.

Do not publicly expose port 9880 or copy model/audio files into this template.
