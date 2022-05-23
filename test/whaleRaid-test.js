const { expect } = require("chai");
const { ethers } = require("hardhat");
const Web3 = require("web3");
const { fromWei } = Web3.utils;

describe("☠ Whale Raid Test Suite", async () =>{
    let owner, alice, bob, whale, land, artifacts, aqua, raid;
    before(async ()=> {
        [owner, alice, bob] = await ethers.getSigners();
        const nft1 = await ethers.getContractFactory('testWhale');
        whale = await nft1.deploy();
        const nft2 = await ethers.getContractFactory('testLand');
        land = await nft2.deploy();
        const art = await ethers.getContractFactory('Artifacts');
        artifacts = await art.deploy();
        const rewardToken = await ethers.getContractFactory('testAqua');
        aqua = await rewardToken.deploy();
        const race = await ethers.getContractFactory('testRaid');
        raid = await race.deploy(whale.address, aqua.address, land.address, artifacts.address);

        await whale.connect(alice).mint(3);
        await whale.connect(bob).mint(3);

        await land.connect(alice).mint(2);
        await land.connect(bob).mint(2);

        await aqua.connect(alice).mint(1000);
        await aqua.connect(bob).mint(1000);
        await aqua.mint(1000);
        await aqua.transfer(raid.address, ethers.utils.parseEther('1000'));

        await aqua.connect(bob).approve(raid.address, ethers.utils.parseEther('100000'));
        await aqua.connect(alice).approve(raid.address, ethers.utils.parseEther('100000'));

        await whale.connect(alice).setApprovalForAll(raid.address, true);
        await whale.connect(bob).setApprovalForAll(raid.address, true);
        await land.connect(alice).setApprovalForAll(raid.address, true);
        await land.connect(bob).setApprovalForAll(raid.address, true);

        await artifacts.approveAddress(raid.address, true);
    });

    describe('Raid Contract deployed ▸', async () =>{
        it('Deployer should be owner', async () =>{
            it("Should set the owner", async() => {
                expect(await raid.owner()).to.equal(owner.address);
            });
        });
    });

    describe('Initialize Land ▸', async () =>{
        it('Should update the Land Stats', async () =>{
            await raid.connect(alice).initializeLand([1, 2], [[70, 85, 45], [75, 60, 87]]);
            await raid.connect(bob).initializeLand([3, 4], [[80, 40, 45], [75, 57, 90]]);
            expect(await raid.landStats(1, 0)).to.eq('70');
        });
    });

    describe('Alice starts Raiding without Land ▸', async () =>{
        it('Ownership of Whale transferred', async () =>{
            await raid.connect(alice).sendRaid(1, 0);
            expect(await whale.ownerOf(1)).to.eq(raid.address);
        });

        it("Entry Fees deducted", async () =>{
            expect(await aqua.balanceOf(alice.address)).to.eq(ethers.utils.parseEther('975'));
        });
    });

    describe("Bob Raids ▸", async () =>{
        it('Bob plays a Land Booster', async () =>{
            await raid.connect(bob).sendRaid(4, 3);
        });

        it('Should increase Prize Multiplier', async () =>{
            const structVar = await raid.whaleInfo(4);
            expect(structVar[3]).to.eq('2');
        });

        it('Losing Opponent must be in deadWhales and multiplier be 0', async () =>{
            expect(await raid.deadWhales([0])).to.eq(1);
            const structVar = await raid.whaleInfo(1);
            expect(structVar[3]).to.eq('0');
        });

        it('Alice raids with a new Whale with Land Booster', async () =>{
            await raid.connect(alice).sendRaid(2, 2);
            const structVar = await raid.whaleInfo(2);
            expect(structVar[3]).to.eq('2');
        });

        it('Bobs Whale loses so prize multiplier decreases', async () =>{
            const structVar = await raid.whaleInfo(4);
            expect(structVar[3]).to.eq('1');
        });

        it('Returning Token 4 from raid but not before unlocking Period', async () =>{
            await expect(raid.connect(bob).returnRaid([4])).to.be.revertedWith('Not unstaked yet');
            await network.provider.send("evm_increaseTime", [24 * 3600]);
            await raid.connect(bob).returnRaid([4]);
        });

        it("Bob raids with another Whale Land included but incurs loss and Token 2 get multiplier 3", async () =>{
            await raid.connect(bob).sendRaid(5, 4);
            expect(await raid.deadWhales([1])).to.eq(5);
            const structVar = await raid.whaleInfo(2);
            expect(structVar[3]).to.eq('3');
        });

    });

    describe("Returning from Raid ▸", async () =>{
        it("Unstaking from dead Whales doesn't yield Aqua", async () =>{
            await network.provider.send("evm_increaseTime", [30 * 3600]);
            await raid.connect(bob).returnRaid([5]);
            expect(await aqua.balanceOf(bob.address)).to.eq(ethers.utils.parseEther('975'));
        });

        it('Unstaking Staked Whales gives multiplied Aqua and Artifact gained that generates a event', async () =>{
            await expect(raid.connect(alice).returnRaid([2]))
                .to.emit(raid, 'ArtifactReceived').withArgs(alice.address, 2);
            expect(await aqua.balanceOf(alice.address)).to.eq(ethers.utils.parseEther('1025'));
        });

    });

    describe("Withdraw Aqua from contract ▸", async () =>{
        await raid.withdrawAqua();
        expect(await aqua.balanceOf(owner.address)).to.eq(ethers.utils.parseEther('1000'));
    })
});