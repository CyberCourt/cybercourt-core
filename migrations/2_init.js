
const Reserve = artifacts.require("Reserve");
const GovernorAlphaProxyFactory = artifacts.require("GovernorAlphaProxyFactory");
const JudgerOrgProxyFactory = artifacts.require("JudgerOrgProxyFactory");
const MainContractProxyFactory = artifacts.require("MainContractProxyFactory");
const TimelockProxyFactory = artifacts.require("TimelockProxyFactory");
const ControlledTokenProxyFactory = artifacts.require("ControlledTokenProxyFactory");


module.exports = function (deployer) {
  deployer.then(async () => {
    
    let reserveContract = await deployer.deploy(Reserve);
    let governorAlphaProxyFactory = await deployer.deploy(GovernorAlphaProxyFactory);
    let judgerOrgProxyFactory = await deployer.deploy(JudgerOrgProxyFactory);
    let maincontractProxyFactory = await deployer.deploy(MainContractProxyFactory);
    let timelockProxyFactory = await deployer.deploy(TimelockProxyFactory);
    let controlledTokenProxyFactory = await deployer.deploy(ControlledTokenProxyFactory);
  })
};
