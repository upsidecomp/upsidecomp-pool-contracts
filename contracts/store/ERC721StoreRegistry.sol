// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "./ERC721Store.sol";
import "./core/draw/Draw.sol";
import "./core/registry/StoreRegistry.sol";

import "./../prize-pool/PrizePool.sol";
import "./../utils/MappedSinglyLinkedList.sol";

/**
 * Mint a single ERC721 which can hold NFTs
 */
contract ERC721StoreRegistry is Draw, StoreRegistry, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;
    using SafeCastUpgradeable for uint256;

    PrizePool public prizePool;
    IERC20Upgradeable public ticket;

    uint256 public maxExitFeeMantissa;

    uint256 public liquidityCap;

    function initialize(
      PrizePool _prizePool,
      IERC20Upgradeable _ticket,
      uint256 _maxExitFeeMantissa
    )
      public
      initializer
    {
        require(address(_prizePool) != address(0), "ERC721StoreRegistry/prize-pool-not-zero");
        require(address(_ticket) != address(0), "ERC721StoreRegistry/ticket-not-zero");

        __Ownable_init();

        liquidityCap = -1;
        maxExitFeeMantissa = _maxExitFeeMantissa;
        prizePool = _prizePool;
        ticket = _ticket;
    }

    function register(string memory name, string memory symbol)
        external
        nonReentrant
        override
        returns (address)
    {
        address operator = msg.sender;

        ERC721Store s = new ERC721Store();
        s.initialize(name, symbol, operator);

        super._register(s);

        super._createTree(address(s));

        return address(s);
    }

    function deregister(address store) external override returns (bool) {
        // todo
    }

    function deposit(address store, address from, uint256 amount) external onlyStore(store) onlyPrizePool override {
      uint256 newBalance = super._deposit(store, from, amount);
      super._update(store, from, newBalance);
    }

    function withdraw(address store, address to, uint256 amount) external onlyStore(store) onlyPrizePool override {
        uint256 newBalance = super._withdraw(store, to, amount);
        super._update(store, to, newBalance);
    }

    function draw(address store, uint256 randomNumber) external view returns (address) {
      return super._draw(store, randomNumber, totalSupply(store));
    }

    modifier onlyPrizePool() {
      require(msg.sender == address(prizePool), "ERC721StoreRegistry/only-prize-pool");
      _;
    }
}
