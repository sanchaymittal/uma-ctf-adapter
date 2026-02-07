// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IConditionalTokens } from "./interfaces/IConditionalTokens.sol";
import { IStork } from "@storknetwork/stork-evm-sdk/IStork.sol";
import { StorkStructs } from "@storknetwork/stork-evm-sdk/StorkStructs.sol";

contract StorkCtfAdapter {
    IConditionalTokens public immutable ctf;
    IStork public immutable stork;

    enum MarketType {
        PRICE_ABOVE_STRIKE,    // "BTC >= $110k at time T"
        PRICE_RANGE_UP_DOWN    // "BTC UP in next 5 min"
    }

    struct QuestionData {
        bytes32 assetId;
        MarketType marketType;
        int256 referencePrice;  // strikePrice OR openingPrice depending on type
        uint256 expiration;
        bool resolved;
        bytes32 questionID;
        address creator;
    }

    mapping(bytes32 => QuestionData) public questions;

    event QuestionInitialized(bytes32 indexed questionID, bytes32 assetId, MarketType marketType, int256 referencePrice, uint256 expiration);
    event QuestionResolved(bytes32 indexed questionID, int256 price, bool result);

    constructor(address _ctf, address _stork) {
        ctf = IConditionalTokens(_ctf);
        stork = IStork(_stork);
    }

    // For PRICE_ABOVE_STRIKE: strikePrice is passed directly, no storkData needed
    // For PRICE_RANGE_UP_DOWN: storkData contains opening price to push on-chain
    function initialize(
        bytes32 assetId,
        MarketType marketType,
        int256 strikePrice,
        uint256 expiration,
        string memory description,
        bytes calldata storkData
    ) external payable returns (bytes32 questionID) {
        require(expiration > block.timestamp, "Expiration must be future");

        // Generate unique question ID
        questionID = keccak256(abi.encodePacked(assetId, uint8(marketType), strikePrice, expiration, description, msg.sender));

        require(questions[questionID].expiration == 0, "Question already initialized");

        int256 referencePrice = strikePrice;

        // For UP_DOWN markets, push opening price and store it
        if (marketType == MarketType.PRICE_RANGE_UP_DOWN) {
            require(storkData.length > 0, "storkData required for UP_DOWN markets");
            
            // PULL MODEL: Update Stork contract with fresh signed data
            stork.updateTemporalNumericValuesV1{value: msg.value}(
                abi.decode(storkData, (StorkStructs.TemporalNumericValueInput[]))
            );
            
            // Read the freshly updated price
            StorkStructs.TemporalNumericValue memory data = stork.getTemporalNumericValueV1(assetId);
            referencePrice = int256(data.quantizedValue);
        }

        questions[questionID] = QuestionData({
            assetId: assetId,
            marketType: marketType,
            referencePrice: referencePrice,
            expiration: expiration,
            resolved: false,
            questionID: questionID,
            creator: msg.sender
        });

        // Prepare condition on CTF (Outcome Slot Count = 2 for Binary)
        ctf.prepareCondition(address(this), questionID, 2);

        emit QuestionInitialized(questionID, assetId, marketType, referencePrice, expiration);
    }

    // PULL MODEL: Update Stork contract with fresh signed data, then read
    function resolve(bytes32 questionID, bytes calldata storkData) external payable {
        QuestionData storage q = questions[questionID];
        require(q.expiration != 0, "Question not found");
        require(!q.resolved, "Already resolved");
        require(block.timestamp >= q.expiration, "Not expired yet");
        require(storkData.length > 0, "storkData required");

        // PULL MODEL: Update Stork contract with fresh signed data
        stork.updateTemporalNumericValuesV1{value: msg.value}(
            abi.decode(storkData, (StorkStructs.TemporalNumericValueInput[]))
        );

        // Read the freshly updated price
        StorkStructs.TemporalNumericValue memory data = stork.getTemporalNumericValueV1(q.assetId);
        int256 closingPrice = int256(data.quantizedValue);
        
        // Resolution Logic depends on market type
        bool result;
        if (q.marketType == MarketType.PRICE_ABOVE_STRIKE) {
            // YES if closing price >= strike price
            result = closingPrice >= q.referencePrice;
        } else {
            // YES if closing price >= opening price (UP)
            result = closingPrice >= q.referencePrice;
        }

        // Payouts: [NO, YES]
        uint256[] memory payouts = new uint256[](2);
        if (result) {
            payouts[0] = 0;
            payouts[1] = 1; // YES
        } else {
            payouts[0] = 1; // NO
            payouts[1] = 0;
        }

        q.resolved = true;
        
        ctf.reportPayouts(questionID, payouts);
        
        emit QuestionResolved(questionID, closingPrice, result);
    }
}
