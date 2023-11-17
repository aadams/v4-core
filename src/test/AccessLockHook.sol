// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BaseTestHooks} from "./BaseTestHooks.sol";
import {PoolKey} from "../types/PoolKey.sol";
import {IPoolManager} from "../interfaces/IPoolManager.sol";
import {IHooks} from "../interfaces/IHooks.sol";
import {CurrencyLibrary, Currency} from "../types/Currency.sol";
import {Hooks} from "../libraries/Hooks.sol";
import {TickMath} from "../libraries/TickMath.sol";

contract AccessLockHook is BaseTestHooks {
    using CurrencyLibrary for Currency;

    IPoolManager manager;

    constructor(IPoolManager _manager) {
        manager = _manager;
    }

    enum LockAction {
        Mint,
        Take,
        Donate,
        Swap,
        ModifyPosition
    }

    function beforeSwap(
        address, /* sender **/
        PoolKey calldata key,
        IPoolManager.SwapParams calldata, /* params **/
        bytes calldata hookData
    ) external override returns (bytes4) {
        return _executeAction(key, hookData, IHooks.beforeSwap.selector);
    }

    function beforeDonate(
        address, /* sender **/
        PoolKey calldata key,
        uint256, /* amount0 **/
        uint256, /* amount1 **/
        bytes calldata hookData
    ) external override returns (bytes4) {
        return _executeAction(key, hookData, IHooks.beforeDonate.selector);
    }

    function beforeModifyPosition(
        address, /* sender **/
        PoolKey calldata key,
        IPoolManager.ModifyPositionParams calldata, /* params **/
        bytes calldata hookData
    ) external override returns (bytes4) {
        return _executeAction(key, hookData, IHooks.beforeModifyPosition.selector);
    }

    function _executeAction(PoolKey memory key, bytes calldata hookData, bytes4 selector) internal returns (bytes4) {
        if (hookData.length == 0) {
            // We have re-entered the hook or we are initializing liquidity in the pool before testing the lock actions.
            return selector;
        }
        (uint256 amount, LockAction action) = abi.decode(hookData, (uint256, LockAction));

        // These actions just use some hardcoded parameters.
        if (action == LockAction.Mint) {
            manager.mint(key.currency1, address(this), amount);
        } else if (action == LockAction.Take) {
            manager.take(key.currency1, address(this), amount);
        } else if (action == LockAction.Donate) {
            manager.donate(key, amount, amount, new bytes(0));
        } else if (action == LockAction.Swap) {
            manager.swap(
                key,
                IPoolManager.SwapParams({
                    zeroForOne: true,
                    amountSpecified: int256(amount),
                    sqrtPriceLimitX96: TickMath.MIN_SQRT_RATIO + 1
                }),
                new bytes(0)
            );
        } else if (action == LockAction.ModifyPosition) {
            manager.modifyPosition(
                key,
                IPoolManager.ModifyPositionParams({tickLower: -60, tickUpper: 60, liquidityDelta: int256(amount)}),
                new bytes(0)
            );
        } else {
            revert("Invalid action");
        }

        return selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}

contract NoAccessLockHook is BaseTestHooks {
    IPoolManager manager;

    constructor(IPoolManager _manager) {
        manager = _manager;
    }

    function beforeModifyPosition(
        address, /* sender **/
        PoolKey calldata key,
        IPoolManager.ModifyPositionParams calldata, /* params **/
        bytes calldata /* hookData **/
    ) external override returns (bytes4) {
        // This should revert.
        manager.mint(key.currency0, address(this), 100 * 10e18);
        return IHooks.beforeModifyPosition.selector;
    }
}