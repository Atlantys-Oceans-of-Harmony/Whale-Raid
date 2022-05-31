// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const Greeter = await hre.ethers.getContractFactory("WhaleRaid");
  const greeter = await Greeter.deploy("0x8CC9176682521A38A04EAfd124932dE3aB246588","0xbd0c432B5F1d75b7A7BDf88D9F0ba815c64E758B","0x3232599EE4758Ff58C4db70F041A20668391670d","0xBa7cBAB48e8739b5F8377DA9AE264F23055924cD");

  await greeter.deployed();

  console.log("Raid deployed to:", greeter.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
