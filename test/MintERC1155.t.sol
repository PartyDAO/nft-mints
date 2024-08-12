// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { TestBase } from "./util/TestBase.t.sol";
import { MintERC1155 } from "src/MintERC1155.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { LintJSON } from "./util/LintJSON.t.sol";
import { MockERC1155Receiver } from "utils/MockERC1155Receiver.sol";
import { EmptyContract } from "utils/EmptyContract.sol";

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
        token.initialize(address(this), "My Token Name", "image here", "This is a token", editions, 150);

        assertEq(token.name(), "My Token Name");
        assertEq(token.imageURI(), "image here");
        assertEq(token.description(), "This is a token");
    }

    event ContractURIUpdated();

    function test_initialize_excessEditions() external {
        MintERC1155 impl = new MintERC1155(address(this));

        MintERC1155.Attribute[] memory attributes = new MintERC1155.Attribute[](1);
        attributes[0] = MintERC1155.Attribute({ traitType: "traitType", value: "value" });

        MintERC1155.Edition[] memory editions = new MintERC1155.Edition[](26);

        token = MintERC1155(Clones.clone(address(impl)));

        vm.expectRevert(MintERC1155.MintERC1155_ExcessEditions.selector);
        token.initialize(address(this), "My Token Name", "image here", "This is a token", editions, 150);
    }

    function test_setContractInfo() external {
        vm.expectEmit(true, true, true, true);
        emit ContractURIUpdated();
        token.setContractInfo("MyTestContract", "https://example.com/image.png", "New description", address(this), 100);

        assertEq(token.name(), "MyTestContract");
        assertEq(token.imageURI(), "https://example.com/image.png");
        assertEq(token.description(), "New description");

        (address royaltyReceiver, uint256 royalties) = token.royaltyInfo(0, 1 ether);
        assertEq(royaltyReceiver, address(this));
        assertEq(royalties, 0.01 ether);

        _lintJSON(token.contractURI());
    }

    function test_initialize_percentChance0() external {
        MintERC1155.Edition[] memory editions = new MintERC1155.Edition[](1);
        editions[0] = MintERC1155.Edition({
            name: "Edition 1",
            imageURI: "https://example.com/image1.png",
            percentChance: 0,
            attributes: new MintERC1155.Attribute[](0)
        });

        MintERC1155 impl = new MintERC1155(address(this));
        MintERC1155 newToken = MintERC1155(Clones.clone(address(impl)));

        vm.expectRevert(MintERC1155.MintERC1155_PercentChance0.selector);
        newToken.initialize(address(this), "", "", "", editions, 150);
    }

    function test_initialize_totalPercentChanceNot100() external {
        MintERC1155.Edition[] memory editions = new MintERC1155.Edition[](1);
        editions[0] = MintERC1155.Edition({
            name: "Edition 1",
            imageURI: "https://example.com/image1.png",
            percentChance: 95,
            attributes: new MintERC1155.Attribute[](0)
        });

        MintERC1155 impl = new MintERC1155(address(this));
        MintERC1155 newToken = MintERC1155(Clones.clone(address(impl)));

        vm.expectRevert(MintERC1155.MintERC1155_TotalPercentChanceNot100.selector);
        newToken.initialize(address(this), "", "", "", editions, 150);
    }

    function test_mintBatch_unauthorized() external {
        vm.expectRevert(MintERC1155.MintERC1155_Unauthorized.selector);
        vm.prank(_randomAddress());
        token.mintBatch(address(this), new uint256[](0), new uint256[](0));
    }

    function test_totalEditions() external view {
        assertEq(token.totalEditions(), 2);
    }

    function test_uri_lintJSON() external {
        _lintJSON(token.uri(1));
        _lintJSON(token.uri(2));
    }

    function test_safeTransferAcceptanceCheckOnMint_single() external {
        // Receiver should accept ERC1155 tokens
        address receiver = address(new MockERC1155Receiver());
        assertTrue(token.safeTransferAcceptanceCheckOnMint(receiver));

        // Non-receiver should not accept ERC1155 tokens
        address nonReceiver = address(new EmptyContract());
        assertFalse(token.safeTransferAcceptanceCheckOnMint(nonReceiver));

        // EOA should accept ERC1155 tokens
        address eoa = vm.addr(1);
        assertTrue(token.safeTransferAcceptanceCheckOnMint(eoa));
    }

    function test_safeTransferAcceptanceCheckOnMint_batch() external {
        // Receiver should accept ERC1155 tokens
        address receiver = address(new MockERC1155Receiver());
        assertTrue(token.safeTransferAcceptanceCheckOnMint(receiver));

        // Non-receiver should not accept ERC1155 tokens
        address nonReceiver = address(new EmptyContract());
        assertFalse(token.safeTransferAcceptanceCheckOnMint(nonReceiver));

        // EOA should accept ERC1155 tokens
        address eoa = vm.addr(1);
        assertTrue(token.safeTransferAcceptanceCheckOnMint(eoa));
    }
}
