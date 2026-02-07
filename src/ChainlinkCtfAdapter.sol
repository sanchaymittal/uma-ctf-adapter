// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IConditionalTokens } from "./interfaces/IConditionalTokens.sol";
import { AggregatorV3Interface } from "./interfaces/AggregatorV3Interface.sol";

/// @title ChainlinkCtfAdapter
/// @notice Enables resolution of CTF markets via Chainlink Price Feeds
contract ChainlinkCtfAdapter {

    /*///////////////////////////////////////////////////////////////////
                            STRUCTS 
    //////////////////////////////////////////////////////////////////*/

    struct QuestionData {
        address priceFeed;
        int256 strikePrice;
        uint256 expiration;
        bool resolved;
        bytes32 questionID;
        address creator;
    }

    /*///////////////////////////////////////////////////////////////////
                            EVENTS 
    //////////////////////////////////////////////////////////////////*/

    event QuestionInitialized(
        bytes32 indexed questionID,
        address indexed creator,
        address indexed priceFeed,
        int256 strikePrice,
        uint256 expiration
    );

    event QuestionResolved(
        bytes32 indexed questionID,
        int256 price,
        uint256[] payouts
    );

    /*///////////////////////////////////////////////////////////////////
                            ERRORS 
    //////////////////////////////////////////////////////////////////*/

    error Initialized();
    error NotInitialized();
    error ExpirationOnPast();
    error Resolved();
    error NotReadyToResolve();
    error InvalidFeed();

    /*///////////////////////////////////////////////////////////////////
                            IMMUTABLES 
    //////////////////////////////////////////////////////////////////*/

    /// @notice Conditional Tokens Framework
    IConditionalTokens public immutable ctf;

    /*///////////////////////////////////////////////////////////////////
                            STATE 
    //////////////////////////////////////////////////////////////////*/

    /// @notice Mapping of questionID to QuestionData
    mapping(bytes32 => QuestionData) public questions;

    /*///////////////////////////////////////////////////////////////////
                            CONSTRUCTOR 
    //////////////////////////////////////////////////////////////////*/

    constructor(address _ctf) {
        ctf = IConditionalTokens(_ctf);
    }

    /*///////////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS 
    //////////////////////////////////////////////////////////////////*/

    /// @notice Initializes a question
    /// @param priceFeed     - Address of the Chainlink AggregatorV3
    /// @param strikePrice   - Strike price to compare against (same decimals as feed)
    /// @param expiration    - Timestamp after which the market can be resolved
    /// @param description   - Description string (used for salt/uniqueness)
    function initialize(
        address priceFeed,
        int256 strikePrice,
        uint256 expiration,
        string memory description
    ) external returns (bytes32 questionID) {
        if (expiration <= block.timestamp) revert ExpirationOnPast();
        if (priceFeed == address(0)) revert InvalidFeed();

        // Simple check to see if it responds to latestRoundData
        try AggregatorV3Interface(priceFeed).latestRoundData() returns (uint80, int256, uint256, uint256, uint80) {
            // accessible
        } catch {
            revert InvalidFeed();
        }

        // Generate unique question ID
        questionID = keccak256(abi.encodePacked(priceFeed, strikePrice, expiration, description, msg.sender));

        if (questions[questionID].questionID != bytes32(0)) revert Initialized();

        questions[questionID] = QuestionData({
            priceFeed: priceFeed,
            strikePrice: strikePrice,
            expiration: expiration,
            resolved: false,
            questionID: questionID,
            creator: msg.sender
        });

        // Prepare the question on the CTF (2 outcomes: YES, NO)
        ctf.prepareCondition(address(this), questionID, 2);

        emit QuestionInitialized(questionID, msg.sender, priceFeed, strikePrice, expiration);
    }

    /// @notice Resolves a question based on valid Chainlink data
    /// @param questionID - The unique questionID
    function resolve(bytes32 questionID) external {
        QuestionData storage qData = questions[questionID];

        if (qData.questionID == bytes32(0)) revert NotInitialized();
        if (qData.resolved) revert Resolved();
        if (block.timestamp < qData.expiration) revert NotReadyToResolve();

        // Fetch latest price
        (
            /* uint80 roundId */,
            int256 price,
            /* uint256 startedAt */,
            /* uint256 updatedAt */,
            /* uint80 answeredInRound */
        ) = AggregatorV3Interface(qData.priceFeed).latestRoundData();

        // Check freshness? 
        // For binary expirations, usually we just want the *latest* available price *at or after* expiration.
        // If the oracle stops updating, we might settle with an old price (risk).
        // But for this MVP adapter, we trust the latest round data.

        // Resolve
        qData.resolved = true;

        uint256[] memory payouts = new uint256[](2);
        
        // Outcome Logic:
        // Slot 0: YES (Long) -> 1 if price >= strike
        // Slot 1: NO (Short) -> 1 if price < strike
        
        if (price >= qData.strikePrice) {
            // YES Wins
            payouts[0] = 1;
            payouts[1] = 0;
        } else {
            // NO Wins
            payouts[0] = 0;
            payouts[1] = 1;
        }

        ctf.reportPayouts(questionID, payouts);
        
        emit QuestionResolved(questionID, price, payouts);
    }

    /// @notice Defines the helper logic to check if a question is initialized
    function isInitialized(bytes32 questionID) external view returns (bool) {
        return questions[questionID].questionID != bytes32(0);
    }
}
