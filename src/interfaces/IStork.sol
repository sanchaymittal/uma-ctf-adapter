// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IStork {
    struct TemporalNumericValue {
        int192 quantizedValue;
        uint64 timestampNs;
    }

    struct TemporalNumericValueInput {
        bytes32 id;
        int192 quantizedValue;
        bytes32 publisherMerkleRoot;
        uint64 valueComputeAlgHash;
        bytes32 r;
        bytes32 s;
        uint8 v;
        uint64 timestampNs;
    }

    function getTemporalNumericValueUnsafeV1(bytes32 assetId) 
        external 
        view 
        returns (TemporalNumericValue memory);

    function getTemporalNumericValueV1(bytes32 assetId) 
        external 
        view 
        returns (TemporalNumericValue memory);

    function updateTemporalNumericValuesV1(TemporalNumericValueInput[] calldata inputs) external;
}
