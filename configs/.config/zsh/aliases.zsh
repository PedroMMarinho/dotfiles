# Aliases

# Clear alias
alias c='clear'

# Better ls
alias ls='eza --icons=auto'

# Detailed listing
alias ll='eza -lh --icons=auto --git'

# Detailed listing including hidden files
alias la='eza -lah --icons=auto --git'

# Tree view
alias tree='eza --tree --icons=auto'

compdef eza=ls

if command -v bat >/dev/null 2>&1; then
  alias cat='bat'
elif command -v batcat >/dev/null 2>&1; then
  alias bat='batcat'
  alias cat='batcat'
fi

# Core Utilities
alias grep='rg --color=auto'
alias diff='diff --color=auto'
alias df='df -h'

# Navigation 
alias -- -='cd -'

# Git

alias gs='git status'
alias glog='PAGER="less -F -X" git log'
alias ga='git add -A'