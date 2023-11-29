#! /bin/bash
echo "***ANVIL FORK***"

# echo "Getting latest block..." && \
# FORK_BLOCK=`cast block --rpc-url $MAINNET | grep "number" | grep -Eo '[0-9]{8}'` && \
echo $FORK_BLOCK && \
# anvil --fork-url  $MAINNET --fork-block-number $FORK_BLOCK --block-time 5
anvil --fork-url  $MAINNET --fork-block-number $FORK_BLOCK --port 8545 --base-fee 0 --chain-id 1337


exit 0