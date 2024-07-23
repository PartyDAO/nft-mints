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

    constructor(address dropNftLogic, address owner_) Ownable(owner_) {
        DROP_NFT_LOGIC = dropNftLogic;
    }

    function createDrop(DropArgs memory args) external returns (DropERC1155 drop) {
        // TODO: Validate inputs
        // - Prevent sum of edition percentChance from exceeding 100
        // - Prevent edition percentChance of 0

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
        DropInfo storage dropInfo = drops[drop];

        dropInfo.remainingMints -= amount;

        if (drops[drop].mintedPerWallet[msg.sender] + amount > dropInfo.perWalletLimit) {
            revert("Exceeds wallet limit");
        }
        drops[drop].mintedPerWallet[msg.sender] += amount;

        require(msg.value == (dropInfo.pricePerMint + dropInfo.feePerMint) * amount, "Incorrect payment amount");

        if (dropInfo.allowlistMerkleRoot != bytes32(0)) {
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            require(MerkleProof.verify(merkleProof, dropInfo.allowlistMerkleRoot, leaf), "Invalid merkle proof");
        }

        orders.push(Order({ to: msg.sender, drop: drop, amount: amount }));
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

            order.drop.mintBatch(order.to, ids, amounts);
            delete orders[nextOrderIdToFill_];
            nextOrderIdToFill_++;
        }

        nextOrderIdToFill = nextOrderIdToFill_;
    }

    function VERSION() external pure returns (string memory) {
        return "1.0.0";
    }
}
