// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title KYC_SBT
 * @dev 賃貸借契約用のSoulbound Token（譲渡不可能なNFT）
 */
contract KYC_SBT is ERC721, Ownable {
    
    // SBTのメタデータ構造
    struct SBTData {
        string userId;           // 一意のユーザーID
        uint256 issuedDate;      // 発行日（Unixタイムスタンプ）
        uint256 expiryDate;      // 有効期限
        bytes32 propertyHash;    // 物件情報のハッシュ
        uint8 kycLevel;          // KYCレベル（1: 基本, 2: 拡張）
        bool isValid;            // 有効フラグ
    }
    
    // トークンIDごとのSBTデータ
    mapping(uint256 => SBTData) public sbtData;
    
    // アドレスごとのトークンID（1人1トークンのみ）
    mapping(address => uint256) public addressToTokenId;
    
    // トークンカウンター
    uint256 private _tokenIdCounter;
    
    // イベント
    event SBTMinted(address indexed to, uint256 indexed tokenId, string userId);
    event SBTRevoked(uint256 indexed tokenId);
    event SBTExtended(uint256 indexed tokenId, uint256 newExpiryDate);
    
    constructor() ERC721("Rental KYC SBT", "RKYC") Ownable(msg.sender) {
        _tokenIdCounter = 1;
    }
    
    /**
     * @dev SBTを発行する（管理者のみ）
     */
    function mintSBT(
        address to,
        string memory userId,
        uint256 validityPeriod,  // 有効期間（秒）
        bytes32 propertyHash,
        uint8 kycLevel
    ) public onlyOwner returns (uint256) {
        require(addressToTokenId[to] == 0, "Address already has an SBT");
        require(kycLevel >= 1 && kycLevel <= 2, "Invalid KYC level");
        
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        
        _safeMint(to, tokenId);
        
        sbtData[tokenId] = SBTData({
            userId: userId,
            issuedDate: block.timestamp,
            expiryDate: block.timestamp + validityPeriod,
            propertyHash: propertyHash,
            kycLevel: kycLevel,
            isValid: true
        });
        
        addressToTokenId[to] = tokenId;
        
        emit SBTMinted(to, tokenId, userId);
        
        return tokenId;
    }
    
    /**
     * @dev SBTを無効化する（管理者のみ）
     */
    function revokeSBT(uint256 tokenId) public onlyOwner {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        sbtData[tokenId].isValid = false;
        emit SBTRevoked(tokenId);
    }
    
    /**
     * @dev SBTの有効期限を延長する（管理者のみ）
     */
    function extendSBT(uint256 tokenId, uint256 additionalTime) public onlyOwner {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        sbtData[tokenId].expiryDate += additionalTime;
        emit SBTExtended(tokenId, sbtData[tokenId].expiryDate);
    }
    
    /**
     * @dev SBTが有効かチェック
     */
    function isValidSBT(uint256 tokenId) public view returns (bool) {
        if (_ownerOf(tokenId) == address(0)) return false;
        SBTData memory data = sbtData[tokenId];
        return data.isValid && block.timestamp <= data.expiryDate;
    }
    
    /**
     * @dev アドレスが有効なSBTを持っているかチェック
     */
    function hasValidSBT(address account) public view returns (bool) {
        uint256 tokenId = addressToTokenId[account];
        if (tokenId == 0) return false;
        return isValidSBT(tokenId);
    }
    
    /**
     * @dev SBTのメタデータを取得
     */
    function getSBTData(uint256 tokenId) public view returns (SBTData memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        return sbtData[tokenId];
    }
    
    /**
     * @dev 譲渡を無効化（Soulbound Token）
     */
    function _update(address to, uint256 tokenId, address auth) 
        internal 
        override 
        returns (address) 
    {
        address from = _ownerOf(tokenId);
        
        // Mintingの場合のみ許可（from == address(0)）
        if (from != address(0)) {
            revert("SBT: This token is Soulbound and cannot be transferred");
        }
        
        return super._update(to, tokenId, auth);
    }
    
    /**
     * @dev トークンURIを返す（オフチェーンメタデータ用）
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        
        // 実際の運用ではIPFSやサーバーのURLを返す
        return string(abi.encodePacked(
            "https://api.rental-kyc.example.com/metadata/",
            Strings.toString(tokenId)
        ));
    }
}
