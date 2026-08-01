[CmdletBinding()]
param(
    [switch]$ValidateOnly,
    [string]$PreviewPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

$projectRoot = Split-Path -Parent $PSScriptRoot
$scriptsRoot = $PSScriptRoot

function Get-CurrentGsvRoot {
    $configPath = Join-Path $projectRoot 'config\local-runtime.psd1'
    if (-not (Test-Path -LiteralPath $configPath)) {
        return ''
    }
    try {
        $config = Import-PowerShellDataFile -Path $configPath
        return [string]$config.GsvRoot
    }
    catch {
        return ''
    }
}

function ConvertTo-CommandLineArgument {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return ([string][char]34) + ([string][char]34)
    }
    if ($Value.Contains([string][char]34)) {
        throw 'A selected path contains an unsupported quote character.'
    }
    return ([string][char]34) + $Value + ([string][char]34)
}
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="QQ AI Voice Bot Setup Center"
        Width="1180" Height="790" MinWidth="980" MinHeight="680"
        WindowStartupLocation="CenterScreen" Background="#F4F7FB"
        FontFamily="Microsoft YaHei UI">
    <Window.Resources>
        <Style TargetType="{x:Type Button}">
            <Setter Property="Margin" Value="0,6,10,6" />
            <Setter Property="Padding" Value="15,8" />
            <Setter Property="MinHeight" Value="34" />
            <Setter Property="Foreground" Value="#17365D" />
            <Setter Property="Background" Value="#E7F0FC" />
            <Setter Property="BorderBrush" Value="#B9D2F4" />
            <Setter Property="BorderThickness" Value="1" />
            <Setter Property="Cursor" Value="Hand" />
        </Style>
        <Style x:Key="PrimaryButton" TargetType="{x:Type Button}">
            <Setter Property="Margin" Value="0,6,10,6" />
            <Setter Property="Padding" Value="15,8" />
            <Setter Property="MinHeight" Value="34" />
            <Setter Property="Foreground" Value="White" />
            <Setter Property="Background" Value="#2167C9" />
            <Setter Property="BorderBrush" Value="#2167C9" />
            <Setter Property="BorderThickness" Value="1" />
            <Setter Property="Cursor" Value="Hand" />
        </Style>
        <Style TargetType="{x:Type TabItem}">
            <Setter Property="Padding" Value="15,8" />
            <Setter Property="FontWeight" Value="SemiBold" />
        </Style>
        <Style x:Key="Card" TargetType="{x:Type Border}">
            <Setter Property="Background" Value="White" />
            <Setter Property="BorderBrush" Value="#D8E3F1" />
            <Setter Property="BorderThickness" Value="1" />
            <Setter Property="CornerRadius" Value="8" />
            <Setter Property="Padding" Value="18" />
            <Setter Property="Margin" Value="0,0,0,12" />
        </Style>
        <Style x:Key="StepNumber" TargetType="{x:Type Border}">
            <Setter Property="Width" Value="26" />
            <Setter Property="Height" Value="26" />
            <Setter Property="CornerRadius" Value="13" />
            <Setter Property="Background" Value="#2167C9" />
            <Setter Property="Margin" Value="0,0,10,0" />
            <Setter Property="VerticalAlignment" Value="Top" />
        </Style>
    </Window.Resources>
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="84" />
            <RowDefinition Height="*" />
            <RowDefinition Height="194" />
        </Grid.RowDefinitions>

        <Border Grid.Row="0" Background="#122847" Padding="28,16">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*" />
                    <ColumnDefinition Width="330" />
                </Grid.ColumnDefinitions>
                <StackPanel>
                    <TextBlock Text="QQ AI Voice Bot · 可视化配置中心" Foreground="White" FontSize="25" FontWeight="SemiBold" />
                    <TextBlock Text="所有本机动作都在这里完成；密钥仍只在 QQ 开放平台与 AstrBot 的官方界面中填写。" Foreground="#C5D9F5" FontSize="13" Margin="0,4,0,0" />
                </StackPanel>
                <Border Grid.Column="1" Background="#1D3B65" CornerRadius="6" Padding="12,8" VerticalAlignment="Center">
                    <TextBlock Text="建议顺序：Docker → QQ → 大模型 → 人格包 → 语音包 → 常驻" Foreground="#EAF3FF" TextWrapping="Wrap" />
                </Border>
            </Grid>
        </Border>

        <Border Grid.Row="1" Padding="22,18,22,10">
            <TabControl x:Name="MainTabs">
                <TabItem Header="0  开始">
                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                        <Grid Margin="8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*" />
                                <ColumnDefinition Width="360" />
                            </Grid.ColumnDefinitions>
                            <StackPanel Margin="0,0,18,0">
                                <TextBlock Text="先看懂这套机器人" FontSize="22" FontWeight="SemiBold" Foreground="#17365D" />
                                <TextBlock Text="它由三个独立部分组成：QQ 官方机器人负责收发群消息；AstrBot 负责大模型与路由；GPT-SoVITS 负责本机定制语音。三个服务均运行在这台电脑上。" TextWrapping="Wrap" Margin="0,9,0,14" FontSize="14" />
                                <Border Style="{StaticResource Card}">
                                    <StackPanel>
                                        <TextBlock Text="第一次请按下列顺序完成" FontWeight="SemiBold" FontSize="16" />
                                        <TextBlock Text="1. 安装并启动 Docker Desktop。\n2. 在 QQ 开放平台创建自己的官方机器人，并在 AstrBot 绑定。\n3. 在 AstrBot 配置自己的大模型 API。\n4. 可选：安装 GPT-SoVITS，导入有权使用的语音包。\n5. 点击“日常启动”，再测试 @机器人。" TextWrapping="Wrap" LineHeight="25" Margin="0,8,0,0" />
                                    </StackPanel>
                                </Border>
                                <Border Style="{StaticResource Card}">
                                    <StackPanel>
                                        <TextBlock Text="重要边界" FontWeight="SemiBold" FontSize="16" />
                                        <TextBlock Text="本向导不会保存或上传你的 QQ AppSecret、模型 API Key、VPN 账号、聊天记录。不要把这些信息发到群聊、截图或打包文件中。" TextWrapping="Wrap" Foreground="#8A3A16" Margin="0,8,0,0" />
                                    </StackPanel>
                                </Border>
                            </StackPanel>
                            <StackPanel Grid.Column="1">
                                <Border Style="{StaticResource Card}">
                                    <StackPanel>
                                        <TextBlock Text="现在的运行状态" FontSize="17" FontWeight="SemiBold" />
                                        <TextBlock Text="检查 Docker、AstrBot、GPT-SoVITS、TTS 与 GPU。" TextWrapping="Wrap" Margin="0,7,0,8" />
                                        <WrapPanel>
                                            <Button x:Name="BtnInitialStatus" Style="{StaticResource PrimaryButton}" Content="检查本机状态" />
                                            <Button x:Name="BtnOpenDashboardFromStart" Content="打开 AstrBot" />
                                        </WrapPanel>
                                    </StackPanel>
                                </Border>
                                <Border Style="{StaticResource Card}">
                                    <StackPanel>
                                        <TextBlock Text="日常只需记住" FontSize="17" FontWeight="SemiBold" />
                                        <TextBlock Text="电脑必须开机、不能睡眠；Docker 与 GPT-SoVITS 必须在运行。浏览器页面可以关闭。若 QQ 白名单依赖 VPN，启动前请先连接到已登记出口 IP 的 VPN 节点。" TextWrapping="Wrap" LineHeight="22" Margin="0,7,0,0" />
                                    </StackPanel>
                                </Border>
                            </StackPanel>
                        </Grid>
                    </ScrollViewer>
                </TabItem>

                <TabItem Header="1  基础环境">
                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                        <StackPanel Margin="8">
                            <TextBlock Text="Docker Desktop 与 AstrBot" FontSize="22" FontWeight="SemiBold" Foreground="#17365D" />
                            <TextBlock Text="Docker 是 AstrBot 的运行底座。安装完成后首次打开 Docker Desktop，等待左下角显示 Engine running，再回到这里。" TextWrapping="Wrap" Margin="0,9,0,14" FontSize="14" />
                            <Border Style="{StaticResource Card}">
                                <StackPanel>
                                    <TextBlock Text="下载 Docker Desktop" FontSize="17" FontWeight="SemiBold" />
                                    <TextBlock Text="推荐 Windows 的 WSL 2 / Linux containers 模式。安装过程若提示启用 WSL，请按 Docker 官方提示完成并重启。" TextWrapping="Wrap" Margin="0,7,0,8" />
                                    <WrapPanel>
                                        <Button x:Name="BtnDockerDocs" Style="{StaticResource PrimaryButton}" Content="打开官方安装说明" />
                                        <Button x:Name="BtnDockerDirect" Content="官方下载 Docker Desktop" />
                                    </WrapPanel>
                                </StackPanel>
                            </Border>
                            <Border Style="{StaticResource Card}">
                                <StackPanel>
                                    <TextBlock Text="启动基础机器人" FontSize="17" FontWeight="SemiBold" />
                                    <TextBlock Text="此按钮会创建本机运行配置（如尚未创建）、启动 Docker / AstrBot，并在日志区显示结果。首次拉取镜像可能需要几分钟。" TextWrapping="Wrap" Margin="0,7,0,8" />
                                    <WrapPanel>
                                        <Button x:Name="BtnStartBase" Style="{StaticResource PrimaryButton}" Content="启动 AstrBot" />
                                        <Button x:Name="BtnOpenDashboard" Content="打开 AstrBot 仪表盘" />
                                        <Button x:Name="BtnDockerStatus" Content="检查 Docker 状态" />
                                    </WrapPanel>
                                </StackPanel>
                            </Border>
                            <Border Style="{StaticResource Card}">
                                <StackPanel>
                                    <TextBlock Text="首次进入 AstrBot" FontSize="17" FontWeight="SemiBold" />
                                    <TextBlock Text="浏览器打开 http://localhost:6185 后，先注册本机管理员账号。这个账号仅用于管理本机 AstrBot，不等同于 QQ 账号。" TextWrapping="Wrap" Margin="0,7,0,0" />
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </TabItem>

                <TabItem Header="2  QQ 官方机器人">
                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                        <StackPanel Margin="8">
                            <TextBlock Text="在 QQ 开放平台完成账号接入" FontSize="22" FontWeight="SemiBold" Foreground="#17365D" />
                            <TextBlock Text="这部分必须使用你自己的 QQ 开放平台账号。向导只打开相应页面并说明要填什么，不要求你把凭据填进项目文件。" TextWrapping="Wrap" Margin="0,9,0,12" FontSize="14" />
                            <Border Style="{StaticResource Card}">
                                <StackPanel>
                                    <DockPanel Margin="0,0,0,8"><Border Style="{StaticResource StepNumber}" DockPanel.Dock="Left"><TextBlock Text="1" Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center" FontWeight="Bold" /></Border><TextBlock Text="创建机器人并设置资料" FontWeight="SemiBold" FontSize="16" VerticalAlignment="Center" /></DockPanel>
                                    <TextBlock Text="打开“我的机器人” → 创建机器人。进入账号信息，设置昵称、简介和头像；QQ 客户端的展示同步有时会延迟，请等待平台审核或缓存刷新。" TextWrapping="Wrap" />
                                    <Button x:Name="BtnOpenQqPlatform" Style="{StaticResource PrimaryButton}" Content="打开 QQ 开放平台 · 我的机器人" HorizontalAlignment="Left" />
                                </StackPanel>
                            </Border>
                            <Border Style="{StaticResource Card}">
                                <StackPanel>
                                    <DockPanel Margin="0,0,0,8"><Border Style="{StaticResource StepNumber}" DockPanel.Dock="Left"><TextBlock Text="2" Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center" FontWeight="Bold" /></Border><TextBlock Text="开发设置：选择 WebSocket，保存 AppID / AppSecret" FontWeight="SemiBold" FontSize="16" VerticalAlignment="Center" /></DockPanel>
                                    <TextBlock Text="在“开发设置”中把事件订阅方式设为 WebSocket。复制 AppID 和 AppSecret；它们随后只填写在 AstrBot 的 QQ 官方机器人适配器里。AppSecret 相当于密码，不能发给任何人。" TextWrapping="Wrap" />
                                </StackPanel>
                            </Border>
                            <Border Style="{StaticResource Card}">
                                <StackPanel>
                                    <DockPanel Margin="0,0,0,8"><Border Style="{StaticResource StepNumber}" DockPanel.Dock="Left"><TextBlock Text="3" Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center" FontWeight="Bold" /></Border><TextBlock Text="服务器 IP 白名单：登记当前公网出口 IP" FontWeight="SemiBold" FontSize="16" VerticalAlignment="Center" /></DockPanel>
                                    <TextBlock Text="白名单填写的是当前 VPN / 网络的公网出口 IPv4，不是 127.0.0.1、路由器内网地址或手机热点地址。若换 VPN 节点或关闭 VPN，出口 IP 改变后就要回 QQ 平台更新白名单。WebSocket 不需要开放家庭路由器端口。" TextWrapping="Wrap" />
                                    <WrapPanel><Button x:Name="BtnVpnStatus" Style="{StaticResource PrimaryButton}" Content="检测当前出口 IP" /><Button x:Name="BtnCopyQqChecklist" Content="复制 QQ 配置清单" /></WrapPanel>
                                </StackPanel>
                            </Border>
                            <Border Style="{StaticResource Card}">
                                <StackPanel>
                                    <DockPanel Margin="0,0,0,8"><Border Style="{StaticResource StepNumber}" DockPanel.Dock="Left"><TextBlock Text="4" Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center" FontWeight="Bold" /></Border><TextBlock Text="开发体验用户与 AstrBot 接入" FontWeight="SemiBold" FontSize="16" VerticalAlignment="Center" /></DockPanel>
                                    <TextBlock Text="在 QQ 平台的“开发体验号设置”添加你用于测试的 QQ 号。然后打开 AstrBot → 机器人，创建 QQ 官方机器人适配器，填入刚才的 AppID / AppSecret 并保存。最后在 QQ 中 @机器人测试。" TextWrapping="Wrap" />
                                    <Button x:Name="BtnOpenAstrBotPlatforms" Style="{StaticResource PrimaryButton}" Content="打开 AstrBot · 机器人配置" HorizontalAlignment="Left" />
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </TabItem>

                <TabItem Header="3  大模型">
                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                        <StackPanel Margin="8">
                            <TextBlock Text="给机器人接入对话大模型" FontSize="22" FontWeight="SemiBold" Foreground="#17365D" />
                            <TextBlock Text="模型可以是云端 API，也可以是你自己运行的服务。这里不会代替你选择或购买模型；完成后直接在 AstrBot 聊天页测试。" TextWrapping="Wrap" Margin="0,9,0,14" FontSize="14" />
                            <Border Style="{StaticResource Card}">
                                <StackPanel>
                                    <TextBlock Text="按这个顺序配置" FontSize="17" FontWeight="SemiBold" />
                                    <TextBlock Text="1. AstrBot → 模型提供商，新增与你的服务兼容的提供商（常见为 OpenAI API 兼容）。\n2. 输入服务 Base URL、你的 API Key、模型名称；保存后把它选为默认对话模型。\n3. 在聊天页发送一句“只回复：连接成功。”确认没有报错。\n4. 再到 人格 / Persona 页面导入自己的中性或原创人设提示词。" TextWrapping="Wrap" LineHeight="25" Margin="0,7,0,8" />
                                    <TextBlock Text="新手选择：默认优先选文本对话 / Chat / Instruct 模型；Thinking、R1 一类只作为复杂问题备用。Embedding、图像、视频、ASR、TTS、Rerank 不能当默认对话模型。" TextWrapping="Wrap" Foreground="#4A5F78" Margin="0,0,0,8" />
                                    <WrapPanel>
                                        <Button x:Name="BtnOpenProviders" Style="{StaticResource PrimaryButton}" Content="打开 AstrBot · 模型提供商" />
                                        <Button x:Name="BtnOpenChat" Content="打开 AstrBot · 测试聊天" />
                                        <Button x:Name="BtnOpenPersona" Content="打开 AstrBot · 人格" />
                                        <Button x:Name="BtnOpenModelGuide" Content="打开模型 / API 新手指南" />
                                    </WrapPanel>
                                </StackPanel>
                            </Border>
                            <Border Style="{StaticResource Card}">
                                <StackPanel>
                                    <TextBlock Text="常见误区" FontSize="17" FontWeight="SemiBold" />
                                    <TextBlock Text="模型名称必须是服务商实际支持的 ID；Base URL 不要把聊天网页地址当作 API 地址；若模型输出了思考过程，换用不返回思考文本的模型，或按服务商文档关闭该输出。" TextWrapping="Wrap" Margin="0,7,0,0" />
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </TabItem>

                <TabItem Header="4  本地语音">
                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                        <StackPanel Margin="8">
                            <TextBlock Text="GPT-SoVITS 定制语音（可选）" FontSize="22" FontWeight="SemiBold" Foreground="#17365D" />
                            <TextBlock Text="基础包可以只用通用 TTS；导入语音包后才能使用本机定制声线。语音包免去训练，但生成每条语音仍需要本机 GPU 推理。" TextWrapping="Wrap" Margin="0,9,0,14" FontSize="14" />
                            <Border Style="{StaticResource Card}">
                                <StackPanel>
                                    <TextBlock Text="A. 下载匹配的 GPT-SoVITS 运行环境" FontSize="17" FontWeight="SemiBold" />
                                    <TextBlock Text="当前 v2ProPlus 系列语音包需要相同世代的 GPT-SoVITS 运行环境。显卡为 NVIDIA 50 系时选择发布页标明 nvidia50 / 50 系支持的包；不要用 v3、v4 的运行环境来加载 v2ProPlus 权重。" TextWrapping="Wrap" Margin="0,7,0,8" />
                                    <WrapPanel>
                                        <Button x:Name="BtnGsvRelease" Style="{StaticResource PrimaryButton}" Content="有梯子：打开官方发布页" />
                                        <Button x:Name="BtnGsvChina" Content="大陆下载：ModelScope 50 系包" />
                                        <Button x:Name="BtnGsvDocs" Content="打开中文说明" />
                                    </WrapPanel>
                                </StackPanel>
                            </Border>
                            <Border Style="{StaticResource Card}">
                                <StackPanel>
                                    <TextBlock Text="B. 选择已解压的 GPT-SoVITS 文件夹" FontSize="17" FontWeight="SemiBold" />
                                    <TextBlock Text="请选择其中能看到 api_v2.py、runtime\python.exe、GPT_SoVITS\configs\tts_infer.yaml 的最外层文件夹。" TextWrapping="Wrap" Margin="0,7,0,6" />
                                    <DockPanel LastChildFill="True"><Button x:Name="BtnBrowseGsv" Content="浏览..." DockPanel.Dock="Right" /><Button x:Name="BtnSaveGsv" Style="{StaticResource PrimaryButton}" Content="保存并检查" DockPanel.Dock="Right" /><TextBox x:Name="TxtGsvRoot" IsReadOnly="False" Padding="8" VerticalContentAlignment="Center" Margin="0,6,10,6" /></DockPanel>
                                </StackPanel>
                            </Border>
                            <Border Style="{StaticResource Card}">
                                <StackPanel>
                                    <TextBlock Text="C. 导入已授权的语音包 ZIP" FontSize="17" FontWeight="SemiBold" />
                                    <TextBlock Text="导入器会校验哈希、复制权重和参考音频、备份 AstrBot 配置，并启用“文字 + 语音”。不会触碰 QQ 凭据或大模型设置。导入后会自动启动服务。" TextWrapping="Wrap" Margin="0,7,0,6" />
                                    <DockPanel LastChildFill="True"><Button x:Name="BtnBrowseVoicePack" Content="选择 ZIP..." DockPanel.Dock="Right" /><Button x:Name="BtnImportVoicePack" Style="{StaticResource PrimaryButton}" Content="导入语音包" DockPanel.Dock="Right" /><TextBox x:Name="TxtVoicePack" IsReadOnly="True" Padding="8" VerticalContentAlignment="Center" Margin="0,6,10,6" /></DockPanel>
                                </StackPanel>
                            </Border>
                            <Border Style="{StaticResource Card}">
                                <StackPanel>
                                    <TextBlock Text="D. 语音自检" FontSize="17" FontWeight="SemiBold" />
                                    <TextBlock Text="导入后点击状态检查；应看到 GPT-SoVITS API、TTS enabled、Text plus voice output 与两项权重均为 OK。然后在 QQ 中 @机器人发一句短句测试。" TextWrapping="Wrap" Margin="0,7,0,8" />
                                    <WrapPanel><Button x:Name="BtnVoiceStatus" Style="{StaticResource PrimaryButton}" Content="检查语音状态" /><Button x:Name="BtnOpenGsvDocs" Content="打开本机 GPT-SoVITS API 文档" /></WrapPanel>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </TabItem>

                <TabItem Header="5  人格包">
                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                        <StackPanel Margin="8">
                            <TextBlock Text="导入文本人格包（可选）" FontSize="22" FontWeight="SemiBold" Foreground="#17365D" />
                            <TextBlock Text="人格包只包含系统提示词与校验元数据。它不包含 QQ 凭据、模型 API Key、聊天记录、语音权重、音频或图片；导入时也不会执行 ZIP 内的任何脚本。" TextWrapping="Wrap" Margin="0,9,0,14" FontSize="14" />
                            <Border Style="{StaticResource Card}">
                                <StackPanel>
                                    <TextBlock Text="A. 选择人格包 ZIP" FontSize="17" FontWeight="SemiBold" />
                                    <TextBlock Text="向导会先验证 ZIP 的清单、文件白名单与系统提示词 SHA-256；验证通过后，会把提示词复制到剪贴板并打开 AstrBot 的官方人格页面。" TextWrapping="Wrap" Margin="0,7,0,6" />
                                    <DockPanel LastChildFill="True"><Button x:Name="BtnBrowsePersonaPack" Content="选择人格包 ZIP..." DockPanel.Dock="Right" /><Button x:Name="BtnPreparePersonaPack" Style="{StaticResource PrimaryButton}" Content="安全准备并打开人格页" DockPanel.Dock="Right" /><TextBox x:Name="TxtPersonaPack" IsReadOnly="True" Padding="8" VerticalContentAlignment="Center" Margin="0,6,10,6" /></DockPanel>
                                </StackPanel>
                            </Border>
                            <Border Style="{StaticResource Card}">
                                <StackPanel>
                                    <TextBlock Text="B. 在 AstrBot 保存人格" FontSize="17" FontWeight="SemiBold" />
                                    <TextBlock Text="打开页面后，新建人格；使用日志中显示的 Persona ID，粘贴已经复制的完整系统提示词并保存。这里保留官方 UI 作为唯一的人格数据库写入入口，因此不会要求或保存你的管理登录令牌。" TextWrapping="Wrap" Margin="0,7,0,8" />
                                    <Button x:Name="BtnOpenPersonaFromPack" Content="打开 AstrBot · 人格" HorizontalAlignment="Left" />
                                </StackPanel>
                            </Border>
                            <Border Style="{StaticResource Card}">
                                <StackPanel>
                                    <TextBlock Text="C. 设为默认人格" FontSize="17" FontWeight="SemiBold" />
                                    <TextBlock Text="确认刚才的人格已保存后再点此按钮。它只会备份并更新本机 AstrBot 配置中的默认人格 ID，不会改动人格数据库、QQ 配置或模型设置。随后执行一次日常启动，新的会话才会使用它。" TextWrapping="Wrap" Margin="0,7,0,8" />
                                    <Button x:Name="BtnSetDefaultPersona" Style="{StaticResource PrimaryButton}" Content="设为默认人格（已保存后）" HorizontalAlignment="Left" />
                                </StackPanel>
                            </Border>
                            <Border Style="{StaticResource Card}">
                                <StackPanel>
                                    <TextBlock Text="为什么不是一键写入数据库？" FontSize="17" FontWeight="SemiBold" />
                                    <TextBlock Text="AstrBot 的人格记录会随版本升级变化。通过官方人格页面保存，能避免导入器直接改数据库产生兼容或覆盖风险；已有聊天也可能保留自己原先的人格，新建会话再测试即可。" TextWrapping="Wrap" Margin="0,7,0,0" />
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </TabItem>
                <TabItem Header="6  启动与常驻">
                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                        <StackPanel Margin="8">
                            <TextBlock Text="日常使用与登录后自动启动" FontSize="22" FontWeight="SemiBold" Foreground="#17365D" />
                            <Border Style="{StaticResource Card}" Margin="0,14,0,12">
                                <StackPanel>
                                    <TextBlock Text="日常启动" FontSize="17" FontWeight="SemiBold" />
                                    <TextBlock Text="双击 Setup-Center.cmd 后点击下面的“日常启动”即可，无需保持网页或终端窗口开启。浏览器页面关闭不会影响机器人。" TextWrapping="Wrap" Margin="0,7,0,8" />
                                    <WrapPanel><Button x:Name="BtnDailyStart" Style="{StaticResource PrimaryButton}" Content="日常启动（Docker + AstrBot + 语音）" /><Button x:Name="BtnDailyStop" Content="停止机器人服务" /><Button x:Name="BtnDailyStatus" Content="再次检查状态" /></WrapPanel>
                                </StackPanel>
                            </Border>
                            <Border Style="{StaticResource Card}">
                                <StackPanel>
                                    <TextBlock Text="登录后自动启动" FontSize="17" FontWeight="SemiBold" />
                                    <TextBlock Text="确认手动启动已经成功后，可注册 Windows 登录后的自动启动任务。它会先等待一段时间，再启动 Docker、GPT-SoVITS 和 AstrBot。请让 VPN 客户端本身也设为登录后自动连接；电脑关机、休眠、断网或 VPN 节点变更时机器人会离线。" TextWrapping="Wrap" Margin="0,7,0,8" />
                                    <WrapPanel><Button x:Name="BtnInstallAutostart" Style="{StaticResource PrimaryButton}" Content="启用登录后自动启动" /><Button x:Name="BtnUninstallAutostart" Content="取消登录后自动启动" /></WrapPanel>
                                </StackPanel>
                            </Border>
                            <Border Style="{StaticResource Card}">
                                <StackPanel>
                                    <TextBlock Text="VPN / 白名单快速判断" FontSize="17" FontWeight="SemiBold" />
                                    <TextBlock Text="如果机器人突然不响应，而本机服务均正常，最先确认 VPN 是否仍在正确节点，并用“检测当前出口 IP”比对 QQ 平台白名单。只要公网出口 IP 不变，VPN 页面不必一直开着。" TextWrapping="Wrap" Margin="0,7,0,8" />
                                    <Button x:Name="BtnRunEgressCheck" Style="{StaticResource PrimaryButton}" Content="检测当前出口 IP" HorizontalAlignment="Left" />
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </TabItem>

                <TabItem Header="7  分享项目">
                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                        <StackPanel Margin="8">
                            <TextBlock Text="安全地分享给其他人" FontSize="22" FontWeight="SemiBold" Foreground="#17365D" />
                            <TextBlock Text="推荐发三个互不混放的包：基础环境包 + 可选文本人格包 + 可选已授权语音包。下载者先安装基础包，再按需导入人格和语音，不需要重新训练。" TextWrapping="Wrap" Margin="0,9,0,14" FontSize="14" />
                            <Border Style="{StaticResource Card}">
                                <StackPanel>
                                    <TextBlock Text="基础环境包" FontSize="17" FontWeight="SemiBold" />
                                    <TextBlock Text="只包含向导、启动脚本、Docker 配置和中性人格示例。它绝不包含你的 QQ 账号、AppSecret、模型 API Key、聊天数据、运行日志、个人音频或模型权重。" TextWrapping="Wrap" Margin="0,7,0,8" />
                                    <WrapPanel><Button x:Name="BtnCheckSharePackage" Style="{StaticResource PrimaryButton}" Content="检查基础包是否安全" /><Button x:Name="BtnExportSharePackage" Content="导出基础环境 ZIP" /></WrapPanel>
                                </StackPanel>
                            </Border>
                            <Border Style="{StaticResource Card}">
                                <StackPanel>
                                    <TextBlock Text="可选语音包" FontSize="17" FontWeight="SemiBold" />
                                    <TextBlock Text="仅在你确实拥有权利并获得传播授权时才导出或分享。语音包会包含权重和参考音频；它仍不含 QQ 凭据、模型 API Key、人格或聊天记录。" TextWrapping="Wrap" Margin="0,7,0,8" />
                                    <WrapPanel><Button x:Name="BtnExportVoicePack" Style="{StaticResource PrimaryButton}" Content="导出已授权语音包" /><Button x:Name="BtnOpenReleaseFolder" Content="打开 release 文件夹" /></WrapPanel>
                                </StackPanel>
                            </Border>
                            <Border Style="{StaticResource Card}">
                                <StackPanel>
                                    <TextBlock Text="可选人格包" FontSize="17" FontWeight="SemiBold" />
                                    <TextBlock Text="人格包只包含可分享的文本提示词和校验信息；不含 QQ 凭据、模型 Key、聊天记录、媒体、模型权重或训练素材。下载者会在官方 AstrBot 人格页保存它，再由向导设置为默认人格。" TextWrapping="Wrap" Margin="0,7,0,8" />
                                    <WrapPanel><Button x:Name="BtnCheckPersonaPack" Style="{StaticResource PrimaryButton}" Content="检查人格包是否安全" /><Button x:Name="BtnExportPersonaPack" Content="导出人格包 ZIP" /></WrapPanel>
                                </StackPanel>
                            </Border>
                            <Border Style="{StaticResource Card}">
                                <StackPanel>
                                    <TextBlock Text="给下载者的一句话说明" FontSize="17" FontWeight="SemiBold" />
                                    <TextBlock Text="“先解压基础包，双击 Setup-Center.cmd，按页签完成 Docker、QQ、模型配置；需要时再导入文本人格包和语音包。所有账号、密钥与白名单都由你自己创建，不要把它们发给我。”" TextWrapping="Wrap" Margin="0,7,0,8" />
                                    <Button x:Name="BtnCopyDownloadInstructions" Content="复制这段说明" HorizontalAlignment="Left" />
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </TabItem>
            </TabControl>
        </Border>

        <Border Grid.Row="2" Background="#10223B" Padding="22,12">
            <Grid>
                <Grid.RowDefinitions><RowDefinition Height="26" /><RowDefinition Height="*" /></Grid.RowDefinitions>
                <DockPanel Grid.Row="0"><TextBlock x:Name="TxtTaskState" Text="就绪。点击任意按钮后，执行结果会显示在这里。" Foreground="#D7E8FF" VerticalAlignment="Center" /><ProgressBar x:Name="TaskProgress" Width="170" Height="8" IsIndeterminate="True" Visibility="Collapsed" DockPanel.Dock="Right" VerticalAlignment="Center" /></DockPanel>
                <TextBox x:Name="TxtOutput" Grid.Row="1" Background="#0B1728" Foreground="#DDF0FF" BorderBrush="#284A74" BorderThickness="1" FontFamily="Consolas" FontSize="12" TextWrapping="Wrap" AcceptsReturn="True" IsReadOnly="True" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" Padding="9" />
            </Grid>
        </Border>
    </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$script:OutputBox = $window.FindName('TxtOutput')
