#!/bin/bash

command -v yt-dlp >/dev/null || { echo "❌ 未找到 yt-dlp"; exit 1; }
command -v ffmpeg >/dev/null || { echo "❌ 未找到 ffmpeg"; exit 1; }
command -v jq >/dev/null || { echo "❌ 未找到 jq"; exit 1; }

echo "🎬 要下載的影片章節："
read -r yt_url

echo "📁 要合併章節的檔案路徑（影片或音訊）："
read -r raw_path
media_path=$(eval echo "$raw_path")

if [ ! -f "$media_path" ]; then
  echo "❌ 找不到檔案：$media_path"
  exit 1
fi

dir_path=$(dirname "$media_path")
filename=$(basename "$media_path")
extension="${filename##*.}"
base="${filename%.*}"
base_clean=$(echo "$base" | sed -E 's/_20[0-9]{6}_[0-9]{6}$//')
timestamp=$(date +"%Y%m%d_%H%M%S")
final_ext="$extension"
converted_path="$media_path"

# === mp3 ➜ 自動依原始位元率轉成 m4a ===
if [[ "$extension" == "mp3" ]]; then
  final_ext="m4a"
  converted_path="$dir_path/${base_clean}_converted.m4a"

  # 擷取原始 mp3 位元率（取整數 kbps）
  bitrate_kbps=$(ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate \
    -of default=noprint_wrappers=1:nokey=1 "$media_path" | awk '{print int($1/1000) }')

  # 根據原始位元率決定轉碼後位元率
  if (( bitrate_kbps <= 128 )); then
    aac_bitrate="96k"
  elif (( bitrate_kbps <= 160 )); then
    aac_bitrate="128k"
  elif (( bitrate_kbps <= 192 )); then
    aac_bitrate="144k"
  else
    aac_bitrate="160k"
  fi

  echo "🔁 偵測到 mp3，原始位元率 ${bitrate_kbps}kbps，轉為 m4a（AAC $aac_bitrate）..."
  ffmpeg -hide_banner -loglevel error -i "$media_path" -map a -c:a aac -b:a "$aac_bitrate" -f mp4 "$converted_path"
  if [ $? -ne 0 ]; then
    echo "❌ mp3 轉 m4a 失敗"
    exit 1
  fi
  echo "✅ 已轉檔：$converted_path"
fi

# === 抓取章節 JSON ===
info_json="$dir_path/temp_info.json"
chapter_txt="$dir_path/temp_chapters.txt"
yt-dlp --skip-download --write-info-json -o "$dir_path/temp.%(ext)s" "$yt_url"
mv "$dir_path/temp.info.json" "$info_json"

# === 建立 ffmetadata 章節檔案 ===
echo ";FFMETADATA1" > "$chapter_txt"
jq -c '.chapters[]' "$info_json" | while read -r chapter; do
  start=$(jq -r '.start_time' <<< "$chapter")
  end=$(jq -r '.end_time' <<< "$chapter")
  title=$(jq -r '.title' <<< "$chapter" | tr '\n\r' ' ' | sed 's/[]\[\"]//g')
  echo -e "[CHAPTER]\nTIMEBASE=1/1\nSTART=${start%.*}\nEND=${end%.*}\ntitle=$title" >> "$chapter_txt"
done

# === 章節嵌入輸出（暫存）===
temp_output="$dir_path/${base_clean}_with_chapters.$final_ext"
ffmpeg -hide_banner -loglevel error -i "$converted_path" -i "$chapter_txt" -map_metadata 1 -codec copy "$temp_output"

# === 提取封面圖 ===
cover_img="$dir_path/cover_temp.jpg"
ffmpeg -hide_banner -loglevel error -i "$media_path" -an -vcodec copy "$cover_img" 2>/dev/null

# === 將封面圖嵌回新檔（若有）===
output_file="$dir_path/${base_clean}_$timestamp.$final_ext"
if [ -f "$cover_img" ]; then
  echo "🖼 偵測到封面圖，嵌入至新檔案..."
  ffmpeg -hide_banner -loglevel error -i "$temp_output" -i "$cover_img" \
    -map 0 -map 1 -c copy -disposition:1 attached_pic "$output_file"
  rm -f "$cover_img" "$temp_output"
else
  echo "⚠️ 未偵測到封面圖，使用章節檔案"
  mv "$temp_output" "$output_file"
fi

# === 清除暫存 ===
rm -f "$info_json" "$chapter_txt"
[[ "$extension" == "mp3" ]] && rm -f "$converted_path"

echo "✅ 處理完成！章節與封面已嵌入：$output_file"