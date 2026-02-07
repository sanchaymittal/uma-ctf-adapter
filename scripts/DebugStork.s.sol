// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "../src/StorkCtfAdapter.sol";
import "@storknetwork/stork-evm-sdk/StorkStructs.sol";

contract DebugStork is Script {
    function run() external {
        address adapterAddr = 0x1F34219303889894772AF27ebacac56F7a769216;
        StorkCtfAdapter adapter = StorkCtfAdapter(adapterAddr);

        bytes32 assetId = 0x7404e3d104ea7841c3d9e6fd20adfe99b4ad586bc08d8f3bd3afef894cf184de;
        uint256 expiration = 1770425804;
        string memory description = "btc-up-and-down-5min-1770425804";
        
        // Exact storkData from the failure
        bytes memory storkData = hex"000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000017404e3d104ea7841c3d9e6fd20adfe99b4ad586bc08d8f3bd3afef894cf184de000000000000000000000000000000000000000000000edaa6e1398ca6556d00d741cd03b5072692da68359f94b7b22d299d4be6546acf0db272070c6c8801e20000000000000000000000000000000000000000000000000000000000000000f05d132b0fa02dfae11c9dee1bb104b8459959cd3abb3af6caabaa5610dfbd5a3c970c6e52145889a373f04f62d462efb73eef8d9076d29e7937acfcb618c292000000000000000000000000000000000000000000000000000000000000001b0000000000000000000000000000000000000000000000001891d09dc564a700";

        console.log("Simulating initialize call...");
        
        vm.startBroadcast();
        adapter.initialize(
            assetId,
            StorkCtfAdapter.MarketType.PRICE_RANGE_UP_DOWN,
            0,
            expiration,
            description,
            storkData
        );
        vm.stopBroadcast();
    }
}
