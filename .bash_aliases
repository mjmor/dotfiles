google() {
    search=""
    echo "Googling: $@"
    for term in $@; do
        search="$search%20$term"
    done
    open "https://www.google.com/search?q=$search"
}

youtube() {
    search=""
    echo "Youtube searching: $@"
    for term in $@; do
        search="$search%20$term"
    done
    open "https://www.youtube.com/results?search_query=$search"
}

backup() {
    echo "Performing backup to $1..."
    echo "Are you sure you'd like to continue? y/n"
    read yn
    while [ "$yn" != "y" ] && [ "$yn" != "n" ]; do
        echo "$yn is not a valid response. Please enter y/n"
        read yn
    done
    if [ "$yn" == "n" ]; then
        return 1
    fi
    rsync -aAX --info=progress2 --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found","/home/flounder/.cache/*"} / "$1"
}

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias l.='ls -d .* --color=auto'

# my own alias'
alias shutdown='sudo shutdown now'
alias ..='cd ..'
alias apt-get='sudo apt-get'
alias apt='sudo apt'
alias c='clear'
alias h='history'

alias update='sudo apt-get update && sudo apt-get upgrade'
alias df='df -H'

#networking alias'
alias fping='ping -c 100 -s.2'
alias iptables='sudo /sbin/iptables -L -n -v --line-numbers'
alias iptablesin='sudo /sbin/iptables -L INPUT -n -v --line-numbers'
alias iptablesout='sudo /sbin/iptables -L OUTPUT -n -v --line-numbers'
alias iptablesfw='sudo /sbin/iptables -L FORWARD -n -v --line-numbers'
alias firewall='iptables'

# navigation
alias cd..='cd ..'
alias copy='xclip -selection clipboard'

# git & development
alias st='git status'
alias format='yarn prettier -w $(git ls-files -m) $(git diff --staged --name-only)'

# vi to vim
alias vi="/usr/bin/vim"

# City of Detroit specific config
# TODO: separate into own aliases file and only source if on work computer.
alias uxds='cd ~/Projects/uxds/'
alias uxds-run='uxds && yarn storybook'
alias detroitmi='cd ~/Projects/detroitmi/'
