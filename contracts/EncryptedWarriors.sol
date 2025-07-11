// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Import Zama's FHE library for encrypted data types and operations
import "fhevm/lib/TFHE.sol";

/**
 * @title EncryptedWarriors
 * @dev A simplified strategy game contract demonstrating confidential unit attributes
 * using Zama's Fully Homomorphic Encryption (FHE) with euint data types.
 * Unit attack and defense values are kept encrypted on-chain, and combat
 * outcomes are computed confidentially.
 */
contract EncryptedWarriors {
    // Enum to represent the public outcome of a combat
    enum CombatOutcome {
        NO_COMBAT,      // Initial state, or no combat has occurred
        ATTACKER_WINS,  // Attacker's encryptedAttack > Defender's encryptedDefense
        DEFENDER_WINS,  // Defender's encryptedDefense > Attacker's encryptedAttack
        DRAW            // Attacker's encryptedAttack == Defender's encryptedDefense
    }

    // Struct to define a Warrior unit with encrypted attributes
    struct Warrior {
        euint8 encryptedAttack;  // Encrypted attack value (0-255)
        euint8 encryptedDefense; // Encrypted defense value (0-255)
        bool deployed;           // True if the player has deployed a unit
    }

    // --- State Variables ---
    // Mapping to store each player's Warrior unit
    mapping(address => Warrior) public playersWarriors;

    // Addresses of the two players in the game
    address public player1;
    address public player2;

    // Constants for game rules
    uint256 public constant MAX_PLAYERS = 2;
    uint256 public playersJoined = 0; // Counter for players who have joined

    // Stores the outcome of the last combat, publicly visible
    CombatOutcome public lastCombatOutcome;

    // --- Events ---
    // Emitted when a player joins the game
    event PlayerJoined(address indexed playerAddress, uint256 totalPlayers);
    // Emitted when a unit is deployed
    event UnitDeployed(address indexed playerAddress);
    // Emitted after combat, with the public outcome
    event CombatConcluded(address indexed attacker, address indexed defender, CombatOutcome outcome);
}