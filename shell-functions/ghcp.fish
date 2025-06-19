# GitHub PR Cherry Pick Function for Fish Shell
# Save this file as ~/.config/fish/functions/ghcp.fish

function ghcp --description "Cherry pick all commits from a GitHub Pull Request"
  set -l pr_number ""
  set -l dry_run false
  set -l verbose false
  set -l recovery_mode false

  # Parse arguments
  for arg in $argv
    switch $arg
      case -h --help
        echo "Usage: ghcp <PR_NUMBER> [OPTIONS]"
        echo "       ghcp --recover <PR_NUMBER>"
        echo "       ghcp --status"
        echo ""
        echo "Options:"
        echo "  -n, --dry-run          Show what would be done without executing"
        echo "  -v, --verbose          Enable verbose output"
        echo "  --recover <PR_NUMBER>  Recover from previous failed cherry-pick"
        echo "  --status               Show current cherry-pick status"
        echo "  -h, --help             Show this help message"
        return 0
      case -n --dry-run
        set dry_run true
      case -v --verbose
        set verbose true
      case --recover
        set recovery_mode true
        # Next argument should be PR number
        set -l next_idx (math (contains -i $arg $argv) + 1)
        if test $next_idx -le (count $argv)
          set pr_number $argv[$next_idx]
          if not string match -qr '^\d+$' $pr_number
            echo "Error: Recovery mode requires a valid PR number" >&2
            return 1
          end
        else
          echo "Error: Recovery mode requires a PR number" >&2
          return 1
        end
      case --status
        if test -f "$HOME/.ghcp_recovery"
          echo "Recovery information found:"
          source "$HOME/.ghcp_recovery"
          echo "  - PR: #$PR_NUMBER"
          echo "  - Progress: $SUCCESS_COUNT/$TOTAL_COUNT commits"
          echo "  - Failed at: $FAILED_AT_COMMIT"
          echo ""
          echo "Use 'ghcp --recover $PR_NUMBER' to continue"
        else
          echo "No recovery information found"
        end
        return 0
      case '-*'
        echo "Error: Unknown option: $arg" >&2
        return 1
      case '*'
        if string match -qr '^\d+$' $arg
          set pr_number $arg
        else
          echo "Error: Invalid PR number: $arg" >&2
          return 1
        end
    end
  end

  # Handle recovery mode
  if test "$recovery_mode" = true
    _ghcp_handle_recovery $pr_number
    return $status
  end

  # Check if PR number was provided
  if test -z "$pr_number"
    echo "Error: PR number is required" >&2
    echo "Usage: ghcp <PR_NUMBER>"
  return 1
  end

  # Enable verbose mode if requested
  if test "$verbose" = true
    set -g fish_trace 1
  end

  # Check requirements
  if not _ghcp_check_requirements
    return 1
  end

  # Get and display commits
  set -l commits (_ghcp_get_pr_commits $pr_number)
  if test $status -ne 0
    return 1
  end

  _ghcp_display_commits $commits

  # Dry run mode
  if test "$dry_run" = true
    echo "🔍 DRY RUN MODE - No changes will be made"
    set -l commit_count (echo $commits | wc -l | string trim)
    echo "✅ All checks passed. Ready to cherry-pick $commit_count commits"
    echo ""
    echo "To execute for real, run: ghcp $pr_number"
    return 0
  end

  # Confirm operation
  if not _ghcp_confirm_operation
    return 0
  end

  # Execute cherry pick
  _ghcp_cherry_pick_commits $commits $pr_number
end

# Helper function: Check requirements
function _ghcp_check_requirements
  # Check if we're in a git repository
  if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
    echo "Error: Current directory is not a git repository" >&2
    return 1
  end

  # Check if working directory is clean
  if not git diff-index --quiet HEAD -- 2>/dev/null
    echo "Warning: Working directory has uncommitted changes"
    read -P "Continue anyway? This could lead to conflicts. [y/N] " -l response
    if not string match -qr '^[Yy]' $response
      echo "Operation cancelled. Please commit or stash your changes first."
      return 1
    end
  end

  # Check if we're on a detached HEAD
  if not git symbolic-ref HEAD >/dev/null 2>&1
    echo "Error: You are in 'detached HEAD' state. Please checkout a branch first." >&2
    return 1
  end

  # Check if GitHub CLI is installed
  if not command -q gh
    echo "Error: GitHub CLI (gh) not found, please install it first" >&2
    echo "Install instructions: https://cli.github.com/"
    return 1
  end

  # Check GitHub CLI authentication
  if not gh auth status >/dev/null 2>&1
    echo "Error: GitHub CLI is not authenticated" >&2
    echo "Please run: gh auth login"
    return 1
  end

  # Check if jq is available
  if not command -q jq
    echo "Error: jq not found, please install it first" >&2
    echo "jq is required for parsing GitHub CLI JSON output"
    return 1
  end

  return 0
end

