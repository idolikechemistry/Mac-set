#!/usr/bin/env bash
set -euo pipefail

PORT=50123
TS_BASE="/opt/topspin4.5.0"
JRE_BIN="$TS_BASE/jre/bin/java"
NMRDATA_DIR="$TS_BASE/classes/binary/nmrdata-search"
NMRDATA_JAR="$NMRDATA_DIR/nmrdata-search.jar"
LOG="/tmp/nmrdata-search.log"
DATASET_DIR=""

print_usage() {
  cat <<'USAGE'
用法：
  topspin_nmr_fix.sh [--dataset /path/to/your/EXPNO]

選項：
  --dataset PATH   指向你的實驗資料夾（含 fid/ser 與 pdata），例如：
                   /Users/jay/my_documents/TCC_Lab/WJ_NMR_Raw_Data/WJ143_20251010/1

說明：
  1) 檢查 50123 埠是否已有 nmrdata-search 在 LISTEN；如無，啟動服務並寫入 /tmp/nmrdata-search.log
  2) 若提供 --dataset，將建立/修復 PATH 下的 pdata/1 與 outd，並修正權限

範例：
  chmod +x topspin_nmr_fix.sh
  ./topspin_nmr_fix.sh --dataset "/Users/jay/my_documents/TCC_Lab/WJ_NMR_Raw_Data/WJ143_20251010/1"
USAGE
}

# 解析參數
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dataset)
      shift
      DATASET_DIR="${1:-}"
      if [[ -z "$DATASET_DIR" ]]; then
        echo "[X] --dataset 需要一個路徑"
        exit 1
      fi
      shift
      ;;
    -h|--help)
      print_usage; exit 0;;
    *)
      echo "[!] 不識別的參數：$1"
      print_usage; exit 1;;
  esac
done

echo "=== TopSpin 快修開始 ==="

# A) 檢查與啟動 nmrdata-search
echo "[A] 檢查 127.0.0.1:${PORT} 是否有服務在 LISTEN ..."
if lsof -iTCP:${PORT} -sTCP:LISTEN >/dev/null 2>&1; then
  echo "[A] OK：已有服務在 LISTEN。"
else
  echo "[A] 未偵測到 LISTEN，嘗試啟動 nmrdata-search ..."
  # 基本檢查
  if [[ ! -x "$JRE_BIN" ]]; then
    echo "[A] 找不到或無法執行的 Java：$JRE_BIN"
    echo "    請確認 TopSpin 安裝在 $TS_BASE，或將 JRE_BIN 指向可用的 java。"
    exit 1
  fi
  if [[ ! -f "$NMRDATA_JAR" ]]; then
    echo "[A] 找不到 JAR：$NMRDATA_JAR"
    echo "    請確認 TopSpin 版本與安裝路徑；或用 GUI 啟動 NMR Data Search。"
    exit 1
  fi

  # 啟動服務
  mkdir -p "$(dirname "$LOG")"
  nohup "$JRE_BIN" -jar "$NMRDATA_JAR" --server.port=${PORT} >>"$LOG" 2>&1 &
  sleep 1.5

  if lsof -iTCP:${PORT} -sTCP:LISTEN >/dev/null 2>&1; then
    echo "[A] 啟動成功：nmrdata-search 已在 ${PORT} 監聽。"
    echo "[A] 日誌：$LOG"
  else
    echo "[A] 啟動失敗；請查看日誌：$LOG"
    exit 1
  fi
fi

# B) 修復資料集（若有提供）
if [[ -n "$DATASET_DIR" ]]; then
  echo "[B] 資料集路徑：$DATASET_DIR"
  if [[ ! -d "$DATASET_DIR" ]]; then
    echo "[B] 路徑不存在：$DATASET_DIR"
    exit 1
  fi

  PDATA="$DATASET_DIR/pdata/1"
  OUTD="$PDATA/outd"

  echo "[B] 建立/確認 $PDATA 與 $OUTD ..."
  mkdir -p "$OUTD"

  echo "[B] 修正擁有者與權限 ..."
  # staff 為 macOS 預設群組；如你的系統不同，請自行調整
  sudo chown -R "$USER":staff "$DATASET_DIR"
  chmod -R u+rwX,go+rX "$DATASET_DIR"

  echo "[B] 檢查檔案鎖定旗標（uchg） ..."
  if ls -lO "$DATASET_DIR" | grep -q "uchg"; then
    echo "[B] 偵測到 uchg，移除鎖定 ..."
    chflags -R nouchg "$DATASET_DIR"
  fi

  echo "[B] 完成。"
fi

echo "=== 全部完成 ✅ ==="
echo "提醒：請到 系統設定 → 隱私權與安全性 → 完整磁碟存取，加入："
echo "  - $JRE_BIN"
echo "  - $NMRDATA_DIR"
echo "  - TopSpin 主程式（.app）"
