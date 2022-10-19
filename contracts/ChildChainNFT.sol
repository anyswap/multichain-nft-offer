// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./AnyCallApp.sol";

contract ChildChain_NFT is ERC721Enumerable, AnyCallApp {
    bytes32 public Method_Claim = keccak256("claim");
    bytes32 public Method_Transfer = keccak256("transfer");

    uint256 mainChain;

    constructor(
        address callProxy,
        uint256 mainChain_,
        string memory name,
        string memory symbol
    ) AnyCallApp(callProxy, 2) ERC721(name, symbol) {
        mainChain = mainChain_;
    }

    function claim(address to, uint256 tokenId) external payable {
        bytes memory data = abi.encode(Method_Claim, to, tokenId, false); // mint not fetch
        _anyCall(peer[mainChain], data, mainChain);
    }

    function claimAndFetch(address to, uint256 tokenId) external payable {
        bytes memory data = abi.encode(Method_Claim, to, tokenId, true); // mint and fetch
        _anyCall(peer[mainChain], data, mainChain);
    }

    function Swapout_no_fallback(
        uint256 toChainID,
        address to,
        uint256 tokenId
    ) public payable {
        _burn(tokenId);
        bytes memory data = abi.encode(Method_Transfer, to, tokenId, false);
        _anyCall_no_fallback(peer[mainChain], data, toChainID);
    }

    function _anyExecute(uint256 fromChainID, bytes calldata data)
        internal
        override
        returns (bool success, bytes memory result)
    {
        (bytes32 method, address to, uint256 tokenId, bool sendBack) = abi.decode(
            data,
            (bytes32, address, uint256, bool)
        );
        if (method == Method_Transfer) {
            _mint(to, tokenId);
        }
    }

    function _anyFallback(bytes memory data)
        internal
        override
        returns (bool success, bytes memory result)
    {
        (bytes32 method, address to, uint256 tokenId, bool sendBack) = abi.decode(
            data,
            (bytes32, address, uint256, bool)
        );
        if (method == Method_Claim) {
            // revert claim
        }
        if (method == Method_Transfer) {
            // revert transfer
        }
        return (true, "");
    }
}
