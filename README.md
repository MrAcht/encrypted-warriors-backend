# Encrypted Warriors Backend

**Encrypted Warriors** is a next-generation blockchain game backend, built for privacy, fairness, and competitive play. This backend powers the smart contract logic, deployment, and cryptographic operations for the Encrypted Warriors dapp.

## 🚀 Features

- **Solidity Smart Contracts**: Secure, gas-optimized, and extensible.
- **FHEVM Integration Ready**: Designed for confidential on-chain computation using Fully Homomorphic Encryption (FHE).
- **TypeScript + Hardhat**: Modern development stack for reliability and maintainability.
- **Automated Testing**: Comprehensive test suite for all core logic.
- **Docker & CI Ready**: Easy deployment and reproducibility.

## 📦 Project Structure

```
contracts/         # Solidity smart contracts (main: EncryptedWarriors.sol)
test/              # Automated tests (Mocha/Chai)
scripts/           # Deployment and utility scripts
types/             # TypeChain-generated TypeScript types
artifacts/, cache/ # Build artifacts (auto-generated, can be deleted)
fhevmTemp/         # FHEVM-related configs (if using FHEVM)
```

## 🛠️ Getting Started

### Prerequisites

- Node.js v16+
- npm or yarn
- Hardhat (`npm install --save-dev hardhat`)
- (Optional) Docker

### Install Dependencies

```bash
npm install
```

### Compile Contracts

```bash
npx hardhat compile
```

### Run Tests

```bash
npx hardhat test
```

### Deploy Contracts

```bash
npx hardhat run scripts/deploy.js --network <network>
```

### Docker Support

- Build and run with Docker for reproducible environments.
- See `Dockerfile` and `docker-compose.yml` for details.

## 🔒 Security & Privacy

- **FHEVM Ready**: Designed for confidential computation and encrypted game logic.
- **Best Practices**: Follows OpenZeppelin and industry standards for contract security.
- **Automated Tests**: All critical logic is covered by tests.

## 🤝 Contributing

- Fork, branch, and submit pull requests.
- Write clear commit messages and document your code.
- Run tests before submitting.

## 📄 License

MIT License

---

**Encrypted Warriors** — Powering the next era of private, competitive blockchain gaming.
