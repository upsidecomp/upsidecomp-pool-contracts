// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;


interface IStoreRegistryCredit {
  function deposit(address store, address from, uint256 amount) external;
  function withdraw(address store, address to, uint256 amount) external;
}
