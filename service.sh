#!/system/bin/sh
# 懂球帝广告屏蔽 v1.4
# Author: Sinc

MODULE_DIR=/data/adb/modules/dongqiudi-adblock
IPTABLES=/system/bin/iptables
PKG=com.dongqiudi.news
BASE_DIR=/data/data/$PKG
LOG_FILE=/cache/dongqiudi-adblock.log

# 广告关键词列表
AD_KEYWORDS="ad|adnet|pangle|sigmob|gdt|beizi|cpc_|ksad|mobads|preload|splash|wind|windmill|volley|eascript|retry|msa|cbd|huawei|openads|byted|pangle|unity|vungle|applovin|mintegral|adcolony|chartboost|ironsrc|tapjoy|jiguang|pushio|amazon"

# 白名单：这些目录不能封锁（懂球帝必要功能目录）
SKIP_DIRS="dynamic|tpl4native|video_cache|image_cache|WebView|Crash|sentry|libCachedImageData|loaderFactory|mdlDownload"

# 等待系统完全启动
while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 3
done
sleep 10

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [懂球帝广告屏蔽] $1" >> "$LOG_FILE" 2>/dev/null
}

log "=== 懂球帝广告屏蔽 v1.3 全能版(fix) 启动 ==="

# 设置权限并加载iptables规则
chmod 0755 ${MODULE_DIR}/system/bin/dongqiudi-adblock.sh 2>/dev/null
/system/bin/sh ${MODULE_DIR}/system/bin/dongqiudi-adblock.sh

# ============================================
# 智能广告目录扫描封锁（修复版）
# ============================================
block_dir() {
  local dir="$1"
  local basename=$(basename "$dir")
  
  # 跳过白名单目录
  echo "$basename" | grep -qiE "^($SKIP_DIRS)$" && return
  
  if [ -d "$dir" ]; then
    # 只锁定父目录，不递归锁内部文件（v1.3方式）
    chattr -R -i "$dir" 2>/dev/null
    chmod 000 "$dir" 2>/dev/null
    chmod 000 "$dir" 2>/dev/null
    chattr +i "$dir" 2>/dev/null
    
    # 验证：循环尝试直到确认权限为000
    local retry=0
    while [ $retry -lt 5 ]; do
      local perm=$(ls -ld "$dir" 2>/dev/null | awk '{print $1}')
      case "$perm" in
        d---------*) break ;;  # 000 成功
        *)
          chattr -R -i "$dir" 2>/dev/null
          chmod 000 "$dir" 2>/dev/null
          chmod 000 "$dir" 2>/dev/null
          chattr +i "$dir" 2>/dev/null
          retry=$((retry + 1))
          sleep 1
          ;;
      esac
    done
    if [ $retry -ge 5 ]; then
      log "⚠️ 目录 $dir 无法设置为000，当前权限: $perm"
    fi
  else
    mkdir -p "$dir" 2>/dev/null
    chmod 000 "$dir" 2>/dev/null
    chattr +i "$dir" 2>/dev/null
  fi
}

scan_and_block() {
  local scan_base="$1"
  if [ ! -d "$scan_base" ]; then
    return
  fi
  find "$scan_base" -maxdepth 1 -type d 2>/dev/null | while read dirpath; do
    local basename=$(basename "$dirpath")
    echo "$basename" | grep -qiE "^($SKIP_DIRS)$" && continue
    [ "$dirpath" = "$scan_base" ] && continue
    if echo "$basename" | grep -qiE "$AD_KEYWORDS"; then
      block_dir "$dirpath"
      log "智能扫描封锁: $dirpath"
    fi
  done
}

# 首次扫描
scan_and_block "${BASE_DIR}/app_adnet"
scan_and_block "${BASE_DIR}/cache"
scan_and_block "${BASE_DIR}/files"

# 也检查shared_prefs
if [ -d "${BASE_DIR}/shared_prefs" ]; then
  find "${BASE_DIR}/shared_prefs" -maxdepth 1 -type d 2>/dev/null | while read dirpath; do
    local basename=$(basename "$dirpath")
    echo "$basename" | grep -qiE "^($SKIP_DIRS)$" && continue
    [ "$dirpath" = "${BASE_DIR}/shared_prefs" ] && continue
    if echo "$basename" | grep -qiE "$AD_KEYWORDS"; then
      block_dir "$dirpath"
      log "智能扫描封锁(shared_prefs): $dirpath"
    fi
  done
fi

# 循环监控守护 - 每10分钟扫描新增广告目录
(
  while true; do
    sleep 300
    scan_and_block "${BASE_DIR}/app_adnet"
    scan_and_block "${BASE_DIR}/cache"
    scan_and_block "${BASE_DIR}/files"
    if [ -d "${BASE_DIR}/shared_prefs" ]; then
      find "${BASE_DIR}/shared_prefs" -maxdepth 1 -type d 2>/dev/null | while read dirpath; do
        local basename=$(basename "$dirpath")
        echo "$basename" | grep -qiE "^($SKIP_DIRS)$" && continue
        [ "$dirpath" = "${BASE_DIR}/shared_prefs" ] && continue
        if echo "$basename" | grep -qiE "$AD_KEYWORDS"; then
          block_dir "$dirpath"
          log "智能监控新封锁(shared_prefs): $dirpath"
        fi
      done
    fi
  done
) &

# iptables监控守护 - 每小时检查规则是否被系统重置
(
  while true; do
    sleep 3600
    ${IPTABLES} -L DONGQIU_AD >/dev/null 2>&1 || {
      log "检测到iptables规则丢失，重新加载..."
      /system/bin/sh ${MODULE_DIR}/system/bin/dongqiudi-adblock.sh
    }
  done
) &

log "✅ 懂球帝广告屏蔽已启动，自动发现并封锁广告缓存目录，规则自愈监控已运行"