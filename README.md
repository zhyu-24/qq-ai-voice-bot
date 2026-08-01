# 本地 QQ AI 语音机器人

本目录是当前电脑上的本地部署项目：AstrBot 在 Docker 中运行，GPT-SoVITS 在 Windows 主机上运行，QQ 官方机器人使用 WebSocket 接入。

## 日常使用

直接双击 `Setup-Center.cmd`：

- “日常启动”会启动 Docker、AstrBot 与已配置的 GPT-SoVITS；
- “检查本机状态”会检查语音、TTS、权重和 GPU；
- “启动与常驻”可以设置 Windows 登录后自动启动；
- 浏览器的 AstrBot 页面无需保持打开。

详细图形化流程见 [docs/SETUP_CENTER.md](docs/SETUP_CENTER.md)。

## 分享给其他人

请分享 `release` 中导出的两个独立包：

- 基础环境包：图形化向导、Docker/AstrBot 启动脚本、文档；
- 可选语音包：仅在拥有使用与传播授权时分享，下载者可在向导的“本地语音”页导入。

基础包不包含 QQ 凭据、模型 API Key、个人数据、聊天记录、日志、模型权重或参考音频。