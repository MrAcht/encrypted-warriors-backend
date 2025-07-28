// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, euint8, ebool, externalEuint8 } from "@fhevm/solidity/lib/FHE.sol";
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

/**
 * @title EncryptedWarriors
 * @dev A simplified strategy game contract demonstrating confidential unit attributes
 * using Zama's Fully Homomorphic Encryption (FHE) with euint data types.
 * Unit attack and defense values are kept encrypted on-chain, and combat
 * outcomes are computed confidentially.
 */
contract EncryptedWarriors is SepoliaConfig {
    enum CombatOutcome {
        NO_COMBAT,
        ATTACKER_WINS,
        DEFENDER_WINS,
        DRAW
    }

    struct Warrior {
        euint8 encryptedAttack;
        euint8 encryptedDefense;
        bool deployed;
    }

    struct Game {
        address creator;
        address player2;
        bool started;
        // Add more fields as needed
    }

    mapping(address => Warrior) public playersWarriors;
    address public player1;
    address public player2;
    uint256 public constant MAX_PLAYERS = 2;
    uint256 public playersJoined = 0;

    // Publicly visible outcome, set by an authorized party after off-chain decryption
    CombatOutcome public lastCombatOutcome;

    // New state variables to store encrypted combat results
    ebool public encryptedAttackerWins;
    ebool public encryptedDefenderWins;
    ebool public encryptedIsDraw;

    // Owner of the contract, typically the deployer, who can submit public outcomes
    address public owner;

    mapping(bytes32 => Game) public games;
    mapping(address => bytes32) public playerGameCode; // Optional: track which game a player is in

    event GameCreated(bytes32 indexed code, address indexed creator);
    event PlayerJoined(bytes32 indexed code, address indexed player);
    event UnitDeployed(address indexed playerAddress);
    event CombatConcluded(address indexed attacker, address indexed defender, CombatOutcome outcome);
    event EncryptedCombatResultsStored(address indexed attacker, address indexed defender);
    event PublicOutcomeSubmitted(CombatOutcome outcome);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyGamePlayers() {
        require(msg.sender == player1 || msg.sender == player2, "Not a registered game player.");
        _;
    }

    modifier onlyEmptySlot() {
        require(!playersWarriors[msg.sender].deployed, "You already have a unit deployed.");
        _;
    }

    modifier requireTwoPlayers() {
        require(playersJoined == MAX_PLAYERS, "Waiting for all players to join.");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function.");
        _;
    }

    // Create a new game and generate a random code
    function createGame() external returns (bytes32) {
        bytes32 code = keccak256(abi.encodePacked(msg.sender, block.timestamp, blockhash(block.number - 1)));
        require(games[code].creator == address(0), "Game already exists");
        games[code] = Game(msg.sender, address(0), false);
        playerGameCode[msg.sender] = code;
        emit GameCreated(code, msg.sender);
        return code;
    }

    // Join a game by code
    function joinGame(bytes32 code) external {
        require(games[code].creator != address(0), "Game does not exist");
        require(games[code].player2 == address(0), "Game already full");
        require(games[code].creator != msg.sender, "Creator cannot join their own game");
        games[code].player2 = msg.sender;
        games[code].started = true;
        playerGameCode[msg.sender] = code;
        emit PlayerJoined(code, msg.sender);
    }

    // Example: get game info by code
    function getGame(bytes32 code) external view returns (address, address, bool) {
        Game memory g = games[code];
        return (g.creator, g.player2, g.started);
    }

    // Add your other game logic here, using 'code' instead of 'gameId'

    function deployUnit(
        externalEuint8 _encryptedAttack,
        bytes calldata _attackProof,
        externalEuint8 _encryptedDefense,
        bytes calldata _defenseProof
    )
        public
        onlyGamePlayers
        onlyEmptySlot
        requireTwoPlayers
    {
        euint8 unitAttack = FHE.fromExternal(_encryptedAttack, _attackProof);
        euint8 unitDefense = FHE.fromExternal(_encryptedDefense, _defenseProof);

        playersWarriors[msg.sender] = Warrior(unitAttack, unitDefense, true);

        FHE.allowThis(unitAttack);
        FHE.allow(unitAttack, msg.sender);
        FHE.allowThis(unitDefense);
        FHE.allow(unitDefense, msg.sender);

        emit UnitDeployed(msg.sender);
    }

    /**
     * @dev Initiates a confidential combat between two deployed units.
     * The combat outcome is determined using FHE operations on encrypted attributes.
     * The encrypted results are stored on-chain for later off-chain decryption.
     * @param _attacker The address of the attacking player.
     * @param _defender The address of the defending player.
     */
    function attack(address _attacker, address _defender) public onlyGamePlayers requireTwoPlayers {
        require(playersWarriors[_attacker].deployed, "Attacker unit not deployed.");
        require(playersWarriors[_defender].deployed, "Defender unit not deployed.");
        require(msg.sender == _attacker || msg.sender == _defender, "Only involved players can initiate combat.");

        Warrior storage attackerUnit = playersWarriors[_attacker];
        Warrior storage defenderUnit = playersWarriors[_defender];

        // --- Confidential Combat Logic using FHE operations ---
        // Store the encrypted boolean results in state variables
        encryptedAttackerWins = FHE.gt(attackerUnit.encryptedAttack, defenderUnit.encryptedDefense);
        encryptedDefenderWins = FHE.gt(defenderUnit.encryptedDefense, attackerUnit.encryptedAttack);
        encryptedIsDraw = FHE.eq(attackerUnit.encryptedAttack, defenderUnit.encryptedAttack);

        // Grant contract owner permission to re-encrypt these ebools for off-chain decryption
        FHE.allow(encryptedAttackerWins, owner);
        FHE.allow(encryptedDefenderWins, owner);
        FHE.allow(encryptedIsDraw, owner);

        emit EncryptedCombatResultsStored(_attacker, _defender);
    }

    /**
     * @dev Allows the contract owner to submit the public combat outcome after off-chain decryption.
     * This function should be called by an off-chain relayer or the owner after decrypting
     * the `encryptedAttackerWins`, `encryptedDefenderWins`, and `encryptedIsDraw` values.
     * @param _outcome The plaintext combat outcome.
     */
    function submitCombatOutcome(CombatOutcome _outcome) public onlyOwner {
        lastCombatOutcome = _outcome;
        emit PublicOutcomeSubmitted(_outcome);
        // Optionally, clear the encrypted results after they've been publicly revealed
        // encryptedAttackerWins = ebool(0); // Resetting ebools might require specific FHE library methods or be omitted
        // encryptedDefenderWins = ebool(0);
        // encryptedIsDraw = ebool(0);
    }

    /**
     * @dev Returns the last publicly revealed combat outcome.
     */
    function getCombatResult() public view returns (CombatOutcome) {
        return lastCombatOutcome;
    }

    /**
     * @dev Allows the caller to retrieve their own encrypted unit stats.
     * The client-side `fhevmjs` library will handle re-encryption and decryption.
     * @return encryptedAttack The caller's encrypted attack value.
     * @return encryptedDefense The caller's encrypted defense value.
     */
    function getMyEncryptedUnitStats() public view onlyGamePlayers returns (euint8 encryptedAttack, euint8 encryptedDefense) {
        require(playersWarriors[msg.sender].deployed, "You have no unit deployed to reveal stats for.");

        // Return the raw encrypted values; re-encryption happens client-side
        return (
            playersWarriors[msg.sender].encryptedAttack,
            playersWarriors[msg.sender].encryptedDefense
        );
    }

    /**
     * @dev Allows the contract owner to retrieve the encrypted combat results.
     * The client-side `fhevmjs` library will handle re-encryption and decryption.
     * @return attackerWins The encrypted attacker wins result.
     * @return defenderWins The encrypted defender wins result.
     * @return isDraw The encrypted draw result.
     */
    function getEncryptedCombatResults() public view onlyOwner returns (ebool attackerWins, ebool defenderWins, ebool isDraw) {
        // Return the raw encrypted values; re-encryption happens client-side
        return (
            encryptedAttackerWins,
            encryptedDefenderWins,
            encryptedIsDraw
        );
    }
}