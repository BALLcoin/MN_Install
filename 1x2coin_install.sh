#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE="1x2coin.conf"
1X2COIN_DAEMON="/usr/local/bin/1x2coind"
1X2COIN_CLI="/usr/local/bin/1x2coin-cli"
1X2COIN_REPO="https://github.com/1x2-coin/1x2coin.git"
1X2COIN_LATEST_RELEASE="https://github.com/1x2-coin/1x2coin/releases/download/v1.0.0/1x2coin-1.0.0-x86_64-linux-gnu.tar.gz"
DEFAULT_1X2COIN_PORT=9214
DEFAULT_1X2COIN_RPC_PORT=9213
DEFAULT_1X2COIN_USER="1x2coin"
NODE_IP=NotCheckedYet
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'


function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $@. Please investigate.${NC}"
  exit 1
fi
}


function checks() {
if [[ $(lsb_release -d) != *16.04* ]]; then
  echo -e "${RED}You are not running Ubuntu 16.04. Installation is cancelled.${NC}"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

if [ -n "$(pidof $LUNARIUM_DAEMON)" ] || [ -e "$LUNARIUM_DAEMON" ] ; then
  echo -e "${GREEN}\c"
  echo -e "Lunarium is already installed. Exiting..."
  echo -e "{NC}"
  exit 1
fi
}

function prepare_system() {

echo -e "Prepare the system to install Lunarium master node."
apt-get update >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1
apt install -y software-properties-common >/dev/null 2>&1
echo -e "${GREEN}Adding bitcoin PPA repository"
apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1
echo -e "Installing required packages, it may take some time to finish.${NC}"
apt-get update >/dev/null 2>&1
apt-get upgrade >/dev/null 2>&1
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" git make build-essential libtool automake autotools-dev autoconf pkg-config libssl-dev libevent-dev libdb4.8-dev libdb4.8++-dev libminiupnpc-dev libboost-all-dev ufw fail2ban pwgen curl>/dev/null 2>&1
NODE_IP=$(curl -s4 icanhazip.com)
clear
if [ "$?" -gt "0" ];
  then
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-get update"
    echo "apt-get -y upgrade"
    echo "apt -y install software-properties-common"
    echo "apt-add-repository -y ppa:bitcoin/bitcoin"
    echo "apt-get update"
    echo "apt install -y git make build-essential libtool automake autotools-dev autoconf pkg-config libssl-dev libevent-dev libdb4.8-dev libdb4.8++-dev libminiupnpc-dev libboost-all-dev"
    exit 1
fi
clear

}

