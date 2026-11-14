#!/usr/bin/env bash

# 1. 在當前執行目錄下建立 .tmp 暫存區
TMP_DIR="./.tmp"
mkdir -p "$TMP_DIR"

# 2. 搜尋當前目錄下的影音檔案（支援常見副檔名，不區分大小寫）
FILES=()
while IFS= read -r -d '' file; do
    clean_file="${file#./}"
    FILES+=("$clean_file")
done < <(find . -maxdepth 1 -type f \( \
    -iname "*.wav" -o -iname "*.mp3" -o -iname "*.m4a" -o \
    -iname "*.flac" -o -iname "*.aac" -o -iname "*.ogg" -o \
    -iname "*.opus" -o -iname "*.mp4" -o -iname "*.mkv" -o \
    -iname "*.mov" -o -iname "*.webm" \
\) -print0)

if [ ${#FILES[@]} -eq 0 ]; then
    echo "⚠️ 當前目錄下沒有找到符合的影音檔案。"
    rm -rf "$TMP_DIR"
    exit 0
fi

echo -e "🚀 開始處理 ${#FILES[@]} 個檔案（轉檔為 16kHz / 16-bit Mono WAV）...\n"

count=0
for file in "${FILES[@]}"; do
    # 排除已帶有 _16-bit.wav 後綴的輸出檔，避免重複轉換
    if [[ "$file" == *"_16-bit.wav" ]]; then
        continue
    fi

    name_without_ext="${file%.*}"
    tmp_output="${TMP_DIR}/${name_without_ext}_tmp.wav"
    final_output="./${name_without_ext}_16-bit.wav"

    echo "🎙️ 正在處理: $file"

    # 使用 FFmpeg 轉碼至 .tmp 暫存資料夾
    ffmpeg -hide_banner -loglevel error -y -i "$file" -ar 16000 -ac 1 -c:a pcm_s16le "$tmp_output"

    if [ $? -eq 0 ]; then
        mv "$tmp_output" "$final_output"
        echo -e "✅ 成功輸出: $final_output\n"
        ((count++))
    else
        echo -e "❌ 轉檔失敗: $file\n"
        [ -f "$tmp_output" ] && rm -f "$tmp_output"
    fi
done

# 3. 清理 .tmp 暫存區
rm -rf "$TMP_DIR"

echo "🎉 轉檔完畢！共成功轉換 $count 個檔案。"
