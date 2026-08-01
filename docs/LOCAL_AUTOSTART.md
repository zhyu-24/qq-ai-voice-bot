# 本机常驻与登录自启

这套机器人仍在这台电脑上运行。QQ 官方机器人平台只负责向 AstrBot 推送和接收消息；真正生成文本、语音和调用本地 GPT-SoVITS 的服务都在你的笔记本里。

## 平时需要保持的状态

- 电脑已开机、已登录 Windows，且不要进入睡眠。
- Docker Desktop 已运行或允许启动脚本自动拉起。
- 如果 QQ 开发平台的服务器 IP 白名单使用 VPN 出口，VPN 客户端本身要先自动连接。
- 不需要一直开着 AstrBot 网页、GPT-SoVITS 文档页、QQ 开发者后台或 QQ 聊天窗口。

## 手动启动

双击项目根目录的 Start-LocalBot.cmd。

它会依次：

1. 等待默认 45 秒，让 VPN、显卡驱动和 Docker Desktop 有时间就绪。
2. 检查或启动 Docker Desktop。
3. 检查或启动本机 GPT-SoVITS API，地址是 127.0.0.1:9880。
4. 根据 AstrBot 当前选择的本地 TTS 提供商预加载 GPT 和 SoVITS 权重。
5. 启动 AstrBot；如果它本来就在运行，会短暂重启一次，使 TTS 连接重新初始化。

首次运行时，启动窗口会显示进度。成功后可以访问：

- AstrBot: http://localhost:6185
- GPT-SoVITS API 文档: http://127.0.0.1:9880/docs

## 状态与停止

- Status-LocalBot.cmd：只检查 Docker、AstrBot、GPT-SoVITS、TTS 双输出和本地权重是否就绪。
- Stop-LocalBot.cmd：停止 AstrBot，再请求 GPT-SoVITS 优雅退出。Docker Desktop 会故意保持运行。
- 可以在 PowerShell 中运行 Status 脚本并加 CheckVpnEgress 参数，查看当前公网出口 IP。只有在 config\local-runtime.psd1 填写了 ExpectedVpnPublicIp 时才会做一致性提示。

不要把 9880 做路由器端口转发，也不要把 6185 对外网暴露。

## 登录后自动启动

在先手动启动成功一次后，双击 Install-LocalBotAutostart.cmd。

它只注册一个 Windows “用户登录时”任务，任务名为 Local QQ AI Voice Bot。每次登录后，它会先等待 45 秒，再执行启动脚本。该方式比“开机时”更适合你的情况，因为 VPN、Docker Desktop 和笔记本 GPU 都依赖已登录的桌面会话。

如需取消，双击 Uninstall-LocalBotAutostart.cmd。

## 电源设置

为了保持机器人在线，请在 Windows 电源设置中将“接通电源时睡眠”设为“从不”。不建议合盖后运行：多数笔记本会进入休眠或限制 GPU。任务计划只能在电脑已开机、已登录时把服务拉起，不能让关机的电脑继续回复。

## 日志位置

GPT-SoVITS 自动启动后的日志：

- logs\gpt-sovits-api.out.log
- logs\gpt-sovits-api.err.log

AstrBot 日志可在项目根目录执行：

    docker compose -f compose.yml logs --tail=100 astrbot

不要把日志、data 文件夹或截图中含有密钥的内容公开发给别人。
