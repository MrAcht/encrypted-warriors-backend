const { ethers } = require("hardhat")

async function main() {
  console.log("Deploying EncryptedWarriors contract...")

  const EncryptedWarriors = await ethers.getContractFactory("EncryptedWarriors")
  const encryptedWarriors = await EncryptedWarriors.deploy()

  await encryptedWarriors.waitForDeployment()

  console.log("EncryptedWarriors deployed to:", await encryptedWarriors.getAddress())
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })