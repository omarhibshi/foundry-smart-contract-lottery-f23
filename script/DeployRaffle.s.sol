// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        (
            uint256 entranceFee,
            uint256 interval,
            bytes32 gasLaneHash,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        (
            address vrfCoordinator,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            address link
        ) = helperConfig.activechainLinkConfig();

        // Create subscription if it does not exist
        if (subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(
                vrfCoordinator,
                deployerKey
            );
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                vrfCoordinator,
                subscriptionId,
                link,
                deployerKey
            );
        }
        // Deploy Raffle
        vm.startBroadcast();
        Raffle raffle = new Raffle(
            entranceFee,
            interval,
            vrfCoordinator,
            gasLaneHash,
            subscriptionId,
            callbackGasLimit
        );
        vm.stopBroadcast();
        // Add Raffle as a consumer (using the VRFCoordinator contracts which have the addConsumer function  )
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffle),
            vrfCoordinator,
            subscriptionId,
            deployerKey
        );
        return (raffle, helperConfig);
    }
}
