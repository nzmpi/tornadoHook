// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import {IHasher, TornadoHook} from "../contracts/TornadoHook.sol";
import {Groth16Verifier as CircomVerifier} from "../contracts/verifiers/CircomVerifier.sol";
import {HonkVerifier as NoirVerifier} from "../contracts/verifiers/NoirVerifier.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {PoolModifyLiquidityTest} from "v4-core/test/PoolModifyLiquidityTest.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

contract DeployHook is ScaffoldETHDeploy {
    using HookMiner for address;

    struct Data {
        bytes data;
    }

    address create2Deployer = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

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
        //PoolModifyLiquidityTest modifyLiquidityRouter = new PoolModifyLiquidityTest(manager);
        uint160 flags = uint160(
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG
                | Hooks.AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
                | Hooks.AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
        );
        bytes32 salt;
        (, salt) = create2Deployer.find(flags, type(TornadoHook).creationCode, abi.encode(manager, hasher, circomVerifier, noirVerifier));
        TornadoHook hook = new TornadoHook{salt: salt}(manager, hasher, circomVerifier, noirVerifier);
    }
}
