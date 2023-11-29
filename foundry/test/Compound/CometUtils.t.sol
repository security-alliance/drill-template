// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import {CometUtilsHarness} from "src/utils/Compound/harnesses/CometUtilsHarness.sol";
import {Comet} from "comet/Comet.sol";
import {Configurator} from "comet/Configurator.sol";
import {ERC20} from "comet/ERC20.sol";

contract CometUtilsTest is Test {
    // the identifiers of the forks
    uint256 mainnetFork;
    address weth;
    address usdc;
    address cometAddress;
    ERC20 usdcContract;


    function setUp() public {
        string memory MAINNET_RPC_URL = vm.envString("MAINNET");
        weth = vm.envAddress("WETH");
        usdc = vm.envAddress("USDC");
        cometAddress = vm.envAddress("CUSDC");
        address configuratorAddress = vm.envAddress("COMET_CONFIGURATOR");
        address cometImpl = vm.envAddress("COMET_IMPL");
        usdcContract = ERC20(usdc);

        mainnetFork = vm.createSelectFork(MAINNET_RPC_URL);
        Configurator configurator = Configurator(configuratorAddress);

    }

    function configureHarnessWithCollateral(
        uint256 collateralAmount
    ) internal returns (CometUtilsHarness harness) {
        vm.selectFork(mainnetFork);
        assertEq(vm.activeFork(), mainnetFork);

        // the new contract is written to `mainnetFork`'s storage
        harness = new CometUtilsHarness(weth, usdc, cometAddress);
        deal(weth, address(harness), collateralAmount);

        harness.depositCollateral(weth, collateralAmount);
    }

    function test_canBorrowMaxLiquidity() public {
        CometUtilsHarness harness = configureHarnessWithCollateral(5 ether);
        uint256 borrowable = harness.getBorrowable(address(harness));

        harness.borrowUSDC(borrowable);
        uint256 usdcBalance = usdcContract.balanceOf(address(harness));
        assertEq(borrowable, usdcBalance);

    }

}
