# Lunarium Coin
Shell script to install an [Lunarium Masternode](http://lunariumcoin.io/) on a Linux server running Ubuntu 16.04.

***
## Installation:  

* wget -q https://raw.githubusercontent.com/LunariumCoin/Lunarium-MN-Install/master/lunarium_install.sh
* bash lunarium_install.sh

***

## Desktop wallet setup  

After the MN is up and running, you need to configure the desktop wallet accordingly. Here are the steps:  
1. Open the Lunarium Wallet.  
2. Go to RECEIVE and create a New Address: **MN1**  
3. Send **10000** XLN to **MN1**.  
4. Wait for 6 confirmations.
5. Go to **Tools -> "Debug console"**  
6. Type the following command: **masternode outputs**. Copy the values of **txhash** and **outputidx**.  
7. Go to **Tools -> Open Masternode Configuration File**, add a new line with the format: ***alias IP:port genkey collateral_output_txid collateral_output_index***
* Alias = **MN1**  
* IP:port = **VPS_IP:44071**  
* Privkey: **Masternode Genkey provided by the script in the installation step above**  
* collateral_output_txid: **First value from Step 6**  
* Output index:  **Second value from Step 6**  
8. Click **File -> Save** to add the masternode
9. Close the masternode.conf file.
9. Restart Lunarium Wallet
10. Go to **Masternodes** tab
* Right click on **MN1** in the list
* Click **Start Alias** in the popup menu
11. Status should switch to **ENABLED**
12. Done! Your should receive your first rewards in the next 24 hours or less.

***

## Usage:  

For security reasons **Lunarium** is installed under **lunarium** user, hence you need to **su lunarium** before checking:    

```
If not installed using default username lunarium, please replace lunarium with your actual username.   

su lunarium  
lunarium-cli masternode status  
lunarium-cli getinfo  
exit # back to root user  
```  

Also, if you want to check/start/stop **Lunarium**, run one of the following commands as **root**:

```
systemctl status lunarium #To check the service is running.  
systemctl start lunarium.service #To start Lunarium service.  
systemctl stop lunarium.service #To stop Lunarium service.  
systemctl is-enabled lunarium #To check whetether Lunarium service is enabled on boot or not.  
```  

***

## Credits:

Based on a script by Zoldur (https://github.com/zoldur). Thanks!
