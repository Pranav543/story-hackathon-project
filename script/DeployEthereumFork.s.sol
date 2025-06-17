// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {CrossChainLender} from "../src/CrossChainLender.sol";
import {CustomMockERC20} from "../src/mocks/CustomMockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployEthereumFork is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address storyLendingContract = vm.envAddress("STORY_LENDING_CONTRACT");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Fund the deployer account with ETH for gas
        vm.deal(deployer, 1000 ether);
        console.log("=== DEPLOYING TO ETHEREUM MAINNET FORK ===");
        console.log("Deployer:", deployer);
        console.log("Story Contract:", storyLendingContract);
        console.log("Deployer balance:", deployer.balance / 1e18, "ETH");
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy cross-chain lender with REAL deBridge addresses
        CrossChainLender lender = new CrossChainLender(storyLendingContract);
        console.log(" CrossChainLender deployed at:", address(lender));
        
        // For testing, deploy mock USDC (easier than dealing with real USDC whale)
        CustomMockERC20 mockUSDC = new CustomMockERC20("Test USDC", "TUSDC", 6);
        console.log(" Mock USDC deployed at:", address(mockUSDC));
        
        // Setup liquidity
        mockUSDC.mint(address(lender), 10000000e6); // 10M USDC
        mockUSDC.mint(deployer, 1000000e6); // 1M USDC to deployer
        lender.setSupportedToken(address(mockUSDC), true);
        console.log(" Added 10M TUSDC liquidity to lender");
        console.log(" Minted 1M TUSDC to deployer");

        // Verify setup
        uint256 lenderBalance = mockUSDC.balanceOf(address(lender));
        uint256 deployerBalance = mockUSDC.balanceOf(deployer);
        
        console.log("Final balances:");
        console.log("- Lender contract:", lenderBalance / 1e6, "TUSDC");
        console.log("- Deployer:", deployerBalance / 1e6, "TUSDC");

        console.log("\n=== ETHEREUM DEPLOYMENT SUMMARY ===");
        console.log("CrossChainLender:", address(lender));
        console.log("Mock USDC:", address(mockUSDC));
        console.log("DLN Source (Real):", 0xeF4fB24aD0916217251F553c0596F8Edc630EB66);
        console.log("DLN Destination (Real):", 0xE7351Fd770A37282b91D153Ee690B63579D6dd7f);
        console.log("Story Contract:", storyLendingContract);

        vm.stopBroadcast();
        
        // Save addresses for test script
        _saveDeploymentAddresses(address(lender), address(mockUSDC));
    }
    
    function _saveDeploymentAddresses(address lender, address usdc) internal {
        string memory addresses = string.concat(
            "ETHEREUM_LENDER_CONTRACT=", vm.toString(lender), "\n",
            "ETHEREUM_USDC_CONTRACT=", vm.toString(usdc), "\n"
        );
        vm.writeFile("./deployed-addresses-ethereum.env", addresses);
        console.log(" Deployment addresses saved to deployed-addresses-ethereum.env");
    }
}
