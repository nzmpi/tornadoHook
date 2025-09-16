//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import {DeployHookAnvil} from "./DeployHookAnvil.s.sol";
import {DeployHookTestnet} from "./DeployHookTestnet.s.sol";

contract DeployScript is ScaffoldETHDeploy {
    function run() external {
        if (block.chainid == 31337) {
            DeployHookAnvil deployHook = new DeployHookAnvil();
            deployHook.run();
        } else {
            DeployHookTestnet deployHook = new DeployHookTestnet();
            deployHook.run();
        }
    }
}
