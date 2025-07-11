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

    // --- Modifiers ---
    // Ensures the caller is one of the registered game players
    modifier onlyGamePlayers() {
        require(msg.sender == player1 || msg.sender == player2, "Not a registered game player.");
        _;
    }

    // Ensures the caller does not already have a unit deployed
    modifier onlyEmptySlot() {
        require(!playersWarriors[msg.sender].deployed, "You already have a unit deployed.");
        _;
    }

    // Ensures both players have joined the game
    modifier requireTwoPlayers() {
        require(playersJoined == MAX_PLAYERS, "Waiting for all players to join.");
        _;
    }

    // --- Functions ---

    /**
     * @dev Allows a player to join the game. Limited to MAX_PLAYERS.
     */
    function joinGame() public {
        require(playersJoined < MAX_PLAYERS, "Game is full.");

        if (playersJoined == 0) {
            player1 = msg.sender;
        } else if (playersJoined == 1 && msg.sender != player1) {
            player2 = msg.sender;
        } else {
            // This case handles attempts to join by player1 again if player2 hasn't joined,
            // or if player2 tries to join but player1 is still the only one.
            revert("Already joined or invalid state to join.");
        }
        playersJoined++;
        emit PlayerJoined(msg.sender, playersJoined);
    }

    /**
     * @dev Allows a player to deploy their unit with encrypted attack and defense.
     * The values are encrypted client-side and passed as bytes, then converted
     * to euint8 on-chain using TFHE.asEuint8.
     * @param _encryptedAttack The encrypted attack value as bytes.
     * @param _encryptedDefense The encrypted defense value as bytes.
     */
    function deployUnit(bytes calldata _encryptedAttack, bytes calldata _encryptedDefense)
        public
        onlyGamePlayers
        onlyEmptySlot
        requireTwoPlayers // Ensure both players are in before deploying units
    {
        // Convert bytes (received from client) to euint8.
        // TFHE.asEuint8 verifies the Zero-Knowledge Proof (ZKPoK) and returns an euint8.
        euint8 attack = TFHE.asEuint8(_encryptedAttack);
        euint8 defense = TFHE.asEuint8(_encryptedDefense);

        // Store the encrypted attributes in the player's Warrior struct.
        // These values remain encrypted on the blockchain.
        playersWarriors[msg.sender] = Warrior(attack, defense, true);

        emit UnitDeployed(msg.sender);
    }
}