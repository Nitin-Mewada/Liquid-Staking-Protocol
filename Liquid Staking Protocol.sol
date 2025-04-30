// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title LiquidStaking
 * @dev A simplified liquid staking protocol that allows users to stake ETH and receive stETH tokens
 * which represent their staked ETH plus accumulated rewards.
 */
contract LiquidStaking is ERC20, Ownable, ReentrancyGuard {
    // Events
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsDistributed(uint256 amount);

    // Total amount of ETH staked in the contract
    uint256 public totalStakedETH;
    
    // Tracks the exchange rate between stETH and ETH (starts at 1:1)
    // Represented as a fixed-point number with 18 decimals
    uint256 public exchangeRate = 1 ether;
    
    // Constructor
    constructor() ERC20("Staked ETH", "stETH") Ownable(msg.sender) {}
    
    /**
     * @dev Allows users to stake ETH and receive stETH tokens
     * The amount of stETH tokens received depends on the current exchange rate
     */
    function stake() external payable nonReentrant {
        require(msg.value > 0, "Cannot stake 0 ETH");
        
        // Calculate stETH amount based on current exchange rate
        uint256 stETHAmount = (msg.value * 1 ether) / exchangeRate;
        
        // Update total staked ETH
        totalStakedETH += msg.value;
        
        // Mint stETH tokens for the user
        _mint(msg.sender, stETHAmount);
        
        emit Staked(msg.sender, msg.value);
    }
    
    /**
     * @dev Allows users to unstake ETH by burning their stETH tokens
     * @param stETHAmount Amount of stETH tokens to burn
     */
    function unstake(uint256 stETHAmount) external nonReentrant {
        require(stETHAmount > 0, "Cannot unstake 0 stETH");
        require(balanceOf(msg.sender) >= stETHAmount, "Insufficient stETH balance");
        
        // Calculate ETH amount based on current exchange rate
        uint256 ethAmount = (stETHAmount * exchangeRate) / 1 ether;
        
        require(address(this).balance >= ethAmount, "Insufficient ETH in contract");
        
        // Burn stETH tokens
        _burn(msg.sender, stETHAmount);
        
        // Update total staked ETH
        totalStakedETH -= ethAmount;
        
        // Transfer ETH to the user
        (bool success, ) = payable(msg.sender).call{value: ethAmount}("");
        require(success, "ETH transfer failed");
        
        emit Unstaked(msg.sender, ethAmount);
    }
    
    /**
     * @dev Allows the owner to distribute rewards, updating the exchange rate
     * In a real implementation, this would be triggered by external staking rewards
     */
    function distributeRewards() external payable onlyOwner {
        require(msg.value > 0, "No rewards to distribute");
        require(totalStakedETH > 0, "No ETH staked");
        
        // Update exchange rate based on new rewards
        // New exchange rate = (total ETH + rewards) / total stETH supply
        exchangeRate = ((totalStakedETH + msg.value) * 1 ether) / totalSupply();
        
        // Update total staked ETH
        totalStakedETH += msg.value;
        
        emit RewardsDistributed(msg.value);
    }
    
    // Fallback and receive functions to accept ETH transfers
    receive() external payable {}
    fallback() external payable {}
}
