# 💻 Cursor/VSCode Remote SSH 配置

通过 VPN 代理，让 Cursor/VSCode 在本机显示界面，后端 (vscode-server) 运行在远程 GPU 服务器上。

**工作流程**：Cursor (本机前端) → SSH → proxy.sh (智能代理) → Docker EasyConnect → VPN 隧道 → 远程 GPU 服务器 (vscode-server 后端)

## 配置步骤

### 1. 复制代理脚本

```bash
cp proxy.sh ~/.ssh/
chmod +x ~/.ssh/proxy.sh
```

### 2. 配置 SSH

编辑 `~/.ssh/config`，为每台服务器添加配置：

```ssh-config
# GPU 服务器 1
Host gpu-server1
    HostName 192.168.1.100
    User root
    Port 22
    ProxyCommand ~/.ssh/proxy.sh %h %p

# GPU 服务器 2
Host gpu-server2
    HostName 192.168.1.101
    User root
    Port 25792
    ProxyCommand ~/.ssh/proxy.sh %h %p

# 可以添加更多服务器...
```

> 💡 **关键点**：`ProxyCommand ~/.ssh/proxy.sh %h %p` 会自动检测 VPN 状态：
>
> - VPN 运行时 → 走 SOCKS5 代理
> - VPN 未运行 → 直连（适用于校内网络）

### 3. 配置 SSH 免密登录

```bash
# 生成密钥（如果还没有）
ssh-keygen -t ed25519

# 复制公钥到服务器
ssh-copy-id gpu-server1
ssh-copy-id gpu-server2
```

### 4. 在 Cursor/VSCode 中连接

1. 安装 **Remote - SSH** 扩展
2. 按 `Cmd+Shift+P`，输入 `Remote-SSH: Connect to Host`
3. 选择配置好的服务器（如 `gpu-server1`）
4. 等待 vscode-server 自动安装完成
5. 开始编码！🎉

## 使用流程

| 场景 | 操作                                          |
| ---- | --------------------------------------------- |
| 校内 | 直接打开 Cursor，连接服务器                   |
| 校外 | 先从菜单栏启动 VPN，等连接成功后再打开 Cursor |

## 常见问题

**Q: Cursor 连接时卡住？**

A:

1. 确认 VPN 已连接（菜单栏显示 🟢）
2. 终端测试：`ssh gpu-server1` 是否正常
3. 查看日志：`~/.cursor-server/` 或 `~/.vscode-server/`

**Q: 连接后插件不工作？**

A: Remote SSH 模式下，部分插件需要在远程安装。点击扩展图标，选择「在 SSH: xxx 中安装」。

**Q: 如何使用远程服务器的 GPU？**

A: 连接成功后，在 Cursor 终端中运行的代码自动使用远程 GPU：

```python
import torch
print(torch.cuda.is_available())  # True
print(torch.cuda.device_count())  # 8 (取决于服务器)
```
