#!/bin/bash
# ghcp uninstaller script

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}$1${NC}"; }
print_success() { echo -e "${GREEN}$1${NC}"; }
print_warning() { echo -e "${YELLOW}$1${NC}"; }
print_error() { echo -e "${RED}$1${NC}" >&2; }

# 使用與安裝腳本相同的 shell 檢測邏輯
detect_shell() {
  # 如果用戶手動指定了 shell 類型，優先使用
  if [ -n "${GHCP_SHELL_TYPE:-}" ]; then
    case "${GHCP_SHELL_TYPE}" in
      zsh|bash|fish)
        echo "$GHCP_SHELL_TYPE"
        return 0
        ;;
      *)
        print_warning "⚠️  Invalid GHCP_SHELL_TYPE: $GHCP_SHELL_TYPE (using auto-detection)"
        ;;
    esac
  fi

  # 優先檢查 $SHELL 環境變量
  if [ -n "$SHELL" ]; then
    case "$SHELL" in
      */zsh) echo "zsh" ;;
      */bash) echo "bash" ;;
      */fish) echo "fish" ;;
      */dash) echo "bash" ;;  # dash 當作 bash 處理
      */sh) echo "bash" ;;    # sh 當作 bash 處理
      *)
        # 如果 $SHELL 路徑不清楚，檢查版本變量
        if [ -n "$ZSH_VERSION" ]; then
          echo "zsh"
        elif [ -n "$FISH_VERSION" ]; then
          echo "fish" 
        elif [ -n "$BASH_VERSION" ]; then
          echo "bash"
        else
          echo "unknown"
        fi
        ;;
    esac
  else
    # 沒有 $SHELL 環境變量，回退到版本檢查
    if [ -n "$ZSH_VERSION" ]; then
      echo "zsh"
    elif [ -n "$FISH_VERSION" ]; then
      echo "fish"
    elif [ -n "$BASH_VERSION" ]; then
      echo "bash"
    else
      echo "unknown"
    fi
  fi
}

