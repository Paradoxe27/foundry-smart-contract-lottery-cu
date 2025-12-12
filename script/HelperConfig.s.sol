//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol"; 
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants {

    /* VRF Mock Values*/
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9; // 0.000000001 LINK per gas
    int256 public constant MOCK_WEI_PERUINT_LINK = 4e16; // 0.0005 ETH per LINK

    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;   
    uint256 public constant LOCAL_CHAIN_ID = 31337;     
}

contract HelperConfig is CodeConstants, Script{


    /*Custom error* */
    error HelperConfig__InvalidChainId();


    // Configuration logic will go here
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        uint256 subscriptionId;
        address link;
        address account;
        
    }


    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor () {
        networkConfigs[SEPOLIA_CHAIN_ID] = getSepoliaCOnfig();
    }

    function getSepoliaCOnfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000,
            subscriptionId: 98927884179761824483301169993737059049455335891020886792192066062302014675253,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account:0x7876Cf372A403d5a9736dB5AB93b2f29f63a05E5
        });
    }

    function getCOnfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {

        if (networkConfigs[chainId].vrfCoordinator != address(0)) {

            return networkConfigs[chainId];
        
        } else if (chainId == LOCAL_CHAIN_ID) {

            return getOrCreateAnvilEthConfig();
        
        
        } else {
            revert HelperConfig__InvalidChainId();
        }

    }

    function getConfig() public returns (NetworkConfig memory) {
        return getCOnfigByChainId(block.chainid);
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // check to see if we have an actual network config
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorVock = 
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PERUINT_LINK);

        LinkToken linkToken = new LinkToken();

        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: address(vrfCoordinatorVock),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000,
            subscriptionId: 0,
            link: address(linkToken),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });

        return localNetworkConfig;
        
    }
}