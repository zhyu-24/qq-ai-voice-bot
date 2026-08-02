# QQ AI Voice Bot Starter Kit

这是一个 Windows 优先的 QQ 官方机器人基础包。它使用 AstrBot 处理群消息和大模型，可选连接本机 GPT-SoVITS 生成定制语音，也可安全导入独立的文本人格包。

它不是预配置好的账号：每位使用者必须使用自己的 QQ 官方机器人、模型服务和本机运行环境。

## 从这里开始

解压后，直接双击 `Setup-Center.cmd`。

> **新电脑的第 0 步：** 在安装 Docker Desktop 前，先按 [Windows Docker / WSL 2 前置指南](docs/DOCKER_WSL2_GUIDE.md) 开启 CPU 虚拟化并安装 WSL 2。若 Docker 显示 “Virtualization support not detected”，这不是 Docker 登录问题，登录不能修复它。

它会打开一个图形化配置中心，按页签完成：

1. 开启硬件虚拟化并安装 / 验证 WSL 2；
2. 安装 Docker Desktop，并启动 AstrBot；
3. 在 QQ 开放平台创建机器人、选择 WebSocket、配置 IP 白名单；
4. 在 AstrBot 中填写自己的 QQ AppID 与 AppSecret；
5. 按 [模型选择与 API 获取指南](docs/MODEL_AND_API_GUIDE.md) 在 AstrBot 中配置自己的大模型服务和 API Key；
6. 可选：导入纯文本人格包，复制提示词并在 AstrBot 官方人格页保存；
7. 可选：安装 GPT-SoVITS、选择本机目录、导入有权使用的语音包 ZIP；
8. 启动、停止、状态检查与登录后自动启动。

配置中心会在首次 WSL 2 安装时请求管理员授权并打开终端；其余项目配置不需要手动输入 PowerShell 命令。详细说明在 [docs/SETUP_CENTER.md](docs/SETUP_CENTER.md)；零基础模型/API 指南在 [docs/MODEL_AND_API_GUIDE.md](docs/MODEL_AND_API_GUIDE.md)；人格包说明在 [docs/PERSONA_PACK.md](docs/PERSONA_PACK.md)。

初次使用时请选择服务商列表中的**文本对话模型**；不要误选 Embedding、图像/视频生成、ASR、TTS 或 Rerank 模型。

## 有梯子 / 大陆下载路线

- Docker：向导内提供 Docker 官方说明、[WSL 2 / 虚拟化前置指南](docs/DOCKER_WSL2_GUIDE.md)和官方下载按钮。个人本机使用通常不需要 Docker 账号；但匿名拉取 Docker Hub 镜像遇到限流时可自行登录。
- GPT-SoVITS：向导提供 GitHub 发布页（适合可访问 GitHub 的网络）与 ModelScope 的 50 系显卡包链接（适合大陆下载）。请始终选择与你的语音包兼容的运行环境。
- QQ 开放平台与 AstrBot：向导会打开相应网页，并在页面中列出每一步需要填写的内容。

## 包含内容

- Docker Compose 版 AstrBot
- 图形化配置中心与启动、停止、状态检查工具
- 可选文本人格包的安全校验、剪贴板准备与官方 UI 导入指引
- 可选本地 GPT-SoVITS 的路径检查和安全语音包导入器
- 登录后自动启动脚本
- 中性、原创人格示例
- 发布前安全检查

## 刻意不包含的内容

- QQ AppID、AppSecret、账号或 IP 白名单
- 模型 API Key、账单或服务账户
- AstrBot 运行数据、聊天记录、数据库、日志或管理员账号
- 任何语音录音、训练权重、参考音频、原作角色资料或账号头像
- 任何私人或未获分享许可的人格提示词
- VPN 客户端及 VPN 凭据

## VPN / 白名单要点

QQ 官方机器人在 WebSocket 模式下不需要把电脑端口暴露给公网。但 QQ 平台会校验服务器 IP 白名单：请登记当前 VPN 或网络的公网出口 IPv4，而不是本机或路由器内网地址。更换 VPN 节点、关闭 VPN、切换网络或手机热点后，如果出口 IP 改变，请回 QQ 开放平台更新白名单。

## 分享与授权

基础包可以分享；请先运行 `Check-Package.cmd`。人格包和语音包应当分开发送：人格包只能包含可分享的文本设定，语音包仅在发布者拥有模型与参考音频的使用和传播授权时分享。两个包都不应携带 QQ 凭据、模型 Key、聊天数据或任何用户私密信息。
