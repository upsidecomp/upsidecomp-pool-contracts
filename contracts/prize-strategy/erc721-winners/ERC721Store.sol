// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

// import "./OpenZeppelin/token/ERC721/ERC721Holder.sol";
import "@openzeppelin/contracts-upgradeable@3.4.0/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable@3.4.0/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable@3.4.0/access/OwnableUpgradeable.sol";

import "./../../utils/MappedSinglyLinkedList.sol";
import "./../ERC721PrizeStrategy.sol";

interface IERC721Store {
  function getCurrentPrize() external;
  function getNextPrize() external;

  function setNextPrie() external;
}


/**
 * Mint a single ERC721 which can hold NFTs
 */
contract ERC721Store is ERC721Upgradeable, ERC721Holder {
    using MappedSinglyLinkedList for MappedSinglyLinkedList.Mapping;

    event Deposit(IERC721Upgradeable indexed token, uint256[] tokenId, address indexed from);
    event Withdraw(address indexed token, uint256 tokenId, address indexed to);

    MappedSinglyLinkedList.Mapping internal store;
    mapping (IERC721Upgradeable => uint256[]) internal storeTokenIds;

    ERC721PrizeStrategy public ERC721PrizeStrategy;

    constructor(
      ERC721PrizeStrategy _ERC721PrizeStrategy,
      string memory name,
      string memory symbol
    ) ERC721(name, symbol) {
        _mint(msg.sender, 0);

        ERC721PrizeStrategy = _ERC721PrizeStrategy;

        __Ownable_init();
    }

    function deposit(IERC721Upgradeable _token, uint256 _tokenIds[], address owner) public onlyOwner {
      require(_token != address(this), "cant deposit self");

      address operator = msg.sender;

      if (!store.contains(address(_token))) {
        store.addAddress(address(_token));
      }

      for (uint256 i = 0; i < _tokenIds.length; i++) {
        _deposit(_token, _tokenIds[i], operator);
      }

      emit Deposit(_token, _tokenId, msg.sender);
    }

    function _deposit(IERC721Upgradeable _token, uint256 _tokenId, address owner) internal {
      IERC721Upgradeable(_token).safeTransferFrom(owner, address(this), _tokenId);

      for (uint256 i = 0; i < storeTokenIds[_token].length; i++) {
        if (storeTokenIds[_token][i] == _tokenId) {
          revert("erc721-duplicate");
        }
      }

      storeTokenIds[_token].push(_tokenId);
    }
}
