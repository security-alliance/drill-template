// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";
import { Lockup } from "../src/Lockup.sol";
import {MockToken} from "../src/fixtures/MockToken.sol";
import { CallbackToken } from "../src/fixtures/CallbackToken.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract LockupPause is Script {

    Lockup deployedLockup;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        address lockupProxyAddress = 0xCC9676b9bf25cE45a3a5F88205239aFdDeCF1BC7;
        
        Lockup lockup = Lockup(lockupProxyAddress);
        
        address lockupOwner = lockup.owner();
        
        if (lockupOwner != deployer) {
            console.log("Lockup owner is not the deployer");
            return;
        }
        
        if (lockup.paused()) {
            console.log("Lockup is already paused");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);
        
        lockup.pause();
        
        vm.stopBroadcast();

    }
}
