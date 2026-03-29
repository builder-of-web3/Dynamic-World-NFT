const hre = require("hardhat");

async function main() {
  const { ethers, network } = hre;
  const [owner] = await ethers.getSigners();

  const contractAddress = process.env.CONTRACT_ADDRESS;
  const mintPriceEth = process.env.MINT_PRICE_ETH;

  if (!contractAddress) {
    throw new Error("Missing CONTRACT_ADDRESS env var");
  }

  if (!mintPriceEth) {
    throw new Error("Missing MINT_PRICE_ETH env var");
  }

  const contract = await ethers.getContractAt("DynamicWorldNFT", contractAddress);
  const mintPriceWei = ethers.parseEther(mintPriceEth);

  console.log("Network:", network.name);
  console.log("Owner:", owner.address);
  console.log("Contract:", contractAddress);
  console.log("New mint price:", mintPriceEth, "ETH");

  const tx = await contract.setMintPrice(mintPriceWei);
  console.log("Submitted tx:", tx.hash);

  const receipt = await tx.wait();
  console.log("Confirmed in block:", receipt.blockNumber);

  const updatedMintPrice = await contract.mintPrice();
  console.log("Updated on-chain mint price:", ethers.formatEther(updatedMintPrice), "ETH");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
