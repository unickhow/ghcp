# ghcp - GitHub PR Cherry Pick

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Support](https://img.shields.io/badge/shell-bash%20%7C%20zsh%20%7C%20fish-blue)](https://github.com/unickhow/ghcp)
[![GitHub CLI](https://img.shields.io/badge/requires-GitHub%20CLI-green)](https://cli.github.com/)

A command-line tool that simplifies cherry-picking all commits from a GitHub Pull Request to your current branch.

## ✨ Features

- **One-command cherry-pick**: Cherry-pick entire PRs with a single command
- **Smart conflict handling**: Intelligent conflict detection and recovery options
- **Cross-shell compatibility**: Works with bash, zsh, fish, and more
- **Dry-run mode**: Preview changes before executing
- **Recovery mode**: Resume from failed cherry-picks
- **Safety checks**: Validates git state, PR status, and permissions
- **Progress tracking**: Shows detailed progress during operations
- **Multiple installation options**: Choose between standalone script or shell integration

## 🚀 Quick Start

```bash
# Install with auto-detection
curl -fsSL https://raw.githubusercontent.com/unickhow/ghcp/main/install.sh | bash

# Cherry-pick PR #33
ghcp 33
```

## 📋 Requirements

- **Git**: Version 2.0 or higher
- **GitHub CLI**: [Install instructions](https://cli.github.com/)
- **jq**: JSON processor ([Install instructions](https://stedolan.github.io/jq/download/))
- **Operating System**: macOS, Linux, or Windows (with WSL)
- **Shell**: bash, zsh, fish, or any POSIX-compatible shell

### GitHub CLI Setup

Ensure you're authenticated with GitHub CLI:

```bash
gh auth login
gh auth status  # Verify authentication
```

## 🛠 Installation

### Method 1: Quick Install (Recommended)

The installer automatically detects your shell and installs the appropriate version:

```bash
curl -fsSL https://raw.githubusercontent.com/unickhow/ghcp/main/install.sh | bash
```

### Method 2: Standalone Executable

Works with any shell, but without tab completion:

```bash
# Install to ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/unickhow/ghcp/main/bin/ghcp -o ~/.local/bin/ghcp
chmod +x ~/.local/bin/ghcp

# Ensure ~/.local/bin is in your PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc  # or ~/.zshrc
source ~/.bashrc  # or ~/.zshrc
```

### Method 3: Shell Function (with Tab Completion)

#### For Zsh users:

```bash
# Download and source the function
curl -fsSL https://raw.githubusercontent.com/unickhow/ghcp/main/shell-functions/ghcp.zsh >> ~/.zshrc
source ~/.zshrc
```

#### For Bash users:

```bash
# Download and source the function
curl -fsSL https://raw.githubusercontent.com/unickhow/ghcp/main/shell-functions/ghcp.bash >> ~/.bashrc
source ~/.bashrc
```

#### For Fish users:

```bash
# Download to fish functions directory
curl -fsSL https://raw.githubusercontent.com/unickhow/ghcp/main/shell-functions/ghcp.fish -o ~/.config/fish/functions/ghcp.fish
```

### Method 4: Package Managers

#### Homebrew (macOS/Linux):

```bash
brew tap unickhow/tap
brew install ghcp
```

#### Oh My Zsh Plugin:

```bash
git clone https://github.com/unickhow/ghcp ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/ghcp
```

Then add `ghcp` to your plugins in `~/.zshrc`:

```bash
plugins=(... ghcp)
```

## 📖 Usage

### Basic Usage

```bash
# Cherry-pick all commits from PR #33
ghcp 33

# Preview what would be done (recommended first step)
ghcp 33 --dry-run

# Verbose output for debugging
ghcp 33 --verbose
```

### Recovery and Status

```bash
# Check current cherry-pick status
ghcp --status

# Recover from a failed cherry-pick
ghcp --recover 33

# Get help
ghcp --help
```

### Tab Completion

If you installed the shell function version, you can use tab completion:

```bash
ghcp <Tab>  # Shows available PR numbers
```

## 🔄 Workflow Examples

### Standard Workflow

```bash
# 1. Switch to your target branch
git checkout feature-branch

# 2. Preview the cherry-pick
ghcp 33 --dry-run

# 3. Execute if everything looks good
ghcp 33
```

### Handling Conflicts

```bash
# If cherry-pick fails due to conflicts
ghcp 33

# Resolve conflicts manually, then:
git add .
git cherry-pick --continue

# Continue with remaining commits
ghcp --recover 33
```

### Advanced Usage

```bash
# Check PR status and commits before cherry-picking
gh pr view 33
ghcp 33 --dry-run

# Cherry-pick with verbose output
ghcp 33 --verbose

# Check what happened after completion
git log --oneline -10
```

## ⚠️ Limitations and Considerations

### Current Limitations

1. **Single Repository**: Only works within the same repository (cross-repo PRs not supported)
2. **Linear History**: Works best with linear commit history; complex merge commits may cause issues
3. **GitHub Only**: Requires GitHub repository (no GitLab/Bitbucket support)
4. **Internet Required**: Needs internet connection to fetch PR data

### Important Notes

- **Backup Recommended**: Always work on a separate branch or ensure your work is backed up
- **Clean Working Directory**: The tool checks for uncommitted changes and will warn you
- **PR State**: Works with open, closed, and merged PRs, but will warn about non-open PRs
- **Merge Commits**: Will detect and warn about merge commits which may not cherry-pick cleanly
- **Duplicate Detection**: Checks for commits that may already exist in your branch

## 🔧 Configuration

### Environment Variables

```bash
# Customize temp directory (optional)
export GHCP_TEMP_DIR="/custom/temp/path"

# Enable debug mode (optional)
export GHCP_DEBUG=1
```

### Git Configuration

For optimal experience, ensure your git is configured:

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

## 🚫 Uninstallation

### Remove Standalone Installation

```bash
rm -f ~/.local/bin/ghcp
rm -f ~/.ghcp_recovery  # Remove any recovery files
```

### Remove Shell Function Installation

Remove the ghcp lines from your shell configuration file:

```bash
# For zsh users
sed -i '/# ghcp/,+1d' ~/.zshrc

# For bash users  
sed -i '/# ghcp/,+1d' ~/.bashrc

# For fish users
rm -f ~/.config/fish/functions/ghcp.fish
```

### Use Uninstall Script

```bash
curl -fsSL https://raw.githubusercontent.com/unickhow/ghcp/main/uninstall.sh | bash
```

### Remove Oh My Zsh Plugin

```bash
rm -rf ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/ghcp
```

Remove `ghcp` from your plugins list in `~/.zshrc`.

## 🐛 Troubleshooting

### Common Issues

#### "GitHub CLI not authenticated"

```bash
gh auth login
gh auth status
```

#### "jq not found"

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# CentOS/RHEL
sudo yum install jq
```

#### "Not a git repository"

Ensure you're running the command from within a git repository:

```bash
cd /path/to/your/git/repo
ghcp 33
```

#### "Working directory has uncommitted changes"

Either commit your changes or stash them:

```bash
git add .
git commit -m "Save work in progress"
# or
git stash
```

#### Cherry-pick conflicts

Follow the git conflict resolution workflow:

```bash
# Edit conflicted files
git add .
git cherry-pick --continue
ghcp --recover 33  # Continue with remaining commits
```

### Getting Help

1. **Check status**: `ghcp --status`
2. **Verbose output**: `ghcp 33 --verbose`
3. **GitHub issues**: [Report bugs here](https://github.com/unickhow/ghcp/issues)
4. **Discussions**: [Ask questions here](https://github.com/unickhow/ghcp/discussions)

## 🧪 Testing

Run the test suite:

```bash
# Clone the repository
git clone https://github.com/unickhow/ghcp.git
cd ghcp

# Install test dependencies
npm install -g bats  # or brew install bats-core

# Run tests
make test
# or
bats test/
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup

```bash
git clone https://github.com/unickhow/ghcp.git
cd ghcp
make install-dev  # Install development dependencies
make test         # Run tests
```

### Submitting Changes

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes and add tests
4. Run the test suite: `make test`
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [GitHub CLI](https://cli.github.com/) - For excellent GitHub integration
- [jq](https://stedolan.github.io/jq/) - For JSON processing
- The open-source community for inspiration and feedback

## 📊 Project Status

- ✅ **Stable**: Core functionality is complete and tested
- 🔄 **Active Development**: Regular updates and improvements
- 🐛 **Bug Reports**: Please report issues on GitHub
- 💡 **Feature Requests**: Suggestions welcome via GitHub issues

---

**Star this repository if ghcp has been helpful to you!** ⭐

Made with ❤️ for the developer community.
