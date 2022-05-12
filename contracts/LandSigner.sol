//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "./EIP712.sol";

contract PlotSigner is EIP712{

    string private constant SIGNING_DOMAIN = "Whale-Plots";
    string private constant SIGNATURE_VERSION = "1";

    //TODO: Add time check
    struct PlotInfo{
        uint tokenId;
        uint attack;
        uint defense; 
        uint resource;
        bytes signature;
    }

    constructor() EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION){
        
    }

    function getSigner(PlotInfo memory result) public view returns(address){
        return _verify(result);
    }
  
    function _hash(PlotInfo memory result) internal view returns (bytes32) {
    return _hashTypedDataV4(keccak256(abi.encode(
      keccak256("PlotInfo(uint256 tokenId,uint256 attack,uint256 defense,uint256 resource)"),
      result.tokenId,
      result.attack,
      result.defense,
      result.resource
    )));
    }

    function _verify(PlotInfo memory result) internal view returns (address) {
        bytes32 digest = _hash(result);
        return ECDSA.recover(digest, result.signature);
    }

}