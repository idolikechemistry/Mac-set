#!/bin/bash

# 1. 在當前執行目錄下建立 .tmp 暫存區
TMP_DIR="./.tmp"
mkdir -p "$TMP_DIR"

# 啟用 Zsh 擴充檔案匹配
setopt local_options extended_glob

# 2. 匹配常見音訊與影片格式
AUDIO_FILES=(*.(wav|WAV|mp3|MP3|m4a|M4A|flac|FLAC|aac|AAC|ogg|OGG|opus|OPUS|mp4|MP4|mkv|MKV|mov|MOV|webm|WEBM)(N))

if [ ${#AUDIO_FILES} -eq 0 ]; then
    echo "⚠️ 當前目錄下沒有找到符合的影音檔案。"
    rm -rf "$TMP_DIR"
    exit 0
fi

echo "🚀 開始處理 ${#AUDIO_FILES} 個檔案（轉檔為 16kHz / 16-bit Mono WAV）...\n"

count=0
for file in "${AUDIO_FILES[@]}"; do
    # 排除已帶有 _16-bit 後綴的輸出檔，避免重複轉換
    if [[ "$file" == *_16-bit.wav ]]; then
        continue
    fi

    filename=$(basename -- "$file")
    name_without_ext="${filename%.*}"

    # 暫存檔路徑與最終輸出檔名
    tmp_output="${TMP_DIR}/${name_without_ext}_tmp.wav"
    final_output="./${name_without_ext}_16-bit.wav"

    echo "🎙️ 正在處理: $file"

    # 使用 FFmpeg 轉碼至 .tmp 暫存資料夾
    ffmpeg -hide_banner -loglevel error -y -i "$file" -ar 16000 -ac 1 -c:a pcm_s16le "$tmp_output"

    if [ $? -eq 0 ]; then
        # 轉檔成功後搬至當前目錄
        mv "$tmp_output" "$final_output"
        echo "✅ 成功輸出: $final_output\n"
        ((count++))
    else
        echo "❌ 轉檔失敗: $file\n"
        [ -f "$tmp_output" ] && rm -f "$tmp_output"
    fi
done

# 3. 處理完畢後自動清理 .tmp 資料夾
rm -rf "$TMP_DIR"

echo "🎉 轉檔完畢！共成功轉換 $count 個檔案。"
