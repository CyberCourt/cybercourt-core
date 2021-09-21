
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
    let tokenFaucet = await TokenFaucet.deployed();
    let testToken = await TestToken.deployed();
    
    let entrance = await deployer.deploy(Entrance,reserveContract.address,governorAlphaProxyFactory.address,
      judgerOrgProxyFactory.address,maincontractProxyFactory.address,timelockProxyFactory.address,controlledTokenProxyFactory.address);
    let createKindleStatus = await entrance.createKindle();
    console.log(createKindleStatus.logs);

    // let setTokenFacuet = await entrance.setTokenFaucet(testToken.address,tokenFaucet.address);
    // console.log(setTokenFacuet);

    let judgerOrgAddress = createKindleStatus.logs[0].args["judgerOrgAddr"];
    console.log(judgerOrgAddress);
    let judgerOrg = await JudgerOrg.at(judgerOrgAddress);
    // let mintStatus = await judgerOrg.setWhiteJudger(accounts[0],1);
    // console.log(mintStatus);
    let setIdleStatus = await judgerOrg.setIdleStatus(true);
    console.log(setIdleStatus);
    // let erc20  = await ERC20.at();
    // let approveStatus = await testToken.approve(entrance.address,10000000);
    // let createMainContractStatus = await entrance.createMainContract([accounts[0]],judgerOrgAddress,"60000000000000000",10000,testToken.address);
    // console.log("createMainContractStatus");
    // console.log(createMainContractStatus);
    // let applyJudgeStatus = await entrance.applyJudge(judgerOrgAddress,0);
    // console.log("applyJudgeStatus");
    // console.log(applyJudgeStatus);
    // let launchJudgerStatus = await entrance.launchJudgerProposal(judgerOrgAddress,0,[accounts[0]],[9800]);
    // console.log(launchJudger);
  })
};
