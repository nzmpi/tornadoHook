//SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./Constants.sol";
import {WithdrawalData} from "./TornadoHook.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";

contract TornadoHookEntry is IUnlockCallback {
    using SafeERC20 for IERC20;

    IPoolManager public immutable POOL_MANAGER;
    IHooks public immutable HOOK;

    error THE_NotPoolManager();
    error THE_OnlyERC20();

    constructor(IPoolManager _manager, IHooks _hook) payable {
        POOL_MANAGER = _manager;
        HOOK = _hook;
    }

    struct Callback {
        bool isDeposit;
        address caller;
        Currency currency0;
        Currency currency1;
        bytes hookData;
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        if (msg.sender != address(POOL_MANAGER)) revert THE_NotPoolManager();

        Callback memory callback = abi.decode(data, (Callback));
        if (callback.currency0.isAddressZero() || callback.currency1.isAddressZero()) revert THE_OnlyERC20();
        (callback.currency0, callback.currency1) = callback.currency0 < callback.currency1
            ? (callback.currency0, callback.currency1)
            : (callback.currency1, callback.currency0);

        PoolKey memory key = PoolKey({
            currency0: callback.currency0,
            currency1: callback.currency1,
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: HOOK
        });

        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: MIN_TICK,
            tickUpper: MAX_TICK,
            liquidityDelta: callback.isDeposit ? LIQUIDITY_DELTA : -LIQUIDITY_DELTA,
            salt: SALT
        });

        (BalanceDelta delta,) = POOL_MANAGER.modifyLiquidity(key, params, callback.hookData);

        if (callback.isDeposit) {
            _settle(callback.caller, callback.currency0, uint256(uint128(-delta.amount0())));
            _settle(callback.caller, callback.currency1, uint256(uint128(-delta.amount1())));
        }

        return "";
    }

    function deposit(Currency token0, Currency token1, bytes32 commitment) external {
        bytes memory callback = abi.encode(
            Callback({
                isDeposit: true,
                caller: msg.sender,
                currency0: token0,
                currency1: token1,
                hookData: abi.encode(commitment)
            })
        );
        POOL_MANAGER.unlock(callback);
    }

    function withdraw(Currency token0, Currency token1, WithdrawalData calldata withdrawalData) external {
        bytes memory callback = abi.encode(
            Callback({
                isDeposit: false,
                caller: msg.sender,
                currency0: token0,
                currency1: token1,
                hookData: abi.encode(withdrawalData)
            })
        );
        POOL_MANAGER.unlock(callback);
    }

    function _settle(address caller, Currency currency, uint256 amount) internal {
        POOL_MANAGER.sync(currency);
        IERC20(Currency.unwrap(currency)).safeTransferFrom(caller, address(POOL_MANAGER), amount);
        POOL_MANAGER.settle();
    }
}
