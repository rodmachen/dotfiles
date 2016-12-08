# Path to your oh-my-zsh installation.
export ZSH=/Users/rodmachen/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="risto"

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
plugins=(bower git heroku node npm osx atom z)

# User configuration

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
# export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
# export MANPATH="/usr/local/man:$MANPATH"
#PATH=$PATH:/usr/local/bin/; export PATH

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
alias sz="atom ~/.zshrc"
alias rdm="cd /Users/rodmachen/Dropbox/code/projects/rodmachen.com"
alias cdm="cd /Users/rodmachen/Dropbox/code/projects/rodmachen.com/code.rodmachen.com"
alias pdm="cd /Users/rodmachen/Dropbox/code/projects/rodmachen.com/photo.rodmachen.com"
alias rd="cd /Users/rodmachen/Dropbox/code/projects/rodneydean.org"
alias sp="s3_website push"
# alias s.="subl . --command toggle_full_screen"
alias a.="atom ."
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
alias grs="git rebase staging"
alias gprm="git pull --rebase upstream master"
alias gpom="git push origin master"
alias vim="/Applications/MacVim.app/Contents/MacOS/Vim"
alias vg="valgrind --tool=memcheck --leak-check=yes --show-reachable=yes --num-callers=20 --track-fds=yes"
alias gn="geeknote show \"*\""
alias gfi="git-fixit"
alias nrg="npm run generate"
alias nrst="npm run start:dev"
alias nrsp="npm run stop:dev"
alias grom="git rebase origin/master"

stty -ixon

export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting
export NPM_TOKEN=ed58743d-77c1-4438-b4b4-f1c73ec3d947
export JIRA_PW=zqLUYV8
export JIRA_USERNAME=chat_stats
export LOG_LEVEL=DEBUG
export DB_NAME=integrations
export DB_USER=help
export DB_PASSWORD="nQaH?fE)(f4YyK/mHQ,77f%77"
export DB_HOST=127.0.0.1
export GOPATH=$HOME/golang
export PATH=$PATH:$GOPATH/bin
export CE_ORG_SECRET="b86a3995ce412c955d2a4524dc89080b"
export CE_USER_SECRET="IxgwtigG6Vm/3DMsQShzHgCTpI41Q934bH7R4rFMveo="
export SHOPIFY_API_KEY="db2b5217f7ed5da85ba876932cdf7e2a"
export SHOPIFY_API_SECRET="da9a96bac21de804599430c594de4b60"
export DB="http://org-member-state-db"
export DB_PASS="password"
cd ~/Dropbox/code/

# The next line updates PATH for the Google Cloud SDK.
source '/Users/rodmachen/google-cloud-sdk/path.zsh.inc'

# The next line enables shell command completion for gcloud.
source '/Users/rodmachen/google-cloud-sdk/completion.zsh.inc'
