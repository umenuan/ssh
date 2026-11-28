cat > ~/.bashrc <<'EOF'
alias 0='bash <(wget -qO- https://raw.githubusercontent.com/umenuan/ssh/main/0.sh)'
alias 1='bash <(wget -qO- https://raw.githubusercontent.com/umenuan/ssh/main/1.sh)'
alias 2='bash <(wget -qO- https://raw.githubusercontent.com/umenuan/ssh/main/2.sh)'
alias 3='bash <(wget -qO- https://raw.githubusercontent.com/umenuan/ssh/main/3.sh)'
alias 4='bash <(wget -qO- https://raw.githubusercontent.com/umenuan/ssh/main/4.sh)'
alias 5='bash <(wget -qO- https://raw.githubusercontent.com/umenuan/ssh/main/5.sh)'
alias 6='bash <(wget -qO- https://raw.githubusercontent.com/umenuan/ssh/main/6.sh)'
alias 7='bash <(wget -qO- https://raw.githubusercontent.com/umenuan/ssh/main/7.sh)'
alias 8='bash <(wget -qO- https://raw.githubusercontent.com/umenuan/ssh/main/8.sh)'
alias 9='bash <(wget -qO- https://raw.githubusercontent.com/umenuan/ssh/main/9.sh)'

alias nq='bash <(curl -sL https://run.NodeQuality.com)'

alias dk='curl -fsSL https://get.docker.com | sudo sh'

alias wp='wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh'

alias 3x='bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)'

alias 1p='bash -c "$(curl -sSL https://resource.fit2cloud.com/1panel/package/v2/quick_start.sh)"'

alias sp='curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash && sudo apt install speedtest -y'

alias re='bash <(curl -Ls https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh) debian --ssh-key "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOmhMiWBMLsvwLJY2X6qkCm+Lm/tEOu4SCH+/ujMw9oO"'
alias rs='bash <(curl -Ls https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh) reset'

alias ai='apt install -y'
alias ap='apt purge -y'
alias jc='journalctl'
alias sc='systemctl'

alias n='nload -m -t 1000 -u M eth0'

alias s='speedtest'
alias r='reboot'
alias c='clear'

EOF

source ~/.bashrc
