# Bash completion for ghcp
# Source this file in your .bashrc or save to /etc/bash_completion.d/ghcp

_ghcp_complete() {
	local cur prev opts pr_numbers
	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD-1]}"

	# Available options
	opts="--help --status --recover --dry-run --verbose -h -n -v"

	# If previous word is --recover, complete with PR numbers
	if [[ "$prev" == "--recover" ]]; then
		_ghcp_pr_numbers_complete
		return 0
	fi

	# Complete options if current word starts with -
	if [[ "$cur" == -* ]]; then
		COMPREPLY=($(compgen -W "$opts" -- "$cur"))
		return 0
	fi

	# If first argument and not an option, complete with PR numbers
	if [[ ${COMP_CWORD} -eq 1 ]]; then
		_ghcp_pr_numbers_complete
		return 0
	fi
}

_ghcp_pr_numbers_complete() {
	# Check if we're in a git repository
	if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		return 1
	fi
	# Check if gh CLI is available and authenticated
	if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
		return 1
	fi

	# Get PR numbers and titles
	local pr_data
	pr_data=$(gh pr list --json number,title --jq '.[] | "\(.number) # \(.title)"' 2>/dev/null | head -20)

	if [[ -n "$pr_data" ]]; then
		# Extract just the numbers for completion
		local pr_numbers
		pr_numbers=$(echo "$pr_data" | cut -d' ' -f1)
		COMPREPLY=($(compgen -W "$pr_numbers" -- "$cur"))

		# Show titles as descriptions if possible
		if [[ ${#COMPREPLY[@]} -gt 0 ]]; then
			# This creates a more informative display
			printf "\nAvailable PRs:\n" >&2
			echo "$pr_data" | while IFS= read -r line; do
				local num title
				num=$(echo "$line" | cut -d' ' -f1)
				title=$(echo "$line" | cut -d'#' -f2- | sed 's/^ *//')
				printf "  %-4s %s\n" "$num" "$title" >&2
			done
			printf "\n" >&2
		fi
	fi

}

# Register the completion function
complete -F _ghcp_complete ghcp

# Advanced completion with descriptions (requires bash 4.4+)
if [[ ${BASH_VERSINFO[0]} -gt 4 || (${BASH_VERSINFO[0]} -eq 4 && ${BASH_VERSINFO[1]} -ge 4) ]]; then
	_ghcp_complete_advanced() {
		local cur prev opts
		COMPREPLY=()
		cur="${COMP_WORDS[COMP_CWORD]}"
		prev="${COMP_WORDS[COMP_CWORD-1]}"

		case "$prev" in
			--recover)
				_ghcp_pr_numbers_complete
				return 0
				;;
		esac

		case "$cur" in
			-*)
				local opts=(
					"--help:Show help message"
					"--status:Show current cherry-pick status"
					"--recover:Recover from failed cherry-pick"
					"--dry-run:Show what would be done without executing"
					"--verbose:Enable verbose output"
					"-h:Show help message"
					"-n:Show what would be done without executing"
					"-v:Enable verbose output"
				)

				local option_names=()
				for opt in "${opts[@]}"; do
					option_names+=("${opt%%:*}")
				done

				COMPREPLY=($(compgen -W "${option_names[*]}" -- "$cur"))
				return 0
				;;
			*)
				if [[ ${COMP_CWORD} -eq 1 ]]; then
					_ghcp_pr_numbers_complete
					return 0
				fi
				;;
		esac
	}

	complete -F _ghcp_complete_advanced ghcp
fi
