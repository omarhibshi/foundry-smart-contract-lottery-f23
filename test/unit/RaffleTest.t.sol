// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "../../forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "../../forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    /* Events */
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    Raffle raffle;
    HelperConfig helperConfig;
    //
    uint256 entranceFee;
    uint256 interval;
    bytes32 gasLaneHash;
    uint256 deployerKey;
    //
    address vrfCoordinator;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    //
    address public PLAYER = makeAddr("player");
    uint256 constant STARTIG_USER_BALANCE = 10 ether;
    //
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1
    }

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        //
        (entranceFee, interval, gasLaneHash, deployerKey) = helperConfig
            .activeNetworkConfig();
        //
        (vrfCoordinator, subscriptionId, callbackGasLimit, link) = helperConfig
            .activechainLinkConfig();

        vm.deal(PLAYER, STARTIG_USER_BALANCE);
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testRaffleInitialzesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    //////////////////////////
    // enterRaffle tests    //
    ///////////////////////////
    function testRaffleRevertsWhenYouDontPayEnopughEth() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee + 1}();
        assert(raffle.getPlayer(0) == PLAYER);
    }

    function testEmitEventOnEntrance() public {
        vm.prank(PLAYER);
        /**
         * @dev function expectEmit(
         *          bool checkTopic1,
         *          bool checkTopic2,
         *          bool checkTopic3,
         *          bool checkData
         *      ) external;
         *
         * @notice depending on your emitted event, you enable any of the 4 booleans (3 indexed topic and 1 data)
         * @notice the data is normaly the address of the emitter which the contract being tested
         */
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER); // we need to emit this event in the test to compare it to the event emitted by the contract
        raffle.enterRaffle{value: entranceFee + 1}();
    }

    function testCantEnterWhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee + 1}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        //
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee + 1}();
    }

    //////////////////////////
    // checkUpkeep tests    //
    ///////////////////////////

    function testCheckUpkeepReturnsFalseIfIthasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Arrange
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testChackUpkeepReturnsFalseIfRaffleNotOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee + 1}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded == false);
    }

    //////////////////////////
    // performUpkeeep tests  //
    ///////////////////////////

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee + 1}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act  /Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public skipFork {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;

        /**
         * @dev To use expectRevert with a custom error type "with parameters", ABI encode the error type.
         *   vm.expectRevert(
         *      abi.encodeWithSelector(CustomError.selector, 1, 2)  // 1 and 2 are the parameters of the error
         *   );
         */

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee + 1}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnteredAndTimePassed
    {
        // Act /Assert
        /**
         * @dev Tells the VM to start recording all the emitted events. To access them, use getRecordedLogs.
         *      function recordLogs() external;
         * @notice Use this when a function emits more than one event and you want to access them all.
         */
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requesId
        Vm.Log[] memory entries = vm.getRecordedLogs(); // saves the recorded logs of emitted events in the entries array

        /**
         * @dev entries => [0] -> event RandomWordsRequested(list of paramateres ...)
         *                 [1] -> event EnteredRaffle(address indexed player)
         *      entries => [1].topics[0] -> bytes32 is still the event name itself "EnteredRaffle(address indexed player)"
         *                 [1].topics[1] -> bytes32 indexed requestId
         */
        bytes32 requesteId = entries[1].topics[1];

        Raffle.RaffleState rState = raffle.getRaffleState();

        assert(uint256(requesteId) > 0);
        assert(rState == Raffle.RaffleState.CALCULATING);
    }

    function testFullfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEnteredAndTimePassed skipFork {
        vm.expectRevert("nonexistent request");
        // The localhost doesn't have a Chainlink node (or no chainlink node is listening to it), ), so we can't use the Chainlink VRF Coordinator.
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFullfillRandomWordsPicksAWinnerResetAndSendsMoney()
        public
        raffleEnteredAndTimePassed
        skipFork
    {
        // Arrange

        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARTIG_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee + 1}();
        }

        uint256 prize = entranceFee * (additionalEntrants + 1);

        vm.recordLogs();
        raffle.performUpkeep(""); // emits requesId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requesteId = entries[1].topics[1];
        uint256 previouseTimeStamp = raffle.getLastTimeStamp();

        // pretend to be chainlink vrf to get raandom number & pick winner
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requesteId),
            address(raffle)
        );

        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getLengthOfPlayers() == 0);
        assert(previouseTimeStamp < raffle.getLastTimeStamp());
        assert(
            raffle.getRecentWinner().balance >=
                STARTIG_USER_BALANCE + prize - entranceFee
        );
    }
}
