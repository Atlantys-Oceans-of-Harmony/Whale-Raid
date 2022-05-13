//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LandSigner.sol";

contract Raid is Ownable,PlotSigner{

    IERC721 Whale;
    IERC721 Land;
    IERC721 Artifacts;
    IERC20 AQUA;

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
    uint public artifactOdds = 20;


    mapping(uint=>stakeWhales) public whaleInfo;
    mapping(address=>uint[]) public userStaked;
    mapping(uint=>uint[3]) public landStats; //Resource,Attack,Defense
    mapping(uint=>bool) public landInitialized;

    address designatedSigner;

    event ArtifactReceived(address indexed user,uint indexed tokenId);

    constructor(address _whale,address _arb,address _land,address _artifacts){
        Whale = IERC721(_whale);
        AQUA = IERC20(_arb);
        Land = IERC721(_land);
        Artifacts = IERC721(_artifacts);
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
        require(msg.sender == tx.origin,"contract can't call function");
        require(Whale.ownerOf(tokenId)==msg.sender,"Not whale owner");
        AQUA.transferFrom(msg.sender,address(this),entryFees);
        Whale.transferFrom(msg.sender,address(this),tokenId);
        if(land !=0){
            require(landInitialized[tokenId],"Land not initialized");
            require(Land.ownerOf(land)==msg.sender,"Not land owner");
            Land.transferFrom(msg.sender,address(this),land);
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
            uint[3] memory userLand = landStats[land];
            uint[3] memory opponentLand = landStats[whaleInfo[opponent].land];
            uint odds;
            
            if (opponentLand[2] >= userLand[1]){ //Defense > Attack
                odds = 50 + 25*(opponentLand[2] - userLand[1])/100;
            }
            else{
                odds = 50 - 25*(userLand[1]-opponentLand[2])/100;
            }
            if(random%100 < odds){
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
        require(tokenId.length < 60,"Can't return more than 60 raids");
        uint amount = 0;
        uint random = uint(vrf());
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
            uint bonus = landStats[whaleInfo[tokenId[i]].land][0]/10;
            delete whaleInfo[tokenId[i]];
            if(random%100 < artifactOdds+bonus){
                emit ArtifactReceived(msg.sender, tokenId[i]);
            }
            random /= 10;
        }
        AQUA.transfer(msg.sender,amount);
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

    function withdrawAqua() external onlyOwner{
        AQUA.transfer(msg.sender,AQUA.balanceOf(address(this)));
    }

    function setArtifact(address _artifact) external onlyOwner{
        Artifacts = IERC721(_artifact);
    }

    function setPlot(address _plot) external onlyOwner{
        Land = IERC721(_plot);
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

    function setAqua(address _arb) external onlyOwner{
        AQUA = IERC20(_arb);
    }

}