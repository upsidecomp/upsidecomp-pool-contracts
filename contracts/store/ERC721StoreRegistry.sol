// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable@3.4.0/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable@3.4.0/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable@3.4.0/utils/ReentrancyGuardUpgradeable.sol";

import "./../../utils/MappedSinglyLinkedList.sol";
import "./ERC721Store.sol";
import "../../external/compound/CTokenInterface.sol";
import "./../../prize-pool/PrizePool.sol";
import "sortition-sum-tree-factory/contracts/SortitionSumTreeFactory.sol";
import "@openzeppelin/contracts-upgradeable@3.4.0/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable@3.4.0/utils/SafeCastUpgradeable.sol";

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
    CTokenInterface public cToken;

    function initialize(PrizePool _prizePool, CTokenInterface _cToken) public initializer {
        require(address(_prizePool) != address(0), "ERC721StoreRegistry/prize-pool-not-zero");
        require(address(_cToken) != address(0), "ERC721StoreRegistry/ctoken-not-zero");

        prizePool = _prizePool;
        cToken = _cToken;
        
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
        s.initialize(name, symbol, address(cToken));

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

    modifier onlyStore(address store) {
        _ensureActiveStore(store);
        _;
    }

    function ensureActiveStore(address store) external view {
        _ensureActiveStore(store);
    }

    function _ensureActiveStore(address store) internal view {
        require(_isStoreActive[ERC721Store(store)], "invalid store id");
    }

    modifier onlyPrizePool() {
      require(msg.sender == address(prizePool), "PeriodicPrizeStrategy/only-prize-pool");
      _;
    }
}
