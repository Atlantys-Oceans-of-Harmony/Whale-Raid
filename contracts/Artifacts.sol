//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Artifacts is ERC721Enumerable,Ownable{

    mapping(address=>bool) allowedAddress;

    uint tokenId;
    string baseUri;
    string commonURI;

    constructor() ERC721("Ocean Artifact","ART"){
    }

    modifier onlyAllowed{
        require(allowedAddress[msg.sender],"Address not approved");
        _;
    }

    function mintArtifact(address _to,uint _amount) external onlyAllowed{
        for(uint i=0;i<_amount;i++){
            tokenId++;
            _mint(_to,tokenId);
        }
    }

    function approveAddress(address _toApprove,bool _isApproved) external onlyOwner{
        allowedAddress[_toApprove] = _isApproved;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseUri;
    }

    function setBaseURI(string memory _uri) external onlyOwner{
        baseUri = _uri;
    }

    function setCommonURI(string memory _uri) external onlyOwner{
        commonURI = _uri;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, Strings.toString(tokenId))) : commonURI;
    }

}