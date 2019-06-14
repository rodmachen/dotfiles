# ----- Birdhouse Bootstrapper

# Should come first in your /Users/rmachen/.zshrc so it can be overridden.
# if test -L ~/.birdhouse/birdhouse_loader; then
#     source ~/.birdhouse/birdhouse_loader "/Users/rmachen/local-code/homeaway/birdhouse/lib" "/Users/rmachen/.zshrc"
# fi

# ----- Birdhouse Bootstrapper

# Path to your oh-my-zsh installation.
export ZSH=/Users/rmachen/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
# ZSH_THEME="risto"
# risto theme with blue and green swapped
ZSH_THEME="rodsto"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git node npm osx atom z)

# User configuration

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/share/npm/bin"
# export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
# export MANPATH="/usr/local/man:$MANPATH"
#PATH=$PATH:/usr/local/bin/; export PATH
eval "$(rbenv init -)"

source $ZSH/oh-my-zsh.sh

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
# export EDITOR='vim'
# else
# export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/dsa_id"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.

# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias zs="source ~/.zshrc"
alias sz="code ~/.zshrc"
alias rdm="cd /Users/rmachen/Dropbox/code/projects/rodmachen.com"
alias cdm="cd /Users/rmachen/Dropbox/code/projects/rodmachen.com/code.rodmachen.com"
alias pdm="cd /Users/rmachen/Dropbox/code/projects/rodmachen.com/photo.rodmachen.com"
alias rd="cd /Users/rmachen/Dropbox/code/projects/rodneydean.org"
alias sp="s3_website push"
# alias s.="subl . --command toggle_full_screen"
alias a.="atom ."
alias c.="code ."
# alias ga="git add ."
# alias gc="git commit -m"
# alias gac="git commit -am"
# alias gp="git push"
alias gs="git status"
alias glp="git log --pretty=format:'%h %ad | %s%d [%an]' --graph --date=short"
alias gmm="git merge master"
alias gcm="git commit -m"
alias gcom="git checkout master"
alias type="git cat-file -t"
alias dump="git cat-file -p"
alias gpum="git pull upstream master"
alias gpus="git pull --rebase upstream staging"
alias gpos="git push origin staging"
alias gps="git push --set-upstream origin"
alias grs="git rebase staging"
alias gprm="git pull --rebase upstream master"
alias gpom="git push origin master"
# alias vim="/Applications/MacVim.app/Contents/MacOS/Vim"
alias vg="valgrind --tool=memcheck --leak-check=yes --show-reachable=yes --num-callers=20 --track-fds=yes"
alias gn="geeknote show \"*\""
alias gfi="git-fixit"
alias nrg="npm run generate"
alias nrst="npm run start:dev"
alias nrsp="npm run stop:dev"
alias grom="git rebase origin/master"
alias rake='noglob rake'
alias mci="mvn clean install -DskipTests"
alias mcit="mvn clean install"
alias mct="mvn clean test"
alias audio="sudo kextunload /System/Library/Extensions/AppleHDA.kext;sudo kextload /System/Library/Extensions/AppleHDA.kext"
alias mcis='mci && ./start.sh'
alias mcic='mvn test jacoco:report'

stty -ixon

export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting
export NPM_TOKEN=ed58743d-77c1-4438-b4b4-f1c73ec3d947
# cd ~/local-code/homeaway

function code {
    if [[ $# = 0 ]]
    then
        open -a "Visual Studio Code"
    else
        local argPath="$1"
        [[ $1 = /* ]] && argPath="$1" || argPath="$PWD/${1#./}"
        open -a "Visual Studio Code" "$argPath"
    fi
}
# echo source $HOME/.bash_profile_bootstrap
