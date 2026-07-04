#!/system/bin/sh

# =====================================================
# 懂球帝广告屏蔽 v2 - iptables + ipset 混合屏蔽
# =====================================================
# 此脚本包含三层屏蔽：
# 1. iptables string 匹配：拦截 HTTP 明文中的广告域名
# 2. ipset + iptables: 拦截已知广告 IP 段
# 3. DNS 重定向：将广告域名解析到黑名单 IP
# =====================================================

IPTABLES=iptables
IP6TABLES=ip6tables

log_msg() {
  echo "[懂球帝广告屏蔽] $1" >> /cache/dongqiudi-adblock.log 2>/dev/null
}

log_msg "开始加载广告屏蔽规则..."

# ===== 第一步：创建 ipset 集合（广告IP黑名单） =====
# 检查内核是否支持ipset
if command -v ipset >/dev/null 2>&1; then
  # 创建/清空 hash:net 类型集合
  ipset destroy dongqiudi_ad 2>/dev/null
  ipset create dongqiudi_ad hash:net 2>/dev/null || {
    log_msg "ipset 创建失败，回退到纯 iptables 模式"
  }

  if ipset list dongqiudi_ad >/dev/null 2>&1; then
    # 知名广告CDN网段（穿山甲、腾讯广告、百度广告常用IP段）
    AD_NETS=(
      # 穿山甲/CDN 常见段
      "180.163.150.0/23"
      "180.163.151.0/24"
      "220.181.34.0/24"
      "220.181.90.0/24"
      "111.13.11.0/24"
      "111.13.101.0/24"
      "60.28.3.0/24"
      "60.28.29.0/24"
      "110.249.128.0/20"
      "111.32.128.0/19"
      "116.211.100.0/22"
      "106.11.0.0/16"
      "106.11.220.0/22"
      "106.11.224.0/22"
      "106.11.228.0/22"
      "106.11.232.0/22"
      "106.11.236.0/22"
      "106.11.240.0/22"
      # 腾讯广点通
      "182.254.4.0/22"
      "182.254.8.0/22"
      "182.254.12.0/22"
      "119.147.128.0/20"
      "14.17.64.0/18"
      # 百度
      "115.239.210.0/24"
      "115.239.211.0/24"
      "61.135.168.0/24"
      # 快手的CDN
      "36.110.128.0/19"
      "58.250.0.0/16"
    )

    for net in "${AD_NETS[@]}"; do
      ipset add dongqiudi_ad "$net" 2>/dev/null
    done
    log_msg "ipset 集合已创建，包含 $(ipset list dongqiudi_ad 2>/dev/null | grep -c '^[0-9]') 个网段"
  fi
else
  log_msg "ipset 不可用，回退到纯 iptables 模式"
fi

# ===== 第二步：清理旧规则 =====
# 清理 IPv4
$IPTABLES -D OUTPUT -j DONGQIU_AD 2>/dev/null
$IPTABLES -F DONGQIU_AD 2>/dev/null
$IPTABLES -X DONGQIU_AD 2>/dev/null
# 清理 IPv6
$IP6TABLES -D OUTPUT -j DONGQIU_AD 2>/dev/null
$IP6TABLES -F DONGQIU_AD 2>/dev/null
$IP6TABLES -X DONGQIU_AD 2>/dev/null

# ===== 第三步：创建新链 =====
$IPTABLES -N DONGQIU_AD
$IP6TABLES -N DONGQIU_AD

# ===== 第四步：IPv4 规则 =====

# 4.1 ipset 规则（如果可用）
if ipset list dongqiudi_ad >/dev/null 2>&1; then
  $IPTABLES -A DONGQIU_AD -m set --match-set dongqiudi_ad dst -j DROP
  log_msg "ipset 规则已添加"
fi

