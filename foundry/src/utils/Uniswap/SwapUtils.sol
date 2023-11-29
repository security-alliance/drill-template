// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;


import {IERC20} from "src/interfaces/IERC20.sol";
import {ICErc20, ICEther, InterestRateModel, IComptroller, IUniswapAnchoredView, TokenConfig} from "src/interfaces/Compound.sol";

interface IWETH9 is IERC20 {
    function deposit() external payable;

    function withdraw(uint wad) external;
}

// File: IUniswapV3SwapCallback.sol

/// @title Callback for IUniswapV3PoolActions#swap
/// @notice Any contract that calls IUniswapV3PoolActions#swap must implement this interface
interface IUniswapV3SwapCallback {
    /// @notice Called to `msg.sender` after executing a swap via IUniswapV3Pool#swap.
    /// @dev In the implementation you must pay the pool tokens owed for the swap.
    /// The caller of this method must be checked to be a UniswapV3Pool deployed by the canonical UniswapV3Factory.
    /// amount0Delta and amount1Delta can both be 0 if no tokens were swapped.
    /// @param amount0Delta The amount of token0 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token0 to the pool.
    /// @param amount1Delta The amount of token1 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token1 to the pool.
    /// @param data Any data passed through by the caller via the IUniswapV3PoolActions#swap call
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}

interface IUniswapV3Router is IUniswapV3SwapCallback {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactInputParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInput(
        ExactInputParams calldata params
    ) external payable returns (uint256 amountOut);

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactOutputSingleParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutputSingle(
        ExactOutputSingleParams calldata params
    ) external payable returns (uint256 amountIn);

    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another along the specified path (reversed)
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactOutputParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutput(
        ExactOutputParams calldata params
    ) external payable returns (uint256 amountIn);
}

contract SwapUtils {
    IUniswapV3Router constant UNI_V3_ROUTER =
        IUniswapV3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    IERC20 internal usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 internal dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IWETH9 internal weth = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 internal wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

    uint24 public swapFee3000 = 3000;
    uint24 public swapFee500 = 500;

    constructor() {
        approveTokenMax(address(usdc), address(UNI_V3_ROUTER));
        approveTokenMax(address(dai), address(UNI_V3_ROUTER));
        approveTokenMax(address(weth), address(UNI_V3_ROUTER));
    }

    function approveTokenMax(address token, address spender) internal {
        IERC20(token).approve(spender, type(uint256).max);
    }

    function swap(address _in, address _out, uint256 _inAmount) public {
        uint256 remaining = _inAmount;
        uint256 out;

        // Direct swap in 0.05% pool 50%
        uint256 swapAmount = _inAmount / 2;
        remaining -= swapAmount;
        out =
            out +
            UNI_V3_ROUTER.exactInput(
                IUniswapV3Router.ExactInputParams(
                    abi.encodePacked(_in, swapFee500, _out),
                    address(this),
                    block.timestamp,
                    swapAmount,
                    0
                )
            );

        // Direct swap in 0.3% pool 30%
        swapAmount = _inAmount / 3;
        remaining -= swapAmount;
        out =
            out +
            UNI_V3_ROUTER.exactInput(
                IUniswapV3Router.ExactInputParams(
                    abi.encodePacked(_in, swapFee3000, _out),
                    address(this),
                    block.timestamp,
                    swapAmount,
                    0
                )
            );

        // Multihop swap through WBTC 20%
        swapAmount = remaining;
        out =
            out +
            UNI_V3_ROUTER.exactInput(
                IUniswapV3Router.ExactInputParams(
                    abi.encodePacked(_in, swapFee3000, address(wbtc), swapFee500, _out),
                    address(this),
                    block.timestamp,
                    swapAmount,
                    0
                )
            );
    }

}
