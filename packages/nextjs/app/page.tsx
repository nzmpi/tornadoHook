"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import type { NextPage } from "next";
import { useAccount, useReadContract, useWriteContract } from "wagmi";
import { BugAntIcon, MagnifyingGlassIcon } from "@heroicons/react/24/outline";
import { AddressInput, IntegerInput, InputBase } from "~~/components/scaffold-eth";
import { useScaffoldReadContract, useScaffoldWriteContract, useDeployedContractInfo } from "~~/hooks/scaffold-eth";
import { ethers, keccak256 } from "ethers";
import { poseidon1, poseidon2 } from "poseidon-lite";
import { Noir, InputMap } from "@noir-lang/noir_js";
import { UltraHonkBackend, ProofData } from "@aztec/bb.js";
import * as snarkjs from "snarkjs";
import circuit from "../../circuits/noir/target/noir.json";

const FIELD_SIZE = BigInt("0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001");
const LEVELS = 20;
const abiCoder = ethers.AbiCoder.defaultAbiCoder();

const Home: NextPage = () => {
    const { address: connectedAddress } = useAccount();
    const [token0Amount, setToken0Amount] = useState("");
    const [token1Amount, setToken1Amount] = useState("");
    const [nullifierStringToDeposit, setNullifierStringToDeposit] = useState("");
    const [nullifierToDeposit, setNullifierToDeposit] = useState(0n);
    const [secretStringToDeposit, setSecretStringToDeposit] = useState("");
    const [secretToDeposit, setSecretToDeposit] = useState(0n);
    const [nullifierStringToWithdraw, setNullifierStringToWithdraw] = useState("");
    const [nullifierToWithdraw, setNullifierToWithdraw] = useState(0n);
    const [secretStringToWithdraw, setSecretStringToWithdraw] = useState("");
    const [secretToWithdraw, setSecretToWithdraw] = useState(0n);
    const [commitmentToDeposit, setCommitmentToDeposit] = useState("");
    const [commitmentToWithdraw, setCommitmentToWithdraw] = useState("");
    const [recipient, setRecipient] = useState(connectedAddress?? "");
    const [nullifierHashToDeposit, setNullifierHashToDeposit] = useState(0n);
    const [nullifierHashToWithdraw, setNullifierHashToWithdraw] = useState(0n);
    const [secretHashToDeposit, setSecretHashToDeposit] = useState(0n);
    const [secretHashToWithdraw, setSecretHashToWithdraw] = useState(0n);
    const [treeNumber, setTreeNumber] = useState("");
    const [commitmentIndex, setCommitmentIndex] = useState("");
    const [verifier, setVerifier] = useState<"circom" | "noir">("circom");
    const [proof, setProof] = useState("");
    const [calculatingProof, setCalculatingProof] = useState(false);
    const [status, setStatus] = useState("");

    const { data: token0Contract } = useDeployedContractInfo({ contractName: "MockERC20" });
    const { data: token1Contract } = useDeployedContractInfo({ contractName: "MockERC201" });
    const { data: router } = useDeployedContractInfo({ contractName: "PoolModifyLiquidityTest" });
    const { data: hook } = useDeployedContractInfo({ contractName: "TornadoHook" });
    const { data: balanceToken0 } = useScaffoldReadContract({
        contractName: "MockERC20",
        functionName: "balanceOf",
        args: [connectedAddress],
    });
    const { data: balanceToken1 } = useScaffoldReadContract({
        contractName: "MockERC201",
        functionName: "balanceOf",
        args: [connectedAddress],
    });

    const { writeContractAsync: token0ContractWrite } = useScaffoldWriteContract({ contractName: "MockERC20" });
    const { writeContractAsync: token1ContractWrite } = useScaffoldWriteContract({ contractName: "MockERC201" });
    const { writeContractAsync: routerWrite } = useScaffoldWriteContract({ contractName: "PoolModifyLiquidityTest" });

    const compiledCircuit = JSON.parse(JSON.stringify(circuit));
    const noir = new Noir(compiledCircuit);
    const backend = new UltraHonkBackend(circuit.bytecode); 

    const poolKey = {
        currency0: token0Contract?.address?? "0x0000000000000000000000000000000000000000",
        currency1: token1Contract?.address?? "0x0000000000000000000000000000000000000000",
        fee: 3000,
        tickSpacing: 60,
        hooks: hook?.address?? "0x0000000000000000000000000000000000000000"
    };

    const { data: path } = useScaffoldReadContract({
        contractName: "TornadoHook",
        functionName: "getPath",
        args: [toId(), BigInt(treeNumber), BigInt(commitmentIndex)],
    });

    function toId() {
        const poolId = abiCoder.encode(
            ["address", "address" , "uint24", "int24", "address"],
            [poolKey.currency0, poolKey.currency1, poolKey.fee, poolKey.tickSpacing, poolKey.hooks]
        );
        return ethers.keccak256(poolId) as `0x${string}`;
    }

    function getHash(preimage: string) {
        return BigInt(ethers.keccak256(ethers.toUtf8Bytes(preimage))) % FIELD_SIZE;
    }

    function getParams(isDeposit: boolean) {
        return {
            tickLower: -887220,
            tickUpper: 887220,
            liquidityDelta: isDeposit ? ethers.parseEther("10") : ethers.parseEther("-10"),
            salt: ethers.hexlify(ethers.zeroPadValue(ethers.toBeHex(0), 32))
        };
    }

    async function getWithdrawalData() {
        const root = path ? path[LEVELS] : "0x0000000000000000000000000000000000000000000000000000000000000000";
        const withdrawalData = {
            isCircom: verifier === "circom" ? true : false,
            nullifierHash: "0x" + nullifierHashToWithdraw.toString(16),
            root: root,
            recipient: recipient,
            proof: await getNoirProof(root)
        };
        return {
            hookData: ethers.hexlify(abiCoder.encode(
                ["tuple(bool, bytes32 , bytes32, address, bytes)"],
                [[withdrawalData.isCircom, withdrawalData.nullifierHash, withdrawalData.root, withdrawalData.recipient, withdrawalData.proof]]
            ))
        };
    }

    function getSquare(input: bigint) {
        return (input * input) % FIELD_SIZE;
    }

    async function getCircomProof() {
        const relayer = "0x0000000000000000000000000000000000000000";
        const fee = "0x0000000000000000000000000000000000000000000000000000000000000000";
        const pathElements = path ? path.slice(0, LEVELS) : [];
        const pathIndices = Array.from({ length: 20 }, (_, i) => 
            Number((BigInt(commitmentIndex) / (2n ** BigInt(i))) % 2n));
        const recipientSquare = "0x" + getSquare(BigInt(recipient)).toString(16);
        const input = {
            root: path ? path[LEVELS] : "0x0000000000000000000000000000000000000000000000000000000000000000",
            nullifierHash: "0x" + nullifierHashToWithdraw.toString(16),
            recipient: recipient,
            relayer: relayer,
            fee: fee,
            refund: fee,
            nullifier: "0x" + nullifierToWithdraw.toString(16),
            secret: "0x" + secretToWithdraw.toString(16),
            pathElements: pathElements,
            pathIndices: pathIndices,
            recipientSquare: recipientSquare,
            relayerSquare: fee,
            feeSquare: fee,
            refundSquare: fee
        };
        
        setStatus("Generating proof...");
        const mainWasm = await fetch("../../circuits/circom/main_js/main.wasm");
        const mainWasmUint8Array = new Uint8Array(await mainWasm.arrayBuffer());
        const mainZkey = await fetch("../../circuits/circom/main_0001.zkey");
        const mainZkeyUint8Array = new Uint8Array(await mainZkey.arrayBuffer());
        setStatus(mainWasmUint8Array.length.toString());
        /* const { proof, publicSignals } = await snarkjs.groth16.fullProve(
            input,
            mainWasmUint8Array,
            mainZkeyUint8Array
        );
        setStatus(publicSignals.length.toString()); */
    }

    async function getNoirProof(root: string) {
        const relayer = "0x0000000000000000000000000000000000000000";
        const fee = "0x0000000000000000000000000000000000000000000000000000000000000000";
        const pathElements = path ? path.slice(0, LEVELS) : [];
        const pathIndices = Array.from({ length: 20 }, (_, i) => 
            Number((BigInt(commitmentIndex) / (2n ** BigInt(i))) % 2n));
        const recipientSquare = "0x" + getSquare(BigInt(recipient)).toString(16);
        const input: InputMap = {
            root: root,
            nullifierHash: "0x" + nullifierHashToWithdraw.toString(16),
            recipient: recipient,
            relayer: relayer,
            fee: fee,
            refund: fee,
            nullifier: "0x" + nullifierToWithdraw.toString(16),
            secret: "0x" + secretToWithdraw.toString(16),
            pathElements: pathElements,
            pathIndices: pathIndices,
            recipientSquare: recipientSquare,
            relayerSquare: fee,
            feeSquare: fee,
            refundSquare: fee
        };
        const { witness } = await noir.execute(input);
        setCalculatingProof(true);
        const proofData: ProofData = await backend.generateProof(witness);
        setCalculatingProof(false);

        const isValid = await backend.verifyProof(proofData);
        //setStatus(isValid.toString());
        /* setStatus(ethers.hexlify(abiCoder.encode(
                ["tuple(bool, bytes32 , bytes32, address, bytes)"],
                [[false, "0x" + nullifierHashToWithdraw.toString(16), root, recipient, ethers.hexlify(proofData.proof)]]
            ))); */
        setStatus(ethers.hexlify(proofData.proof));

        return ethers.hexlify(proofData.proof);
    }

    useEffect(() => {
        if (nullifierStringToDeposit.length === 0) {
            setNullifierToDeposit(0n);
            setNullifierHashToDeposit(0n);
        }
        else {
            const hash = getHash(nullifierStringToDeposit);
            setNullifierToDeposit(hash);
            setNullifierHashToDeposit(poseidon1([hash]));
        }
    }, [nullifierStringToDeposit]);

    useEffect(() => {
        if (secretStringToDeposit.length === 0) {
            setSecretToDeposit(0n);
            setSecretHashToDeposit(0n);
        } else {
            const hash = getHash(secretStringToDeposit);
            setSecretToDeposit(hash);
            setSecretHashToDeposit(poseidon1([hash]));
        }
    }, [secretStringToDeposit]);

    useEffect(() => {
        if (nullifierStringToWithdraw.length === 0) {
            setNullifierToWithdraw(0n);
            setNullifierHashToWithdraw(0n);
        }
        else {
            const hash = getHash(nullifierStringToWithdraw);
            setNullifierToWithdraw(hash);
            setNullifierHashToWithdraw(poseidon1([hash]));
        }
    }, [nullifierStringToWithdraw]);

    useEffect(() => {
        if (secretStringToWithdraw.length === 0) {
            setSecretToWithdraw(0n);
            setSecretHashToWithdraw(0n);
        } else {
            const hash = getHash(secretStringToWithdraw);
            setSecretToWithdraw(hash);
            setSecretHashToWithdraw(poseidon1([hash]));
        }
    }, [secretStringToWithdraw])

    return (
        <>
        
        <div className="mx-auto mt-7">
            <form className="w-[500px] bg-base-100 rounded-3xl shadow-xl border-pink-700 border-2 p-2 px-7 py-5 flex justify-center">
                <div className="mt-3 flex flex-col space-y-3">
                    <div className="form-control mb-5">
                        <span className="text-1xl">
                            Your token0 balance: {ethers.formatEther(balanceToken0?? 0)}
                        </span>
                        <div className="mt-5 flex items-center space-x-2">
                            <IntegerInput value={token0Amount} onChange={amount => setToken0Amount(amount)} placeholder="amount (wei)"/>
                            <button
                                type="button"
                                className="btn btn-primary"
                                onClick={async () => {
                                    try {
                                        await token0ContractWrite({
                                            functionName: "mint",
                                            args: [connectedAddress, BigInt(token0Amount)],
                                        });
                                    } catch (e) {
                                        console.error("Error mint token0:", e);
                                    }
                                }}>
                                Mint
                            </button>
                            <button
                                type="button"
                                className="btn btn-primary"
                                onClick={async () => {
                                    try {
                                        await token0ContractWrite({
                                            functionName: "approve",
                                            args: [router?.address, ethers.MaxUint256],
                                        });
                                    } catch (e) {
                                        console.error("Error approve token0:", e);
                                    }
                                }}>
                                Approve
                            </button>
                        </div>
                    </div>
                    <div className="form-control mb-5">
                        <span className="text-1xl">
                            Your token1 balance: {ethers.formatEther(balanceToken1?? 0)}
                        </span>
                        <div className="mt-5 flex items-center space-x-2">
                            <IntegerInput value={token1Amount} onChange={amount => setToken1Amount(amount)} placeholder="amount (wei)"/>
                            <button
                                type="button"
                                className="btn btn-primary"
                                onClick={async () => {
                                    try {
                                        await token1ContractWrite({
                                            functionName: "mint",
                                            args: [connectedAddress, BigInt(token1Amount)],
                                        });
                                    } catch (e) {
                                        console.error("Error mint token1:", e);
                                    }
                                }}>
                                Mint
                            </button>
                            <button
                                type="button"
                                className="btn btn-primary"
                                onClick={async () => {
                                    try {
                                        await token1ContractWrite({
                                            functionName: "approve",
                                            args: [router?.address, ethers.MaxUint256],
                                        });
                                    } catch (e) {
                                        console.error("Error approve token1:", e);
                                    }
                                }}>
                                Approve
                            </button>
                        </div>
                    </div>
                </div>
            </form>

            <form className="mt-7 w-[500px] bg-base-100 rounded-3xl shadow-xl border-pink-700 border-2 p-2 px-7 py-5 flex justify-center">
                <div className="mt-3 flex flex-col space-y-3">
                    <span className="text-2xl flex justify-center">
                        Deposit
                    </span>
                    <label className="label">
                        <span className="label-text font-bold">
                            Nullifier:
                        </span>
                    </label>
                    <InputBase name="nullifierToDeposit" placeholder="nullifier" value={nullifierStringToDeposit} onChange={setNullifierStringToDeposit} />
                    <label className="label">
                        <span className="label-text font-bold">
                            Secret:
                        </span>
                    </label>
                    <InputBase name="secretToDeposit" placeholder="secret" value={secretStringToDeposit} onChange={setSecretStringToDeposit} />
                    <button
                        type="button"
                        className="btn btn-primary"
                        onClick={async () => {
                            try {
                                await routerWrite({
                                    functionName: "modifyLiquidity",
                                    args: [
                                        poolKey,
                                        getParams(true),
                                        ethers.hexlify(ethers.zeroPadValue(ethers.toBeHex(poseidon2([nullifierToDeposit, secretToDeposit])), 32)),
                                    ],
                                });
                            } catch (e) {
                                console.error("Error deposit:", e);
                            }
                        }}>
                        Deposit
                    </button>
                </div>
            </form>

            <form className="mt-7 w-[500px] bg-base-100 rounded-3xl shadow-xl border-pink-700 border-2 p-2 px-7 py-5 flex justify-center">
                <div className="mt-3 flex flex-col space-y-3">
                    <span className="text-2xl flex justify-center">
                        Withdraw
                    </span>
                    <div className="mb-3 flex items-center space-x-10">
                        <label className="flex items-center gap-2">
                        <input
                            type="radio"
                            name="verifierChoice"
                            value="circom"
                            checked={verifier === "circom"}
                            onChange={() => setVerifier("circom")}
                        />
                        Circom
                        </label>

                        <label className="flex items-center gap-2">
                        <input
                            type="radio"
                            name="verifierChoice"
                            value="noir"
                            checked={verifier === "noir"}
                            onChange={() => setVerifier("noir")}
                        />
                        Noir
                        </label>
                    </div>
                    <label className="label">
                        <span className="label-text font-bold">
                            Nullifier:
                        </span>
                    </label>
                    <InputBase name="nullifierToWithdraw" placeholder="nullifier" value={nullifierStringToWithdraw} onChange={setNullifierStringToWithdraw} />
                    <label className="label">
                        <span className="label-text font-bold">
                            Secret:
                        </span>
                    </label>
                    <InputBase name="secretToWithdraw" placeholder="secret" value={secretStringToWithdraw} onChange={setSecretStringToWithdraw} />
                    <label className="label">
                        <span className="label-text font-bold">
                            Recipient:
                        </span>
                    </label>
                    <AddressInput onChange={setRecipient} value={recipient} placeholder="recipient" />
                    <label className="label">
                        <span className="label-text font-bold">
                            Tree Number:
                        </span>
                    </label>
                    <IntegerInput name="treeNumber" placeholder="tree number" value={treeNumber} onChange={setTreeNumber} />
                    <label className="label">
                        <span className="label-text font-bold">
                            Commitment Index:
                        </span>
                    </label>
                    <IntegerInput name="commitmentIndex" placeholder="commitment index" value={commitmentIndex} onChange={setCommitmentIndex} />
                    <button
                        type="button"
                        className="btn btn-primary"
                        onClick={async () => {
                            try {
                                await routerWrite({
                                    functionName: "modifyLiquidity",
                                    args: [
                                        poolKey,
                                        getParams(false),
                                        await getWithdrawalData(),
                                    ],
                                });
                            } catch (e) {
                                console.error("Error withdraw:", e);
                            }
                        }}>
                        Withdraw
                    </button>
                    <button
                        type="button"
                        className="btn btn-primary"
                        onClick={async () => {
                            try {
                                getCircomProof();
                            } catch (e) {
                                console.error("Error test:", e);
                            }
                        }}>
                        test
                    </button>
                </div>
                {status}
            </form>
            {status}
        </div>
        </>
    );
};

export default Home;
