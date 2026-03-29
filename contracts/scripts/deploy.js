const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);
  console.log("Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH");

  const DynamicWorldNFT = await ethers.getContractFactory("DynamicWorldNFT");
  const nft = await DynamicWorldNFT.deploy();
  await nft.waitForDeployment();

  const address = await nft.getAddress();
  console.log("✅ DynamicWorldNFT deployed to:", address);
  console.log("Network:", hre.network.name);
  console.log("\nVerify with:");
  console.log(`npx hardhat verify --network ${hre.network.name} ${address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
