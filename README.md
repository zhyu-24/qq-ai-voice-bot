# QQ AI Voice Bot（本地 QQ 官方机器人基础项目）

这是一个面向 Windows 的项目模板与发布工具集，用于搭建基于 **QQ 官方机器人**、**AstrBot** 和第三方大模型 API 的本地机器人。AstrBot 在 Docker Desktop 容器中运行，负责接收 QQ 消息、调用对话模型并回发结果；需要定制语音时，可额外在 Windows 主机上运行 GPT-SoVITS。本仓库同时提供可视化配置中心、启动/状态工具，以及将基础环境、人格和语音分别打包的安全检查与导入工具。

它不是一个已配置完成、拿来就能登录 QQ 的机器人，也不随仓库提供真实账号、密钥、人设、录音或语音权重。

## 最快开始

如果拿到的是发布者导出的**基础环境 ZIP**（而不是本仓库源代码）：

1. 解压 ZIP 到一个自己有写入权限的本地文件夹，例如“文档”下；不要在压缩包内直接运行。
2. 新电脑先完成 [Docker / WSL 2 指南](docs/DOCKER_WSL2_GUIDE.md)：开启 CPU 虚拟化、安装 WSL 2，并确认 Docker Desktop 显示 **Engine running**。
3. 双击 `Setup-Center.cmd`。这是推荐路径；按窗口中的页面依次配置 Docker、QQ 官方机器人和大模型。
4. 打开 `http://localhost:6185`，完成 AstrBot 首次管理员创建，并配置模型服务。
5. 在 QQ 测试群中 `@机器人 你好`。收到文字回复即表示基本链路可用；语音是另行可选的功能。

`Start-LocalBot.cmd` 等命令脚本适合已经了解流程的用户作为替代；首次安装优先使用可视化的 `Setup-Center.cmd`。

## 能做什么，不能做什么

### 当前能力

- 通过 QQ 官方机器人 WebSocket 通道接收和回复 QQ 消息，不登录、不托管个人 QQ 号。
- 通过 AstrBot 接入使用者自己的文本对话模型 API；支持在 WebUI 中配置与测试模型。
- 默认将 AstrBot 管理界面仅绑定到本机 `127.0.0.1:6185`。
- 提供 Windows 图形化配置中心、日常启动、停止、状态检查和登录后自动启动工具。
- 导入经清单、文件白名单、大小与 SHA-256 校验的人格包；提示词仍通过 AstrBot 官方人格页面保存。
- 可选连接本机 GPT-SoVITS，并导入经 SHA-256 校验的语音权重包，启用“文字 + 语音”输出。
- 为发布者提供基础环境包、人格包和语音包的检查与导出工具。

### 明确的边界与限制

- 每位使用者都必须自行创建 QQ 官方机器人，并自行提供 AppID、AppSecret、模型 API Key、账户、费用与 IP 白名单；这些不会从发布者或仓库继承。
- 本仓库和基础环境模板不含可直接导入的真实人格包或语音包，只有模板、工具和配置示例。
- GPT-SoVITS、GPU、语音权重和参考音频均为可选项；未配置它们时可只运行文字机器人或自行配置云端 TTS。
- 本项目不安装、不分发 GPT-SoVITS 本体、显卡驱动、VPN，也不代替 QQ 平台审核、模型服务开通或素材授权。
- QQ 平台、AstrBot、模型服务和 GPT-SoVITS 的界面、字段、版本与计费规则会变化；以其官方页面和当前账号控制台为准。
- 本项目不等同于将服务部署到云端。电脑关机、未登录或休眠时，本机机器人不能继续回复。

## 工作方式

```text
QQ 用户 / 测试群
        │  @机器人消息、机器人回复
        ▼
QQ 官方机器人平台（WebSocket，需配置 AppID / AppSecret / 出口 IP 白名单）
        │
        ▼
AstrBot（Docker Desktop 容器，管理界面 http://localhost:6185）
        │
        ├── 调用使用者自己的模型 API ──► 文本回复
        │
        └── [可选] 调用 Windows 主机上的 GPT-SoVITS
                         host.docker.internal:9880
                                      │
                                      ▼
                              语音回复（可与文字同时发送）
```

