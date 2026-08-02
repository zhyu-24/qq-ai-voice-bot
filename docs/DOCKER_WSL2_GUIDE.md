# Windows 上的 Docker Desktop、WSL 2 与虚拟化前置指南

本项目的 AstrBot 运行在 Docker Desktop 中，并使用 **WSL 2 / Linux containers** 后端。新电脑第一次安装时，请先完成本页，再安装或启动 Docker Desktop。

如果 Docker Desktop 显示 **“Virtualization support not detected”**，这不是 Docker 账号问题：登录不会替代 WSL 2 或 CPU 虚拟化设置。个人在本机运行本项目通常不需要登录 Docker 账号；只有 Docker Hub 拉取限流或组织策略要求时才需要登录。

官方参考：

- [Microsoft：安装 WSL](https://learn.microsoft.com/zh-cn/windows/wsl/install)
- [Docker：Windows 安装要求](https://docs.docker.com/desktop/setup/install/windows-install/)

## 第 0 步：确认 Windows 版本

本流程适用于 Windows 11，或 Windows 10 版本 2004 / 内部版本 19041 及以上。按 `Win + R`，输入 `winver` 可查看版本。

## 第 1 步：确认 CPU 虚拟化已开启

1. 按 `Ctrl + Shift + Esc` 打开**任务管理器**。
2. 打开 **性能** → **CPU**。
3. 查看右下角的“虚拟化”。

- 显示“**已启用**”：继续第 2 步。
- 显示“**已禁用**”：重启电脑并进入 BIOS / UEFI，开启下列名称之一后保存退出：
  - Intel：`Intel Virtualization Technology`、`VT-x` 或 `Virtualization Extensions`
  - AMD：`SVM Mode`、`AMD-V` 或 `Secure Virtual Machine`

进入 BIOS 的按键因品牌而异，常见为开机时连续按 `F2`、`Del`、`Esc` 或 `F10`。若电脑由学校或单位管理、BIOS 选项被锁定，请联系设备管理员；在虚拟机里的 Windows 还需要宿主机开启“嵌套虚拟化”。

## 第 2 步：安装 WSL 2

1. 在开始菜单搜索 **PowerShell**。
2. 右键 **Windows PowerShell**，选择“**以管理员身份运行**”。
3. 执行：

```powershell
wsl --install
```

4. 命令完成后**重启 Windows**。
5. 重启后再次以管理员身份打开 PowerShell，执行：

```powershell
wsl --update
wsl --status
```

`wsl --install` 默认会安装 Ubuntu；即使本项目不需要你日常进入 Ubuntu，也请让这一步完成。首次打开 Ubuntu 时若要求创建 Linux 用户名和密码，这些与程序无关，只是作为你个人登录与执行一些操作时的验证，只需要让自己能记住就好（在输入密码时可能框内没有字符出现，这是正常情况，实际你的密码已经输入了，只是没有显示，输完之后只要回车确认即可）按页面提示创建即可。

## 第 3 步：备用安装路线

若 `wsl --install` 显示帮助文本，通常说明 WSL 已安装：先执行 `wsl --update`，再执行 `wsl --status`。

若提示缺少 Windows 功能、安装失败，仍在**管理员 PowerShell**中依次执行：

```powershell
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

随后重启 Windows，并执行：

```powershell
wsl --set-default-version 2
wsl --update
wsl --status
```

若下载长期卡在 `0.0%`，可尝试 Microsoft 推荐的网页下载方式：

```powershell
wsl --install --web-download -d Ubuntu
```

若这个命令提示虚拟化不可用，请返回第 1 步开启 BIOS / UEFI 中的虚拟化。

## 第 4 步：安装并验证 Docker Desktop

1. 下载并安装 [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)。
2. 第一次打开时保持 **Use WSL 2 based engine / Linux containers** 模式。
3. 等待 Docker Desktop 显示 **Engine running**。
4. 在普通 PowerShell 中执行：

```powershell
docker version
```

输出同时出现 `Client` 和 `Server` 两部分，才表示 Docker Engine 已就绪。此时回到项目，双击 `Setup-Center.cmd`，点击“启动 AstrBot”。

## 常见现象快速判断

| 现象 | 优先处理 |
| --- | --- |
| Docker 显示 `Virtualization support not detected` | 先检查任务管理器中的虚拟化，再安装/更新 WSL 2；登录 Docker 不会修复它。 |
| `docker version` 只有 Client、没有 Server | Docker Desktop 尚未启动完成，或 WSL 2 / 虚拟化未就绪。 |
| `wsl --install` 失败 | 确认 Windows 版本，按第 3 步开启两个 Windows 功能并重启。 |
| `wsl --set-default-version 2` 报虚拟机平台或虚拟化错误 | 返回第 1 步，在 BIOS / UEFI 开启 VT-x / SVM。 |
| Docker 能启动但拉取镜像失败 | 这是网络或 Docker Hub 限流问题；可检查网络，必要时再登录 Docker 账号。 |

VPN 不影响本机是否能够启用 WSL 2 或虚拟化；它只可能影响 Docker 镜像下载、模型 API 访问和 QQ IP 白名单。
