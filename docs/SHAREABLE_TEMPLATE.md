# 可分享的一键安装模板

shareable-template 文件夹是一个独立、无私密内容的项目模板。它可以作为 GitHub 仓库内容或发送给朋友的 ZIP 起点。

模板内已经不包含：

- QQ AppSecret、模型 API Key、VPN 信息或 IP 白名单
- AstrBot 的 data、聊天记录、管理员账户和日志
- 参考音频、生成音频、GPT-SoVITS 权重和训练输出
- 当前机器的 GPT-SoVITS 绝对路径
- 私有角色人设、原作素材或专属头像

## 创建 ZIP

双击项目根目录的 Export-ShareablePackage.cmd。

它会先扫描 shareable-template，再在 release 文件夹中创建 qq-ai-voice-bot-starter.zip。若发现常见的音频、权重、运行数据或疑似密钥，脚本会拒绝创建 ZIP。

也可以直接将 shareable-template 上传为一个新仓库；不要上传整个当前项目根目录。

## 对使用者的真实要求

模板可以把安装体验简化到“先完成 WSL 2 / 虚拟化，再安装 Docker，最后双击 Install.cmd”，但无法也不应该替他们复制你的线上身份或私有资产。对方仍需：

新电脑的 Docker 前置步骤见 [Windows Docker / WSL 2 前置指南](DOCKER_WSL2_GUIDE.md)。

1. 创建自己的 QQ 官方机器人并填写自己的 AppID、AppSecret 和 IP 白名单。
2. 创建自己的大模型或云 TTS 配置，并承担自己的 API 费用。
3. 若使用个性化本地语音，自行准备有权使用的 GPT-SoVITS 环境、模型权重和参考音频。
4. 如果 QQ 白名单绑定 VPN 出口，则自行配置自己的 VPN 自动连接。
5. 根据自身电脑和显卡决定是否启用本地语音。

这使模板可以安全复用技术流程，同时不会把你的账号、私聊数据、训练成果或受限素材交给别人。