这里的 **Docker** 可以理解为将 AstrBot 放在一个隔离的运行环境中；**WSL 2** 是 Windows 上 Docker Desktop 使用 Linux 容器时所依赖的 Windows 组件。**模型 API** 是模型服务商提供的网络接口，通常需要 Base URL、API Key 和 Model ID 三项。GPT-SoVITS 是本地语音合成运行环境，不负责生成聊天文字。

QQ WebSocket 模式不要求把家中路由器端口开放到公网，但 QQ 平台会校验此电脑的**公网出口 IP**。如果白名单填写的是 VPN 出口 IP，启动前必须连接同一 VPN 节点；换网络、热点或 VPN 节点后可能需要更新白名单。

## 五类内容：请不要混淆

1. **仓库源代码 / 项目创建者目录**：当前 Git 仓库。它包含发布脚本、模板、测试和文档，供维护者开发、检查和导出，不应当被当成已配置运行目录分享出去。
2. **基础环境包**：由 `shareable-template/` 生成的无私密内容 ZIP，例如 `qq-ai-voice-bot-starter-v5.zip`。普通使用者从这个 ZIP 解压后开始配置。
3. **已配置运行目录**：某一台电脑上实际运行的基础环境包文件夹。其 `data/`、本地配置、日志和备份可能含有凭据或私密数据，不能提交或分享。
4. **人格包**：独立的纯文本 ZIP，提供系统提示词和清单；不含语音、模型、账号或密钥。
5. **语音包**：独立的本地 GPT-SoVITS 模型权重与参考音频 ZIP；不等于人格包，也不等于完整机器人。

## 仓库内容概览

```text
.
├─ Setup-Center.cmd / Start-LocalBot.cmd / Status-LocalBot.cmd / Stop-LocalBot.cmd
├─ Export-ShareablePackage.cmd / Export-PersonaPack.cmd / Export-VoicePack.cmd
├─ compose.yml / Dockerfile / config/
├─ scripts/                  # PowerShell 实现与安全校验逻辑
├─ shareable-template/       # 可安全导出的基础环境包来源
├─ persona-pack-template/    # 人格包结构与授权声明模板
├─ voice-pack-template/      # 语音包安装器与授权声明模板
├─ docs/                     # 面向使用者与维护者的说明
└─ tests/                    # 隔离回归测试
```

### 根目录脚本、Docker 与配置文件

- `Setup-Center.cmd`：打开 Windows 图形化配置中心，覆盖基础安装、QQ、模型、人格包、语音包、状态和常驻设置；推荐首次使用。
- `Install.cmd`：命令行式的最小初始化与启动入口；首次使用时创建本地运行配置并启动 AstrBot。适合不使用图形界面的替代路线。
- `Start-LocalBot.cmd`、`Status-LocalBot.cmd`、`Stop-LocalBot.cmd`：分别用于日常启动、只读状态检查和停止 AstrBot / 请求 GPT-SoVITS 优雅退出。停止后 Docker Desktop 会保留运行。
- `Install-LocalBotAutostart.cmd`、`Uninstall-LocalBotAutostart.cmd`：注册或删除名为 `Local QQ AI Voice Bot` 的“用户登录时”Windows 计划任务；不是开机后无人值守运行方案。
- `Export-ShareablePackage.cmd`：检查 `shareable-template/` 后，将其导出到本机 `release/`。
- `Export-PersonaPack.cmd`、`Export-VoicePack.cmd`：为项目创建者分别导出人格包、语音包。前者需要自己准备的私有人格源文件；后者需要已验证的本地运行配置、权重和参考音频。仓库本身不具备这些真实素材。
- `compose.yml` 与 `Dockerfile`：定义 AstrBot 容器。容器数据挂载到根目录 `data/`，管理端口仅映射为 `127.0.0.1:6185`；Dockerfile 在 AstrBot 基础镜像中安装 `edge-tts`。
- `config/local-runtime.psd1.example`：本地 GPT-SoVITS 路径、端口、启动等待时间、可选 VPN 出口 IP 等的示例。复制为 `config/local-runtime.psd1` 后才是当前机器的实际选择。
- `config/tts-settings.json`：AstrBot TTS 配置字段的对照片段，其中的 `REPLACE_WITH_YOUR_TTS_PROVIDER_ID` 只是占位符，不是可用提供商。
- `.dockerignore`、`.gitignore`：避免将运行数据、凭据、日志、音频和模型权重带入镜像或 Git；不要为了“方便”取消这些忽略规则。

