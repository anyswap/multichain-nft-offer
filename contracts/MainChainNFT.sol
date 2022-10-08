// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./AnyCallApp.sol";

contract MainChain_NFT is ERC721Enumerable, AnyCallApp {
    bytes32 public Method_Claim = keccak256("claim");
    bytes32 public Method_Transfer = keccak256("transfer");

    constructor(
        address callProxy,
        string memory name,
        string memory symbol
    ) AnyCallApp(callProxy, 2) ERC721(name, symbol) {}

    function claim(address to, uint256 tokenId) external payable {
        tokenId = block.chainid * 10**10 + tokenId;
        _mint(to, tokenId);
    }

    function Swapout_no_fallback(
        address to,
        uint256 tokenId,
        uint256 toChainID
    ) public payable {
        _burn(tokenId);
        bytes memory data = abi.encode(Method_Transfer, to, tokenId, false);
        _anyCall(peer[toChainID], data, address(0), toChainID);
    }

    function _anyExecute(uint256 fromChainID, bytes calldata data)
        internal
        override
        returns (bool success, bytes memory result)
    {
        (bytes32 method, address to, uint256 tokenId, bool sendBack) = abi
            .decode(data, (bytes32, address, uint256, bool));
        if (method == Method_Claim) {
            tokenId = block.chainid * 10**10 + tokenId;
            _mint(to, tokenId);
            if (sendBack) {
                Swapout_no_fallback(to, tokenId, fromChainID);
            }
        }
        if (method == Method_Transfer) {
            _mint(to, tokenId);
        }
    }

    function _anyFallback(bytes memory data)
        internal
        override
        returns (bool success, bytes memory result)
    {
        (bytes32 method, address to, uint256 tokenId) = abi.decode(
            data,
            (bytes32, address, uint256)
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
