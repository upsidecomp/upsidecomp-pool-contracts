// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;


interface IStoreRegistryAction {
  function register(string memory name, string memory symbol) external returns (address);
  function deregister(address store) external returns (bool);
}
