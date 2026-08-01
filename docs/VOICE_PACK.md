# 可选语音权重包

基础环境包与语音权重包是分开的。

- 基础包：shareable-template 或 qq-ai-voice-bot-starter.zip，不含任何模型与音频。
- 语音包：由 Export-VoicePack.cmd 生成，包含 GPT 权重、SoVITS 权重、参考音频、哈希校验和独立安装器。

## 生成语音包

在当前已经验证能正常发声的电脑上，双击：

    Export-VoicePack.cmd

默认会在 release 文件夹生成：

    aemeath-local-voice.zip

这个 ZIP 约 313 MiB，模型权重通常无法明显压缩。它不包含 AstrBot data、QQ 密钥、模型 API Key、聊天记录或 VPN 配置。

## 下载者导入步骤

1. 先安装并运行基础包，完成自己的 QQ 官方机器人和大模型配置。
2. 安装兼容的本地 GPT-SoVITS，并在基础项目的 config\local-runtime.psd1 中填写 GsvRoot。
3. 解压语音包 ZIP。
4. 双击语音包中的 Install-VoicePack.cmd。
5. 在弹出的窗口中选择基础机器人项目目录。
6. 安装器会验证哈希、复制模型与参考音频、备份 data\cmd_config.json、只更新本地 TTS 提供商，然后启动 GPT-SoVITS 与 AstrBot。

安装后，下载者无需重新训练这个声音；但每次语音生成依然需要其本机 GPU 和 GPT-SoVITS 运行时。

## 导入器的修改范围

导入器只修改：

- GPT-SoVITS 安装目录中的 GPT 权重、SoVITS 权重与参考音频副本。
- 基础项目的 data\cmd_config.json 中对应的 TTS provider 和 TTS 总开关。
- 基础项目的 backups 文件夹，用于保留修改前的 AstrBot 配置。

它不会修改 QQ AppID、AppSecret、LLM API Key、平台配置或聊天记录。配置备份含有本机配置，应始终保持私有，不能上传或分享。

## 发布边界

当前授权仅按你确认的模型和参考音频分发权限处理。语音包不附带原作角色图像、官方台词、人格提示词、QQ 账号或任何平台凭据。若未来要附加其他素材，需要分别确认其可再分发范围。
