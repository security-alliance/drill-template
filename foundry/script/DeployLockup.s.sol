// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";
import { Lockup } from "../src/Lockup.sol";
import {MockToken} from "../src/fixtures/MockToken.sol";
import { CallbackToken } from "../src/fixtures/CallbackToken.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract Deploy is Script {


    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);
        

        address implementation = address(new Lockup());
        address proxy = address(
            new ERC1967Proxy(
                implementation,
                abi.encodeWithSignature("initialize()")
            )
        );
        
        // TODO transfer ownership of lockup to a safe
        vm.stopBroadcast();

    }
}
