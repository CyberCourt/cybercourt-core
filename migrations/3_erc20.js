
const CC = artifacts.require("CC");
const TestToken = artifacts.require("TestToken");

const TokenFaucet = artifacts.require("TokenFaucet");


module.exports = function (deployer) {
  deployer.then(async () => {
    
    let accounts = await web3.eth.getAccounts();
    
    let cc = await deployer.deploy(CC);
    let testToken = await deployer.deploy(TestToken);
    let ccStatus = await cc.initialize(accounts[0], accounts[0],"10000000000000000000000000");
    let testTokenStatus = await testToken.initialize(accounts[0], accounts[0],"10000000000000000000000000");
    
    let tokenFaucet = await deployer.deploy(TokenFaucet);
    
    // tokenFaucet.initialize(
    //   cc.address, testToken.address, "1000000000000000000"
    // );
    
    let approveStatus = cc.approve(tokenFaucet.address,"100000000000000000000000");
  })
};
