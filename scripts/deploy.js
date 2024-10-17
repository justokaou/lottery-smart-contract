// We require the Hardhat Runtime Environment (HRE) explicitly here. This is optional
// but useful when running the script in a standalone fashion through `node <script>`.
// Importing Hardhat's 'ethers' object.
const hre = require("hardhat");

async function main() {
    // Get the signer (deployer) from Hardhat's ethers object.
    // The signer represents the account that will deploy the contract.
    const [deployer] = await hre.ethers.getSigners();

    // Log the address of the account deploying the contract.
    console.log("Deploying contracts with the account:", deployer.address);

    // Get the ContractFactory for the "lottery" contract.
    // A ContractFactory is an abstraction used to deploy new smart contracts.
    const Lottery = await hre.ethers.getContractFactory("lottery");

    // Deploy the contract instance to the blockchain.
    // The `deploy()` function sends the deployment transaction.
    const deployLottery = await Lottery.deploy();

    // Wait until the contract is deployed (i.e., the transaction is mined).
    await deployLottery.deployed();

    // Log the address of the deployed contract. `deployLottery.address` gives the contract address.
    console.log("Lottery address:", deployLottery.address);
}

// The pattern below ensures that any errors in the main function are caught and handled.
// If an error occurs, it logs the error and sets the process exit code to 1 to indicate failure.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1; // Set exit code to 1 to signal that an error occurred.
});