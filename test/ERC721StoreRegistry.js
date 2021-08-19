const { deployMockContract } = require('ethereum-waffle')
const { deploy1820 } = require('deploy-eip-1820')


const { expect } = require('chai')
const hardhat = require('hardhat')
const { AddressZero, Zero, One } = require('ethers').constants

const now = () => (new Date()).getTime() / 1000 | 0
const toWei = (val) => ethers.utils.parseEther('' + val)
const debug = require('debug')('ptv3:PeriodicPrizePool.test')

let overrides = { gasLimit: 9500000 }

describe('MultipleWinners', function() {
  let wallet, wallet2, wallet3, wallet4

  let externalERC20Award, externalERC721Award

  let registry, comptroller, prizePool, prizeStrategy, token

  let ticket, sponsorship, rng, rngFeeToken

  beforeEach(async () => {
    [wallet, wallet2, wallet3, wallet4] = await hardhat.ethers.getSigners()

    debug({
      wallet: wallet.address,
      wallet2: wallet2.address,
      wallet3: wallet3.address,
      wallet4: wallet4.address
    })

    debug('deploying PrizePool...')
    const PrizePool = await hre.artifacts.readArtifact("PrizePool")
    prizePool = await deployMockContract(wallet, PrizePool.abi, overrides)

    debug('deploying ERC721StoreRegistry...')
    const ERC721StoreRegistry =  await hre.ethers.getContractFactory("ERC721StoreRegistry", wallet, overrides)
    storeRegistry = await ERC721StoreRegistry.deploy()

    debug('initializing storeRegistry...')
    await storeRegistry.initialize(prizePool.address)

    debug('initialized!')
  })
})
