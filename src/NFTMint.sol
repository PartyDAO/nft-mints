// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./DropERC1155.sol";

contract NFTMint is Ownable {
    struct DropArgs {
        string uri;
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
        uint256 totalMinted;
        uint256 maxMints;
        bytes32 allowlistMerkleRoot;
        mapping(address => uint256) mintedPerWallet;
    }

    address public immutable DROP_NFT_LOGIC;

    mapping(DropERC1155 => DropInfo) public drops;

    event DropCreated(DropERC1155 indexed drop, DropArgs args);
    event NFTMinted(DropERC1155 indexed drop, address indexed to, uint256 indexed tokenId);
    event NFTRevealed(DropERC1155 indexed drop, uint256 indexed tokenId, uint256 indexed editionId);
    event DropClaimed(DropERC1155 indexed drop, address indexed to, uint256 amount);

    constructor(address dropNftLogic, address owner_) Ownable(owner_) {
        DROP_NFT_LOGIC = dropNftLogic;
    }

    function createDrop(DropArgs memory args)
        external
        returns (DropERC1155 drop)
    {
        // TODO: Validate inputs
        // - Prevent sum of edition percentChance from exceeding 100
        // - Prevent edition percentChance of 0

        drop = DropERC1155(Clones.clone(DROP_NFT_LOGIC));
        drop.initialize(args.uri, address(this), args.editions);

        DropInfo storage dropInfo = drops[drop];
        dropInfo.owner = args.owner;
        dropInfo.maxMints = args.maxMints;
        dropInfo.pricePerMint = args.pricePerMint;
        dropInfo.feePerMint = args.feePerMint;
        dropInfo.feeRecipient = args.feeRecipient;
        dropInfo.perWalletLimit = args.perWalletLimit;
        dropInfo.allowlistMerkleRoot = args.allowlistMerkleRoot;

        emit DropCreated(drop, args);
    }

    function mint(DropERC1155 drop, uint256 amount, bytes32[] calldata merkleProof) external payable {
        DropInfo storage dropInfo = drops[drop];

        require(dropInfo.totalMinted + amount <= dropInfo.maxMints, "Exceeds max supply");
        require(dropInfo.mintedPerWallet[msg.sender] + amount <= dropInfo.perWalletLimit, "Exceeds wallet limit");
        require(msg.value >= (dropInfo.pricePerMint + dropInfo.feePerMint) * amount, "Insufficient payment");

        if (dropInfo.allowlistMerkleRoot != bytes32(0)) {
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            require(MerkleProof.verify(merkleProof, dropInfo.allowlistMerkleRoot, leaf), "Invalid merkle proof");
        }

        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = dropInfo.totalMinted + i;
            drop.mint(msg.sender, tokenId);
            emit NFTMinted(drop, msg.sender, tokenId);
        }

        drops[drop].totalMinted += amount;
        drops[drop].mintedPerWallet[msg.sender] += amount;

        // Transfer fee to fee recipient
        dropInfo.feeRecipient.transfer(dropInfo.feePerMint * amount);
    }

    // TODO: After certain amount of time, allow permissionless reveal?
    function revealMint(DropERC1155 drop, uint256[] memory tokenIds, uint256 seed) external onlyOwner {
        DropERC1155.Edition[] memory editions = drop.getAllEditions();

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            // Prevent revealing the same tokenId multiple times
            require(drop.tokenIdToEditionId(tokenId) == 0, "TokenId already revealed");

            uint256 selectedEditionId = 0;
            uint256 cumulativeChance = 0;
            uint256 roll = uint256(keccak256(abi.encodePacked(tokenId, seed, block.timestamp))) % 100;
            for (uint256 j = 0; j < editions.length; j++) {
                cumulativeChance += editions[j].percentChance;
                if (roll < cumulativeChance) {
                    selectedEditionId = j;

                    drop.assignEdition(tokenId, j);

                    emit NFTRevealed(drop, tokenId, selectedEditionId);
                    break;
                }
            }
        }
    }

    function claimDropPayments(DropERC1155 drop) external returns (uint256 amount) {
        DropInfo storage dropInfo = drops[drop];
        require(dropInfo.owner == msg.sender, "Only drop owner can claim mint payments");

        amount = dropInfo.pricePerMint * dropInfo.totalMinted;
        dropInfo.owner.transfer(amount);

        emit DropClaimed(drop, dropInfo.owner, amount);
    }

    function VERSION() external pure returns (string memory) {
        return "1.0.0";
    }
}
