# Live Scenario Documentation


## Context

### Goals

Organize and conduct a series of drills to help protocol teams prepare for attacks and dependency failures in order to test both **social** and **technical** resiliency, harden internal procedures for deployment & recovery, and develop a training program for team members.

After going through these drills the team will be able to understand:

- What are the key dependencies of the protocol and what happens if they fail?
- Is there sufficient monitoring infra to detect & respond to failures?
- Is there an understanding of who has access to admin keys and how & when they are accessed to respond to threats?
- Do essential team members have backup people in place who can respond if they are unavailable?
- Does the team know who to contact in other protocols if a failure is detected?

### Stakeholders

All team members are welcome in the exercise with duties related to:

- Notification & reporting infrastructure for application state & dependencies
- Smart contract developers
- FE development & interface hosting
- Communications

### Vision

Throughout these exercises we will develop a suite of open source tools that teams will be able to use for future exercises and training new team members.

### Scenario

We simulate a failure within the Compound protocol on a fork of Ethereum Mainnet. We will gather protocol devs and partners in a simulated war room to diagnose the problem, develop and action plan, and implement the recovery procedure. The failure mode is not be communicated in advance and the team will have to use the forked network to figure out the problem and respond.

## Architecture

![Compound Exercise(3).png](assets/Compound_Exercise(3).png)

