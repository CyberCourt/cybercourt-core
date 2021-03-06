
const Entrance = artifacts.require("Entrance");
const JudgerOrg = artifacts.require("JudgerOrg");
const CC = artifacts.require("CC");
const TestToken = artifacts.require("TestToken");
const Reserve = artifacts.require("Reserve");
const GovernorAlphaProxyFactory = artifacts.require("GovernorAlphaProxyFactory");
const JudgerOrgProxyFactory = artifacts.require("JudgerOrgProxyFactory");
const MainContractProxyFactory = artifacts.require("MainContractProxyFactory");
const TimelockProxyFactory = artifacts.require("TimelockProxyFactory");
const TokenFaucet = artifacts.require("TokenFaucet");
const ControlledTokenProxyFactory = artifacts.require("ControlledTokenProxyFactory");



module.exports = function (deployer) {
  deployer.then(async () => {
    
    let accounts = await web3.eth.getAccounts();
    
    let reserveContract = await Reserve.deployed();
    let governorAlphaProxyFactory = await GovernorAlphaProxyFactory.deployed();
    let judgerOrgProxyFactory = await JudgerOrgProxyFactory.deployed();
    let maincontractProxyFactory = await MainContractProxyFactory.deployed();
    let timelockProxyFactory = await TimelockProxyFactory.deployed();
    let controlledTokenProxyFactory = await ControlledTokenProxyFactory.deployed();
    
    let entrance = await deployer.deploy(Entrance,reserveContract.address,governorAlphaProxyFactory.address,
      judgerOrgProxyFactory.address,maincontractProxyFactory.address,timelockProxyFactory.address,controlledTokenProxyFactory.address);
    
  })
};
