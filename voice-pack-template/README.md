# Optional local voice pack

This package contains authorized model weights and reference audio for one local GPT-SoVITS voice. It is an add-on for the QQ AI Voice Bot Starter Kit, not a complete QQ robot.

## Before installation

You need all of the following:

1. The base QQ AI Voice Bot project has been installed and opened at least once.
2. Docker Desktop is installed.
3. Your own QQ Official Bot and LLM configuration have been completed in AstrBot.
4. GPT-SoVITS compatible with the pack is installed locally.
5. In the base project, config\local-runtime.psd1 has a valid GsvRoot.

## Installation

1. Extract this ZIP to any local folder.
2. Double-click Install-VoicePack.cmd.
3. Choose the base QQ AI Voice Bot project folder when prompted.
4. The installer verifies the asset hashes, copies the weights and reference audio into your GPT-SoVITS folder, backs up your AstrBot configuration, updates only the local TTS provider, and starts the bot.

The first generated reply may take longer while the GPU initializes.

## What this does not provide

- a QQ account, AppID, AppSecret, IP whitelist, VPN, or model API key
- GPT-SoVITS runtime or a GPU
- conversation history, an original persona, official character graphics, or any account identity

The pack removes the need to train this voice again. It does not remove the GPU cost of generating each reply.

Do not redistribute this package unless the accompanying authorization permits redistribution.
