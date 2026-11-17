#!/bin/sh
# macOS Menu Bar 項目間距與內距快速調整工具 (雙作用域同步版)

set -e

show_usage() {
    cat <<EOF
用法: $(basename "$0") <模式 | 間距數值> [選取內距數值]

預設模式:
  ultra     極限壓縮模式 (間距: -6, 內距: -2) —— 接近 Thaw 負值滑桿效果
  tight     緊密模式     (間距: -2, 內距: 0)  —— 明顯縮緊且不易誤觸重疊
  compact   貼合模式     (間距: 0,  內距: 0)
  reset     清除所有覆寫，還原為 macOS 系統預設寬度
  status    檢視目前雙作用域生效的參數數值

自訂數值範例:
  $(basename "$0") -4       # 間距與內距皆設為 -4
  $(basename "$0") -4 0     # 間距設為 -4，游標懸停內距設為 0
EOF
}

is_int() {
    case "$1" in
        "" | "-" | *[!0-9-]* | ?*-*) return 1 ;;
        *) return 0 ;;
    esac
}

reload_prompt() {
    killall ControlCenter SystemUIServer 2>/dev/null || true
    echo "------------------------------------------------------------"
    echo "提示：系統元件已重載，但所有第三方 App 必須「登出再重新登入」"
    echo "（快捷鍵 Cmd + Shift + Q）才會套用新的欄位寬度。"
    echo "------------------------------------------------------------"
}

show_status() {
    echo "=== 標準全域 (-globalDomain) ==="
    echo "NSStatusItemSpacing:          $(defaults read -g NSStatusItemSpacing 2>/dev/null || echo '未設定 (預設)')"
    echo "NSStatusItemSelectionPadding: $(defaults read -g NSStatusItemSelectionPadding 2>/dev/null || echo '未設定 (預設)')"
    echo ""
    echo "=== 本機硬體域 (-currentHost) ==="
    echo "NSStatusItemSpacing:          $(defaults -currentHost read -g NSStatusItemSpacing 2>/dev/null || echo '未設定 (預設)')"
    echo "NSStatusItemSelectionPadding: $(defaults -currentHost read -g NSStatusItemSelectionPadding 2>/dev/null || echo '未設定 (預設)')"
}

apply_spacing() {
    spacing="$1"
    padding="$2"
    defaults write -g NSStatusItemSpacing -int "$spacing"
    defaults write -g NSStatusItemSelectionPadding -int "$padding"
    defaults -currentHost write -g NSStatusItemSpacing -int "$spacing"
    defaults -currentHost write -g NSStatusItemSelectionPadding -int "$padding"
    echo "已同步寫入雙作用域 -> 間距 (Spacing): $spacing | 內距 (Padding): $padding"
    reload_prompt
}

reset_spacing() {
    defaults delete -g NSStatusItemSpacing 2>/dev/null || true
    defaults delete -g NSStatusItemSelectionPadding 2>/dev/null || true
    defaults -currentHost delete -g NSStatusItemSpacing 2>/dev/null || true
    defaults -currentHost delete -g NSStatusItemSelectionPadding 2>/dev/null || true
    echo "已清除所有自訂參數，恢復為 macOS 系統預設寬度。"
    reload_prompt
}

if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

case "$1" in
    ultra)
        apply_spacing -6 -2
        ;;
    tight)
        apply_spacing -2 0
        ;;
    compact)
        apply_spacing 0 0
        ;;
    reset|default)
        reset_spacing
        ;;
    status)
        show_status
        ;;
    -h|--help|help)
        show_usage
        ;;
    *)
        if is_int "$1"; then
            SPACING_VAL="$1"
            PADDING_VAL="${2:-$1}"
            if ! is_int "$PADDING_VAL"; then
                echo "錯誤：內距數值必須為整數。" >&2
                exit 1
            fi
            apply_spacing "$SPACING_VAL" "$PADDING_VAL"
        else
            echo "錯誤：無效的參數 '$1'" >&2
            show_usage
            exit 1
        fi
        ;;
esac
