#!/bin/bash
# Smart installer for ghcp - detects shell and installs accordingly

set -e

REPO_URL="https://raw.githubusercontent.com/unickhow/ghcp/main"
INSTALL_DIR="$HOME/.ghcp"
BIN_DIR="$HOME/.local/bin"

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

	# 優先檢查 $SHELL 環境變量，這會反映用戶的實際默認 shell
	# 而不是當前腳本執行的 shell
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

install_standalone() {
	print_info "Installing standalone executable version..."

	# Create bin directory if it doesn't exist
	mkdir -p "$BIN_DIR"

	# Download executable
	if curl -fsSL "$REPO_URL/bin/ghcp" -o "$BIN_DIR/ghcp"; then
		chmod +x "$BIN_DIR/ghcp"
		print_success "✅ Standalone version installed to $BIN_DIR/ghcp"
	else
		print_error "❌ Failed to download ghcp executable"
		return 1
	fi

	# Check if bin directory is in PATH
	if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
		print_warning "⚠️  $BIN_DIR is not in your PATH"
		echo "Add this line to your shell configuration file:"
		echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
	fi
}

install_shell_function() {
	local shell_type="$1"
	print_info "Installing $shell_type function version..."

	mkdir -p "$INSTALL_DIR"

	# Download shell-specific function
	if curl -fsSL "$REPO_URL/shell-functions/ghcp.$shell_type" -o "$INSTALL_DIR/ghcp.$shell_type"; then
		print_info "Downloaded function for $shell_type"
	else
		print_error "❌ Failed to download $shell_type function"
		return 1
	fi

	# Handle completion differently for each shell
	case "$shell_type" in
		zsh)
			# For zsh, download completion to fpath directory and rename to _ghcp
			local zsh_completion_dir="$HOME/.zsh/completions"
			mkdir -p "$zsh_completion_dir"

			if curl -fsSL "$REPO_URL/completions/ghcp.zsh" -o "$zsh_completion_dir/_ghcp" 2>/dev/null; then
				print_info "Downloaded zsh completion to $zsh_completion_dir/_ghcp"

				# Add completion directory to fpath in .zshrc if not already there
				local config_file="$HOME/.zshrc"
				if ! grep -q "$zsh_completion_dir" "$config_file" 2>/dev/null; then
					echo "" >> "$config_file"
					echo "# ghcp - GitHub PR Cherry Pick completion" >> "$config_file"
					echo "fpath=(\"$zsh_completion_dir\" \$fpath)" >> "$config_file"
				fi
			fi
			;;
		bash|fish)
			# For bash and fish, download to ghcp directory
			if curl -fsSL "$REPO_URL/completions/ghcp.$shell_type" -o "$INSTALL_DIR/ghcp_completion.$shell_type" 2>/dev/null; then
				print_info "Downloaded completion for $shell_type"
			fi
			;;
	esac

	# Add to shell configuration
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
			mkdir -p "$(dirname "$config_file")"
			;;
	esac

	# Check if already installed
	if ! grep -q "source.*ghcp.$shell_type" "$config_file" 2>/dev/null; then
		echo "" >> "$config_file"
		echo "# ghcp - GitHub PR Cherry Pick" >> "$config_file"
		echo "source \"$INSTALL_DIR/ghcp.$shell_type\"" >> "$config_file"

		# Add completion source for bash and fish (zsh handles it automatically)
		case "$shell_type" in
			bash|fish)
				if [ -f "$INSTALL_DIR/ghcp_completion.$shell_type" ]; then
					echo "source \"$INSTALL_DIR/ghcp_completion.$shell_type\"" >> "$config_file"
				fi
				;;
			zsh)
				# For zsh, just note that completion is available
				echo "# Completion is automatically loaded from fpath" >> "$config_file"
				;;
		esac

		print_success "✅ Added ghcp to $config_file"
	else
		print_info "ghcp already exists in $config_file"
	fi
}

