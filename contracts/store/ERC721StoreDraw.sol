// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "sortition-sum-tree-factory/contracts/SortitionSumTreeFactory.sol";
import "@pooltogether/uniform-random-number/contracts/UniformRandomNumber.sol";

import "./ERC721Store.sol";
import "./core/registry/StoreRegistry.sol";

/**
 * Mint a single ERC721 which can hold NFTs
 */
abstract contract ERC721StoreDraw {
    using SafeMathUpgradeable for uint256;
    using SafeCastUpgradeable for uint256;
    using SortitionSumTreeFactory for SortitionSumTreeFactory.SortitionSumTrees;

    // Ticket-weighted odds
    SortitionSumTreeFactory.SortitionSumTrees internal sortitionSumTrees;
    uint256 constant private MAX_TREE_LEAVES = 5;

    function _createTree(address store) internal {
      sortitionSumTrees.createTree(keccak256(abi.encodePacked(store)), MAX_TREE_LEAVES);
    }

    function _update(address store, address user, uint256 balance) internal {
      sortitionSumTrees.set(keccak256(abi.encodePacked(store)), balance, bytes32(uint256(user)));
    }

    /// @notice Returns the user's chance of winning.
    function _chanceOf(address store, address user) internal view returns (uint256) {
      return sortitionSumTrees.stakeOf(keccak256(abi.encodePacked(store)), bytes32(uint256(user)));
    }

    /// @notice Selects a user using a random number.  The random number will be uniformly bounded to the ticket totalSupply.
    /// @param randomNumber The random number to use to select a user.
    /// @return The winner
    function _draw(address store, uint256 randomNumber, uint256 bound) internal view returns (address) {
      address selected;
      if (bound == 0) {
        selected = address(0);
      } else {
        uint256 token = UniformRandomNumber.uniform(randomNumber, bound);
        selected = address(uint256(sortitionSumTrees.draw(keccak256(abi.encodePacked(store)), token)));
      }
      return selected;
    }
}
