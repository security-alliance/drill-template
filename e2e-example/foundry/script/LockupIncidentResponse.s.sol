// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";
import { Lockup } from "../src/Lockup.sol";
import { LockupDeployer } from "./LockupDeployer.s.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract LockupIncidentResponse is LockupDeployer {

    Lockup lockup;

    function runIncidentResponse(address lockupAddr) public {
    
        if (lockupAddr == address(0)) {
            // Assume that `lockupAddr == 0` means the lockup needs to be deployed
            deploy();
            lockup = deployedLockup;
        } else {
            lockup = Lockup(lockupAddr);
        }

        vm.startPrank(lockup.owner());
        lockup.pause();
        vm.stopPrank();

        uint256[] memory ids;

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        lockup.claim(ids);

        vm.startPrank(lockup.owner());
        lockup.upgradeToAndCall(address(this), "");
        vm.stopPrank();
    }

    function proxiableUUID() external returns (bytes32) {
        return 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    }
}