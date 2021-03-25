#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE="ballcoin.conf"
ballcoin_DAEMON="/usr/local/bin/ballcoind"
ballcoin_CLI="/usr/local/bin/ballcoin-cli"
ballcoin_REPO="https://github.com/BALLcoin/BALLcoin.git"
ballcoin_LATEST_RELEASE="https://github.com/BALLcoin/BALLcoin/releases/download/1.1.3/ubuntu18.4.zip"
DEFAULT_ballcoin_PORT=51884
DEFAULT_ballcoin_RPC_PORT=51883
DEFAULT_ballcoin_USER="ballcoin"
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
if [[ $(lsb_release -d) != *18.04* ]]; then
  echo -e "${RED}You are not running Ubuntu 18.04. Installation is cancelled.${NC}"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

if [ -n "$(pidof $ballcoin_DAEMON)" ] || [ -e "$ballcoin_DAEMON" ] ; then
  echo -e "${GREEN}\c"
  echo -e "ballcoin is already installed. Exiting..."
  echo -e "{NC}"
  exit 1
fi
}

function prepare_system() {

echo -e "Prepare the system to install ballcoin master node."
apt-get update >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1
apt install -y software-properties-common >/dev/null 2>&1
echo -e "${GREEN}Adding bitcoin PPA repository"
apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1
echo -e "Installing required packages, it may take some time to finish.${NC}"
apt-get update >/dev/null 2>&1
apt-get upgrade >/dev/null 2>&1
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" net-tools unzip git make build-essential libtool automake autotools-dev autoconf pkg-config libssl-dev libevent-dev libdb4.8-dev libdb4.8++-dev libminiupnpc-dev libboost-all-dev ufw fail2ban pwgen curl>/dev/null 2>&1
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
    echo "apt install -y net-tools unzip  git make build-essential libtool automake autotools-dev autoconf pkg-config libssl-dev libevent-dev libdb4.8-dev libdb4.8++-dev libminiupnpc-dev libboost-all-dev"
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

function compile_ballcoin() {
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
  git clone $ballcoinREPO ballcoin
  cd ballcoin
  ./autogen.sh
  ./configure
  make
  strip src/ballcoind src/ballcoin-cli src/ballcointx
  make install
  cd ~
  rm -rf $TMP_FOLDER
  clear
}

function copy_ballcoin_binaries(){
  wget $ballcoin_LATEST_RELEASE >/dev/null
  unzip `basename $ballcoin_LATEST_RELEASE`   >/dev/null
  cp ballcoin-cli ballcoind ballcoin-tx ballcoin-qt /usr/local/bin >/dev/null
  chmod 755 /usr/local/bin/ballcoin* >/dev/null
  clear
}

function install_ballcoin(){
  echo -e "Installing ballcoin files."
  echo -e "${GREEN}You have the choice between source code compilation (slower and requries 4G of RAM or VPS that allows swap to be added), or to use precompiled binaries instead (faster).${NC}"
  if [[ "no" == $(ask_yes_or_no "Do you want to perform source code compilation?") || \
        "no" == $(ask_yes_or_no "Are you **really** sure you want compile the source code, it will take a while?") ]]
  then
    copy_ballcoin_binaries
    clear
  else
    compile_ballcoin
    clear
  fi
}

function enable_firewall() {
  echo -e "Installing fail2ban and setting up firewall to allow ingress on port ${GREEN}$ballcoin_PORT${NC}"
  ufw allow $ballcoin_PORT/tcp comment "ballcoin MN port" >/dev/null
  ufw allow ssh comment "SSH" >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
  systemctl enable fail2ban >/dev/null 2>&1
  systemctl start fail2ban >/dev/null 2>&1
}

function systemd_ballcoin() {
  cat << EOF > /etc/systemd/system/$ballcoin_USER.service
[Unit]
Description=ballcoin service
After=network.target
[Service]
ExecStart=$ballcoin_DAEMON -conf=$ballcoin_FOLDER/$CONFIG_FILE -datadir=$ballcoin_FOLDER
ExecStop=$ballcoin_CLI -conf=$ballcoin_FOLDER/$CONFIG_FILE -datadir=$ballcoin_FOLDER stop
Restart=always
User=$ballcoin_USER
Group=$ballcoin_USER

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start $ballcoin_USER.service
  systemctl enable $ballcoin_USER.service

  if [[ -z "$(ps axo user:15,cmd:100 | egrep ^$ballcoin_USER | grep $ballcoin_DAEMON)" ]]; then
    echo -e "${RED}ballcoind is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo -e "${GREEN}systemctl start $ballcoin_USER.service"
    echo -e "systemctl status $ballcoin_USER.service"
    echo -e "less /var/log/syslog${NC}"
    exit 1
  fi
}

function ask_port() {
read -p "ballcoin Port: " -i $DEFAULT_ballcoin_PORT -e ballcoin_PORT
: ${ballcoin_PORT:=$DEFAULT_ballcoin_PORT}
}

function ask_user() {
  echo -e "${GREEN}The script will now setup ballcoin user and configuration directory. Press ENTER to accept defaults values.${NC}"
  read -p "ballcoin user: " -i $DEFAULT_ballcoin_USER -e ballcoin_USER
  : ${ballcoin_USER:=$DEFAULT_ballcoin_USER}

  if [ -z "$(getent passwd $ballcoin_USER)" ]; then
    USERPASS=$(pwgen -s 12 1)
    useradd -m $ballcoin_USER
    echo "$ballcoin_USER:$USERPASS" | chpasswd

    ballcoin_HOME=$(sudo -H -u $ballcoin_USER bash -c 'echo $HOME')
    DEFAULT_ballcoin_FOLDER="$ballcoin_HOME/.ballcoin"
    read -p "Configuration folder: " -i $DEFAULT_ballcoin_FOLDER -e ballcoin_FOLDER
    : ${ballcoin_FOLDER:=$DEFAULT_ballcoin_FOLDER}
    mkdir -p $ballcoin_FOLDER
    chown -R $ballcoin_USER: $ballcoin_FOLDER >/dev/null
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

  while [[ ${PORTS[@]} =~ $ballcoin_PORT ]] || [[ ${PORTS[@]} =~ $[ballcoin_PORT+1] ]]; do
    clear
    echo -e "${RED}Port in use, please choose another port:${NF}"
    ask_port
  done
}

function create_config() {
  RPCUSER=$(pwgen -s 8 1)
  RPCPASSWORD=$(pwgen -s 15 1)
  cat << EOF > $ballcoin_FOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
rpcport=$DEFAULT_ballcoin_RPC_PORT
listen=1
server=1
daemon=1
port=$ballcoin_PORT
EOF
}

function create_key() {
  echo -e "Enter your ${RED}Masternode Private Key${NC}. Leave it blank to generate a new ${RED}Masternode Private Key${NC} for you:"
  read -e ballcoin_KEY
  if [[ -z "$ballcoin_KEY" ]]; then
  su $ballcoin_USER -c "$ballcoin_DAEMON -conf=$ballcoin_FOLDER/$CONFIG_FILE -datadir=$ballcoin_FOLDER -daemon"
  sleep 15
  if [ -z "$(ps axo user:15,cmd:100 | egrep ^$ballcoin_USER | grep $ballcoin_DAEMON)" ]; then
   echo -e "${RED}ballcoind server couldn't start. Check /var/log/syslog for errors.{$NC}"
   exit 1
  fi
  ballcoin_KEY=$(su $ballcoin_USER -c "$ballcoin_CLI -conf=$ballcoin_FOLDER/$CONFIG_FILE -datadir=$ballcoin_FOLDER masternode genkey")
  su $ballcoin_USER -c "$ballcoin_CLI -conf=$ballcoin_FOLDER/$CONFIG_FILE -datadir=$ballcoin_FOLDER stop"
fi
}

function update_config() {
  sed -i 's/daemon=1/daemon=0/' $ballcoin_FOLDER/$CONFIG_FILE
  cat << EOF >> $ballcoin_FOLDER/$CONFIG_FILE
maxconnections=256
masternode=1
masternodeaddr=$NODE_IP:$ballcoin_PORT
masternodeprivkey=$ballcoin_KEY
EOF
  chown -R $ballcoin_USER: $ballcoin_FOLDER >/dev/null
}

function important_information() {
 echo
 echo -e "================================================================================================================================"
 echo -e "ballcoin Masternode is up and running as user ${GREEN}$ballcoin_USER${NC} and it is listening on port ${GREEN}$ballcoin_PORT${NC}."
 echo -e "${GREEN}$ballcoin_USER${NC} password is ${RED}$USERPASS${NC}"
 echo -e "Configuration file is: ${RED}$ballcoin_FOLDER/$CONFIG_FILE${NC}"
 echo -e "Start: ${RED}systemctl start $ballcoin_USER.service${NC}"
 echo -e "Stop: ${RED}systemctl stop $ballcoin_USER.service${NC}"
 echo -e "VPS_IP:PORT ${RED}$NODE_IP:$ballcoin_PORT${NC}"
 echo -e "MASTERNODE PRIVATEKEY is: ${RED}$ballcoin_KEY${NC}"
 echo -e "Please check ballcoin is running with the following command: ${GREEN}systemctl status $ballcoin_USER.service${NC}"
 echo -e "================================================================================================================================"
}

function setup_node() {
  ask_user
  check_port
  create_config
  create_key
  update_config
  enable_firewall
  systemd_ballcoin
  important_information
}


##### Main #####
clear
checks
prepare_system
install_ballcoin
setup_node
