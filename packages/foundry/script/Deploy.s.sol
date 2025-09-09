//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import {DeployHook} from "./DeployHook.s.sol";

contract DeployScript is ScaffoldETHDeploy {
    function run() external {
        DeployHook deployHook = new DeployHook();
        deployHook.run();
    }
}
