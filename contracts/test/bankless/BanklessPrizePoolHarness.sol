pragma solidity 0.6.12;

import "./../../bankless/PrizePool.sol";
import "./BanklessYieldSourceStub.sol";

contract BanklessPrizePoolHarness is PrizePool {

  BanklessYieldSourceStub stubYieldSource;

  function initializeAll(
    ControlledTokenInterface[] memory _controlledTokens,
    uint256 _maxExitFeeMantissa,
    BanklessYieldSourceStub _stubYieldSource
  )
    public
  {
    PrizePool.initialize(
      _controlledTokens,
      _maxExitFeeMantissa
    );
    stubYieldSource = _stubYieldSource;
  }

  function _canAwardExternal(address _externalToken) internal override view returns (bool) {
    return stubYieldSource.canAwardExternal(_externalToken);
  }

  function _token() internal override view returns (IERC20Upgradeable) {
    return stubYieldSource.token();
  }

  function _balance() internal override returns (uint256) {
    return stubYieldSource.balance();
  }
}
