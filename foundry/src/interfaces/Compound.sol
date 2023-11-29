// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.7;

/// @dev Describe how to interpret the fixedPrice in the TokenConfig.
enum PriceSource {
    FIXED_ETH, /// implies the fixedPrice is a constant multiple of the ETH price (which varies)
    FIXED_USD, /// implies the fixedPrice is a constant multiple of the USD price (which is 1)
    REPORTER /// implies the price is set by the reporter
}

struct PriceData {
    uint248 price;
    bool failoverActive;
}

/// @dev Describe how the USD price should be determined for an asset.
///  There should be 1 TokenConfig object for each supported asset, passed in the constructor.
struct TokenConfig {
    // The address of the Compound Token
    address cToken;
    // The address of the underlying market token. For this `LINK` market configuration, this would be the address of the `LINK` token.
    address underlying;
    // The bytes32 hash of the underlying symbol.
    bytes32 symbolHash;
    // The number of smallest units of measurement in a single whole unit.
    uint256 baseUnit;
    // Where price is coming from.  Refer to README for more information
    PriceSource priceSource;
    // The fixed price multiple of either ETH or USD, depending on the `priceSource`. If `priceSource` is `reporter`, this is unused.
    uint256 fixedPrice;
    // The address of the pool being used as the anchor for this market.
    address uniswapMarket;
    // The address of the `ValidatorProxy` acting as the reporter
    address reporter;
    // Prices reported by a `ValidatorProxy` must be transformed to 6 decimals for the UAV.  This is the multiplier to convert the reported price to 6dp
    uint256 reporterMultiplier;
    // True if the pair on Uniswap is defined as ETH / X
    bool isUniswapReversed;
}

interface IUniswapAnchoredView {
    /// @notice The event emitted when new prices are posted but the stored price is not updated due to the anchor
    event PriceGuarded(
        bytes32 indexed symbolHash,
        uint256 reporterPrice,
        uint256 anchorPrice
    );

    /// @notice The event emitted when the stored price is updated
    event PriceUpdated(bytes32 indexed symbolHash, uint256 price);

    /// @notice The event emitted when failover is activated
    event FailoverActivated(bytes32 indexed symbolHash);

    /// @notice The event emitted when failover is deactivated
    event FailoverDeactivated(bytes32 indexed symbolHash);

    function numTokens() external view returns (uint256);

    function price(string memory symbol) external view returns (uint256);

    function prices(
        bytes32 symbolHash
    ) external view returns (PriceData memory);

    function validate(
        uint256 /* previousRoundId */,
        int256 /* previousAnswer */,
        uint256 /* currentRoundId */,
        int256 currentAnswer
    ) external returns (bool valid);

    /**
     * @notice Get the underlying price of a cToken, in the format expected by the Comptroller.
     * @dev Implements the PriceOracle interface for Compound v2.
     * @param cToken The cToken address for price retrieval
     * @return Price denominated in USD for the given cToken address, in the format expected by the Comptroller.
     */
    function getUnderlyingPrice(address cToken) external view returns (uint256);

    function getTokenConfigBySymbolHash(
        bytes32 symbolHash
    ) external view returns (TokenConfig memory);

    function getTokenConfigByReporter(
        address reporter
    ) external view returns (TokenConfig memory);

    function getTokenConfigByUnderlying(
        address underlying
    ) external view returns (TokenConfig memory);

    function getTokenConfigByCToken(
        address cToken
    ) external view returns (TokenConfig memory);

    function getTokenConfig(
        uint256 i
    ) external view returns (TokenConfig memory);

    function fetchEthPrice() external view returns (uint256);
}

