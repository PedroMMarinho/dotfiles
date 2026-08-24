# History

if [[ ! -d "${XDG_STATE_HOME:-$HOME/.local/state}/zsh" ]]; then
  mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/zsh"
fi

HISTFILE="$XDG_STATE_HOME/zsh/history"
HISTSIZE=100000
SAVEHIST=100000

setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS

# Shell behaviour

setopt AUTOCD
setopt NOBEEP
setopt NUMERIC_GLOB_SORT

# Smart directory navigation

eval "$(zoxide init --cmd cd zsh)"

# Completion

autoload -Uz compinit

compinit -d "$XDG_CACHE_HOME/zsh/completion_dump"
# Enable interactive completion
zstyle ':completion:*' menu select


zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# Fuzzy finder
# Arch 
if [[ -f /usr/share/fzf/key-bindings.zsh ]]; then
  source /usr/share/fzf/key-bindings.zsh
  source /usr/share/fzf/completion.zsh
fi

# Modular Config Files

# fzf Configuration
source "$ZDOTFILES/fzf.zsh"

# Aliases
source "$ZDOTFILES/aliases.zsh"

# Bindings
source "$ZDOTFILES/bindings.zsh"

# Plugins 
source "$ZDOTFILES/plugins.zsh"

# Syntax highlighting tweaks
source "$ZDOTFILES/highlighting.zsh"

# Prompt theme
source "$ZDOTFILES/prompt.zsh"

export PATH="$HOME/.local/bin:$PATH"
