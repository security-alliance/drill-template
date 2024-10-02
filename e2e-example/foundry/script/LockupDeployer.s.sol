// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";
import { Lockup } from "../src/Lockup.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract LockupDeployer is Script {

    Lockup deployedLockup;

    function deploy() public {
        vm.startBroadcast();
        address implementation = address(new Lockup());
        address proxy = address(
            new ERC1967Proxy(
                implementation,
                abi.encodeWithSignature("initialize()")
            )
        );
        vm.stopBroadcast();

        deployedLockup = Lockup(proxy);
    }
}
