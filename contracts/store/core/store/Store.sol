// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "../interfaces/IStore.sol";

abstract contract Store is IStore, Initializable, ERC721HolderUpgradeable {
  address private _manager;

  function initialize(address manager) public initializer {
      _setManager(manager);
  }

  function deposit(IERC721Upgradeable _token, uint256 _tokenId) public override virtual;
  function withdraw(IERC721Upgradeable _token, uint256 _tokenId) public override virtual;

  modifier onlyManager() {
      require(msg.sender == _manager, "Store/not-manager");
      _;
  }

  function setManager(address manager) external onlyManager override {
    _setManager(manager);
  }

  function _setManager(address manager) internal {
    _manager = manager;
  }
}
