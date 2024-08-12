// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

contract MockFailingRecipient is IERC1155Receiver {
    bool public receiveERC1155 = true;
    bool public receiveERC1155Batch = true;

    function setReceiveERC1155(bool value) external {
        receiveERC1155 = value;
    }

    function setReceiveERC1155Batch(bool value) external {
        receiveERC1155Batch = value;
    }

    receive() external payable {
        revert("Failed to receive funds");
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    )
        external
        view
        override
        returns (bytes4)
    {
        return receiveERC1155 ? this.onERC1155Received.selector : bytes4(0);
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    )
        external
        view
        override
        returns (bytes4)
    {
        return receiveERC1155Batch ? this.onERC1155BatchReceived.selector : bytes4(0);
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }
}
