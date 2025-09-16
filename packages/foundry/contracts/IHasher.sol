//SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IHasher {
    function poseidon(bytes32[2] memory) external pure returns (bytes32);
}