$script:TaskState = $window.FindName('TxtTaskState')
$script:TaskProgress = $window.FindName('TaskProgress')
$script:GsvRootTextBox = $window.FindName('TxtGsvRoot')
$script:VoicePackTextBox = $window.FindName('TxtVoicePack')
$script:PersonaPackTextBox = $window.FindName('TxtPersonaPack')
$script:GsvRootTextBox.Text = Get-CurrentGsvRoot

function Add-SetupLog {
    param([Parameter(Mandatory = $true)][string]$Text)

    $prefix = Get-Date -Format 'HH:mm:ss'
    $script:OutputBox.AppendText("[$prefix] $Text`r`n")
    $script:OutputBox.ScrollToEnd()
}

function Set-SetupBusy {
    param([bool]$Busy, [string]$Status = '就绪。')

    $script:TaskProgress.Visibility = if ($Busy) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
    $script:TaskState.Text = $Status
}

function Open-SetupUrl {
    param([Parameter(Mandatory = $true)][string]$Url)

    try {
        Start-Process -FilePath $Url
        Add-SetupLog "已在浏览器打开：$Url"
    }
    catch {
        [System.Windows.MessageBox]::Show("无法打开链接：$Url`r`n$($_.Exception.Message)", '无法打开浏览器', 'OK', 'Error') | Out-Null
    }
}

