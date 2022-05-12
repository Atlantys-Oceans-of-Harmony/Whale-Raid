//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LandSigner.sol";

contract Raid is Ownable,PlotSigner{

    IERC721 Whale;
    IERC721 Land;
    IERC20 ARB;

    struct stakeWhales{
        address owner;
        uint land;
        uint timeStaked;
        uint prizeMultiplier;
        uint position;
        uint userPosition;
    }

    uint[] public stakedWhales;
    uint[] public deadWhales;

    uint public basePrize = 25 ether;
    uint public entryFees = 25 ether;
    uint public lockPeriod = 24 hours;

    mapping(uint=>stakeWhales) public whaleInfo;
    mapping(address=>uint[]) public userStaked;
    mapping(uint=>uint[3]) public landStats; //Resource,Attack,Defense
    mapping(uint=>bool) public landInitialized;

    address designatedSigner;

    constructor(address _whale,address _arb,address _land){
        Whale = IERC721(_whale);
        ARB = IERC20(_arb);
        Land = IERC721(_land);
    }

    function initializeLand(uint[] memory tokenId,uint[][3] memory stats,bytes[] memory sigantures) external {
        for(uint i=0;i<tokenId.length;i++){
            require(getSigner(PlotInfo(tokenId[i],stats[i][0],stats[i][1],stats[i][2],sigantures[i]))==designatedSigner,"Invalid signer");
            for(uint j=0;j<3;j++){
                landStats[tokenId[i]][j] = stats[i][j];
                landInitialized[tokenId[i]] = true;
            }
        }
    }

    function sendRaid(uint tokenId,uint land) external {
        require(Whale.ownerOf(tokenId)==msg.sender,"Not owner");
        require(msg.sender == tx.origin,"contract can't call function");
        ARB.transferFrom(msg.sender,address(this),entryFees);
        Whale.transferFrom(msg.sender,address(this),tokenId);
        if(land !=0){
            Land.transferFrom(msg.sender,address(this),land);
            require(landInitialized[tokenId],"Land not initialized");
        }
        uint random = uint(vrf());
        if(stakedWhales.length == 0){
            //Auto win if no opponents exist
            whaleInfo[tokenId] = stakeWhales(msg.sender,land,block.timestamp,1,stakedWhales.length,userStaked[msg.sender].length);
            stakedWhales.push(tokenId);
            userStaked[msg.sender].push(tokenId);
        }
        else{
            uint opponent = stakedWhales[random % stakedWhales.length];
            random = random/10000;
            if(random%100 < 50){
                //opponent wins
                whaleInfo[opponent].prizeMultiplier += 1;
                whaleInfo[tokenId] = stakeWhales(msg.sender,land,block.timestamp,0,deadWhales.length,userStaked[msg.sender].length);
                deadWhales.push(tokenId);
                userStaked[msg.sender].push(tokenId);
            }
            else{
                //user wins
                if(whaleInfo[opponent].prizeMultiplier - 1 == 0){
                    popToken(opponent);
                    deadWhales.push(opponent);
                    whaleInfo[opponent].position = deadWhales.length - 1;
                }
                whaleInfo[opponent].prizeMultiplier -= 1;
                whaleInfo[tokenId] = stakeWhales(msg.sender,land,block.timestamp,2,stakedWhales.length,userStaked[msg.sender].length);
                stakedWhales.push(tokenId);
                userStaked[msg.sender].push(tokenId);
            }
        }
    }

    function returnRaid(uint[] memory tokenId) external {
        uint amount = 0;
        for(uint i=0;i<tokenId.length;i++){
            stakeWhales storage currWhale = whaleInfo[tokenId[i]];
            require(currWhale.owner == msg.sender,"Not owner");
            require(block.timestamp - currWhale.timeStaked > lockPeriod,"Not unstaked yet");
            amount += basePrize*currWhale.prizeMultiplier;
            popToken(tokenId[i]);
            Whale.transferFrom(address(this),msg.sender,tokenId[i]);
            if(currWhale.land != 0){
                Land.transferFrom(address(this),msg.sender,currWhale.land);
            }
            popUser(tokenId[i]);
            delete whaleInfo[tokenId[i]];
        }
        ARB.transfer(msg.sender,amount);
    }

    function popToken(uint tokenId) private {
        uint currPosition = whaleInfo[tokenId].position;
        if(whaleInfo[tokenId].prizeMultiplier != 0){
            uint lastToken = stakedWhales[stakedWhales.length - 1];
            whaleInfo[lastToken].position = currPosition;
            stakedWhales[currPosition] = lastToken;
            stakedWhales.pop();
        }else{
            uint lastToken = deadWhales[deadWhales.length - 1];
            whaleInfo[lastToken].position = currPosition;
            deadWhales[currPosition] = lastToken;
            deadWhales.pop();
        }
    }

    function popUser(uint tokenId) private {
        uint currPosition = whaleInfo[tokenId].userPosition;
        uint lastToken = userStaked[msg.sender][userStaked[msg.sender].length-1];
        userStaked[msg.sender][currPosition] = userStaked[msg.sender][userStaked[msg.sender].length-1];
        whaleInfo[lastToken].userPosition = currPosition;
    }

    function getUserStaked(address _user) external view returns(uint[] memory){
        return userStaked[_user];
    }

    function vrf() private view returns (bytes32 result) {
        uint256[1] memory bn;
        bn[0] = block.number;
        assembly {
            let memPtr := mload(0x40)
            if iszero(staticcall(not(0), 0xff, bn, 0x20, memPtr, 0x20)) {
                invalid()
            }
            result := mload(memPtr)
        }
        return result;
    }

    function withdrawARB() external onlyOwner{
        ARB.transfer(msg.sender,ARB.balanceOf(address(this)));
    }

    function setPrice(uint _price) external onlyOwner{
        entryFees = _price;
    }

    function setPrize(uint _prize) external onlyOwner{
        basePrize = _prize;
    }

    function setLockPeriod(uint _period) external onlyOwner{
        lockPeriod = _period;
    }

    function setWhale(address _whale) external onlyOwner{
        Whale = IERC721(_whale);
    }

    function setArb(address _arb) external onlyOwner{
        ARB = IERC20(_arb);
    }

}