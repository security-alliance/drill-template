// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IPoolAddressesProvider} from "aave/interfaces/IPoolAddressesProvider.sol";
import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import {IERC20} from "src/interfaces/IERC20.sol";
import {ICToken, ICErc20, TokenConfig, PriceData, InterestRateModel, IComptroller} from "src/interfaces/Compound.sol";
import {IYearnStrategyHarness, IVaultAPI} from "src/interfaces/Yearn.sol";
import {CompoundUtils} from "src/utils/Compound/CompoundUtils.sol";

contract TestUtils is Test {
    IPoolAddressesProvider provider; // The interface for the Aave pool addresses provider

    IVaultAPI vault_USDC; // The interface for the USDC vault
    IYearnStrategyHarness genLevCompV4_USDC; // The interface for the Yearn USDC strategy
    IERC20 USDC; // The interface for the USDC token
    ICErc20 cUSDC; // The interface for the cUSDC token (Compound USDC)
    ICToken cETH; // The interface for the cETH token (Compound ETH)

    IYearnStrategyHarness lenderYieldOptimiser_USDC; // The interface for the Yearn USDC lender yield optimiser strategy

    CompoundUtils compoundUtils;

    IVaultAPI vault_DAI; // The interface for the DAI vault
    IYearnStrategyHarness genLevCompV4_DAI; // The interface for the Yearn DAI strategy
    IERC20 DAI; // The interface for the DAI token
    ICErc20 cDAI; // The interface for the cDAI token (Compound DAI)

    IComptroller comptroller; // The interface for the Compound protocol's Comptroller

    address keeper; // The address of the keeper
    address strategist; // The address of the strategist
    address management; // The address of management
    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // The address of WETH




    function updateDebtStrategyRatio(
        IYearnStrategyHarness _strat,
        uint256 _ratio
    ) public {
        IVaultAPI _vault = IVaultAPI(_strat.vault());
        vm.startPrank(management);

        _vault.updateStrategyDebtRatio(address(_strat), _ratio * 100); // Convert to bps

        vm.stopPrank();
    }

    /*
     * This function adjusts the collateral target and position for a given strategy.
     * It takes two parameters:
     * _strat: The strategy for which the collateral target is to be adjusted.
     * _collateralTarget: The new collateral target.
     * The function first sets the new collateral target, then calls the tend function twice.
     */
    function adjustCollateralTargetAndPosition(
        IYearnStrategyHarness _strat,
        uint256 _collateralTarget
    ) public {
        vm.startPrank(strategist);
        _strat.setCollateralTarget(_collateralTarget);
        vm.stopPrank();

        vm.startPrank(keeper);
        _strat.tend();
        _strat.tend();
        vm.stopPrank();
    }


    function setUpCompUtils() public {
        keeper = vm.envAddress("YEARN_GENLEVCOMPV4_KEEPER");
        strategist = vm.envAddress("YEARN_GENLEVCOMPV4_STRATEGIST");
        management = vm.envAddress("YEARN_MANAGEMENT");

        address _lenderYieldOptimiser_USDC = vm.envAddress(
            "YEARN_LENDERYIELDOPT_USDC"
        );
        lenderYieldOptimiser_USDC = IYearnStrategyHarness(
            _lenderYieldOptimiser_USDC
        );

        address _genLevCompV4_USDC = vm.envAddress("YEARN_GENLEVCOMPV4_USDC");
        genLevCompV4_USDC = IYearnStrategyHarness(_genLevCompV4_USDC);

        address _usdc = vm.envAddress("USDC");
        USDC = IERC20(_usdc);

        address _vault_USDC = vm.envAddress("YEARN_VAULT_USDC");
        vault_USDC = IVaultAPI(_vault_USDC);

        address _cUSDC = vm.envAddress("CUSDC_V2");
        cUSDC = ICErc20(_cUSDC);

        address _cETH = vm.envAddress("CETH_V2");
        cETH = ICToken(_cETH);

        address _genLevCompV4_DAI = vm.envAddress("YEARN_GENLEVCOMPV4_DAI");
        genLevCompV4_DAI = IYearnStrategyHarness(_genLevCompV4_DAI);

        address _dai = vm.envAddress("DAI");
        DAI = IERC20(_dai);

        address _vault_DAI = vm.envAddress("YEARN_VAULT_DAI");
        vault_DAI = IVaultAPI(_vault_DAI);

        address _cDAI = vm.envAddress("CDAI_V2");
        cDAI = ICErc20(_cDAI);

        address _compoundComptroller = vm.envAddress("COMPOUND_COMPTROLLER");
        comptroller = IComptroller(_compoundComptroller);
    }
}
