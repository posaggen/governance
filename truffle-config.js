module.exports = {
  networks: {
    coverage: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 8777,            // Standard Ethereum port (default: none)
      network_id: "5777",       // Any network (default: none)
      gas: 6721975
    },
    test: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 7545,            // Standard Ethereum port (default: none)
      network_id: "*",       // Any network (default: none)
      gas: 6721975
    },
  },
  compilers: {
    solc: {
      version: "0.5.11",
      parser: "solcjs",  // Leverages solc-js purely for speedy parsing
      settings: {
        optimizer: {
          enabled: true,
          runs: 1000  // Optimize for how many times you intend to run the code
        },
      }
    }
  },
  plugins: ["solidity-coverage"],
  mocha: {
    reporter: 'eth-gas-reporter',
    reporterOptions : { 
      excludeContracts: ['Migrations'],
      proxyResolver:'TransactionWatcher',
    }
  },
}