function Open-SetupFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    try {
        if (-not (Test-Path -LiteralPath $Path)) {
            throw "文件不存在：$Path"
        }
        Start-Process -FilePath $Path
        Add-SetupLog "已打开本地说明：$Path"
    }
    catch {
        [System.Windows.MessageBox]::Show("无法打开本地说明：$Path`r`n$($_.Exception.Message)", '无法打开说明', 'OK', 'Error') | Out-Null
    }
}
$script:TaskWorker = New-Object System.ComponentModel.BackgroundWorker
$script:TaskWorker.add_DoWork({
    param($sender, $eventArgs)

    $task = $eventArgs.Argument
    try {
        $parts = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $task.FilePath) + @($task.Arguments)
        $quoteCharacter = [string][char]34
        $argumentLine = (($parts | ForEach-Object {
            $argumentValue = [string]$_
            if ($argumentValue.Contains($quoteCharacter)) {
                throw 'A selected path contains an unsupported quote character.'
            }
            $quoteCharacter + $argumentValue + $quoteCharacter
        }) -join ' ')
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = (Get-Command powershell.exe).Source
        $startInfo.Arguments = $argumentLine
        $startInfo.WorkingDirectory = $task.WorkingDirectory
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        [void]$process.Start()
        $standardOutput = $process.StandardOutput.ReadToEnd()
        $standardError = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        $eventArgs.Result = [pscustomobject]@{
            Title = $task.Title
            ExitCode = $process.ExitCode
            Output = $standardOutput
            ErrorOutput = $standardError
        }
    }
    catch {
        $eventArgs.Result = [pscustomobject]@{
            Title = $task.Title
            ExitCode = -1
            Output = ''
            ErrorOutput = $_.Exception.Message
        }
    }
})

