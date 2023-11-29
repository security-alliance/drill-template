// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;


import {IFlashLoanSimpleReceiver} from "aave/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {IPoolAddressesProvider} from "aave/interfaces/IPoolAddressesProvider.sol";
import {DataTypes} from "aave/protocol/libraries/types/DataTypes.sol";
import {IPool} from "aave/interfaces/IPool.sol";

/**
 * @title FlashLoanSimpleReceiverBase
 * @author Aave
 * @notice Base contract to develop a flashloan-receiver contract.
 */
abstract contract FlashLoanSimpleReceiverBase is IFlashLoanSimpleReceiver {
    IPoolAddressesProvider public immutable override ADDRESSES_PROVIDER;
    IPool public immutable override POOL;

    constructor(IPoolAddressesProvider provider) {
        ADDRESSES_PROVIDER = provider;
        POOL = IPool(provider.getPool());
    }
}

abstract contract FlashloanUtils is FlashLoanSimpleReceiverBase {
    constructor(
        IPoolAddressesProvider _provider
    ) FlashLoanSimpleReceiverBase(_provider) {}

    /**CUSTOM UTILS**/

    function getATokenAddress(address asset) external view returns (address) {
        DataTypes.ReserveData memory reserveData = POOL.getReserveData(asset);
        return reserveData.aTokenAddress;
    }
}