interface InterestRateModel {
    /**
     * @notice Calculates the current borrow interest rate per block
     * @param cash The total amount of cash the market has
     * @param borrows The total amount of borrows the market has outstanding
     * @param reserves The total amount of reserves the market has
     * @return The borrow rate per block (as a percentage, and scaled by 1e18)
     */
    function getBorrowRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) external view returns (uint256, uint256);

    /**
     * @notice Calculates the current supply interest rate per block
     * @param cash The total amount of cash the market has
     * @param borrows The total amount of borrows the market has outstanding
     * @param reserves The total amount of reserves the market has
     * @param reserveFactorMantissa The current reserve factor the market has
     * @return The supply rate per block (as a percentage, and scaled by 1e18)
     */
    function getSupplyRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves,
        uint256 reserveFactorMantissa
    ) external view returns (uint256);

    /**
     * @notice Calculates the utilization rate of the market: `borrows / (cash + borrows - reserves)`
     * @param cash The amount of cash in the market
     * @param borrows The amount of borrows in the market
     * @param reserves The amount of reserves in the market (currently unused)
     * @return The utilization rate as a mantissa between [0, BASE]
     */
    function utilizationRate(
        uint cash,
        uint borrows,
        uint reserves
    ) external pure returns (uint);
}

interface ICToken {
    /*** Market Events ***/

    /**
     * @notice Event emitted when interest is accrued
     */
    event AccrueInterest(
        uint256 cashPrior,
        uint256 interestAccumulated,
        uint256 borrowIndex,
        uint256 totalBorrows
    );

    /**
     * @notice Event emitted when tokens are minted
     */
    event Mint(address minter, uint256 mintAmount, uint256 mintTokens);

    /**
     * @notice Event emitted when tokens are redeemed
     */
    event Redeem(address redeemer, uint256 redeemAmount, uint256 redeemTokens);

    /**
     * @notice Event emitted when underlying is borrowed
     */
    event Borrow(
        address borrower,
        uint256 borrowAmount,
        uint256 accountBorrows,
        uint256 totalBorrows
    );

    /**
     * @notice Event emitted when a borrow is repaid
     */
    event RepayBorrow(
        address payer,
        address borrower,
        uint256 repayAmount,
        uint256 accountBorrows,
        uint256 totalBorrows
    );

    /**
     * @notice Event emitted when a borrow is liquidated
     */
    event LiquidateBorrow(
        address liquidator,
        address borrower,
        uint256 repayAmount,
        address cTokenCollateral,
        uint256 seizeTokens
    );

    /*** Admin Events ***/

    /**
     * @notice Event emitted when pendingAdmin is changed
     */
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    /**
     * @notice Event emitted when pendingAdmin is accepted, which means admin is updated
     */
    event NewAdmin(address oldAdmin, address newAdmin);

    /**
     * @notice Event emitted when the reserve factor is changed
     */
    event NewReserveFactor(
        uint256 oldReserveFactorMantissa,
        uint256 newReserveFactorMantissa
    );

    /**
     * @notice Event emitted when the reserves are added
     */
    event ReservesAdded(
        address benefactor,
        uint256 addAmount,
        uint256 newTotalReserves
    );

    /**
     * @notice Event emitted when the reserves are reduced
     */
    event ReservesReduced(
        address admin,
        uint256 reduceAmount,
        uint256 newTotalReserves
    );

    /**
     * @notice EIP20 Transfer event
     */
    event Transfer(address indexed from, address indexed to, uint256 amount);

    /**
     * @notice EIP20 Approval event
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );

    /**
     * @notice Failure event
     */
    event Failure(uint256 error, uint256 info, uint256 detail);

    function borrow(uint borrowAmount) external returns (uint);

    function transfer(address dst, uint256 amount) external returns (bool);

    function transferFrom(
        address src,
        address dst,
        uint256 amount
    ) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function balanceOfUnderlying(address owner) external returns (uint256);

    function getAccountSnapshot(
        address account
    ) external view returns (uint256, uint256, uint256, uint256);

    function borrowRatePerBlock() external view returns (uint256);

    function supplyRatePerBlock() external view returns (uint256);

    function totalBorrowsCurrent() external returns (uint256);

    function borrowBalanceCurrent(address account) external returns (uint256);

    function borrowBalanceStored(
        address account
    ) external view returns (uint256);

    function exchangeRateCurrent() external returns (uint256);

    function accrualBlockNumber() external view returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function getCash() external view returns (uint256);

    function accrueInterest() external returns (uint256);

    function interestRateModel() external view returns (InterestRateModel);

    function totalReserves() external view returns (uint256);

