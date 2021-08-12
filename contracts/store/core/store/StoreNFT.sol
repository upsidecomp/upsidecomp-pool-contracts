// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "./Store.sol";

abstract contract StoreNFT is Store, ERC721Upgradeable {
  function initialize (
    address manager,
    string memory name,
    string memory symbol
  ) public initializer {
      Store.initialize(manager);
      __ERC721_init(name, symbol);

      _mint(msg.sender, 0);
  }

  function deposit(IERC721Upgradeable _token, uint256 _tokenId) public onlyManager override {
    require(address(_token) != address(this), "cant deposit self");

    IERC721Upgradeable(_token).safeTransferFrom(msg.sender, address(this), _tokenId);

    emit Deposit(_token, _tokenId, msg.sender);
  }

  function withdraw(IERC721Upgradeable _token, uint256 _tokenId) public onlyManager override {
    IERC721Upgradeable(_token).safeTransferFrom(address(this), msg.sender, _tokenId);

    emit Withdraw(_token, _tokenId, msg.sender);
  }
}
