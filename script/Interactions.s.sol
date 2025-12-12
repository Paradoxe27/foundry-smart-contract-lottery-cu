//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script,console} from "forge-std/Script.sol";
import {HelperConfig,CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script  {

    function createSubscriptionUsingConfig() public returns (uint256, address) {

        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;

       (uint256 subId,) = createSubscription(vrfCoordinator,account);

       return (subId, vrfCoordinator);


    }

    function createSubscription (address vrfCoordinator, address account) public returns (uint256, address){

        console.log("Creating subscription on chainId:", block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Your Subscription Id is:", subId);
        console.log("Please update the subscriptionId in the HelperConfig.s.sol file");

        return (subId, vrfCoordinator);



    }

    function run() public {

        createSubscriptionUsingConfig();
        
    }

    

}

contract FundSubscription is Script, CodeConstants {

    uint256 constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {

        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;
        fundSubscription(vrfCoordinator, subscriptionId, linkToken, account);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken, address account) public {

        console.log("FUnding Subscription,",subscriptionId);
        console.log("Using VRFCoordinator:", vrfCoordinator);
        console.log("On ChainId:", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID){
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT*10);
            vm.stopBroadcast();
        } else 
        {
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
        }

    }

    function run() public {}
        
}

contract AddConsumer is Script {

    function addConsumerUsingConfig(address mostRecentDeployed) public {

        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        addConsumer(mostRecentDeployed, vrfCoordinator, subId, account);


    }
    
    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subId, address account) public {

        console.log("Adding a Consumer contract:",subId);
        console.log("Using VRFCoordinator:", vrfCoordinator);
        console.log("On ChainId:", block.chainid);

        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddToVrf);
        vm.stopBroadcast();


    }

    function run() public {
        address mostRecentDeployed = DevOpsTools.get_most_recent_deployment("Raffle",block.chainid);
        addConsumerUsingConfig(mostRecentDeployed);
    }
}