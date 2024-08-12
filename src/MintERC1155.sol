// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ERC2981Upgradeable } from "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import { LibString } from "solady/src/utils/LibString.sol";

/// @custom:security-contact security@partydao.org
contract MintERC1155 is ERC1155Upgradeable, OwnableUpgradeable, ERC2981Upgradeable {
    error MintERC1155_Unauthorized();
    error MintERC1155_TotalPercentChanceNot100();
    error MintERC1155_PercentChance0();
    error MintERC1155_ExcessEditions();

    event ContractURIUpdated();

    // Represents an attribute of an edition
    struct Attribute {
        // The type of the trait (e.g., "color", "size")
        string traitType;
        // The value of the trait (e.g., "red", "large")
        string value;
    }

    // Represents an edition of tokens
    struct Edition {
        // The name of the edition
        string name;
        // The URI of the image associated with the edition
        string imageURI;
        // The percent chance of minting this edition
        uint256 percentChance;
        // The attributes associated with this edition
        Attribute[] attributes;
    }

    /// @notice The address that can mint tokens
    address public immutable MINTER;

    /// @notice Editions for this contract
    Edition[] public editions;
    /// @notice Contract level name for `contractURI`
    string public name;
    /// @notice Contract level image for `contractURI`
    string public imageURI;
    /// @notice Contract level description for `contractURI`
    string public description;

    constructor(address minter) {
        _disableInitializers();
        MINTER = minter;
    }

    function initialize(
        address owner_,
        string calldata name_,
        string calldata imageURI_,
        string calldata description_,
        Edition[] calldata editions_,
        uint16 royaltyAmountBps
    )
        external
        initializer
    {
        {
            if (editions_.length > 25) {
                revert MintERC1155_ExcessEditions();
            }

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
        }

        name = name_;
        imageURI = imageURI_;
        description = description_;
        __Ownable_init(owner_);
        _setDefaultRoyalty(owner_, royaltyAmountBps);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts) external {
        if (msg.sender != MINTER) {
            revert MintERC1155_Unauthorized();
        }
        _mintBatch(to, ids, amounts, "");
    }

    function totalEditions() external view returns (uint256) {
        return editions.length;
    }

    function getAllEditions() external view returns (Edition[] memory) {
        Edition[] memory allEditions = new Edition[](editions.length);
        for (uint256 i = 0; i < editions.length; i++) {
            allEditions[i] = editions[i];
        }
        return allEditions;
    }

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

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC1155Upgradeable, ERC2981Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

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

    /**
     * @notice Check if the given address can receive tokens from this contract
     * @param to Address to check if receiving tokens is safe
     */
    function safeBatchTransferAcceptanceCheckOnMint(address to) external view returns (bool) {
        uint256[] memory idOrAmountArray = new uint256[](1);
        idOrAmountArray[0] = 1;

        bytes memory callData = abi.encodeCall(
            IERC1155Receiver.onERC1155BatchReceived, (MINTER, address(0), idOrAmountArray, idOrAmountArray, "")
        );

        if (to.code.length > 0) {
            (bool success, bytes memory res) = to.staticcall{ gas: 400_000 }(callData);
            if (success) {
                bytes4 response = abi.decode(res, (bytes4));
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    return false;
                }
            } else {
                return false;
            }
        }
        return true;
    }

    function VERSION() external pure returns (string memory) {
        return "0.1.5";
    }
}
