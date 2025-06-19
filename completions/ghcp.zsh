#compdef ghcp

# Zsh completion for ghcp
# Save this file to a directory in your $fpath, typically:
# ~/.zsh/completions/_ghcp or /usr/local/share/zsh/site-functions/_ghcp

_ghcp() {
    local context state line
    typeset -A opt_args
    
    _arguments -C \
        '1: :_ghcp_commands' \
        '*:: :->args' \
        && return 0
    
    case $state in
        args)
            case $words[1] in
                --recover)
                    _ghcp_pr_numbers
                    ;;
                *)
                    _ghcp_pr_numbers
                    ;;
            esac
            ;;
    esac
}

_ghcp_commands() {
    local -a commands
    commands=(
        '--help:Show help message'
        '--status:Show current cherry-pick status'
        '--recover:Recover from failed cherry-pick'
    )
    
    # Add PR numbers if we're in a git repository
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        local -a pr_numbers
        local prs
        if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
            prs=(${(f)"$(gh pr list --json number,title --jq '.[] | "\(.number):\(.title)"' 2>/dev/null | head -20)"})
            if [[ ${#prs[@]} -gt 0 ]]; then
                commands+=($prs)
            fi
        fi
    fi
    
    _describe 'ghcp commands' commands
}

_ghcp_pr_numbers() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        return 1
    fi
    
    if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
        return 1
    fi
    
    local -a pr_numbers
    local prs
    prs=(${(f)"$(gh pr list --json number,title --jq '.[] | "\(.number):\(.title)"' 2>/dev/null | head -20)"})
    
    if [[ ${#prs[@]} -gt 0 ]]; then
        _describe 'PR numbers' prs
    fi
}

# Options completion
_ghcp_options() {
    local -a options
    options=(
        '--help[Show help message]'
        '--status[Show current cherry-pick status]'
        '--recover[Recover from failed cherry-pick]:PR number:_ghcp_pr_numbers'
        '--dry-run[Show what would be done without executing]'
        '--verbose[Enable verbose output]'
        '-h[Show help message]'
        '-n[Show what would be done without executing]'
        '-v[Enable verbose output]'
    )
    
    _describe 'options' options
}

# 只在補全環境中註冊函數，不要直接執行
# 移除了原本的 _ghcp "$@" 這行