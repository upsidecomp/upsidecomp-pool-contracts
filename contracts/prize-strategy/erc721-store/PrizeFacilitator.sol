// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@pooltogether/pooltogether-rng-contracts/contracts/RNGInterface.sol";

import "./../../token/TokenControllerInterface.sol";
import "./../../token/ControlledToken.sol";
import "./../../token/TicketInterface.sol";
import "./../../prize-pool/PrizePool.sol";
import "./../../utils/MappedSinglyLinkedList.sol";
import "./../../Constants.sol";

import "./../../store/ERC721Store.sol";
import "./../../store/ERC721StoreRegistry.sol";

/* solium-disable security/no-block-members */
abstract contract PrizeFacilitator is Initializable, OwnableUpgradeable {
   using MappedSinglyLinkedList for MappedSinglyLinkedList.Mapping;

  // Contract Interfaces
  PrizePool public prizePool;
  TicketInterface public ticket;
  IERC20Upgradeable public sponsorship;
  RNGInterface public rng;
  ERC721StoreRegistry public storeRegistry;

  // Storage
  uint32 public rngRequestTimeout;

  function initialize (
    PrizePool _prizePool,
    TicketInterface _ticket,
    IERC20Upgradeable _sponsorship,
    RNGInterface _rng,
    ERC721StoreRegistry _storeRegistry
  ) public initializer {
    require(address(_prizePool) != address(0), "PeriodicPrizeStrategy/prize-pool-not-zero");
    require(address(_ticket) != address(0), "PeriodicPrizeStrategy/ticket-not-zero");
    require(address(_sponsorship) != address(0), "PeriodicPrizeStrategy/sponsorship-not-zero");
    require(address(_rng) != address(0), "PeriodicPrizeStrategy/rng-not-zero");

    prizePool = _prizePool;
    ticket = _ticket;
    rng = _rng;
    sponsorship = _sponsorship;
    storeRegistry = _storeRegistry;

    __Ownable_init();

    rngRequestTimeout = 1800;
  }

  function deposit(address to, uint256 amount, address token, address referrer, bytes32 storeId) public onlyFacilitatedStore(storeId) {
    prizePool.depositTo(storeRegistry.getStoreAddress(storeId), amount, token, referrer);
    store.updateBalance(storeId, to, amount);
  }

  modifier onlyFacilitatedStore(bytes32 storeId) {
      storeRegistry.ensureRegisteredStore(storeId);
      _;
  }
}