$script:TaskWorker.add_RunWorkerCompleted({
    param($sender, $eventArgs)

    Set-SetupBusy -Busy $false
    if ($null -ne $eventArgs.Error) {
        Add-SetupLog "[FAIL] 后台任务异常：$($eventArgs.Error.Exception.Message)"
        $script:TaskState.Text = '执行失败，请查看日志。'
        return
    }
    $result = $eventArgs.Result
    if ($null -eq $result) {
        Add-SetupLog '[FAIL] 后台任务没有返回结果。'
        $script:TaskState.Text = '执行失败，请查看日志。'
        return
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$result.Output)) {
        Add-SetupLog $result.Output.TrimEnd()
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$result.ErrorOutput)) {
        Add-SetupLog "[stderr] $($result.ErrorOutput.TrimEnd())"
    }
    if ([int]$result.ExitCode -eq 0) {
        $script:TaskState.Text = "$($result.Title) 已完成。"
        Add-SetupLog "[OK] $($result.Title) 已完成。"
    }
    else {
        $script:TaskState.Text = "$($result.Title) 失败（退出码 $($result.ExitCode)）。"
        Add-SetupLog "[FAIL] $($result.Title) 失败（退出码 $($result.ExitCode)）。"
    }
})

function Invoke-SetupScript {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @()
    )

    if ($script:TaskWorker.IsBusy) {
        [System.Windows.MessageBox]::Show('已有任务正在执行，请等待它完成。', '请稍候', 'OK', 'Information') | Out-Null
        return
    }
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        [System.Windows.MessageBox]::Show("找不到需要的脚本：$FilePath", '缺少文件', 'OK', 'Error') | Out-Null
        return
    }
    Set-SetupBusy -Busy $true -Status "$Title 正在执行，请稍候……"
    Add-SetupLog "[START] $Title"
    $script:TaskWorker.RunWorkerAsync([pscustomobject]@{
        Title = $Title
        FilePath = $FilePath
        Arguments = @($Arguments)
        WorkingDirectory = $projectRoot
    })
}

