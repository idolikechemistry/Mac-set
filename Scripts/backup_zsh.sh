#!/bin/bash

# 定義目標路徑（iCloud 上的文字編輯資料夾）
DEST_DIR="$HOME/Library/Mobile Documents/com~apple~TextEdit/Documents"

# 檢查目標資料夾是否存在，不存在則建立
if [ ! -d "$DEST_DIR" ]; then
    echo "正在建立 iCloud 目標路徑..."
    mkdir -p "$DEST_DIR"
fi

echo "開始備份 Zsh 與 Powerlevel10k 設定檔..."

# 複製 .zshrc
if [ -f "$HOME/.zshrc" ]; then
    cp "$HOME/.zshrc" "$DEST_DIR/.zshrc.bak"
    echo "✅ .zshrc 已備份至 iCloud (檔名: .zshrc.bak)"
else
    echo "❌ 找不到 .zshrc 檔案"
fi

# 複製 .p10k.zsh
if [ -f "$HOME/.p10k.zsh" ]; then
    cp "$HOME/.p10k.zsh" "$DEST_DIR/.p10k.zsh.bak"
    echo "✅ .p10k.zsh 已備份至 iCloud (檔名: .p10k.zsh.bak)"
else
    echo "❌ 找不到 .p10k.zsh 檔案"
fi

echo "--- 備份完成 ---"
