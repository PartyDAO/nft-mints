// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { DropERC1155 } from "./DropERC1155.sol";

contract NFTMint is Ownable {
    struct DropArgs {
        uint256 maxMints;
        DropERC1155.Edition[] editions;
        bytes32 allowlistMerkleRoot;
        uint256 pricePerMint;
        uint256 perWalletLimit;
        uint256 feePerMint;
        address payable owner;
        address payable feeRecipient;
    }

    struct DropInfo {
        uint256 pricePerMint;
        uint256 feePerMint;
        address payable owner;
        address payable feeRecipient;
        uint256 perWalletLimit;
        uint256 remainingMints;
        bytes32 allowlistMerkleRoot;
        mapping(address => uint256) mintedPerWallet;
    }

    struct Order {
        address to;
        DropERC1155 drop;
        uint256 amount;
    }

    address public immutable DROP_NFT_LOGIC;

    mapping(DropERC1155 => DropInfo) public drops;
    Order[] public orders;
    uint256 public nextOrderIdToFill;

    event DropCreated(DropERC1155 indexed drop, DropArgs args);
    event NFTMinted(DropERC1155 indexed drop, address indexed to, uint256 indexed tokenId);
    event NFTRevealed(DropERC1155 indexed drop, uint256 indexed tokenId, uint256 indexed editionId);
    event DropClaimed(DropERC1155 indexed drop, address indexed to, uint256 amount);

    constructor(address owner_) Ownable(owner_) {
        DROP_NFT_LOGIC = address(new DropERC1155(address(this)));
    }

    function createDrop(DropArgs memory args) external returns (DropERC1155 drop) {
        drop = DropERC1155(Clones.clone(DROP_NFT_LOGIC));
        drop.initialize(address(this), args.editions);

        DropInfo storage dropInfo = drops[drop];
        dropInfo.owner = args.owner;
        dropInfo.remainingMints = args.maxMints;
        dropInfo.pricePerMint = args.pricePerMint;
        dropInfo.feePerMint = args.feePerMint;
        dropInfo.feeRecipient = args.feeRecipient;
        dropInfo.perWalletLimit = args.perWalletLimit;
        dropInfo.allowlistMerkleRoot = args.allowlistMerkleRoot;

        emit DropCreated(drop, args);
    }

    function mint(DropERC1155 drop, uint256 amount, bytes32[] calldata merkleProof) external payable {
        if (amount > 100) {
            revert("Exceeds max mint amount per tx");
        }

        DropInfo storage dropInfo = drops[drop];

        uint256 modifiedAmount = Math.min(amount, dropInfo.remainingMints);
        dropInfo.remainingMints -= modifiedAmount;
        uint256 totalCost = (dropInfo.pricePerMint + dropInfo.feePerMint) * modifiedAmount;

        if (drops[drop].mintedPerWallet[msg.sender] + modifiedAmount > dropInfo.perWalletLimit) {
            revert("Exceeds wallet limit");
        }
        drops[drop].mintedPerWallet[msg.sender] += modifiedAmount;

        require(msg.value >= totalCost, "Incorrect payment amount");

        if (dropInfo.allowlistMerkleRoot != bytes32(0)) {
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            require(MerkleProof.verify(merkleProof, dropInfo.allowlistMerkleRoot, leaf), "Invalid merkle proof");
        }

        orders.push(Order({ to: msg.sender, drop: drop, amount: modifiedAmount }));

        (bool feeSuccess,) = dropInfo.feeRecipient.call{ value: dropInfo.feePerMint * modifiedAmount, gas: 100_000 }("");
        (bool mintProceedsSuccess,) =
            dropInfo.owner.call{ value: dropInfo.pricePerMint * modifiedAmount, gas: 100_000 }("");

        bool refundSuccess = true;
        if (msg.value > totalCost) {
            (refundSuccess,) = payable(msg.sender).call{ value: msg.value - totalCost, gas: 100_000 }("");
        }

        if (!feeSuccess || !mintProceedsSuccess || !refundSuccess) {
            revert("Failed to transfer funds");
        }
    }

    function fillOrders(uint256 numOrdersToFill) external onlyOwner {
        uint256 nonce = 0;
        uint256 nextOrderIdToFill_ = nextOrderIdToFill;
        uint256 finalNextOrderToFill =
            numOrdersToFill == 0 ? orders.length : Math.min(orders.length, nextOrderIdToFill_ + numOrdersToFill);

        while (nextOrderIdToFill_ < finalNextOrderToFill) {
            Order storage order = orders[nextOrderIdToFill_];
            DropERC1155.Edition[] memory editions = order.drop.getAllEditions();

            uint256[] memory ids = new uint256[](editions.length);
            uint256[] memory amounts = new uint256[](editions.length);

            for (uint256 i = 0; i < editions.length; i++) {
                ids[i] = i + 1;
            }

            for (uint256 i = 0; i < order.amount; i++) {
                uint256 roll = uint256(keccak256(abi.encodePacked(nonce++, blockhash(block.number - 1)))) % 100;

                uint256 cumulativeChance = 0;
                for (uint256 j = 0; j < editions.length; j++) {
                    cumulativeChance += editions[j].percentChance;
                    if (roll < cumulativeChance) {
                        amounts[j]++;
                        break;
                    }
                }
            }

            // If the mint fails with 500_000 gas, the order is still marked as filled.
            try order.drop.mintBatch{ gas: 500_000 }(order.to, ids, amounts) { } catch { }
            delete orders[nextOrderIdToFill_];
            nextOrderIdToFill_++;
        }

        nextOrderIdToFill = nextOrderIdToFill_;
    }

    function VERSION() external pure returns (string memory) {
        return "1.0.0";
    }
}
