🌍 Dynamic World NFT
> NFTs that breathe with the world — fully on-chain dynamic SVGs on Optimism that evolve based on real-world data.
---
Overview
Dynamic World NFT is a fully on-chain ERC-721 collection on Optimism where each NFT's visual appearance and metadata update automatically based on real-world data: climate readings, financial markets, geopolitical events, space exploration, health alerts, and technology breakthroughs.
No IPFS — all SVG metadata generated on-chain via `tokenURI()`
Oracle-driven — a Node.js oracle reads live APIs and calls `updateWorldState()` on-chain
6 categories — Climate, Market, Geopolitical, Space, Health, Technology
Cheap on Optimism — oracle updates cost <$0.01 each
---
Project Structure
```
dynamic-nft/
├── contracts/          # Solidity smart contract + Hardhat
│   ├── DynamicWorldNFT.sol
│   ├── hardhat.config.js
│   ├── scripts/deploy.js
│   └── package.json
├── frontend/           # Next.js 14 minting site (deploy to Vercel)
│   ├── src/
│   │   ├── app/        # App router pages
│   │   ├── components/ # UI components
│   │   └── lib/        # Contract ABI, wagmi providers
│   └── vercel.json
└── oracle/             # Node.js oracle service
    ├── oracle.js
    └── package.json
```
---
1. Deploy the Contract
```bash
cd contracts
npm install
cp .env.example .env
# Fill in PRIVATE_KEY and OPTIMISM_ETHERSCAN_API_KEY

# Deploy to Optimism Sepolia (testnet)
npm run deploy:testnet

# Deploy to Optimism Mainnet
npm run deploy:mainnet

# Verify on Etherscan
npx hardhat verify --network optimism-sepolia <CONTRACT_ADDRESS>
```
After deploying, note your contract address.
---
2. Configure & Deploy the Frontend
```bash
cd frontend
npm install
cp .env.example .env.local
```
Edit `.env.local`:
```
NEXT_PUBLIC_CONTRACT_ADDRESS=0xYourDeployedContractAddress
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_wc_project_id   # cloud.walletconnect.com
NEXT_PUBLIC_CHAIN_ID=11155420   # 10 for mainnet
```
Deploy to Vercel:
```bash
npm install -g vercel
vercel --prod
```
Or connect your GitHub repo to Vercel and add env vars in the Vercel dashboard.
---
3. Set Up the Oracle
```bash
cd oracle
npm install
cp .env.example .env
```
Edit `.env`:
```
ORACLE_PRIVATE_KEY=your_oracle_wallet_key
CONTRACT_ADDRESS=0xYourDeployedContractAddress
OPTIMISM_RPC_URL=https://mainnet.optimism.io
NASA_API_KEY=your_nasa_key   # free at api.nasa.gov
```
Authorize the oracle wallet (run once from deployer wallet):
```javascript
// In Hardhat console or a script:
await contract.setOracle("0xYourOracleWalletAddress", true);
```
Run the oracle:
```bash
# One-time run
node oracle.js

# Schedule with cron (every 6 hours)
0 */6 * * * cd /path/to/oracle && node oracle.js >> oracle.log 2>&1
```
---
Contract Interface
Mint
```solidity
function mint(WorldCategory category) external payable returns (uint256 tokenId)
```
Categories: `0=CLIMATE, 1=MARKET, 2=GEOPOLITICAL, 3=SPACE, 4=HEALTH, 5=TECHNOLOGY`
Update (Oracle only)
```solidity
function updateWorldState(
    uint256 tokenId,
    uint8 intensity,    // 0-100
    uint8 sentiment,    // 0-100: 0=critical, 100=positive
    string calldata eventTag,
    string calldata dataPoint
) external
```
Batch Update
```solidity
function batchUpdateWorldState(
    uint256[] calldata tokenIds,
    uint8[] calldata intensities,
    uint8[] calldata sentiments,
    string[] calldata eventTags,
    string[] calldata dataPoints
) external
```
---
How NFTs Evolve
Category	Data Source	Update Frequency
Climate	Open-Meteo, NOAA	Daily
Market	CoinGecko	Every 6 hours
Geopolitical	GDELT Project	Daily
Space	NASA APOD, SpaceX	Event-triggered
Health	WHO Alerts	Event-triggered
Technology	HackerNews, ArXiv	Every 6 hours
---
Tech Stack
Layer	Tech
Smart Contract	Solidity 0.8.20, OpenZeppelin 5
Network	Optimism (L2)
Development	Hardhat
Frontend	Next.js 14, TypeScript
Web3	wagmi v2, viem, RainbowKit
Styling	Tailwind CSS
Deployment	Vercel
Oracle	Node.js, ethers.js v6
---
Security Notes
Oracle private key must be kept secret and separate from the deployer key
Contract owner can revoke oracle authorization at any time via `setOracle(addr, false)`
All on-chain updates are immutably logged and auditable
Consider a multisig for the contract owner role in production
---
License
MIT
