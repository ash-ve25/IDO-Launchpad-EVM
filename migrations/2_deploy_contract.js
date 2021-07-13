const STRToken = artifacts.require("STRToken");
const StakingPool = artifacts.require("StakingPool");
const IDOPool = artifacts.require("IDOPool");

module.exports = async function(deployer, network, accounts) {
  await deployer.deploy(STRToken);
  const daiToken = await STRToken.deployed();

  await deployer.deploy(StakingPool, STRToken.address, 200, 150, 100, 50, 25);
  const dappToken = await StakingPool.deployed();  

  // await deployer.deploy(IDOPool, dappToken.address, daiToken.address);
  // const tokenFarm = await TokenFarm.deployed();
};