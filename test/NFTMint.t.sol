// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { TestBase } from "./util/TestBase.t.sol";
import { NFTMint } from "src/NFTMint.sol";
import { MintERC1155 } from "src/MintERC1155.sol";
import { Vm } from "forge-std/src/Test.sol";
import { MockFailingRecipient } from "./util/MockFailingRecipient.sol";

contract NFTMintTest is TestBase {
    NFTMint nftMint;
    address feeRecipient = vm.createWallet("feeRecipient").addr;

    function setUp() external {
        nftMint = new NFTMint(address(this), feeRecipient);
    }

    function test_createMint() public returns (MintERC1155) {
        MintERC1155.Attribute[] memory attributes = new MintERC1155.Attribute[](1);
        attributes[0] = MintERC1155.Attribute({ traitType: "traitType", value: "value" });

        MintERC1155.Edition[] memory editions = new MintERC1155.Edition[](3);
        editions[0] = MintERC1155.Edition({
            name: "Edition 1",
            imageURI: "https://example.com/image1.png",
            percentChance: 80,
            attributes: attributes
        });
        editions[1] = MintERC1155.Edition({
            name: "Edition 2",
            imageURI: "https://example.com/image2.png",
            percentChance: 15,
            attributes: new MintERC1155.Attribute[](0)
        });
        editions[2] = MintERC1155.Edition({
            name: "Edition 3",
            imageURI: "https://example.com/image2.png",
            percentChance: 5,
            attributes: new MintERC1155.Attribute[](0)
        });

        NFTMint.MintArgs memory mintArgs = NFTMint.MintArgs({
            mintExpiration: uint40(block.timestamp + 1 days),
            maxMints: 110,
            editions: editions,
            allowlistMerkleRoot: bytes32(0),
            pricePerMint: 0.01 ether,
            perWalletLimit: 105,
            feePerMint: 0.001 ether,
            owner: payable(address(this)),
            name: "My Token Name",
            imageURI: "image here",
            description: "This is a description",
            royaltyAmountBps: 150
        });

        return nftMint.createMint(mintArgs);
    }

    function test_createMint_invalidExpiration() external {
        MintERC1155.Attribute[] memory attributes = new MintERC1155.Attribute[](1);
        attributes[0] = MintERC1155.Attribute({ traitType: "traitType", value: "value" });

        MintERC1155.Edition[] memory editions = new MintERC1155.Edition[](1);
        editions[0] = MintERC1155.Edition({
            name: "Edition 1",
            imageURI: "https://example.com/image1.png",
            percentChance: 100,
            attributes: attributes
        });

        NFTMint.MintArgs memory mintArgs = NFTMint.MintArgs({
            mintExpiration: 1 days,
            maxMints: 110,
            editions: editions,
            allowlistMerkleRoot: bytes32(0),
            pricePerMint: 0.01 ether,
            perWalletLimit: 105,
            feePerMint: 0.001 ether,
            owner: payable(address(this)),
            name: "My Token Name",
            imageURI: "image here",
            description: "This is a description",
            royaltyAmountBps: 150
        });

        vm.expectRevert(NFTMint.NFTMint_InvalidExpiration.selector);
        nftMint.createMint(mintArgs);
    }

    function test_createMint_invalidPerWalletLimit() external {
        MintERC1155.Attribute[] memory attributes = new MintERC1155.Attribute[](1);
        attributes[0] = MintERC1155.Attribute({ traitType: "traitType", value: "value" });

        MintERC1155.Edition[] memory editions = new MintERC1155.Edition[](1);
        editions[0] = MintERC1155.Edition({
            name: "Edition 1",
            imageURI: "https://example.com/image1.png",
            percentChance: 100,
            attributes: attributes
        });

        NFTMint.MintArgs memory mintArgs = NFTMint.MintArgs({
            mintExpiration: uint40(block.timestamp + 1 days),
            maxMints: 110,
            editions: editions,
            allowlistMerkleRoot: bytes32(0),
            pricePerMint: 0.01 ether,
            perWalletLimit: 0,
            feePerMint: 0.001 ether,
            owner: payable(address(this)),
            name: "My Token Name",
            imageURI: "image here",
            description: "This is a description",
            royaltyAmountBps: 150
        });

        vm.expectRevert(NFTMint.NFTMint_InvalidPerWalletLimit.selector);
        nftMint.createMint(mintArgs);
    }

    function test_createMint_invalidMaxMints() external {
        MintERC1155.Attribute[] memory attributes = new MintERC1155.Attribute[](1);
        attributes[0] = MintERC1155.Attribute({ traitType: "traitType", value: "value" });

        MintERC1155.Edition[] memory editions = new MintERC1155.Edition[](1);
        editions[0] = MintERC1155.Edition({
            name: "Edition 1",
            imageURI: "https://example.com/image1.png",
            percentChance: 100,
            attributes: attributes
        });

        NFTMint.MintArgs memory mintArgs = NFTMint.MintArgs({
            mintExpiration: uint40(block.timestamp + 1 days),
            maxMints: 0,
            editions: editions,
            allowlistMerkleRoot: bytes32(0),
            pricePerMint: 0.01 ether,
            perWalletLimit: 1,
            feePerMint: 0.001 ether,
            owner: payable(address(this)),
            name: "My Token Name",
            imageURI: "image here",
            description: "This is a description",
            royaltyAmountBps: 150
        });

        vm.expectRevert(NFTMint.NFTMint_InvalidMaxMints.selector);
        nftMint.createMint(mintArgs);
    }

    function test_createMint_invalidOwner() external {
        MintERC1155.Attribute[] memory attributes = new MintERC1155.Attribute[](1);
        attributes[0] = MintERC1155.Attribute({ traitType: "traitType", value: "value" });

        MintERC1155.Edition[] memory editions = new MintERC1155.Edition[](1);
        editions[0] = MintERC1155.Edition({
            name: "Edition 1",
            imageURI: "https://example.com/image1.png",
            percentChance: 100,
            attributes: attributes
        });

        NFTMint.MintArgs memory mintArgs = NFTMint.MintArgs({
            mintExpiration: uint40(block.timestamp + 1 days),
            maxMints: 1,
            editions: editions,
            allowlistMerkleRoot: bytes32(0),
            pricePerMint: 0.01 ether,
            perWalletLimit: 1,
            feePerMint: 0.001 ether,
            owner: payable(address(0)),
            name: "My Token Name",
            imageURI: "image here",
            description: "This is a description",
            royaltyAmountBps: 150
        });

        vm.expectRevert(NFTMint.NFTMint_InvalidOwner.selector);
        nftMint.createMint(mintArgs);
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

        vm.expectRevert(NFTMint.NFTMint_InvalidAmount.selector);
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

    function test_order_buyerCantReceiveERC1155() external {
        MintERC1155 mint = test_createMint();

        vm.expectRevert(NFTMint.NFTMint_BuyerNotAcceptingERC1155.selector);
        nftMint.order{ value: 0.011 ether }(mint, 1, "", new bytes32[](0));
    }

    function test_order_mintExpired() external {
        MintERC1155 mint = test_createMint();

        address minter = _randomAddress();

        vm.deal(minter, 10 ether);
        vm.prank(minter);

        skip(2 days);
        vm.expectRevert(NFTMint.NFTMint_MintExpired.selector);
        nftMint.order{ value: 0.011 ether }(mint, 1, "", new bytes32[](0));
    }

    function test_order_invalidAmount() external {
        MintERC1155 mint = test_createMint();

        address minter = _randomAddress();

        vm.deal(minter, 10 ether);
        vm.prank(minter);

        vm.expectRevert(NFTMint.NFTMint_InvalidAmount.selector);
        nftMint.order{ value: 0.01 ether }(mint, 0, "", new bytes32[](0));
    }

    function test_order_invalidMerkleProof() external {
        MintERC1155.Attribute[] memory attributes = new MintERC1155.Attribute[](1);
        attributes[0] = MintERC1155.Attribute({ traitType: "traitType", value: "value" });

        MintERC1155.Edition[] memory editions = new MintERC1155.Edition[](1);
        editions[0] = MintERC1155.Edition({
            name: "Edition 1",
            imageURI: "https://example.com/image1.png",
            percentChance: 100,
            attributes: attributes
        });

        address minter1 = _randomAddress();
        address minter2 = _randomAddress();

        vm.deal(minter1, 10 ether);
        vm.deal(minter2, 10 ether);

        bytes32 allowlistMerkleRoot = keccak256(abi.encodePacked(minter1));
        NFTMint.MintArgs memory mintArgs = NFTMint.MintArgs({
            mintExpiration: uint40(block.timestamp + 1 days),
            maxMints: 110,
            editions: editions,
            allowlistMerkleRoot: allowlistMerkleRoot,
            pricePerMint: 0.01 ether,
            perWalletLimit: 105,
            feePerMint: 0.001 ether,
            owner: payable(address(this)),
            name: "My Token Name",
            imageURI: "image here",
            description: "This is a description",
            royaltyAmountBps: 150
        });

        MintERC1155 mint = nftMint.createMint(mintArgs);

        vm.prank(minter1);
        nftMint.order{ value: 0.011 ether }(mint, 1, "", new bytes32[](0));

        vm.prank(minter2);
        vm.expectRevert(NFTMint.NFTMint_InvalidMerkleProof.selector);
        nftMint.order{ value: 0.011 ether }(mint, 1, "", new bytes32[](0));
    }

    function test_order_failedToTransferFunds() external {
        MintERC1155.Attribute[] memory attributes = new MintERC1155.Attribute[](1);
        attributes[0] = MintERC1155.Attribute({ traitType: "traitType", value: "value" });

        MintERC1155.Edition[] memory editions = new MintERC1155.Edition[](1);
        editions[0] = MintERC1155.Edition({
            name: "Edition 1",
            imageURI: "https://example.com/image1.png",
            percentChance: 100,
            attributes: attributes
        });

        address minter = address(new MockFailingRecipient());

        vm.deal(minter, 10 ether);
        vm.prank(minter);

        // Set feeRecipient to an address that will fail to receive funds
        NFTMint.MintArgs memory mintArgs = NFTMint.MintArgs({
            mintExpiration: uint40(block.timestamp + 1 days),
            maxMints: 110,
            editions: editions,
            allowlistMerkleRoot: bytes32(0),
            pricePerMint: 0.01 ether,
            perWalletLimit: 105,
            feePerMint: 0.001 ether,
            owner: payable(address(this)),
            name: "My Token Name",
            imageURI: "image here",
            description: "This is a description",
            royaltyAmountBps: 150
        });

        MintERC1155 mint = nftMint.createMint(mintArgs);

        vm.expectRevert(NFTMint.NFTMint_FailedToTransferFunds.selector);
        vm.prank(minter);
        nftMint.order{ value: 0.012 ether }(mint, 1, "", new bytes32[](0));
    }

    event OrderFilled(
        MintERC1155 indexed mint, uint256 indexed orderId, address indexed to, uint256 amount, uint256[] amounts
    );

    function test_fillOrders(uint96 blocksToSkip) external {
        vm.roll(block.number + blocksToSkip);
        (MintERC1155 mint, address minter) = test_order();
        skip(1);

        // Not checking data because token amounts is inherently random
        vm.expectEmit(true, true, true, false);
        emit OrderFilled(mint, 0, minter, 5, new uint256[](0));
        vm.recordLogs();
        nftMint.fillOrders(0);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter != address(mint)) {
                continue;
            }
            bytes32 singleTransferLog0 =
                keccak256(abi.encodePacked("TransferSingle(address,address,address,uint256,uint256)"));
            bytes32 batchTransferLog0 =
                keccak256(abi.encodePacked("TransferBatch(address,address,address,uint256[],uint256[])"));

            if (logs[i].topics[0] != singleTransferLog0 && logs[i].topics[0] != batchTransferLog0) {
                revert("No transfer event found");
            }

            if (logs[i].topics[0] == singleTransferLog0) {
                (, uint256 amount) = abi.decode(logs[i].data, (uint256, uint256));
                assertEq(amount, 100);
            }
            if (logs[i].topics[0] == batchTransferLog0) {
                (, uint256[] memory amounts) = abi.decode(logs[i].data, (uint256[], uint256[]));

                uint256 sumAmounts = 0;
                for (uint256 j = 0; j < amounts.length; j++) {
                    sumAmounts += amounts[j];
                }

                assertEq(sumAmounts, 100);
            }
        }
    }

    function test_fillOrdersPublic(address filler) external {
        vm.assume(address(this) != filler);

        (MintERC1155 mint, address minter) = test_order();

        vm.startPrank(filler);
        nftMint.fillOrders(0);
        assertEq(nftMint.nextOrderIdToFill(), 0);

        skip(1 hours);
        vm.expectEmit(true, true, true, false);
        emit OrderFilled(mint, 0, minter, 5, new uint256[](0));
        nftMint.fillOrders(0);

        assertEq(nftMint.nextOrderIdToFill(), 1);
    }

    function test_fillOrders_insufficientGas() external {
        MintERC1155 mint = test_createMint();

        address minter = _randomAddress();
        vm.deal(minter, 10 ether);
        vm.prank(minter);
        nftMint.order{ value: 1.1 ether }(mint, 100, "Test order", new bytes32[](0));

        skip(1 days);
        // Simulate low gas scenario
        vm.startPrank(address(this));
        vm.expectRevert(NFTMint.NFTMint_InsufficientGas.selector);
        nftMint.fillOrders{ gas: 500_000 }(0);
        vm.stopPrank();
    }

    receive() external payable { }
}
