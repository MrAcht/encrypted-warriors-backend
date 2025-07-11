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

    /**
     * @dev Initiates a confidential combat between two deployed units.
     * The combat outcome is determined using FHE operations on encrypted attributes.
     * A public outcome (ATTACKER_WINS, DEFENDER_WINS, DRAW) is set on-chain.
     * @param _attacker The address of the attacking player.
     * @param _defender The address of the defending player.
     */
    function attack(address _attacker, address _defender) public onlyGamePlayers requireTwoPlayers {
        // Ensure both attacker and defender have deployed their units
        require(playersWarriors[_attacker].deployed, "Attacker unit not deployed.");
        require(playersWarriors[_defender].deployed, "Defender unit not deployed.");
        // Ensure the caller is either the attacker or defender (simplified access)
        require(msg.sender == _attacker || msg.sender == _defender, "Only involved players can initiate combat.");

        Warrior storage attackerUnit = playersWarriors[_attacker];
        Warrior storage defenderUnit = playersWarriors[_defender];

        // --- Confidential Combat Logic using FHE operations ---
        // Compare attacker's encryptedAttack with defender's encryptedDefense
        ebool attackerWins = TFHE.gt(attackerUnit.encryptedAttack, defenderUnit.encryptedDefense); // Is attack > defense?
        ebool defenderWins = TFHE.gt(defenderUnit.encryptedDefense, attackerUnit.encryptedAttack); // Is defense > attack?
        ebool isDraw = TFHE.eq(attackerUnit.encryptedAttack, defenderUnit.encryptedDefense); // Is attack == defense?

        // --- Public Outcome Revelation ---
        // TFHE.decrypt can be called on an ebool within the contract to get its boolean plaintext.
        // This makes the combat outcome publicly verifiable, while the exact stats remain private.
        // In more complex scenarios, specific access control or multi-party decryption might be used.
        if (TFHE.decrypt(attackerWins)) {
            lastCombatOutcome = CombatOutcome.ATTACKER_WINS;
        } else if (TFHE.decrypt(defenderWins)) {
            lastCombatOutcome = CombatOutcome.DEFENDER_WINS;
        } else if (TFHE.decrypt(isDraw)) {
            lastCombatOutcome = CombatOutcome.DRAW;
        } else {
            // Fallback, should not be reached if logic is exhaustive
            lastCombatOutcome = CombatOutcome.NO_COMBAT;
        }

        emit CombatConcluded(_attacker, _defender, lastCombatOutcome);
    }

    /**
     * @dev Returns the last publicly revealed combat outcome.
     */
    function getCombatResult() public view returns (CombatOutcome) {
        return lastCombatOutcome;
    }

    /**
     * @dev Allows the caller to retrieve their own encrypted unit stats,
     * re-encrypted under their FHE public key for client-side decryption.
     * @return encryptedAttack The caller's encrypted attack value as bytes.
     * @return encryptedDefense The caller's encrypted defense value as bytes.
     */
    function getMyEncryptedUnitStats() public view onlyGamePlayers returns (bytes memory encryptedAttack, bytes memory encryptedDefense) {
        require(playersWarriors[msg.sender].deployed, "You have no unit deployed to reveal stats for.");

        // Re-encrypt the stored euint8s with the caller's FHE public key.
        // TFHE.callerPublicKey() retrieves the FHE public key provided by the caller's transaction.
        // This allows the caller to decrypt the returned bytes using their private FHE key client-side.
        return (
            TFHE.reencrypt(playersWarriors[msg.sender].encryptedAttack, TFHE.callerPublicKey()),
            TFHE.reencrypt(playersWarriors[msg.sender].encryptedDefense, TFHE.callerPublicKey())
        );
    }
}