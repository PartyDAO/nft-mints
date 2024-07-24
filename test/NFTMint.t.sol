// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { TestBase } from "./util/TestBase.t.sol";
import { NFTMint } from "src/NFTMint.sol";
import { DropERC1155 } from "src/DropERC1155.sol";

contract NFTMintTest is TestBase {
    NFTMint nftMint;

    function setUp() external {
        nftMint = new NFTMint(address(this));
    }

    function test_createDrop() public returns (DropERC1155) {
        DropERC1155.Attribute[] memory attributes = new DropERC1155.Attribute[](1);
        attributes[0] = DropERC1155.Attribute({ traitType: "traitType", value: "value" });

        DropERC1155.Edition[] memory editions = new DropERC1155.Edition[](2);
        editions[0] = DropERC1155.Edition({
            name: "Edition 1",
            imageURI: "https://example.com/image1.png",
            percentChance: 80,
            attributes: attributes
        });
        editions[1] = DropERC1155.Edition({
            name: "Edition 2",
            imageURI: "https://example.com/image2.png",
            percentChance: 20,
            attributes: new DropERC1155.Attribute[](0)
        });

        NFTMint.DropArgs memory dropArgs = NFTMint.DropArgs({
            maxMints: 100,
            editions: editions,
            allowlistMerkleRoot: bytes32(0),
            pricePerMint: 0.01 ether,
            perWalletLimit: 100,
            feePerMint: 0.001 ether,
            owner: payable(address(this)),
            feeRecipient: payable(address(this))
        });

        return nftMint.createDrop(dropArgs);
    }

    function test_mint() public {
        DropERC1155 drop = test_createDrop();
        address minter = _randomAddress();

        vm.deal(minter, 10 ether);
        vm.prank(minter);
        nftMint.mint{ value: 1.1 ether }(drop, 100, new bytes32[](0));

        vm.roll(block.number + 1);
        nftMint.fillOrders(0);
    }

    function test_fillOrders() external {
        test_mint();
        nftMint.fillOrders(0);
    }

    receive() external payable { }
}
