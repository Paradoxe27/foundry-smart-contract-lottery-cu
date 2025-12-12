# Proveably random contracts

## What do we want it to do?
1. everyone can enter the raffle by paying an amount of eth as fees
2. After X period of time, the lottery will automatically draw a winner 
    1. This will be done programmatically
3. Using Chainlink VRF & Chainlink Automation
    1. Chainlink VRF -> Randomness
    2. Chainlink Automation -> Time based triggers

## Tests!

1. Write the deploy script
    1. Note THis will not work on ZKsync
2. write test
    1. Local chain
    2. forked chain
    3. forked mainnet