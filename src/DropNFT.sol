// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

contract DropNFT is Initializable, ERC721Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    struct Attribute {
        string traitType;
        string value;
    }

    struct Edition {
        string name;
        string image;
        uint256 percentChance;
        Attribute[] attributes;
    }

    Edition[] public editions;
    mapping(uint256 tokenId => uint256 editionId) public tokenIdToEditionId;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory name_, string memory symbol_, address owner_, Edition[] memory editions_) public initializer {
        __ERC721_init(name_, symbol_);
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();

        // Edition 0 is reserved to indicate that the tokenId has not been revealed
        editions.push(Edition({
            // TODO: Should we be opinionated about what the default editionId 0
            //       returns? If so what should it be?
            name: "Not Revealed!",
            image: "https://placeholder.com",
            percentChance: 0,
            attributes: new Attribute[](0)
        }));

        for (uint256 i = 0; i < editions_.length; i++) {
            editions.push(editions_[i]);
        }
    }

    function mint(address to, uint256 tokenId) external {
        require(msg.sender == owner(), "Only owner can mint");
        _safeMint(to, tokenId);
    }

    function assignEdition(uint256 tokenId, uint256 editionId) external {
        require(msg.sender == owner(), "Only owner can assign edition");
        tokenIdToEditionId[tokenId] = editionId;
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

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        uint256 editionId = tokenIdToEditionId[tokenId];
        require(editionId != 0, "TokenId not revealed");
        Edition memory edition = editions[editionId];

        return string.concat(
            "data:application/json;base64,",
            Base64.encode(
                abi.encodePacked(
                    '{"name":"',
                    // TODO: Confirm with team what name should be
                    edition.name,
                    '", "attributes": [',
                    _generateAttributes(edition),
                    '], "image":"',
                    edition.image,
                    '"}'
                )
            )
        );
    }

    function _generateAttributes(Edition memory edition) private pure returns (string memory) {
        Attribute[] memory attributes = edition.attributes;
        string memory json = "";
        for (uint256 i = 0; i < attributes.length; i++) {
            json = string.concat(
                json,
                '{"trait_type":"',
                attributes[i].traitType,
                '","value":"',
                attributes[i].value,
                '"}'
            );

            // Add comma unless it's the last attribute
            if (i < attributes.length - 1) {
                json = string.concat(json, ',');
            }
        }
        return json;
    }

    function _authorizeUpgrade(address) internal override { }

    function VERSION() external pure returns (string memory) {
        return "1.0.0";
    }
}