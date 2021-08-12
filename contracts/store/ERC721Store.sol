// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

// import "./OpenZeppelin/token/ERC721/ERC721Holder.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "./../utils/MappedSinglyLinkedList.sol";

/**
 * Mint a single ERC721 which can hold NFTs
 */
contract ERC721Store is Initializable, ERC721Upgradeable, ERC721HolderUpgradeable, OwnableUpgradeable {
    using MappedSinglyLinkedList for MappedSinglyLinkedList.Mapping;

    event Deposit(IERC721Upgradeable indexed token, uint256[] tokenIds, address indexed from);
    event Withdraw(address indexed token, uint256 tokenId, address indexed to);

    // store
    MappedSinglyLinkedList.Mapping internal store;
    mapping (IERC721Upgradeable => uint256[]) internal storeTokenIds;
    mapping(address => uint256) private _balance;

    address private _manager;

    function initialize (
      string memory name,
      string memory symbol,
      address manager
    ) public initializer {
        __ERC721_init(name, symbol);
        __Ownable_init();

        _mint(msg.sender, 0);

        store.initialize();

        _manager = manager;
    }

    function deposit(IERC721Upgradeable _token, uint256[] calldata _tokenIds) public onlyManager(msg.sender) {
      require(address(_token) != address(this), "cant deposit self");

      address operator = msg.sender;

      if (!store.contains(address(_token))) {
        store.addAddress(address(_token));
      }

      for (uint256 i = 0; i < _tokenIds.length; i++) {
        _deposit(_token, _tokenIds[i], operator);
      }

      emit Deposit(_token, _tokenIds, operator);
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

    function balance(address user) view external returns (uint256) {
        return _balance[user];
    }

    modifier onlyManager(address manager) {
        require(manager == _manager, "not manager");
        _;
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
