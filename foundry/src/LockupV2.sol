// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Lockup} from "./Lockup.sol";

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
contract LockupV2 is Lockup {
    /***************************************************************************
        Initialization + Admin
    ***************************************************************************/

    constructor() Lockup() {}

    /***************************************************************************
        Business logic
    ***************************************************************************/

    function claim(uint256[] calldata _ids) external override whenNotPaused {
        for (uint256 i; i < _ids.length; ++i) {
            LockupInfo memory l = lockups[_ids[i]];

            if (i != 0)
                require(_ids[i - 1] < _ids[i], "input ids are not increasing");
            require(l.startTime != 0, "lockup doesn't exist");
            require(
                l.startTime + LOCKUP_PERIOD < block.timestamp,
                "lockup not complete"
            );

            delete lockups[_ids[i]];
            IERC20(l.token).transfer(l.recipient, l.amount);
            emit LockupClaimed(l);
        }
    }
}
