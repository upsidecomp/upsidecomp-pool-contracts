// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable@3.4.0/token/ERC20/IERC20Upgradeable.sol";

interface ICompLike is IERC20Upgradeable {
  function getCurrentVotes(address account) external view returns (uint96);
  function delegate(address delegatee) external;
}