# Helper function: Get PR commits
function _ghcp_get_pr_commits
  set -l pr_number $argv[1]

  echo "Fetching commits from PR #$pr_number..."

  # Get commits in chronological order
  set -l commits (gh pr view $pr_number --json commits --jq '.commits | sort_by(.committedDate) | .[].oid' 2>/dev/null)

  if test $status -ne 0
    echo "Error: Unable to fetch PR #$pr_number" >&2
    echo "Please check:"
    echo "  - PR number is correct"
    echo "  - You have access to the repository"
    echo "  - You're authenticated with GitHub CLI (run 'gh auth status')"
    return 1
  end

  if test -z "$commits"
    echo "Error: No commits found in PR #$pr_number" >&2
    return 1
  end

  echo $commits
end

# Helper function: Display commits
function _ghcp_display_commits
  set -l commits $argv[1]
  set -l commit_count (echo $commits | wc -l | string trim)

  echo "Found $commit_count commits to cherry pick:"
  echo ""

  set -l index 1
  for commit in (string split \n $commits)
    if test -n "$commit"
      set -l commit_msg (git log --oneline -1 $commit 2>/dev/null; or echo "Unable to get commit info")
      printf "%2d. %s - %s\n" $index $commit $commit_msg
      set index (math $index + 1)
    end
  end
  echo ""
end

# Helper function: Confirm operation
function _ghcp_confirm_operation
  while true
    read -P "Continue cherry picking these commits? [y/N] " -l response
    switch $response
      case Y y Yes yes
        return 0
      case N n No no ''
        echo "Operation cancelled"
        return 1
      case '*'
        echo "Please answer yes (y) or no (n)"
    end
  end
end

# Helper function: Cherry pick commits
function _ghcp_cherry_pick_commits
  set -l commits $argv[1]
  set -l pr_number $argv[2]
  set -l success_count 0
  set -l total_count (echo $commits | wc -l | string trim)

  echo "Starting cherry pick for PR #$pr_number commits..."
  echo ""

  # Create temp file for commit list
  set -l temp_file (mktemp)
  echo $commits > $temp_file

  set -l index 1
  for commit in (string split \n $commits)
    if test -n "$commit"
      printf "[%d/%d] Cherry picking commit: %s\n" $index $total_count $commit

      if git cherry-pick $commit
        echo "✓ Successfully cherry picked commit: $commit"
        set success_count (math $success_count + 1)
      else
        echo "✗ Cherry pick failed for commit: $commit"
        echo ""
        echo "Please resolve conflicts and run one of the following commands:"
        echo "  - Continue: git cherry-pick --continue"
        echo "  - Skip: git cherry-pick --skip"
        echo "  - Abort: git cherry-pick --abort"
        echo ""
        echo "After resolving, you can manually continue with remaining commits"
        echo "or re-run: ghcp $pr_number"

        # Save recovery information
        echo "FAILED_AT_COMMIT=$commit" > "$HOME/.ghcp_recovery"
        echo "PR_NUMBER=$pr_number" >> "$HOME/.ghcp_recovery"
        echo "SUCCESS_COUNT=$success_count" >> "$HOME/.ghcp_recovery"
        echo "TOTAL_COUNT=$total_count" >> "$HOME/.ghcp_recovery"

        rm -f $temp_file
        return 1
      end
      set index (math $index + 1)
    end
  end

  # Clean up
  rm -f $temp_file
  rm -f "$HOME/.ghcp_recovery"

  echo ""
  echo "🎉 Successfully cherry picked all $success_count commits from PR #$pr_number!"
end

# Helper function: Handle recovery
function _ghcp_handle_recovery
  set -l pr_number $argv[1]

  if not test -f "$HOME/.ghcp_recovery"
    echo "Error: No recovery information found" >&2
    return 1
  end

  echo "Loading recovery information..."
  source "$HOME/.ghcp_recovery"

  if test "$PR_NUMBER" != "$pr_number"
    echo "Error: Recovery file is for PR #$PR_NUMBER, but you requested PR #$pr_number" >&2
    return 1
  end

  echo "Recovered state:"
  echo "  - PR: #$PR_NUMBER"
  echo "  - Progress: $SUCCESS_COUNT/$TOTAL_COUNT commits"
  echo "  - Failed at: $FAILED_AT_COMMIT"

  # Check current git state
  if git diff-index --quiet HEAD -- 2>/dev/null
    echo "Warning: No conflicts detected. The previous conflict may have been resolved."
    read -P "Continue with remaining commits? [y/N] " -l response
    if not string match -qr '^[Yy]' $response
      return 0
    end
    echo "Recovery functionality would continue here..."
  else
    echo "Conflicts still exist. Please resolve them first:"
    git status --porcelain
    echo ""
    echo "After resolving conflicts:"
    echo "  - Continue: git cherry-pick --continue && ghcp --recover $pr_number"
    echo "  - Skip: git cherry-pick --skip && ghcp --recover $pr_number"
    echo "  - Abort: git cherry-pick --abort && rm ~/.ghcp_recovery"
  end
end
