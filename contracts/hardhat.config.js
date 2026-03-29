require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.26",
    settings: {
      optimizer: { enabled: true, runs: 200 },
      evmVersion: "cancun",
      viaIR: true,
    },
  },
  networks: {
    // Optimism Mainnet
    optimism: {
      url: process.env.OPTIMISM_RPC_URL || "https://mainnet.optimism.io",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 10,
    },
    // Optimism Sepolia (testnet)
    "optimism-sepolia": {
      url: process.env.OPTIMISM_SEPOLIA_RPC_URL || "https://sepolia.optimism.io",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 11155420,
    },
    // Soneium Mainnet
    soneium: {
      url: process.env.SONEIUM_RPC_URL || "https://rpc.soneium.org/",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 1868,
    },
  },
  etherscan: {
    apiKey: {
      optimisticEthereum: process.env.OPTIMISM_ETHERSCAN_API_KEY || "",
      "optimism-sepolia": process.env.OPTIMISM_ETHERSCAN_API_KEY || "",
      soneium: "empty",
    },
    customChains: [
      {
        network: "optimism-sepolia",
        chainId: 11155420,
        urls: {
          apiURL: "https://api-sepolia-optimistic.etherscan.io/api",
          browserURL: "https://sepolia-optimism.etherscan.io",
        },
      },
      {
        network: "soneium",
        chainId: 1868,
        urls: {
          apiURL: "https://soneium.blockscout.com/api",
          browserURL: "https://soneium.blockscout.com",
        },
      },
    ],
  },
};