    function reserveFactorMantissa() external view returns (uint256);

    function seize(
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) external returns (uint256);

    function totalBorrows() external view returns (uint256);

    function totalSupply() external view returns (uint256);
}

interface ICErc20 is ICToken {
    function mint(uint mintAmount) external returns (uint);

    function repayBorrow(uint repayAmount) external returns (uint);
}

interface ICEther is ICToken {
    function mint() external payable;

    function repayBorrow() external payable;
}

interface IComptroller {
    function enterMarkets(
        address[] calldata cTokens
    ) external returns (uint256[] memory);

    function exitMarket(address cToken) external returns (uint256);

    /*** Policy Hooks ***/

    function mintAllowed(
        address cToken,
        address minter,
        uint256 mintAmount
    ) external returns (uint256);

    function mintVerify(
        address cToken,
        address minter,
        uint256 mintAmount,
        uint256 mintTokens
    ) external;

    function redeemAllowed(
        address cToken,
        address redeemer,
        uint256 redeemTokens
    ) external returns (uint256);

    function redeemVerify(
        address cToken,
        address redeemer,
        uint256 redeemAmount,
        uint256 redeemTokens
    ) external;

    function borrowAllowed(
        address cToken,
        address borrower,
        uint256 borrowAmount
    ) external returns (uint256);

    function borrowVerify(
        address cToken,
        address borrower,
        uint256 borrowAmount
    ) external;

    function repayBorrowAllowed(
        address cToken,
        address payer,
        address borrower,
        uint256 repayAmount
    ) external returns (uint256);

    function repayBorrowVerify(
        address cToken,
        address payer,
        address borrower,
        uint256 repayAmount,
        uint256 borrowerIndex
    ) external;

    function liquidateBorrowAllowed(
        address cTokenBorrowed,
        address cTokenCollateral,
        address liquidator,
        address borrower,
        uint256 repayAmount
    ) external returns (uint256);

    function liquidateBorrowVerify(
        address cTokenBorrowed,
        address cTokenCollateral,
        address liquidator,
        address borrower,
        uint256 repayAmount,
        uint256 seizeTokens
    ) external;

    function seizeAllowed(
        address cTokenCollateral,
        address cTokenBorrowed,
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) external returns (uint256);

    function seizeVerify(
        address cTokenCollateral,
        address cTokenBorrowed,
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) external;

    function transferAllowed(
        address cToken,
        address src,
        address dst,
        uint256 transferTokens
    ) external returns (uint256);

    function transferVerify(
        address cToken,
        address src,
        address dst,
        uint256 transferTokens
    ) external;

    /*** Liquidity/Liquidation Calculations ***/

    function liquidateCalculateSeizeTokens(
        address cTokenBorrowed,
        address cTokenCollateral,
        uint256 repayAmount
    ) external view returns (uint256, uint256);

    function getAccountLiquidity(
        address account
    ) external view returns (uint256, uint256, uint256);

    /**
     * @notice Determine what the account liquidity would be if the given amounts were redeemed/borrowed
     * @param cTokenModify The market to hypothetically redeem/borrow in
     * @param account The account to determine liquidity for
     * @param redeemTokens The number of tokens to hypothetically redeem
     * @param borrowAmount The amount of underlying to hypothetically borrow
     * @return (possible error code (semi-opaque),
                hypothetical account liquidity in excess of collateral requirements,
     *          hypothetical account shortfall below collateral requirements)
     */
    function getHypotheticalAccountLiquidity(
        address account,
        address cTokenModify,
        uint redeemTokens,
        uint borrowAmount
    ) external view returns (uint, uint, uint);

    /***  Comp claims ****/
    function claimComp(address holder) external;

    function claimComp(address holder, ICToken[] memory cTokens) external;

    function markets(
        address ctoken
    ) external view returns (bool, uint256, bool);

    function compSpeeds(address ctoken) external view returns (uint256); // will be deprecated

    function compSupplySpeeds(address ctoken) external view returns (uint256);

    function compBorrowSpeeds(address ctoken) external view returns (uint256);

    function oracle() external view returns (address);
}
