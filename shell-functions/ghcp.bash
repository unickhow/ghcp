# GitHub PR Cherry Pick Function for Bash
# Source this file in your .bashrc: source /path/to/ghcp.bash

ghcp() {
	local pr_number=""
	local dry_run=false
  local verbose=false
  local recovery_mode=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
		case $1 in
			-h|--help)
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
				;;
			-n|--dry-run)
				dry_run=true
				shift
				;;
			-v|--verbose)
				verbose=true
				shift
				;;
			--recover)
				recovery_mode=true
				shift
				if [[ $# -gt 0 ]] && [[ $1 =~ ^[0-9]+$ ]]; then
					pr_number="$1"
					shift
				else
					echo "Error: Recovery mode requires a PR number" >&2
					return 1
				fi
				;;
			--status)
				if [ -f "$HOME/.ghcp_recovery" ]; then
					echo "Recovery information found:"
					source "$HOME/.ghcp_recovery"
					echo "  - PR: #$PR_NUMBER"
					echo "  - Progress: $SUCCESS_COUNT/$TOTAL_COUNT commits"
					echo "  - Failed at: $FAILED_AT_COMMIT"
					echo ""
					echo "Use 'ghcp --recover $PR_NUMBER' to continue"
				else
					echo "No recovery information found"
				fi
				return 0
				;;
			-*)
				echo "Error: Unknown option: $1" >&2
				return 1
				;;
			*)
				if [[ $1 =~ ^[0-9]+$ ]]; then
					pr_number="$1"
				else
					echo "Error: Invalid PR number: $1" >&2
					return 1
				fi
				shift
				;;
		esac
  done

  # Handle recovery mode
  if [ "$recovery_mode" = true ]; then
		_ghcp_handle_recovery "$pr_number"
		return $?
  fi

  # Check if PR number was provided
  if [ -z "$pr_number" ]; then
		echo "Error: PR number is required" >&2
		echo "Usage: ghcp <PR_NUMBER>"
		return 1
  fi

  # Enable verbose mode if requested
  if [ "$verbose" = true ]; then
		set -x
  fi

  # Check requirements
  _ghcp_check_requirements || return 1

  # Get and display commits
  local commits
  commits=$(_ghcp_get_pr_commits "$pr_number") || return 1
  _ghcp_display_commits "$commits"

  # Dry run mode
  if [ "$dry_run" = true ]; then
		echo "🔍 DRY RUN MODE - No changes will be made"
		local commit_count
		commit_count=$(echo "$commits" | wc -l | tr -d ' ')
		echo "✅ All checks passed. Ready to cherry-pick $commit_count commits"
		echo ""
		echo "To execute for real, run: ghcp $pr_number"
		return 0
  fi

  # Confirm operation
  _ghcp_confirm_operation || return 0

  # Execute cherry pick
  _ghcp_cherry_pick_commits "$commits" "$pr_number"
}

# Helper function: Check requirements
_ghcp_check_requirements() {
  # Check if we're in a git repository
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		echo "Error: Current directory is not a git repository" >&2
		return 1
  fi

  # Check if working directory is clean
  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
		echo "Warning: Working directory has uncommitted changes"
		printf "Continue anyway? This could lead to conflicts. [y/N] "
		read -r response
		if [[ ! "$response" =~ ^[Yy]$ ]]; then
			echo "Operation cancelled. Please commit or stash your changes first."
			return 1
		fi
  fi

  # Check if we're on a detached HEAD
  if ! git symbolic-ref HEAD >/dev/null 2>&1; then
		echo "Error: You are in 'detached HEAD' state. Please checkout a branch first." >&2
		return 1
  fi

  # Check if GitHub CLI is installed
  if ! command -v gh >/dev/null 2>&1; then
		echo "Error: GitHub CLI (gh) not found, please install it first" >&2
		echo "Install instructions: https://cli.github.com/"
		return 1
  fi

  # Check GitHub CLI authentication
  if ! gh auth status >/dev/null 2>&1; then
		echo "Error: GitHub CLI is not authenticated" >&2
		echo "Please run: gh auth login"
		return 1
  fi

  # Check if jq is available
  if ! command -v jq >/dev/null 2>&1; then
		echo "Error: jq not found, please install it first" >&2
		echo "jq is required for parsing GitHub CLI JSON output"
		return 1
  fi

  return 0
}

