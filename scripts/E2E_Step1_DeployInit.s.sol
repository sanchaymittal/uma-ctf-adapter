// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import { ChainlinkCtfAdapter } from "../src/ChainlinkCtfAdapter.sol";
import { MockAggregator } from "../src/mocks/MockAggregator.sol";

contract E2E_Step1_DeployInit is Script {
    function run() external {
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address ctfAddress = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Mock Aggregator
        MockAggregator aggregator = new MockAggregator(50000e8, 8);
        console.log("MockAggregator:", address(aggregator));

        // 2. Deploy Adapter
        ChainlinkCtfAdapter adapter = new ChainlinkCtfAdapter(ctfAddress);
        console.log("ChainlinkCtfAdapter:", address(adapter));

        // 3. Initialize Market
        int256 strikePrice = 60000e8;
        uint256 expiration = block.timestamp + 3600; // Expire in 1 hour
        
        bytes32 questionID = adapter.initialize(
            address(aggregator),
            strikePrice,
            expiration,
            "BTC > 60k?"
        );
        console.log("QuestionID:");
        console.logBytes32(questionID);

        // Save addresses for Step 2 (Quick hack: Logs, or strict deterministic deploy)
        // For E2E, we'll just parse the logs or hardcode if we use deterministic.
        // Let's rely on the console output to grab the addresses for the next command?
        // Or store in a file?
        // Simpler: Just rely on logs for now.

        // Also update price to WIN condition now, so it's ready when time passes
        aggregator.updatePrice(70000e8);
        console.log("Price updated to 70k");

        vm.stopBroadcast();
    }
}
