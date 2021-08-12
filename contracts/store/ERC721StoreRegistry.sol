// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "sortition-sum-tree-factory/contracts/SortitionSumTreeFactory.sol";
import "@pooltogether/uniform-random-number/contracts/UniformRandomNumber.sol";

import "./ERC721Store.sol";
import "./core/registry/StoreRegistry.sol";

import "./../prize-pool/PrizePool.sol";
import "./../utils/MappedSinglyLinkedList.sol";

/**
 * Mint a single ERC721 which can hold NFTs
 */
contract ERC721StoreRegistry is StoreRegistry, ReentrancyGuardUpgradeable {
    using SafeMathUpgradeable for uint256;
    using SafeCastUpgradeable for uint256;
    using SortitionSumTreeFactory for SortitionSumTreeFactory.SortitionSumTrees;

    // Ticket-weighted odds
    SortitionSumTreeFactory.SortitionSumTrees internal sortitionSumTrees;
    uint256 constant private MAX_TREE_LEAVES = 5;

    PrizePool public prizePool;

    function initialize(PrizePool _prizePool) public initializer {
        require(address(_prizePool) != address(0), "ERC721StoreRegistry/prize-pool-not-zero");

        StoreRegistry.initialize();

        prizePool = _prizePool;
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

        sortitionSumTrees.createTree(keccak256(abi.encodePacked(address(s))), MAX_TREE_LEAVES);

        return address(s);
    }

    function deregister(address store) external override returns (bool) {
        // todo: fix
    }

    function deposit(address store, address from, uint256 amount) external onlyStore(store) onlyPrizePool override {
      uint256 newBalance = super._deposit(store, from, amount);
      sortitionSumTrees.set(keccak256(abi.encodePacked(store)), newBalance, bytes32(uint256(from)));
    }

    function withdraw(address store, address to, uint256 amount) external onlyStore(store) onlyPrizePool override {
        uint256 newBalance = super._withdraw(store, to, amount);
        sortitionSumTrees.set(keccak256(abi.encodePacked(store)), newBalance, bytes32(uint256(to)));
    }

    /// @notice Returns the user's chance of winning.
    function chanceOf(address store, address user) external view returns (uint256) {
      return sortitionSumTrees.stakeOf(keccak256(abi.encodePacked(store)), bytes32(uint256(user)));
    }

    /// @notice Selects a user using a random number.  The random number will be uniformly bounded to the ticket totalSupply.
    /// @param randomNumber The random number to use to select a user.
    /// @return The winner
    function draw(address store, uint256 randomNumber) external view returns (address) {
      uint256 bound = totalSupply(store);
      address selected;
      if (bound == 0) {
        selected = address(0);
      } else {
        uint256 token = UniformRandomNumber.uniform(randomNumber, bound);
        selected = address(uint256(sortitionSumTrees.draw(keccak256(abi.encodePacked(store)), token)));
      }
      return selected;
    }

    modifier onlyPrizePool() {
      require(msg.sender == address(prizePool), "ERC721StoreRegistry/only-prize-pool");
      _;
    }
}
