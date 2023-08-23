// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

//The purpose of this contract:
// 1. Deploy mocks when we are on a local anvil chain.
// 2. Keep track of contract address across different chains.
//    - Sepolia ETH/USD
//    - Mainnet ETH/USD}
import {VRFCoordinatorV2Mock} from "chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {Script} from "forge-std/Script.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;
    chainLinkConfig public activechainLinkConfig;
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        bytes32 gasLaneHash;
        uint256 deployerKey;
    }
    struct chainLinkConfig {
        address vrfCoordinator;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address link;
    }
    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    event HelperConfig__CreatedMockVRFCoordinator(address vrfCoordinator);

    constructor() {
        if (block.chainid == 11155111) {
            (
                activeNetworkConfig,
                activechainLinkConfig
            ) = getSepoliaEthConfig();
        } else {
            (
                activeNetworkConfig,
                activechainLinkConfig
            ) = getorCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig()
        public
        view
        returns (NetworkConfig memory, chainLinkConfig memory)
    {
        // Network configurations examples:
        // - Price feed address on Sepolia
        // - vrf coordinator address on Sepolia
        // - gas price oracle address on Sepolia

        NetworkConfig memory SepoliaNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 1 minutes,
            gasLaneHash: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            deployerKey: vm.envUint("SANAA_PRIVATE_KEY")
        });

        chainLinkConfig memory SepoliaChainConfig = chainLinkConfig({
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            subscriptionId: 0,
            callbackGasLimit: 500000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
        });
        return (SepoliaNetworkConfig, SepoliaChainConfig);
    }

    function getorCreateAnvilEthConfig()
        public
        returns (NetworkConfig memory, chainLinkConfig memory)
    {
        // first check if a mock is already deployed, in this case priceFeed will be set to anything other than 0x0 (address(0)
        if (activechainLinkConfig.vrfCoordinator != address(0)) {
            return (activeNetworkConfig, activechainLinkConfig);
        }
        //

        uint96 baseFee = 0.25 ether;
        uint96 gasPriceLink = 1e9;

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(
            baseFee,
            gasPriceLink
        );

        LinkToken link = new LinkToken();
        //address mockAddress = address(mock);

        vm.stopBroadcast();
        emit HelperConfig__CreatedMockVRFCoordinator(
            address(vrfCoordinatorV2Mock)
        );

        NetworkConfig memory anvilNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            gasLaneHash: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
        //
        chainLinkConfig memory anvilChainConfig = chainLinkConfig({
            vrfCoordinator: address(vrfCoordinatorV2Mock),
            subscriptionId: 0,
            callbackGasLimit: 500000,
            link: address(link)
        });
        return (anvilNetworkConfig, anvilChainConfig);
    }
}
