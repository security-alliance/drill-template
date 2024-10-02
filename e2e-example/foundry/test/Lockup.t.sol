// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Lockup} from "../src/Lockup.sol";
import {LockupV2} from "../src/LockupV2.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MockToken} from "../src/fixtures/MockToken.sol";


contract LockupTest is Test {
    Lockup lockup;
    MockToken token;

    address alice;
    address bob;
    address owner;

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
        token = new MockToken("Token", "Token", address(this));

        alice = makeAddr("alice");
        bob = makeAddr("bob");
        owner = lockup.owner();
        
        token.mint(alice, 50 ether);
        vm.startPrank(alice);
        token.approve(address(lockup), type(uint256).max);
        vm.stopPrank();
    }

    function test_pause_unpause() public {
        vm.startPrank(owner);

        // Test pause
        lockup.pause();
        assertTrue(lockup.paused(), "Contract should be paused");

        // Test unpause
        lockup.unpause();
        assertFalse(lockup.paused(), "Contract should be unpaused");

        vm.stopPrank();
    }

    function test_pause_unpause_not_owner() public {
        vm.startPrank(alice);

        // Test pause (should revert)
        vm.expectRevert();
        lockup.pause();

        // Test unpause (should revert)
        vm.expectRevert();
        lockup.unpause();

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
            (l.id, l.token, l.recipient, l.startTime, l.amount) = lockup
                .lockups(i + 1);
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
        for (uint256 i; i < ids.length; ++i) ids[i] = i + 1;
        lockup.claim(ids);
    }
    
    function test_upgrade_succeeds() public {
        vm.startPrank(owner);
        lockup.upgradeToAndCall(address(new LockupV2()), "");
        vm.stopPrank();
        
        
        // Ensure contract still works post upgrade
        vm.startPrank(alice);
        uint256 id = lockup.lockup(token, bob, 10 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + lockup.LOCKUP_PERIOD() + 1);
        uint256[] memory ids = new uint256[](1);
        ids[0] = id;
        lockup.claim(ids);
    }
}
