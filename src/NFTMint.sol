// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { MintERC1155 } from "./MintERC1155.sol";

/// @custom:security-contact security@partydao.org
contract NFTMint is Ownable {
    error NFTMint_ExceedsWalletLimit();
    error NFTMint_InsufficientValue();
    error NFTMint_InvalidMerkleProof();
    error NFTMint_FailedToTransferFunds();
    error NFTMint_BuyerNotAcceptingERC1155();
    error NFTMint_MintExpired();
    error NFTMint_InvalidAmount();
    error NFTMint_InvalidExpiration();
    error NFTMint_InvalidPerWalletLimit();
    error NFTMint_InvalidMaxMints();
    error NFTMint_InvalidOwner();
    error NFTMint_InvalidFeeRecipient();

    event MintCreated(MintERC1155 indexed mint, MintArgs args);
    event OrderPlaced(
        MintERC1155 indexed mint, uint256 indexed orderId, address indexed to, uint256 amount, string comment
    );
    event OrderFilled(
        MintERC1155 indexed mint, uint256 indexed orderId, address indexed to, uint256 amount, uint256[] amounts
    );

    //  Arguments required to create a new mint
    struct MintArgs {
        // Price per mint in wei
        uint96 pricePerMint;
        // Fee per mint in wei
        uint96 feePerMint;
        // Address of the owner of the mint
        address payable owner;
        // Address to receive the fee
        address payable feeRecipient;
        // Timestamp when the mint expires
        uint40 mintExpiration;
        // Merkle root for the allowlist
        bytes32 allowlistMerkleRoot;
        // Maximum mints allowed per wallet
        uint32 perWalletLimit;
        // Maximum number of mints for this mint
        uint32 maxMints;
        // Array of editions for this mint
        MintERC1155.Edition[] editions;
        // Name of the mint
        string name;
        // URI of the image for the mint
        string imageURI;
        // Description of the mint
        string description;
        // Royalty amount that goes to owner in basis points
        uint16 royaltyAmountBps;
    }

    // Information about an active mint
    struct MintInfo {
        // Price per mint in wei
        uint96 pricePerMint;
        // Fee per mint in wei
        uint96 feePerMint;
        // Number of mints remaining
        uint32 remainingMints;
        // Maximum mints allowed per wallet
        uint32 perWalletLimit;
        // Timestamp when the mint expires
        uint40 mintExpiration;
        // Address to receive the fee
        address payable feeRecipient;
        // Merkle root for the allowlist
        bytes32 allowlistMerkleRoot;
        // Mapping of addresses to the number of mints they have made
        mapping(address => uint32) mintedPerWallet;
    }

    // Information about an order placed for a mint
    struct Order {
        // Address of the ERC1155 contract for the mint
        MintERC1155 mint;
        // Address to receive the minted tokens
        address to;
        // Timestamp when the order was placed
        uint40 orderTimestamp;
        uint32 amount;
    }

    /// @notice Address of the logic contract for minting NFTs
    address public immutable MINT_NFT_LOGIC;

    /// @notice Next order ID to fill in the `orders` array. All orders before this index have been filled.
    uint96 public nextOrderIdToFill;
    mapping(MintERC1155 => MintInfo) public mints;
    /// @notice Array of all orders placed. Filled orders are deleted.
    Order[] public orders;

    constructor(address owner_) Ownable(owner_) {
        MINT_NFT_LOGIC = address(new MintERC1155(address(this)));
    }

    /**
     * @notice Create a new mint
     * @param args Arguments for the mint
     */
    function createMint(MintArgs memory args) external returns (MintERC1155) {
        if (args.mintExpiration < block.timestamp + 1 minutes) {
            revert NFTMint_InvalidExpiration();
        }
        if (args.perWalletLimit == 0) {
            revert NFTMint_InvalidPerWalletLimit();
        }
        if (args.maxMints == 0) {
            revert NFTMint_InvalidMaxMints();
        }
        if (args.owner == address(0)) {
            revert NFTMint_InvalidOwner();
        }
        if (args.feeRecipient == address(0) && args.feePerMint != 0) {
            revert NFTMint_InvalidFeeRecipient();
        }

        MintERC1155 newMint = MintERC1155(
            Clones.cloneDeterministic(
                MINT_NFT_LOGIC, keccak256(abi.encodePacked(block.chainid, msg.sender, block.timestamp))
            )
        );
        newMint.initialize(args.owner, args.name, args.imageURI, args.description, args.editions, args.royaltyAmountBps);

        MintInfo storage mintInfo = mints[newMint];
        mintInfo.remainingMints = args.maxMints;
        mintInfo.pricePerMint = args.pricePerMint;
        mintInfo.feePerMint = args.feePerMint;
        mintInfo.feeRecipient = args.feeRecipient;
        mintInfo.perWalletLimit = args.perWalletLimit;
        mintInfo.allowlistMerkleRoot = args.allowlistMerkleRoot;
        mintInfo.mintExpiration = args.mintExpiration;

        emit MintCreated(newMint, args);
        return newMint;
    }

    /**
     * @notice Place an order for a mint. The `msg.sender` must be able to receive ERC1155s.
     * @param mint Address of the ERC1155 for the order
     * @param amount Amount of 1155s to order
     * @param comment Optional comment to attach to the order
     * @param merkleProof Merkle proof showing inclusion in the merkle root
     */
    function order(
        MintERC1155 mint,
        uint32 amount,
        string memory comment,
        bytes32[] calldata merkleProof
    )
        external
        payable
    {
        MintInfo storage mintInfo = mints[mint];

        if (mintInfo.mintExpiration < block.timestamp) {
            revert NFTMint_MintExpired();
        }

        uint32 modifiedAmount = uint32(Math.min(amount, mintInfo.remainingMints));
        if (modifiedAmount == 0 || modifiedAmount > 100) {
            revert NFTMint_InvalidAmount();
        }

        mintInfo.remainingMints -= modifiedAmount;
        uint256 totalCost = (mintInfo.pricePerMint + mintInfo.feePerMint) * modifiedAmount;

        if (msg.value < totalCost) {
            revert NFTMint_InsufficientValue();
        }

        if (mints[mint].mintedPerWallet[msg.sender] + modifiedAmount > mintInfo.perWalletLimit) {
            revert NFTMint_ExceedsWalletLimit();
        }
        mints[mint].mintedPerWallet[msg.sender] += modifiedAmount;

        if (mintInfo.allowlistMerkleRoot != bytes32(0)) {
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            if (!MerkleProof.verify(merkleProof, mintInfo.allowlistMerkleRoot, leaf)) {
                revert NFTMint_InvalidMerkleProof();
            }
        }

        if (!mint.safeTransferAcceptanceCheckOnMint(msg.sender)) {
            revert NFTMint_BuyerNotAcceptingERC1155();
        }

        orders.push(
            Order({ to: msg.sender, mint: mint, orderTimestamp: uint40(block.timestamp), amount: modifiedAmount })
        );

        {
            bool feeSuccess = true;
            if (mintInfo.feePerMint > 0) {
                (feeSuccess,) =
                    mintInfo.feeRecipient.call{ value: mintInfo.feePerMint * modifiedAmount, gas: 100_000 }("");
            }
            bool mintProceedsSuccess = true;
            if (mintInfo.pricePerMint > 0) {
                (mintProceedsSuccess,) =
                    mint.owner().call{ value: mintInfo.pricePerMint * modifiedAmount, gas: 100_000 }("");
            }
            bool refundSuccess = true;
            if (msg.value > totalCost) {
                (refundSuccess,) = payable(msg.sender).call{ value: msg.value - totalCost, gas: 100_000 }("");
            }

            if (!feeSuccess || !mintProceedsSuccess || !refundSuccess) {
                revert NFTMint_FailedToTransferFunds();
            }
        }

        emit OrderPlaced(mint, orders.length - 1, msg.sender, modifiedAmount, comment);
    }

    /**
     * @notice Fill pending orders. Orders older than 1 hour are fillable by anyone. Newer orders can only be filled by
     * the owner.
     * @param numOrdersToFill The maximum number of orders to fill. Specify 0 to fill all orders.
     */
    function fillOrders(uint96 numOrdersToFill) external {
        uint256 nonce = 0;
        uint256 nextOrderIdToFill_ = nextOrderIdToFill;
        uint256 finalNextOrderToFill =
            numOrdersToFill == 0 ? orders.length : Math.min(orders.length, nextOrderIdToFill_ + numOrdersToFill);

        while (nextOrderIdToFill_ < finalNextOrderToFill) {
            Order memory currentOrder = orders[nextOrderIdToFill_];
            if (msg.sender != owner() && currentOrder.orderTimestamp + 1 hours > block.timestamp) {
                // Only the owner can fill orders that are less than 1 hour old
                break;
            }
            if (currentOrder.orderTimestamp == block.timestamp) {
                // Don't fill orders in the same block to ensure there is randomness
                break;
            }
            MintERC1155.Edition[] memory editions = currentOrder.mint.getAllEditions();

            uint256[] memory ids = new uint256[](editions.length);
            uint256[] memory amounts = new uint256[](editions.length);

            for (uint256 i = 0; i < editions.length; i++) {
                ids[i] = i + 1;
            }

            for (uint256 i = 0; i < currentOrder.amount; i++) {
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

            emit OrderFilled(currentOrder.mint, nextOrderIdToFill_, currentOrder.to, currentOrder.amount, amounts);

            uint256 numNonZero = 0;
            for (uint256 i = 0; i < editions.length; i++) {
                if (amounts[i] != 0) {
                    if (numNonZero < i) {
                        ids[numNonZero] = ids[i];
                        amounts[numNonZero] = amounts[i];
                    }
                    numNonZero++;
                }
            }

            assembly {
                mstore(ids, numNonZero)
                mstore(amounts, numNonZero)
            }

            delete orders[nextOrderIdToFill_];
            nextOrderIdToFill_++;
            // If the mint fails with 500_000 gas, the order is still marked as filled.
            try currentOrder.mint.mintBatch{ gas: 500_000 }(currentOrder.to, ids, amounts) { } catch { }
        }

        nextOrderIdToFill = uint96(nextOrderIdToFill_);
    }

    function VERSION() external pure returns (string memory) {
        return "0.1.5";
    }
}
