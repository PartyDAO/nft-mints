// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { TestBase } from "./util/TestBase.t.sol";
import { NFTMint } from "src/NFTMint.sol";
import { MintERC1155 } from "src/MintERC1155.sol";

contract NFTMintTest is TestBase {
    NFTMint nftMint;

    function setUp() external {
        nftMint = new NFTMint(address(this));
    }

    function test_createMint() public returns (MintERC1155) {
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

        NFTMint.MintArgs memory mintArgs = NFTMint.MintArgs({
            maxMints: 110,
            editions: editions,
            allowlistMerkleRoot: bytes32(0),
            pricePerMint: 0.01 ether,
            perWalletLimit: 105,
            feePerMint: 0.001 ether,
            owner: payable(address(this)),
            feeRecipient: payable(address(this)),
            name: "My Token Name",
            imageURI: "image here",
            description: "This is a description"
        });

        return nftMint.createMint(mintArgs);
    }

    event OrderPlaced(
        MintERC1155 indexed mint, uint256 indexed orderId, address indexed to, uint256 amount, string comment
    );

    function test_order() public returns (MintERC1155, address) {
        MintERC1155 mint = test_createMint();
        address minter = _randomAddress();

        vm.deal(minter, 10 ether);
        vm.prank(minter);
        vm.expectEmit(true, true, true, true);
        emit OrderPlaced(mint, 0, minter, 100, "Fist order!");

        nftMint.order{ value: 1.1 ether }(mint, 100, "Fist order!", new bytes32[](0));

        return (mint, minter);
    }

    function test_order_order101_exceedsMaxOrderAmountPerTx() external {
        MintERC1155 mint = test_createMint();

        address minter = _randomAddress();

        vm.deal(minter, 10 ether);
        vm.prank(minter);

        vm.expectRevert(NFTMint.NFTMint_ExceedsMaxOrderAmountPerTx.selector);
        nftMint.order{ value: 1.1 ether }(mint, 101, "", new bytes32[](0));
    }

    function test_order_exceedsWalletLimit() external {
        MintERC1155 mint = test_createMint();

        address minter = _randomAddress();

        vm.deal(minter, 10 ether);
        vm.startPrank(minter);

        nftMint.order{ value: 1.1 ether }(mint, 100, "", new bytes32[](0));
        vm.expectRevert(NFTMint.NFTMint_ExceedsWalletLimit.selector);
        nftMint.order{ value: 0.066 ether }(mint, 6, "", new bytes32[](0));
    }

    function test_order_placeTwoOrders() external {
        MintERC1155 mint = test_createMint();

        address minter = _randomAddress();

        vm.deal(minter, 10 ether);
        vm.startPrank(minter);

        vm.expectEmit(true, true, true, true);
        emit OrderPlaced(mint, 0, minter, 10, "Fist order!");
        nftMint.order{ value: 0.11 ether }(mint, 10, "Fist order!", new bytes32[](0));

        vm.expectEmit(true, true, true, true);
        emit OrderPlaced(mint, 1, minter, 10, "Second order!");
        nftMint.order{ value: 0.11 ether }(mint, 10, "Second order!", new bytes32[](0));
        vm.stopPrank();

        nftMint.fillOrders(0);
    }

    function test_order_insufficientValue() external {
        MintERC1155 mint = test_createMint();

        address minter = _randomAddress();

        vm.deal(minter, 10 ether);
        vm.prank(minter);

        vm.expectRevert(NFTMint.NFTMint_InsufficientValue.selector);
        nftMint.order{ value: 0.01 ether }(mint, 1, "", new bytes32[](0));
    }

    function test_order_refundExcess() external {
        MintERC1155 mint = test_createMint();

        address minter = _randomAddress();

        vm.deal(minter, 0.013 ether);
        vm.prank(minter);

        nftMint.order{ value: 0.013 ether }(mint, 1, "", new bytes32[](0));

        assertEq(minter.balance, 0.002 ether);
    }

    event OrderFilled(
        MintERC1155 indexed mint, uint256 indexed orderId, address indexed to, uint256 amount, uint256[] amounts
    );

    function test_fillOrders() external {
        vm.roll(block.number + 1);
        (MintERC1155 mint, address minter) = test_order();

        // Not checking data because token amounts is inherently random
        vm.expectEmit(true, true, true, false);
        emit OrderFilled(mint, 0, minter, 100, new uint256[](0));
        nftMint.fillOrders(0);
    }

    receive() external payable { }
}
