// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../PrizeSplit.sol";
import "../PeriodicPrizeStrategy.sol";

contract ERC721SinglePrizeStrategy is PeriodicPrizeStrategy, PrizeSplit {
  // Maximum number of ERC721Prizes per award distribution period
  uint256 internal _numberOfERC721Prizes = 0;

  mapping(IERC721Upgradeable => mapping(address => uint256[])) public externalErc721TokenIdsByUser;

  function initializeERC721Winners (
    uint256 _prizePeriodStart,
    uint256 _prizePeriodSeconds,
    PrizePool _prizePool,
    TicketInterface _ticket,
    IERC20Upgradeable _sponsorship,
    RNGInterface _rng
  ) public initializer {
    IERC20Upgradeable[] memory _externalErc20Awards;

    PeriodicPrizeStrategy.initialize(
      _prizePeriodStart,
      _prizePeriodSeconds,
      _prizePool,
      _ticket,
      _sponsorship,
      _rng,
      _externalErc20Awards
    );

  }

  function addExternalErc721AwardByUser(IERC721Upgradeable _externalErc721, uint256 calldata _tokenId) external {
    require(prizePool.canAwardExternal(address(_externalErc721)), "PeriodicPrizeStrategy/cannot-award-external");
    require(address(_externalErc721).supportsInterface(Constants.ERC165_INTERFACE_ID_ERC721), "PeriodicPrizeStrategy/erc721-invalid");

    if (!externalErc721s.contains(address(_externalErc721))) {
      externalErc721s.addAddress(address(_externalErc721));
    }

    _incrementNumberOfERC721Prizes();
    _addExternalErc721Award(_externalErc721, _tokenId);

    emit ExternalErc721AwardAdded(_externalErc721, _tokenIds);
  }

  /**
    * @notice Sets maximum number of winners.
    * @dev Sets maximum number of winners per award distribution period.
    * @param count Number of winners.
  */
  function _decrementNumberOfERC721Prizes() internal requireAwardNotInProgress {
    _setNumberOfWinners(_numberOfERC721Prizes + 1);
  }

  /**
    * @notice Sets maximum number of winners.
    * @dev Sets maximum number of winners per award distribution period.
    * @param count Number of winners.
  */
  function _incrementNumberOfERC721Prizes() internal requireAwardNotInProgress {
    _setNumberOfWinners(_numberOfERC721Prizes - 1);
  }

   /**
    * @dev Set the maximum number of winners. Must be greater than 0.
    * @param count Number of winners.
  */
  function _setNumberOfWinners(uint256 count) internal {
    require(count > 0, "MultipleWinners/winners-gte-one");

    __numberOfWinners = count;
    emit NumberOfWinnersSet(count);
  }

  /**
    * @notice Maximum number of winners per award distribution period
    * @dev Read maximum number of winners per award distribution period from internal __numberOfWinners variable.
    * @return __numberOfWinners The total number of winners per prize award.
  */
  function numberOfWinners() external view returns (uint256) {
    return __numberOfWinners;
  }

  /**
    * @notice Award ticket or sponsorship tokens to prize split recipient.
    * @dev Award ticket or sponsorship tokens to prize split recipient via the linked PrizePool contract.
    * @param target Recipient of minted tokens
    * @param amount Amount of minted tokens
    * @param tokenIndex Index (0 or 1) of a token in the prizePool.tokens mapping
  */
  function _awardPrizeSplitAmount(address target, uint256 amount, uint8 tokenIndex) override internal {
    _awardToken(target, amount, tokenIndex);
  }

  /**
    * @notice Distributes captured award balance to winners
    * @dev Distributes the captured award balance to the main winner and secondary winners if __numberOfWinners greater than 1.
    * @param randomNumber Random number seed used to select winners
  */
  function _distribute(uint256 randomNumber) internal override {
    uint256 prize = prizePool.captureAwardBalance();

    // distributes prize to prize splits and returns remaining award.
    prize = _distributePrizeSplits(prize);

    if (IERC20Upgradeable(address(ticket)).totalSupply() == 0) {
      emit NoWinners();
      return;
    }

    bool _carryOverBlocklistPrizes = carryOverBlocklist;

    // main winner is simply the first that is drawn
    uint256 numberOfWinners = __numberOfWinners;
    address[] memory winners = new address[](numberOfWinners);
    uint256 nextRandom = randomNumber;
    uint256 winnerCount = 0;
    uint256 retries = 0;
    uint256 _retryCount = blocklistRetryCount;
    while (winnerCount < numberOfWinners) {
      address winner = ticket.draw(nextRandom);

      if (!isBlocklisted[winner]) {
        winners[winnerCount++] = winner;
      } else if (++retries >= _retryCount) {
        emit RetryMaxLimitReached(winnerCount);
        if(winnerCount == 0) {
          emit NoWinners();
        }
        break;
      }

      // add some arbitrary numbers to the previous random number to ensure no matches with the UniformRandomNumber lib
      bytes32 nextRandomHash = keccak256(abi.encodePacked(nextRandom + 499 + winnerCount*521));
      nextRandom = uint256(nextRandomHash);
    }

    // main winner gets all external ERC721 tokens
    _awardExternalErc721s(winners[0]);

    // yield prize is split up among all winners
    uint256 prizeShare = _carryOverBlocklistPrizes ? prize.div(numberOfWinners) : prize.div(winnerCount);
    if (prizeShare > 0) {
      for (uint i = 0; i < winnerCount; i++) {
        _awardTickets(winners[i], prizeShare);
      }
    }

    if (splitExternalErc20Awards) {
      address currentToken = externalErc20s.start();
      while (currentToken != address(0) && currentToken != externalErc20s.end()) {
        uint256 balance = IERC20Upgradeable(currentToken).balanceOf(address(prizePool));
        uint256 split = _carryOverBlocklistPrizes ? balance.div(numberOfWinners) : balance.div(winnerCount);
        if (split > 0) {
          for (uint256 i = 0; i < winnerCount; i++) {
            prizePool.awardExternalERC20(winners[i], currentToken, split);
          }
        }
        currentToken = externalErc20s.next(currentToken);
      }
    } else {
      _awardExternalErc20s(winners[0]);
    }
  }
}
