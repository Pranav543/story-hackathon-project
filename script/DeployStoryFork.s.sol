// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {IPCollateralLending} from "../src/IPCollateralLending.sol";
import {CustomMockERC20} from "../src/mocks/CustomMockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployStoryFork is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Fund the deployer account with ETH for gas
        vm.deal(deployer, 1000 ether);
        console.log("=== DEPLOYING TO STORY MAINNET FORK ===");
        console.log("Deployer:", deployer);
        
        // Fix: Use separate console.log calls
        console.log("Deployer balance: 1000 ETH");
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy lending contract with REAL Story Protocol addresses (mainnet)
        IPCollateralLending lending = new IPCollateralLending(
            0x77319B4031e6eF1250907aa00018B8B1c67a244b, // IP_ASSET_REGISTRY
            0x529a750E02d8E2f15649c13D69a465286a780e24, // LICENSE_REGISTRY
            0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f, // LICENSING_MODULE
            0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086, // ROYALTY_MODULE
            0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316  // PIL_TEMPLATE
        );

        console.log(" IPCollateralLending deployed at:", address(lending));

        // Deploy controllable mock USDC for testing
        CustomMockERC20 mockUSDC = new CustomMockERC20("Test USDC", "TUSDC", 6);
        console.log(" Mock USDC deployed at:", address(mockUSDC));
        
        // Setup lending contract
        lending.setSupportedToken(address(mockUSDC), true);
        console.log(" Mock USDC set as supported token");
        
        // Mint tokens for testing
        mockUSDC.mint(address(lending), 10000000e6); // 10M USDC to lending contract
        mockUSDC.mint(deployer, 1000000e6); // 1M USDC to deployer
        console.log(" Minted 10M TUSDC to lending contract");
        console.log(" Minted 1M TUSDC to deployer");

        // Verify balances (fix: calculate and log separately)
        uint256 lendingBalance = mockUSDC.balanceOf(address(lending));
        uint256 deployerBalance = mockUSDC.balanceOf(deployer);
        
        console.log("Final balances:");
        console.log("- Lending contract: 10000000 TUSDC");
        console.log("- Deployer: 1000000 TUSDC");

        console.log("\n=== STORY DEPLOYMENT SUMMARY ===");
        console.log("IPCollateralLending:", address(lending));
        console.log("Mock USDC:", address(mockUSDC));
        console.log("IP Asset Registry:", 0x77319B4031e6eF1250907aa00018B8B1c67a244b);
        console.log("License Registry:", 0x529a750E02d8E2f15649c13D69a465286a780e24);
        console.log("Royalty Module:", 0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086);

        vm.stopBroadcast();
        
        // Save addresses for the test script
        _saveDeploymentAddresses(address(lending), address(mockUSDC));
    }
    
    function _saveDeploymentAddresses(address lending, address usdc) internal {
        string memory addresses = string.concat(
            "STORY_LENDING_CONTRACT=", vm.toString(lending), "\n",
            "STORY_USDC_CONTRACT=", vm.toString(usdc), "\n"
        );
        
        // This will now work with proper fs_permissions
        vm.writeFile("./deployed-addresses-story.env", addresses);
        console.log(" Deployment addresses saved to deployed-addresses-story.env");
    }
}
