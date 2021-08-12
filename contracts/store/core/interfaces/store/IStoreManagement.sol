// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

interface IStoreManagement {
  // function manager() external view returns (address);

  function setManager(address manager) external;

  event Manager(address _manager);
}
