module.exports = {
  providerOptions: {
    mnemonic:
      "glad notable bullet donkey fall dolphin simple size stone evil slogan dinner",
    default_balance_ether: 1000000
  },
  istanbulReporter: ["html", "lcov"],
  skipFiles: [
    "mocks/cDAINonMintableMock.sol",
    "mocks/GoodCompoundStakingTest.sol",
    "mocks/DaiEthPriceMockOracle.sol",
    "mocks/TwentyDecimalsTokenMock.sol",
    "mocks/EightDecimalsTokenMock.sol",
    "mocks/EthUSDMockOracle.sol",
    "mocks/cDAILowWorthMock.sol",
    "mocks/cEDTMock.sol",
    "mocks/cUSDCMock.sol",
    "mocks/OverMintTesterRegularStake.sol",
    "mocks/GoodFundManagerTest.sol",
    "mocks/cSDTMock.sol",
    "mocks/SixteenDecimalsTokenMock.sol",
    "mocks/GasPriceMockOracle.sol",
    "mocks/UsdcMock.sol",
    "mocks/DAIMock.sol",
    "mocks/BatUSDMockOracle.sol",
    "mocks/CompUsdMockOracle.sol",
    "mocks/OverMintTester.sol",
    "mocks/cDAIMock.sol",
    "mocks/cBATMock.sol",
    "utils/ReputationTestHelper.sol",
    "utils/BancorFormula.sol",
    "utils/DSMath.sol"
  ],
  mocha: {
    grep: "@skip-on-coverage", // Find everything with this tag
    invert: true, // Run the grep's inverse set.
    enableTimeouts: false,
    timeout: 3600000
  }
};
