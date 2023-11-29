// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {TestUtils} from "../utils/TestUtils.sol";
import {IUSDT} from "src/interfaces/IUSDT.sol";
import {IAToken} from "aave/interfaces/IAToken.sol";
import {VariableDebtToken} from "aave/protocol/tokenization/VariableDebtToken.sol";
import "forge-std/StdUtils.sol";
import {Pool} from "aave/protocol/pool/Pool.sol";
import {PoolConfigurator} from "aave/protocol/pool/PoolConfigurator.sol";
import {IPoolAddressesProvider} from "aave/interfaces/IPoolAddressesProvider.sol";
import {DataTypes} from "aave/protocol/libraries/types/DataTypes.sol";

contract TestAaveAdmin is TestUtils {
    address emergencyAdmin = 0xCA76Ebd8617a03126B6FB84F9b1c1A0fB71C2633;
    address poolAdmin = 0xEE56e2B3D491590B5b31738cC34d5232F378a8D5;
    address freezeAdmin = 0x2eE68ACb6A1319de1b49DC139894644E424fefD6;

    IPoolAddressesProvider addressProvider;
    PoolConfigurator poolConfigurator;

    function setUp() public {
        setUpTests();
        addressProvider = pool.ADDRESSES_PROVIDER();
        poolConfigurator = PoolConfigurator(
            addressProvider.getPoolConfigurator()
        );
    }

    function freezeUsdt() internal {
        vm.startPrank(freezeAdmin);
        poolConfigurator.setReserveFreeze(address(usdt), true);

        vm.stopPrank();
    }

    function pauseUsdt() internal {
        vm.startPrank(emergencyAdmin);
        poolConfigurator.setReservePause(address(usdt), true);

        vm.stopPrank();
    }

    function testEmergencyPause() public {
        vm.startPrank(emergencyAdmin);
        poolConfigurator.setReservePause(address(usdt), true);

        vm.stopPrank();
    }

    function testReserveFreeze() public {
        vm.startPrank(freezeAdmin);
        poolConfigurator.setReserveFreeze(address(usdt), true);

        vm.stopPrank();
    }

    function testCannotDepositAfterPause() public {
        pauseUsdt();

        address holder = makeAddr("holder");

        deal(address(usdt), holder, 100e9);

        uint256 expectedDeposit = 50e9;
        uint256 underlyingBalanceBefore = usdt.balanceOf(address(aUsdt));

        vm.startPrank(holder);
        usdt.approve(address(pool), 100e9);
        vm.expectRevert();
        pool.supply(address(usdt), expectedDeposit, holder, 0);
        vm.stopPrank();
    }

    function testCannotWithdrawAfterPause() public {
        address holder = makeAddr("holder");

        deal(address(usdt), holder, 100e9);

        uint256 expectedDeposit = 50e9;
        uint256 underlyingBalanceBefore = usdt.balanceOf(address(aUsdt));

        vm.startPrank(holder);
        usdt.approve(address(pool), 100e9);
        pool.supply(address(usdt), expectedDeposit, holder, 0);
        vm.stopPrank();

        pauseUsdt();
        vm.startPrank(holder);
        vm.expectRevert();
        pool.withdraw(address(usdt), type(uint256).max, holder);
        vm.stopPrank();
    }

    function testCannotBorrowAfterPause() public {
        address holder = makeAddr("holder");

        deal(address(usdt), holder, 100e9);

        uint256 expectedDeposit = 50e9;
        uint256 underlyingBalanceBefore = usdt.balanceOf(address(aUsdt));

        vm.startPrank(holder);
        usdt.approve(address(pool), 100e9);
        pool.supply(address(usdt), expectedDeposit, holder, 0);
        vm.stopPrank();

        pauseUsdt();
        vm.startPrank(holder);
        vm.expectRevert();
        pool.borrow(address(usdt), 10e9, 2, 0, holder);
        vm.stopPrank();
    }

    function testCannotRepayAfterPause() public {
        address holder = makeAddr("holder");

        deal(address(usdt), holder, 100e9);

        uint256 expectedDeposit = 50e9;
        uint256 underlyingBalanceBefore = usdt.balanceOf(address(aUsdt));

        vm.startPrank(holder);
        usdt.approve(address(pool), 100e9);
        pool.supply(address(usdt), expectedDeposit, holder, 0);
        pool.borrow(address(usdt), 10e9, 2, 0, holder);
        vm.stopPrank();

        pauseUsdt();
        vm.startPrank(holder);
        vm.expectRevert();
        pool.repay(address(usdt), type(uint256).max, 2, holder);
        vm.stopPrank();
    }

    function testCannotDepositAfterFreeze() public {
        freezeUsdt();

        address holder = makeAddr("holder");

        deal(address(usdt), holder, 100e9);

        uint256 expectedDeposit = 50e9;
        uint256 underlyingBalanceBefore = usdt.balanceOf(address(aUsdt));

        vm.startPrank(holder);
        usdt.approve(address(pool), 100e9);
        vm.expectRevert();
        pool.supply(address(usdt), expectedDeposit, holder, 0);
        vm.stopPrank();
    }

    function testCanWithdrawAfterFreeze() public {
        address holder = makeAddr("holder");

        deal(address(usdt), holder, 100e9);

        uint256 expectedDeposit = 50e9;
        uint256 underlyingBalanceBefore = usdt.balanceOf(address(aUsdt));

        vm.startPrank(holder);
        usdt.approve(address(pool), 100e9);
        pool.supply(address(usdt), expectedDeposit, holder, 0);
        vm.stopPrank();

        freezeUsdt();
        vm.startPrank(holder);
        // vm.expectRevert();
        pool.withdraw(address(usdt), type(uint256).max, holder);
        vm.stopPrank();
    }

    function testCannotBorrowAfterFreeze() public {
        address holder = makeAddr("holder");

        deal(address(usdt), holder, 100e9);

        uint256 expectedDeposit = 50e9;
        uint256 underlyingBalanceBefore = usdt.balanceOf(address(aUsdt));

        vm.startPrank(holder);
        usdt.approve(address(pool), 100e9);
        pool.supply(address(usdt), expectedDeposit, holder, 0);
        vm.stopPrank();

        freezeUsdt();
        vm.startPrank(holder);
        vm.expectRevert();
        pool.borrow(address(usdt), 10e9, 2, 0, holder);
        vm.stopPrank();
    }

    function testCanRepayAfterFreeze() public {
        address holder = makeAddr("holder");

        deal(address(usdt), holder, 100e9);

        uint256 expectedDeposit = 50e9;
        uint256 underlyingBalanceBefore = usdt.balanceOf(address(aUsdt));

        vm.startPrank(holder);
        usdt.approve(address(pool), 100e9);
        pool.supply(address(usdt), expectedDeposit, holder, 0);
        pool.borrow(address(usdt), 10e9, 2, 0, holder);
        vm.stopPrank();

        freezeUsdt();
        vm.startPrank(holder);
        pool.repay(address(usdt), type(uint256).max, 2, holder);
        vm.stopPrank();
    }
}
