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

# Set python to homebrew install
export python3="/opt/homebrew/opt/python@3.12"

# Go
export GOPATH=$HOME/go       # Your workspace directory
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"
if [ -f "/Users/max/Projects/skyfall/skyfall" ]; then export PATH="$PATH:/Users/max/Projects/skyfall"; fi
