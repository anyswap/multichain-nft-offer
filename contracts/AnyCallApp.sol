// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Administrable.sol";
import "./IAnycallProxy.sol";
import "./IExecutor.sol";
import "./IFeePool.sol";

abstract contract AnyCallApp is Administrable {
    uint256 public flag; // 2: pay on dest chain, 4: allow fall back
    address public anyCallProxy;

    uint256 public constant FLAG_PAY_FEE_ON_DEST = 0x1 << 1;
    uint256 public constant FLAG_ALLOW_FALLBACK = 0x1 << 2;

    mapping(uint256 => address) internal peer;

    modifier onlyExecutor() {
        require(msg.sender == IAnycallProxy(anyCallProxy).executor());
        _;
    }

    constructor (address anyCallProxy_, uint256 flag_) {
        anyCallProxy = anyCallProxy_;
        flag = flag_;
    }

    function setPeers(uint256[] memory chainIDs, address[] memory  peers) public onlyAdmin {
        for (uint i = 0; i < chainIDs.length; i++) {
            peer[chainIDs[i]] = peers[i];
        }
    }

    function getPeer(uint256 foreignChainID) external view returns (address) {
        return peer[foreignChainID];
    }

    function setAnyCallProxy(address proxy) public onlyAdmin {
        anyCallProxy = proxy;
    }

    function _anyExecute(uint256 fromChainID, bytes calldata data) internal virtual returns (bool success, bytes memory result);
    function _anyFallback(bytes memory data) internal virtual returns (bool success, bytes memory result);

    function _anyCall(address _to, bytes memory _data, uint256 _toChainID) internal {
        if (flag | FLAG_PAY_FEE_ON_DEST == FLAG_PAY_FEE_ON_DEST) {
            IAnycallProxy(anyCallProxy).anyCall(_to, _data, _toChainID, flag, "");
        } else {
            IAnycallProxy(anyCallProxy).anyCall{value: msg.value}(_to, _data, _toChainID, flag, "");
        }
    }

    function _anyCall_no_fallback(address _to, bytes memory _data, uint256 _toChainID) internal {
        uint256 _flag = flag & (~FLAG_ALLOW_FALLBACK);
        if (flag | FLAG_PAY_FEE_ON_DEST == FLAG_PAY_FEE_ON_DEST) {
            IAnycallProxy(anyCallProxy).anyCall(_to, _data, _toChainID, _flag, "");
        } else {
            IAnycallProxy(anyCallProxy).anyCall{value: msg.value}(_to, _data, _toChainID, _flag, "");
        }
    }

    function anyExecute(bytes calldata data) external onlyExecutor returns (bool success, bytes memory result) {
        (address callFrom, uint256 fromChainID,) = IExecutor(IAnycallProxy(anyCallProxy).executor()).context();
        require(peer[fromChainID] == callFrom, "call not allowed");
        return _anyExecute(fromChainID, data);
    }

    function anyFallback(bytes memory data) external onlyExecutor returns (bool success, bytes memory result) {
        (address callFrom, uint256 fromChainID,) = IExecutor(IAnycallProxy(anyCallProxy).executor()).context();
        require(peer[fromChainID] == callFrom, "call not allowed");
        return _anyFallback(data);
    }


    receive() external payable {}

    function withdraw(address _to, uint256 _amount) external onlyAdmin {
        (bool success, ) = _to.call{value: _amount}("");
        require(success);
    }

    // if the app want to support `pay fee on destination chain`,
    // we'd better wrapper the interface `IFeePool` functions here.

    function depositFee() external payable {
        address _pool = IAnycallProxy(anyCallProxy).config();
        IFeePool(_pool).deposit{value: msg.value}(address(this));
    }

    function withdrawFee(address _to, uint256 _amount) external onlyAdmin {
        address _pool = IAnycallProxy(anyCallProxy).config();
        IFeePool(_pool).withdraw(_amount);

        (bool success, ) = _to.call{value: _amount}("");
        require(success);
    }

    function withdrawAllFee(address _pool, address _to) external onlyAdmin {
        uint256 _amount = IFeePool(_pool).executionBudget(address(this));
        IFeePool(_pool).withdraw(_amount);

        (bool success, ) = _to.call{value: _amount}("");
        require(success);
    }

    function executionBudget() external view returns (uint256) {
        address _pool = IAnycallProxy(anyCallProxy).config();
        return IFeePool(_pool).executionBudget(address(this));
    }
}
