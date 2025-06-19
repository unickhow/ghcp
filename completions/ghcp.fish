# Fish completion for ghcp
# Save this file as ~/.config/fish/completions/ghcp.fish

# Function to get PR numbers and titles
function __ghcp_get_prs
  # Check if we're in a git repository
  if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
    return 1
  end

  # Check if gh CLI is available and authenticated
  if not command -q gh; or not gh auth status >/dev/null 2>&1
    return 1
  end

  # Get PR numbers and titles
  gh pr list --json number,title --jq '.[] | "\(.number)\t\(.title)"' 2>/dev/null | head -20
end

# Function to check if we need PR number completion
function __ghcp_needs_pr_number
  set -l cmd (commandline -poc)

  # If --recover is the previous argument, we need a PR number
  if contains -- --recover $cmd
  # Check if PR number is already provided after --recover
    set -l recover_idx (contains -i -- --recover $cmd)
    if test (count $cmd) -eq $recover_idx
      return 0
    end
  else if test (count $cmd) -eq 1
    # First argument after ghcp should be PR number (unless it's an option)
    return 0
  end
  return 1
end

# Completion for PR numbers
complete -c ghcp -f -n '__ghcp_needs_pr_number' -a '(__ghcp_get_prs)'

# Option completions
complete -c ghcp -s h -l help -d 'Show help message'
complete -c ghcp -s n -l dry-run -d 'Show what would be done without executing'
complete -c ghcp -s v -l verbose -d 'Enable verbose output'
complete -c ghcp -l status -d 'Show current cherry-pick status'
complete -c ghcp -l recover -d 'Recover from failed cherry-pick' -x -a '(__ghcp_get_prs)'

# Subcommand completions
complete -c ghcp -n '__fish_use_subcommand' -a 'help' -d 'Show help message'
complete -c ghcp -n '__fish_use_subcommand' -a 'status' -d 'Show current cherry-pick status'

# Advanced option handling
complete -c ghcp -n '__fish_seen_subcommand_from recover' -x -a '(__ghcp_get_prs)'

# Dynamic completion based on git repository state
complete -c ghcp -n '__fish_use_subcommand; and git rev-parse --is-inside-work-tree >/dev/null 2>&1' -x -a '(__ghcp_get_prs)'
