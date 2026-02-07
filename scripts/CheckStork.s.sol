// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import { IStork } from "../src/interfaces/IStork.sol";

contract CheckStork is Script {
    function run() external {
        address storkAddress = 0xacC0a0cF13571d30B4b8637996F5D6D774d4fd62;
        IStork stork = IStork(storkAddress);

        console.log("Checking Stork at:", storkAddress);

        // Try to read a value (view function)
        // BTCUSD encoded Asset ID (keccak256("BTCUSD"))
        bytes32 assetId = 0x7404e3d104ea7841c3d9e6fd20adfe99b4ad586bc08d8f3bd3afef894cf184de;
        
        console.log("Checking getTemporalNumericValueV1...");
        // Define V1 interface inline or assume same struct return
        // We need to use low-level call or update interface
        (bool success, bytes memory data) = address(stork).staticcall(
            abi.encodeWithSignature("getTemporalNumericValueV1(bytes32)", assetId)
        );

        if (success) {
            IStork.TemporalNumericValue memory val = abi.decode(data, (IStork.TemporalNumericValue));
            console.log("Success! Price:", uint256(int256(val.quantizedValue)));
            console.log("Timestamp:", val.timestampNs);
        } else {
            console.log("Failed to call getTemporalNumericValueV1");
            console.logBytes(data);
        }

        // Simulate Update (Write)
        console.log("Simulating Update...");
        IStork.TemporalNumericValueInput[] memory inputs = new IStork.TemporalNumericValueInput[](1);
        inputs[0] = IStork.TemporalNumericValueInput({
            id: assetId,
            quantizedValue: int192(70185449999999997000000), // Example from recent logs
            publisherMerkleRoot: 0x110577317c3c06db7e68122ce6ca728a4d8451594f1e1a3bbce601fb47117aa0,
            valueComputeAlgHash: 0,
            r: 0xc8867865cc5b2d81be19d1b2bd3bb96a7c59ba6d7970ec33621f66654da7db6d,
            s: 0x4f72e2afbdc0ddadc469bfba519e68ba57b58d1c280493b762a72f253aa0aa05,
            v: 27,
            timestampNs: 1770423271574285256
        });

        try stork.updateTemporalNumericValuesV1(inputs) {
            console.log("Update Simulation Success!");
        } catch (bytes memory reason) {
            console.log("Update Failed");
            console.logBytes(reason);
        }
    }
}
