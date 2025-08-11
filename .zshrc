source ~/.bash_profile

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

# Add these to your ~/.zshrc
setopt APPEND_HISTORY          # Append to history file instead of overwriting
setopt INC_APPEND_HISTORY      # Add commands as they are typed, not at shell exit
setopt HIST_EXPIRE_DUPS_FIRST  # Expire duplicate entries first
setopt HIST_IGNORE_DUPS        # Don't record an entry if it's a duplicate
setopt HIST_IGNORE_SPACE       # Don't record entries starting with a space
setopt HIST_VERIFY             # Don't execute immediately upon history expansion
setopt SHARE_HISTORY           # Share history between all sessions

setopt interactivecomments

# Lando
export PATH="$HOME/.lando/bin${PATH+:$PATH}"; #landopath

# Yarn scripts
export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"

# Go
export GOPATH=$HOME/go       # Your workspace directory
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