function Select-GsvRoot {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = '选择 GPT-SoVITS 最外层文件夹（其中应有 api_v2.py）'
    $dialog.ShowNewFolderButton = $false
    if (-not [string]::IsNullOrWhiteSpace($script:GsvRootTextBox.Text) -and (Test-Path -LiteralPath $script:GsvRootTextBox.Text)) {
        $dialog.SelectedPath = $script:GsvRootTextBox.Text
    }
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:GsvRootTextBox.Text = $dialog.SelectedPath
    }
}

function Select-VoicePack {
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Filter = 'Voice-pack ZIP (*.zip)|*.zip|All files (*.*)|*.*'
    $dialog.Title = '选择已授权的本地语音包 ZIP'
    if ($dialog.ShowDialog()) {
        $script:VoicePackTextBox.Text = $dialog.FileName
    }
}

function Select-PersonaPack {
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Filter = 'Persona-pack ZIP (*.zip)|*.zip|All files (*.*)|*.*'
    $dialog.Title = '选择人格包 ZIP'
    if ($dialog.ShowDialog()) {
        $script:PersonaPackTextBox.Text = $dialog.FileName
    }
}
function Copy-SetupText {
    param([Parameter(Mandatory = $true)][string]$Text)
    [System.Windows.Clipboard]::SetText($Text)
    Add-SetupLog '[OK] 已复制到剪贴板。'
}

