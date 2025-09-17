import { GenericContractsDeclaration } from "~~/utils/scaffold-eth/contract";

/**
 * @example
 * const externalContracts = {
 *   1: {
 *     DAI: {
 *       address: "0x...",
 *       abi: [...],
 *     },
 *   },
 * } as const;
 */
const externalContracts = {
    31337: {
        Token0: {
            address: "0x0c8e79f3534b00d9a3d4a856b665bf4ebc22f2ba",
            abi: [
                {
                type: "constructor",
                inputs: [
                    {
                    name: "_name",
                    type: "string",
                    internalType: "string",
                    },
                    {
                    name: "_symbol",
                    type: "string",
                    internalType: "string",
                    },
                    {
                    name: "_decimals",
                    type: "uint8",
                    internalType: "uint8",
                    },
                ],
                stateMutability: "nonpayable",
                },
                {
                type: "function",
                name: "DOMAIN_SEPARATOR",
                inputs: [],
                outputs: [
                    {
                    name: "",
                    type: "bytes32",
                    internalType: "bytes32",
                    },
                ],
                stateMutability: "view",
                },
                {
                type: "function",
                name: "allowance",
                inputs: [
                    {
                    name: "",
                    type: "address",
                    internalType: "address",
                    },
                    {
                    name: "",
                    type: "address",
                    internalType: "address",
                    },
                ],
                outputs: [
                    {
                    name: "",
                    type: "uint256",
                    internalType: "uint256",
                    },
                ],
                stateMutability: "view",
                },
                {
                type: "function",
                name: "approve",
                inputs: [
                    {
                    name: "spender",
                    type: "address",
                    internalType: "address",
                    },
                    {
                    name: "amount",
                    type: "uint256",
                    internalType: "uint256",
                    },
                ],
                outputs: [
                    {
                    name: "",
                    type: "bool",
                    internalType: "bool",
                    },
                ],
                stateMutability: "nonpayable",
                },
                {
                type: "function",
                name: "balanceOf",
                inputs: [
                    {
                    name: "",
                    type: "address",
                    internalType: "address",
                    },
                ],
                outputs: [
                    {
                    name: "",
                    type: "uint256",
                    internalType: "uint256",
                    },
                ],
                stateMutability: "view",
                },
                {
                type: "function",
                name: "burn",
                inputs: [
                    {
                    name: "from",
                    type: "address",
                    internalType: "address",
                    },
                    {
                    name: "value",
                    type: "uint256",
                    internalType: "uint256",
                    },
                ],
                outputs: [],
                stateMutability: "nonpayable",
                },
                {
                type: "function",
                name: "decimals",
                inputs: [],
                outputs: [
                    {
                    name: "",
                    type: "uint8",
                    internalType: "uint8",
                    },
                ],
                stateMutability: "view",
                },
                {
                type: "function",
                name: "mint",
                inputs: [
                    {
                    name: "to",
                    type: "address",
                    internalType: "address",
                    },
                    {
                    name: "value",
                    type: "uint256",
                    internalType: "uint256",
                    },
                ],
                outputs: [],
                stateMutability: "nonpayable",
                },
                {
                type: "function",
                name: "name",
                inputs: [],
                outputs: [
                    {
                    name: "",
                    type: "string",
                    internalType: "string",
                    },
                ],
                stateMutability: "view",
                },
                {
                type: "function",
                name: "nonces",
                inputs: [
                    {
                    name: "",
                    type: "address",
                    internalType: "address",
                    },
                ],
                outputs: [
                    {
                    name: "",
                    type: "uint256",
                    internalType: "uint256",
                    },
                ],
                stateMutability: "view",
                },
                {
                type: "function",
                name: "permit",
                inputs: [
                    {
                    name: "owner",
                    type: "address",
                    internalType: "address",
                    },
                    {
                    name: "spender",
                    type: "address",
                    internalType: "address",
                    },
                    {
                    name: "value",
                    type: "uint256",
                    internalType: "uint256",
                    },
                    {
                    name: "deadline",
                    type: "uint256",
                    internalType: "uint256",
                    },
                    {
                    name: "v",
                    type: "uint8",
                    internalType: "uint8",
                    },
                    {
                    name: "r",
                    type: "bytes32",
                    internalType: "bytes32",
                    },
                    {
                    name: "s",
                    type: "bytes32",
                    internalType: "bytes32",
                    },
                ],
                outputs: [],
                stateMutability: "nonpayable",
                },
                {
                type: "function",
                name: "symbol",
                inputs: [],
                outputs: [
                    {
                    name: "",
                    type: "string",
                    internalType: "string",
                    },
                ],
                stateMutability: "view",
                },
                {
                type: "function",
                name: "totalSupply",
                inputs: [],
                outputs: [
                    {
                    name: "",
                    type: "uint256",
                    internalType: "uint256",
                    },
                ],
                stateMutability: "view",
                },
                {
                type: "function",
                name: "transfer",
                inputs: [
                    {
                    name: "to",
                    type: "address",
                    internalType: "address",
                    },
                    {
                    name: "amount",
                    type: "uint256",
                    internalType: "uint256",
                    },
                ],
                outputs: [
                    {
                    name: "",
                    type: "bool",
                    internalType: "bool",
                    },
                ],
                stateMutability: "nonpayable",
                },
                {
                type: "function",
                name: "transferFrom",
                inputs: [
                    {
                    name: "from",
                    type: "address",
                    internalType: "address",
                    },
                    {
                    name: "to",
                    type: "address",
                    internalType: "address",
                    },
                    {
                    name: "amount",
                    type: "uint256",
                    internalType: "uint256",
                    },
                ],
                outputs: [
                    {
                    name: "",
                    type: "bool",
                    internalType: "bool",
                    },
                ],
                stateMutability: "nonpayable",
                },
                {
                type: "event",
                name: "Approval",
                inputs: [
                    {
                    name: "owner",
                    type: "address",
                    indexed: true,
                    internalType: "address",
                    },
                    {
                    name: "spender",
                    type: "address",
                    indexed: true,
                    internalType: "address",
                    },
                    {
                    name: "amount",
                    type: "uint256",
                    indexed: false,
                    internalType: "uint256",
                    },
                ],
                anonymous: false,
                },
                {
                type: "event",
                name: "Transfer",
                inputs: [
                    {
                    name: "from",
                    type: "address",
                    indexed: true,
                    internalType: "address",
                    },
                    {
                    name: "to",
                    type: "address",
                    indexed: true,
                    internalType: "address",
                    },
                    {
                    name: "amount",
                    type: "uint256",
                    indexed: false,
                    internalType: "uint256",
                    },
                ],
                anonymous: false,
                },
            ],
        },
        Token1: {
            address: "0xed1db453c3156ff3155a97ad217b3087d5dc5f6e",
            abi: [
                {
                type: "constructor",
                inputs: [
                    {
                    name: "_name",
                    type: "string",
                    internalType: "string",
                    },
                    {
                    name: "_symbol",
                    type: "string",
                    internalType: "string",
                    },
                    {
                    name: "_decimals",
                    type: "uint8",
                    internalType: "uint8",
                    },
                ],
                stateMutability: "nonpayable",
                },
                {
                type: "function",
                name: "DOMAIN_SEPARATOR",
                inputs: [],
                outputs: [
                    {
                    name: "",
                    type: "bytes32",
                    internalType: "bytes32",
                    },
                ],
                stateMutability: "view",
                },
                {
                type: "function",
                name: "allowance",
                inputs: [
                    {
                    name: "",
                    type: "address",
                    internalType: "address",
                    },
                    {
                    name: "",
                    type: "address",
                    internalType: "address",
                    },
                ],
                outputs: [
                    {
                    name: "",
                    type: "uint256",
                    internalType: "uint256",
                    },
                ],
                stateMutability: "view",
                },
                {
                type: "function",
                name: "approve",
                inputs: [
                    {
                    name: "spender",
                    type: "address",
                    internalType: "address",
                    },
                    {
                    name: "amount",
                    type: "uint256",
                    internalType: "uint256",
                    },
                ],
                outputs: [
                    {
                    name: "",
                    type: "bool",
                    internalType: "bool",
                    },
                ],
                stateMutability: "nonpayable",
                },
                {
                type: "function",
                name: "balanceOf",
                inputs: [
                    {
                    name: "",
                    type: "address",
                    internalType: "address",
                    },
                ],
                outputs: [
                    {
                    name: "",
                    type: "uint256",
                    internalType: "uint256",
                    },
                ],
                stateMutability: "view",
                },
                {
                type: "function",
                name: "burn",
                inputs: [
                    {
                    name: "from",
                    type: "address",
                    internalType: "address",
                    },
                    {
                    name: "value",
                    type: "uint256",
                    internalType: "uint256",
                    },
                ],
                outputs: [],
                stateMutability: "nonpayable",
                },
                {
                type: "function",
                name: "decimals",
                inputs: [],
                outputs: [
                    {
                    name: "",
                    type: "uint8",
                    internalType: "uint8",
                    },
                ],
                stateMutability: "view",
                },
                {
                type: "function",
                name: "mint",
                inputs: [
                    {
                    name: "to",
                    type: "address",
                    internalType: "address",
                    },
                    {
                    name: "value",
                    type: "uint256",
                    internalType: "uint256",
                    },
                ],
                outputs: [],
                stateMutability: "nonpayable",
                },
                {
                type: "function",
                name: "name",
                inputs: [],
                outputs: [
                    {
                    name: "",
                    type: "string",
                    internalType: "string",
                    },
                ],
                stateMutability: "view",
                },
                {
                type: "function",
                name: "nonces",
                inputs: [
                    {
                    name: "",
                    type: "address",
                    internalType: "address",
                    },
                ],
                outputs: [
                    {
                    name: "",
                    type: "uint256",
                    internalType: "uint256",
                    },
                ],
                stateMutability: "view",
                },
                {
                type: "function",
                name: "permit",
                inputs: [
                    {
                    name: "owner",
                    type: "address",
                    internalType: "address",
                    },
                    {
                    name: "spender",
                    type: "address",
                    internalType: "address",
                    },
                    {
                    name: "value",
                    type: "uint256",
                    internalType: "uint256",
                    },
                    {
                    name: "deadline",
                    type: "uint256",
                    internalType: "uint256",
                    },
                    {
                    name: "v",
                    type: "uint8",
                    internalType: "uint8",
                    },
                    {
                    name: "r",
                    type: "bytes32",
                    internalType: "bytes32",
                    },
                    {
                    name: "s",
                    type: "bytes32",
                    internalType: "bytes32",
                    },
                ],
                outputs: [],
                stateMutability: "nonpayable",
                },
                {
                type: "function",
                name: "symbol",
                inputs: [],
                outputs: [
                    {
                    name: "",
                    type: "string",
                    internalType: "string",
                    },
                ],
                stateMutability: "view",
                },
                {
                type: "function",
                name: "totalSupply",
                inputs: [],
                outputs: [
                    {
                    name: "",
                    type: "uint256",
                    internalType: "uint256",
                    },
                ],
                stateMutability: "view",
                },
                {
                type: "function",
                name: "transfer",
                inputs: [
                    {
                    name: "to",
                    type: "address",
                    internalType: "address",
                    },
                    {
                    name: "amount",
                    type: "uint256",
                    internalType: "uint256",
                    },
                ],
                outputs: [
                    {
                    name: "",
                    type: "bool",
                    internalType: "bool",
                    },
                ],
                stateMutability: "nonpayable",
                },
                {
                type: "function",
                name: "transferFrom",
                inputs: [
                    {
                    name: "from",
                    type: "address",
                    internalType: "address",
                    },
                    {
                    name: "to",
                    type: "address",
                    internalType: "address",
                    },
                    {
                    name: "amount",
                    type: "uint256",
                    internalType: "uint256",
                    },
                ],
                outputs: [
                    {
                    name: "",
                    type: "bool",
                    internalType: "bool",
                    },
                ],
                stateMutability: "nonpayable",
                },
                {
                type: "event",
                name: "Approval",
                inputs: [
                    {
                    name: "owner",
                    type: "address",
                    indexed: true,
                    internalType: "address",
                    },
                    {
                    name: "spender",
                    type: "address",
                    indexed: true,
                    internalType: "address",
                    },
                    {
                    name: "amount",
                    type: "uint256",
                    indexed: false,
                    internalType: "uint256",
                    },
                ],
                anonymous: false,
                },
                {
                type: "event",
                name: "Transfer",
                inputs: [
                    {
                    name: "from",
                    type: "address",
                    indexed: true,
                    internalType: "address",
                    },
                    {
                    name: "to",
                    type: "address",
                    indexed: true,
                    internalType: "address",
                    },
                    {
                    name: "amount",
                    type: "uint256",
                    indexed: false,
                    internalType: "uint256",
                    },
                ],
                anonymous: false,
                },
            ],
        },
        TornadoHook: {
            address: "0x241D9F66C2B4505A575fC863060891Cb3E5b0D03",
            abi: [
            {
                "type":"constructor","inputs":[{"name":"_manager","type":"address","internalType":"contract IPoolManager"},{"name":"_hasher","type":"address","internalType":"contract IHasher"},{"name":"_circomVerifier","type":"address","internalType":"contract Groth16Verifier"},{"name":"_noirVerifier","type":"address","internalType":"contract HonkVerifier"}],"stateMutability":"payable"},{"type":"function","name":"afterAddLiquidity","inputs":[{"name":"sender","type":"address","internalType":"address"},{"name":"key","type":"tuple","internalType":"struct PoolKey","components":[{"name":"currency0","type":"address","internalType":"Currency"},{"name":"currency1","type":"address","internalType":"Currency"},{"name":"fee","type":"uint24","internalType":"uint24"},{"name":"tickSpacing","type":"int24","internalType":"int24"},{"name":"hooks","type":"address","internalType":"contract IHooks"}]},{"name":"params","type":"tuple","internalType":"struct ModifyLiquidityParams","components":[{"name":"tickLower","type":"int24","internalType":"int24"},{"name":"tickUpper","type":"int24","internalType":"int24"},{"name":"liquidityDelta","type":"int256","internalType":"int256"},{"name":"salt","type":"bytes32","internalType":"bytes32"}]},{"name":"delta","type":"int256","internalType":"BalanceDelta"},{"name":"feesAccrued","type":"int256","internalType":"BalanceDelta"},{"name":"hookData","type":"bytes","internalType":"bytes"}],"outputs":[{"name":"","type":"bytes4","internalType":"bytes4"},{"name":"","type":"int256","internalType":"BalanceDelta"}],"stateMutability":"nonpayable"},{"type":"function","name":"afterDonate","inputs":[{"name":"sender","type":"address","internalType":"address"},{"name":"key","type":"tuple","internalType":"struct PoolKey","components":[{"name":"currency0","type":"address","internalType":"Currency"},{"name":"currency1","type":"address","internalType":"Currency"},{"name":"fee","type":"uint24","internalType":"uint24"},{"name":"tickSpacing","type":"int24","internalType":"int24"},{"name":"hooks","type":"address","internalType":"contract IHooks"}]},{"name":"amount0","type":"uint256","internalType":"uint256"},{"name":"amount1","type":"uint256","internalType":"uint256"},{"name":"hookData","type":"bytes","internalType":"bytes"}],"outputs":[{"name":"","type":"bytes4","internalType":"bytes4"}],"stateMutability":"nonpayable"},{"type":"function","name":"afterInitialize","inputs":[{"name":"sender","type":"address","internalType":"address"},{"name":"key","type":"tuple","internalType":"struct PoolKey","components":[{"name":"currency0","type":"address","internalType":"Currency"},{"name":"currency1","type":"address","internalType":"Currency"},{"name":"fee","type":"uint24","internalType":"uint24"},{"name":"tickSpacing","type":"int24","internalType":"int24"},{"name":"hooks","type":"address","internalType":"contract IHooks"}]},{"name":"sqrtPriceX96","type":"uint160","internalType":"uint160"},{"name":"tick","type":"int24","internalType":"int24"}],"outputs":[{"name":"","type":"bytes4","internalType":"bytes4"}],"stateMutability":"nonpayable"},{"type":"function","name":"afterRemoveLiquidity","inputs":[{"name":"sender","type":"address","internalType":"address"},{"name":"key","type":"tuple","internalType":"struct PoolKey","components":[{"name":"currency0","type":"address","internalType":"Currency"},{"name":"currency1","type":"address","internalType":"Currency"},{"name":"fee","type":"uint24","internalType":"uint24"},{"name":"tickSpacing","type":"int24","internalType":"int24"},{"name":"hooks","type":"address","internalType":"contract IHooks"}]},{"name":"params","type":"tuple","internalType":"struct ModifyLiquidityParams","components":[{"name":"tickLower","type":"int24","internalType":"int24"},{"name":"tickUpper","type":"int24","internalType":"int24"},{"name":"liquidityDelta","type":"int256","internalType":"int256"},{"name":"salt","type":"bytes32","internalType":"bytes32"}]},{"name":"delta","type":"int256","internalType":"BalanceDelta"},{"name":"feesAccrued","type":"int256","internalType":"BalanceDelta"},{"name":"hookData","type":"bytes","internalType":"bytes"}],"outputs":[{"name":"","type":"bytes4","internalType":"bytes4"},{"name":"","type":"int256","internalType":"BalanceDelta"}],"stateMutability":"nonpayable"},{"type":"function","name":"afterSwap","inputs":[{"name":"sender","type":"address","internalType":"address"},{"name":"key","type":"tuple","internalType":"struct PoolKey","components":[{"name":"currency0","type":"address","internalType":"Currency"},{"name":"currency1","type":"address","internalType":"Currency"},{"name":"fee","type":"uint24","internalType":"uint24"},{"name":"tickSpacing","type":"int24","internalType":"int24"},{"name":"hooks","type":"address","internalType":"contract IHooks"}]},{"name":"params","type":"tuple","internalType":"struct SwapParams","components":[{"name":"zeroForOne","type":"bool","internalType":"bool"},{"name":"amountSpecified","type":"int256","internalType":"int256"},{"name":"sqrtPriceLimitX96","type":"uint160","internalType":"uint160"}]},{"name":"delta","type":"int256","internalType":"BalanceDelta"},{"name":"hookData","type":"bytes","internalType":"bytes"}],"outputs":[{"name":"","type":"bytes4","internalType":"bytes4"},{"name":"","type":"int128","internalType":"int128"}],"stateMutability":"nonpayable"},{"type":"function","name":"beforeAddLiquidity","inputs":[{"name":"sender","type":"address","internalType":"address"},{"name":"key","type":"tuple","internalType":"struct PoolKey","components":[{"name":"currency0","type":"address","internalType":"Currency"},{"name":"currency1","type":"address","internalType":"Currency"},{"name":"fee","type":"uint24","internalType":"uint24"},{"name":"tickSpacing","type":"int24","internalType":"int24"},{"name":"hooks","type":"address","internalType":"contract IHooks"}]},{"name":"params","type":"tuple","internalType":"struct ModifyLiquidityParams","components":[{"name":"tickLower","type":"int24","internalType":"int24"},{"name":"tickUpper","type":"int24","internalType":"int24"},{"name":"liquidityDelta","type":"int256","internalType":"int256"},{"name":"salt","type":"bytes32","internalType":"bytes32"}]},{"name":"hookData","type":"bytes","internalType":"bytes"}],"outputs":[{"name":"","type":"bytes4","internalType":"bytes4"}],"stateMutability":"nonpayable"},{"type":"function","name":"beforeDonate","inputs":[{"name":"sender","type":"address","internalType":"address"},{"name":"key","type":"tuple","internalType":"struct PoolKey","components":[{"name":"currency0","type":"address","internalType":"Currency"},{"name":"currency1","type":"address","internalType":"Currency"},{"name":"fee","type":"uint24","internalType":"uint24"},{"name":"tickSpacing","type":"int24","internalType":"int24"},{"name":"hooks","type":"address","internalType":"contract IHooks"}]},{"name":"amount0","type":"uint256","internalType":"uint256"},{"name":"amount1","type":"uint256","internalType":"uint256"},{"name":"hookData","type":"bytes","internalType":"bytes"}],"outputs":[{"name":"","type":"bytes4","internalType":"bytes4"}],"stateMutability":"nonpayable"},{"type":"function","name":"beforeInitialize","inputs":[{"name":"sender","type":"address","internalType":"address"},{"name":"key","type":"tuple","internalType":"struct PoolKey","components":[{"name":"currency0","type":"address","internalType":"Currency"},{"name":"currency1","type":"address","internalType":"Currency"},{"name":"fee","type":"uint24","internalType":"uint24"},{"name":"tickSpacing","type":"int24","internalType":"int24"},{"name":"hooks","type":"address","internalType":"contract IHooks"}]},{"name":"sqrtPriceX96","type":"uint160","internalType":"uint160"}],"outputs":[{"name":"","type":"bytes4","internalType":"bytes4"}],"stateMutability":"nonpayable"},{"type":"function","name":"beforeRemoveLiquidity","inputs":[{"name":"sender","type":"address","internalType":"address"},{"name":"key","type":"tuple","internalType":"struct PoolKey","components":[{"name":"currency0","type":"address","internalType":"Currency"},{"name":"currency1","type":"address","internalType":"Currency"},{"name":"fee","type":"uint24","internalType":"uint24"},{"name":"tickSpacing","type":"int24","internalType":"int24"},{"name":"hooks","type":"address","internalType":"contract IHooks"}]},{"name":"params","type":"tuple","internalType":"struct ModifyLiquidityParams","components":[{"name":"tickLower","type":"int24","internalType":"int24"},{"name":"tickUpper","type":"int24","internalType":"int24"},{"name":"liquidityDelta","type":"int256","internalType":"int256"},{"name":"salt","type":"bytes32","internalType":"bytes32"}]},{"name":"hookData","type":"bytes","internalType":"bytes"}],"outputs":[{"name":"","type":"bytes4","internalType":"bytes4"}],"stateMutability":"nonpayable"},{"type":"function","name":"beforeSwap","inputs":[{"name":"sender","type":"address","internalType":"address"},{"name":"key","type":"tuple","internalType":"struct PoolKey","components":[{"name":"currency0","type":"address","internalType":"Currency"},{"name":"currency1","type":"address","internalType":"Currency"},{"name":"fee","type":"uint24","internalType":"uint24"},{"name":"tickSpacing","type":"int24","internalType":"int24"},{"name":"hooks","type":"address","internalType":"contract IHooks"}]},{"name":"params","type":"tuple","internalType":"struct SwapParams","components":[{"name":"zeroForOne","type":"bool","internalType":"bool"},{"name":"amountSpecified","type":"int256","internalType":"int256"},{"name":"sqrtPriceLimitX96","type":"uint160","internalType":"uint160"}]},{"name":"hookData","type":"bytes","internalType":"bytes"}],"outputs":[{"name":"","type":"bytes4","internalType":"bytes4"},{"name":"","type":"int256","internalType":"BeforeSwapDelta"},{"name":"","type":"uint24","internalType":"uint24"}],"stateMutability":"nonpayable"},{"type":"function","name":"commitments","inputs":[{"name":"commitment","type":"bytes32","internalType":"bytes32"}],"outputs":[{"name":"","type":"bool","internalType":"bool"}],"stateMutability":"view"},{"type":"function","name":"currentTreeNumber","inputs":[{"name":"","type":"bytes32","internalType":"PoolId"}],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view"},{"type":"function","name":"getHookPermissions","inputs":[],"outputs":[{"name":"","type":"tuple","internalType":"struct Hooks.Permissions","components":[{"name":"beforeInitialize","type":"bool","internalType":"bool"},{"name":"afterInitialize","type":"bool","internalType":"bool"},{"name":"beforeAddLiquidity","type":"bool","internalType":"bool"},{"name":"afterAddLiquidity","type":"bool","internalType":"bool"},{"name":"beforeRemoveLiquidity","type":"bool","internalType":"bool"},{"name":"afterRemoveLiquidity","type":"bool","internalType":"bool"},{"name":"beforeSwap","type":"bool","internalType":"bool"},{"name":"afterSwap","type":"bool","internalType":"bool"},{"name":"beforeDonate","type":"bool","internalType":"bool"},{"name":"afterDonate","type":"bool","internalType":"bool"},{"name":"beforeSwapReturnDelta","type":"bool","internalType":"bool"},{"name":"afterSwapReturnDelta","type":"bool","internalType":"bool"},{"name":"afterAddLiquidityReturnDelta","type":"bool","internalType":"bool"},{"name":"afterRemoveLiquidityReturnDelta","type":"bool","internalType":"bool"}]}],"stateMutability":"pure"},{"type":"function","name":"getPath","inputs":[{"name":"poolId","type":"bytes32","internalType":"PoolId"},{"name":"tree","type":"uint256","internalType":"uint256"},{"name":"index","type":"uint256","internalType":"uint256"}],"outputs":[{"name":"","type":"bytes32[21]","internalType":"bytes32[21]"}],"stateMutability":"view"},{"type":"function","name":"nextLeafIndex","inputs":[{"name":"","type":"bytes32","internalType":"PoolId"}],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view"},{"type":"function","name":"nullifierHashes","inputs":[{"name":"nullifierHash","type":"bytes32","internalType":"bytes32"}],"outputs":[{"name":"","type":"bool","internalType":"bool"}],"stateMutability":"view"},{"type":"function","name":"poolManager","inputs":[],"outputs":[{"name":"","type":"address","internalType":"contract IPoolManager"}],"stateMutability":"view"},{"type":"function","name":"roots","inputs":[{"name":"root","type":"bytes32","internalType":"bytes32"}],"outputs":[{"name":"","type":"bool","internalType":"bool"}],"stateMutability":"view"},{"type":"event","name":"Deposit","inputs":[{"name":"commitment","type":"bytes32","indexed":true,"internalType":"bytes32"},{"name":"tree","type":"uint256","indexed":true,"internalType":"uint256"},{"name":"leafIndex","type":"uint256","indexed":true,"internalType":"uint256"}],"anonymous":false},{"type":"event","name":"Withdrawal","inputs":[{"name":"to","type":"address","indexed":true,"internalType":"address"},{"name":"nullifierHash","type":"bytes32","indexed":true,"internalType":"bytes32"}],"anonymous":false},{"type":"error","name":"HookNotImplemented","inputs":[]},{"type":"error","name":"NotPoolManager","inputs":[]},{"type":"error","name":"TH_CommitmentExists","inputs":[]},{"type":"error","name":"TH_InvalidProof","inputs":[]},{"type":"error","name":"TH_NullifierIsSpent","inputs":[]},{"type":"error","name":"TH_OnlyERC20","inputs":[]},{"type":"error","name":"TH_WrongFee","inputs":[]},{"type":"error","name":"TH_WrongLevel","inputs":[{"name":"","type":"uint256","internalType":"uint256"}]},{"type":"error","name":"TH_WrongLiquidityDelta","inputs":[]},{"type":"error","name":"TH_WrongRoot","inputs":[]},{"type":"error","name":"TH_WrongSalt","inputs":[]},{"type":"error","name":"TH_WrongTick","inputs":[]},{"type":"error","name":"TH_WrongTickSpacing","inputs":[]}
            ],
        }
    },
} as const;

export default externalContracts satisfies GenericContractsDeclaration;
