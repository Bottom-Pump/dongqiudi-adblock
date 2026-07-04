# 懂球帝广告屏蔽 | Dongqiudi AdBlock

> 专为懂球帝 APP 定制的 Magisk 广告屏蔽模块

[![Magisk](https://img.shields.io/badge/Magisk-24.0%2B-00B4D8?logo=magisk)](https://github.com/topjohnwu/Magisk)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-v1.4-green)](.)

## 功能特性

- 🛡️ **三层拦截**：文件系统级 + 网络级 + DNS 级，广告无处可逃
- 📦 **覆盖主流广告 SDK**：穿山甲、广点通、快手、百度、Google Ads 等 20+
- 🔒 **广告缓存目录锁定**：自动扫描懂球帝数据目录，将广告缓存目录设为 `000` 权限并锁定
- 🧠 **智能白名单**：`video_cache`、`image_cache` 等必要功能目录不会被误封
- 🔄 **规则自愈**：每 5 分钟扫描新增广告目录，每小时检测 iptables 规则是否丢失并自动重载
- ⚡ **低功耗**：守护进程开销极小，不影响日常使用

## 拦截原理

```
┌──────────────────────────────────────────────────────┐
│                    三层拦截架构                         │
├──────────┬───────────────────┬───────────────────────┤
│  层级 1   │      层级 2       │        层级 3          │
│  文件系统  │     网络层        │        DNS 层          │
│          │                   │                       │
│ chmod 000 │ iptables string   │   hosts 文件           │
│ chattr +i │ + ipset 网段拦截   │   广告域名 → 0.0.0.0   │
│          │ 直接 DROP 广告请求  │   DNS 辅助防线         │
└──────────┴───────────────────┴───────────────────────┘
```

### 文件系统层（service.sh）
- 开机启动后扫描 `/data/data/com.dongqiudi.news/` 下所有子目录
- 匹配含广告关键词（`ad`、`pangle`、`gdt`、`ksad` 等）的目录
- 设置 `chmod 000` + `chattr +i` 锁定目录，使广告 SDK 无法读写缓存
- 每 5 分钟循环扫描新增目录，白名单内的功能目录跳过

### 网络层（dongqiudi-adblock.sh）
- **iptables string 匹配**：在 `OUTPUT` 链拦截 HTTP 请求中含广告域名的数据包
- **ipset 网段拦截**：将穿山甲、广点通等广告 CDN 的 IP 段加入黑名单直接 DROP
- **IPv4 + IPv6 双栈**：同时拦截两种协议
- 若内核不支持 ipset，自动回退纯 iptables 模式
- 每小时检测规则是否被系统重置

### DNS 层（hosts）
- 50+ 广告域名解析到 `0.0.0.0`
- DNS 层面的辅助防线，双重保险

## 已拦截广告 SDK

| 类别 | SDK |
|------|-----|
| 穿山甲 | Pangle, pglstatp-toutiao.com, ctobsnssdk.com |
| 腾讯广点通 | GDT, gdt.qq.com, pgdt.gtimg.cn |
| 快手 | adkwai.com, kwad.net, kwaid.com |
| 百度 | mobads.baidu.com, cpro.baidustatic.com |
| 倍孜 | Beizi, mddlsa.com |
| Google | DoubleClick, Google Syndication, Google AdServices |
| 美团 | ad.meituan.com, union.meituan.com |
| Unity Ads | unity |
| Vungle | vungle |
| AppLovin | applovin |
| Mintegral | mintegral |
| AdColony | adcolony |
| Chartboost | chartboost |
| IronSource | ironsrc |
| Tapjoy | tapjoy |
| Sigmob | sigmob.com |
| 极光推送 | jiguang, pushio |
| 友盟 | umeng.com |
| 其他 | 实况足球/eFootball 广告域名等 |

> **注意**：拦截基于域名和 IP 段匹配，不会影响懂球帝 APP 的正常功能使用。

## 环境要求

- Magisk **24.0+**（推荐 Magisk 26+）
- Android **8.0+**
- 已安装 **懂球帝 APP**

## 安装方法

### 方式一：Magisk Manager 刷入

1. 下载最新版的 `dongqiudi-adblock-*.zip`
2. 打开 Magisk Manager → **模块** → **从本地安装**
3. 选择下载的 zip 文件
4. 重启手机

### 方式二：自定义 Recovery 刷入

1. 将 zip 文件复制到手机存储
2. 进入 TWRP 等 Recovery
3. 选择安装 → 选择 zip → 滑动刷入
4. 重启手机

### 验证是否生效

刷入重启后，执行以下命令验证：

```bash
# 检查模块是否加载
su -c "ls /data/adb/modules/dongqiudi-adblock"

# 查看 iptables 规则计数
su -c "iptables -L DONGQIU_AD -n -v"

# 查看运行日志
su -c "cat /cache/dongqiudi-adblock.log"
```

## 更新日志

### v1.4（2026-07-04）
- 新增大量广告域名规则
- 优化 iptables 规则自愈逻辑
- 更新 hosts 列表，补充漏网域名

### v1.3
- 新增 ipset 网段拦截
- 优化广告目录扫描逻辑
- 引入智能白名单机制

### v1.2
- 首次发布，基于文件系统 + iptables + hosts 三层拦截

## 卸载

1. 在 Magisk Manager 中找到本模块，点击 **卸载**
2. 重启手机即可完全移除

## 自行打包

```bash
cd dongqiudi-adblock
zip -r ../dongqiudi-adblock-v1.4.zip . -x ".git/*" -x "README.md" -x "LICENSE" -x ".gitignore"
```

## License

[GPL v3](LICENSE)

## Author

**Sinc** — [GitHub](https://github.com/Bottom-Pump)

---

> 如果这个项目对你有帮助，欢迎 ⭐ Star 支持！
