// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable@3.4.0/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable@3.4.0/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable@3.4.0/utils/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable@3.4.0/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable@3.4.0/introspection/ERC165CheckerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable@3.4.0/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable@3.4.0/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable@3.4.0/utils/AddressUpgradeable.sol";
import "@pooltogether/pooltogether-rng-contracts/contracts/RNGInterface.sol";
import "@pooltogether/fixed-point/contracts/FixedPoint.sol";

import "../token/TokenListener.sol";
import "../token/TokenControllerInterface.sol";
import "../token/ControlledToken.sol";
import "../token/TicketInterface.sol";
import "../prize-pool/PrizePool.sol";
import "../Constants.sol";
import "./PeriodicPrizeStrategyListenerInterface.sol";
import "./PeriodicPrizeStrategyListenerLibrary.sol";
import "./BeforeAwardListener.sol";

/* solium-disable security/no-block-members */
abstract contract DistinctPrizeStrategy is Initializable,
                                           OwnableUpgradeable,
                                           ReentrancyGuardUpgradeable,
                                           TokenListener {

  using SafeMathUpgradeable for uint256;
  using SafeMathUpgradeable for uint16;
  using SafeCastUpgradeable for uint256;
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using MappedSinglyLinkedList for MappedSinglyLinkedList.Mapping;
  using AddressUpgradeable for address;
  using ERC165CheckerUpgradeable for address;

  uint256 internal constant ETHEREUM_BLOCK_TIME_ESTIMATE_MANTISSA = 13.4 ether;

  event PrizePoolOpened(
    address indexed operator,
    uint256 indexed prizePeriodStartedAt
  );

  event RngRequestFailed(uint256 distinctPrizeId);

  event PrizePoolAwardStarted(
    address indexed operator,
    address indexed prizePool,
    uint32 indexed rngRequestId,
    uint32 rngLockBlock
  );

  event PrizePoolAwardCancelled(
    address indexed operator,
    address indexed prizePool,
    uint32 indexed rngRequestId,
    uint32 rngLockBlock,
    uint256 distinctPrizeId
  );

  event PrizePoolAwarded(
    address indexed operator,
    uint256 randomNumber
  );

  event RngServiceUpdated(
    RNGInterface indexed rngService
  );

  event TokenListenerUpdated(
    TokenListenerInterface indexed tokenListener
  );

  event RngRequestTimeoutSet(
    uint32 rngRequestTimeout
  );

  event PrizePeriodSecondsUpdated(
    uint256 prizePeriodSeconds
  );

  event BeforeAwardListenerSet(
    BeforeAwardListenerInterface indexed beforeAwardListener
  );

  event PeriodicPrizeStrategyListenerSet(
    PeriodicPrizeStrategyListenerInterface indexed periodicPrizeStrategyListener
  );

  event ExternalErc721AwardAdded(
    IERC721Upgradeable indexed externalErc721,
    uint256[] tokenIds
  );

  event ExternalErc20AwardAdded(
    IERC20Upgradeable indexed externalErc20
  );

  event ExternalErc721AwardRemoved(
    IERC721Upgradeable indexed externalErc721Award
  );

  event ExternalErc20AwardRemoved(
    IERC20Upgradeable indexed externalErc20Award
  );

  event Initialized(
    PrizePool indexed prizePool,
    TicketInterface ticket,
    IERC20Upgradeable sponsorship,
    RNGInterface rng
  );

  /// @notice Semver Version
  string constant public VERSION = "3.4.1";

  // Comptroller
  TokenListenerInterface public tokenListener;

  // Contract Interfaces
  PrizePool public prizePool;
  TicketInterface public ticket;
  IERC20Upgradeable public sponsorship;
  RNGInterface public rng;

  // RngRequest rngRequest;
  uint32 rngRequestTimeout;

  /// @notice A listener that is called before the prize is awarded
  BeforeAwardListenerInterface public beforeAwardListener;

  /// @notice A listener that is called after the prize is awarded
  PeriodicPrizeStrategyListenerInterface public periodicPrizeStrategyListener;

  // periodicPrizeStrategyDistinct
  struct RngRequest {
    uint32 id;
    uint32 lockBlock;
    uint32 requestedAt;
  }

  struct DistinctPrize {
    address owner;
    IERC721Upgradeable internalErc721;
    uint256[] internalErc721TokenId;
    uint256 prizePeriodSeconds;
    uint256 prizePeriodStartedAt;
    uint256 accruedBalance;
  }

  mapping(uint256 => DistinctPrize) public distinctPrizeList;
  mapping(uint256 => mapping(address => mapping(address => uint192))) public distinctPrizeTokenBalance;
  uint256 internal _distinctPrizeId = 0;

  /// @notice Initializes a new strategy
  /// @param _prizePool The prize pool to award
  /// @param _ticket The ticket to use to draw winners
  /// @param _sponsorship The sponsorship token
  /// @param _rng The RNG service to use
  function initialize (
    PrizePool _prizePool,
    TicketInterface _ticket,
    IERC20Upgradeable _sponsorship,
    RNGInterface _rng,
    IERC20Upgradeable[] memory externalErc20Awards
  ) public initializer {
    require(address(_prizePool) != address(0), "PeriodicPrizeStrategy/prize-pool-not-zero");
    require(address(_ticket) != address(0), "PeriodicPrizeStrategy/ticket-not-zero");
    require(address(_sponsorship) != address(0), "PeriodicPrizeStrategy/sponsorship-not-zero");
    require(address(_rng) != address(0), "PeriodicPrizeStrategy/rng-not-zero");
    
    prizePool = _prizePool;
    ticket = _ticket;
    rng = _rng;
    sponsorship = _sponsorship;

    __Ownable_init();
    Constants.REGISTRY.setInterfaceImplementer(address(this), Constants.TOKENS_RECIPIENT_INTERFACE_HASH, address(this));

    // 30 min timeout
    // _setRngRequestTimeout(1800);

    emit Initialized(
      _prizePool,
      _ticket,
      _sponsorship,
      _rng
    );
  }

  function _distribute(uint256 randomNumber) internal virtual;

  function depositToDistinctPrize(
    address from,
    uint256 amount,
    address controlledToken,
    uint256 distinctPrizeId
  )
    public
    nonReentrant
    onlyPrizePoolControlledToken(controlledToken)
    canAddLiquidity(amount)
  {
    ControlledToken(address(controlledToken)).transferFrom(from, address(this), amount);

    distinctPrizeTokenBalance[distinctPrizeId][controlledToken][from] = distinctPrizeTokenBalance[distinctPrizeId][controlledToken][from].add(amount.toUint128());
  }
  
  function withdrawFromDistinctPrize(
    address from,
    uint256 amount,
    address controlledToken,
    uint256 distinctPrizeId
  )
    public
    nonReentrant
    onlyPrizePoolControlledToken(controlledToken)
    canRemoveLiquidity(amount)
  {
    ControlledToken(address(controlledToken)).transferFrom(address(this), from, amount);

    distinctPrizeTokenBalance[distinctPrizeId][controlledToken][from] = distinctPrizeTokenBalance[distinctPrizeId][controlledToken][from].sub(amount.toUint128());
  }
  
  function addERC721Prize(address owner, IERC721Upgradeable _externalErc721, uint256[] calldata _tokenIds) public {
    require(prizePool.canAwardExternal(address(_externalErc721)), "PeriodicPrizeStrategy/cannot-award-external");
    require(address(_externalErc721).supportsInterface(Constants.ERC165_INTERFACE_ID_ERC721), "PeriodicPrizeStrategy/erc721-invalid");

    distinctPrizeId++;
    
    distinctPrizeList[distinctPrizeId] = DistinctPrize({
       owner: owner,
       internalErc721: _externalErc721
    });
    
    for (uint256 i = 0; i < _tokenIds.length; i++) {
      _addExternalErc721Award(_externalErc721, _tokenIds[i]);
    }

    emit ExternalErc721AwardAdded(_externalErc721, _tokenIds);
  }

  /// @notice Calculates and returns the currently accrued prize
  /// @return The current prize size
  function currentPrize() public view returns (uint256) {
    return prizePool.awardBalance();
  }

  function getPrize(uint256 distinctPrizeId) public view returns (address, uint256) {
    return (distinctPrizeList[distinctPrizeId].internalErc721, distinctPrizeList[distinctPrizeId].internalErc721TokenId);
  }

  function getPrizeAccruedBalance(uint256 distinctPrizeId) public view returns (uint256) {
    return distinctPrizeList[distinctPrizeId].accruedBalance;
  }

  /// @notice Allows the owner to set the token listener
  /// @param _tokenListener A contract that implements the token listener interface.
  function setTokenListener(TokenListenerInterface _tokenListener) external onlyOwner requireAwardNotInProgress {
    require(address(0) == address(_tokenListener) || address(_tokenListener).supportsInterface(TokenListenerLibrary.ERC165_INTERFACE_ID_TOKEN_LISTENER), "PeriodicPrizeStrategy/token-listener-invalid");

    tokenListener = _tokenListener;

    emit TokenListenerUpdated(tokenListener);
  }

  /// @notice Estimates the remaining blocks until the prize given a number of seconds per block
  /// @param secondsPerBlockMantissa The number of seconds per block to use for the calculation.  Should be a fixed point 18 number like Ether.
  /// @return The estimated number of blocks remaining until the prize can be awarded.
  function estimateRemainingBlocksToPrize(uint256 secondsPerBlockMantissa, uint256 distinctPrizeId) public view returns (uint256) {
    return FixedPoint.divideUintByMantissa(
      _prizePeriodRemainingSeconds(distinctPrizeId),
      secondsPerBlockMantissa
    );
  }

  /// @notice Returns the number of seconds remaining until the prize can be awarded.
  /// @return The number of seconds remaining until the prize can be awarded.
  function prizePeriodRemainingSeconds(uint256 distinctPrizeId) external view returns (uint256) {
    return _prizePeriodRemainingSeconds(distinctPrizeId);
  }

  /// @notice Returns the number of seconds remaining until the prize can be awarded.
  /// @return The number of seconds remaining until the prize can be awarded.
  function _prizePeriodRemainingSeconds(uint256 distinctPrizeId) internal view returns (uint256) {
    uint256 endAt = _prizePeriodEndAt(distinctPrizeId);
    uint256 time = _currentTime();
    if (time > endAt) {
      return 0;
    }
    return endAt.sub(time);
  }

  /// @notice Returns whether the prize period is over
  /// @return True if the prize period is over, false otherwise
  function isPrizePeriodOver(uint256 distinctPrizeId) external view returns (bool) {
    return _isPrizePeriodOver(distinctPrizeId);
  }

  /// @notice Returns whether the prize period is over
  /// @return True if the prize period is over, false otherwise
  function _isPrizePeriodOver(uint256 distinctPrizeId) internal view returns (bool) {
    return _currentTime() >= _prizePeriodEndAt(distinctPrizeId);
  }

  /// @notice Returns the timestamp at which the prize period ends
  /// @return The timestamp at which the prize period ends.
  function prizePeriodEndAt(uint256 distinctPrizeId) external view returns (uint256) {
    // current prize started at is non-inclusive, so add one
    return _prizePeriodEndAt(distinctPrizeId);
  }

  /// @notice Returns the timestamp at which the prize period ends
  /// @return The timestamp at which the prize period ends.
  function _prizePeriodEndAt(uint256 distinctPrizeId) internal view returns (uint256) {
    // current prize started at is non-inclusive, so add one
    return distinctPrizeList[distinctPrizeId].prizePeriodStartedAt.add(distinctPrizeList[distinctPrizeId].prizePeriodSeconds);
  }

  /// @notice Awards collateral as tickets to a user
  /// @param user Recipient of minted tokens
  /// @param amount Amount of minted tokens
  function _awardTickets(address user, uint256 amount) internal {
    prizePool.award(user, amount, address(ticket));
  }

  /// @notice Mints ticket or sponsorship tokens for user.
  /// @dev Mints ticket or sponsorship tokens by looking up the address in the prizePool.tokens mapping.
  /// @param user Recipient of minted tokens
  /// @param amount Amount of minted tokens
  /// @param tokenIndex Index (0 or 1) of a token in the prizePool.tokens mapping
  function _awardToken(address user, uint256 amount, uint8 tokenIndex) internal {
    ControlledTokenInterface[] memory _controlledTokens = prizePool.tokens();
    require(tokenIndex <= _controlledTokens.length, "PeriodicPrizeStrategy/award-invalid-token-index");
    ControlledTokenInterface _token = _controlledTokens[tokenIndex];
    prizePool.award(user, amount, address(_token));
  }

  /// @notice Called by the PrizePool for transfers of controlled tokens
  /// @dev Note that this is only for *transfers*, not mints or burns
  /// @param controlledToken The type of collateral that is being sent
  function beforeTokenTransfer(address from, address to, uint256 amount, address controlledToken) external override onlyPrizePool {
    require(from != to, "PeriodicPrizeStrategy/transfer-to-self");

    if (controlledToken == address(ticket)) {
      _requireAwardNotInProgress();
    }

    if (address(tokenListener) != address(0)) {
      tokenListener.beforeTokenTransfer(from, to, amount, controlledToken);
    }
  }

  /// @notice Called by the PrizePool when minting controlled tokens
  /// @param controlledToken The type of collateral that is being minted
  function beforeTokenMint(
    address to,
    uint256 amount,
    address controlledToken,
    address referrer
  )
    external
    override
    onlyPrizePool
  {
    if (controlledToken == address(ticket)) {
      _requireAwardNotInProgress();
    }
    if (address(tokenListener) != address(0)) {
      tokenListener.beforeTokenMint(to, amount, controlledToken, referrer);
    }
  }

  /// @notice returns the current time.  Used for testing.
  /// @return The current time (block.timestamp)
  function _currentTime() internal virtual view returns (uint256) {
    return block.timestamp;
  }

  /// @notice returns the current time.  Used for testing.
  /// @return The current time (block.timestamp)
  function _currentBlock() internal virtual view returns (uint256) {
    return block.number;
  }

  /// @notice Starts the award process by starting random number request.  The prize period must have ended.
  /// @dev The RNG-Request-Fee is expected to be held within this contract before calling this function
  function startAward(uint256 distinctPrizeId) external requireCanStartAward {
    (address feeToken, uint256 requestFee) = rng.getRequestFee();
    if (feeToken != address(0) && requestFee > 0) {
      IERC20Upgradeable(feeToken).safeApprove(address(rng), requestFee);
    }

    (uint32 requestId, uint32 lockBlock) = rng.requestRandomNumber();

    distinctPrizeList[distinctPrizeId].rngRequest.id = requestId;
    distinctPrizeList[distinctPrizeId].rngRequest.lockBlock = lockBlock;
    distinctPrizeList[distinctPrizeId].rngRequest.requestedAt = _currentTime().toUint32();

    // todo: fix emit with distinctPrizeId
    emit PrizePoolAwardStarted(_msgSender(), address(prizePool), requestId, lockBlock);
  }

  /// @notice Can be called by anyone to unlock the tickets if the RNG has timed out.
  function cancelAward(uint256 distinctPrizeId) public {
    require(isRngTimedOut(), "PeriodicPrizeStrategy/rng-not-timedout");

    uint32 requestId = distinctPrizeList[distinctPrizeId].rngRequest.id;
    uint32 lockBlock = distinctPrizeList[distinctPrizeId].rngRequest.lockBlock;

    delete distinctPrizeList[distinctPrizeId].rngRequest;

    emit RngRequestFailed(distinctPrizeId);
    emit PrizePoolAwardCancelled(msg.sender, address(prizePool), requestId, lockBlock, distinctPrizeId);
  }

  /// @notice Completes the award process and awards the winners.  The random number must have been requested and is now available.
  function completeAward() external requireCanCompleteAward {
    uint256 randomNumber = rng.randomNumber(rngRequest.id);
    delete rngRequest;

    if (address(beforeAwardListener) != address(0)) {
      beforeAwardListener.beforePrizePoolAwarded(randomNumber, prizePeriodStartedAt);
    }
    _distribute(randomNumber);
    if (address(periodicPrizeStrategyListener) != address(0)) {
      periodicPrizeStrategyListener.afterPrizePoolAwarded(randomNumber, prizePeriodStartedAt);
    }

    // // to avoid clock drift, we should calculate the start time based on the previous period start time.
    // prizePeriodStartedAt = _calculateNextPrizePeriodStartTime(_currentTime());

    emit PrizePoolAwarded(_msgSender(), randomNumber);
    // emit PrizePoolOpened(_msgSender(), prizePeriodStartedAt);
  }

  modifier requireAwardNotInProgress() {
      _;
  }
  
  modifier requireCanCompleteAward() {
      _;
  }

  modifier onlyOwnerOrListener() {
    require(_msgSender() == owner() ||
            _msgSender() == address(periodicPrizeStrategyListener) ||
            _msgSender() == address(beforeAwardListener),
            "PeriodicPrizeStrategy/only-owner-or-listener");
    _;
  }
  
  modifier onlyPrizePool() {
    require(_msgSender() == address(prizePool), "PeriodicPrizeStrategy/only-prize-pool");
    _;
  }

  modifier onlyPrizePoolControlledToken(address controlledToken) {
    require(prizePool.isControlled(ControlledTokenInterface(controlledToken)), "PeriodicPrizeStrategy/unknown-token");
    _;
  }

  modifier canAddLiquidity(address from, address controlledToken, uint256 amount) {
    require(amount <= IERC20Upgradeable(controlledToken).balanceOf(from), "PeriodicPrizeStrategy/unknown-token");
    _;
  }
  
  // todo: fix
  modifier canRemoveLiquidity(address from, address controlledToken, uint256 amount) {
    require(amount <= IERC20Upgradeable(controlledToken).balanceOf(from), "PeriodicPrizeStrategy/unknown-token");
    _;
  }
}
