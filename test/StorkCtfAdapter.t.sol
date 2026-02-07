// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import { StorkCtfAdapter } from "../src/StorkCtfAdapter.sol";
import { MockStork } from "../src/mocks/MockStork.sol";
import { IConditionalTokens } from "../src/interfaces/IConditionalTokens.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// Minimal Mock CTF to catch calls
contract MockCTF is IConditionalTokens {
    event ConditionPrepared(bytes32 indexed questionId, address oracle, uint256 outcomeSlotCount);
    event PayoutsReported(bytes32 indexed questionId, uint256[] payouts);

    function prepareCondition(address oracle, bytes32 questionId, uint256 outcomeSlotCount) external override {
        emit ConditionPrepared(questionId, oracle, outcomeSlotCount);
    }
    
    function reportPayouts(bytes32 questionId, uint256[] calldata payouts) external override {
        emit PayoutsReported(questionId, payouts);
    }
    
    // Unused overrides
    function payoutNumerators(bytes32) external override returns (uint256[] memory) { return new uint256[](0); }
    function payoutDenominator(bytes32) external override returns (uint256) { return 0; }
    function splitPosition(IERC20, bytes32, bytes32, uint256[] calldata, uint256) external override {}
    function mergePositions(IERC20, bytes32, bytes32, uint256[] calldata, uint256) external override {}
    function redeemPositions(IERC20, bytes32, bytes32, uint256[] calldata) external override {}
    function getOutcomeSlotCount(bytes32) external view override returns (uint256) { return 2; }
    function getConditionId(address, bytes32, uint256) external pure override returns (bytes32) { return bytes32(0); }
    function getCollectionId(bytes32, bytes32, uint256) external view override returns (bytes32) { return bytes32(0); }
    function getPositionId(IERC20, bytes32) external pure override returns (uint256) { return 0; }
}

contract StorkCtfAdapterTest is Test {
    StorkCtfAdapter adapter;
    MockStork stork;
    MockCTF ctf;

    bytes32 constant ASSET_ID = bytes32("BTCUSD");

    // Redefine event for expectEmit
    event PayoutsReported(bytes32 indexed questionId, uint256[] payouts);

    function setUp() public {
        ctf = new MockCTF();
        stork = new MockStork();
        adapter = new StorkCtfAdapter(address(ctf), address(stork));
    }

    function testInitialize() public {
        uint256 expiration = block.timestamp + 1 hours;
        bytes32 questionID = adapter.initialize(ASSET_ID, 100000e18, expiration, "BTC > 100k");
        
        // Verify storage
        (bytes32 storedAsset, int256 storedStrike, uint256 storedExp, bool resolved,,) = adapter.questions(questionID);
        
        assertEq(storedAsset, ASSET_ID);
        assertEq(storedStrike, 100000e18);
        assertEq(storedExp, expiration);
        assertFalse(resolved);
    }

    function testInitializePastExpirationReverts() public {
        vm.expectRevert("Expiration must be future");
        adapter.initialize(ASSET_ID, 100000e18, block.timestamp - 1, "BTC > 100k");
    }

    function testResolveYes() public {
        uint256 expiration = block.timestamp + 1 hours;
        int256 strike = 100000e18; 
        bytes32 questionID = adapter.initialize(ASSET_ID, strike, expiration, "BTC > 100k");

        // Forward time
        vm.warp(expiration + 1);
        
        // Price goes to 101k (> 100k)
        // Stork's quantizedValue is int192. Assuming 18 decimals matching the strike.
        stork.updateValue(ASSET_ID, 101000e18, uint64(block.timestamp * 1e9));

        // Expect PayoutsReported event from MockCTF
        // Payouts for YES: [0, 1]
        uint256[] memory expectedAsync = new uint256[](2);
        expectedAsync[0] = 0;
        expectedAsync[1] = 1;

        vm.expectEmit(true, false, false, true, address(ctf));
        emit PayoutsReported(questionID, expectedAsync);
        
        adapter.resolve(questionID);
        
        // Verify resolved state
        (,,, bool resolved,,) = adapter.questions(questionID);
        assertTrue(resolved);
    }

    function testResolveNo() public {
        uint256 expiration = block.timestamp + 1 hours;
        int256 strike = 100000e18;
        bytes32 questionID = adapter.initialize(ASSET_ID, strike, expiration, "BTC > 100k");

        vm.warp(expiration + 1);
        
        // Price stays 99k (< 100k)
        stork.updateValue(ASSET_ID, 99000e18, uint64(block.timestamp * 1e9));

        // Payouts for NO: [1, 0]
        uint256[] memory expectedAsync = new uint256[](2);
        expectedAsync[0] = 1;
        expectedAsync[1] = 0;

        vm.expectEmit(true, false, false, true, address(ctf));
        emit PayoutsReported(questionID, expectedAsync);

        adapter.resolve(questionID);
    }
    
    function testResolveBeforeExpirationReverts() public {
        uint256 expiration = block.timestamp + 1 hours;
        bytes32 questionID = adapter.initialize(ASSET_ID, 100000e18, expiration, "BTC > 100k");

        vm.expectRevert("Not expired yet");
        adapter.resolve(questionID);
    }
}
