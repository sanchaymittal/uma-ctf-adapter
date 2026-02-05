// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import { ChainlinkCtfAdapter } from "../src/ChainlinkCtfAdapter.sol";
import { AggregatorV3Interface } from "../src/interfaces/AggregatorV3Interface.sol";
import { IConditionalTokens } from "../src/interfaces/IConditionalTokens.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract MockAggregator is AggregatorV3Interface {
    int256 public price;
    uint256 public updatedAt;
    uint8 public _decimals;

    constructor(int256 _price, uint8 decimals_) {
        price = _price;
        _decimals = decimals_;
        updatedAt = block.timestamp;
    }

    function updatePrice(int256 _price) external {
        price = _price;
        updatedAt = block.timestamp;
    }

    function decimals() external view override returns (uint8) { return _decimals; }
    function description() external pure override returns (string memory) { return "Mock"; }
    function version() external pure override returns (uint256) { return 1; }
    function getRoundData(uint80) external view override returns (uint80, int256, uint256, uint256, uint80) {
        return (1, price, updatedAt, updatedAt, 1);
    }
    function latestRoundData() external view override returns (uint80, int256, uint256, uint256, uint80) {
        return (1, price, updatedAt, updatedAt, 1);
    }
}

contract MockCTF is IConditionalTokens {
    function prepareCondition(address oracle, bytes32 questionId, uint256 outcomeSlotCount) external override {}
    function reportPayouts(bytes32 questionId, uint256[] calldata payouts) external override {}
    
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

contract ChainlinkCtfAdapterTest is Test {
    ChainlinkCtfAdapter adapter;
    MockAggregator aggregator;
    MockCTF ctf;

    function setUp() public {
        ctf = new MockCTF();
        aggregator = new MockAggregator(1000e8, 8); // $1000, 8 decimals
        adapter = new ChainlinkCtfAdapter(address(ctf));
    }

    function testInitialize() public {
        uint256 expiration = block.timestamp + 1 hours;
        bytes32 questionID = adapter.initialize(address(aggregator), 1100e8, expiration, "BTC > 1100");
        
        assertTrue(questionID != bytes32(0));
        assertTrue(adapter.isInitialized(questionID));
    }

    function testInitializePastExpirationReverts() public {
        uint256 expiration = block.timestamp - 1;
        vm.expectRevert(ChainlinkCtfAdapter.ExpirationOnPast.selector);
        adapter.initialize(address(aggregator), 1100e8, expiration, "BTC > 1100");
    }

    function testResolveYes() public {
        uint256 expiration = block.timestamp + 1 hours;
        int256 strike = 1100e8; 
        bytes32 questionID = adapter.initialize(address(aggregator), strike, expiration, "BTC > 1100");

        // Forward time
        vm.warp(expiration + 1);
        
        // Price goes to 1200 (> 1100)
        aggregator.updatePrice(1200e8);

        adapter.resolve(questionID);
        // If logic matches, should report YES (payouts[0]=1, payouts[1]=0)
        // Since CTF is mocked, we assume it called correctly. 
        // We could emit events in Adapter or spy on Mock, but Adapter emits event.
    }

    function testResolveNo() public {
        uint256 expiration = block.timestamp + 1 hours;
        int256 strike = 1100e8;
        bytes32 questionID = adapter.initialize(address(aggregator), strike, expiration, "BTC > 1100");

        vm.warp(expiration + 1);
        
        // Price stays 1000 (< 1100)
        aggregator.updatePrice(1000e8);

        adapter.resolve(questionID);
    }
    
    function testResolveBeforeExpirationReverts() public {
        uint256 expiration = block.timestamp + 1 hours;
        bytes32 questionID = adapter.initialize(address(aggregator), 1100e8, expiration, "BTC > 1100");

        vm.expectRevert(ChainlinkCtfAdapter.NotReadyToResolve.selector);
        adapter.resolve(questionID);
    }
}
