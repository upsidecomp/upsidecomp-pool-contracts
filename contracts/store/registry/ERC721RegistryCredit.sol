// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

abstract contract ERC721RegistryCredit {
  struct CreditBalance {
    uint192 balance;
    uint32 timestamp;
    bool initialized;
  }

  /// @dev Stores each users balance of credit per token.
  mapping(address => mapping(address => CreditBalance)) internal _tokenCreditBalances;

  function _updateCreditBalance(address user, address controlledToken, uint256 newBalance) internal {
    uint256 oldBalance = _tokenCreditBalances[controlledToken][user].balance;

    _tokenCreditBalances[controlledToken][user] = CreditBalance({
      balance: newBalance.toUint128(),
      timestamp: _currentTime().toUint32(),
      initialized: true
    });

    if (oldBalance < newBalance) {
      emit CreditMinted(user, controlledToken, newBalance.sub(oldBalance));
    }
    else if (newBalance < oldBalance) {
      emit CreditBurned(user, controlledToken, oldBalance.sub(newBalance));
    }
  }
}
