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
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"
export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@3)"
