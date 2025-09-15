//SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {TickMath} from "v4-core/libraries/TickMath.sol";

uint256 constant FIELD_SIZE = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;
bytes32 constant ZERO_VALUE = 0x2fe54c60d3acabf3343a35b6eba15db4821b340f76e741e2249685ed4899af6c; // = keccak256("tornado") % FIELD_SIZE
uint256 constant LEVELS = 20;
int24 constant MIN_TICK = TickMath.MIN_TICK + 52;
int24 constant MAX_TICK = TickMath.MAX_TICK - 52;
uint24 constant FEE = 3000;
int24 constant TICK_SPACING = 60;
int256 constant LIQUIDITY_DELTA = 10 ether;
bytes32 constant SALT = bytes32(0);