function ask_yes_or_no() {
  read -p "$1 ([Y]es or [N]o | ENTER): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

function compile_lunarium() {
echo -e "Checking if swap space is needed."
PHYMEM=$(free -g|awk '/^Mem:/{print $2}')
SWAP=$(free -g|awk '/^Swap:/{print $2}')
if [ "$PHYMEM" -lt "4" ] && [ -n "$SWAP" ]
  then
    echo -e "${GREEN}Server is running with less than 4G of RAM without SWAP, creating 8G swap file.${NC}"
    SWAPFILE=/swapfile
    dd if=/dev/zero of=$SWAPFILE bs=1024 count=8388608
    chown root:root $SWAPFILE
    chmod 600 $SWAPFILE
    mkswap $SWAPFILE
    swapon $SWAPFILE
    echo "${SWAPFILE} none swap sw 0 0" >> /etc/fstab
else
  echo -e "${GREEN}Server running with at least 4G of RAM, no swap needed.${NC}"
fi
clear



  echo -e "Clone git repo and compile it. This may take some time."
  cd $TMP_FOLDER
  git clone $1X2COINREPO lunarium
  cd lunarium
  ./autogen.sh
  ./configure
  make
  strip src/1x2coind src/1x2coin-cli src/1x2cointx
  make install
  cd ~
  rm -rf $TMP_FOLDER
  clear
}

function copy_1x2coin_binaries(){
  wget $1X2COIN_LATEST_RELEASE >/dev/null
  tar -xzf `basename $1X2COIN_LATEST_RELEASE` --strip-components=2 >/dev/null
  cp 1x2coin-cli 1x2coind 1x2coin-tx 1x2coin-qt /usr/local/bin >/dev/null
  chmod 755 /usr/local/bin/1x2coin* >/dev/null
  clear
}

function install_1x2coin(){
  echo -e "Installing 1x2coin files."
  echo -e "${GREEN}You have the choice between source code compilation (slower and requries 4G of RAM or VPS that allows swap to be added), or to use precompiled binaries instead (faster).${NC}"
  if [[ "no" == $(ask_yes_or_no "Do you want to perform source code compilation?") || \
        "no" == $(ask_yes_or_no "Are you **really** sure you want compile the source code, it will take a while?") ]]
  then
    copy_1x2coin_binaries
    clear
  else
    compile_1x2coin
    clear
  fi
}

function enable_firewall() {
  echo -e "Installing fail2ban and setting up firewall to allow ingress on port ${GREEN}$1X2COIN_PORT${NC}"
  ufw allow $1X2COIN_PORT/tcp comment "1x2coin MN port" >/dev/null
  ufw allow ssh comment "SSH" >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
  systemctl enable fail2ban >/dev/null 2>&1
  systemctl start fail2ban >/dev/null 2>&1
}

function systemd_1x2coin() {
  cat << EOF > /etc/systemd/system/$1X2COIN_USER.service
[Unit]
Description=1x2coin service
After=network.target
[Service]
ExecStart=$1X2COIN_DAEMON -conf=$1X2COIN_FOLDER/$CONFIG_FILE -datadir=$1X2COIN_FOLDER
ExecStop=$1X2COIN_CLI -conf=$1X2COIN_FOLDER/$CONFIG_FILE -datadir=$1X2COIN_FOLDER stop
Restart=always
User=$1X2COIN_USER
Group=$1X2COIN_USER

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start $1X2COIN_USER.service
  systemctl enable $1X2COIN_USER.service

  if [[ -z "$(ps axo user:15,cmd:100 | egrep ^$1X2COIN_USER | grep $1X2COIN_DAEMON)" ]]; then
    echo -e "${RED}1x2coind is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo -e "${GREEN}systemctl start $1X2COIN_USER.service"
    echo -e "systemctl status $1X2COIN_USER.service"
    echo -e "less /var/log/syslog${NC}"
    exit 1
  fi
}

function ask_port() {
read -p "1X2COIN Port: " -i $DEFAULT_1X2COIN_PORT -e 1X2COIN_PORT
: ${1X2COIN_PORT:=$DEFAULT_1X2COIN_PORT}
}

function ask_user() {
  echo -e "${GREEN}The script will now setup 1x2coin user and configuration directory. Press ENTER to accept defaults values.${NC}"
  read -p "1x2coin user: " -i $DEFAULT_1X2COIN_USER -e 1X2COIN_USER
  : ${1X2COIN_USER:=$DEFAULT_LUNARIUM_USER}

  if [ -z "$(getent passwd $1X2COIN_USER)" ]; then
    USERPASS=$(pwgen -s 12 1)
    useradd -m $1X2COIN_USER
    echo "$1X2COIN_USER:$USERPASS" | chpasswd

    1X2COIN_HOME=$(sudo -H -u $LUNARIUM_USER bash -c 'echo $HOME')
    DEFAULT_LUNARIUM_FOLDER="$LUNARIUM_HOME/.lunarium"
    read -p "Configuration folder: " -i $DEFAULT_1X2COIN_FOLDER -e 1X2COIN_FOLDER
    : ${LUNARIUM_FOLDER:=$DEFAULT_1X2COIN_FOLDER}
    mkdir -p $1X2COIN_FOLDER
    chown -R $1X2COIN_USER: $1X2COIN_FOLDER >/dev/null
  else
    clear
    echo -e "${RED}User exits. Please enter another username: ${NC}"
    ask_user
  fi
}

function check_port() {
  declare -a PORTS
  PORTS=($(netstat -tnlp | awk '/LISTEN/ {print $4}' | awk -F":" '{print $NF}' | sort | uniq | tr '\r\n'  ' '))
  ask_port

  while [[ ${PORTS[@]} =~ $LUNARIUM_PORT ]] || [[ ${PORTS[@]} =~ $[LUNARIUM_PORT+1] ]]; do
    clear
    echo -e "${RED}Port in use, please choose another port:${NF}"
    ask_port
  done
}

function create_config() {
  RPCUSER=$(pwgen -s 8 1)
  RPCPASSWORD=$(pwgen -s 15 1)
  cat << EOF > $LUNARIUM_FOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
rpcport=$DEFAULT_LUNARIUM_RPC_PORT
listen=1
server=1
daemon=1
port=$LUNARIUM_PORT
addnode=212.237.21.165
addnode=212.237.8.42
addnode=80.211.30.202
addnode=80.211.83.188
addnode=80.211.74.34
addnode=212.237.24.82
EOF
}

function create_key() {
  echo -e "Enter your ${RED}Masternode Private Key${NC}. Leave it blank to generate a new ${RED}Masternode Private Key${NC} for you:"
  read -e LUNARIUM_KEY
  if [[ -z "$LUNARIUM_KEY" ]]; then
  su $LUNARIUM_USER -c "$LUNARIUM_DAEMON -conf=$LUNARIUM_FOLDER/$CONFIG_FILE -datadir=$LUNARIUM_FOLDER -daemon"
  sleep 15
  if [ -z "$(ps axo user:15,cmd:100 | egrep ^$LUNARIUM_USER | grep $LUNARIUM_DAEMON)" ]; then
   echo -e "${RED}Lunariumd server couldn't start. Check /var/log/syslog for errors.{$NC}"
   exit 1
  fi
  LUNARIUM_KEY=$(su $LUNARIUM_USER -c "$LUNARIUM_CLI -conf=$LUNARIUM_FOLDER/$CONFIG_FILE -datadir=$LUNARIUM_FOLDER masternode genkey")
  su $LUNARIUM_USER -c "$LUNARIUM_CLI -conf=$LUNARIUM_FOLDER/$CONFIG_FILE -datadir=$LUNARIUM_FOLDER stop"
fi
}

function update_config() {
  sed -i 's/daemon=1/daemon=0/' $LUNARIUM_FOLDER/$CONFIG_FILE
  cat << EOF >> $LUNARIUM_FOLDER/$CONFIG_FILE
maxconnections=256
masternode=1
masternodeaddr=$NODE_IP:$LUNARIUM_PORT
masternodeprivkey=$LUNARIUM_KEY
EOF
  chown -R $LUNARIUM_USER: $LUNARIUM_FOLDER >/dev/null
}

function important_information() {
 echo
 echo -e "================================================================================================================================"
 echo -e "Lunarium Masternode is up and running as user ${GREEN}$LUNARIUM_USER${NC} and it is listening on port ${GREEN}$LUNARIUM_PORT${NC}."
 echo -e "${GREEN}$LUNARIUM_USER${NC} password is ${RED}$USERPASS${NC}"
 echo -e "Configuration file is: ${RED}$LUNARIUM_FOLDER/$CONFIG_FILE${NC}"
 echo -e "Start: ${RED}systemctl start $LUNARIUM_USER.service${NC}"
 echo -e "Stop: ${RED}systemctl stop $LUNARIUM_USER.service${NC}"
 echo -e "VPS_IP:PORT ${RED}$NODE_IP:$LUNARIUM_PORT${NC}"
 echo -e "MASTERNODE PRIVATEKEY is: ${RED}$LUNARIUM_KEY${NC}"
 echo -e "Please check Lunarium is running with the following command: ${GREEN}systemctl status $LUNARIUM_USER.service${NC}"
 echo -e "================================================================================================================================"
}

function setup_node() {
  ask_user
  check_port
  create_config
  create_key
  update_config
  enable_firewall
  systemd_lunarium
  important_information
}


##### Main #####
clear
checks
prepare_system
install_lunarium
setup_node
