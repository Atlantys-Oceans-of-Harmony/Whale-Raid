const hre = require("hardhat");

async function main() {

    const Whale = await hre.ethers.getContractFactory("testWhale");
    const whale = await Whale.deploy();
    await whale.deployed();

    console.log("Whale deployed to:", whale.address);

    const Arb = await hre.ethers.getContractFactory("testAqua");
    const arb = await Arb.deploy();
    await arb.deployed();

    console.log("Arb deployed to:", arb.address);

    const Land = await hre.ethers.getContractFactory("testLand");
    const land = await Land.deploy();
    await land.deployed();

    console.log("Land deployed to:", land.address);

    const Artifacts = await hre.ethers.getContractFactory("Artifacts");
    const artifacts = await Artifacts.deploy();
    await artifacts.deployed();

    console.log("artifacts deployed to:", artifacts.address);

    const WhaleRaid = await hre.ethers.getContractFactory("WhaleRaid");
    const raids = await WhaleRaid.deploy(whale.address, arb.address, land.address, artifacts.address);
    await raids.deployed();

    console.log("Whale Raid deployed to:", raids.address);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
