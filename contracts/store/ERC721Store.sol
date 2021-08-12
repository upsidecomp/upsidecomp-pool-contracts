// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./../utils/MappedSinglyLinkedList.sol";
import "./core/store/StoreNFT.sol";


contract ERC721Store is StoreNFT, OwnableUpgradeable {
  using MappedSinglyLinkedList for MappedSinglyLinkedList.Mapping;

  MappedSinglyLinkedList.Mapping internal store;
  mapping (IERC721Upgradeable => uint256[]) internal storeTokenIds;

  function initialize (
    string memory name,
    string memory symbol,
    address manager
  ) public initializer {
      StoreNFT.initialize(manager, name, symbol);
  }

  function deposits(IERC721Upgradeable _token, uint256[] calldata _tokenIds) public onlyManager {
    require(address(_token) != address(this), "cant deposit self");

    address operator = msg.sender;

    if (!store.contains(address(_token))) {
      store.addAddress(address(_token));
    }

    for (uint256 i = 0; i < _tokenIds.length; i++) {
      uint256 _tokenId = _tokenIds[i];

      super.deposit(_token, _tokenId);

      for (uint256 i = 0; i < storeTokenIds[_token].length; i++) {
        if (storeTokenIds[_token][i] == _tokenId) {
          revert("erc721-duplicate");
        }
      }

      storeTokenIds[_token].push(_tokenId);
    }
  }
}

contract ERC721StoreCredit is ERC721Store {
  struct CreditBalance {
    uint192 balance;
    uint32 timestamp;
    bool initialized;
  }

  /// @dev Stores each users balance of credit per token.
  mapping(address => mapping(address => CreditBalance)) internal _tokenCreditBalances;
}