check_dependencies() {
	print_info "Checking dependencies..."

	local missing_deps=()

	# Check curl
	if ! command -v curl >/dev/null 2>&1; then
			missing_deps+=("curl")
	fi

	# Check git (not required for installation but needed for ghcp)
	if ! command -v git >/dev/null 2>&1; then
			print_warning "⚠️  git not found - required for ghcp to work"
	fi

	# Check gh CLI (not required for installation but needed for ghcp)
	if ! command -v gh >/dev/null 2>&1; then
			print_warning "⚠️  GitHub CLI (gh) not found - required for ghcp to work"
			print_info "Install with: brew install gh"
	fi

	# Check jq (not required for installation but needed for ghcp)
	if ! command -v jq >/dev/null 2>&1; then
			print_warning "⚠️  jq not found - required for ghcp to work"
			print_info "Install with: brew install jq"
	fi

	if [ ${#missing_deps[@]} -gt 0 ]; then
			print_error "Missing required dependencies for installation: ${missing_deps[*]}"
			return 1
	fi

	print_success "✅ Installation dependencies satisfied"
}

get_install_type() {
	# 優先使用環境變數
	if [ -n "${GHCP_INSTALL_TYPE:-}" ]; then
		echo "$GHCP_INSTALL_TYPE"
		return 0
	fi

	# 默認安裝類型：兩種都安裝
	echo "3"
}

main() {
	print_info "🚀 Installing ghcp - GitHub PR Cherry Pick tool"
	echo ""

	# Check basic dependencies
	if ! check_dependencies; then
		exit 1
	fi

	# Detect current shell
	local detected_shell
	detected_shell=$(detect_shell)

	print_info "Shell detection:"
	print_info "  \$SHELL environment variable: ${SHELL:-not set}"
	print_info "  Current executing shell: $(ps -p $ -o comm= 2>/dev/null || echo "unknown")"
	print_info "  Detected user shell: $detected_shell"

	# 如果執行 shell 和用戶 shell 不同，給出說明
	local current_shell
	current_shell=$(ps -p $ -o comm= 2>/dev/null | sed 's/^-//' || echo "unknown")
	if [ "$current_shell" != "$detected_shell" ] && [ "$current_shell" != "unknown" ]; then
		print_warning "⚠️  Note: Script is running in $current_shell but installing for $detected_shell"
		print_info "   This is normal when using 'curl | bash'"
	fi

	# Get installation type
	local choice
	choice=$(get_install_type)

	# 根據檢測到的 shell 調整安裝選項
	if [ "$detected_shell" = "unknown" ]; then
		print_warning "Unknown shell detected. Installing standalone version only."
		choice="1"
	fi

	# 顯示安裝計劃
	case "$choice" in
		1)
			print_info "Installing: Standalone executable only"
			;;
		2)
			print_info "Installing: Shell function with completion only"
			;;
		3)
			print_info "Installing: Both standalone and shell function (recommended)"
			;;
		*)
			print_error "Invalid installation type: $choice"
			print_info "Set GHCP_INSTALL_TYPE to 1, 2, or 3"
			exit 1
			;;
	esac

	echo ""

	case "$choice" in
		1)
			install_standalone
			;;
		2)
			if [ "$detected_shell" = "unknown" ]; then
				print_error "Cannot install shell function for unknown shell"
				exit 1
			fi
			install_shell_function "$detected_shell"
			;;
		3)
			install_standalone
			echo ""
			if [ "$detected_shell" != "unknown" ]; then
				install_shell_function "$detected_shell"
			fi
			;;
	esac

	echo ""
	print_success "🎉 Installation complete!"
	echo ""
	print_info "Usage: ghcp <PR_NUMBER>"
	print_info "Example: ghcp 33"
	echo ""

	if [ "$choice" = "2" ] || [ "$choice" = "3" ]; then
		print_warning "Please restart your terminal or run:"
		case "$detected_shell" in
			zsh) echo "source ~/.zshrc" ;;
			bash) echo "source ~/.bashrc" ;;
			fish) echo "source ~/.config/fish/config.fish" ;;
		esac
	fi

	# 顯示下一步建議
	echo ""
	print_info "Next steps:"
	echo "1. Ensure GitHub CLI is authenticated: gh auth login"
	echo "2. Ensure jq is installed: brew install jq"
	echo "3. Test the installation: ghcp --help"

	# 顯示可用的安裝選項給想要自定義的用戶
	echo ""
	print_info "💡 Customization options (for future reference):"
	echo "  GHCP_INSTALL_TYPE=1 curl ... | bash  # Standalone only"
	echo "  GHCP_INSTALL_TYPE=2 curl ... | bash  # Shell function only"
	echo "  GHCP_INSTALL_TYPE=3 curl ... | bash  # Both (default)"
	echo ""
	echo "  GHCP_SHELL_TYPE=zsh curl ... | bash  # Force shell type"
	echo "  GHCP_SHELL_TYPE=bash curl ... | bash"
	echo "  GHCP_SHELL_TYPE=fish curl ... | bash"
}

main "$@"
