// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;


import {ERC20} from "comet/ERC20.sol";
import {Comet} from "comet/Comet.sol";
import {CometMath} from "comet/CometMath.sol";
import {CometStorage} from "comet/CometStorage.sol";
import {CometCore} from "comet/CometCore.sol";

contract CometUtils is CometMath {
    /// @dev The scale for base index (depends on time/rate scales, not base token)
    uint64 internal constant BASE_INDEX_SCALE = 1e15;

    /// @dev The scale for factors
    uint64 internal constant FACTOR_SCALE = 1e18;

    Comet internal comet;
    uint8 public numAssets;
    uint256 public baseScale;
    address public baseTokenPriceFeed;
    address public baseToken;

    uint64 internal baseSupplyIndex;
    uint64 internal baseBorrowIndex;

    constructor(address _comet) {
        comet = Comet(payable(_comet));
        numAssets = comet.numAssets();
        baseScale = comet.baseScale();
        baseSupplyIndex = BASE_INDEX_SCALE;
        baseBorrowIndex = BASE_INDEX_SCALE;
        baseTokenPriceFeed = comet.baseTokenPriceFeed();
        baseToken = comet.baseToken();
    }

    /**CUSTOM UTILS**/

    function getLiquidity(address account) public returns (int256) {
        // Possibly call accrue first
        comet.accrueAccount(address(this));
        (int104 principal, , , uint16 assetsIn, ) = comet.userBasic(account);
        int liquidity = signedMulPrice(
            presentValue(principal),
            comet.getPrice(baseTokenPriceFeed),
            uint64(baseScale)
        );
        

        for (uint8 i = 0; i < numAssets; ) {
            if (isInAsset(assetsIn, i)) {
                CometCore.AssetInfo memory asset = comet.getAssetInfo(i);

                (uint128 balance, ) = comet.userCollateral(
                    account,
                    asset.asset
                );

                uint newAmount = mulPrice(
                    balance,
                    comet.getPrice(asset.priceFeed),
                    asset.scale
                );

                liquidity += signed256(
                    mulFactor(newAmount, asset.borrowCollateralFactor)
                );
            }
            unchecked {
                i++;
            }
        }

        return liquidity;
    }

    function getAssetValue(
        address _asset,
        uint256 _amount
    ) public view returns (uint256) {
        CometCore.AssetInfo memory asset = comet.getAssetInfoByAddress(_asset);
        uint256 value = mulPrice(
            _amount,
            comet.getPrice(asset.priceFeed),
            asset.scale
        );
        return value;
    }

    function getTotalBorrowableValue() public view returns (uint256) {
        int256 reserves = comet.getReserves();
        uint balance = ERC20(baseToken).balanceOf(address(comet));
        int256 borrowable = signed256(balance) - reserves;
        int borrowableValue = signedMulPrice(
            borrowable,
            comet.getPrice(baseTokenPriceFeed),
            uint64(baseScale)
        );
        return borrowableValue >= 0 ? unsigned256(borrowableValue) : 0;
    }

    function getWithdrawableCollateral(
        address account,
        address asset
    ) public view returns (uint256 withdrawable) {
        // Possibly call accrue
        (int104 principal, , , , ) = comet.userBasic(account);

        CometCore.AssetInfo memory assetInfo = comet.getAssetInfoByAddress(
            asset
        );
        (uint128 balance, ) = comet.userCollateral(account, assetInfo.asset);

        if (principal >= 0) withdrawable = uint256(balance);
        else {
            uint256 unsignedPrincipal = uint256(uint104(principal * -1));

            // Get required amount of collateral to match this principal accounting for liquidation factor
            uint256 assetPrice = comet.getPrice(assetInfo.priceFeed);
            uint256 assetPriceDiscounted = mulFactor(
                assetPrice,
                FACTOR_SCALE - (FACTOR_SCALE - assetInfo.borrowCollateralFactor)
            );
            uint256 basePrice = comet.getPrice(baseTokenPriceFeed);
            uint256 minCollateral = (basePrice *
                unsignedPrincipal *
                assetInfo.scale) /
                assetPriceDiscounted /
                baseScale;

            withdrawable = uint256(balance) > minCollateral
                ? (uint256(balance) - minCollateral)
                : 0;
        }
    }

    function getBorrowable(
        address account
    ) public returns (uint256 borrowable) {
        int liquidity = getLiquidity(account);
        uint256 basePrice = comet.getPrice(baseTokenPriceFeed);

        if (liquidity <= 0) borrowable = 0;
        else {
            borrowable = divPrice(
                unsigned256(liquidity),
                comet.getPrice(baseTokenPriceFeed),
                uint64(baseScale)
            );
        }
    }

    /** EXPOSE COMET INTERNALS **/
    /**
     * @dev Multiply a signed `fromScale` quantity by a price, returning a common price quantity
     */
    function signedMulPrice(
        int n,
        uint price,
        uint64 fromScale
    ) internal pure returns (int) {
        return (n * signed256(price)) / int256(uint256(fromScale));
    }

    /**
     * @dev Whether user has a non-zero balance of an asset, given assetsIn flags
     */
    function isInAsset(
        uint16 assetsIn,
        uint8 assetOffset
    ) internal pure returns (bool) {
        return (assetsIn & (uint16(1) << assetOffset) != 0);
    }

    /**
     * @dev Multiply a `fromScale` quantity by a price, returning a common price quantity
     */
    function mulPrice(
        uint n,
        uint price,
        uint64 fromScale
    ) internal pure returns (uint) {
        return (n * price) / fromScale;
    }

    /**
     * @dev Multiply a number by a factor
     */
    function mulFactor(uint n, uint factor) internal pure returns (uint) {
        return (n * factor) / FACTOR_SCALE;
    }

    /**
     * @dev Divide a common price quantity by a price, returning a `toScale` quantity
     */
    function divPrice(
        uint n,
        uint price,
        uint64 toScale
    ) internal pure returns (uint) {
        return (n * toScale) / price;
    }

    /**

    /**
     * @dev The positive present supply balance if positive or the negative borrow balance if negative
     */
    function presentValue(
        int104 principalValue_
    ) internal view returns (int256) {
        if (principalValue_ >= 0) {
            return
                signed256(
                    presentValueSupply(
                        baseSupplyIndex,
                        uint104(principalValue_)
                    )
                );
        } else {
            return
                -signed256(
                    presentValueBorrow(
                        baseBorrowIndex,
                        uint104(-principalValue_)
                    )
                );
        }
    }

    /**
     * @dev The principal amount projected forward by the supply index
     */
    function presentValueSupply(
        uint64 baseSupplyIndex_,
        uint104 principalValue_
    ) internal pure returns (uint256) {
        return (uint256(principalValue_) * baseSupplyIndex_) / BASE_INDEX_SCALE;
    }

    /**
     * @dev The principal amount projected forward by the borrow index
     */
    function presentValueBorrow(
        uint64 baseBorrowIndex_,
        uint104 principalValue_
    ) internal pure returns (uint256) {
        return (uint256(principalValue_) * baseBorrowIndex_) / BASE_INDEX_SCALE;
    }

    /**
     * @dev The positive principal if positive or the negative principal if negative
     */
    function principalValue(
        int256 presentValue_
    ) internal view returns (int104) {
        if (presentValue_ >= 0) {
            return
                signed104(
                    principalValueSupply(
                        baseSupplyIndex,
                        uint256(presentValue_)
                    )
                );
        } else {
            return
                -signed104(
                    principalValueBorrow(
                        baseBorrowIndex,
                        uint256(-presentValue_)
                    )
                );
        }
    }

    /**
     * @dev The present value projected backward by the supply index (rounded down)
     *  Note: This will overflow (revert) at 2^104/1e18=~20 trillion principal for assets with 18 decimals.
     */
    function principalValueSupply(
        uint64 baseSupplyIndex_,
        uint256 presentValue_
    ) internal pure returns (uint104) {
        return safe104((presentValue_ * BASE_INDEX_SCALE) / baseSupplyIndex_);
    }

    /**
     * @dev The present value projected backward by the borrow index (rounded up)
     *  Note: This will overflow (revert) at 2^104/1e18=~20 trillion principal for assets with 18 decimals.
     */
    function principalValueBorrow(
        uint64 baseBorrowIndex_,
        uint256 presentValue_
    ) internal pure returns (uint104) {
        return
            safe104(
                (presentValue_ * BASE_INDEX_SCALE + baseBorrowIndex_ - 1) /
                    baseBorrowIndex_
            );
    }
}