### `scripts/`、模板与测试目录

- `scripts/`：所有 `.cmd` 包装器所调用的 PowerShell 实现。包括 Docker/GPT-SoVITS 启停、状态与公网出口检测、配置中心、登录自启、打包、人格/语音包导入与验证。`CmdConfig.Common.ps1` 负责严格 UTF-8 JSON 读取、验证、原子替换和备份。
- `shareable-template/`：将要交付给普通使用者的基础环境包来源，包含自身的脚本、文档、Docker 文件和空配置示例。它还包含 `Check-Package.cmd`、MIT `LICENSE`、`SECURITY.md` 与 `THIRD_PARTY_NOTICES.md`。
- `persona-pack-template/`：人格包的四文件结构说明与授权/分发声明。导出的人格包仅应携带 `manifest.json`、`assets/system-prompt.md`、说明与授权声明。
- `voice-pack-template/`：语音包中的 `Install-VoicePack.cmd`、安装逻辑和授权/分发声明。实际导出时才会加入经许可的权重和参考音频。
- `docs/`：完整的使用、排错与发布说明，见下方索引。
- `tests/`：PowerShell 隔离回归测试与说明，不会连接真实机器人服务。

## 使用前需要准备什么

### 必需

- **Windows**：Windows 11，或 Windows 10 版本 2004 / 内部版本 19041 及以上。
- **CPU 虚拟化与 WSL 2**：任务管理器“性能 → CPU”中的“虚拟化”应为“已启用”；需要安装 WSL 2。
- **Docker Desktop for Windows**：使用 WSL 2 后端和 Linux containers，且显示 **Engine running**。普通个人本机运行通常不要求登录 Docker 账号。
- **QQ 官方机器人账号与平台配置**：在 QQ 官方机器人平台创建自己的机器人，取得 AppID 与 AppSecret，选择 WebSocket，并设置当前公网出口 IPv4 白名单及测试群所需权限。
- **一个可用的文本模型服务**：从服务商取得 Base URL、API Key 和精确的 Model ID，并自行处理账户、余额和计费。
- **本机管理员权限（仅某些前置步骤）**：首次安装 WSL 2 或启用 Windows 功能时需要；常规配置中心操作不应要求把密钥输进终端。

### 可选：本地 GPT-SoVITS 语音

- 与语音包匹配的 GPT-SoVITS 本地运行环境，以及正确的 GPU 驱动和可用于推理的 GPU。项目文档不规定统一显卡型号或显存门槛，兼容性以所选 GPT-SoVITS 发行版和语音包为准。
- 对应的、拥有使用权和再分发权（如需分享）的 GPT / SoVITS 权重与参考音频，或由有权发布者提供的语音包。
- 在 `config/local-runtime.psd1` 中设置 `GsvRoot`。Docker 内的 AstrBot 访问 Windows 主机服务时使用 `http://host.docker.internal:9880`，不是容器内的 `127.0.0.1`。

没有 GPU 或不想配置 GPT-SoVITS 时，仍可完成 QQ + AstrBot + 文本模型；也可以在 AstrBot 中自行选择合适的云端 TTS。不要把“本地语音可选”误解成“无需模型 API”。

## 从基础环境包安装（普通使用者）