[Configuration Notes](https://www.notion.so/Configuration-Notes-8b710b4130224b998c5628136709ea17?pvs=21)

[Response](https://www.notion.so/Response-ceb9694b1c4e4f07be50f5cc1fe10668?pvs=21)

Public Repo: 

[GitHub - ipatka/w3sa-public](https://github.com/ipatka/w3sa-public)

## 🧪 Network Fork

The network fork runs in docker on a Digital Ocean droplet. The docker compose file here sets up a local anvil node and explorer.

![Screen Shot 2023-07-04 at 9.57.19 PM.png](assets/Screen_Shot_2023-07-04_at_9.57.19_PM.png)

[https://github.com/ipatka/blockscout/blob/anvil/docker-compose/docker-compose-anvil.yml](https://github.com/ipatka/blockscout/blob/anvil/docker-compose/docker-compose-anvil.yml)

The network fork also runs an nginx proxy to forward requests on the *****/rpc/***** route to the local anvil node

Block explorer: [https://securityalliance.dev/](https://securityalliance.dev/)

RPC (include trailing slash, idk why): [https://securityalliance.dev/rpc/](https://securityalliance.dev/rpc/) 

![Screen Shot 2023-07-13 at 8.42.03 AM.png](assets/Screen_Shot_2023-07-13_at_8.42.03_AM.png)

### ⛑ Health Scripts

`restartFoundry.sh`

Checks if anvil node & blockscout api are alive. If not, restarts the docker container

[https://github.com/ipatka/blockscout/blob/anvil/scripts/restartFoundry.sh](https://github.com/ipatka/blockscout/blob/anvil/scripts/restartFoundry.sh)

Runs on a [cron](https://www.notion.so/Configuration-Notes-8b710b4130224b998c5628136709ea17?pvs=21) job every 5 minutes

Anvil sometimes freezes and has to be restarted. Perhaps need pruning

`syncBlockTime.sh`

Compares fork time to mainnet time and sets fork time to mainnet time. Useful when fork falls behind mainnet to keep block explorer times up to date

Runs on a [cron](https://www.notion.so/Configuration-Notes-8b710b4130224b998c5628136709ea17?pvs=21) job every 5 minutes

[https://github.com/ipatka/sec-alliance-sims/blob/main/script/sh/syncBlockTime.sh](https://github.com/ipatka/sec-alliance-sims/blob/main/script/sh/syncBlockTime.sh)

### 📓 Scripts

`Verify Contracts`

Fetch deployment blocks & source code for contracts you want to verify:

[https://github.com/ipatka/sec-alliance-sims/blob/main/script/ts/fetchDeploymentBlocks.ts](https://github.com/ipatka/sec-alliance-sims/blob/main/script/ts/fetchDeploymentBlocks.ts)

Submit them to blockscout:

[https://github.com/ipatka/sec-alliance-sims/blob/main/script/ts/verifyBlockscout.ts](https://github.com/ipatka/sec-alliance-sims/blob/main/script/ts/verifyBlockscout.ts)

****NOTE**** Deployment blocks of mainnet contracts you want to verify must be indexed by blockscout. See notes

### 📋 Configuration notes

- Digital ocean with 300GB DB should be sufficient
- Install direnv on the droplet ***and*** your local env for testing
- Mainnet RPC URL with *****a lot***** of capacity & concurrent request support (10M requests per day, 20 concurrent)
- [Install and configure nginx proxy](https://www.notion.so/Configuration-Notes-8b710b4130224b998c5628136709ea17?pvs=21)
- Install foundry on droplet
- [Allow firewall rules for docker bridge & network](https://www.notion.so/Configuration-Notes-8b710b4130224b998c5628136709ea17?pvs=21)
- Configure the indexer to start indexing one block after the fork
- Configure the indexer to index the block ranges for contract deployments that you want to verify

## 🤖 Bots

There are a series of bots which:

- Configure the network fork
- Mimic market behavior
- Spoof oracles
- Exploit faulty oracles

### 📋 Configuration Bots

`fork.sh`

Create a fork from mainnet at latest block. Useful for local testing

[https://github.com/ipatka/sec-alliance-sims/blob/main/script/sh/fork.sh](https://github.com/ipatka/sec-alliance-sims/blob/main/script/sh/fork.sh)

### 💰 Market Bots

`marketBehavior.sh`

[https://github.com/ipatka/sec-alliance-sims/blob/main/script/sh/marketBehavior.sh](https://github.com/ipatka/sec-alliance-sims/blob/main/script/sh/marketBehavior.sh)

![bots(1).png](assets/bots(1).png)

1. Buy WBTC, LINK, COMP on Uniswap & mint WETH
2. Deposit collateral into compound v3
3. Borrow USDC from collateral
4. Sell USDC for WETH
5. Withdraw WETH

********************Randomizes the amounts for buys, borrows, sells slightly to add variety********************

### 🔎 Oracle Bots

`assumeOracles.sh`

[https://github.com/ipatka/sec-alliance-sims/blob/main/script/sh/assumeOracles.sh](https://github.com/ipatka/sec-alliance-sims/blob/main/script/sh/assumeOracles.sh)

![Untitled scene.png](assets/Untitled_scene.png)

1. Deploy compromised aggregator that allows owner to transmit any price
2. Propose and confirm aggregator on price feeds & validators
    1. Impersonating chainlink multisig
3. Fetch mainnet price
4. Transmit mainnet price to fork

`honestOracles.sh`

[https://github.com/ipatka/sec-alliance-sims/blob/main/script/sh/honestOracles.sh](https://github.com/ipatka/sec-alliance-sims/blob/main/script/sh/honestOracles.sh)

![Honest Oracles.png](assets/Honest_Oracles.png)

1. Fetch mainnet price for each asset
2. Transmit mainnet price on fork
3. Sleep & repeat

`walkOracles`

[https://github.com/ipatka/sec-alliance-sims/blob/main/script/sh/walkOracles.sh](https://github.com/ipatka/sec-alliance-sims/blob/main/script/sh/walkOracles.sh)

![Honest Oracles(1).png](assets/Honest_Oracles(1).png)

1. Fetch current price on fork
2. If base asset, lower the value by asset factor
3. If collateral asset, increase value by asset factor
4. Sleep & repeat

### 😈 Exploit Bots

`exploit.sh`

[https://github.com/ipatka/sec-alliance-sims/blob/main/script/sh/exploit.sh](https://github.com/ipatka/sec-alliance-sims/blob/main/script/sh/exploit.sh)

![Exploit.png](assets/Exploit.png)

1. Calculate flash loan amount for target drain of Comet USDC (can target anywhere from 1% to 100% minus protocol reserves)
2. Borrow asset from Aave
3. Deposit collateral
4. Borrow max available
5. Dump USDC on Uniswap
6. Reserve enough flash loaned asset for repayment
7. Convert remaining to WETH for withdraw
8. Withdraw

## ⚖️ Contracts

`CompromisedAggregator.sol`

[https://github.com/ipatka/sec-alliance-sims/blob/main/src/CompromisedAggregator.sol](https://github.com/ipatka/sec-alliance-sims/blob/main/src/CompromisedAggregator.sol)

Mimics Chainlink aggregator and reports prices to compound V3

Allows owner to transmit answers directly without signature verification

*****************Deployment Script*****************: `SpoofAggregatorUpdate.s.sol`

[https://github.com/ipatka/sec-alliance-sims/blob/main/script/SpoofAggregatorUpdate.s.sol](https://github.com/ipatka/sec-alliance-sims/blob/main/script/SpoofAggregatorUpdate.s.sol)

Deploys new aggregator

*****Transmission Script:***** `TransmitPrice.s.sol`

[https://github.com/ipatka/sec-alliance-sims/blob/main/script/TransmitPrice.s.sol](https://github.com/ipatka/sec-alliance-sims/blob/main/script/TransmitPrice.s.sol)

Submits price to aggregator and calls validator just like mainnet

`CometUtils.sol`

[https://github.com/ipatka/sec-alliance-sims/blob/main/src/CometUtils.sol](https://github.com/ipatka/sec-alliance-sims/blob/main/src/CometUtils.sol)

Extends Comet contract to expose some internal utility functions and adds new ones to get available liquidity to borrower, asset values, etc

Useful for exploit and market behavior bots

`Exploiter.sol`

[https://github.com/ipatka/sec-alliance-sims/blob/main/src/Exploiter.sol](https://github.com/ipatka/sec-alliance-sims/blob/main/src/Exploiter.sol)

Extends Aave flash loan base to:

1. Perform simple flash loans of supported assets (WETH, WBTC, etc)
2. Deposits into Compound
3. Borrows max available
4. Dump USDC on uniswap
5. Pays back flashloan

**********If flash loan is not WETH it sells remaining profit for WETH at the end so it can be withdrawn**********

## 📡 Forta Node

The forta node runs in local standalone mode in a docker on a Digital Ocean droplet. The docker compose file here sets up a forta node, the monitoring bots, and a notification server to push alerts to discord and telegram

[https://github.com/ipatka/forta-node/blob/secalliance/docker-compose/standalone/docker-compose.yml](https://github.com/ipatka/forta-node/blob/secalliance/docker-compose/standalone/docker-compose.yml)

### 🤖 Monitoring Bots

**********Oracle Bot:********** [https://github.com/ipatka/compound-monitoring/tree/comet/oracle-price-monitor](https://github.com/ipatka/compound-monitoring/tree/comet/oracle-price-monitor)

Standard bot running on mainnet. This bot detects when the validator for the price aggregator rejects a price. **Note the price is still transmitted on chain and becomes the valid price for compound, it just emits an event which triggers the bot**

The validator checks the Uniswap price

Example:

WETH price feed: [https://etherscan.io/address/0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419](https://etherscan.io/address/0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419)

WETH aggregator: [https://etherscan.io/address/0xE62B71cf983019BFf55bC83B48601ce8419650CC#readContract](https://etherscan.io/address/0xE62B71cf983019BFf55bC83B48601ce8419650CC#readContract)

WETH validator: [https://etherscan.io/address/0x264BDDFD9D93D48d759FBDB0670bE1C6fDd50236](https://etherscan.io/address/0x264BDDFD9D93D48d759FBDB0670bE1C6fDd50236)

Rejection example: [https://etherscan.io/tx/0xd9704bef01b010eeb55bc6cb9216b6df765ce59143daca911168efb72f861a0d#eventlog](https://etherscan.io/tx/0xd9704bef01b010eeb55bc6cb9216b6df765ce59143daca911168efb72f861a0d#eventlog)

![Screen Shot 2023-07-04 at 9.02.10 PM.png](assets/Screen_Shot_2023-07-04_at_9.02.10_PM.png)

**********Market Bot**********: [https://github.com/ipatka/compound-monitoring/tree/comet/comet-monitor](https://github.com/ipatka/compound-monitoring/tree/comet/comet-monitor)

Custom bot which looks for supply and withdraw events from Comet

![Screen Shot 2023-07-04 at 9.02.20 PM.png](assets/Screen_Shot_2023-07-04_at_9.02.20_PM.png)

### 📓 Scripts

`forta.sh`

Runs forta and starts indexing at latest RPC block

[https://github.com/ipatka/forta-node/blob/secalliance/docker-compose/standalone/scripts/forta.sh](https://github.com/ipatka/forta-node/blob/secalliance/docker-compose/standalone/scripts/forta.sh)

### 📋 Configuration notes

- Install direnv on droplet
- Set discord webhook & telegram bot keys


# Configuration Notes

## Block explorer & Anvil

Configure digital ocean droplet with docker

run this docker compose file [https://github.com/ipatka/blockscout/blob/anvil/docker-compose/docker-compose-anvil.yml](https://github.com/ipatka/blockscout/blob/anvil/docker-compose/docker-compose-anvil.yml)

Set up nginx

allow firewall rules for docker bridge & network

Get foundry ip

set nginx rules

```jsx
root@blockscout-anvil:~# docker network ls
NETWORK ID     NAME                     DRIVER    SCOPE
21115a3f42cb   bridge                   bridge    local
f130f9397f9a   docker-compose_default   bridge    local
05d9b72a4cf3   host                     host      local
89bcdefcd60d   none                     null      local
root@blockscout-anvil:~# docker network inspect -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}' f130f9397f9a
192.168.192.0/20
root@blockscout-anvil:~# sudo ufw allow to 192.168.192.0/20
Rules updated

Execute a command in a running container
root@blockscout-anvil:~# docker exec -it foundry sh
/ # ping foundry
PING foundry (192.168.192.2): 56 data bytes
64 bytes from 192.168.192.2: seq=0 ttl=64 time=0.058 ms
e64 bytes from 192.168.192.2: seq=1 ttl=64 time=0.080 ms
```

NGINX

```jsx
server {
	listen 80 default_server;
	listen [::]:80 default_server;

	# SSL configuration
	#
	# listen 443 ssl default_server;
	# listen [::]:443 ssl default_server;
	#
	# Note: You should disable gzip for SSL traffic.
	# See: https://bugs.debian.org/773332
	#
	# Read up on ssl_ciphers to ensure a secure configuration.
	# See: https://bugs.debian.org/765782
	#
	# Self signed certs generated by the ssl-cert package
	# Don't use them in a production server!
	#
	# include snippets/snakeoil.conf;

	root /var/www/html;

	# Add index.php to the list if you are using PHP
	index index.html index.htm index.nginx-debian.html;

	server_name _;

	location / {
		# First attempt to serve request as file, then
		# as directory, then fall back to displaying a 404.
		# try_files $uri $uri/ =404;
		proxy_pass  http://192.168.192.8:4000/;
	}

	location /explorer/ {
	    proxy_pass  http://192.168.192.8:4000/;
	}

	location /rpc/ {
	    proxy_set_header X-Forwarded-Host $host;
	    proxy_set_header X-Forwarded-Server $host;
	    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
	    proxy_pass  http://192.168.192.2:8545/;
	}

	# pass PHP scripts to FastCGI server
	#
	#location ~ \.php$ {
	#	include snippets/fastcgi-php.conf;
	#
	#	# With php-fpm (or other unix sockets):
	#	fastcgi_pass unix:/run/php/php7.4-fpm.sock;
	#	# With php-cgi (or other tcp sockets):
	#	fastcgi_pass 127.0.0.1:9000;
	#}

	# deny access to .htaccess files, if Apache's document root
	# concurs with nginx's one
	#
	#location ~ /\.ht {
	#	deny all;
	#}
}

# Virtual Host configuration for example.com
#
# You can move that to a different file under sites-available/ and symlink that
# to sites-enabled/ to enable it.
#
#server {
#	listen 80;
#	listen [::]:80;
#
#	server_name example.com;
#
#	root /var/www/example.com;
#	index index.html;
#
#	location / {
#		try_files $uri $uri/ =404;
#	}
#}

server {

	# SSL configuration
	#
	# listen 443 ssl default_server;
	# listen [::]:443 ssl default_server;
	#
	# Note: You should disable gzip for SSL traffic.
	# See: https://bugs.debian.org/773332
	#
	# Read up on ssl_ciphers to ensure a secure configuration.
	# See: https://bugs.debian.org/765782
	#
	# Self signed certs generated by the ssl-cert package
	# Don't use them in a production server!
	#
	# include snippets/snakeoil.conf;

	root /var/www/html;

	# Add index.php to the list if you are using PHP
	index index.html index.htm index.nginx-debian.html;
    server_name securityalliance.dev; # managed by Certbot

	location / {
		# First attempt to serve request as file, then
		# as directory, then fall back to displaying a 404.
		# try_files $uri $uri/ =404;
		proxy_pass  http://192.168.192.8:4000/;
	}

	location /explorer/ {
	    proxy_pass  http://192.168.192.8:4000/;
	}

	location /rpc/ {
	    proxy_set_header X-Forwarded-Host $host;
	    proxy_set_header X-Forwarded-Server $host;
	    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
	    proxy_pass  http://192.168.192.2:8545/;
	}

	# pass PHP scripts to FastCGI server
	#
	#location ~ \.php$ {
	#	include snippets/fastcgi-php.conf;
	#
	#	# With php-fpm (or other unix sockets):
	#	fastcgi_pass unix:/run/php/php7.4-fpm.sock;
	#	# With php-cgi (or other tcp sockets):
	#	fastcgi_pass 127.0.0.1:9000;
	#}

	# deny access to .htaccess files, if Apache's document root
	# concurs with nginx's one
	#
	#location ~ /\.ht {
	#	deny all;
	#}

    listen [::]:443 ssl ipv6only=on; # managed by Certbot
    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/securityalliance.dev/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/securityalliance.dev/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

}
server {
    if ($host = securityalliance.dev) {
        return 301 https://$host$request_uri;
    } # managed by Certbot

	listen 80 ;
	listen [::]:80 ;
    server_name securityalliance.dev;
    return 404; # managed by Certbot

}
```

### Cron Jobs

****Bots****

```jsx
*/15 * * * * (export PATH="$PATH:/root/.foundry/bin"; export BOT=2; /usr/bin/timeout 420 direnv exec /root/sec-alliance-sims bash /root/sec-alliance-sims/script/sh/marketBehavior.sh > /root/logs/`date +\%Y\%m\%d\%H\%M\%S`-bot-2-cron.log 2>&1)
*/15 * * * * (export PATH="$PATH:/root/.foundry/bin"; export BOT=3;  /usr/bin/timeout 420 direnv exec /root/sec-alliance-sims bash /root/sec-alliance-sims/script/sh/marketBehavior.sh > /root/logs/`date +\%Y\%m\%d\%H\%M\%S`-bot-3-cron.log 2>&1)
*/5 * * * * (export PATH="$PATH:/root/.foundry/bin"; /usr/bin/timeout 30 direnv exec /root/sec-alliance-sims bash /root/sec-alliance-sims/script/sh/syncBlockTimeCron.sh > /root/logs/`date +\%Y\%m\%d\%H\%M\%S`-sync-cron.log 2>&1)
```

*****Blockscout*****

```jsx
*/5 * * * * (export PATH="$PATH:/root/.foundry/bin"; /usr/bin/timeout 270 direnv exec /root/blockscout sh /root/blockscout/scripts/restartFoundry.sh > /root/logs/`date +\%Y\%m\%d\%H\%M\%S`-foundryhealth-cron.log 2>&1)
```