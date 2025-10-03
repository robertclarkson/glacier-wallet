# Regtest Block Rewards

In Bitcoin Core regtest mode, the block subsidy **halves every 150 blocks** (unlike mainnet's 210,000 blocks).

## Block Reward Schedule

| Block Range | Reward per Block |
|-------------|------------------|
| 0 - 149     | 50 BTC          |
| 150 - 299   | 25 BTC          |
| 300 - 449   | 12.5 BTC        |
| 450 - 599   | 6.25 BTC        |
| 600 - 749   | 3.125 BTC       |
| ... and so on |                |

After ~30 halvings (around block 4500), the reward becomes essentially zero.

## Important Notes

1. **Coinbase Maturity**: You need 101 confirmations before spending a coinbase output
   - So you need to mine 101 blocks before you can spend the first block's reward
   - The first 100 blocks are "immature"

2. **Recommended Practice**: 
   - Keep your regtest blockchain under 150 blocks to maintain 50 BTC rewards
   - If you need more funds, reset the chain periodically: 
     ```bash
     bitcoin-cli -regtest -rpcuser=bitcoin -rpcpassword=bitcoin stop
     rm -rf ~/.bitcoin/regtest
     bitcoind -regtest -rpcuser=bitcoin -rpcpassword=bitcoin -rpcport=18443 -daemon
     ```

3. **Why You Had Zero Balance**:
   - You had mined 5,000+ blocks
   - After ~30 halvings, the subsidy became negligible
   - All your blocks were mined after the subsidy exhausted

## Fresh Start

The blockchain has been reset to block 0. Mine 101 blocks to get started:
- This will give you 50 BTC from block 0, spendable after 101 confirmations
- Total mature balance after 101 blocks: 50 BTC (from block 0 only)
- After 102 blocks: 100 BTC (blocks 0-1 are mature)
- After 103 blocks: 150 BTC (blocks 0-2 are mature)
- And so on...

**Remember**: Stay under block 150 if you want to keep 50 BTC per block!
