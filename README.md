# 本地 QQ AI 语音机器人

本目录是当前电脑上的本地部署项目：AstrBot 在 Docker 中运行，GPT-SoVITS 在 Windows 主机上运行，QQ 官方机器人使用 WebSocket 接入。

## 日常使用

直接双击 `Setup-Center.cmd`：

- “日常启动”会启动 Docker、AstrBot 与已配置的 GPT-SoVITS；
- “检查本机状态”会检查语音、TTS、权重和 GPU；
- “人格包”可安全导入纯文本系统提示词，并在官方 AstrBot 页面保存；
- “启动与常驻”可以设置 Windows 登录后自动启动；
- 浏览器的 AstrBot 页面无需保持打开。

详细图形化流程见 [docs/SETUP_CENTER.md](docs/SETUP_CENTER.md)。人格包格式与导入边界见 [docs/PERSONA_PACK.md](docs/PERSONA_PACK.md)。第一次接触模型服务时，请先阅读 [模型选择与 API 获取指南](docs/MODEL_AND_API_GUIDE.md)。

## 项目本地配置与分享

下载或发布时，请把内容分成彼此独立的包：

- 基础环境包：图形化向导、Docker/AstrBot 启动脚本、文档；解压后双击 `Setup-Center.cmd` 即可跟随傻瓜式教程完成配置。
- 可选人格包：纯文本系统提示词与哈希校验，不带任何媒体或凭据。
- 可选语音包：如发布者另行提供已训练的爱弥斯语音包，可在向导中一键导入；仅在拥有使用与传播授权时分享。

基础包不包含 QQ 凭据、模型 API Key、个人数据、聊天记录、日志、模型权重、参考音频或你的本地人格文本。`release` 和 `persona-imports` 都是本机私有目录，不会被 Git 提交。