# 檢測當前安裝狀態
detect_installation() {
  print_info "📋 Checking installation status..."

  local detected_shell
  detected_shell=$(detect_shell)

  print_info "Shell detection:"
  print_info "  \$SHELL environment variable: ${SHELL:-not set}"
  print_info "  Current executing shell: $(ps -p $ -o comm= 2>/dev/null || echo "unknown")"
  print_info "  Detected user shell: $detected_shell"
  echo ""

  local found_installations=()

  # 檢查 standalone 安裝
  local -a standalone_locations=(
    "$HOME/.local/bin/ghcp"
    "/usr/local/bin/ghcp"
    "/opt/homebrew/bin/ghcp"
    "/usr/bin/ghcp"
  )

  print_info "Checking standalone installation:"
  for location in "${standalone_locations[@]}"; do
    if [ -f "$location" ]; then
      if [ -L "$location" ]; then
        local target
        target=$(readlink "$location")
        print_warning "  ✓ Found symbolic link: $location -> $target"
        found_installations+=("standalone_link:$location")
      else
        print_success "  ✓ Found executable file: $location"
        found_installations+=("standalone:$location")
      fi
    else
      print_info "  - Not found: $location"
    fi
  done
  echo ""

  # 檢查 shell function 安裝
  print_info "Checking shell function installation:"

  # 檢查 .ghcp 目錄
  if [ -d "$HOME/.ghcp" ]; then
    print_success "  ✓ Found ghcp directory: $HOME/.ghcp"
    found_installations+=("ghcp_dir:$HOME/.ghcp")

    for shell_type in zsh bash fish; do
      if [ -f "$HOME/.ghcp/ghcp.$shell_type" ]; then
        print_success "    ✓ Found $shell_type function: ghcp.$shell_type"
        found_installations+=("function:$shell_type")
      fi

      if [ -f "$HOME/.ghcp/ghcp_completion.$shell_type" ]; then
        print_success "    ✓ Found $shell_type completion: ghcp_completion.$shell_type"
        found_installations+=("completion:$shell_type")
      fi
    done
  else
    print_info "  - Not found ghcp directory"
  fi

  # 檢查 zsh 補全特殊位置
  if [ -f "$HOME/.zsh/completions/_ghcp" ]; then
    print_success "  ✓ Found zsh completion: ~/.zsh/completions/_ghcp"
    found_installations+=("zsh_completion:$HOME/.zsh/completions/_ghcp")
  fi

  # 檢查 fish 特殊安裝位置
  if [ -f "$HOME/.config/fish/functions/ghcp.fish" ]; then
    print_success "  ✓ Found fish function: ~/.config/fish/functions/ghcp.fish"
    found_installations+=("fish_function:$HOME/.config/fish/functions/ghcp.fish")
  fi

  if [ -f "$HOME/.config/fish/completions/ghcp.fish" ]; then
    print_success "  ✓ Found fish completion: ~/.config/fish/completions/ghcp.fish"
    found_installations+=("fish_completion:$HOME/.config/fish/completions/ghcp.fish")
  fi

  # 檢查 shell 配置文件
  print_info "Checking shell configuration file references:"

  local config_files=()
  [ -f "$HOME/.zshrc" ] && config_files+=("$HOME/.zshrc")
  [ -f "$HOME/.bashrc" ] && config_files+=("$HOME/.bashrc")
  [ -f "$HOME/.config/fish/config.fish" ] && config_files+=("$HOME/.config/fish/config.fish")

  for config_file in "${config_files[@]}"; do
    if grep -q "ghcp" "$config_file" 2>/dev/null; then
      print_warning "  ✓ Found ghcp reference in configuration file: $config_file"
      found_installations+=("config:$config_file")
    else
      print_info "  - Not found reference in configuration file: $config_file"
    fi
  done
  echo ""

  # 檢查 Oh My Zsh plugin
  local omz_plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/ghcp"
  if [ -d "$omz_plugin_dir" ]; then
    print_success "  ✓ Found Oh My Zsh plugin: $omz_plugin_dir"
    found_installations+=("omz_plugin:$omz_plugin_dir")
  fi

  # 檢查 recovery 文件
  if [ -f "$HOME/.ghcp_recovery" ]; then
    print_info "  ✓ Found recovery file: $HOME/.ghcp_recovery"
    found_installations+=("recovery:$HOME/.ghcp_recovery")
  fi

  # 檢查 Homebrew 安裝
  if command -v brew >/dev/null 2>&1; then
    if brew list ghcp >/dev/null 2>&1; then
      print_success "  ✓ Found Homebrew installation: brew list ghcp"
      found_installations+=("homebrew:ghcp")
    fi
  fi

  if [ ${#found_installations[@]} -eq 0 ]; then
    print_warning "⚠️  No ghcp installations found"
    return 1
  fi

  print_success "✅ Found ${#found_installations[@]} installations"
  return 0
}

remove_standalone() {
  print_info "🗑️  Removing standalone executable files..."

  local removed=false

  # 檢查常見安裝位置
  local -a locations=(
    "$HOME/.local/bin/ghcp"
    "/usr/local/bin/ghcp"
    "/opt/homebrew/bin/ghcp"
    "/usr/bin/ghcp"
  )

  for location in "${locations[@]}"; do
    if [ -f "$location" ] || [ -L "$location" ]; then
      if rm -f "$location" 2>/dev/null; then
        print_success "✅ Removed: $location"
        removed=true
      else
        print_warning "⚠️  Cannot remove: $location (permission denied)"
      fi
    fi
  done

  if [ "$removed" = false ]; then
    print_info "No standalone executable files found"
  fi
}

remove_shell_function() {
  local shell_type="$1"
  print_info "🗑️  Removing $shell_type shell function..."

  local function_file="$HOME/.ghcp/ghcp.$shell_type"
  local completion_file="$HOME/.ghcp/ghcp_completion.$shell_type"
  local removed=false

  # 移除函數文件
  if [ -f "$function_file" ]; then
    rm -f "$function_file"
    print_success "✅ Removed: $function_file"
    removed=true
  fi

  # 處理不同 shell 的補全移除
  case "$shell_type" in
    zsh)
      # 移除 zsh 補全文件
      local zsh_completion="$HOME/.zsh/completions/_ghcp"
      if [ -f "$zsh_completion" ]; then
        rm -f "$zsh_completion"
        print_success "✅ Removed: $zsh_completion"
        removed=true
      fi

      # 移除舊格式的補全文件（如果存在）
      if [ -f "$completion_file" ]; then
        rm -f "$completion_file"
        print_success "✅ Removed: $completion_file"
        removed=true
      fi
      ;;
    bash)
      if [ -f "$completion_file" ]; then
        rm -f "$completion_file"
        print_success "✅ Removed: $completion_file"
        removed=true
      fi
      ;;
    fish)
      # 移除 fish 補全文件
      local fish_function="$HOME/.config/fish/functions/ghcp.fish"
      local fish_completion="$HOME/.config/fish/completions/ghcp.fish"

      if [ -f "$fish_function" ]; then
        rm -f "$fish_function"
        print_success "✅ Removed: $fish_function"
        removed=true
      fi

      if [ -f "$fish_completion" ]; then
        rm -f "$fish_completion"
        print_success "✅ Removed: $fish_completion"
        removed=true
      fi

      # 移除舊格式的補全文件（如果存在）
      if [ -f "$completion_file" ]; then
        rm -f "$completion_file"
        print_success "✅ Removed: $completion_file"
        removed=true
      fi
      ;;
  esac

  # 從 shell 配置文件中移除
  local config_file
  case "$shell_type" in
    zsh)
      config_file="$HOME/.zshrc"
      ;;
    bash)
      config_file="$HOME/.bashrc"
      ;;
    fish)
      config_file="$HOME/.config/fish/config.fish"
      ;;
  esac

  if [ -f "$config_file" ] && grep -q "ghcp" "$config_file" 2>/dev/null; then
    # 創建備份
    cp "$config_file" "$config_file.ghcp-uninstall-backup-$(date +%Y%m%d-%H%M%S)"

    # 移除 ghcp 相關行
    case "$shell_type" in
      zsh)
        # 移除 ghcp 相關的所有行：函數、補全、fpath
        if sed '/# ghcp/,+3d; /fpath.*\.zsh\/completions/d' "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"; then
            print_success "✅ Removed ghcp configuration from $config_file"
            removed=true
        fi
        ;;
      fish)
        # Fish shell 處理
        if grep -v "ghcp" "$config_file" > "$config_file.tmp"; then
            mv "$config_file.tmp" "$config_file"
            print_success "✅ Removed ghcp configuration from $config_file"
            removed=true
        fi
        ;;
      bash)
        # Bash 處理
        if sed '/# ghcp/,+2d' "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"; then
            print_success "✅ Removed ghcp configuration from $config_file"
            removed=true
        fi
        ;;
    esac

    print_info "   (Created backup file)"
  fi

  if [ "$removed" = false ]; then
    print_info "No $shell_type shell function installation found"
  fi
}

