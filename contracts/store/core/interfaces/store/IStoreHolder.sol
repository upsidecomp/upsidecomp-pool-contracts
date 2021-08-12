// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

interface IStoreHolder {
  function deposit(IERC721Upgradeable _token, uint256 _tokenId) external;
  function withdraw(IERC721Upgradeable _token, uint256 _tokenId) external;

  event Deposit(IERC721Upgradeable indexed token, uint256 tokenId, address indexed from);
  event Withdraw(IERC721Upgradeable indexed token, uint256 tokenId, address indexed to);
}
