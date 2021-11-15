pragma solidity 0.6.12;
import "./helpers/ERC20.sol";

import "./libraries/Address.sol";

import "./libraries/SafeERC20.sol";

import "./libraries/EnumerableSet.sol";

import "./helpers/Ownable.sol";

import "./helpers/ReentrancyGuard.sol";

import "sortition-sum-tree-factory/contracts/SortitionSumTreeFactory.sol";

import "./MainContractProxyFactory.sol";
import "./JudgerOrgProxyFactory.sol";
import "./GovernorAlphaProxyFactory.sol";
import "./TimelockProxyFactory.sol";
import "./Reserve.sol";
import "@pooltogether/fixed-point/contracts/FixedPoint.sol";
import "./token/ControlledToken.sol";
import "./token/ControlledTokenProxyFactory.sol";
import "./token/TokenControllerInterface.sol";
import "./token/TokenFaucet.sol";
import "./token/TokenFaucetProxyFactory.sol";
contract Entrance is Ownable, ReentrancyGuard,TokenControllerInterface {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;


    mapping(address => MainContract[]) public mainContractMap; 
    mapping(address => bool) public judgerOrgMap; 
    mapping(address => ControlledToken) public controlledTokenMap; 
    mapping(address => TokenFaucet) public tokenFaucetMap; 
    Reserve public reserve; 
    GovernorAlphaProxyFactory public governorAlphaProxyFactory; 
    JudgerOrgProxyFactory public judgerOrgProxyFactory; 
    MainContractProxyFactory public mainContractProxyFactory; 
    TimelockProxyFactory public timelockProxyFactory; 
    ControlledTokenProxyFactory public controlledTokenProxyFactory; 
    event createMainContractEvent(address indexed from,address judgerOrgAddr,address mainContractAddr,uint256 mainContractOrder,string contentOrIpfsHash);
    event addContractEvent(address indexed from,address judgerOrgAddr,uint256 mainContractOrder,uint8 contractOrder,string contentOrIpfsHash);
    event addStakeEvent(address indexed from, address judgerOrgAddr,uint256 mainContractOrder,uint256 stakeBalance);
    event applyExitEvent(address indexed from, address judgerOrgAddr,uint256 mainContractOrder);
    event finishExitEvent(address judgerOrgAddr,uint256 mainContractOrder);

    event exitStakeEvent(address indexed from, address judgerOrgAddr,uint256 mainContractOrder,uint256 stakeBalance);
    event signContractEvent(address indexed from, address judgerOrgAddr,uint256 mainContractOrder,uint8 contractOrder,int8 signStatus);
    event finishContractSignEvent(address judgerOrgAddr,uint256 mainContractOrder,uint8 contractOrder);
    event createKindleEvent(address indexed from,address indexed judgerOrgAddr,address governAddr);
    event launchProposalEvent(address indexed from,address judgerOrgAddr,uint256 mainContractOrder,uint256 proposalOrder);
    event signProposalEvent(address indexed from,address judgerOrgAddr,uint256 mainContractOrder,uint256 proposalOrder,int8 signStatus);
    event finishConProposalEvent(address judgerOrgAddr,uint256 mainContractOrder,uint256 proposalOrder);
    event launchJudgerProposalEvent(address indexed from,address judgerOrgAddr,uint256 mainContractOrder,uint256 proposalOrder);
    event signJudgerProposalEvent(address indexed from,address judgerOrgAddr,uint256 mainContractOrder,uint256 proposalOrder,int8 signStatus);
    event finishJudgerProposalEvent(address indexed addr,address judgerOrgAddr,uint256 mainContractOrder,uint256 proposalOrder);
    // event assignJudgerEvent( address indexed judgerOrgAddr,uint256 mainContractOrder,address[] addr);

    event applyJudgeEvent(address indexed from, address judgerOrgAddr,uint256 mainContractOrder,address[] judgerAddr);
    event setTokenFaucetEvent(address indexed token,address indexed tokenFaucet);

    constructor(Reserve reserve_,
        GovernorAlphaProxyFactory governorAlphaProxyFactory_,
        JudgerOrgProxyFactory judgerOrgProxyFactory_,
        MainContractProxyFactory mainContractProxyFactory_,
        TimelockProxyFactory timelockProxyFactory_,
        ControlledTokenProxyFactory controlledTokenProxyFactory_) public {
        reserve = reserve_;
        governorAlphaProxyFactory = governorAlphaProxyFactory_;
        judgerOrgProxyFactory = judgerOrgProxyFactory_;
        mainContractProxyFactory = mainContractProxyFactory_;
        timelockProxyFactory = timelockProxyFactory_;
        controlledTokenProxyFactory = controlledTokenProxyFactory_;
    }

    function createMainContract(
        address[] memory persons,
        address judgerOrgAddr,
        string memory contentOrIpfsHash,
        uint256 stakeBalance,
        ERC20 token
    ) public {
        require(judgerOrgMap[judgerOrgAddr] != false,"JudgerOrg not initialized");
        require(persons.length < 10,"Num exceeds the limit");
        MainContract mainContract = mainContractProxyFactory.create();
        mainContract.initialize();
        MainContract[] storage mainContractArray = mainContractMap[judgerOrgAddr];
        
        ControlledToken conToken = controlledTokenMap[address(token)];
        if (address(conToken) == address(0)){
           conToken = controlledTokenProxyFactory.create();
           conToken.initialize("ControlToken","CToken",token.decimals(),TokenControllerInterface(this));
           controlledTokenMap[address(token)] = conToken;
        }
        mainContract.createMainContract(msg.sender,persons,stakeBalance,token,conToken,judgerOrgAddr);
        mainContractArray.push(mainContract);

        emit createMainContractEvent(msg.sender,judgerOrgAddr,address(mainContract),mainContractArray.length-1,contentOrIpfsHash);

        _signContract(judgerOrgAddr,mainContractArray.length-1,0,1);
        _addStakeBalance(judgerOrgAddr,mainContractArray.length-1,stakeBalance);
    }
    function setTokenFaucet(address token,TokenFaucet tokenFaucet) external onlyOwner {
        tokenFaucetMap[token] = tokenFaucet;
        emit setTokenFaucetEvent(token,address(tokenFaucet));
    }
    function beforeTokenTransfer(address from, address to, uint256 amount) external override {
        // require(address(controlledTokenMap[msg.sender])!= address(0), "Not correct token");

        TokenFaucet tokenFaucet = tokenFaucetMap[msg.sender];
        if (address(tokenFaucet) != address(0)) {
            tokenFaucet.beforeTokenTransfer(from, to, amount, msg.sender);
        }
    }
    function addContract(address judgerOrgAddr,uint256 mainContractOrder,
        string memory contentOrIpfsHash,uint256 stakeBalance) external  {
        onlyValidKindle(judgerOrgAddr);
        onlyValidMainContractOrder(judgerOrgAddr,mainContractOrder);
        
        MainContract mainContract = mainContractMap[judgerOrgAddr][mainContractOrder];

        mainContract.addContract(msg.sender);
        emit addContractEvent(msg.sender,judgerOrgAddr,mainContractOrder,mainContract.contractMapNum()-1,contentOrIpfsHash);
        _signContract(judgerOrgAddr,mainContractOrder,mainContract.contractMapNum()-1,1);
        _addStakeBalance(judgerOrgAddr,mainContractOrder,stakeBalance);
    }
    function addStakeBalance(address judgerOrgAddr,uint256 mainContractOrder,uint256 stakeBalance) external  {
        onlyValidKindle(judgerOrgAddr);
        onlyValidMainContractOrder(judgerOrgAddr,mainContractOrder);
        _addStakeBalance(judgerOrgAddr,mainContractOrder,stakeBalance);
    }
    function _addStakeBalance(address judgerOrgAddr,uint256 mainContractOrder,uint256 stakeBalance) internal  {
        
        // require(stakeBalance>0,"Amount cannot be zero");

        if (stakeBalance>0){
            address tokenAddr = mainContractMap[judgerOrgAddr][mainContractOrder].token();
            uint256 reserveBal = FixedPoint.multiplyUintByMantissa(stakeBalance, reserve.rateMantissa());
            IERC20(tokenAddr).safeTransferFrom(msg.sender,address(reserve), reserveBal);
            uint256 finalBalance = stakeBalance-reserveBal;
            IERC20(tokenAddr).safeTransferFrom(msg.sender,address(this), finalBalance);
            
            controlledTokenMap[tokenAddr].controllerMint(msg.sender,finalBalance);

            IERC20(tokenAddr).safeTransfer(address(mainContractMap[judgerOrgAddr][mainContractOrder]), finalBalance);
            mainContractMap[judgerOrgAddr][mainContractOrder].addStakeBalance(msg.sender,finalBalance);
            
            emit addStakeEvent(msg.sender,judgerOrgAddr,mainContractOrder,stakeBalance);
        }
    }

    function applyExit(address judgerOrgAddr,uint256 mainContractOrder) external  {
        onlyValidKindle(judgerOrgAddr);
        onlyValidMainContractOrder(judgerOrgAddr,mainContractOrder);

        JudgerOrg judgerOrg = JudgerOrg(judgerOrgAddr);
        // require(judgerOrg.assignJudgerNum() > judgerOrg.idleJudgerSupply(), "Enough Judgers");
        mainContractMap[judgerOrgAddr][mainContractOrder].applyExit(msg.sender);
        emit applyExitEvent(msg.sender,judgerOrgAddr,mainContractOrder);
    }
    function exitStakeBalance(address judgerOrgAddr,uint256 mainContractOrder,uint256 stakeBalance) external  {
        onlyValidKindle(judgerOrgAddr);
        onlyValidMainContractOrder(judgerOrgAddr,mainContractOrder);
        address tokenAddr = mainContractMap[judgerOrgAddr][mainContractOrder].token();
        (bool isFinished,bool isJudgeFinished) =mainContractMap[judgerOrgAddr][mainContractOrder].exitStakeBalance(msg.sender,stakeBalance);
        controlledTokenMap[tokenAddr].controllerBurn(msg.sender,stakeBalance);

        if (isJudgeFinished){
            
            MainContract mainContract = mainContractMap[judgerOrgAddr][mainContractOrder];

            for (uint8 j=0; j< mainContract.judgerMapNum();j++){
                JudgerOrg(judgerOrgAddr).finish(mainContract.judgerMap(j));
            }
        }
        
        if (isFinished){
            emit finishExitEvent(judgerOrgAddr,mainContractOrder);
        }else{
            emit exitStakeEvent(msg.sender,judgerOrgAddr,mainContractOrder,stakeBalance);
        }
    }
     function _signContract(address judgerOrgAddr,uint256 mainContractOrder,uint8 contractOrder,int8 signStatus) internal  {

        bool isFinished = mainContractMap[judgerOrgAddr][mainContractOrder].signContract(msg.sender,contractOrder,signStatus);

        if (isFinished){
            emit finishContractSignEvent(judgerOrgAddr,mainContractOrder,contractOrder);
        }
        emit signContractEvent(msg.sender,judgerOrgAddr,mainContractOrder,contractOrder,signStatus);
       
    }
    function signContract(address judgerOrgAddr,uint256 mainContractOrder,uint8 contractOrder,int8 signStatus,uint256 stakeBalance) external  {
        
        onlyValidKindle(judgerOrgAddr);
        onlyValidMainContractOrder(judgerOrgAddr,mainContractOrder);

        _signContract(judgerOrgAddr,mainContractOrder,contractOrder,signStatus);
        _addStakeBalance(judgerOrgAddr,mainContractOrder,stakeBalance);
    }

    function createKindle() external returns (address){

        JudgerOrg judgerOrg = judgerOrgProxyFactory.create();
        judgerOrg.initialize(address(this),address(this),msg.sender);
        judgerOrg.setAcceptTokenMap(0x0d72F64D1173c849d440aEBd1A9732427F86f586, true, 1e16);
        GovernorAlpha governorAlpha = governorAlphaProxyFactory.create();
        governorAlpha.initialize(address(this), address(judgerOrg));
        Timelock timelock = timelockProxyFactory.create();
        timelock.initialize(address(governorAlpha), 1 days);
        judgerOrg.setOwner(address(timelock));
        governorAlpha.setTimelock(address(timelock));

        judgerOrgMap[address(judgerOrg)] = true;

        emit createKindleEvent(msg.sender,address(judgerOrg),address(governorAlpha));
        return address(judgerOrg);
    }

    
    function launchProposal(address judgerOrgAddr,uint256 mainContractOrder,address[] memory persons,uint256[] memory balances) external  {
        onlyValidKindle(judgerOrgAddr);
        onlyValidMainContractOrder(judgerOrgAddr,mainContractOrder);
        require(persons.length < 10,"Num exceeds the limit");
        MainContract mainContract = mainContractMap[judgerOrgAddr][mainContractOrder];
        mainContract.launchProposal(msg.sender,persons,balances);
        
        emit launchProposalEvent(msg.sender,judgerOrgAddr,mainContractOrder,mainContract.conPersonProposalMapNum()-1);        
        _signProposal(judgerOrgAddr,mainContractOrder,mainContract.conPersonProposalMapNum()-1, 1);

    }
    function _signProposal(address judgerOrgAddr,uint256 mainContractOrder,uint256 proposalOrder,int8 signStatus) internal{
        MainContract mainContract = mainContractMap[judgerOrgAddr][mainContractOrder];

        bool isFinished = mainContract.signProposal(msg.sender,proposalOrder,signStatus);

        if (isFinished){
            address tokenAddr = mainContractMap[judgerOrgAddr][mainContractOrder].token();

            for (uint8 i=0;i<mainContract.contractPersonAddrMapNum();i++){       
                address person = mainContract.contractPersonAddrMap(i);
                (bool isJoined ,uint256 balance) = mainContract.contractPersonMap(person);
                controlledTokenMap[tokenAddr].controllerBurn(person,balance);

                mainContract.clearContractPersonBalance(person);
            }
            emit finishConProposalEvent(judgerOrgAddr,mainContractOrder,proposalOrder);
        }
        emit signProposalEvent(msg.sender,judgerOrgAddr,mainContractOrder,proposalOrder,signStatus);

    }
    function signProposal(address judgerOrgAddr,uint256 mainContractOrder,uint256 proposalOrder,int8 signStatus) external{
        onlyValidKindle(judgerOrgAddr);
        onlyValidMainContractOrder(judgerOrgAddr,mainContractOrder);
        _signProposal(judgerOrgAddr,mainContractOrder,proposalOrder, signStatus);
    }

    
    function launchJudgerProposal(address judgerOrgAddr,uint256 mainContractOrder,address[] memory persons,uint256[] memory balance) external{
        onlyValidKindle(judgerOrgAddr);
        onlyValidMainContractOrder(judgerOrgAddr,mainContractOrder);
        require(persons.length < 10,"Num exceeds the limit");
        // onlyJudgerPerson(judgerOrgAddr,mainContractOrder);

        MainContract mainContract = mainContractMap[judgerOrgAddr][mainContractOrder];
        mainContract.launchJudgerProposal(msg.sender,persons,balance);
        
        emit launchJudgerProposalEvent(msg.sender,judgerOrgAddr,mainContractOrder,mainContract.judgerProposalMapNum()-1);        
        _signJudgerProposal(judgerOrgAddr,mainContractOrder,mainContract.judgerProposalMapNum()-1, 1);

    }
    function _signJudgerProposal(address judgerOrgAddr,uint256 mainContractOrder,uint256 proposalOrder,int8 signStatus) internal  {
        MainContract mainContract = mainContractMap[judgerOrgAddr][mainContractOrder];
        bool isFinished = mainContractMap[judgerOrgAddr][mainContractOrder].signJudgerProposal(msg.sender,proposalOrder,signStatus);

        if (isFinished){
            
            address tokenAddr = mainContractMap[judgerOrgAddr][mainContractOrder].token();

            for (uint8 i=0;i<mainContract.contractPersonAddrMapNum();i++){       
                address person = mainContract.contractPersonAddrMap(i);
                (bool isJoined ,uint256 balance) = mainContract.contractPersonMap(person);
                controlledTokenMap[tokenAddr].controllerBurn(person,balance);

                mainContract.clearContractPersonBalance(person);
            }

            for (uint8 j=0; j< mainContract.judgerMapNum();j++){
                JudgerOrg(judgerOrgAddr).finish(mainContract.judgerMap(j));
            }
            emit finishJudgerProposalEvent(msg.sender,judgerOrgAddr,mainContractOrder,proposalOrder);
        }
        emit signJudgerProposalEvent(msg.sender,judgerOrgAddr,mainContractOrder,proposalOrder,signStatus);
    }
    function signJudgerProposal(address judgerOrgAddr,uint256 mainContractOrder,uint256 proposalOrder,int8 signStatus) external  {
        onlyValidKindle(judgerOrgAddr);
        onlyValidMainContractOrder(judgerOrgAddr,mainContractOrder);
        _signJudgerProposal(judgerOrgAddr,mainContractOrder,proposalOrder, signStatus);
    }

    function applyJudge(address judgerOrgAddr, uint256 mainContractOrder) external  {
        onlyValidKindle(judgerOrgAddr);
        onlyValidMainContractOrder(judgerOrgAddr,mainContractOrder);
        // onlyContractPerson(judgerOrgAddr,mainContractOrder);
        MainContract mainContract  = mainContractMap[judgerOrgAddr][mainContractOrder];
        JudgerOrg judgerOrg = JudgerOrg(judgerOrgAddr);

        for (uint8 j=0; j< mainContract.judgerMapNum();j++){
            JudgerOrg(judgerOrgAddr).finish(mainContract.judgerMap(j));
        }
        mainContract.applyJudge(msg.sender,judgerOrg.assignJudgerNum());
        
        uint256 randomNumber = uint256(blockhash(block.number - 1));

        uint256 nextRandom = randomNumber;
        uint8 judgerNum = judgerOrg.assignJudgerNum();
        address[] memory judgerArray = new address[](judgerNum);
        for (uint8 i=0; i<judgerNum; i++){
            address judger = judgerOrg.assignJudger(nextRandom,i);
            require(judger != address(0),"Not enough judges");
            judgerArray[i]=judger;
            
            mainContract.setJudger(mainContract.judgerMapNum()-1,i,judger);
            
            bytes32 nextRandomHash = keccak256(abi.encodePacked(nextRandom + 499 + i*521));
            nextRandom = uint256(nextRandomHash);
        }
            
        emit applyJudgeEvent(msg.sender,judgerOrgAddr,mainContractOrder,judgerArray);
    }
    function onlyValidKindle(address judgerOrg) private{
        require(mainContractMap[judgerOrg].length>0, "Not valid kindle");
    }
    
    function onlyValidMainContractOrder(address judgerOrg, uint256 mainContractOrder) private{
        require(mainContractOrder < mainContractMap[judgerOrg].length , "mainContractOrder");
    }
    
}