remove_oh_my_zsh_plugin() {
  print_info "🗑️  Removing Oh My Zsh plugin..."

  local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/ghcp"

  if [ -d "$plugin_dir" ]; then
    rm -rf "$plugin_dir"
    print_success "✅ Removed: $plugin_dir"

    # 檢查 .zshrc 中的插件列表
    if [ -f "$HOME/.zshrc" ] && grep -q "plugins.*ghcp" "$HOME/.zshrc"; then
      print_warning "⚠️  Please manually remove 'ghcp' from the plugins list in ~/.zshrc"
      print_info "    Look for similar: plugins=(... ghcp ...)"
    fi
  else
    print_info "No Oh My Zsh plugin found"
  fi
}

remove_homebrew_package() {
  print_info "🗑️  Removing Homebrew package..."

  if command -v brew >/dev/null 2>&1; then
    if brew list ghcp >/dev/null 2>&1; then
      brew uninstall ghcp
      print_success "✅ Removed Homebrew package"
    else
      print_info "No Homebrew package found"
    fi
  else
    print_info "No Homebrew package found"
  fi
}

remove_recovery_files() {
  print_info "🗑️  Removing recovery and temporary files..."

  local -a files=(
    "$HOME/.ghcp_recovery"
    "$HOME/.ghcp"
  )

  for file in "${files[@]}"; do
    if [ -e "$file" ]; then
      rm -rf "$file"
      print_success "✅ Removed: $file"
    fi
  done
}

