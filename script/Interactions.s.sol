// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Raffle} from "../src/Raffle.sol";

/**
 * @title CreateSubscription
 * @notice the functions run() and createSubscriptionUsingConfig() are only used for runing the script on the command line
 * @dev This contratc creates a subscription on the VRF Coordinator. It creates a subscription on localhost, testnet and mainnet alike
 */
contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();

        (, , , uint256 deployerKey) = helperConfig.activeNetworkConfig();
        (address vrfCoordinator, , , ) = helperConfig.activechainLinkConfig();

        return createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(
        address vrfCoordinator,
        uint256 deployerKey
    ) public returns (uint64) {
        console.log("Creating subscription on chainid", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Subscription Id is :", subId);
        console.log("Please uddate the subscription id in HelperConfig.s.sol");
        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

/**
 * @title  FundSubscription
 * @notice he functions run() and fundSubscriptionUsingConfig() are only used for runing the script on the command line
 * @dev This contracts fund an existing subscription on the VRF Coordinator. It funds a subscription on localhost, testnet and mainnet alike
 */
contract FundSubscription is Script {
    uint96 private constant FUND_AMAOUNT = 3e18;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();

        (, , , uint256 deployerKey) = helperConfig.activeNetworkConfig();
        (
            address vrfCoordinator,
            uint64 subscriptionId,
            ,
            address linkToken
        ) = helperConfig.activechainLinkConfig();
        fundSubscription(
            vrfCoordinator,
            subscriptionId,
            linkToken,
            deployerKey
        );
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subscriptionId,
        address linkToken,
        uint256 deployerKey
    ) public {
        console.log("Funding subscription on chainid  : ", block.chainid);
        console.log("Using vfrCoordinator : ", vrfCoordinator);
        console.log("Subscription Id is :", subscriptionId);
        console.log("Llink address used : ", linkToken);

        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                FUND_AMAOUNT
            );
            vm.stopBroadcast();
        } else {
            console.log(LinkToken(linkToken).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(linkToken).balanceOf(address(this)));
            console.log(address(this));
            vm.startBroadcast(deployerKey);
            LinkToken(linkToken).transferAndCall(
                vrfCoordinator,
                FUND_AMAOUNT,
                abi.encode(subscriptionId)
            );
            vm.stopBroadcast();
        }

        console.log(
            "Funded subscription Id %S with %s Link(s) :",
            subscriptionId,
            FUND_AMAOUNT
        );
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

/**
 * @title  AddConsumer
 * @notice
 * @dev This contracts adds a consumer to the VRF Coordinator. It adds a consumer on localhost, testnet and mainnet alike
 */
contract AddConsumer is Script {
    function addConsumer(
        address contractToAddToVrf,
        address vrfCoordinator,
        uint64 subId,
        uint256 deployerKey
    ) public {
        console.log("Adding consumer contract: ", contractToAddToVrf);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(
            subId,
            contractToAddToVrf
        );
        vm.stopBroadcast();
        console.log(
            "Added consumer %s to subscription Id %s :",
            contractToAddToVrf,
            subId
        );
    }

    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();

        (, , , uint256 deployerKey) = helperConfig.activeNetworkConfig();
        (address vrfCoordinatorV2, uint64 subId, , ) = helperConfig
            .activechainLinkConfig();

        addConsumer(mostRecentlyDeployed, vrfCoordinatorV2, subId, deployerKey);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        console.log("Raffle address is : ", mostRecentlyDeployed);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}