function Invoke-PublisherAction {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string]$RequiredPath
    )

    if (-not (Test-Path -LiteralPath $RequiredPath) -or -not (Test-Path -LiteralPath $FilePath)) {
        $message = '这是发布者源项目的工具。下载者只需使用基础包和语音包，不需要再次导出。'
        [System.Windows.MessageBox]::Show($message, '发布者工具', 'OK', 'Information') | Out-Null
        Add-SetupLog "[INFO] $message"
        return
    }
    Invoke-SetupScript -Title $Title -FilePath $FilePath
}

$statusScript = Join-Path $scriptsRoot 'Get-LocalBotStatus.ps1'
$startScript = Join-Path $scriptsRoot 'Start-LocalBot.ps1'
$stopScript = Join-Path $scriptsRoot 'Stop-LocalBot.ps1'

$window.FindName('BtnInitialStatus').Add_Click({ Invoke-SetupScript -Title '本机状态检查' -FilePath $statusScript })
$window.FindName('BtnDockerStatus').Add_Click({ Invoke-SetupScript -Title 'Docker 状态检查' -FilePath $statusScript })
$window.FindName('BtnVoiceStatus').Add_Click({ Invoke-SetupScript -Title '语音状态检查' -FilePath $statusScript })
$window.FindName('BtnDailyStatus').Add_Click({ Invoke-SetupScript -Title '本机状态检查' -FilePath $statusScript })
$window.FindName('BtnVpnStatus').Add_Click({ Invoke-SetupScript -Title '公网出口 IP 检测' -FilePath $statusScript -Arguments @('-CheckVpnEgress') })
$window.FindName('BtnRunEgressCheck').Add_Click({ Invoke-SetupScript -Title '公网出口 IP 检测' -FilePath $statusScript -Arguments @('-CheckVpnEgress') })

$window.FindName('BtnDockerDocs').Add_Click({ Open-SetupUrl 'https://docs.docker.com/desktop/setup/install/windows-install/' })
$window.FindName('BtnDockerDirect').Add_Click({ Open-SetupUrl 'https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe' })
$window.FindName('BtnOpenDashboardFromStart').Add_Click({ Open-SetupUrl 'http://localhost:6185' })
$window.FindName('BtnOpenDashboard').Add_Click({ Open-SetupUrl 'http://localhost:6185' })
$window.FindName('BtnOpenAstrBotPlatforms').Add_Click({ Open-SetupUrl 'http://localhost:6185/#/platforms' })
$window.FindName('BtnOpenProviders').Add_Click({ Open-SetupUrl 'http://localhost:6185/#/providers' })
$window.FindName('BtnOpenModelGuide').Add_Click({ Open-SetupFile (Join-Path $projectRoot 'docs\MODEL_AND_API_GUIDE.md') })
$window.FindName('BtnOpenChat').Add_Click({ Open-SetupUrl 'http://localhost:6185/#/chat' })
$window.FindName('BtnOpenPersona').Add_Click({ Open-SetupUrl 'http://localhost:6185/#/persona' })
$window.FindName('BtnOpenQqPlatform').Add_Click({ Open-SetupUrl 'https://q.qq.com/qqbot/#/apps' })
$window.FindName('BtnGsvRelease').Add_Click({ Open-SetupUrl 'https://github.com/RVC-Boss/GPT-SoVITS/releases' })
$window.FindName('BtnGsvChina').Add_Click({ Open-SetupUrl 'https://www.modelscope.cn/models/FlowerCry/gpt-sovits-7z-pacakges/resolve/master/GPT-SoVITS-v2pro-20250604-nvidia50.7z' })
$window.FindName('BtnGsvDocs').Add_Click({ Open-SetupUrl 'https://github.com/RVC-Boss/GPT-SoVITS/blob/main/docs/cn/README.md' })
$window.FindName('BtnOpenGsvDocs').Add_Click({ Open-SetupUrl 'http://127.0.0.1:9880/docs' })