以下步骤适用于从 `shareable-template` 导出的基础 ZIP。源代码仓库与已配置运行目录的用途不同，维护者请看下一节。

1. **解压并打开配置中心**
   - 解压基础 ZIP；确认文件夹中有 `Setup-Center.cmd`、`compose.yml` 和 `scripts/`。
   - 双击 `Setup-Center.cmd`。如果 Windows 显示安全提示，请先确认 ZIP 的来源和签名/发布说明是否可信。

2. **完成 Docker / WSL 2 前置**
   - 按 [Docker / WSL 2 指南](docs/DOCKER_WSL2_GUIDE.md) 检查 Windows 版本与 CPU 虚拟化。
   - 在“以管理员身份运行”的 Windows PowerShell 执行：

   ```powershell
   wsl --install
   ```

   - 重启 Windows 后执行：

   ```powershell
   wsl --update
   wsl --status
   ```

   - 安装 Docker Desktop，保持 WSL 2 / Linux containers 模式。普通 PowerShell 中执行下列命令，输出同时有 `Client` 和 `Server` 才算就绪：

   ```powershell
   docker version
   ```

3. **启动 AstrBot 并完成首次 WebUI 初始化**
   - 在配置中心“基础环境”页点击“启动 AstrBot”，或双击 `Install.cmd`。
   - 打开 `http://localhost:6185`，按 AstrBot 首次引导创建本机管理帐号。这个地址只应在本机打开，不要映射到公网。

4. **创建并连接 QQ 官方机器人**
   - 在配置中心打开 QQ 官方机器人平台，创建机器人，保存自己的 AppID 与 AppSecret。
   - 事件订阅选择 WebSocket；将当前公网出口 IPv4 填入 QQ 平台服务器 IP 白名单。配置中心可检测出口 IP。
   - 在 AstrBot 的“机器人 / 平台”页面新增 QQ 官方机器人（WebSocket）适配器，填写 AppID、AppSecret 并启用。
   - 将机器人加入可测试的 QQ 群，按 QQ 平台要求设置接收消息范围、主动发言权限；建议先启用“仅 @ 时回复”。

5. **配置模型 API**
   - 先读 [模型选择与 API 获取指南](docs/MODEL_AND_API_GUIDE.md)。不要用 Embedding、图像/视频、ASR、TTS 或 Rerank 模型作为普通聊天模型。
   - 在 `http://localhost:6185/#/providers` 新建对应的模型提供商，填写服务商给出的 Base URL、API Key、Model ID，保存并设为默认对话模型。
   - 在 `http://localhost:6185/#/chat` 发送 `只回复：连接成功。`。成功后再去 QQ 群测试。

6. **可选：添加人格或本地语音**
   - 人格包和语音包都是独立下载物，基础包不附带。分别按下文步骤导入。
   - 本地语音还须先安装兼容 GPT-SoVITS、设置 `GsvRoot`；不要在未确认授权的情况下使用或转发音频、权重和模型。

## 从仓库源代码发布或开发

当前仓库是**项目创建者目录**，不是已配置运行目录，也不应将整个根目录打包发给使用者：根目录可能在本机生成 `data/`、日志、备份、素材或配置，而这些都不适合分享。

发布基础环境包的建议流程：

1. 在仓库根目录检查基础模板：双击 `shareable-template\Check-Package.cmd`，或在源项目使用 `Export-ShareablePackage.cmd` 前先检查。
2. 确认 `shareable-template/` 不含 `data`、日志、状态、模型、参考音频、输出文件、`config/local-runtime.psd1` 或任何密钥。
3. 双击 `Export-ShareablePackage.cmd`。脚本会检查模板，并在本机 `release/` 生成基础 ZIP。
4. 以一台干净电脑或隔离目录验证 ZIP；仅分享生成的基础 ZIP（或单独上传 `shareable-template/`），不要分享当前仓库根目录。
5. 如确有可分享素材，单独运行人格/语音导出工具，并逐项确认文本、模型权重和参考音频的使用与再分发授权。

