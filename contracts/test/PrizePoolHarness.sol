pragma solidity 0.6.12;

import "../prize-pool/PrizePool.sol";
import "./YieldSourceStub.sol";

contract PrizePoolHarness is PrizePool {

  uint256 public currentTime;

  YieldSourceStub stubYieldSource;

  function initializeAll(
    RegistryInterface _reserveRegistry,
    ControlledTokenInterface[] memory _controlledTokens,
    uint256 _maxExitFeeMantissa,
    ERC721StoreRegistry _storeRegistry,
    YieldSourceStub _stubYieldSource
  )
    public
  {
    PrizePool.initialize(
      _reserveRegistry,
      _controlledTokens,
      _maxExitFeeMantissa,
      _storeRegistry
    );
    stubYieldSource = _stubYieldSource;
  }

  function supply(uint256 mintAmount, address store) external {
    _supply(mintAmount, store);
  }

  function redeem(uint256 redeemAmount) external {
    _redeem(redeemAmount);
  }

  function setCurrentTime(uint256 _currentTime) external {
    currentTime = _currentTime;
  }

  function _currentTime() internal override view returns (uint256) {
    return currentTime;
  }

  function _canAwardExternal(address _externalToken) internal override view returns (bool) {
    return stubYieldSource.canAwardExternal(_externalToken);
  }

  function _token() internal override view returns (IERC20Upgradeable) {
    return stubYieldSource.token();
  }

  function _balance(address store) internal override returns (uint256) {
    return stubYieldSource.balance(store);
  }

  function _supply(uint256 mintAmount, address store) internal override {
    return stubYieldSource.supply(mintAmount, store);
  }

  function _redeem(uint256 redeemAmount) internal override returns (uint256) {
    return stubYieldSource.redeem(redeemAmount);
  }
}
