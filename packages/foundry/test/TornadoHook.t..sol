//SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../contracts/Constants.sol";
import {IHasher} from "../contracts/IHasher.sol";
import {BaseHook, TornadoHook, WithdrawalData} from "../contracts/TornadoHook.sol";
import {TornadoHookEntry} from "../contracts/TornadoHookEntry.sol";
import {Groth16Verifier as CircomVerifier} from "../contracts/verifiers/CircomVerifier.sol";
import {BaseHonkVerifier, HonkVerifier as NoirVerifier} from "../contracts/verifiers/NoirVerifier.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {Test, console} from "forge-std/Test.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {CustomRevert} from "v4-core/libraries/CustomRevert.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";

contract TornadoHookTest is Test, Deployers {
    using LiquidityAmounts for uint160;
    using StateLibrary for IPoolManager;

    uint256 immutable LIQUIDITY_DELTA_SQUARE = uint256(LIQUIDITY_DELTA) * uint256(LIQUIDITY_DELTA);
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
    PoolId poolId;
    TornadoHook hook;
    TornadoHookEntry entry;

    constructor() payable {
        // deploy poseidon hasher
        bytes memory bytecode =
            abi.decode(vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), "/test/poseidon2.json"))), (Data)).data;
        IHasher hasher;
        assembly ("memory-safe") {
            hasher := create(0, add(bytecode, 0x20), mload(bytecode))
        }

        HASHER = hasher;
        CIRCOM_VERIFIER = new CircomVerifier();
        NOIR_VERIFIER = new NoirVerifier();

        vm.label(user1, "User1");
        vm.label(user2, "User2");
        vm.label(user3, "User3");
        vm.label(address(this), "Test contract");
    }

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        uint160 flags = uint160(
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG
                | Hooks.AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
                | Hooks.AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG
        );
        deployCodeTo(
            "TornadoHook.sol:TornadoHook", abi.encode(manager, HASHER, CIRCOM_VERIFIER, NOIR_VERIFIER), address(flags)
        );
        hook = TornadoHook(address(flags));
        entry = new TornadoHookEntry(manager, hook);

        token0 = MockERC20(Currency.unwrap(currency0));
        token1 = MockERC20(Currency.unwrap(currency1));

        vm.startPrank(user1);
        token0.mint(user1, 100 ether);
        token1.mint(user1, 200 ether);
        token0.approve(address(entry), type(uint256).max);
        token1.approve(address(entry), type(uint256).max);

        vm.startPrank(user2);
        token0.mint(user2, 300 ether);
        token1.mint(user2, 400 ether);
        token0.approve(address(entry), type(uint256).max);
        token1.approve(address(entry), type(uint256).max);
        vm.stopPrank();

        (key,) = initPool(currency0, currency1, hook, 3000, SQRT_PRICE_1_1);
        poolId = key.toId();
    }

    function test_setUp() public view {
        (uint160 sqrtPriceX96,,,) = manager.getSlot0(poolId);
        assertNotEq(sqrtPriceX96, 0, "Pool not initialized");
        assertEq(manager.getLiquidity(poolId), 0, "Pool is not empty");
        assertEq(hook.currentTreeNumber(poolId), 0, "Wrong initial tree number");
        assertEq(hook.nextLeafIndex(poolId), 0, "Wrong initial leaf index");

        (uint128 liquidity,,) = manager.getPositionInfo(poolId, user1, MIN_TICK, MAX_TICK, SALT);
        assertEq(liquidity, 0, "Wrong user1 liquidity");
        (liquidity,,) = manager.getPositionInfo(poolId, user2, MIN_TICK, MAX_TICK, SALT);
        assertEq(liquidity, 0, "Wrong user2 liquidity");
        (liquidity,,) = manager.getPositionInfo(poolId, user3, MIN_TICK, MAX_TICK, SALT);
        assertEq(liquidity, 0, "Wrong user3 liquidity");
        (liquidity,,) = manager.getPositionInfo(poolId, address(entry), MIN_TICK, MAX_TICK, SALT);
        assertEq(liquidity, 0, "Wrong entry liquidity");
    }

    function test_deposit() public {
        vm.startPrank(user1);
        uint256 userBalanceBefore0 = token0.balanceOf(user1);
        uint256 userBalanceBefore1 = token1.balanceOf(user1);
        uint256 managerBalanceBefore0 = token0.balanceOf(address(manager));
        uint256 managerBalanceBefore1 = token1.balanceOf(address(manager));
        bytes32 commitment = _getCommitment("user1 nullifier", "user1 secret");
        bytes32 expectedRoot = 0x2afe60738ea9338219c1122c95cb273d05f9fa23f435ff4b09c3408bca994615;
        assertFalse(hook.roots(expectedRoot), "Root should not exist 1");

        vm.expectEmit(true, true, true, false);
        emit TornadoHook.Deposit(commitment, 1, 0);
        entry.deposit(currency0, currency1, commitment);

        // check the contract state
        assertEq(hook.currentTreeNumber(poolId), 1, "Wrong tree number 1");
        assertEq(hook.nextLeafIndex(poolId), 1, "Wrong leaf index 1");
        assertTrue(hook.commitments(commitment), "Commitment is not saved 1");
        assertTrue(hook.roots(expectedRoot), "Root is not saved 1");
        assertEq(hook.getPath(poolId, 1, 0)[LEVELS], expectedRoot, "Wrong calculated root 1");

        // instead of checking the balances we check k = x*y, due to a price change
        assertEq(_getK(user1, userBalanceBefore0, userBalanceBefore1), LIQUIDITY_DELTA_SQUARE, "Wrong user1 K");
        assertEq(
            _getK(address(manager), managerBalanceBefore0, managerBalanceBefore1),
            LIQUIDITY_DELTA_SQUARE,
            "Wrong manager K 1"
        );

        // check liquidities
        assertEq(manager.getLiquidity(poolId), uint256(LIQUIDITY_DELTA), "Wrong manager liquidity 1");
        (uint128 liquidity,,) = manager.getPositionInfo(poolId, user1, MIN_TICK, MAX_TICK, SALT);
        assertEq(liquidity, 0, "Wrong user1 liquidity 1");
        (liquidity,,) = manager.getPositionInfo(poolId, address(entry), MIN_TICK, MAX_TICK, SALT);
        assertEq(liquidity, uint256(LIQUIDITY_DELTA), "Wrong entry liquidity 1");

        vm.startPrank(user2);
        userBalanceBefore0 = token0.balanceOf(user2);
        userBalanceBefore1 = token1.balanceOf(user2);
        managerBalanceBefore0 = token0.balanceOf(address(manager));
        managerBalanceBefore1 = token1.balanceOf(address(manager));
        commitment = _getCommitment("user2 nullifier", "user2 secret");
        expectedRoot = 0x05dd7f25fce2c0e54c73c13733622782c4ebb519d2d9b097fd97258349fcd7e0;
        assertFalse(hook.roots(expectedRoot), "Root should not exist 2");

        vm.expectEmit(true, true, true, false);
        emit TornadoHook.Deposit(commitment, 1, 1);
        entry.deposit(currency0, currency1, commitment);

        // check the contract state
        assertEq(hook.currentTreeNumber(poolId), 1, "Wrong tree number 2");
        assertEq(hook.nextLeafIndex(poolId), 2, "Wrong leaf index 2");
        assertTrue(hook.commitments(commitment), "Commitment is not saved 2");
        assertTrue(hook.roots(expectedRoot), "Root is not saved 2");
        assertEq(hook.getPath(poolId, 1, 1)[LEVELS], expectedRoot, "Wrong calculated root 2");

        // instead of checking the balances we check k = x*y, due to a price change
        assertEq(_getK(user2, userBalanceBefore0, userBalanceBefore1), LIQUIDITY_DELTA_SQUARE, "Wrong user2 K");
        assertEq(
            _getK(address(manager), managerBalanceBefore0, managerBalanceBefore1),
            LIQUIDITY_DELTA_SQUARE,
            "Wrong manager K 2"
        );

        // check liquidities
        assertEq(manager.getLiquidity(poolId), 2 * uint256(LIQUIDITY_DELTA), "Wrong manager liquidity 2");
        (liquidity,,) = manager.getPositionInfo(poolId, user1, MIN_TICK, MAX_TICK, SALT);
        assertEq(liquidity, 0, "Wrong user1 liquidity 2");
        (liquidity,,) = manager.getPositionInfo(poolId, user2, MIN_TICK, MAX_TICK, SALT);
        assertEq(liquidity, 0, "Wrong user2 liquidity 2");
        (liquidity,,) = manager.getPositionInfo(poolId, address(entry), MIN_TICK, MAX_TICK, SALT);
        assertEq(liquidity, 2 * uint256(LIQUIDITY_DELTA), "Wrong entry liquidity 2");
    }

    function test_deposit_after_swaps() public {
        vm.startPrank(user1);
        bytes32 commitment = _getCommitment("user1 nullifier", "user1 secret");
        entry.deposit(currency0, currency1, commitment);

        _swaps();

        vm.startPrank(user2);
        uint256 userBalanceBefore0 = token0.balanceOf(user2);
        uint256 userBalanceBefore1 = token1.balanceOf(user2);
        uint256 managerBalanceBefore0 = token0.balanceOf(address(manager));
        uint256 managerBalanceBefore1 = token1.balanceOf(address(manager));
        commitment = _getCommitment("user2 nullifier", "user2 secret");
        entry.deposit(currency0, currency1, commitment);

        // instead of checking the balances we check k = x*y, due to a price change
        assertApproxEqRel(
            _getK(user2, userBalanceBefore0, userBalanceBefore1), LIQUIDITY_DELTA_SQUARE, 1, "Wrong user2 K"
        );
        assertApproxEqRel(
            _getK(address(manager), managerBalanceBefore0, managerBalanceBefore1),
            LIQUIDITY_DELTA_SQUARE,
            1,
            "Wrong manager K"
        );

        assertEq(manager.getLiquidity(poolId), 2 * uint256(LIQUIDITY_DELTA), "Wrong manager liquidity");
        (uint128 liquidity,,) = manager.getPositionInfo(poolId, address(entry), MIN_TICK, MAX_TICK, SALT);
        assertEq(liquidity, 2 * uint256(LIQUIDITY_DELTA), "Wrong entry liquidity");
    }

    function test_fuzz_deposit(address depositor, string calldata nullifier, string calldata secret) public {
        vm.skip(false);
        vm.assume(depositor != address(entry) || depositor != address(manager));
        vm.startPrank(depositor);
        _mintAndApprove(depositor);

        uint256 userBalanceBefore0 = token0.balanceOf(depositor);
        uint256 userBalanceBefore1 = token1.balanceOf(depositor);
        uint256 managerBalanceBefore0 = token0.balanceOf(address(manager));
        uint256 managerBalanceBefore1 = token1.balanceOf(address(manager));
        bytes32 commitment = _getCommitment(nullifier, secret);

        vm.expectEmit(true, true, true, false);
        emit TornadoHook.Deposit(commitment, 1, 0);
        entry.deposit(currency0, currency1, commitment);

        // check the contract state
        assertEq(hook.currentTreeNumber(poolId), 1, "Wrong tree number");
        assertEq(hook.nextLeafIndex(poolId), 1, "Wrong leaf index");
        assertTrue(hook.commitments(commitment), "Commitment is not saved");

        // instead of checking the balances we check k = x*y, due to a price change
        assertEq(_getK(depositor, userBalanceBefore0, userBalanceBefore1), LIQUIDITY_DELTA_SQUARE, "Wrong depositor K");
        assertEq(
            _getK(address(manager), managerBalanceBefore0, managerBalanceBefore1),
            LIQUIDITY_DELTA_SQUARE,
            "Wrong manager K"
        );

        // check liquidities
        assertEq(manager.getLiquidity(poolId), uint256(LIQUIDITY_DELTA), "Pool is empty");
        (uint128 liquidity,,) = manager.getPositionInfo(poolId, depositor, MIN_TICK, MAX_TICK, SALT);
        assertEq(liquidity, 0, "Wrong depositor liquidity");
        (liquidity,,) = manager.getPositionInfo(poolId, address(entry), MIN_TICK, MAX_TICK, SALT);
        assertEq(liquidity, uint256(LIQUIDITY_DELTA), "Wrong entry liquidity");
    }

    function test_withdraw() public {
        vm.startPrank(user1);
        bytes32 commitment = _getCommitment("user1 nullifier", "user1 secret");
        entry.deposit(currency0, currency1, commitment);

        vm.startPrank(user2);
        commitment = _getCommitment("user2 nullifier", "user2 secret");
        entry.deposit(currency0, currency1, commitment);

        vm.startPrank(user3);
        uint256 userBalanceBefore0 = token0.balanceOf(user1);
        uint256 userBalanceBefore1 = token1.balanceOf(user1);
        uint256 recipientBalanceBefore0 = token0.balanceOf(user3);
        uint256 recipientBalanceBefore1 = token1.balanceOf(user3);
        uint256 managerBalanceBefore0 = token0.balanceOf(address(manager));
        uint256 managerBalanceBefore1 = token1.balanceOf(address(manager));
        bytes memory proof = _getCircomProof();
        bytes32 nullifierHash = 0x10696e46ec40cd307d7e330f3904b52be0e5baf586d7400f7c88f9ef6261ea79;
        bytes32 root = 0x05dd7f25fce2c0e54c73c13733622782c4ebb519d2d9b097fd97258349fcd7e0;
        WithdrawalData memory withdrawalData =
            WithdrawalData({isCircom: true, nullifierHash: nullifierHash, root: root, recipient: user3, proof: proof});

        assertFalse(hook.nullifierHashes(nullifierHash), "Nullifier should not exist 1");

        vm.expectEmit(true, true, false, false);
        emit TornadoHook.Withdrawal(user3, nullifierHash);
        entry.withdraw(currency0, currency1, withdrawalData);

        assertTrue(hook.nullifierHashes(nullifierHash), "Nullifier is not saved 1");

        assertEq(userBalanceBefore0, token0.balanceOf(user1), "Wrong balance0 after user1");
        assertEq(userBalanceBefore1, token1.balanceOf(user1), "Wrong balance1 after user1");
        // instead of checking the balances we check k = x*y, due to a price change
        assertApproxEqRel(
            _getK(user3, recipientBalanceBefore0, recipientBalanceBefore1), LIQUIDITY_DELTA_SQUARE, 1, "Wrong user3 K 1"
        );
        assertApproxEqRel(
            _getK(address(manager), managerBalanceBefore0, managerBalanceBefore1),
            LIQUIDITY_DELTA_SQUARE,
            1,
            "Wrong manager K 1"
        );

        // check liquidities
        assertEq(manager.getLiquidity(poolId), uint256(LIQUIDITY_DELTA), "Wrong manager liquidity 1");
        (uint128 liquidity,,) = manager.getPositionInfo(poolId, address(entry), MIN_TICK, MAX_TICK, SALT);
        assertEq(liquidity, uint256(LIQUIDITY_DELTA), "Wrong entry liquidity 1");

        userBalanceBefore0 = token0.balanceOf(user2);
        userBalanceBefore1 = token1.balanceOf(user2);
        recipientBalanceBefore0 = token0.balanceOf(user3);
        recipientBalanceBefore1 = token1.balanceOf(user3);
        managerBalanceBefore0 = token0.balanceOf(address(manager));
        managerBalanceBefore1 = token1.balanceOf(address(manager));
        proof = _getNoirProof();
        nullifierHash = 0x06872edb69176d4178b5c12fe3a58370af367675f811a847d7c22f1275a8e584;
        withdrawalData =
            WithdrawalData({isCircom: false, nullifierHash: nullifierHash, root: root, recipient: user3, proof: proof});

        assertFalse(hook.nullifierHashes(nullifierHash), "Nullifier should not exist 2");

        vm.expectEmit(true, true, false, false);
        emit TornadoHook.Withdrawal(user3, nullifierHash);
        entry.withdraw(currency0, currency1, withdrawalData);

        assertTrue(hook.nullifierHashes(nullifierHash), "Nullifier is not saved 2");

        assertEq(userBalanceBefore0, token0.balanceOf(user2), "Wrong balance0 after user2");
        assertEq(userBalanceBefore1, token1.balanceOf(user2), "Wrong balance1 after user2");
        // instead of checking the balances we check k = x*y, due to a price change
        assertApproxEqRel(
            _getK(user3, recipientBalanceBefore0, recipientBalanceBefore1), LIQUIDITY_DELTA_SQUARE, 1, "Wrong user3 K 2"
        );
        assertApproxEqRel(
            _getK(address(manager), managerBalanceBefore0, managerBalanceBefore1),
            LIQUIDITY_DELTA_SQUARE,
            1,
            "Wrong manager K 2"
        );

        // check liquidities
        assertEq(manager.getLiquidity(poolId), 0, "Wrong manager liquidity 2");
        (liquidity,,) = manager.getPositionInfo(poolId, address(entry), MIN_TICK, MAX_TICK, SALT);
        assertEq(liquidity, 0, "Wrong entry liquidity 2");
    }

    function test_withdraw_after_swaps() public {
        vm.startPrank(user1);
        bytes32 commitment = _getCommitment("user1 nullifier", "user1 secret");
        entry.deposit(currency0, currency1, commitment);

        vm.startPrank(user2);
        commitment = _getCommitment("user2 nullifier", "user2 secret");
        entry.deposit(currency0, currency1, commitment);

        _swaps();

        vm.startPrank(user3);
        uint256 userBalanceBefore0 = token0.balanceOf(user1);
        uint256 userBalanceBefore1 = token1.balanceOf(user1);
        uint256 recipientBalanceBefore0 = token0.balanceOf(user3);
        uint256 recipientBalanceBefore1 = token1.balanceOf(user3);
        uint256 managerBalanceBefore0 = token0.balanceOf(address(manager));
        uint256 managerBalanceBefore1 = token1.balanceOf(address(manager));
        bytes memory proof = _getCircomProof();
        bytes32 nullifierHash = 0x10696e46ec40cd307d7e330f3904b52be0e5baf586d7400f7c88f9ef6261ea79;
        bytes32 root = 0x05dd7f25fce2c0e54c73c13733622782c4ebb519d2d9b097fd97258349fcd7e0;
        WithdrawalData memory withdrawalData =
            WithdrawalData({isCircom: true, nullifierHash: nullifierHash, root: root, recipient: user3, proof: proof});

        assertFalse(hook.nullifierHashes(nullifierHash), "Nullifier should not exist 1");

        vm.expectEmit(true, true, false, false);
        emit TornadoHook.Withdrawal(user3, nullifierHash);
        entry.withdraw(currency0, currency1, withdrawalData);

        assertTrue(hook.nullifierHashes(nullifierHash), "Nullifier is not saved 1");

        assertEq(userBalanceBefore0, token0.balanceOf(user1), "Wrong balance0 after user1");
        assertEq(userBalanceBefore1, token1.balanceOf(user1), "Wrong balance1 after user1");
        // 0.2% difference due to swaps
        assertApproxEqRel(
            _getK(user3, recipientBalanceBefore0, recipientBalanceBefore1),
            LIQUIDITY_DELTA_SQUARE,
            0.002 ether,
            "Wrong user3 K 1"
        );
        assertApproxEqRel(
            _getK(address(manager), managerBalanceBefore0, managerBalanceBefore1),
            LIQUIDITY_DELTA_SQUARE,
            0.002 ether,
            "Wrong manager K 1"
        );

        assertEq(manager.getLiquidity(poolId), uint256(LIQUIDITY_DELTA), "Wrong manager liquidity 1");
        (uint128 liquidity,,) = manager.getPositionInfo(poolId, address(entry), MIN_TICK, MAX_TICK, SALT);
        assertEq(liquidity, uint256(LIQUIDITY_DELTA), "Wrong entry liquidity 1");

        userBalanceBefore0 = token0.balanceOf(user2);
        userBalanceBefore1 = token1.balanceOf(user2);
        recipientBalanceBefore0 = token0.balanceOf(user3);
        recipientBalanceBefore1 = token1.balanceOf(user3);
        managerBalanceBefore0 = token0.balanceOf(address(manager));
        managerBalanceBefore1 = token1.balanceOf(address(manager));
        proof = _getNoirProof();
        nullifierHash = 0x06872edb69176d4178b5c12fe3a58370af367675f811a847d7c22f1275a8e584;
        withdrawalData =
            WithdrawalData({isCircom: false, nullifierHash: nullifierHash, root: root, recipient: user3, proof: proof});

        assertFalse(hook.nullifierHashes(nullifierHash), "Nullifier should not exist 2");

        vm.expectEmit(true, true, false, false);
        emit TornadoHook.Withdrawal(user3, nullifierHash);
        entry.withdraw(currency0, currency1, withdrawalData);

        assertTrue(hook.nullifierHashes(nullifierHash), "Nullifier is not saved 2");

        assertEq(userBalanceBefore0, token0.balanceOf(user2), "Wrong balance0 after user2");
        assertEq(userBalanceBefore1, token1.balanceOf(user2), "Wrong balance1 after user2");
        // 0.2% difference due to swaps
        assertApproxEqRel(
            _getK(user3, recipientBalanceBefore0, recipientBalanceBefore1),
            LIQUIDITY_DELTA_SQUARE,
            0.002 ether,
            "Wrong user3 K 2"
        );
        assertApproxEqRel(
            _getK(address(manager), managerBalanceBefore0, managerBalanceBefore1),
            LIQUIDITY_DELTA_SQUARE,
            0.002 ether,
            "Wrong manager K 2"
        );

        assertEq(manager.getLiquidity(poolId), 0, "Wrong manager liquidity 2");
        (liquidity,,) = manager.getPositionInfo(poolId, address(entry), MIN_TICK, MAX_TICK, SALT);
        assertEq(liquidity, 0, "Wrong entry liquidity 2");
    }

    function test_deposit_swap_withdraw() public {
        vm.startPrank(user1);
        bytes32 commitment = _getCommitment("user1 nullifier", "user1 secret");
        entry.deposit(currency0, currency1, commitment);

        _swaps();

        vm.startPrank(user2);
        commitment = _getCommitment("user2 nullifier", "user2 secret");
        entry.deposit(currency0, currency1, commitment);

        vm.startPrank(user3);
        uint256 userBalanceBefore0 = token0.balanceOf(user1);
        uint256 userBalanceBefore1 = token1.balanceOf(user1);
        uint256 recipientBalanceBefore0 = token0.balanceOf(user3);
        uint256 recipientBalanceBefore1 = token1.balanceOf(user3);
        uint256 managerBalanceBefore0 = token0.balanceOf(address(manager));
        uint256 managerBalanceBefore1 = token1.balanceOf(address(manager));
        bytes memory proof = _getCircomProof();
        bytes32 nullifierHash = 0x10696e46ec40cd307d7e330f3904b52be0e5baf586d7400f7c88f9ef6261ea79;
        bytes32 root = 0x05dd7f25fce2c0e54c73c13733622782c4ebb519d2d9b097fd97258349fcd7e0;
        WithdrawalData memory withdrawalData =
            WithdrawalData({isCircom: true, nullifierHash: nullifierHash, root: root, recipient: user3, proof: proof});

        assertFalse(hook.nullifierHashes(nullifierHash), "Nullifier should not exist 1");

        vm.expectEmit(true, true, false, false);
        emit TornadoHook.Withdrawal(user3, nullifierHash);
        entry.withdraw(currency0, currency1, withdrawalData);

        assertTrue(hook.nullifierHashes(nullifierHash), "Nullifier is not saved 1");

        assertEq(userBalanceBefore0, token0.balanceOf(user1), "Wrong balance0 after user1");
        assertEq(userBalanceBefore1, token1.balanceOf(user1), "Wrong balance1 after user1");
        // 0.2% difference due to swaps
        assertApproxEqRel(
            _getK(user3, recipientBalanceBefore0, recipientBalanceBefore1),
            LIQUIDITY_DELTA_SQUARE,
            0.002 ether,
            "Wrong user3 K 1"
        );
        assertApproxEqRel(
            _getK(address(manager), managerBalanceBefore0, managerBalanceBefore1),
            LIQUIDITY_DELTA_SQUARE,
            0.002 ether,
            "Wrong manager K 1"
        );

        assertEq(manager.getLiquidity(poolId), uint256(LIQUIDITY_DELTA), "Wrong manager liquidity 1");
        (uint128 liquidity,,) = manager.getPositionInfo(poolId, address(entry), MIN_TICK, MAX_TICK, SALT);
        assertEq(liquidity, uint256(LIQUIDITY_DELTA), "Wrong entry liquidity 1");

        userBalanceBefore0 = token0.balanceOf(user2);
        userBalanceBefore1 = token1.balanceOf(user2);
        recipientBalanceBefore0 = token0.balanceOf(user3);
        recipientBalanceBefore1 = token1.balanceOf(user3);
        managerBalanceBefore0 = token0.balanceOf(address(manager));
        managerBalanceBefore1 = token1.balanceOf(address(manager));
        proof = _getNoirProof();
        nullifierHash = 0x06872edb69176d4178b5c12fe3a58370af367675f811a847d7c22f1275a8e584;
        withdrawalData =
            WithdrawalData({isCircom: false, nullifierHash: nullifierHash, root: root, recipient: user3, proof: proof});

        assertFalse(hook.nullifierHashes(nullifierHash), "Nullifier should not exist 2");
        vm.expectEmit(true, true, false, false);
        emit TornadoHook.Withdrawal(user3, nullifierHash);
        entry.withdraw(currency0, currency1, withdrawalData);

        assertTrue(hook.nullifierHashes(nullifierHash), "Nullifier is not saved 2");

        assertEq(userBalanceBefore0, token0.balanceOf(user2), "Wrong balance0 after user2");
        assertEq(userBalanceBefore1, token1.balanceOf(user2), "Wrong balance1 after user2");
        // 0.2% difference due to swaps
        assertApproxEqRel(
            _getK(user3, recipientBalanceBefore0, recipientBalanceBefore1),
            LIQUIDITY_DELTA_SQUARE,
            0.002 ether,
            "Wrong user3 K 2"
        );
        assertApproxEqRel(
            _getK(address(manager), managerBalanceBefore0, managerBalanceBefore1),
            LIQUIDITY_DELTA_SQUARE,
            0.002 ether,
            "Wrong manager K 2"
        );

        assertEq(manager.getLiquidity(poolId), 0, "Wrong manager liquidity 2");
        (liquidity,,) = manager.getPositionInfo(poolId, address(entry), MIN_TICK, MAX_TICK, SALT);
        assertEq(liquidity, 0, "Wrong entry liquidity 2");
    }

    function test_revert_deposit() public {
        vm.startPrank(user1);
        token0.approve(address(modifyLiquidityRouter), type(uint256).max);
        token1.approve(address(modifyLiquidityRouter), type(uint256).max);

        PoolKey memory key_ =
            PoolKey({currency0: currency0, currency1: currency1, fee: FEE, tickSpacing: TICK_SPACING, hooks: hook});
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: MIN_TICK,
            tickUpper: MAX_TICK,
            liquidityDelta: LIQUIDITY_DELTA,
            salt: SALT
        });
        bytes memory hookData = abi.encode(_getCommitment("user1 nullifier", "user1 secret"));
        // should work properly
        modifyLiquidityRouter.modifyLiquidity(key_, params, hookData);

        // revert with address(0)
        key_.currency0 = CurrencyLibrary.ADDRESS_ZERO;
        initPool(key_.currency0, key_.currency1, hook, key_.fee, SQRT_PRICE_1_1);
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                BaseHook.beforeAddLiquidity.selector,
                abi.encodeWithSelector(TornadoHook.TH_OnlyERC20.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        modifyLiquidityRouter.modifyLiquidity(key_, params, hookData);

        // revert with a wrong lower tick
        key_.currency0 = currency0;
        params.tickLower = MIN_TICK + 60;
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                BaseHook.beforeAddLiquidity.selector,
                abi.encodeWithSelector(TornadoHook.TH_WrongTick.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        modifyLiquidityRouter.modifyLiquidity(key_, params, hookData);

        // revert with a wrong upper tick
        params.tickLower = MIN_TICK;
        params.tickUpper = MAX_TICK - 60;
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                BaseHook.beforeAddLiquidity.selector,
                abi.encodeWithSelector(TornadoHook.TH_WrongTick.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        modifyLiquidityRouter.modifyLiquidity(key_, params, hookData);

        // revert with a wrong liquidity delta
        params.tickUpper = MAX_TICK;
        params.liquidityDelta = 2 * LIQUIDITY_DELTA;
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                BaseHook.beforeAddLiquidity.selector,
                abi.encodeWithSelector(TornadoHook.TH_WrongLiquidityDelta.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        modifyLiquidityRouter.modifyLiquidity(key_, params, hookData);

        // revert with a wrong salt
        params.liquidityDelta = LIQUIDITY_DELTA;
        params.salt = keccak256("salt");
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                BaseHook.beforeAddLiquidity.selector,
                abi.encodeWithSelector(TornadoHook.TH_WrongSalt.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        modifyLiquidityRouter.modifyLiquidity(key_, params, hookData);

        // revert with a wrong commitment
        params.salt = SALT;
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                BaseHook.afterAddLiquidity.selector,
                abi.encodeWithSelector(TornadoHook.TH_CommitmentExists.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        modifyLiquidityRouter.modifyLiquidity(key_, params, hookData);
    }

    function test_revert_withdraw_circom() public {
        vm.startPrank(user1);
        entry.deposit(currency0, currency1, _getCommitment("user1 nullifier", "user1 secret"));
        entry.deposit(currency0, currency1, _getCommitment("user2 nullifier", "user2 secret"));

        vm.startPrank(user3);
        bytes32 nullifierHash = 0x10696e46ec40cd307d7e330f3904b52be0e5baf586d7400f7c88f9ef6261ea79;
        // revert with a wrong root
        WithdrawalData memory withdrawalData = WithdrawalData({
            isCircom: true,
            nullifierHash: nullifierHash,
            root: bytes32(0),
            recipient: user3,
            proof: _getCircomProof()
        });
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                BaseHook.afterRemoveLiquidity.selector,
                abi.encodeWithSelector(TornadoHook.TH_WrongRoot.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        entry.withdraw(currency0, currency1, withdrawalData);

        // revert with a wrong nullifier hash
        withdrawalData.root = 0x05dd7f25fce2c0e54c73c13733622782c4ebb519d2d9b097fd97258349fcd7e0;
        withdrawalData.nullifierHash = _getHash("nullifierHash");
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                BaseHook.afterRemoveLiquidity.selector,
                abi.encodeWithSelector(TornadoHook.TH_InvalidProof.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        entry.withdraw(currency0, currency1, withdrawalData);

        // revert with a wrong recipient
        withdrawalData.nullifierHash = nullifierHash;
        withdrawalData.recipient = user2;
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                BaseHook.afterRemoveLiquidity.selector,
                abi.encodeWithSelector(TornadoHook.TH_InvalidProof.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        entry.withdraw(currency0, currency1, withdrawalData);

        // revert with a bad circom proof
        withdrawalData.recipient = user3;
        withdrawalData.proof = _getBadCircomProof();
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                BaseHook.afterRemoveLiquidity.selector,
                abi.encodeWithSelector(TornadoHook.TH_InvalidProof.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        entry.withdraw(currency0, currency1, withdrawalData);

        // revert with a noir proof
        withdrawalData.proof = _getNoirProof();
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                BaseHook.afterRemoveLiquidity.selector,
                abi.encodeWithSelector(TornadoHook.TH_InvalidProof.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        entry.withdraw(currency0, currency1, withdrawalData);

        // revert with a bad noir proof
        withdrawalData.proof = _getBadNoirProof();
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                BaseHook.afterRemoveLiquidity.selector,
                abi.encodeWithSelector(TornadoHook.TH_InvalidProof.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        entry.withdraw(currency0, currency1, withdrawalData);

        // correct withdraw
        withdrawalData.proof = _getCircomProof();
        entry.withdraw(currency0, currency1, withdrawalData);

        // revert with a wrong nullifier hash
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                BaseHook.afterRemoveLiquidity.selector,
                abi.encodeWithSelector(TornadoHook.TH_NullifierIsSpent.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        entry.withdraw(currency0, currency1, withdrawalData);
    }

    function test_revert_withdraw_noir() public {
        vm.startPrank(user1);
        entry.deposit(currency0, currency1, _getCommitment("user1 nullifier", "user1 secret"));
        entry.deposit(currency0, currency1, _getCommitment("user2 nullifier", "user2 secret"));

        vm.startPrank(user3);
        bytes32 nullifierHash = 0x06872edb69176d4178b5c12fe3a58370af367675f811a847d7c22f1275a8e584;
        // revert with a wrong root
        WithdrawalData memory withdrawalData = WithdrawalData({
            isCircom: false,
            nullifierHash: nullifierHash,
            root: bytes32(0),
            recipient: user3,
            proof: _getNoirProof()
        });
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                BaseHook.afterRemoveLiquidity.selector,
                abi.encodeWithSelector(TornadoHook.TH_WrongRoot.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        entry.withdraw(currency0, currency1, withdrawalData);

        // revert with a wrong nullifier hash
        withdrawalData.root = 0x05dd7f25fce2c0e54c73c13733622782c4ebb519d2d9b097fd97258349fcd7e0;
        withdrawalData.nullifierHash = _getHash("nullifierHash");
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                BaseHook.afterRemoveLiquidity.selector,
                abi.encodeWithSelector(BaseHonkVerifier.SumcheckFailed.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        entry.withdraw(currency0, currency1, withdrawalData);

        // revert with a wrong recipient
        withdrawalData.nullifierHash = nullifierHash;
        withdrawalData.recipient = user2;
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                BaseHook.afterRemoveLiquidity.selector,
                abi.encodeWithSelector(BaseHonkVerifier.SumcheckFailed.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        entry.withdraw(currency0, currency1, withdrawalData);

        // revert with a bad noir proof
        withdrawalData.recipient = user3;
        withdrawalData.proof = _getBadNoirProof();
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                BaseHook.afterRemoveLiquidity.selector,
                abi.encodeWithSelector(BaseHonkVerifier.SumcheckFailed.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        entry.withdraw(currency0, currency1, withdrawalData);

        // revert with a circom proof
        withdrawalData.proof = _getCircomProof();
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                BaseHook.afterRemoveLiquidity.selector,
                abi.encodeWithSelector(BaseHonkVerifier.ProofLengthWrong.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        entry.withdraw(currency0, currency1, withdrawalData);

        // revert with a bad circom proof
        withdrawalData.proof = _getBadCircomProof();
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                BaseHook.afterRemoveLiquidity.selector,
                abi.encodeWithSelector(BaseHonkVerifier.ProofLengthWrong.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        entry.withdraw(currency0, currency1, withdrawalData);

        // correct withdraw
        withdrawalData.proof = _getNoirProof();
        entry.withdraw(currency0, currency1, withdrawalData);

        // revert with a wrong nullifier hash
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                BaseHook.afterRemoveLiquidity.selector,
                abi.encodeWithSelector(TornadoHook.TH_NullifierIsSpent.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        entry.withdraw(currency0, currency1, withdrawalData);
    }

    function _mintAndApprove(address _depositor) internal {
        token0.mint(_depositor, uint256(LIQUIDITY_DELTA));
        token1.mint(_depositor, uint256(LIQUIDITY_DELTA));
        token0.approve(address(entry), type(uint256).max);
        token1.approve(address(entry), type(uint256).max);
    }

    function _swaps() internal {
        address trader = vm.addr(42);
        vm.startPrank(trader);
        token0.mint(trader, 100 ether);
        token1.mint(trader, 100 ether);
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

    function _getCommitment(string memory _nullifier, string memory _secret)
        internal
        view
        returns (bytes32 commitment)
    {
        return HASHER.poseidon([_getHash(_nullifier), _getHash(_secret)]);
    }

    function _getHash(string memory input) internal pure returns (bytes32 res) {
        res = keccak256(bytes(input));
        assembly ("memory-safe") {
            res := mod(res, FIELD_SIZE)
        }
    }

    function _getK(address user, uint256 balance0Before, uint256 balance1Before) internal view returns (uint256) {
        uint256 balance0Now = token0.balanceOf(user);
        uint256 balance1Now = token1.balanceOf(user);

        uint256 x = balance0Before < balance0Now ? balance0Now - balance0Before : balance0Before - balance0Now;
        uint256 y = balance1Before < balance1Now ? balance1Now - balance1Before : balance1Before - balance1Now;
        return x * y;
    }

    function _getCircomProof() internal pure returns (bytes memory) {
        return abi.encode(
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
    }

    function _getNoirProof() internal view returns (bytes memory) {
        return abi.decode(
            vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), "/test/proofs/noir_proof_user2.json"))), (Data)
        ).data;
    }

    function _getBadCircomProof() internal pure returns (bytes memory) {
        return abi.encode(
            [
                11248212746627502792784592779753519429641806161153775494417471465158144667688,
                10157933768447643025042821367718651361361564712984337320693169079449058102469
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
    }

    function _getBadNoirProof() internal view returns (bytes memory) {
        return abi.decode(
            vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), "/test/proofs/bad_noir_proof_user2.json"))), (Data)
        ).data;
    }
}
