// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {IUSDT} from "src/interfaces/IUSDT.sol";
import {IAToken} from "aave/interfaces/IAToken.sol";
import {VariableDebtToken} from "aave/protocol/tokenization/VariableDebtToken.sol";
import "forge-std/StdUtils.sol";
import {Pool} from "aave/protocol/pool/Pool.sol";
import {DataTypes} from "aave/protocol/libraries/types/DataTypes.sol";

contract TestUtils is Test {
    // using ReserveLogic for DataTypes.ReserveData;

    uint256 mainnetFork; // The fork of the mainnet being used for testing
    IUSDT usdt;
    IAToken aUsdt;
    Pool pool;

    function setUpTests() public {
        string memory MAINNET_RPC_URL = vm.envString("MAINNET");

        usdt = IUSDT(vm.envAddress("USDT"));
        pool = Pool(vm.envAddress("AAVE_POOL"));
        aUsdt = IAToken(vm.envAddress("AUSDT"));

        uint256 forkBlock = vm.envUint("FORK_BLOCK");

        mainnetFork = vm.createSelectFork(MAINNET_RPC_URL, forkBlock);
    }

    function dealBorrowRepay(address holder, uint256 borrowAmount) public {
        deal(address(usdt), holder, borrowAmount * 3);
        vm.startPrank(holder);
        usdt.approve(address(pool), borrowAmount * 3);
        pool.supply(address(usdt), borrowAmount * 2, holder, 0);

        uint256 requestedBorrow = borrowAmount;

        pool.borrow(address(usdt), requestedBorrow, 2, 0, holder);

        pool.repay(address(usdt), type(uint256).max, 2, holder);

        vm.stopPrank();
    }
}
