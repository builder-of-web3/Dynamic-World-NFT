// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title DynamicWorldNFT
 * @notice Dynamic NFTs that visually evolve based on real-world data scenarios.
 *         Each NFT has a "World State" that can be updated by the oracle/owner
 *         to reflect real-world events: climate, markets, geopolitics, space, health.
 * @dev Deployed on Optimism. Metadata is fully on-chain & dynamically generated SVG.
 */
contract DynamicWorldNFT is ERC721, ERC721URIStorage, Ownable {
    using Strings for uint256;

    uint256 private _nextTokenId;

    // ─── World State Categories ───────────────────────────────────────────────
    enum WorldCategory {
        CLIMATE,      // Climate & weather extremes
        MARKET,       // Global financial markets
        GEOPOLITICAL, // Conflict, peace, diplomacy
        SPACE,        // Space exploration & astronomy
        HEALTH,       // Pandemics, health crises
        TECHNOLOGY    // Breakthrough tech events
    }

    // ─── NFT State ─────────────────────────────────────────────────────────────
    struct WorldState {
        WorldCategory category;
        uint8 intensity;         // 0–100 (affects visual)
        uint8 sentimentScore;    // 0–100: 0=critical/dark, 100=positive/bright
        string eventTag;         // Short label e.g. "Solar Storm", "Bull Run"
        string dataPoint;        // Human-readable value e.g. "CO2: 425ppm"
        uint256 lastUpdated;     // Block timestamp of last oracle update
        uint256 updateCount;     // How many times this NFT has evolved
    }

    // ─── Storage ───────────────────────────────────────────────────────────────
    mapping(uint256 => WorldState) public worldStates;
    mapping(address => bool) public authorizedOracles;

    // ─── Mint Config ───────────────────────────────────────────────────────────
    uint256 public mintPrice = 0.001 ether;   // ~cheap on Optimism
    uint256 public maxSupply = 10000;
    bool public mintingOpen = true;

    // ─── Events ────────────────────────────────────────────────────────────────
    event WorldStateUpdated(uint256 indexed tokenId, string eventTag, uint8 intensity, uint8 sentiment);
    event OracleAuthorized(address indexed oracle, bool status);
    event NFTMinted(address indexed to, uint256 indexed tokenId, WorldCategory category);

    // ─── Modifiers ─────────────────────────────────────────────────────────────
    modifier onlyOracle() {
        require(authorizedOracles[msg.sender] || msg.sender == owner(), "Not authorized oracle");
        _;
    }

    constructor() ERC721("Dynamic World NFT", "DWNFT") Ownable(msg.sender) {
        authorizedOracles[msg.sender] = true;
    }

    // ─── Minting ───────────────────────────────────────────────────────────────

    /**
     * @notice Mint a Dynamic World NFT. Category chosen by minter.
     * @param category The world category this NFT tracks
     */
    function mint(WorldCategory category) external payable returns (uint256) {
        require(mintingOpen, "Minting is closed");
        require(msg.value >= mintPrice, "Insufficient ETH");
        require(_nextTokenId < maxSupply, "Max supply reached");

        uint256 tokenId = _nextTokenId;
        _nextTokenId += 1;

        _safeMint(msg.sender, tokenId);

        // Initialize with neutral state
        worldStates[tokenId] = WorldState({
            category: category,
            intensity: 50,
            sentimentScore: 50,
            eventTag: _defaultTag(category),
            dataPoint: "Awaiting live data...",
            lastUpdated: block.timestamp,
            updateCount: 0
        });

        emit NFTMinted(msg.sender, tokenId, category);
        return tokenId;
    }

    /**
     * @notice Batch mint multiple NFTs
     */
    function batchMint(WorldCategory[] calldata categories) external payable {
        require(categories.length > 0 && categories.length <= 10, "1-10 at a time");
        require(msg.value >= mintPrice * categories.length, "Insufficient ETH");
        require(_nextTokenId + categories.length <= maxSupply, "Exceeds max supply");

        for (uint256 i = 0; i < categories.length; i++) {
            uint256 tokenId = _nextTokenId;
            _nextTokenId += 1;
            _safeMint(msg.sender, tokenId);
            worldStates[tokenId] = WorldState({
                category: categories[i],
                intensity: 50,
                sentimentScore: 50,
                eventTag: _defaultTag(categories[i]),
                dataPoint: "Awaiting live data...",
                lastUpdated: block.timestamp,
                updateCount: 0
            });
            emit NFTMinted(msg.sender, tokenId, categories[i]);
        }
    }

    // ─── Oracle Updates ────────────────────────────────────────────────────────

    /**
     * @notice Update a token's world state. Called by authorized oracle.
     * @param tokenId     Token to update
     * @param intensity   New intensity 0-100
     * @param sentiment   New sentiment 0-100
     * @param eventTag    Short event label
     * @param dataPoint   Human-readable data string
     */
    function updateWorldState(
        uint256 tokenId,
        uint8 intensity,
        uint8 sentiment,
        string calldata eventTag,
        string calldata dataPoint
    ) external onlyOracle {
        require(_exists(tokenId), "Token does not exist");
        require(intensity <= 100 && sentiment <= 100, "Values must be 0-100");

        WorldState storage state = worldStates[tokenId];
        state.intensity = intensity;
        state.sentimentScore = sentiment;
        state.eventTag = eventTag;
        state.dataPoint = dataPoint;
        state.lastUpdated = block.timestamp;
        state.updateCount += 1;

        emit WorldStateUpdated(tokenId, eventTag, intensity, sentiment);
    }

    /**
     * @notice Batch update multiple tokens at once (gas efficient)
     */
    function batchUpdateWorldState(
        uint256[] calldata tokenIds,
        uint8[] calldata intensities,
        uint8[] calldata sentiments,
        string[] calldata eventTags,
        string[] calldata dataPoints
    ) external onlyOracle {
        require(
            tokenIds.length == intensities.length &&
            tokenIds.length == sentiments.length &&
            tokenIds.length == eventTags.length &&
            tokenIds.length == dataPoints.length,
            "Array length mismatch"
        );

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (!_exists(tokenIds[i])) continue;
            WorldState storage state = worldStates[tokenIds[i]];
            state.intensity = intensities[i];
            state.sentimentScore = sentiments[i];
            state.eventTag = eventTags[i];
            state.dataPoint = dataPoints[i];
            state.lastUpdated = block.timestamp;
            state.updateCount += 1;
            emit WorldStateUpdated(tokenIds[i], eventTags[i], intensities[i], sentiments[i]);
        }
    }

    // ─── On-Chain SVG Metadata ─────────────────────────────────────────────────

    /**
     * @notice Returns fully on-chain dynamic SVG metadata
     */
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        WorldState memory state = worldStates[tokenId];

        string memory svg = _generateSVG(tokenId, state);
        string memory json = Base64.encode(bytes(string(abi.encodePacked(
            '{"name":"Dynamic World #', tokenId.toString(), '",',
            '"description":"A living NFT that evolves with real-world data. Category: ', _categoryName(state.category), '.",',
            '"image":"data:image/svg+xml;base64,', Base64.encode(bytes(svg)), '",',
            '"attributes":[',
                '{"trait_type":"Category","value":"', _categoryName(state.category), '"},',
                '{"trait_type":"Event","value":"', state.eventTag, '"},',
                '{"trait_type":"Intensity","value":', uint256(state.intensity).toString(), '},',
                '{"trait_type":"Sentiment","value":', uint256(state.sentimentScore).toString(), '},',
                '{"trait_type":"Data Point","value":"', state.dataPoint, '"},',
                '{"trait_type":"Update Count","value":', state.updateCount.toString(), '},',
                '{"trait_type":"Last Updated","value":', state.lastUpdated.toString(), '}',
            ']}'
        ))));

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    /**
     * @dev Generate dynamic SVG based on world state
     */
    function _generateSVG(uint256 tokenId, WorldState memory state) internal pure returns (string memory) {
        string memory bgColor1 = _getBgColor1(state);
        string memory bgColor2 = _getBgColor2(state);
        string memory accentColor = _getAccentColor(state);
        string memory emoji = _getCategoryEmoji(state.category);
        string memory intensityBar = _getIntensityBar(state.intensity);
        string memory sentimentGlow = state.sentimentScore > 66 ? "0 0 30px #00ff88" :
                                      state.sentimentScore > 33 ? "0 0 30px #ffaa00" : "0 0 30px #ff4444";

        return string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" width="400" height="400">',
            '<defs>',
            '<linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">',
            '<stop offset="0%" style="stop-color:', bgColor1, ';stop-opacity:1" />',
            '<stop offset="100%" style="stop-color:', bgColor2, ';stop-opacity:1" />',
            '</linearGradient>',
            '<filter id="glow"><feGaussianBlur stdDeviation="3" result="blur"/>',
            '<feComposite in="SourceGraphic" in2="blur" operator="over"/></filter>',
            '</defs>',
            '<rect width="400" height="400" fill="url(#bg)" rx="20"/>',
            '<rect x="10" y="10" width="380" height="380" fill="none" stroke="', accentColor, '" stroke-width="2" rx="16" opacity="0.6"/>',
            // Title
            '<text x="200" y="55" font-family="monospace" font-size="13" fill="', accentColor, '" text-anchor="middle" opacity="0.8">DYNAMIC WORLD NFT</text>',
            // Token ID
            '<text x="200" y="80" font-family="monospace" font-size="20" fill="white" text-anchor="middle" font-weight="bold">#', tokenId.toString(), '</text>',
            // Big emoji/icon
            '<text x="200" y="175" font-size="80" text-anchor="middle">', emoji, '</text>',
            // Event tag
            '<rect x="60" y="200" width="280" height="36" rx="8" fill="', accentColor, '" opacity="0.2"/>',
            '<text x="200" y="223" font-family="monospace" font-size="14" fill="', accentColor, '" text-anchor="middle" font-weight="bold">', state.eventTag, '</text>',
            // Data point
            '<text x="200" y="265" font-family="monospace" font-size="11" fill="white" text-anchor="middle" opacity="0.9">', state.dataPoint, '</text>',
            // Intensity bar
            intensityBar,
            // Category badge
            '<rect x="140" y="340" width="120" height="24" rx="12" fill="', accentColor, '" opacity="0.3"/>',
            '<text x="200" y="357" font-family="monospace" font-size="11" fill="white" text-anchor="middle">', _categoryName(state.category), '</text>',
            // Update count
            '<text x="200" y="390" font-family="monospace" font-size="9" fill="white" text-anchor="middle" opacity="0.5">EVOLVED ', state.updateCount.toString(), ' TIMES</text>',
            '</svg>'
        ));
    }

    function _getIntensityBar(uint8 intensity) internal pure returns (string memory) {
        uint256 filled = (uint256(intensity) * 260) / 100;
        string memory color = intensity > 66 ? "#ff4444" : intensity > 33 ? "#ffaa00" : "#44ff88";
        return string(abi.encodePacked(
            '<rect x="70" y="292" width="260" height="8" rx="4" fill="rgba(255,255,255,0.1)"/>',
            '<rect x="70" y="292" width="', filled.toString(), '" height="8" rx="4" fill="', color, '"/>',
            '<text x="70" y="316" font-family="monospace" font-size="9" fill="white" opacity="0.5">INTENSITY</text>',
            '<text x="330" y="316" font-family="monospace" font-size="9" fill="', color, '" text-anchor="end">', uint256(intensity).toString(), '/100</text>'
        ));
    }

    function _getBgColor1(WorldState memory state) internal pure returns (string memory) {
        if (state.category == WorldCategory.CLIMATE)      return state.sentimentScore > 50 ? "#0a2a1a" : "#2a0a0a";
        if (state.category == WorldCategory.MARKET)       return state.sentimentScore > 50 ? "#0a1a2a" : "#1a0a2a";
        if (state.category == WorldCategory.GEOPOLITICAL) return "#1a0a0a";
        if (state.category == WorldCategory.SPACE)        return "#050510";
        if (state.category == WorldCategory.HEALTH)       return "#0a1a0a";
        return "#0a0a1a"; // TECHNOLOGY
    }

    function _getBgColor2(WorldState memory state) internal pure returns (string memory) {
        if (state.category == WorldCategory.CLIMATE)      return state.sentimentScore > 50 ? "#0a3a2a" : "#3a1a0a";
        if (state.category == WorldCategory.MARKET)       return state.sentimentScore > 50 ? "#0a2a3a" : "#2a0a3a";
        if (state.category == WorldCategory.GEOPOLITICAL) return "#2a0a1a";
        if (state.category == WorldCategory.SPACE)        return "#0a0520";
        if (state.category == WorldCategory.HEALTH)       return "#0a2a1a";
        return "#0a0a2a";
    }

    function _getAccentColor(WorldState memory state) internal pure returns (string memory) {
        if (state.category == WorldCategory.CLIMATE)      return state.sentimentScore > 50 ? "#00ff88" : "#ff6600";
        if (state.category == WorldCategory.MARKET)       return state.sentimentScore > 50 ? "#00aaff" : "#ff00aa";
        if (state.category == WorldCategory.GEOPOLITICAL) return "#ff4444";
        if (state.category == WorldCategory.SPACE)        return "#aa88ff";
        if (state.category == WorldCategory.HEALTH)       return "#00ff44";
        return "#00ffff"; // TECHNOLOGY
    }

    function _getCategoryEmoji(WorldCategory cat) internal pure returns (string memory) {
        if (cat == WorldCategory.CLIMATE)      return unicode"🌍";
        if (cat == WorldCategory.MARKET)       return unicode"📈";
        if (cat == WorldCategory.GEOPOLITICAL) return unicode"🌐";
        if (cat == WorldCategory.SPACE)        return unicode"🚀";
        if (cat == WorldCategory.HEALTH)       return unicode"🧬";
        return unicode"⚡"; // TECHNOLOGY
    }

    function _categoryName(WorldCategory cat) internal pure returns (string memory) {
        if (cat == WorldCategory.CLIMATE)      return "CLIMATE";
        if (cat == WorldCategory.MARKET)       return "MARKET";
        if (cat == WorldCategory.GEOPOLITICAL) return "GEOPOLITICAL";
        if (cat == WorldCategory.SPACE)        return "SPACE";
        if (cat == WorldCategory.HEALTH)       return "HEALTH";
        return "TECHNOLOGY";
    }

    function _defaultTag(WorldCategory cat) internal pure returns (string memory) {
        if (cat == WorldCategory.CLIMATE)      return "Global Climate Watch";
        if (cat == WorldCategory.MARKET)       return "Market Observer";
        if (cat == WorldCategory.GEOPOLITICAL) return "World Affairs";
        if (cat == WorldCategory.SPACE)        return "Space Explorer";
        if (cat == WorldCategory.HEALTH)       return "Health Sentinel";
        return "Tech Frontier";
    }

    // ─── Admin ─────────────────────────────────────────────────────────────────

    function setMintPrice(uint256 _price) external onlyOwner {
        mintPrice = _price;
    }

    function setMintingOpen(bool _open) external onlyOwner {
        mintingOpen = _open;
    }

    function setOracle(address oracle, bool status) external onlyOwner {
        authorizedOracles[oracle] = status;
        emit OracleAuthorized(oracle, status);
    }

    function withdraw() external onlyOwner {
        (bool success, ) = owner().call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }

    function totalSupply() external view returns (uint256) {
        return _nextTokenId;
    }

    // ─── Required Overrides ────────────────────────────────────────────────────

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
