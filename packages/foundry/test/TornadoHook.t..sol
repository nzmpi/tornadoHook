//SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHasher, TornadoHook} from "../contracts/TornadoHook.sol";
import {Groth16Verifier as CircomVerifier} from "../contracts/verifiers/CircomVerifier.sol";
import {HonkVerifier as NoirVerifier} from "../contracts/verifiers/NoirVerifier.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {Test, console} from "forge-std/Test.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";

contract TornadoHookTest is Test, Deployers {
    using LiquidityAmounts for uint160;
    using StateLibrary for IPoolManager;

    bytes32 constant FIELD_SIZE = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;
    bytes32 constant ZERO_VALUE = 0x2fe54c60d3acabf3343a35b6eba15db4821b340f76e741e2249685ed4899af6c; // = keccak256("tornado") % FIELD_SIZE
    int24 constant MIN_TICK = TickMath.MIN_TICK + 52;
    int24 constant MAX_TICK = TickMath.MAX_TICK - 52;
    uint160 immutable MIN_PRICE = TickMath.getSqrtPriceAtTick(MIN_TICK);
    uint160 immutable MAX_PRICE = TickMath.getSqrtPriceAtTick(MAX_TICK);
    address immutable user1 = vm.addr(1);
    address immutable user2 = vm.addr(2);
    address immutable user3 = vm.addr(3);

    IHasher immutable HASHER;
    CircomVerifier immutable CIRCOM_VERIFIER;
    NoirVerifier immutable NOIR_VERIFIER;

    struct Data {
        bytes data;
    }

    MockERC20 token0;
    MockERC20 token1;

    TornadoHook hook;

    constructor() payable {
        bytes memory bytecode =
            abi.decode(vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), "/test/poseidon2.json"))), (Data)).data;
        IHasher hasher;
        assembly {
            hasher := create(0, add(bytecode, 0x20), mload(bytecode))
        }

        HASHER = hasher;
        CIRCOM_VERIFIER = new CircomVerifier();
        NOIR_VERIFIER = new NoirVerifier();
    }

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        uint160 flags = uint160(
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG
                | Hooks.AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
                | Hooks.AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
        );
        deployCodeTo(
            "TornadoHook.sol:TornadoHook", abi.encode(manager, HASHER, CIRCOM_VERIFIER, NOIR_VERIFIER), address(flags)
        );
        hook = TornadoHook(address(flags));

        token0 = MockERC20(Currency.unwrap(currency0));
        token1 = MockERC20(Currency.unwrap(currency1));

        token0.mint(user1, 10000 ether);
        token1.mint(user1, 10000 ether);
        vm.startPrank(user1);
        token0.approve(address(modifyLiquidityRouter), type(uint256).max);
        token1.approve(address(modifyLiquidityRouter), type(uint256).max);

        token0.mint(user2, 10000 ether);
        token1.mint(user2, 10000 ether);
        vm.startPrank(user2);
        token0.approve(address(modifyLiquidityRouter), type(uint256).max);
        token1.approve(address(modifyLiquidityRouter), type(uint256).max);

        (key,) = initPool(currency0, currency1, hook, 3000, SQRT_PRICE_1_1);
    }

    function test() public {
        vm.startPrank(user1);
        bytes32 nullifier = _getHash("user1 nullifier");
        bytes32 secret = _getHash("user1 secret");
        bytes32 commitment = HASHER.poseidon([nullifier, secret]);
        bytes32 expectedRoot = 0x2afe60738ea9338219c1122c95cb273d05f9fa23f435ff4b09c3408bca994615;
        ModifyLiquidityParams memory params =
            ModifyLiquidityParams({tickLower: MIN_TICK, tickUpper: MAX_TICK, liquidityDelta: 10 ether, salt: 0});
        vm.expectEmit(true, true, true, false);
        emit TornadoHook.Deposit(commitment, 1, 0, expectedRoot);
        modifyLiquidityRouter.modifyLiquidity(key, params, abi.encode(commitment));

        vm.startPrank(user2);
        nullifier = _getHash("user2 nullifier");
        secret = _getHash("user2 secret");
        commitment = HASHER.poseidon([nullifier, secret]);
        expectedRoot = 0x05dd7f25fce2c0e54c73c13733622782c4ebb519d2d9b097fd97258349fcd7e0;
        params = ModifyLiquidityParams({tickLower: MIN_TICK, tickUpper: MAX_TICK, liquidityDelta: 10 ether, salt: 0});
        vm.expectEmit(true, true, true, false);
        emit TornadoHook.Deposit(commitment, 1, 1, expectedRoot);
        modifyLiquidityRouter.modifyLiquidity(key, params, abi.encode(commitment));

        _swaps();

        vm.startPrank(user3);
        console.log(token0.balanceOf(address(user3)));
        console.log(token1.balanceOf(address(user3)));
        bytes memory proof = abi.encode(
            [
                11248212746627502792784592779753519429641806161153775494417471465158144667688,
                10157933768447643025042821367718651361361564712984337320693169079449058102468
            ],
            [
                [
                    400057851183980834802119353336106921072489078667598071853635030162425265974,
                    3473556767969256657147886510805983131979682251597990010271507411137147118092
                ],
                [
                    21647015864039657983922799841403530601201233453321259121024708198933765818572,
                    20427958297172244191209139731099298645042338243747062814554128576973552340799
                ]
            ],
            [
                10875954164999359525093690209604075367001905898310946056839354146897589117404,
                4190056633960469961416067544570911618879702213156793302303836221749184546209
            ]
        );
        bytes32 nullifierHash = 0x10696e46ec40cd307d7e330f3904b52be0e5baf586d7400f7c88f9ef6261ea79;
        TornadoHook.WithdrawalData memory withdrawalData = TornadoHook.WithdrawalData({
            isCircom: true,
            nullifierHash: nullifierHash,
            root: expectedRoot,
            recipient: user3,
            proof: proof
        });
        params = ModifyLiquidityParams({tickLower: MIN_TICK, tickUpper: MAX_TICK, liquidityDelta: -10 ether, salt: 0});
        vm.expectEmit(true, true, false, false);
        emit TornadoHook.Withdrawal(user3, nullifierHash);
        modifyLiquidityRouter.modifyLiquidity(key, params, abi.encode(withdrawalData));

        proof = abi.decode(
            vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), "/test/proofs/noir_proof_user2.json"))), (Data)
        ).data;
        nullifierHash = 0x06872edb69176d4178b5c12fe3a58370af367675f811a847d7c22f1275a8e584;
        withdrawalData = TornadoHook.WithdrawalData({
            isCircom: false,
            nullifierHash: nullifierHash,
            root: expectedRoot,
            recipient: user3,
            proof: proof
        });
        vm.expectEmit(true, true, false, false);
        emit TornadoHook.Withdrawal(user3, nullifierHash);
        modifyLiquidityRouter.modifyLiquidity(key, params, abi.encode(withdrawalData));
    }

    function _swaps() internal {
        address trader = vm.addr(42);
        token0.mint(trader, 10000 ether);
        token1.mint(trader, 10000 ether);
        vm.startPrank(trader);
        token0.approve(address(swapRouter), type(uint256).max);
        token1.approve(address(swapRouter), type(uint256).max);
        bool zeroForOne = true;
        swapRouter.swap(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: 3 ether,
                sqrtPriceLimitX96: zeroForOne ? MIN_PRICE : MAX_PRICE
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
        swapRouter.swap(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: 1 ether,
                sqrtPriceLimitX96: zeroForOne ? MIN_PRICE : MAX_PRICE
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
        zeroForOne = false;
        swapRouter.swap(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: 5 ether,
                sqrtPriceLimitX96: zeroForOne ? MIN_PRICE : MAX_PRICE
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
        swapRouter.swap(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: 1.5 ether,
                sqrtPriceLimitX96: zeroForOne ? MIN_PRICE : MAX_PRICE
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
        vm.stopPrank();
    }

    function _getHash(string memory input) internal pure returns (bytes32 res) {
        res = keccak256(bytes(input));
        assembly {
            res := mod(res, FIELD_SIZE)
        }
    }
}
