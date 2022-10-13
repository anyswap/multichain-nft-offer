// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFeePool {
    function deposit(address _account) external payable;

    function withdraw(uint256 _amount) external;

    function executionBudget(address _account) external view returns (uint256);
}
