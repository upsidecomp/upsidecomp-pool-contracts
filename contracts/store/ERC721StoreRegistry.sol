// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "./../utils/MappedSinglyLinkedList.sol";
import "./ERC721Store.sol";
import "./../prize-pool/PrizePool.sol";
import "sortition-sum-tree-factory/contracts/SortitionSumTreeFactory.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

/**
 * Mint a single ERC721 which can hold NFTs
 */
contract ERC721StoreRegistry is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeMathUpgradeable for uint256;
    using SafeCastUpgradeable for uint256;
    using SortitionSumTreeFactory for SortitionSumTreeFactory.SortitionSumTrees;

    // Ticket-weighted odds
    SortitionSumTreeFactory.SortitionSumTrees internal sortitionSumTrees;

    bytes32 constant private TREE_KEY = keccak256("Upside/Ticket");
    uint256 constant private MAX_TREE_LEAVES = 5;

    mapping(ERC721Store => bool) private _isStoreActive;

    PrizePool public prizePool;

    function initialize(PrizePool _prizePool) public initializer {
        require(address(_prizePool) != address(0), "ERC721StoreRegistry/prize-pool-not-zero");

        prizePool = _prizePool;

        sortitionSumTrees.createTree(TREE_KEY, MAX_TREE_LEAVES);

        __Ownable_init();
    }

    function registerStore(string memory name, string memory symbol)
        external
        nonReentrant
        returns (address)
    {
        address operator = msg.sender;

        ERC721Store s = new ERC721Store();
        s.initialize(name, symbol, operator);

        _isStoreActive[s] = true;

        return address(s);
    }

    function deposit(address store, address user, uint256 amount) external onlyPrizePool {
        uint256 balance = ERC721Store(store).balance(user).add(amount);
        sortitionSumTrees.set(TREE_KEY, balance, bytes32(uint256(user)));
    }

    function withdraw(address store, address user, uint256 amount) external onlyPrizePool {
        uint256 balance = ERC721Store(store).balance(user).sub(amount);
        sortitionSumTrees.set(TREE_KEY, balance, bytes32(uint256(user)));
    }

    function ensureActiveStore(address store) external view returns (bool) {
        return _ensureActiveStore(store);
    }

    function _ensureActiveStore(address store) internal view returns (bool) {
        return _isStoreActive[ERC721Store(store)];
    }

    modifier onlyPrizePool() {
      require(msg.sender == address(prizePool), "PeriodicPrizeStrategy/only-prize-pool");
      _;
    }

    modifier onlyStore(address store) {
        require(_ensureActiveStore(store), "invalid store id");
        _;
    }
}
