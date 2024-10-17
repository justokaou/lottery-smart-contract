# Lottery Smart Contract

This project contains a Solidity smart contract that allows users to participate in a lottery system using Ether. The lottery winner is selected randomly via Chainlink's Verifiable Random Function (VRF). The contract includes mechanisms for pausing participation, preventing reentrancy attacks, and ensuring secure random number generation.

<div align="center">

[![](https://img.shields.io/badge/Solidity-red)]()
[![](https://img.shields.io/badge/Chainlink-blue)]()
[![](https://img.shields.io/badge/Node.js-green)]()

</div>

## Features

- **Lottery Participation**: Users can join the lottery by sending 0.1 ETH.
- **Random Winner Selection**: The winner is selected using Chainlink's VRF for secure randomness.
- **Admin Controls**: The contract owner can pause/unpause the contract and withdraw funds.
- **Fair Reward Distribution**: The winner receives 95% of the total pool, and the owner gets a 5% fee.

## Environment Variables

To run this project, you will need to add the following environment variables to your `.env` file:

```bash
PRIVATE_KEY="YOUR_PRIVATE_KEY"
RPC_URL="YOUR_RPC_URL"
ETHERSCAN_API_KEY="YOUR_ETHERSCAN_API_KEY"
```

## Installation

Clone the repository and install the necessary dependencies:

```bash
git clone https://github.com/your-username/lottery-contract.git
cd lottery-contract
npm install
```
## Deployment

Before deploying, make sure you update the `hardhat.config.js` file with the network.

### Compile the contract:

```bash
npx hardhat compile
```
### Deploy the lottery contract:

```bash
npx hardhat run scripts/deploy-lottery.js --network <YOUR_NETWORK>
```
Replace <YOUR_NETWORK> with the network you're deploying to (e.g., rinkeby, mumbai, etc.).

## Contract Verification

If you'd like to verify the contract on a block explorer (like Etherscan), run the following command:

```bash
npx hardhat verify --network <YOUR_NETWORK> <DEPLOYED_CONTRACT_ADDRESS> <LINK_TOKEN_ADDRESS> <VRF_WRAPPER_ADDRESS>
```
For example:
npx hardhat verify --network rinkeby 0xYourLotteryAddress "0xLINK_TOKEN_ADDR" "0xVRF_WRAPPER_ADDR"

## Usage

After deploying the contract, users can interact with it by sending 0.1 ETH to participate in the lottery. The owner can call the `selectWinner()` function to initiate the Chainlink VRF process, which will randomly select a winner.

### Example Commands

- **Participate in the lottery**: Users can participate by interacting with the `participate()` function and sending 0.1 ETH.

- **Select a winner (Owner only)**: The contract owner can call the `selectWinner()` function to randomly choose a winner based on Chainlink's VRF.

- **Pause/Unpause the lottery**: The contract owner can pause or unpause the lottery using `pause()` and `unpause()` respectively.

## Authors

- [@dyfault-eth](https://www.github.com/dyfault-eth)






