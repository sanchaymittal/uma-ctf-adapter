// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import { ChainlinkCtfAdapter } from "../src/ChainlinkCtfAdapter.sol";

contract E2E_Step2_Resolve is Script {
    function run() external {
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        
        // READ from ENV or HARDCODE for testing session
        // Only for this E2E manual run
        address adapterAddr = vm.envAddress("ADAPTER_ADDR");
        bytes32 questionID = vm.envBytes32("QUESTION_ID");

        vm.startBroadcast(deployerPrivateKey);

        ChainlinkCtfAdapter adapter = ChainlinkCtfAdapter(adapterAddr);
        adapter.resolve(questionID);
        console.log("Resolved successfully");

        vm.stopBroadcast();
    }
}
