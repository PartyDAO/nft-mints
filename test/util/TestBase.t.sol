// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Test } from "forge-std/src/Test.sol";

contract TestBase is Test {
    uint256 private _nonce;

    constructor() {
        _nonce =
            uint256(keccak256(abi.encode(tx.origin, tx.origin.balance, block.number, block.timestamp, block.coinbase)));
    }

    function _randomBytes32() internal returns (bytes32) {
        bytes memory seed = abi.encode(_nonce++, block.timestamp, gasleft());
        return keccak256(seed);
    }

    function _randomUint256() internal returns (uint256) {
        return uint256(_randomBytes32());
    }

    function _randomAddress() internal returns (address payable) {
        return payable(address(uint160(_randomUint256())));
    }
}