基础包发布前检查是保守的防护，不是对泄露风险的绝对保证；仍需人工检查文档、截图和配置。详细清单可见 [可分享基础环境模板](docs/SHAREABLE_TEMPLATE.md)。

## 日常使用与验证

推荐在配置中心“启动与常驻”页面操作；以下脚本是等价的快捷入口：

- 启动：双击 `Start-LocalBot.cmd`。它检查/启动 Docker，按本地配置启动 GPT-SoVITS（如已设置），再启动或重启 AstrBot 以初始化 TTS。
- 状态：双击 `Status-LocalBot.cmd`。它只做检查；需要检查 VPN 出口时，可在 PowerShell 运行：

  ```powershell
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Get-LocalBotStatus.ps1 -CheckVpnEgress
  ```

  只有在 `config/local-runtime.psd1` 填写了 `ExpectedVpnPublicIp` 时，状态脚本才会提示是否一致。
- 停止：双击 `Stop-LocalBot.cmd`。它停止 AstrBot、请求 GPT-SoVITS 退出，故意不关闭 Docker Desktop。
- 登录后自启：在已经手动成功启动过一次后，双击 `Install-LocalBotAutostart.cmd`；取消时双击 `Uninstall-LocalBotAutostart.cmd`。保持电脑开机、已登录且不睡眠；若依赖 VPN，VPN 客户端本身也要先设置登录后自动连接。

常用地址：

- AstrBot 管理界面：`http://localhost:6185`
- AstrBot 模型测试页：`http://localhost:6185/#/chat`
- AstrBot 模型提供商页：`http://localhost:6185/#/providers`
- AstrBot 人格页：`http://localhost:6185/#/persona`
- 可选 GPT-SoVITS API 文档：`http://127.0.0.1:9880/docs`

一次完整成功验证至少应满足：`docker version` 显示 Client 和 Server；AstrBot WebUI 能打开；聊天测试返回文本；在已加入机器人且白名单正确的 QQ 测试群中 `@机器人` 后收到回复。启用本地语音时，再确认每条模型回复按设置同时具有文字和语音。已有会话可能保留旧模型或人格，修改后请新建会话测试。

## 人格包：只携带文本设定

人格包是可选的独立 ZIP，通常包含系统提示词 `assets/system-prompt.md`、`manifest.json`（人格 ID、文件大小、SHA-256）以及说明和授权声明。它不包含 QQ AppID/AppSecret、模型 API Key、AstrBot 数据库、聊天记录、日志、音频、图片、权重、训练材料或可执行脚本。

导入步骤：

1. 先让基础环境、QQ 官方机器人和模型 API 正常运行。
2. 打开 `Setup-Center.cmd` 的“人格包”页，选择人格 ZIP。
3. 点击“安全准备并打开人格页”。工具验证清单、允许的文件、大小和 SHA-256，将提示词复制到剪贴板，并打开 `http://localhost:6185/#/persona`。
4. 在 AstrBot 新建人格，使用工具显示的 Persona ID，粘贴提示词并保存。
5. 回到配置中心点击“设为默认人格（已保存后）”，然后再执行一次日常启动，并以**新会话**测试。

导入器不会执行 ZIP 中的代码，不会直接写 AstrBot 人格数据库，也不会索取管理登录令牌；最后一步只会备份并安全更新本机 `data/cmd_config.json` 中的默认人格 ID。格式与发布边界见 [人格包说明](docs/PERSONA_PACK.md)。

## 语音包：权重与参考音频的可选扩展

语音包与人格包完全分离。一个有效语音包可包含一个本地 GPT-SoVITS 声音所需的 GPT 权重、SoVITS 权重、参考音频、哈希和安装器；它不是完整 QQ 机器人，也不携带 QQ 凭据、模型 API Key、聊天记录或原始人格。

导入步骤：

