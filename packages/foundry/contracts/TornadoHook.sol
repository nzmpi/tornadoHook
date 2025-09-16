//SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./Constants.sol";
import {IHasher} from "./IHasher.sol";
import {Groth16Verifier as CircomVerifier} from "./verifiers/CircomVerifier.sol";
import {HonkVerifier as NoirVerifier} from "./verifiers/NoirVerifier.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {BalanceDelta, toBalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";

struct WithdrawalData {
    bool isCircom;
    bytes32 nullifierHash;
    bytes32 root;
    address recipient;
    bytes proof;
}

/**
 * @title TornadoHook
 * @notice A Tornado Cash implementation as a hook
 * @author https://github.com/nzmpi
 */
contract TornadoHook is BaseHook {
    using StateLibrary for IPoolManager;

    uint256 constant BASE_FEE = 10000;
    IHasher immutable HASHER;
    CircomVerifier immutable CIRCOM_VERIFIER;
    NoirVerifier immutable NOIR_VERIFIER;

    mapping(PoolId => mapping(uint256 level => bytes32)) filledSubtrees;
    mapping(bytes32 key => bytes32[LEVELS + 1]) paths;
    mapping(bytes32 commitment => bool) public commitments;
    mapping(bytes32 nullifierHash => bool) public nullifierHashes;
    mapping(bytes32 root => bool) public roots;
    mapping(PoolId => uint256) public currentTreeNumber;
    mapping(PoolId => uint256) public nextLeafIndex;

    error TH_CommitmentExists();
    error TH_InvalidProof();
    error TH_NullifierIsSpent();
    error TH_OnlyERC20();
    error TH_WrongFee();
    error TH_WrongLevel(uint256);
    error TH_WrongLiquidityDelta();
    error TH_WrongRoot();
    error TH_WrongSalt();
    error TH_WrongTick();
    error TH_WrongTickSpacing();

    event Deposit(bytes32 indexed commitment, uint256 indexed tree, uint256 indexed leafIndex);
    event Withdrawal(address indexed to, bytes32 indexed nullifierHash);

    constructor(IPoolManager _manager, IHasher _hasher, CircomVerifier _circomVerifier, NoirVerifier _noirVerifier)
        payable
        BaseHook(_manager)
    {
        HASHER = _hasher;
        CIRCOM_VERIFIER = _circomVerifier;
        NOIR_VERIFIER = _noirVerifier;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            beforeRemoveLiquidity: false,
            afterAddLiquidity: true,
            afterRemoveLiquidity: true,
            beforeSwap: false,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: true,
            afterRemoveLiquidityReturnDelta: true
        });
    }

    /**
     * Get a created path for a leaf
     * @notice not save, reveals the commitment position
     * @param poolId - pool id of the pool
     * @param tree - tree number
     * @param index - index of the leaf in a tree
     * @return path - LEVELS amount of sibling nodes + the corresponding root as a last element
     */
    function getPath(PoolId poolId, uint256 tree, uint256 index) external view returns (bytes32[LEVELS + 1] memory) {
        return paths[_getKey(poolId, tree, index)];
    }

    /**
     * @notice Only certain poolKey and params are allowed
     */
    function _beforeAddLiquidity(
        address,
        PoolKey calldata poolKey,
        ModifyLiquidityParams calldata params,
        bytes calldata
    ) internal override returns (bytes4) {
        _checkPoolKey(poolKey);
        _checkParams(params);
        PoolId poolId = poolKey.toId();
        // create a tree if there is no liquidity
        if (poolManager.getLiquidity(poolId) == 0) {
            _newTreeState(poolId);
        }
        return this.beforeAddLiquidity.selector;
    }

    /**
     * @notice Distributes fees to the pool and inserts the commitment to the tree
     */
    function _afterAddLiquidity(
        address,
        PoolKey calldata poolKey,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta feeDelta,
        bytes calldata hookData
    ) internal override returns (bytes4, BalanceDelta) {
        // donate all generated fees to the pool
        poolManager.donate(poolKey, uint128(feeDelta.amount0()), uint128(feeDelta.amount1()), "");

        bytes32 commitment = abi.decode(hookData, (bytes32));
        if (commitments[commitment]) revert TH_CommitmentExists();
        commitments[commitment] = true;

        // insert the commitment to the tree
        PoolId poolId = poolKey.toId();
        (uint256 insertedIndex, uint256 tree) = _insert(poolId, commitment);

        emit Deposit(commitment, tree, insertedIndex);
        return (this.afterAddLiquidity.selector, feeDelta);
    }

    /**
     * @notice Distributes fees to the pool, verifies a proof and sends tokens to the recipient
     */
    function _afterRemoveLiquidity(
        address,
        PoolKey calldata poolKey,
        ModifyLiquidityParams calldata,
        BalanceDelta callerDelta,
        BalanceDelta feeDelta,
        bytes calldata hookData
    ) internal override returns (bytes4, BalanceDelta) {
        uint256 liquidity = poolManager.getLiquidity(poolKey.toId());
        bool isEmpty = liquidity == 0;
        // If the pool is empty, withdraw everything.
        // Otherwise, distribute the fees to the pool minus the recipient's share
        if (!isEmpty) {
            uint256 feesLeft = BASE_FEE - (uint256(LIQUIDITY_DELTA) * BASE_FEE) / (liquidity + uint256(LIQUIDITY_DELTA));
            uint128 feeDelta0 = uint128(uint128(feeDelta.amount0()) * feesLeft / BASE_FEE);
            uint128 feeDelta1 = uint128(uint128(feeDelta.amount1()) * feesLeft / BASE_FEE);

            poolManager.donate(poolKey, feeDelta0, feeDelta1, "");
            feeDelta = toBalanceDelta(int128(feeDelta0), int128(feeDelta1));
        }

        WithdrawalData memory withdrawalData = abi.decode(hookData, (WithdrawalData));
        if (nullifierHashes[withdrawalData.nullifierHash]) revert TH_NullifierIsSpent();
        if (!roots[withdrawalData.root]) revert TH_WrongRoot();

        if (withdrawalData.isCircom) {
            (uint256[2] memory pi_a, uint256[2][2] memory pi_b, uint256[2] memory pi_c) =
                abi.decode(withdrawalData.proof, (uint256[2], uint256[2][2], uint256[2]));
            if (
                !CIRCOM_VERIFIER.verifyProof(
                    pi_a,
                    pi_b,
                    pi_c,
                    [
                        uint256(withdrawalData.root),
                        uint256(withdrawalData.nullifierHash),
                        uint256(uint160(withdrawalData.recipient)),
                        0,
                        0,
                        0
                    ]
                )
            ) revert TH_InvalidProof();
        } else {
            bytes32[] memory publicInputs = new bytes32[](6);
            publicInputs[0] = withdrawalData.root;
            publicInputs[1] = withdrawalData.nullifierHash;
            publicInputs[2] = bytes32(abi.encode(withdrawalData.recipient));
            // @dev Noir verifier reverts if the proof is invalid
            NOIR_VERIFIER.verify(withdrawalData.proof, publicInputs);
        }

        nullifierHashes[withdrawalData.nullifierHash] = true;
        emit Withdrawal(withdrawalData.recipient, withdrawalData.nullifierHash);

        // send the tokens to the recipient
        BalanceDelta toSend = isEmpty ? callerDelta : callerDelta - feeDelta;
        poolManager.take(poolKey.currency0, withdrawalData.recipient, uint128(toSend.amount0()));
        poolManager.take(poolKey.currency1, withdrawalData.recipient, uint128(toSend.amount1()));

        return (this.afterRemoveLiquidity.selector, callerDelta);
    }

    /**
     * @notice Verifies the pool key
     */
    function _checkPoolKey(PoolKey calldata _poolKey) internal pure {
        if (_poolKey.currency0.isAddressZero() || _poolKey.currency1.isAddressZero()) revert TH_OnlyERC20();
        if (_poolKey.fee != FEE) revert TH_WrongFee();
        if (_poolKey.tickSpacing != TICK_SPACING) revert TH_WrongTickSpacing();
    }

    /**
     * @notice Verifies the params
     */
    function _checkParams(ModifyLiquidityParams calldata _params) internal pure {
        if (_params.tickLower != MIN_TICK || _params.tickUpper != MAX_TICK) revert TH_WrongTick();
        if (
            _params.liquidityDelta != LIQUIDITY_DELTA && _params.liquidityDelta != -LIQUIDITY_DELTA
                && _params.liquidityDelta != 0
        ) {
            revert TH_WrongLiquidityDelta();
        }
        if (_params.salt != SALT) revert TH_WrongSalt();
    }

    /**
     * @notice Inserts a commitment into the tree
     */
    function _insert(PoolId _poolId, bytes32 _leaf) internal returns (uint256 tree, uint256 index) {
        uint256 nextIndex = nextLeafIndex[_poolId];
        // if the tree is full, create a new one
        if (nextIndex == (1 << LEVELS)) {
            _newTreeState(_poolId);
            nextIndex = 0;
        }

        index = nextIndex;
        tree = currentTreeNumber[_poolId];
        bytes32 key = _getKey(_poolId, tree, index);
        bytes32 left;
        bytes32 right;
        for (uint256 i; i < LEVELS; ++i) {
            if (nextIndex % 2 == 0) {
                left = _leaf;
                right = _zeros(i);
                filledSubtrees[_poolId][i] = _leaf;
                paths[key][i] = right;
            } else {
                left = filledSubtrees[_poolId][i];
                right = _leaf;
                paths[key][i] = left;
            }
            _leaf = HASHER.poseidon([left, right]);
            nextIndex /= 2;
        }

        paths[key][LEVELS] = _leaf;
        roots[_leaf] = true;
        nextLeafIndex[_poolId] = index + 1;
    }

    /**
     * @notice Creates a new tree
     */
    function _newTreeState(PoolId _poolId) internal {
        for (uint256 i; i < LEVELS; ++i) {
            filledSubtrees[_poolId][i] = _zeros(i);
        }

        delete nextLeafIndex[_poolId];
        ++currentTreeNumber[_poolId];
    }

    function _getKey(PoolId _poolId, uint256 _tree, uint256 _index) internal pure returns (bytes32) {
        return keccak256(abi.encode(_poolId, _tree, _index));
    }

    function _zeros(uint256 i) internal pure returns (bytes32) {
        if (i < 10) {
            if (i < 5) {
                if (i < 3) {
                    if (i == 0) return ZERO_VALUE;
                    else if (i == 1) return 0x13e37f2d6cb86c78ccc1788607c2b199788c6bb0a615a21f2e7a8e88384222f8;
                    else return 0x217126fa352c326896e8c2803eec8fd63ad50cf65edfef27a41a9e32dc622765;
                } else {
                    if (i == 3) return 0x0e28a61a9b3e91007d5a9e3ada18e1b24d6d230c618388ee5df34cacd7397eee;
                    else return 0x27953447a6979839536badc5425ed15fadb0e292e9bc36f92f0aa5cfa5013587;
                }
            } else if (i < 8) {
                if (i == 5) return 0x194191edbfb91d10f6a7afd315f33095410c7801c47175c2df6dc2cce0e3affc;
                else if (i == 6) return 0x1733dece17d71190516dbaf1927936fa643dc7079fc0cc731de9d6845a47741f;
                else return 0x267855a7dc75db39d81d17f95d0a7aa572bf5ae19f4db0e84221d2b2ef999219;
            } else {
                if (i == 8) return 0x1184e11836b4c36ad8238a340ecc0985eeba665327e33e9b0e3641027c27620d;
                else return 0x0702ab83a135d7f55350ab1bfaa90babd8fc1d2b3e6a7215381a7b2213d6c5ce;
            }
        } else {
            if (i < 15) {
                if (i < 13) {
                    if (i == 10) return 0x2eecc0de814cfd8c57ce882babb2e30d1da56621aef7a47f3291cffeaec26ad7;
                    else if (i == 11) return 0x280bc02145c155d5833585b6c7b08501055157dd30ce005319621dc462d33b47;
                    else return 0x045132221d1fa0a7f4aed8acd2cbec1e2189b7732ccb2ec272b9c60f0d5afc5b;
                } else {
                    if (i == 13) return 0x27f427ccbf58a44b1270abbe4eda6ba53bd6ac4d88cf1e00a13c4371ce71d366;
                    else return 0x1617eaae5064f26e8f8a6493ae92bfded7fde71b65df1ca6d5dcec0df70b2cef;
                }
            } else {
                if (i < 18) {
                    if (i == 15) return 0x20c6b400d0ea1b15435703c31c31ee63ad7ba5c8da66cec2796feacea575abca;
                    else if (i == 16) return 0x09589ddb438723f53a8e57bdada7c5f8ed67e8fece3889a73618732965645eec;
                    else return 0x0064b6a738a5ff537db7b220f3394f0ecbd35bfd355c5425dc1166bf3236079b;
                } else {
                    if (i == 18) return 0x095de56281b1d5055e897c3574ff790d5ee81dbc5df784ad2d67795e557c9e9f;
                    else if (i == 19) return 0x11cf2e2887aa21963a6ec14289183efe4d4c60f14ecd3d6fe0beebdf855a9b63;
                    else revert TH_WrongLevel(i);
                }
            }
        }
    }
}
