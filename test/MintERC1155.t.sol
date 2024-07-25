// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { TestBase } from "./util/TestBase.t.sol";
import { MintERC1155 } from "src/MintERC1155.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { LintJSON } from "./util/LintJSON.t.sol";

contract MintERC1155Test is TestBase, LintJSON {
    MintERC1155 token;

    function setUp() external {
        MintERC1155 impl = new MintERC1155(address(this));

        MintERC1155.Attribute[] memory attributes = new MintERC1155.Attribute[](1);
        attributes[0] = MintERC1155.Attribute({ traitType: "traitType", value: "value" });

        MintERC1155.Edition[] memory editions = new MintERC1155.Edition[](2);
        editions[0] = MintERC1155.Edition({
            name: "Edition 1",
            imageURI: "https://example.com/image1.png",
            percentChance: 80,
            attributes: attributes
        });
        editions[1] = MintERC1155.Edition({
            name: "Edition 2",
            imageURI: "https://example.com/image2.png",
            percentChance: 20,
            attributes: new MintERC1155.Attribute[](0)
        });

        token = MintERC1155(Clones.clone(address(impl)));
        token.initialize(address(this), editions);
    }

    function test_setContractInfo() external {
        token.setContractInfo("MyTestContract", "https://example.com/image.png", address(this), 100);
        assertEq(token.name(), "MyTestContract");
        assertEq(token.imageURI(), "https://example.com/image.png");

        (address royaltyReceiver, uint256 royalties) = token.royaltyInfo(0, 1 ether);
        assertEq(royaltyReceiver, address(this));
        assertEq(royalties, 0.01 ether);

        _lintJSON(token.contractURI());
    }

    function test_uri_lintJSON() external {
        _lintJSON(token.uri(1));
        _lintJSON(token.uri(2));
    }
}