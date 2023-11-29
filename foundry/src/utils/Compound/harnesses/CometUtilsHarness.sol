// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;


import {CometUtils} from "src/utils/Compound/CometUtils.sol";

interface ERC20 {
    /**
     * @notice Gets the balance of the specified address
     * @param owner The address from which the balance will be retrieved
     * @return The balance
     */
    function balanceOf(address owner) external view returns (uint256);

    /**
     * @notice Approve `spender` to transfer up to `amount` from `src`
     * @dev This will overwrite the approval amount for `spender`
     *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
     * @param spender The address of the account which may transfer tokens
     * @param amount The number of tokens that are approved (-1 means infinite)
     * @return Whether or not the approval succeeded
     */
    function approve(address spender, uint256 amount) external returns (bool);

    function decimals() external view returns (uint8);
}

interface IWETH9 is ERC20 {
    function deposit() external payable;

    function withdraw(uint wad) external;
}


contract CometUtilsHarness is CometUtils {
    IWETH9 internal weth;
    ERC20 internal usdc;

    constructor(
        address _weth,
        address _usdc,
        address _comet
    ) CometUtils(_comet) {
        weth = IWETH9(_weth);
        usdc = ERC20(_usdc);
    }

    function withdrawCollateral(
        address asset
    ) external returns (uint256 withdrawableCollateral) {
        withdrawableCollateral = getWithdrawableCollateral(
            address(this),
            asset
        );
        if (withdrawableCollateral > 0)
            comet.withdraw(asset, withdrawableCollateral);
    }

    function depositCollateral(
        address collateralAssetAddress,
        uint256 collateralAmount
    ) public {
        ERC20 collateralAsset = ERC20(collateralAssetAddress);

        // Deposit loaned asset into Comet
        collateralAsset.approve(address(comet), collateralAmount);
        comet.supply(collateralAssetAddress, collateralAmount);
    }

    function borrowUSDC(uint256 amount) external {
        // Borrow USDC
        comet.withdraw(comet.baseToken(), amount);
    }
}
