const { expect } = require("chai");
const { ethers } = require("hardhat");
const { createInstance } = require("fhevmjs");

async function getFheInstance() {
  // Use local FHEVM node or Zama testnet
  const provider = new ethers.JsonRpcProvider("http://host.docker.internal:8545");
  const chainId = (await provider.getNetwork()).chainId;
  const publicKey = await provider.send("eth_getPublicKey", []);
  return await createInstance({ chainId, publicKey });
}

async function encryptWithProof(instance, value) {
  // For euint8
  const encrypted = instance.encrypt8(value);
  const { encrypted: encryptedHex, proof } = encrypted.toJson();
  return { encryptedHex, proof };
}

describe("EncryptedWarriors", function () {
  let contract;
  let owner, player1, player2, other;
  let fhe;

  before(async function () {
    fhe = await getFheInstance();
  });

  beforeEach(async function () {
    [owner, player1, player2, other] = await ethers.getSigners();
    const EncryptedWarriors = await ethers.getContractFactory("EncryptedWarriors");
    contract = await EncryptedWarriors.deploy();
    await contract.waitForDeployment();
  });

  it("should allow two players to join the game", async function () {
    await expect(contract.connect(player1).joinGame())
      .to.emit(contract, "PlayerJoined")
      .withArgs(player1.address, 1);
    await expect(contract.connect(player2).joinGame())
      .to.emit(contract, "PlayerJoined")
      .withArgs(player2.address, 2);
    await expect(contract.connect(other).joinGame()).to.be.revertedWith("Game is full.");
  });

  it("should not allow the same player to join twice", async function () {
    await contract.connect(player1).joinGame();
    await expect(contract.connect(player1).joinGame()).to.be.reverted;
  });

  it("should allow joined players to deploy a unit after both have joined", async function () {
    await contract.connect(player1).joinGame();
    await contract.connect(player2).joinGame();
    const { encryptedHex: encryptedAttack1, proof: attackProof1 } = await encryptWithProof(fhe, 80);
    const { encryptedHex: encryptedDefense1, proof: defenseProof1 } = await encryptWithProof(fhe, 70);
    const { encryptedHex: encryptedAttack2, proof: attackProof2 } = await encryptWithProof(fhe, 60);
    const { encryptedHex: encryptedDefense2, proof: defenseProof2 } = await encryptWithProof(fhe, 50);
    await expect(contract.connect(player1).deployUnit(encryptedAttack1, attackProof1, encryptedDefense1, defenseProof1))
      .to.emit(contract, "UnitDeployed")
      .withArgs(player1.address);
    await expect(contract.connect(player2).deployUnit(encryptedAttack2, attackProof2, encryptedDefense2, defenseProof2))
      .to.emit(contract, "UnitDeployed")
      .withArgs(player2.address);
    await expect(contract.connect(player1).deployUnit(encryptedAttack1, attackProof1, encryptedDefense1, defenseProof1))
      .to.be.revertedWith("You already have a unit deployed.");
  });

  it("should not allow deployUnit before both players have joined", async function () {
    await contract.connect(player1).joinGame();
    const { encryptedHex: encryptedAttack, proof: attackProof } = await encryptWithProof(fhe, 80);
    const { encryptedHex: encryptedDefense, proof: defenseProof } = await encryptWithProof(fhe, 70);
    await expect(contract.connect(player1).deployUnit(encryptedAttack, attackProof, encryptedDefense, defenseProof))
      .to.be.revertedWith("Waiting for all players to join.");
  });

  it("should allow only joined players to deploy a unit", async function () {
    await contract.connect(player1).joinGame();
    await contract.connect(player2).joinGame();
    const { encryptedHex: encryptedAttack, proof: attackProof } = await encryptWithProof(fhe, 80);
    const { encryptedHex: encryptedDefense, proof: defenseProof } = await encryptWithProof(fhe, 70);
    await expect(contract.connect(other).deployUnit(encryptedAttack, attackProof, encryptedDefense, defenseProof))
      .to.be.revertedWith("Not a registered game player.");
  });

  it("should allow combat between two deployed units and emit event", async function () {
    await contract.connect(player1).joinGame();
    await contract.connect(player2).joinGame();
    const { encryptedHex: encryptedAttack1, proof: attackProof1 } = await encryptWithProof(fhe, 80);
    const { encryptedHex: encryptedDefense1, proof: defenseProof1 } = await encryptWithProof(fhe, 70);
    const { encryptedHex: encryptedAttack2, proof: attackProof2 } = await encryptWithProof(fhe, 60);
    const { encryptedHex: encryptedDefense2, proof: defenseProof2 } = await encryptWithProof(fhe, 50);
    await contract.connect(player1).deployUnit(encryptedAttack1, attackProof1, encryptedDefense1, defenseProof1);
    await contract.connect(player2).deployUnit(encryptedAttack2, attackProof2, encryptedDefense2, defenseProof2);
    await expect(contract.connect(player1).attack(player1.address, player2.address))
      .to.emit(contract, "EncryptedCombatResultsStored")
      .withArgs(player1.address, player2.address);
  });

  it("should only allow owner to submit combat outcome", async function () {
    await contract.connect(player1).joinGame();
    await contract.connect(player2).joinGame();
    const { encryptedHex: encryptedAttack1, proof: attackProof1 } = await encryptWithProof(fhe, 80);
    const { encryptedHex: encryptedDefense1, proof: defenseProof1 } = await encryptWithProof(fhe, 70);
    const { encryptedHex: encryptedAttack2, proof: attackProof2 } = await encryptWithProof(fhe, 60);
    const { encryptedHex: encryptedDefense2, proof: defenseProof2 } = await encryptWithProof(fhe, 50);
    await contract.connect(player1).deployUnit(encryptedAttack1, attackProof1, encryptedDefense1, defenseProof1);
    await contract.connect(player2).deployUnit(encryptedAttack2, attackProof2, encryptedDefense2, defenseProof2);
    await contract.connect(player1).attack(player1.address, player2.address);
    await expect(contract.connect(owner).submitCombatOutcome(1))
      .to.emit(contract, "PublicOutcomeSubmitted")
      .withArgs(1);
    await expect(contract.connect(player1).submitCombatOutcome(1))
      .to.be.revertedWith("Only the contract owner can call this function.");
  });

  it("should return the last combat outcome", async function () {
    await contract.connect(player1).joinGame();
    await contract.connect(player2).joinGame();
    const { encryptedHex: encryptedAttack1, proof: attackProof1 } = await encryptWithProof(fhe, 80);
    const { encryptedHex: encryptedDefense1, proof: defenseProof1 } = await encryptWithProof(fhe, 70);
    const { encryptedHex: encryptedAttack2, proof: attackProof2 } = await encryptWithProof(fhe, 60);
    const { encryptedHex: encryptedDefense2, proof: defenseProof2 } = await encryptWithProof(fhe, 50);
    await contract.connect(player1).deployUnit(encryptedAttack1, attackProof1, encryptedDefense1, defenseProof1);
    await contract.connect(player2).deployUnit(encryptedAttack2, attackProof2, encryptedDefense2, defenseProof2);
    await contract.connect(player1).attack(player1.address, player2.address);
    await contract.connect(owner).submitCombatOutcome(2);
    expect(await contract.getCombatResult()).to.equal(2);
  });
});