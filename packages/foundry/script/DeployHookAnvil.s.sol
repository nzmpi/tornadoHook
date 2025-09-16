// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHasher, TornadoHook} from "../contracts/TornadoHook.sol";
import {TornadoHookEntry} from "../contracts/TornadoHookEntry.sol";
import {Groth16Verifier as CircomVerifier} from "../contracts/verifiers/CircomVerifier.sol";
import {HonkVerifier as NoirVerifier} from "../contracts/verifiers/NoirVerifier.sol";
import "./DeployHelpers.s.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolModifyLiquidityTest} from "v4-core/test/PoolModifyLiquidityTest.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

contract DeployHookAnvil is ScaffoldETHDeploy {
    using HookMiner for address;

    uint160 constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
    address constant create2Deployer = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    struct Data {
        bytes data;
    }

    function run() external ScaffoldEthDeployerRunner {
        bytes memory bytecode =
            abi.decode(vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), "/test/poseidon2.json"))), (Data)).data;
        IHasher hasher;
        assembly {
            hasher := create(0, add(bytecode, 0x20), mload(bytecode))
        }

        CircomVerifier circomVerifier = new CircomVerifier();
        NoirVerifier noirVerifier = new NoirVerifier();

        PoolManager manager = new PoolManager(deployer);
        uint160 flags = uint160(
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG
                | Hooks.AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
                | Hooks.AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG
        );
        bytes32 salt;
        (, salt) = create2Deployer.find(
            flags, type(TornadoHook).creationCode, abi.encode(manager, hasher, circomVerifier, noirVerifier)
        );
        TornadoHook hook = new TornadoHook{salt: salt}(manager, hasher, circomVerifier, noirVerifier);
        new TornadoHookEntry(manager, hook);

        address token0 = address(new MockERC20("token0", "tkn0", 18));
        address token1 = address(new MockERC20("token1", "tkn1", 18));

        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: hook
        });
        manager.initialize(key, SQRT_PRICE_1_1);
    }
}
