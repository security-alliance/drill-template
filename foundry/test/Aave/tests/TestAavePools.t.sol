// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {TestUtils} from "../utils/TestUtils.sol";
import {IUSDT} from "src/interfaces/IUSDT.sol";
import {IAToken} from "aave/interfaces/IAToken.sol";
import {VariableDebtToken} from "aave/protocol/tokenization/VariableDebtToken.sol";
import "forge-std/StdUtils.sol";
import {Pool} from "aave/protocol/pool/Pool.sol";
import {DataTypes} from "aave/protocol/libraries/types/DataTypes.sol";

contract TestAavePools is TestUtils {



    function setUp() public {
        setUpTests();
    }

    function testUsdtBalance() public {
        address holder = 0xF977814e90dA44bFA03b6295A0616a897441aceC;
        uint256 balance = usdt.balanceOf(holder);
        assertGt(balance, 0);
    }

    function testUsdtDeal() public {
        address dealt = makeAddr("dealt");
        deal(address(usdt), dealt, 100e6);
        uint256 balance = usdt.balanceOf(dealt);

        assertEq(balance, 100e6);
    }

    function testUsdtPoolDeposit() public {
        address holder = makeAddr("holder");

        deal(address(usdt), holder, 100e9);

        uint256 expectedDeposit = 50e9;
        uint256 underlyingBalanceBefore = usdt.balanceOf(address(aUsdt));

        vm.startPrank(holder);
        usdt.approve(address(pool), 100e9);
        pool.supply(address(usdt), expectedDeposit, holder, 0);

        uint256 underlyingBalanceAfter = usdt.balanceOf(address(aUsdt));

        uint256 depositedUsdt = underlyingBalanceAfter -
            underlyingBalanceBefore;

        uint256 mintedAUsdt = aUsdt.balanceOf(holder);


        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = pool.getUserAccountData(holder);

        assertGt(totalCollateralBase, 0);

        assertEq(expectedDeposit, depositedUsdt);
        assertEq(mintedAUsdt, expectedDeposit);
        assertEq(mintedAUsdt, depositedUsdt);

        vm.stopPrank();
    }

    /*
    Demonstrate that user can withdraw full aToken balance
    */
    function testUsdtPoolWithdraw() public {
        address holder = makeAddr("holder");

        deal(address(usdt), holder, 100e9);

        uint256 expectedDeposit = 50e9;
        uint256 underlyingBalanceBefore = usdt.balanceOf(address(aUsdt));

        vm.startPrank(holder);
        usdt.approve(address(pool), 100e9);
        pool.supply(address(usdt), expectedDeposit, holder, 0);


        uint256 underlyingBalanceAfter = usdt.balanceOf(address(aUsdt));

        uint256 depositedUsdt = underlyingBalanceAfter -
            underlyingBalanceBefore;

        uint256 mintedAUsdt = aUsdt.balanceOf(holder);


        pool.withdraw(address(usdt), mintedAUsdt, holder);

        uint256 aUsdtBalanceAfter = aUsdt.balanceOf(holder);
        uint256 usdtBalanceAfter = usdt.balanceOf(holder);

        assertEq(aUsdtBalanceAfter, 0);
        assertEq(usdtBalanceAfter, 100e9);


        vm.stopPrank();
    }

    function testUsdtPoolBorrow() public {
        address holder = makeAddr("holder");

        deal(address(usdt), holder, 100e9);
        vm.startPrank(holder);
        usdt.approve(address(pool), 100e9);
        pool.supply(address(usdt), 50e9, holder, 0);

        uint256 balance = usdt.balanceOf(holder);

        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = pool.getUserAccountData(holder);

        pool.borrow(address(usdt), 10e9, 2, 0, holder);



        vm.stopPrank();
    }

    function testUsdtPoolRepay() public {
        address otherHolder = makeAddr("otherHolder");
        deal(address(usdt), otherHolder, 100e9);

        vm.startPrank(otherHolder);
        usdt.approve(address(pool), 100e9);
        pool.supply(address(usdt), 50e9, otherHolder, 0);
        vm.stopPrank();

        address holder = makeAddr("holder");

        deal(address(usdt), holder, 100e9);
        vm.startPrank(holder);
        usdt.approve(address(pool), 100e9);
        pool.supply(address(usdt), 50e9, holder, 0);


        uint256 balance = usdt.balanceOf(holder);


        pool.borrow(address(usdt), 10e9, 2, 0, holder);


        pool.repay(address(usdt), type(uint256).max, 2, holder);



        vm.stopPrank();
    }

}
