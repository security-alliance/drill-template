// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { Lockup } from "../src/Lockup.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Token is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        _mint(msg.sender, 100 ether);
    }
}

contract LockupTest is Test {
    Lockup lockup;
    IERC20 token; 

    address alice;
    address bob;

    function setUp() public {
        lockup = new Lockup();
        token = new Token("Token", "Token");

        alice = makeAddr("alice");
        bob = makeAddr("bob");

        token.transfer(alice, 50 ether);
        vm.startPrank(alice);
        token.approve(address(lockup), type(uint256).max);
        vm.stopPrank();
    }

    function test_multiple_lockup_succeeds() public {
        vm.startPrank(alice);
        for (uint256 i; i < 5; ++i) {
            lockup.lockup(token, bob, 10 ether);
        }
        vm.stopPrank();

        assertEq(token.balanceOf(address(lockup)), 50 ether);
        for (uint256 i; i < 5; ++i) {
            Lockup.LockupInfo memory l; 
            (l.token, l.recipient, l.startTime, l.amount)= lockup.lockups(i+1);
            assertEq(address(l.token), address(token));
            assertEq(l.recipient, bob);
            assertEq(l.startTime, block.timestamp);
            assertEq(l.amount, 10 ether);
        }
    }

    function test_multiple_claim_succeeds() public {
        vm.startPrank(alice);
        for (uint256 i; i < 5; ++i) {
            lockup.lockup(token, bob, 10 ether);
        }
        vm.stopPrank();

        vm.warp(block.timestamp + lockup.LOCKUP_PERIOD() + 1);

        uint256[] memory ids = new uint256[](5);
        for (uint256 i; i < ids.length; ++i) ids[i] = i+1;
        lockup.claim(ids);
    }
}