1. 先完成基础环境、自己的 QQ 官方机器人与文本模型配置，并确认 Docker Engine 正常。
2. 从有权发布者处取得与 GPT-SoVITS 运行环境兼容的语音 ZIP，解压到本地文件夹。
3. 安装兼容的 GPT-SoVITS；在基础项目复制配置示例为 `config/local-runtime.psd1`，填好 `GsvRoot`。
4. 双击解压后语音包中的 `Install-VoicePack.cmd`，在提示中选择**已配置的基础机器人项目目录**。
5. 安装器验证哈希，复制权重和参考音频，备份 `data/cmd_config.json`，只更新本地 TTS 提供商和 TTS 开关，然后启动服务。

导入已有语音包通常**不需要重新训练**；但每次生成语音仍需本机的 GPT-SoVITS 运行环境和 GPU。不要重复导入同一个包；安全安装器会拒绝覆盖已有目标文件。语音包修改范围、备份及授权要求见 [语音包说明](docs/VOICE_PACK.md)。

## 本地生成文件、配置与隐私

下列内容对应某台电脑、某个账号或某次运行，均不应提交到 Git、上传公开仓库、打入基础包，或随意共享：

- `config/local-runtime.psd1`：当前电脑的 GPT-SoVITS 路径、端口和可选 VPN 出口期望值。只提交 `config/local-runtime.psd1.example`。
- `.env`：本地环境文件；即使当前 Compose 文件不要求将密钥写在这里，也应把它视为私密文件。
- `data/cmd_config.json` 与整个 `data/`：AstrBot 的运行数据、提供商配置、管理信息和可能的令牌/会话数据。
- `backups/`：导入人格/语音包前产生的配置备份，可能保留此前本机设置。
- `logs/`：服务日志，可能包含运行环境、请求或错误上下文。
- `state/`：本机启动状态，例如 GPT-SoVITS 进程记录。
- `persona-imports/`：已导入人格包在本机的副本。
- `release/`：本机导出的 ZIP；发布前人工复核，不能因为文件在该目录就默认安全。

不要将 API Key、AppSecret、VPN 凭据、公开出口 IP、聊天记录、管理帐号信息、音频或模型权重复制进 README、截图、人格包或基础包。若怀疑密钥已泄露，应立即在相应服务商或 QQ 平台撤销/轮换，不要继续复用。

导入和配置更新会使用严格 UTF-8 JSON 读取、校验、原子替换和备份机制，以避免编码损坏或更新失败时半写入；状态检查遇到坏配置时应返回失败且不打印配置内容。人格与语音包会验证清单与 SHA-256；这些机制不能替代下载来源、内容和授权的人工审核。仓库没有跟踪任何真实资产。

同时，请保持端口私有：不要把 AstrBot 的 `6185` 或 GPT-SoVITS 的 `9880` 直接做路由器端口转发或暴露在公网。

## 故障排查

- **Docker Desktop 报 `Virtualization support not detected`，或 `docker version` 没有 Server**：按 [Docker / WSL 2 指南](docs/DOCKER_WSL2_GUIDE.md) 检查 CPU 虚拟化、Windows 版本、WSL 2 和 Docker Engine。登录 Docker 账号不能修复虚拟化或 WSL 问题。
- **启动后不知道服务是否就绪**：运行 `Status-LocalBot.cmd`；本地常驻、日志位置和停止行为见 [本机常驻与登录自启](docs/LOCAL_AUTOSTART.md)。
- **AstrBot 能打开但没有模型回复，或出现 401/403/404**：核对 Base URL、API Key、精确 Model ID、服务商权限/余额和默认模型，参见 [模型选择与 API 获取指南](docs/MODEL_AND_API_GUIDE.md)。
- **WebUI 聊天正常但 QQ 不回复**：检查 QQ WebSocket 适配器、AppID/AppSecret、机器人是否加入测试群、@ 唤醒规则，以及当前公网出口 IP 是否仍在 QQ 平台白名单中。更换网络或 VPN 节点后需重新检查。
- **只有文字、没有本地语音；或 GPU / GPT-SoVITS 启动失败**：确认 `GsvRoot`、GPT-SoVITS 环境与 GPU 驱动、端口 `9880`、TTS 默认提供商和权重路径。语音包问题见 [语音包说明](docs/VOICE_PACK.md)，基础部署字段可对照 [QQ 官方机器人部署说明](docs/QQ机器人部署说明.md)。
- **人格没有生效**：确认已在 AstrBot 人格页面保存，再设置默认人格，并在新会话中验证；见 [人格包说明](docs/PERSONA_PACK.md)。
- **担心准备发布的基础包混入私密文件**：运行 `Check-Package.cmd` 并使用 [可分享基础环境模板](docs/SHAREABLE_TEMPLATE.md) 的发布清单逐项复核。

