// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ERC2981Upgradeable } from "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import { LibString } from "solady/src/utils/LibString.sol";

contract MintERC1155 is ERC1155Upgradeable, OwnableUpgradeable, ERC2981Upgradeable {
    error MintERC1155_Unauthorized();
    error MintERC1155_ArityMismatch();
    error MintERC1155_TotalPercentChanceNot100();
    error MintERC1155_PercentChance0();

    event ContractURIUpdated();

    struct Attribute {
        string traitType;
        string value;
    }

    struct Edition {
        string name;
        string imageURI;
        uint256 percentChance;
        Attribute[] attributes;
    }

    /// @notice Address that can mint tokens
    address public immutable MINTER;

    /// @notice Editions for this contract
    Edition[] public editions;
    /// @notice Contract level name for `contractURI`
    string public name;
    /// @notice Contract level image for `contractURI`
    string public imageURI;
    /// @notice Contract level description for `contractURI`
    string public description;

    /**
     * @param minter The constant address assigned to `MINTER`
     */
    constructor(address minter) {
        _disableInitializers();
        MINTER = minter;
    }

    /**
     * @notice Initialize the contract. Must be called on all proxy contracts.
     * @param owner_ The owner of the contract
     * @param name_ The name of the contract
     * @param imageURI_ The image URI of the contract
     * @param description_ The description of the contract
     * @param editions_ The editions of the token contract
     */
    function initialize(
        address owner_,
        string calldata name_,
        string calldata imageURI_,
        string calldata description_,
        Edition[] calldata editions_
    )
        external
        initializer
    {
        uint256 totalPercentChance = 0;
        for (uint256 i = 0; i < editions_.length; i++) {
            editions.push();
            editions[i].name = editions_[i].name;
            editions[i].imageURI = editions_[i].imageURI;
            totalPercentChance += editions[i].percentChance = editions_[i].percentChance;

            if (editions_[i].percentChance == 0) {
                revert MintERC1155_PercentChance0();
            }

            for (uint256 j = 0; j < editions_[i].attributes.length; j++) {
                editions[i].attributes.push(editions_[i].attributes[j]);
            }
        }

        if (totalPercentChance != 100) {
            revert MintERC1155_TotalPercentChanceNot100();
        }

        __Ownable_init(owner_);
        name = name_;
        imageURI = imageURI_;
        description = description_;
        _setDefaultRoyalty(owner_, 150);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts) external {
        if (msg.sender != MINTER) {
            revert MintERC1155_Unauthorized();
        }
        if (ids.length != amounts.length) {
            revert MintERC1155_ArityMismatch();
        }
        _mintBatch(to, ids, amounts, "");
    }

    /**
     * @notice Get the total number of editions
     */
    function totalEditions() external view returns (uint256) {
        return editions.length;
    }

    /**
     * @notice Get all editions
     */
    function getAllEditions() external view returns (Edition[] memory) {
        Edition[] memory allEditions = new Edition[](editions.length);
        for (uint256 i = 0; i < editions.length; i++) {
            allEditions[i] = editions[i];
        }
        return allEditions;
    }

    /**
     * @notice Get the URI for a token id. Fully stored on-chain.
     * @param tokenId The token id to get the URI for
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        Edition memory edition = editions[tokenId - 1];

        string memory json = string.concat(
            '{"name":"',
            LibString.escapeJSON(edition.name),
            '","attributes":',
            _generateAttributes(edition),
            ',"image":"',
            LibString.escapeJSON(edition.imageURI),
            '"}'
        );

        return string.concat("data:application/json;utf8,", json);
    }

    function _generateAttributes(Edition memory edition) private pure returns (string memory) {
        Attribute[] memory attributes = edition.attributes;
        string memory json = "[";
        for (uint256 i = 0; i < attributes.length; i++) {
            json = string.concat(
                json,
                '{"trait_type":"',
                LibString.escapeJSON(attributes[i].traitType),
                '","value":"',
                LibString.escapeJSON(attributes[i].value),
                '"}'
            );

            // Add comma unless it's the last attribute
            if (i < attributes.length - 1) {
                json = string.concat(json, ",");
            }
        }
        json = string.concat(json, "]");
        return json;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Upgradeable, ERC2981Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @notice Set the contract level information. Callable by the owner.
     * @param name_ Name of the contract
     * @param imageURI_ Image URI of the contract
     * @param description_ Description of the contract
     * @param royaltyReceiver Royalty receiver specified by `ERC2981`
     * @param royaltyAmountBps Royalty amount specified by `ERC2981`
     */
    function setContractInfo(
        string memory name_,
        string memory imageURI_,
        string memory description_,
        address royaltyReceiver,
        uint16 royaltyAmountBps
    )
        external
        onlyOwner
    {
        _setDefaultRoyalty(royaltyReceiver, royaltyAmountBps);
        name = name_;
        imageURI = imageURI_;
        description = description_;

        emit ContractURIUpdated();
    }

    function contractURI() external view returns (string memory) {
        string memory json = string.concat(
            '{"name":"',
            LibString.escapeJSON(name),
            '","image":"',
            LibString.escapeJSON(imageURI),
            '","description":"',
            LibString.escapeJSON(description),
            '"}'
        );

        return string.concat("data:application/json;utf8,", json);
    }

    function VERSION() external pure returns (string memory) {
        return "0.1.3";
    }
}
