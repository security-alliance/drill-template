// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Lockup} from "../src/Lockup.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LockupExploit} from "../src/LockupExploiter.sol";
import {CallbackToken} from "../src/fixtures/CallbackToken.sol";
import {LockupV2} from "../src/LockupV2.sol";

contract LockupIncidentResponseTest is Test {
    Lockup lockup;
    IERC20 token;
    CallbackToken callbackToken;
    LockupExploit exploiter;

    address alice;
    address bob;
    address exploiterOwner;
    address lockupOwner;

    function setUp() public {
        // Deploy the implementation contract
        Lockup lockupImplementation = new Lockup();

        // Deploy the proxy contract
        bytes memory initializeData = abi.encodeWithSelector(
            Lockup.initialize.selector
        );
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(lockupImplementation),
            initializeData
        );

        // Set the lockup variable to the proxy address, but cast it to the Lockup interface
        lockup = Lockup(address(proxy));
        callbackToken = new CallbackToken(
            "CallbackToken",
            "CBT",
            address(this)
        );

        alice = makeAddr("alice");
        bob = makeAddr("bob");
        exploiterOwner = makeAddr("exploiterOwner");
        lockupOwner = lockup.owner();
    }


    function test_exploit_fails_after_upgrade() public {
        vm.startPrank(lockupOwner);
        lockup.upgradeToAndCall(address(new LockupV2()), "");
        vm.stopPrank();

        // Setup
        exploiter = new LockupExploit(exploiterOwner);

        // Create a lockup for the exploiter
        uint256 lockupAmount = 10 ether;
        callbackToken.mint(address(this), lockupAmount);
        callbackToken.approve(address(lockup), lockupAmount);
        uint256 lockupId = lockup.lockup(
            IERC20(address(callbackToken)),
            address(exploiter),
            lockupAmount
        );
        
        // Create a lockup for alice
        callbackToken.mint(address(this), lockupAmount);
        callbackToken.approve(address(lockup), lockupAmount);
        uint256 aliceLockupId = lockup.lockup(
            IERC20(address(callbackToken)),
            alice,
            lockupAmount
        );

        // Warp time to after the lockup period
        vm.warp(block.timestamp + lockup.LOCKUP_PERIOD() + 1);

        // Record balances before exploit
        uint256 lockupBalanceBefore = callbackToken.balanceOf(address(lockup));
        uint256 exploiterBalanceBefore = callbackToken.balanceOf(
            address(exploiter)
        );

        // Run the exploit
        vm.prank(exploiterOwner);
        exploiter.runExploit(address(callbackToken), address(lockup), lockupId);

        // Check balances after exploit
        uint256 lockupBalanceAfter = callbackToken.balanceOf(address(lockup));
        uint256 exploiterBalanceAfter = callbackToken.balanceOf(
            address(exploiter)
        );

        // Assert that the exploit was unsuccessful
        assertEq(
            lockupBalanceAfter,
            lockupAmount,
            "Lockup should have balance after attempted exploit"
        );
        assertEq(
            exploiterBalanceAfter,
            lockupAmount,
            "Exploiter should have balance after attempted exploit"
        );

        // Try to claim as Alice (should succeed as exploit fails)
        uint256[] memory ids = new uint256[](1);
        ids[0] = aliceLockupId;
        vm.prank(alice);
        lockup.claim(ids);
        

    }
}