//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;


import {Test} from "forge-std/Test.sol";
import {Script,console} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";

contract RaffleTest is CodeConstants, Test {


    modifier raffleEntered() {

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp+ interval + 1);
        vm.roll(block.number + 1);

        _;

    }

    Raffle public raffle;
    HelperConfig public helperConfig;
    
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;


        

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_BALANCE = 10 ether;

    /**Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);


    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle,helperConfig) = deployer.deployContract();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;

        vm.deal(PLAYER, STARTING_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {

        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertWhenYouDontPayEnough() public {

        //Arrange
        vm.prank(PLAYER);
        //Act-Assert
        vm.expectRevert(Raffle.Raffle__sendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        //Arrange        
        vm.prank(PLAYER);

        //Act
        raffle.enterRaffle{value: entranceFee}();
        
        //Act-
        assertEq(raffle.getPlayer(0), PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        
        //Arrange
        vm.prank(PLAYER);

        //Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);

        //Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayerToEnterWhileRaffleIsCalculating() public raffleEntered{
        //Arrange
        
        raffle.performUpkeep("");

        //Act-//Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        
    }

    /*///////////////////////////////Check Upkeep//////////////////////////////////*/

    function testcheckUpKeepReturnsFalseIfItHasNoBalance() public {

        //Arrange
        vm.warp(block.timestamp+ interval + 1);
        vm.roll(block.number + 1);

        //Act 
        (bool upkeepNeeded, ) = raffle.checkUpkeep(""); //this will be false because nobody has entered the raffle
                                                        //and so there's no balance in the contract affle


        //assert
        assert(!upkeepNeeded); //we then assert that upkeepNeeded is false by asserting !upkeepNeeded
                                // meaning that its opposit is true. (since "assert" checks for true values)
    }

    function testUpkeepReturnsFalseIfRaffleIsntOpen() public {

        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp+ interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //assert
        assert(!upkeepNeeded);

    }

    /*///////////////////////////////Check PerformUpkeep//////////////////////////////////*/

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {

        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp+ interval + 1);
        vm.roll(block.number + 1);

        //Act-Assert
        raffle.performUpkeep(""); //if checkUpkeep is true, this should not revert

    }

    function testPerformUPkeepRevertIfCheckUpkeepIsFalse() public {
        //Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        //Act-Assert
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, uint256(rState)));
        
        raffle.performUpkeep("");
    }

    function testPerformUpkeeepUpdateRaffleStateAndEmitRequestId () public raffleEntered {

        

        //Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        //bytes32 requestId = bytes32(entries[1].data);
        //console.log("\n\n\n\n\n THE ACTUAL REQUEST ID IS \n\n\n\n",uint256(requestId));

        //Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256 (requestId) > 0);
        assert(uint256(raffleState) == 1);


    }

    modifier skipFork() {

        if (block.chainid != LOCAL_CHAIN_ID) {
            return; //This says, run the current function only when we are on local chain. if we are on 
                    //annother then skip it 
        }

        _;

    }


     /*///////////////////////////////FulfillRandomWords//////////////////////////////////*/

     function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) 
     public 
     raffleEntered 
     skipFork 
     {
        //Arrange/Act/assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));

     }

     /*/////////////////////////////// ONE GIANT FulfillRandomWords TEST//////////////////////////////////*/


    function testrandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEntered skipFork {

        //Arrane
        uint256 additionalEntrance = 3;
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < startingIndex+additionalEntrance;i++) {

            // casting to uint160 is safe because `i` is a small loop counter < type(uint160).max
            // forge-lint: disable-next-line(unsafe-typecast)
            address newPlayer = address(uint160(i));
            hoax(newPlayer,1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;


        //Act 
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        //bytes32 requestId = bytes32(entries[1].data);

        //console.log("\n\n\n\n\n THE ACTUAL REQUEST ID IS \n\n\n\n",uint256(requestId), "\n\n\n And value\n\n",uint256(value));

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));



        //Assert 
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee*(additionalEntrance+1);

        assert(recentWinner == expectedWinner);
        assert(uint56(raffleState) == 0);
        assert (winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);


    }

}