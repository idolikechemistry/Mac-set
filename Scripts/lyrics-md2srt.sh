#!/bin/bash

# 1. 處理輸入路徑（引號確保空格安全）
INPUT_FILE="$1"

if [ ! -f "$INPUT_FILE" ]; then
    echo "錯誤：找不到檔案，請確認路徑是否正確。"
    exit 1
fi

BASE_NAME=$(basename "${INPUT_FILE%.*}")
OUTPUT_FILE="$HOME/Downloads/${BASE_NAME}.srt"

# 2. 執行轉換
awk '
BEGIN { count = 0; }

# 只要行內包含 [[ 且有 #t= 就抓取，不理會 YAML 區塊
/\[\[.*#t=[0-9:.]+.*\]\]/ {
    line = $0;

    # 提取時間戳記
    if (match(line, /#t=[0-9:.]+/)) {
        time_part = substr(line, RSTART + 3, RLENGTH - 3);
        
        # 提取歌詞：抓取第一個 ]] 之後的所有內容
        split(line, parts, "]]");
        # 取得 ]] 之後的所有內容
        content = substr(line, index(line, "]]") + 2);
        
        # 清理歌詞首尾的空白或特殊符號 (如 Markdown 殘留)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", content);

        if (length(content) > 0) {
            # 處理注音格式 {漢字|讀音1|讀音2} -> 漢字(讀音1讀音2)
            while (match(content, /\{[^}]+\}/)) {
                m_start = RSTART; m_len = RLENGTH;
                target = substr(content, m_start, m_len);
                inner = substr(target, 2, length(target) - 2);
                n = split(inner, p, "|");
                
                repl = p[1] "(";
                for (j = 2; j <= n; j++) repl = repl p[j];
                repl = repl ")";
                
                content = substr(content, 1, m_start - 1) repl substr(content, m_start + m_len);
            }

            times[count] = time_part;
            lyrics[count] = content;
            count++;
        }
    }
}

END {
    if (count == 0) {
        print "Error: 讀取失敗。請確認 .md 檔內的格式是否正確。" > "/dev/stderr";
        exit 1;
    }

    for (i = 0; i < count; i++) {
        print i + 1;
        s_sec = to_seconds(times[i]);
        if (i < count - 1) {
            e_sec = to_seconds(times[i+1]);
            if (e_sec - s_sec > 10) e_sec = s_sec + 10;
        } else {
            e_sec = s_sec + 5;
        }
        printf("%s --> %s\n", seconds_to_srt(s_sec), seconds_to_srt(e_sec));
        print lyrics[i];
        print "";
    }
}

function to_seconds(t,   parts) {
    if (split(t, parts, ":") == 2) return (parts[1] * 60) + parts[2];
    return t;
}

function seconds_to_srt(s,   hh, mm, ss, ms) {
    hh = int(s / 3600);
    mm = int((s % 3600) / 60);
    ss = s % 60;
    ms = int((ss - int(ss)) * 1000 + 0.5);
    if (ms >= 1000) { ss++; ms -= 1000; }
    return sprintf("%02d:%02d:%02d,%03d", hh, mm, int(ss), ms);
}
' "$INPUT_FILE" > "$OUTPUT_FILE"

echo "🎉 處理完畢！"
echo "請檢查下載資料夾中的：${BASE_NAME}.srt"
