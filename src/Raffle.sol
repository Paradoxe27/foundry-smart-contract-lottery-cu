
//  Pragma Statements
//  Import statements
//  Interfaces
//  Libraries
//  Contracts
 
// Each Contract, Library, Interface follows this order:
// versions
// imports
// errors
// interfaces, libraries, contracts
// type declaration (structs, enums, etc.)
// State variables
// Events
// Modifiers
// Functions

// Order of functions:
// contructor()
// receive() function (if exist)
// fallback() function (if exist)
// external functions
// public functions
// internal functions
// private functions

//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample Raffle contract
 * @author Paradoxe27
 * @notice This contrct is for creating a sample raffle
 * @dev This contract implements the Chainlink VRFv2.5 logic
 */

contract Raffle is VRFConsumerBaseV2Plus {

    /**Custom Errors */
    error Raffle__sendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);

    /**Types Declarations */

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /**State Variables */
    uint256 private immutable i_entranceFee;
    //@Dev the duration of the lottery in seconds
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;


    address payable [] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;
    
    

    /**Events */
    event requestedRaffleWinner(uint256 indexed requestId);
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator,bytes32 gasLane, uint256 subscriptionId, 
                uint32 callbackGasLimit) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {

        if (msg.value < i_entranceFee) {
            revert Raffle__sendMoreToEnterRaffle();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);

    }

    function performUpkeep(bytes calldata /*performData*/) external {

        (bool upkeepNeeded, ) = checkUpkeep("");

        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;

        //  Will revert if subscription is not set and funded.
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({ 
                keyHash: i_keyHash, 
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });
        

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

        emit requestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(uint256 /*requestId*/, uint256[] calldata randomWords) internal virtual override {
        // Implement your logic to handle the random words here
        //we will be using the modulo operation, to divide the random number obtained trough VRF by the number of players
        

        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        
        if (!success) {
            revert Raffle__TransferFailed();
        }

        emit WinnerPicked(s_recentWinner);

        s_players = new address payable [](0);//resetting the players array by making him a "new" 
                                              //address payable array of size 0                                            

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;

    } 

    /**
     * @dev This is the function that the Chainlink Keeper nodes will call
     * to see if the lottery is ready to have a winner picked.
     * And the following should be true in order for upkeep to be true:
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is in an "open" state.
     * 3. The contract has ETH. (meaning people has entered the lottery (so they paid their fees in ETH to enter))
     * 4. implicitly, your subscription is funded with LINK.
     * @param - ignored 
     * @return upkeedNeeded - true if it's time to restart the lottery
     * @return - ignored
     */


    function checkUpkeep(bytes memory /*checkData*/) 
        public 
        view 
        returns (bool upkeedNeeded, bytes memory /*performData*/ )
    {
        bool timeHasPassed = block.timestamp - s_lastTimeStamp >= i_interval; 
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;

        upkeedNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);

        return (upkeedNeeded, "");

        
    }



    

    /**Getters FUnctions */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumberOfPlayers() external view returns (uint256) {
        return s_players.length;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {

        return s_players[indexOfPlayer];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

      
}