$window.FindName('BtnStartBase').Add_Click({
    $installScript = Join-Path $scriptsRoot 'Install.ps1'
    if (Test-Path -LiteralPath $installScript) {
        Invoke-SetupScript -Title '启动 AstrBot' -FilePath $installScript -Arguments @('-NoBrowser')
    }
    else {
        Invoke-SetupScript -Title '启动 AstrBot' -FilePath $startScript -Arguments @('-StartupDelaySeconds', '0')
    }
})
$window.FindName('BtnDailyStart').Add_Click({ Invoke-SetupScript -Title '日常启动' -FilePath $startScript })
$window.FindName('BtnDailyStop').Add_Click({ Invoke-SetupScript -Title '停止机器人服务' -FilePath $stopScript })
$window.FindName('BtnBrowseGsv').Add_Click({ Select-GsvRoot })
$window.FindName('BtnSaveGsv').Add_Click({
    if ([string]::IsNullOrWhiteSpace($script:GsvRootTextBox.Text)) {
        [System.Windows.MessageBox]::Show('请先选择 GPT-SoVITS 文件夹。', '还没有选择文件夹', 'OK', 'Information') | Out-Null
        return
    }
    Invoke-SetupScript -Title '保存 GPT-SoVITS 路径' -FilePath (Join-Path $scriptsRoot 'Set-GsvRoot.ps1') -Arguments @('-GsvRoot', $script:GsvRootTextBox.Text)
})
$window.FindName('BtnBrowseVoicePack').Add_Click({ Select-VoicePack })
$window.FindName('BtnImportVoicePack').Add_Click({
    if ([string]::IsNullOrWhiteSpace($script:VoicePackTextBox.Text)) {
        [System.Windows.MessageBox]::Show('请先选择一个 .zip 语音包。', '还没有选择语音包', 'OK', 'Information') | Out-Null
        return
    }
    Invoke-SetupScript -Title '导入本地语音包' -FilePath (Join-Path $scriptsRoot 'Import-VoicePackZip.ps1') -Arguments @('-VoicePackZip', $script:VoicePackTextBox.Text)
})
$window.FindName('BtnBrowsePersonaPack').Add_Click({ Select-PersonaPack })
$window.FindName('BtnPreparePersonaPack').Add_Click({
    if ([string]::IsNullOrWhiteSpace($script:PersonaPackTextBox.Text)) {
        [System.Windows.MessageBox]::Show('请先选择一个 .zip 人格包。', '还没有选择人格包', 'OK', 'Information') | Out-Null
        return
    }
    Invoke-SetupScript -Title '安全准备人格包' -FilePath (Join-Path $scriptsRoot 'Import-PersonaPackZip.ps1') -Arguments @('-PersonaPackZip', $script:PersonaPackTextBox.Text)
})
$window.FindName('BtnOpenPersonaFromPack').Add_Click({ Open-SetupUrl 'http://localhost:6185/#/persona' })
$window.FindName('BtnSetDefaultPersona').Add_Click({
    if ([string]::IsNullOrWhiteSpace($script:PersonaPackTextBox.Text)) {
        [System.Windows.MessageBox]::Show('请先选择并保存对应的人格包。', '还没有选择人格包', 'OK', 'Information') | Out-Null
        return
    }
    $confirmationText = '确认你已经在 AstrBot 的人格页面中使用该包显示的 Persona ID 保存了人格吗？' + [Environment]::NewLine + [Environment]::NewLine + '此操作只会备份并设置默认人格 ID。'
    $confirmation = [System.Windows.MessageBox]::Show($confirmationText, '确认已保存人格', 'YesNo', 'Question')
    if ($confirmation -eq [System.Windows.MessageBoxResult]::Yes) {
        Invoke-SetupScript -Title '设为默认人格' -FilePath (Join-Path $scriptsRoot 'Import-PersonaPackZip.ps1') -Arguments @('-PersonaPackZip', $script:PersonaPackTextBox.Text, '-NoBrowser', '-NoClipboard', '-SetAsDefault')
    }
})
$window.FindName('BtnInstallAutostart').Add_Click({ Invoke-SetupScript -Title '启用登录后自动启动' -FilePath (Join-Path $scriptsRoot 'Install-LocalBotAutostart.ps1') })
$window.FindName('BtnUninstallAutostart').Add_Click({ Invoke-SetupScript -Title '取消登录后自动启动' -FilePath (Join-Path $scriptsRoot 'Uninstall-LocalBotAutostart.ps1') })
$window.FindName('BtnCheckSharePackage').Add_Click({ Invoke-PublisherAction -Title '检查基础包安全性' -FilePath (Join-Path $scriptsRoot 'Test-ShareablePackage.ps1') -RequiredPath (Join-Path $projectRoot 'shareable-template') })
$window.FindName('BtnExportSharePackage').Add_Click({ Invoke-PublisherAction -Title '导出基础环境 ZIP' -FilePath (Join-Path $scriptsRoot 'New-ShareablePackage.ps1') -RequiredPath (Join-Path $projectRoot 'shareable-template') })
$window.FindName('BtnExportVoicePack').Add_Click({
    $confirmation = [System.Windows.MessageBox]::Show('仅当你拥有模型与参考音频的传播授权时，才可以导出语音包。是否继续？', '确认授权', 'YesNo', 'Warning')
    if ($confirmation -eq [System.Windows.MessageBoxResult]::Yes) {
        Invoke-PublisherAction -Title '导出已授权语音包' -FilePath (Join-Path $scriptsRoot 'New-VoicePack.ps1') -RequiredPath (Join-Path $projectRoot 'voice-pack-template')
    }
})
$window.FindName('BtnCheckPersonaPack').Add_Click({ Invoke-PublisherAction -Title '检查人格包安全性' -FilePath (Join-Path $scriptsRoot 'Test-PersonaPackSource.ps1') -RequiredPath (Join-Path $projectRoot 'persona-pack-template') })
$window.FindName('BtnExportPersonaPack').Add_Click({
    $confirmation = [System.Windows.MessageBox]::Show('请确认人格包仅包含你可分享的文本设定，且不包含凭据、聊天记录、媒体或训练素材。是否继续？', '确认内容范围', 'YesNo', 'Warning')
    if ($confirmation -eq [System.Windows.MessageBoxResult]::Yes) {
        Invoke-PublisherAction -Title '导出人格包 ZIP' -FilePath (Join-Path $scriptsRoot 'New-PersonaPack.ps1') -RequiredPath (Join-Path $projectRoot 'persona-pack-template')
    }
})
$window.FindName('BtnOpenReleaseFolder').Add_Click({
    $releasePath = Join-Path $projectRoot 'release'
    [System.IO.Directory]::CreateDirectory($releasePath) | Out-Null
    Start-Process -FilePath $releasePath
})
$window.FindName('BtnCopyQqChecklist').Add_Click({
    Copy-SetupText "QQ 官方机器人检查清单`r`n1. 我的机器人：创建并设置头像、昵称、简介。`r`n2. 开发设置：事件订阅选择 WebSocket。`r`n3. 保存 AppID / AppSecret，只在 AstrBot 的 QQ 官方机器人适配器内填写。`r`n4. 服务器 IP 白名单：填当前 VPN 或网络的公网出口 IPv4。`r`n5. 开发体验号设置：添加自己的测试 QQ。`r`n6. AstrBot：机器人 → 创建 QQ 官方机器人适配器 → 保存 → 在 QQ 中 @机器人测试。"
})
$window.FindName('BtnCopyDownloadInstructions').Add_Click({
    Copy-SetupText "先解压基础包，双击 Setup-Center.cmd，按页签完成 Docker、QQ、模型配置；需要时再导入文本人格包和语音包。所有账号、密钥与白名单都由你自己创建，不要把它们发给我。"
})

Add-SetupLog '欢迎使用可视化配置中心。建议从“开始”页执行一次本机状态检查。'
if ($ValidateOnly) {
    Write-Output 'SETUP_CENTER_XAML_OK'
    return
}

if (-not [string]::IsNullOrWhiteSpace($PreviewPath)) {
    $previewDirectory = Split-Path -Parent $PreviewPath
    if (-not [string]::IsNullOrWhiteSpace($previewDirectory)) {
        [System.IO.Directory]::CreateDirectory($previewDirectory) | Out-Null
    }
    $window.Measure((New-Object System.Windows.Size(1180, 790)))
    $window.Arrange((New-Object System.Windows.Rect(0, 0, 1180, 790)))
    $window.Show()
    $window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::ApplicationIdle, [Action]{})
    $window.UpdateLayout()
    $bitmap = New-Object System.Windows.Media.Imaging.RenderTargetBitmap(1180, 790, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($window)
    $encoder = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream = [System.IO.File]::Open($PreviewPath, [System.IO.FileMode]::Create)
    try {
        $encoder.Save($stream)
    }
    finally {
        $stream.Dispose()
        $window.Close()
    }
    Write-Output "SETUP_CENTER_PREVIEW_OK $PreviewPath"
    return
}

$window.ShowDialog() | Out-Null