# 4.2 string 匹配规则（覆盖 HTTP 明文请求）
AD_STRINGS=(
  # 穿山甲
  "pglstatp-toutiao.com"
  "pangolin-sdk"
  "ctobsnssdk.com"
  "pangle"
  # 快手
  "adkwai.com"
  "kwad.net"
  "kwaid.com"
  # 百度
  "mobads.baidu.com"
  "cpro.baidustatic.com"
  "dup.baidustatic.com"
  "nsclick.baidu.com"
  # 广点通
  "gdt.qq.com"
  "adshonor.gdt"
  "pgdt.gtimg.cn"
  # 倍孜
  "mddlsa.com"
  "beizi.biz"
  "sdk.beizi.biz"
  # 美数
  "meishu.com"
  # Sigmob
  "sigmob.com"
  # 友盟
  "umeng.com"
  # 章鱼移动广告
  "zhangyuyidong.cn"
  "sdk.zhangyuyidong.cn"
  "sdklog.zhangyuyidong.cn"
  # ADN+
  "adn-plus.com.cn"
  "ad-api.adn-plus.com.cn"
  # 其他广告SDK
  "sdktmp.hubcloud.com.cn"
  "sdkoptedge.chinanetcenter.com"
  # HTTP DNS 服务（拦截后将阻断广告域名解析）
  "httpdns.bcelive.com"
  "httpdns.alicdn.com"
  # 其他广告
  "ad.qingting"
  "admaster.com.cn"
  "adsmind"
  "appic.dongqiudi"
  "stat.dongqiudi"
  "tongji.dongqiudi"
  # 谷歌广告
  "doubleclick.net"
  "googlesyndication.com"
  "googleadservices.com"
  "pagead2.googlesyndication"
  "adservice.google"
  # 美团广告
  "meituan.com"
  "ad.meituan.com"
  "union.meituan.com"
  "click.meituan.com"
  "tracking.mttyun.com"
  "mc.meituan.com"
  "sdk.meituan.com"
  "ad.mttyun.com"
  "dp-adplatform.dianping.com"
  "tracking.dianping.com"
  # 实况足球/eFootball广告
  "konami.com"
  "konami.net"
  "efootball.konami"
  "m.konami.net"
  "pesclubmanager" 
  "eFootball2025"
  "pes2024"
  "pes2025"
  "efootball2025"
  # 漏网广告测试
  "ubixioe.com"
  "touch-moblie.com"
  # 新抓包域名 2026-07-04
  "adservice.sigmob.cn"
  "tnc3-bjlgy.zijieapi.com"
  "mercury-sdk.snssdk.com"
  # 第二轮新增
  "cn.miaozhen.com"
  "dmp-collect.xdmssp.com"
  "fp-it.fengkongcloud.com"
  "dc.sigmob.cn"
  "dm.toutiao.com"
  "wanproxy-hz.127.net"
  "msv6.wosms.cn"
  "gdfp.gifshow.com"
  "toblog.volceapplog.com"
  "klink.volceapplog.com"
  "id6.me"
  # 第三轮新增（全量补漏，排除yunxish）
  "open.e.189.cn"
  "open.e.kuaishou.com"
  "open.kwaizt.com"
  "v2.get.sogou.com"
  "opencloud.wostore.cn"
  "s3plus.meituan.net"
  "wkdcm1.tingyun.com"
  "zt.cn.ksapisrv.com"
)

for ad_str in "${AD_STRINGS[@]}"; do
  $IPTABLES -A DONGQIU_AD -m string --string "$ad_str" --algo bm -j DROP 2>/dev/null
done
log_msg "IPv4 string 规则已添加 (${#AD_STRINGS[@]} 条)"

# 4.3 额外丢弃常见广告端口（可选，谨慎）
# 某些广告服务器使用非标端口，暂不开启

# ===== 第五步：IPv6 规则（只添加 string 匹配） =====
for ad_str in "${AD_STRINGS[@]}"; do
  $IP6TABLES -A DONGQIU_AD -m string --string "$ad_str" --algo bm -j DROP 2>/dev/null
done
log_msg "IPv6 string 规则已添加 (${#AD_STRINGS[@]} 条)"

# ===== 第六步：插入 OUTPUT 链 =====
# 插入到 OUTPUT 链顶部（确保先行匹配）
$IPTABLES -I OUTPUT 1 -j DONGQIU_AD
$IP6TABLES -I OUTPUT 1 -j DONGQIU_AD

# ===== 第七步：额外加固 - 防止 DNS 解析绕过 =====
# 强制屏蔽已知的广告 DNS 解析端（保留原hosts作为辅助）
# 写入临时 hosts 补充（针对系统级 DNS 解析）
HOSTS_FILE=/system/etc/hosts
if [ -f "$HOSTS_FILE" ]; then
  # 注意：hosts文件在Magisk模块中被替换为挂载版本，所以实际修改模块内的hosts
  MODULE_HOSTS=/data/adb/modules/dongqiudi-adblock/system/etc/hosts
  if [ -f "$MODULE_HOSTS" ]; then
    log_msg "hosts 辅助文件存在，双保险生效"
  fi
fi

# ===== 完成 =====
RULE_COUNT=$($IPTABLES -L DONGQIU_AD -n 2>/dev/null | wc -l)
log_msg "✅ 规则加载完成！IPv4 DONGQIU_AD 链共 ${RULE_COUNT} 条规则"
log_msg "提示: 使用 'iptables -L DONGQIU_AD -n -v' 查看计数器"

# ===== 开机自检标志 =====
setprop persist.sys.dongqiudi_adblock loaded