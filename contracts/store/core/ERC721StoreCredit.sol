// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

abstract contract ERC721StoreCredit {
  struct CreditBalance {
    uint192 balance;
    uint32 timestamp;
    bool initialized;
  }

  /// @dev Stores each users balance of credit per token.
  mapping(address => mapping(address => CreditBalance)) internal _tokenCreditBalances;
}
