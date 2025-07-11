// scripts/deploy.js
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  const EncryptedWarriors = await hre.ethers.getContractFactory("EncryptedWarriors");
  const encryptedWarriors = await EncryptedWarriors.deploy();

  await encryptedWarriors.deployed();

  console.log("EncryptedWarriors deployed to:", encryptedWarriors.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });