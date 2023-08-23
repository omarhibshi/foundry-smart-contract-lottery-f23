// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

/** Imports */
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title A simple Raffle Contract
 * @author Patrick Collins (O.ALHABSHI)
 * @notice This contract is for creating a sample raffle contract
 * @dev Implements Chainlink VRFv2
 */

/** Interfaces, Libraries, Contracts */

contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
    /** Errors  */
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    /** Type declarations */
    // bool lotteryState = open, closed, calculating
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1
    }

    /** State Variables */
    // Constants variables
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1; // number of random words requested from Chainlink VRF
    // Immutable variables
    uint256 private immutable i_entranceFee; // entrance fee in wei
    uint256 private immutable i_interval; // @dev duration of the raffle in seconds
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator; // @dev Chainlink VRF Coordinator address
    bytes32 private immutable i_gasLaneHash; // @dev Chainlink VRF Gas Lane Hash
    uint64 private immutable i_subscriptionId; // @dev Chainlink VRF Subscription ID
    uint32 private immutable i_callbackGasLimit; // @dev Chainlink VRF Callback Gas Limit
    // Storage variables
    uint256 private s_lastTimeStamp; // @dev last time the raffle was drawn
    address payable[] private s_players; // array of players payable addresses
    address private s_recentWinner; // winner of the raffle
    RaffleState private s_raffleState; // state of the raffle

    /** Events */
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 _entranceFee,
        uint256 _interval,
        address _vrfCoordinator,
        bytes32 _gasLaneHash,
        uint64 _subscriptionId,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        //
        i_entranceFee = _entranceFee;
        i_interval = _interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        i_gasLaneHash = _gasLaneHash;
        i_subscriptionId = _subscriptionId;
        i_callbackGasLimit = _callbackGasLimit;
        //
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
    }

    /** Function to enter the Raffle */
    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    /**
     * @dev This is the function that the Chainlink Keeper nodes call
     * they look for `upkeepNeeded` to return True.
     * the following should be true for this to return true:
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is open.
     * 3. The contract has ETH.
     * 4. Implicity, your subscription is funded with LINK.
     */
    function checkUpkeep(
        // This function is called constently and automatically by the Chainlink Keeper Nodes
        bytes memory /* _checkData*/
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        // ### block.timestamp = 1000, s_lastTimeStamp = 500, i_interval = 1000 => 1000 - 500 > 1000 => false
        // ### block.timestamp = 1600, s_lastTimeStamp = 500, i_interval = 1000 => 1600 - 500 > 1000 => true
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayer = s_players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayer);
        return (upkeepNeeded, "0x0");
    }

    /**
     * @dev This is the function that the Chainlink Keeper nodes call
     * The Fuunction to draw the Raffle winner by following the steps below:
     * 1. Get a Random number from Chainlink VRF
     * 2. Pick a winner using the random number
     */
    function performUpkeep(bytes calldata /* performData */) external override {
        // We don't use the performData in this example. The performData is generated by the Automation Node's call to your checkUpkeep function
        (bool upKeepNeeded, ) = checkUpkeep(""); // checkUpkeep is called by the Chainlink Keeper Nodes
        if (!upKeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        // Set the raffle state to calculating while waiting for Chainlink VRF to return a random number
        s_raffleState = RaffleState.CALCULATING;
        // Will revert if subscription is not set and funded.
        uint256 requestId = i_vrfCoordinator.requestRandomWords( // fulfillRandomWords is called by VRFCoordinator upon receiveing a valid VRF
            i_gasLaneHash,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        ); // 1st evnet emitted is here => RandomWordsRequested
        emit RequestedRaffleWinner(requestId); // 2st evnet emitted is here => RequestedRaffleWinner
    }

    // CEI : Check-Effects-Interactions
    /** Function to receive the random number */
    // 1. Chainlink will call this function to call the random number
    function fulfillRandomWords(
        uint256 /*_requestId*/,
        uint256[] memory _randomWords
    ) internal override {
        // checks
        // Effects
        /**
         * How to pick a random winner using the Modulo operator
         * Example,
         * # s_players's length  = 10 & rng (random number) = 12
         * # 12 % 10 = 2 => s_players[2] is the winner of the raffle
         */
        uint256 indexOfWinner = _randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        /**
         * resets all raffle variables
         * 1. Sets the raffle state back to open
         * 2. Resets the players array
         * 3. Resets the last time stamp
         */
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(winner);
        //
        // Interactions
        // if the transfer fails, it reverts the transaction and all the steps above
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /** Getter Functions */

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getLengthOfPlayers() public view returns (uint256) {
        return s_players.length;
    }
}
