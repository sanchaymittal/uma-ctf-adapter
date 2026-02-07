// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import { StorkCtfAdapter } from "../src/StorkCtfAdapter.sol";

contract DeployArc is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address ctfAddress = vm.envAddress("CTF_ADDRESS");
        // Stork on Arc Testnet
        address storkAddress = 0xacC0a0cF13571d30B4b8637996F5D6D774d4fd62;
        
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying StorkAdapter with:", deployer);
        console.log("Using CTF:", ctfAddress);
        console.log("Using Stork:", storkAddress);

        vm.startBroadcast(deployerPrivateKey);

        StorkCtfAdapter adapter = new StorkCtfAdapter(ctfAddress, storkAddress);
        console.log("StorkCtfAdapter deployed at:", address(adapter));

        vm.stopBroadcast();
        
        console.log("\nDeployment Complete!");
        console.log("Use lifecycle-manager to call initialize() for each new market");
    }
}
