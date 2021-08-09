// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable@3.4.0/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable@3.4.0/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable@3.4.0/token/ERC721/IERC721Upgradeable.sol";
import "@pooltogether/pooltogether-rng-contracts/contracts/RNGInterface.sol";

import "./../../token/TokenControllerInterface.sol";
import "./../../token/ControlledToken.sol";
import "./../../token/TicketInterface.sol";
import "./../../prize-pool/PrizePool.sol";
import "./../../utils/MappedSinglyLinkedList.sol";
import "./../../Constants.sol";


abstract contract PrizeManagers is AccessControlUpgradeable {
  bytes32 public constant PRIZE_MANAGER_ROLE = keccak256("PRIZE_MANAGER");

  function addPrizeManager(address prizeManager, address asset) public {}
  function removePrizeManager(address prizeManager, address asset) public {}

  modifier onlyPrizeManager(address manager, address asset) {
    require(hasRole(PRIZE_MANAGER_ROLE, manager), "PrizeManagers/not-prize-manager");
    _;
  }
 }


interface IERC721Prize {
    function addProject(IERC721Upgradeable token, uint256[] calldata tokenIds, string memory name, uint256 prizePeriodStartedAt, uint256 prizePeriodSeconds) external;
    // function removePrize() external;
    // function countPrizesLeft() external;

    // function completeAward() external;
    // function cancelAward() external;
    // function startAward() external;
}


/* solium-disable security/no-block-members */
abstract contract ERC721PrizeStrategy is Initializable, IERC721Prize, OwnableUpgradeable {
   using MappedSinglyLinkedList for MappedSinglyLinkedList.Mapping;

  event ProjectAdded(uint256 prizeId, address indexed manager, string name, IERC721Upgradeable indexed token, uint256[] tokenIds, uint256 prizePeriodStartedAt, uint256 prizePeriodSeconds);

  struct Prize {
    address manager;
    string name;
    IERC721Upgradeable token;
    uint256[] tokenIds;
    uint256 prizePeriodStartedAt;
    uint256 prizePeriodSeconds;
  }

  // Contract Interfaces
  PrizePool public prizePool;
  TicketInterface public ticket;
  IERC20Upgradeable public sponsorship;
  RNGInterface public rng;

  // Storage
  uint256 private _prizeId = 0;

  // ERC721 Prize Data
  mapping(uint256 => Prize) public prizeList;
  MappedSinglyLinkedList.Mapping internal prizeERC721;
  mapping (IERC721Upgradeable => uint256[]) internal prizeERC721TokenIds;

  function initialize (
    PrizePool _prizePool,
    TicketInterface _ticket,
    IERC20Upgradeable _sponsorship,
    RNGInterface _rng
  ) public initializer {
    require(address(_prizePool) != address(0), "PeriodicPrizeStrategy/prize-pool-not-zero");
    require(address(_ticket) != address(0), "PeriodicPrizeStrategy/ticket-not-zero");
    require(address(_sponsorship) != address(0), "PeriodicPrizeStrategy/sponsorship-not-zero");
    require(address(_rng) != address(0), "PeriodicPrizeStrategy/rng-not-zero");

    prizePool = _prizePool;
    ticket = _ticket;
    rng = _rng;
    sponsorship = _sponsorship;

    __Ownable_init();

    prizeERC721.initialize();
  }

  function deposit(uint256 prizeId, address from) public virtual;
  function withdraw(uint256 prizeId, address to) public virtual;

  function addProject(
    IERC721Upgradeable token,
    uint256[] calldata tokenIds,
    string memory name,
    uint256 prizePeriodStartedAt,
    uint256 prizePeriodSeconds
  ) override public onlyPrizeManager(msg.sender) {
    require(prizePool.canAwardExternal(address(token)), "PeriodicPrizeStrategy/cannot-award-external");
    // require(address(token).supportsInterface(Constants.ERC165_INTERFACE_ID_ERC721), "PeriodicPrizeStrategy/erc721-invalid"); // todo: fix

    address operator = msg.sender;

    _storePrizes(token, tokenIds, operator);
    _addProject(token, tokenIds, operator, name, prizePeriodStartedAt, prizePeriodSeconds);
  }

  function _addProject(
    IERC721Upgradeable token,
    uint256[] calldata tokenIds,
    address manager,
    string memory name,
    uint256 prizePeriodStartedAt,
    uint256 prizePeriodSeconds
  ) internal {
    _prizeId++;

    prizeList[_prizeId] = Prize({
        manager: manager,
        name: name,
        token: IERC721Upgradeable(token),
        tokenIds: tokenIds,
        prizePeriodStartedAt: prizePeriodStartedAt,
        prizePeriodSeconds: prizePeriodSeconds
    });

    emit ProjectAdded(_prizeId, manager, name, token, tokenIds, prizePeriodStartedAt, prizePeriodSeconds);
  }

  function _storePrizes(IERC721Upgradeable _token, uint256[] calldata _tokenIds, address owner) internal {
    if (!prizeERC721.contains(address(_token))) {
      prizeERC721.addAddress(address(_token));
    }

    for (uint256 i = 0; i < _tokenIds.length; i++) {
      _storePrize(_token, _tokenIds[i], owner);
    }
  }

  function _storePrize(IERC721Upgradeable _token, uint256 _tokenId, address owner) internal {
    require(IERC721Upgradeable(_token).ownerOf(_tokenId) != address(prizePool), "PeriodicPrizeStrategy/unavailable-token");

    IERC721Upgradeable(_token).safeTransferFrom(owner, address(prizePool), _tokenId);

    for (uint256 i = 0; i < prizeERC721TokenIds[_token].length; i++) {
      if (prizeERC721TokenIds[_token][i] == _tokenId) {
        revert("PeriodicPrizeStrategy/erc721-duplicate");
      }
    }

    prizeERC721TokenIds[_token].push(_tokenId);
  }

  function startAward() public {}

  function completeAward() public {}

  modifier onlyPrizeManager(address manager) {
      _;
  }
}


abstract contract ERC721PrizeStrategyStake is ERC721PrizeStrategy {
    mapping(uint256 => mapping(address => uint192)) private _balances;

    function deposit(uint256 projectId, address from) public override {

    }

    function withdraw(uint256 projectId, address to) public override {

    }
}
