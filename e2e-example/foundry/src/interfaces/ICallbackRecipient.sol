// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ICallbackRecipient {
    function ERC20Callback(address from, uint256 value) external;
}