#!/usr/bin/env zsh

# --- 顏色設定 ---
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# 檢查 Mutagen 依賴
if ! python3 -c "import mutagen" &> /dev/null; then
    echo -e "${RED}錯誤: 尚未安裝 Mutagen。請執行 'pipx install mutagen' 或 'pip3 install mutagen'。${NC}"
    exit 1
fi

echo -e "${CYAN}🔍 開始掃描並比對同名 .m4a 與 .lrc 檔案...${NC}\n"

count=0

# 掃描當前目錄下所有的 .m4a 檔案 (Nn 確保沒有檔案時不會報錯，且按自然排序)
for m4a_file in *.(m4a|M4A)(Nn); do
    # 提取不含副檔名的主檔名
    base_name="${m4a_file%.*}"
    lrc_file="${base_name}.lrc"

    # 如果同名的 .lrc 檔案存在
    if [ -f "$lrc_file" ]; then
        echo -n -e "正在嵌入: ${YELLOW}${base_name}${NC} ... "

        # 呼叫 Python inline 腳本處理寫入
        RESULT=$(python3 -c '
import sys
from mutagen.mp4 import MP4

m4a_path, lrc_path = sys.argv[1], sys.argv[2]
try:
    audio = MP4(m4a_path)
    with open(lrc_path, "r", encoding="utf-8") as f:
        lrc_text = f.read()

    if lrc_text.strip():
        audio["\xa9lyr"] = [lrc_text]
        audio.save()
        print("SUCCESS")
    else:
        print("EMPTY")
except Exception as e:
    print(f"ERROR|{e}")
' "$m4a_file" "$lrc_file")

        # 根據 Python 腳本的回傳結果顯示對應訊息
        if [[ "$RESULT" == "SUCCESS" ]]; then
            echo -e "${GREEN}✅ 完成${NC}"
            count=$((count + 1))
        elif [[ "$RESULT" == "EMPTY" ]]; then
            echo -e "${RED}❌ 失敗 (LRC 內容為空)${NC}"
        elif [[ "$RESULT" == ERROR* ]]; then
            error_msg=$(echo "$RESULT" | cut -d'|' -f2)
            echo -e "${RED}❌ 寫入發生錯誤: $error_msg${NC}"
        fi
    fi
done

if [ "$count" -eq 0 ]; then
    echo -e "\n${YELLOW}⚠️ 未找到任何成對的 .m4a 與 .lrc 檔案。${NC}"
else
    echo -e "\n${GREEN}🎉 處理完畢！共成功嵌入 $count 個檔案。${NC}"
fi
