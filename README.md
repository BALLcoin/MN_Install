# BALLCoin
Shell script to install an [BALLcoin Masternode](http://www.ball-coin.com/) on a Linux server running Ubuntu 18.04.

***
## Installation:  

* wget -q https://raw.githubusercontent.com/BALLcoin/MN_Install/master/ballcoin_install.sh
* bash ballcoin_install.sh

***
## MN Host Providers: 

Tested and working on

[Lineode](https://www.linode.com/?r=f37c31cc9eb2233aafdf4c9b7e36c91b6315f5ee) 
[Test File](https://raw.githubusercontent.com/BALLcoin/MN_Install/master/Tests/linnode-debug.zip) 

[DigitalOcean](https://m.do.co/c/f414b0f1870e)
[Test File](https://raw.githubusercontent.com/BALLcoin/MN_Install/master/Tests/digitalocean-debug.zip) 


## Desktop wallet setup  

After the MN is up and running, you need to configure the desktop wallet accordingly. Here are the steps:  
1. Open the BALLcoin Wallet.  
2. Go to RECEIVE and create a New Address: **MN1**  
3. Send **5000** BALL to **MN1**.  
4. Wait for 6 confirmations.
5. Go to **Tools -> "Debug console"**  
6. Type the following command: **masternode outputs**. Copy the values of **txhash** and **outputidx**.  
7. Go to **Tools -> Open Masternode Configuration File**, add a new line with the format: ***alias IP:port genkey collateral_output_txid collateral_output_index***
* Alias = **MN1**  
* IP:port = **VPS_IP:51884**  
* Privkey: **Masternode Genkey provided by the script in the installation step above**  
* collateral_output_txid: **First value from Step 6**  
* Output index:  **Second value from Step 6**  
8. Click **File -> Save** to add the masternode
9. Close the masternode.conf file.
9. Restart BALLcoin Wallet
10. Go to **Masternodes** tab
* Right click on **MN1** in the list
* Click **Start Alias** in the popup menu
11. Status should switch to **ENABLED**
12. Done! Your should receive your first rewards in the next 24 hours or less.

***

## Usage:  

For security reasons **BALLcoin** is installed under **BALLcoin** user, hence you need to **su ballcoin** before checking:    

```
If not installed using default username BALLcoin, please replace BALLcoin with your actual username.   

su ballcoin  
ballcoin-cli masternode status  
ballcoin-cli getinfo  
exit # back to root user  
```  

Also, if you want to check/start/stop **BALLcoin**, run one of the following commands as **root**:

```
systemctl status ballcoin #To check the service is running.  
systemctl start ballcoin.service #To start BALLCOIN service.  
systemctl stop ballcoin.service #To stop BALLCOIN service.  
systemctl is-enabled ballcoin #To check whetether BALLcoin service is enabled on boot or not.  
```  

***

## Credits:

Based on a script by Zoldur (https://github.com/zoldur). Thanks!
