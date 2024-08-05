// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { MintERC1155 } from "./MintERC1155.sol";

/// @custom:security-contact security@partydao.org
contract NFTMint is Ownable {
    error NFTMint_ExceedsMaxOrderAmountPerTx();
    error NFTMint_ExceedsWalletLimit();
    error NFTMint_InsufficientValue();
    error NFTMint_InvalidMerkleProof();
    error NFTMint_FailedToTransferFunds();
    error NFTMint_BuyerNotAcceptingERC1155();
    error NFTMint_MintExpired();
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

    struct MintArgs {
        uint96 pricePerMint;
        uint96 feePerMint;
        uint16 royaltyAmountBps;
        address payable owner;
        address payable feeRecipient;
        uint40 mintExpiration;
        bytes32 allowlistMerkleRoot;
        uint32 perWalletLimit;
        uint32 maxMints;
        MintERC1155.Edition[] editions;
        string name;
        string imageURI;
        string description;
    }

    struct MintInfo {
        uint96 pricePerMint;
        uint96 feePerMint;
        uint32 remainingMints;
        uint32 perWalletLimit;
        uint40 mintExpiration;
        address payable owner;
        address payable feeRecipient;
        bytes32 allowlistMerkleRoot;
        mapping(address => uint32) mintedPerWallet;
    }

    struct Order {
        MintERC1155 mint;
        address to;
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
        mintInfo.owner = args.owner;
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
        if (amount > 100) {
            revert NFTMint_ExceedsMaxOrderAmountPerTx();
        }

        MintInfo storage mintInfo = mints[mint];

        if (mintInfo.mintExpiration < block.timestamp) {
            revert NFTMint_MintExpired();
        }

        uint32 modifiedAmount = uint32(Math.min(amount, mintInfo.remainingMints));
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

        if (!mint.safeBatchTransferAcceptanceCheckOnMint(msg.sender)) {
            revert NFTMint_BuyerNotAcceptingERC1155();
        }

        orders.push(
            Order({ to: msg.sender, mint: mint, orderTimestamp: uint40(block.timestamp), amount: modifiedAmount })
        );

        (bool feeSuccess,) = mintInfo.feeRecipient.call{ value: mintInfo.feePerMint * modifiedAmount, gas: 100_000 }("");
        (bool mintProceedsSuccess,) =
            mintInfo.owner.call{ value: mintInfo.pricePerMint * modifiedAmount, gas: 100_000 }("");
        bool refundSuccess = true;
        if (msg.value > totalCost) {
            (refundSuccess,) = payable(msg.sender).call{ value: msg.value - totalCost, gas: 100_000 }("");
        }

        if (!feeSuccess || !mintProceedsSuccess || !refundSuccess) {
            revert NFTMint_FailedToTransferFunds();
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
            Order storage currentOrder = orders[nextOrderIdToFill_];
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

            // If the mint fails with 500_000 gas, the order is still marked as filled.
            try currentOrder.mint.mintBatch{ gas: 500_000 }(currentOrder.to, ids, amounts) { } catch { }
            delete orders[nextOrderIdToFill_];
            nextOrderIdToFill_++;
        }

        nextOrderIdToFill = uint96(nextOrderIdToFill_);
    }

    function VERSION() external pure returns (string memory) {
        return "0.1.5";
    }
}