## 文档索引

根目录 `docs/` 中的每份文档：

- [DOCKER_WSL2_GUIDE.md](docs/DOCKER_WSL2_GUIDE.md)：Windows 虚拟化、WSL 2、Docker Desktop 的安装、验证和常见错误。
- [LOCAL_AUTOSTART.md](docs/LOCAL_AUTOSTART.md)：本机日常启动、状态、停止、登录自启、电源设置与日志位置。
- [MODEL_AND_API_GUIDE.md](docs/MODEL_AND_API_GUIDE.md)：零基础选择文本模型、取得 API 三要素、配置 AstrBot 与排错。
- [PERSONA_PACK.md](docs/PERSONA_PACK.md)：纯文本人格包的内容边界、导入流程和发布注意事项。
- [QQ机器人部署说明.md](docs/QQ机器人部署说明.md)：QQ 官方机器人、AstrBot、TTS、人格与上线检查的手动部署参考。
- [SETUP_CENTER.md](docs/SETUP_CENTER.md)：可视化配置中心各页面、VPN/IP 白名单和使用者需自行完成的事项。
- [SHAREABLE_TEMPLATE.md](docs/SHAREABLE_TEMPLATE.md)：安全基础环境模板的内容边界、ZIP 导出与发布者责任。
- [VOICE_PACK.md](docs/VOICE_PACK.md)：可选 GPT-SoVITS 语音权重包的导出、安装、修改范围和授权边界。

基础包内部还有自己的说明，例如 `shareable-template/README.md`、`shareable-template/SECURITY.md`、`shareable-template/docs/LOCAL_GSV.md` 与 `shareable-template/docs/PUBLISH_CHECKLIST.md`；发布基础包时应让下载者随包阅读。

## 回归测试

测试针对脚本的安全行为，使用 Windows PowerShell 5.1 运行。在仓库根目录打开 **Windows PowerShell 5.1**，执行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-Regression.ps1
```

测试在临时目录中生成假密钥、极小的占位权重/音频和假的项目结构；不会启动 Docker，不会访问 QQ、模型 API 或真实机器人，也不会读取真实 `data/`、真实人格或真实模型资产。它验证严格 UTF-8 与中文往返、`cmd_config.json` 的原子更新与备份、异常时不泄露配置内容、人格/语音包隔离导入、重复导入拒绝、无关配置保留、状态输出脱敏，以及配置中心关键参数绑定。

更多背景见 [tests/README.md](tests/README.md)。

## 项目状态、许可证与第三方声明

本仓库当前提供的是本地部署、可分享模板和安全导入/导出工具；运行效果依赖使用者的 QQ 平台权限、模型服务、网络、Docker 环境，以及可选的 GPT-SoVITS/GPU 环境。维护或发布前应在干净环境验证，且对版本兼容性、服务费用、账号权限和素材授权自行负责。

根目录没有单独跟踪的项目许可证文件，因此本 README 不为整个根仓库虚构许可证。`shareable-template/LICENSE` 为**基础环境模板**提供 MIT 许可证；第三方组件、模型、服务条款与费用请参阅 `shareable-template/THIRD_PARTY_NOTICES.md` 及各组件官方条款。人格包与语音包的分发授权分别由其包内 `LICENSE-AND-AUTHORIZATION.md` 和实际素材的权利状态决定，不能仅因项目是非商业用途就推定可以再分发或模仿官方身份。
