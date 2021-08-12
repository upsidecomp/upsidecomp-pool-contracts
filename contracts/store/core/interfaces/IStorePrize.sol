// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

interface IStorePrize {
  function setNextPrize(IERC721Upgradeable _token, IERC721Upgradeable _tokenId) external;
}
