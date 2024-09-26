pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface BanklessYieldSourceStub {
  function canAwardExternal(address _externalToken) external view returns (bool);

  function token() external view returns (IERC20Upgradeable);

  function balance() external returns (uint256);
}
