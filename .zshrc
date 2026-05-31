source ~/.bash_profile

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

# Persist history across shells
setopt APPEND_HISTORY          # Append to history file instead of overwriting
setopt INC_APPEND_HISTORY      # Add commands as they are typed, not at shell exit
setopt HIST_EXPIRE_DUPS_FIRST  # Expire duplicate entries first
setopt HIST_IGNORE_DUPS        # Don't record an entry if it's a duplicate
setopt HIST_IGNORE_SPACE       # Don't record entries starting with a space
setopt HIST_VERIFY             # Don't execute immediately upon history expansion
setopt SHARE_HISTORY           # Share history between all sessions

# Allow comments in shell
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

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(/Users/max/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions

# Pyenv setup
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"
export PATH="$HOME/.local/bin:$PATH"

# Pipenv setup
export PIPENV_VENV_IN_PROJECT=1

# Google Cloud SDK
export CLOUDSDK_PYTHON="$HOME/.pyenv/versions/3.13.7/bin/python3.13"
# Add gcloud to path.
if [ -f '/Users/max/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/max/google-cloud-sdk/path.zsh.inc'; fi
# Enable shell command completion for gcloud.
if [ -f '/Users/max/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/max/google-cloud-sdk/completion.zsh.inc'; fi
