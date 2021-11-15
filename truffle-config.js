const fs = require('fs');
const mnemonic = "";
const HDWalletProvider = require('@truffle/hdwallet-provider');

module.exports = {
  networks: {
    development: {
      provider: () => new HDWalletProvider(mnemonic, `https://matic-mumbai.chainstacklabs.com`),
      network_id: 80001,
      confirmations: 0,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    arbitrum: {
      provider: () => new HDWalletProvider(mnemonic, `https://arbitrum-rinkeby.infura.io/v3/xxxx(private key)`),
      network_id: 421611,
      confirmations: 0,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    polygon: {
      provider: () => new HDWalletProvider(mnemonic, `https://polygon-mainnet.infura.io/v3/xxxx(private key)`),
      network_id: 137,
      confirmations: 0,
      timeoutBlocks: 200,
      skipDryRun: true
    },
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },
  plugins: ["truffle-contract-size"],


  // Configure your compilers
  compilers: {
    solc: {
      version: "0.6.12",    // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      settings: {          // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 10
        }
      }
      //  evmVersion: "byzantium"
      // }
    }
  }
}