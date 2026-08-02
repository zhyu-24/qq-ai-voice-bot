# 爱弥斯主题 QQ 机器人：部署说明

这个项目基于 **QQ 官方机器人 + AstrBot**。机器人回复由 AstrBot 生成，内置 TTS 在每条模型回复后追加语音；不会登录或托管个人 QQ 号。

## 1. 启动 AstrBot

前提：已先完成 [Windows Docker / WSL 2 前置指南](DOCKER_WSL2_GUIDE.md)，确认 Docker Desktop 显示 Engine running，再在本目录打开 PowerShell。

```powershell
docker compose -f compose.yml up -d
```

打开 `http://localhost:6185`，按首次引导创建管理帐号。停止服务使用：

```powershell
docker compose -f compose.yml down
```

运行数据位于 `data/`，其中可能含有令牌和会话数据；不要提交或分享该目录。

## 2. 配置大模型

在 AstrBot WebUI 的“服务提供商”添加一个聊天模型。可使用 OpenAI 兼容接口、DeepSeek、通义或混元等。保存后先在 WebUI 的聊天测试页确认能收到一条文本回复。

## 3. 配置“每条都发语音”

1. 在“服务提供商”添加一个 TTS 提供商并试听。建议先用质量稳定、支持中文的云端 TTS；不要使用可识别的真人或原角色配音素材。
2. 在全局配置中设置以下字段（`config/tts-settings.json` 是可对照的片段）：
   - `provider_tts_settings.enable`: `true`
   - `provider_tts_settings.provider_id`: 你刚创建的 TTS 提供商 ID
   - `provider_tts_settings.dual_output`: `true`
   - `provider_tts_settings.trigger_probability`: `1.0`
3. 保存并重启 AstrBot。`dual_output: true` 保留文字台词，`1.0` 保证每条模型回复都触发语音。

QQ 官方机器人语音适配使用 WAV 最稳妥。若某个 TTS 默认产出 MP3，请在该提供商配置中改为 WAV，或更换支持 WAV 的提供商。

## 4. 导入角色人格

1. 打开 AstrBot WebUI 的“人格 / Persona”。
2. 新建人格，ID 建议填 `aemeath`，名称填“爱弥斯（同人）”。
3. 将 `persona/aemeath.md` 中“系统提示词”以下的内容粘入系统提示词。
4. 将该人格设为默认人格；如有“群聊会话隔离”选项，建议开启，避免不同群的上下文串联。

## 5. 接入 QQ 官方机器人

1. 登录 [QQ 官方机器人平台](https://q.qq.com/)，创建机器人并保存 `AppID`、`AppSecret`。
2. 在 AstrBot 的“机器人”页面添加 `QQ 官方机器人（WebSocket）`。
3. 填入 `AppID`、`AppSecret` 后启用并保存。
4. 回到手机 QQ 的机器人资料页，将机器人添加至你作为群主的测试群；在群机器人设置中开启消息接收范围与主动发言权限。
5. 在 AstrBot 的 QQ 通道设置里启用“仅 @ 时回复”（或等价的唤醒规则），然后用 `@机器人 你好` 测试。

## 6. 上线检查

- 文本：机器人能在测试群的 @ 消息下正常回复。
- 语音：每一条回复同时出现文字和语音；若只有文字，先检查 TTS 提供商 ID 和 `trigger_probability`。
- 安全：管理 WebUI 只绑定 `127.0.0.1`；部署到云服务器时不要直接裸露在公网，应使用 VPN、反向代理鉴权或防火墙限制访问。
- 频率：建议设置至少 5–10 秒群聊冷却时间，避免多人连续触发导致语音堆积和费用上升。

## 故障排查

| 现象 | 优先检查 |
| --- | --- |
| QQ 无响应 | AppID/AppSecret、QQ 通道是否启用、机器人是否已加入测试群 |
| 只有文字 | TTS 是否可试听、TTS provider ID、`enable` 与 `trigger_probability: 1.0` |
| 语音发送失败 | 将 TTS 输出改为 WAV；检查 AstrBot 日志中的文件上传或格式错误 |
| 偶尔漏掉语音 | 确保回复来源是模型结果而不是插件的固定文本；检查 TTS 配额/网络错误 |
