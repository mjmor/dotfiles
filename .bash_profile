# set iterm to color mode
export CLICOLOR=1

# Set colors to match iTerm2 Terminal Colors
export TERM=xterm-256color

if [ -e ~/.bashrc ]; then
    . ~/.bashrc
fi

export PATH=/opt/homebrew/bin:$PATH

export PATH=$HOME/Library/Python/3.9/bin:$PATH

# Ruby path variables.
if command -v rbenv &> /dev/null && command -v brew &> /dev/null; then
	export PATH="$HOME/.rbenv/bin:$PATH"
	eval "$(rbenv init -)"
	export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"
	export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@3)"
fi

# Node version management.
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Funtoo keychain configuration on Ubuntu.
if command -v keychain &> /dev/null; then
	eval `keychain --eval --agents ssh cod_id_rsa id_ed25519`
fi
