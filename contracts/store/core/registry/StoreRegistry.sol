// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "./../interfaces/store/IStore.sol";
import "./../interfaces/registry/IStoreRegistry.sol";

/**
 * Mint a single ERC721 which can hold NFTs
 */
abstract contract StoreRegistry is IStoreRegistry  {
    using SafeMathUpgradeable for uint256;
    using SafeCastUpgradeable for uint256;

    struct CreditBalance {
      uint192 balance;
      uint32 timestamp;
      bool initialized;
    }

    mapping(IStore => bool) internal _stores;
    mapping(IStore => mapping(address => CreditBalance)) internal _storesBalance;
    mapping(IStore => uint256) _storesTotalSupply;

    function register(string memory name, string memory symbol) external override virtual returns (address);
    function deregister(address store) external override virtual returns (bool);

    function deposit(address store, address from, uint256 amount) external override virtual;
    function withdraw(address store, address to, uint256 amount) external override virtual;

    function _deposit(address store, address from, uint256 amount) internal returns (uint256) {
      require(amount > 0, "StoreRegistry/deposit-amount-more-than-zero");

      uint256 balance = _balanceOf(store, from);
      uint192 newBalance = balance.sub(amount).toUint128();

      _storesTotalSupply[IStore(store)] = _storesTotalSupply[IStore(store)].add(amount);

      _storesBalance[IStore(store)][from] = CreditBalance({
        balance: newBalance,
        timestamp: block.timestamp.toUint32(),
        initialized: true
      });

      return newBalance;
    }

    function _withdraw(address store, address to, uint256 amount) internal returns (uint256) {
      require(amount > 0, "StoreRegistry/withdraw-amount-more-than-zero");

      uint256 balance = _balanceOf(store, to);

      require(amount <= balance, "StoreRegistry/withdraw-amount-exceeds-max");

      uint192 newBalance = balance.sub(amount).toUint128();

      _storesTotalSupply[IStore(store)] = _storesTotalSupply[IStore(store)].sub(amount);
      _storesBalance[IStore(store)][to] = CreditBalance({
              balance: newBalance,
              timestamp: block.timestamp.toUint32(),
              initialized: true
      });

      return newBalance;
    }

    function _register(IStore store) internal {
      _stores[store] = true;
    }

    function ensureActiveStore(address store) external view returns (bool) {
        return _ensureActiveStore(store);
    }

    function _ensureActiveStore(address store) internal view returns (bool) {
        return _stores[IStore(store)];
    }

    function balanceOf(address store, address user) external view returns (uint256) {
      return _balanceOf(store, user);
    }

    function _balanceOf(address store, address user) internal view returns (uint256) {
      return _storesBalance[IStore(store)][user].balance;
    }

    function totalSupply(address store) internal view returns (uint256) {
      return _storesTotalSupply[IStore(store)];
    }

    modifier onlyStore(address store) {
        require(_ensureActiveStore(store), "invalid store id");
        _;
    }
}
