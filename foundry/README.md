

## cron job

```
*/10 * * * * (export PATH="$PATH:/root/.foundry/bin"; /usr/bin/timeout 420 direnv exec /root/sec-alliance-sims sh /root/sec-alliance-sims/script/sh/marketBehavior.sh > /root/logs/`date +\%Y\%m\%d\%H\%M\%S`-cron.log 2>&1)
```

## Quickstart guide
1. Clone the repo with `git clone`. Pull git submodules with `git submodule init && git submodule update`.
2. Install [Foundry](https://book.getfoundry.sh/getting-started/installation) if you haven't already. `curl -L https://foundry.paradigm.xyz | bash`
3. Use Anvil to [run a simulated fork](https://book.getfoundry.sh/tutorials/forking-mainnet-with-cast-anvil) of eth mainnet
4. Copy `.env.example` to `.env` `cp .env.example .envrc`
5. Add a value for the `PRIVATE_KEY` env var from the output of your local `Anvil` chain. You will also need to set an absolute path to this repo for `FOUNDRY`
6. Add the `.env` vars to your `$PATH` or [setup direnv to handle `.env` files](https://dev.to/charlesloder/tidbit-get-direnv-to-use-env-5fkn)
7. You should now be able to run the scripts in `script/sh`

