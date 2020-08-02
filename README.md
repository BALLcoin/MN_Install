# 1x2 Coin
Shell script to install an [1x2coin Masternode](http://www.1x2-coin.net/) on a Linux server running Ubuntu 18.04.

***
## Installation:  

* wget -q https://raw.githubusercontent.com/1x2-coin/MN_Install/master/1x2coin_install.sh
* bash 1x2coin_install.sh.sh

***

## Desktop wallet setup  

After the MN is up and running, you need to configure the desktop wallet accordingly. Here are the steps:  
1. Open the 1x2coin Wallet.  
2. Go to RECEIVE and create a New Address: **MN1**  
3. Send **1000** 1X2 to **MN1**.  
4. Wait for 6 confirmations.
5. Go to **Tools -> "Debug console"**  
6. Type the following command: **masternode outputs**. Copy the values of **txhash** and **outputidx**.  
7. Go to **Tools -> Open Masternode Configuration File**, add a new line with the format: ***alias IP:port genkey collateral_output_txid collateral_output_index***
* Alias = **MN1**  
* IP:port = **VPS_IP:9214**  
* Privkey: **Masternode Genkey provided by the script in the installation step above**  
* collateral_output_txid: **First value from Step 6**  
* Output index:  **Second value from Step 6**  
8. Click **File -> Save** to add the masternode
9. Close the masternode.conf file.
9. Restart 1x2coin Wallet
10. Go to **Masternodes** tab
* Right click on **MN1** in the list
* Click **Start Alias** in the popup menu
11. Status should switch to **ENABLED**
12. Done! Your should receive your first rewards in the next 24 hours or less.

***

## Usage:  

For security reasons **1x2coin** is installed under **1x2coin** user, hence you need to **su 1x2coin** before checking:    

```
If not installed using default username 1x2coin, please replace 1x2coin with your actual username.   

su 1x2coin  
1x2coin-cli masternode status  
1x2coin-cli getinfo  
exit # back to root user  
```  

Also, if you want to check/start/stop **1x2coin**, run one of the following commands as **root**:

```
systemctl status 1x2coin #To check the service is running.  
systemctl start 1x2coin.service #To start 1X2COIN service.  
systemctl stop 1x2coin.service #To stop 1X2COIN service.  
systemctl is-enabled 1x2coin #To check whetether 1x2coin service is enabled on boot or not.  
```  

***

## Credits:

Based on a script by Zoldur (https://github.com/zoldur). Thanks!
