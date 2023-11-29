// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import {TestUtils} from "./utils/TestUtils.sol";

contract YearnStrategiesTest is TestUtils {
    uint256 mainnetFork; // The fork of the mainnet being used for testing

    function setUp() public {
        string memory MAINNET_RPC_URL = vm.envString("MAINNET");

        setUpCompUtils();

        mainnetFork = vm.createSelectFork(MAINNET_RPC_URL);
    }

    /*
     * The following tests are for normal operations of the strategies
     */

    /*
     * This function tests if the DAI keeper can harvest.
     * The function first starts a prank on the keeper.
     * Then, it gets the balance of the DAI vault before the harvest.
     * After that, it calls the harvest function on the DAI strategy.
     * Finally, it gets the balance of the DAI vault after the harvest and asserts that it is not equal to the balance before the harvest.
     */
    function testDaiKeeperCanHarvest() public {
        vm.startPrank(keeper);
        uint256 vaultBalanceBefore = DAI.balanceOf(address(vault_DAI));

        genLevCompV4_DAI.harvest();

        uint256 vaultBalanceAfter = DAI.balanceOf(address(vault_DAI));


        assertNotEq(vaultBalanceAfter, vaultBalanceBefore);
        vm.stopPrank();
    }

    function test_usdcKeeperCanHarvest() public {
        vm.startPrank(keeper);
        uint256 vaultBalanceBefore = USDC.balanceOf(address(vault_USDC));

        genLevCompV4_USDC.harvest();

        uint256 vaultBalanceAfter = USDC.balanceOf(address(vault_USDC));


        assertNotEq(vaultBalanceAfter, vaultBalanceBefore);
        vm.stopPrank();
    }

    function test_usdcKeeperCanTend() public {
        vm.startPrank(keeper);
        uint256 cBalanceBefore = cUSDC.balanceOf(address(genLevCompV4_USDC));

        genLevCompV4_USDC.tend();

        uint256 cBalanceAfter = cUSDC.balanceOf(address(genLevCompV4_USDC));


        assertNotEq(cBalanceAfter, cBalanceBefore);
        vm.stopPrank();
    }


}
