// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { Test } from "forge-std/src/Test.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract LintJSON is Test {
    uint256 private salt;

    constructor() {
        salt = uint256(keccak256(abi.encodePacked(address(this), block.number)));
    }

    function _lintJSON(string memory json) internal {
        if (vm.envOr("COVERAGE", false)) {
            // Don't check if we're running coverage
            return;
        }

        string memory filePath = string.concat("./out/lint-json-", Strings.toHexString(salt++), ".json");

        vm.writeFile(filePath, json);
        string[] memory inputs = new string[](4);
        inputs[0] = "npx";
        inputs[1] = "ts-node";
        inputs[2] = "./utils/lint-json.ts";
        inputs[3] = filePath;
        bytes memory ffiResp = vm.ffi(inputs);

        uint256 resAsInt;
        assembly {
            resAsInt := mload(add(ffiResp, 0x20))
        }
        if (resAsInt != 1) {
            revert("JSON lint failed");
        }
    }
}
