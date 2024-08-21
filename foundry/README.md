## Example Protocol for SEAL Attack Simulation Template

Work in progress. Here is a relevant comment from the `Lockup.sol` contract:


```solidity
/*

    This is a very simple example protocol intended to be used in the SEAL attack simulation template.

    The protocol allows anyone to lock up tokens for a recipient. After `LOCKUP_PERIOD` seconds have passed, 
    the lockup can be finalized by anyone through the `claim()` function.

    Since this is intended for the attack simulation template, a bug has intentionally been introduced into
    this contract. The bug is that the `claim()` function does not clear the lockup information until after
    the call to the token's `transfer()` function. Since there are some obscure tokens that give execution
    control flow to the recipient during a token transfer (e.g. see ERC777 tokens), there are some situations
    where tokens can be claimed multiple times using reentrancy.

    This example protocol + example bug is ideally a good starting point for showing how an attack simulation
    can be set up. With this in mind, some relevant design choices include:

        - It is easy to set-up monitoring for this contract. For example, monitoring of token balances, or
        monitoring of events emitted by this contract. 

        - The exploit is not always triggerable in a way which can drain the entire contract instantly. This is
        because an attempt to exploit the funds would require waiting `LOCKUP_PERIOD` seconds. Also only strange
        tokens with `transfer()` callbacks can be stolen, which are more rare.

        - There are interesting ways to respond to a detected exploit, since this contract is pausable and also
        upgradeable.
*/
```

## Current progress

- Lockup contract implemented in `src/Lockup.sol`
- The bug has been quickly tested to exist in `script/LockupExploit.s.sol`
- An example incident response (pausing then upgrading) has been quickly tested in `script/LockupIncidentResponse.s.sol`
- Some really basic tests have been added in `Lockup.t.sol`


## Todo

- Document the code more and explain how the contracts/scripts tie into the template
- The scripts are very rough and need polishing. They're really more like tests right now, but will adapt them into actual scripts that can be run in the attack sim template repo. Getting these scripts to run with `pnpm` instead of `forge` will probably match the template repo too.
- Add monitoring + bots using the template repo. Will discuss with Isaac on next steps for this