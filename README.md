# home.d

# 安装 op
```bash
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" |
sudo tee /etc/apt/sources.list.d/1password.list

sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | \
sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg

sudo apt update && sudo apt install -y 1password-cli
```

```sh
git config --global --unset core.sshCommand

eval $(op signin)

cp .env.example .env
```

# 设置 remote url
```sh
# 获取
git remote get-url origin
# 设置
git remote set-url origin git@github-work:username/repo.git
```

# 设置 ssh server
`sudo vim /etc/ssh/sshd_config`
```
# 端口（可选，如果需要更改默认端口22）
Port 22

# 启用密码验证
PasswordAuthentication yes

# 确保允许本地网络连接
PermitRootLogin yes
```
`sudo vim /etc/wsl.conf`
```
[boot]
command = service ssh start
```
开启服务
```sh
sudo service ssh start
sudo service ssh status
```
windows 连接
```sh
ssh gray@localhost
# 端口转发
ssh -L 8080:localhost:8080 -N -g gray@localhost
```