get_uninstall_mode() {
  # 檢查環境變量
  if [ -n "${GHCP_UNINSTALL_MODE:-}" ]; then
    echo "$GHCP_UNINSTALL_MODE"
    return 0
  fi

  # 默認移除所有
  echo "all"
}

show_uninstall_summary() {
  echo ""
  print_info "📋 Uninstall summary:"
  print_info "============"

  # 驗證移除結果
  local remaining_items=0

  # 檢查是否還有安裝
  for location in "$HOME/.local/bin/ghcp" "/usr/local/bin/ghcp" "/opt/homebrew/bin/ghcp" "/usr/bin/ghcp"; do
    if [ -f "$location" ]; then
      print_warning "⚠️  Still exists: $location"
      remaining_items=$((remaining_items + 1))
    fi
  done

  if [ -d "$HOME/.ghcp" ]; then
    print_warning "⚠️  Still exists: $HOME/.ghcp"
    remaining_items=$((remaining_items + 1))
  fi

  if [ "$remaining_items" -eq 0 ]; then
    print_success "✅ All ghcp components have been completely removed!"
  else
    print_warning "⚠️  Found $remaining_items remaining items"
    print_info "If these are custom installation locations, please manually remove them"
  fi

  echo ""
  print_info "💡 Next steps:"
  echo "1. Restart terminal or run 'source ~/.bashrc' (or ~/.zshrc)"
  echo "2. If there are custom installation locations, please manually remove them"
  echo "3. Check other shell configuration files for any remaining configurations"
}

main() {
  print_info "🗑️  ghcp uninstaller"
  print_info "=================="
  echo ""

  # 檢測安裝狀態
  if ! detect_installation; then
    print_info "No uninstallable content found"
    exit 0
  fi

  echo ""

  # 獲取卸載模式
  local mode
  mode=$(get_uninstall_mode)

  case "$mode" in
    all)
      print_info "🗑️  Performing full uninstall..."

      # 移除所有組件
      remove_standalone
      echo ""

      local detected_shell
      detected_shell=$(detect_shell)
      if [ "$detected_shell" != "unknown" ]; then
          remove_shell_function "$detected_shell"
          echo ""
      fi

      # 也移除其他 shell 的函數（如果存在）
      for shell_type in zsh bash fish; do
          if [ "$shell_type" != "$detected_shell" ] && [ -f "$HOME/.ghcp/ghcp.$shell_type" ]; then
              remove_shell_function "$shell_type"
              echo ""
          fi
      done

      remove_oh_my_zsh_plugin
      echo ""

      remove_homebrew_package
      echo ""

      remove_recovery_files
      ;;
    standalone)
      remove_standalone
      ;;
    function)
      local detected_shell
      detected_shell=$(detect_shell)
      if [ "$detected_shell" = "unknown" ]; then
          print_error "Cannot detect shell type"
          exit 1
      fi
      remove_shell_function "$detected_shell"
      ;;
    *)
      print_error "Invalid uninstall mode: $mode"
      print_info "Valid options: all, standalone, function"
      exit 1
      ;;
  esac

  show_uninstall_summary
}

main "$@"
