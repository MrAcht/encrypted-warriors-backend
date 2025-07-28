import "@fhevm/hardhat-plugin"
import "@nomicfoundation/hardhat-chai-matchers"
import "@nomicfoundation/hardhat-ethers"
import "@nomicfoundation/hardhat-verify"
import "@typechain/hardhat"
import "hardhat-deploy"
import "hardhat-gas-reporter"
import "solidity-coverage"
import * as dotenv from "dotenv";
import module from "module";
dotenv.config();

const config = {
  defaultNetwork: "hardhat",
  namedAccounts: {
    deployer: 0,
  },
  etherscan: {
    apiKey: {
      sepolia: process.env.ETHERSCAN_API_KEY || "",
    },
  },
  gasReporter: {
    currency: "USD",
    enabled: !!process.env.REPORT_GAS,
    excludeContracts: [],
  },
  networks: {
    hardhat: {
      chainId: 31337,
    },
    anvil: {
      chainId: 31337,
      url: "http://localhost:8545",
    },
    sepolia: {
      url: "https://eth-sepolia.g.alchemy.com/v2/q8DGMPh8W3Why7lADaolnt9182zpEqCL",
      accounts: [process.env.PRIVATE_KEY!],
      chainId: 11155111,
    },
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./contracts",
    tests: "./test",
  },
  solidity: {
    version: "0.8.24",
    settings: {
      metadata: {
        bytecodeHash: "none",
      },
      optimizer: {
        enabled: true,
        runs: 800,
      },
      evmVersion: "cancun",
    },
  },
  typechain: {
    outDir: "types",
    target: "ethers-v6",
  },

  fhevm: {
    config: "sepolia",
  },
} as any;

if (process.platform === "win32") {
  const originalResolveFilename = (module as any)._resolveFilename;
  (module as any)._resolveFilename = function (...args: any[]) {
    const result = originalResolveFilename.apply(this, args);
    return typeof result === "string" ? result.replace(/\\/g, "/") : result;
  };
}

export default config;