# Helper function: Get PR commits
_ghcp_get_pr_commits() {
  local pr_number="$1"
  local commits

  echo "Fetching commits from PR #$pr_number..."

  # Get commits in chronological order
  if ! commits=$(gh pr view "$pr_number" --json commits --jq '.commits | sort_by(.committedDate) | .[].oid' 2>/dev/null); then
		echo "Error: Unable to fetch PR #$pr_number" >&2
		echo "Please check:"
		echo "  - PR number is correct"
		echo "  - You have access to the repository"
		echo "  - You're authenticated with GitHub CLI (run 'gh auth status')"
		return 1
  fi

  if [ -z "$commits" ]; then
		echo "Error: No commits found in PR #$pr_number" >&2
		return 1
  fi

  echo "$commits"
}

# Helper function: Display commits
_ghcp_display_commits() {
  local commits="$1"
  local commit_count
  commit_count=$(echo "$commits" | wc -l | tr -d ' ')

  echo "Found $commit_count commits to cherry pick:"
  echo ""

  local index=1
  while IFS= read -r commit; do
		if [ -n "$commit" ]; then
			local commit_msg
			commit_msg=$(git log --oneline -1 "$commit" 2>/dev/null || echo "Unable to get commit info")
			printf "%2d. %s - %s\n" "$index" "$commit" "$commit_msg"
			index=$((index + 1))
		fi
  done <<< "$commits"
  echo ""
}

# Helper function: Confirm operation
_ghcp_confirm_operation() {
  while true; do
		printf "Continue cherry picking these commits? [y/N] "
		read -r response
		case "$response" in
			[Yy]|[Yy][Ee][Ss])
				return 0
				;;
			[Nn]|[Nn][Oo]|"")
				echo "Operation cancelled"
				return 1
				;;
			*)
				echo "Please answer yes (y) or no (n)"
				;;
		esac
  done
}

# Helper function: Cherry pick commits
_ghcp_cherry_pick_commits() {
  local commits="$1"
  local pr_number="$2"
  local success_count=0
  local total_count
  total_count=$(echo "$commits" | wc -l | tr -d ' ')

  echo "Starting cherry pick for PR #$pr_number commits..."
  echo ""

  # Create temp file for commit list
  local temp_file
  temp_file=$(mktemp)
  echo "$commits" > "$temp_file"

  local index=1
  while IFS= read -r commit; do
		if [ -n "$commit" ]; then
			printf "[%d/%d] Cherry picking commit: %s\n" "$index" "$total_count" "$commit"

			if git cherry-pick "$commit"; then
				echo "✓ Successfully cherry picked commit: $commit"
				success_count=$((success_count + 1))
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

				rm -f "$temp_file"
				return 1
			fi
			index=$((index + 1))
		fi
  done < "$temp_file"

  # Clean up
  rm -f "$temp_file"
  rm -f "$HOME/.ghcp_recovery"

  echo ""
  echo "🎉 Successfully cherry picked all $success_count commits from PR #$pr_number!"
}

# Helper function: Handle recovery
_ghcp_handle_recovery() {
  local pr_number="$1"

  if [ ! -f "$HOME/.ghcp_recovery" ]; then
		echo "Error: No recovery information found" >&2
		return 1
  fi

  echo "Loading recovery information..."
  source "$HOME/.ghcp_recovery"

  if [ "$PR_NUMBER" != "$pr_number" ]; then
		echo "Error: Recovery file is for PR #$PR_NUMBER, but you requested PR #$pr_number" >&2
		return 1
  fi

  echo "Recovered state:"
  echo "  - PR: #$PR_NUMBER"
  echo "  - Progress: $SUCCESS_COUNT/$TOTAL_COUNT commits"
  echo "  - Failed at: $FAILED_AT_COMMIT"

  # Check current git state
  if git diff-index --quiet HEAD -- 2>/dev/null; then
		echo "Warning: No conflicts detected. The previous conflict may have been resolved."
		printf "Continue with remaining commits? [y/N] "
		read -r response
		if [[ ! "$response" =~ ^[Yy]$ ]]; then
			return 0
		fi
		echo "Recovery functionality would continue here..."
  else
		echo "Conflicts still exist. Please resolve them first:"
		git status --porcelain
		echo ""
		echo "After resolving conflicts:"
		echo "  - Continue: git cherry-pick --continue && ghcp --recover $pr_number"
		echo "  - Skip: git cherry-pick --skip && ghcp --recover $pr_number"
		echo "  - Abort: git cherry-pick --abort && rm ~/.ghcp_recovery"
  fi
}
