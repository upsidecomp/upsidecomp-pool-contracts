const { deployMockContract } = require('ethereum-waffle')

const { ethers } = require('ethers')
const { expect } = require('chai')
const hardhat = require('hardhat')
const { call } = require('./../helpers/call')
const { AddressZero } = require('ethers').constants

const toWei = ethers.utils.parseEther
const fromWei = ethers.utils.formatEther

const debug = require('debug')('ptv3:BanklessPrizePool.test')

let overrides = { gasLimit: 9500000 }

const NFT_TOKEN_ID = 1

describe('BanklessPrizePool', function() {
  let wallet, wallet2

  let prizePool, erc20token, erc721token, yieldSourceStub, prizeStrategy, reserve, reserveRegistry
  let multiTokenPrizePool, multiTokenPrizeStrategy

  let poolMaxExitFee = toWei('0.5')

  let ticket, sponsorship, nft

  let compLike

  beforeEach(async () => {
    [wallet, wallet2] = await hardhat.ethers.getSigners()
    debug(`using wallet ${wallet.address}`)

    debug('mocking tokens...')
    const IERC20 = await hre.artifacts.readArtifact("IERC20Upgradeable")
    erc20token = await deployMockContract(wallet, IERC20.abi, overrides)

    const IERC721 = await hre.artifacts.readArtifact("IERC721Upgradeable")
    erc721token = await deployMockContract(wallet, IERC721.abi, overrides)

    const BanklessYieldSourceStub = await hre.artifacts.readArtifact("BanklessYieldSourceStub")
    yieldSourceStub = await deployMockContract(wallet, BanklessYieldSourceStub.abi, overrides)
    await yieldSourceStub.mock.token.returns(erc20token.address)

    const TokenListenerInterface = await hre.artifacts.readArtifact("TokenListenerInterface")
    prizeStrategy = await deployMockContract(wallet, TokenListenerInterface.abi, overrides)

    await prizeStrategy.mock.supportsInterface.returns(true)
    await prizeStrategy.mock.supportsInterface.withArgs('0xffffffff').returns(false)

    debug('deploying PrizePoolHarness...')
    const BanklessPrizePoolHarness = await hre.ethers.getContractFactory("BanklessPrizePoolHarness", wallet, overrides)
    prizePool = await BanklessPrizePoolHarness.deploy()

    const ControlledToken = await hre.artifacts.readArtifact("ControlledToken")
    ticket = await deployMockContract(wallet, ControlledToken.abi, overrides)
    await ticket.mock.controller.returns(prizePool.address)
  })

  describe('initialize()', () => {
    it('should fire the events', async () => {
      let tx = prizePool.initializeAll(
        [ticket.address],
        poolMaxExitFee,
        yieldSourceStub.address
      )

      await expect(tx)
        .to.emit(prizePool, 'Initialized')
        .withArgs(
          poolMaxExitFee
        )

      await expect(tx)
        .to.emit(prizePool, 'ControlledTokenAdded')
        .withArgs(
          ticket.address
        )

      await expect(prizePool.setPrizeStrategy(prizeStrategy.address))
        .to.emit(prizePool, 'PrizeStrategySet')
        .withArgs(prizeStrategy.address)
    })
  })

  describe('with a mocked prize pool', () => {
    beforeEach(async () => {
      await prizePool.initializeAll(
        [ticket.address],
        poolMaxExitFee,
        yieldSourceStub.address
      )
      await prizePool.setPrizeStrategy(prizeStrategy.address)
      // Credit rate is 1% per second, credit limit is 10%
      // await prizePool.setCreditPlanOf(ticket.address, toWei('0.01'), toWei('0.1'))
    })

    describe("beforeTokenTransfer()", () => {
      it('should not allow uncontrolled tokens to call', async () => {
        await expect(prizePool.beforeTokenTransfer(wallet.address, wallet2.address, toWei('1')))
          .to.be.revertedWith('PrizePool/unknown-token')
      })

      it('should allow controlled tokens to call', async () => {
        await ticket.mock.balanceOf.withArgs(wallet.address).returns(toWei('10'))
        await ticket.mock.balanceOf.withArgs(wallet2.address).returns(toWei('10'))

        await prizeStrategy.mock.beforeTokenTransfer.withArgs(wallet.address, wallet2.address, toWei('1'), ticket.address).returns()
        await ticket.call(prizePool, 'beforeTokenTransfer', wallet.address, wallet2.address, toWei('1'))
      })

      it('should allow a user to transfer to themselves', async () => {
        await ticket.mock.balanceOf.withArgs(wallet.address).returns(toWei('100'))

        debug(`beforeTokenTransfer...`)
        await prizeStrategy.mock.beforeTokenTransfer.withArgs(wallet.address, wallet.address, toWei('50'), ticket.address).returns()
        await ticket.call(prizePool, 'beforeTokenTransfer', wallet.address, wallet.address, toWei('50'))
      })
    })

    describe('initialize()', () => {
      it('should set all the vars', async () => {
        expect(await prizePool.token()).to.equal(erc20token.address)
      })

      it('should reject invalid params', async () => {
        const _initArgs = [
          [ticket.address],
          poolMaxExitFee,
          yieldSourceStub.address
        ]
        let initArgs

        debug('deploying secondary prizePool...')
        const PrizePoolHarness = await hre.ethers.getContractFactory("BanklessPrizePoolHarness", wallet, overrides)
        const prizePool2 = await PrizePoolHarness.deploy()

        debug('testing initialization of secondary prizeStrategy...')

        initArgs = _initArgs.slice()
        await ticket.mock.controller.returns(AddressZero)
        await expect(prizePool2.initializeAll(...initArgs)).to.be.revertedWith('PrizePool/token-ctrlr-mismatch')
      })
    })

    describe('depositTo()', () => {
      it('should revert when deposit exceeds liquidity cap', async () => {
        const amount = toWei('1')
        const liquidityCap = toWei('1000')

        await ticket.mock.totalSupply.returns(liquidityCap)
        await prizePool.setLiquidityCap(liquidityCap)

        await expect(prizePool.depositTo(wallet2.address, amount, ticket.address, AddressZero))
          .to.be.revertedWith("PrizePool/exceeds-liquidity-cap")
      })
    })

    describe('withdrawInstantlyFrom()', () => {
      it('should allow a user to withdraw instantly', async () => {
        let amount = toWei('10')

        // updateAwardBalance
        await yieldSourceStub.mock.balance.returns('0')
        await ticket.mock.totalSupply.returns(amount)
        await ticket.mock.balanceOf.withArgs(wallet.address).returns(amount)

        await ticket.mock.controllerBurnFrom.withArgs(wallet.address, wallet.address, amount).returns()
        await erc20token.mock.transfer.withArgs(wallet.address, toWei('10')).returns(true)

        await expect(prizePool.withdrawInstantlyFrom(wallet.address, amount, ticket.address, toWei('10')))
          .to.emit(prizePool, 'InstantWithdrawal')
          .withArgs(wallet.address, wallet.address, ticket.address, amount)
      })

      it('should allow a user to set a maximum exit fee', async () => {
        let amount = toWei('10')
        let fee = toWei('1')

        let redeemed = amount.sub(fee)

        // updateAwardBalance
        await yieldSourceStub.mock.balance.returns('0')
        await ticket.mock.totalSupply.returns(amount)
        await ticket.mock.balanceOf.withArgs(wallet.address).returns(toWei('10'))

        await ticket.mock.controllerBurnFrom.withArgs(wallet2.address, wallet.address, amount).returns()
        await yieldSourceStub.mock.redeem.withArgs(redeemed).returns(redeemed)
        await erc20token.mock.transfer.withArgs(wallet.address, redeemed).returns(true)

        await expect(prizePool.connect(wallet2).withdrawInstantlyFrom(wallet.address, amount, ticket.address, fee))
          .to.emit(prizePool, 'InstantWithdrawal')
          .withArgs(wallet2.address, wallet.address, ticket.address, amount, redeemed, fee)
      })

      it('should revert if fee exceeds the user maximum', async () => {
        let amount = toWei('10')

        const redeemed = toWei('9')

        // updateAwardBalance
        await yieldSourceStub.mock.balance.returns('0')
        await ticket.mock.totalSupply.returns(amount)
        await ticket.mock.balanceOf.withArgs(wallet.address).returns(amount)

        await ticket.mock.controllerBurnFrom.withArgs(wallet.address, wallet.address, amount).returns()
        await yieldSourceStub.mock.redeem.withArgs(redeemed).returns(redeemed)
        await erc20token.mock.transfer.withArgs(wallet.address, toWei('10')).returns(true)

        await expect(prizePool.withdrawInstantlyFrom(wallet.address, amount, ticket.address, toWei('0.3')))
          .to.be.revertedWith('PrizePool/exit-fee-exceeds-user-maximum')
      })

      it('should limit the size of the fee', async () => {
        let amount = toWei('20')

        // fee is now 4/5 of the withdrawal amount
        await prizePool.setCreditPlanOf(ticket.address, toWei('0.01'), toWei('0.8'))

        // updateAwardBalance
        await yieldSourceStub.mock.balance.returns('0')
        await ticket.mock.totalSupply.returns(amount)
        await ticket.mock.balanceOf.withArgs(wallet.address).returns(amount)

        await ticket.mock
          .controllerBurnFrom
          .withArgs(wallet.address, wallet.address, amount)
          .returns()

        await yieldSourceStub.mock
          .redeem
          .withArgs(toWei('10'))
          .returns(toWei('10'))

        await erc20token.mock
          .transfer
          .withArgs(wallet.address, toWei('10'))
          .returns(true)


        // max exit fee is 10, well above
        await expect(prizePool.withdrawInstantlyFrom(wallet.address, amount, ticket.address, toWei('10')))
          .to.emit(prizePool, 'InstantWithdrawal')
          .withArgs(wallet.address, wallet.address, ticket.address, amount, toWei('10'), toWei('10'))
      })

      it('should not allow the prize-strategy to set exit fees exceeding the max', async () => {
        let amount = toWei('10')

        // updateAwardBalance
        await yieldSourceStub.mock.balance.returns('0')
        await ticket.mock.totalSupply.returns(amount)
        await ticket.mock.balanceOf.withArgs(wallet.address).returns(amount)

        await ticket.mock.controllerBurnFrom.withArgs(wallet.address, wallet.address, amount).returns()
        await yieldSourceStub.mock.redeem.withArgs(toWei('10')).returns(toWei('10'))
        await erc20token.mock.transfer.withArgs(wallet.address, toWei('10')).returns(true)

        await expect(prizePool.withdrawInstantlyFrom(wallet.address, amount, ticket.address, toWei('0.3')))
          .to.be.revertedWith('PrizePool/exit-fee-exceeds-user-maximum')
      })

      it('should not allow the prize-strategy to set exit fees exceeding the max', async () => {
        let amount = toWei('11')

        // updateAwardBalance
        await yieldSourceStub.mock.balance.returns('0')
        await ticket.mock.totalSupply.returns(amount)
        await ticket.mock.balanceOf.withArgs(wallet.address).returns(toWei('10'))

        await ticket.mock.controllerBurnFrom.withArgs(wallet.address, wallet.address, amount).returns()
        await yieldSourceStub.mock.redeem.withArgs(toWei('10')).returns(toWei('10'))
        await erc20token.mock.transfer.withArgs(wallet.address, toWei('10')).returns(true)

        // PrizeStrategy exit fee: 100.0
        // PrizePool max exit fee: 5.5  (should be capped at this)
        // User max exit fee:      5.6
        await expect(prizePool.withdrawInstantlyFrom(wallet.address, amount, ticket.address, toWei('5.6')))
          .to.not.be.revertedWith('PrizePool/exit-fee-exceeds-user-maximum')
      })
    })
  })
});
