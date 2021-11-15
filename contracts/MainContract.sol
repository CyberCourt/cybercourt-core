
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "./helpers/ERC20.sol";

import "./libraries/Address.sol";

import "./libraries/SafeERC20.sol";

import "./libraries/EnumerableSet.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "sortition-sum-tree-factory/contracts/SortitionSumTreeFactory.sol";

import "./JudgerOrg.sol";
import "./GovernorAlpha.sol";
import "./Timelock.sol";
import "@pooltogether/fixed-point/contracts/FixedPoint.sol";
import "./token/ControlledToken.sol";

contract MainContract is OwnableUpgradeable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct BasicInfo{
        uint256 startBlockTime; 
        uint256 endBlockTime;
        uint256 applyExitBlockTime;
        uint256 applyJudgeBlockTime;
        uint256 exitWaitPeriodTime;
        ControlledToken controlledToken;
        uint256 limitJudgePeriodTime; 
        int256 succJudgeProposalOrder;
        int256 succConPersonProposalOrder;
        uint256 totalStake;
        int8 status;
        IERC20 token;
        uint256  firstApplyJudgeBlockTime;
    }
    BasicInfo public basicInfo;
    mapping(uint256 => Proposal) public conPersonProposalMap;
    uint256 public conPersonProposalMapNum;

    mapping(uint8 => address) public judgerMap;
    // mapping(uint256 => uint8) public judgerNumMap;
    mapping(address => bool) public judgerExistedMap;
    uint8 public judgerMapNum; 
    mapping(uint256 => Proposal) public judgerProposalMap;
    uint256 public judgerProposalMapNum;

    mapping(uint8 => ContractDetail) public contractMap;
    uint8 public contractMapNum;
    mapping(uint8 => address) public contractPersonAddrMap; 
    uint8 public contractPersonAddrMapNum;
    mapping(address => AddrBalance) public contractPersonMap;
    
    struct Proposal{
        uint8 assignAddrMapNum;
        uint8 agreeNum;
        uint8 rejectNum;
        address proposer;
        mapping(uint8 => address) assignAddrMap;
        mapping(address => uint256) assignBalanceMap;
        mapping(address => SignInfo) signInfoMap;
    }

    struct AddrBalance{
        bool isJoined;
        uint256 balance;
    }

    struct ContractDetail{
        uint256 startBlockTime;
        // string ipfsHash;
        mapping(address => SignInfo) signInfoMap;
    }

    struct SignInfo{
        uint256 blockTime; 
        int8 status;
    }


    uint256 public judgerRateMantissa;
    uint256 public judgerBalance;
    JudgerOrg public judgerOrg;

    function getContractSignInfo(uint8 contractOrder,address user) external view returns(uint256,int8){
        return (contractMap[contractOrder].signInfoMap[user].blockTime,contractMap[contractOrder].signInfoMap[user].status);
    }
    function getProposalSignInfo(bool isJudgerProposal,uint256 proposalOrder,address user) external view returns(uint256,int8){
        if (isJudgerProposal){
            return (judgerProposalMap[proposalOrder].signInfoMap[user].blockTime,judgerProposalMap[proposalOrder].signInfoMap[user].status);

        }else{
            return (conPersonProposalMap[proposalOrder].signInfoMap[user].blockTime,conPersonProposalMap[proposalOrder].signInfoMap[user].status);

        }
    }
    function getProposalAssignAddr(bool isJudgerProposal,uint256 proposalOrder,uint8 order) external view returns(address){
        if (isJudgerProposal){
            return judgerProposalMap[proposalOrder].assignAddrMap[order];
        }else{
            return conPersonProposalMap[proposalOrder].assignAddrMap[order];
        }
    }
    function getProposalAssignBalance(bool isJudgerProposal,uint256 proposalOrder,address user) external view returns(uint256){
        if (isJudgerProposal){
            return judgerProposalMap[proposalOrder].assignBalanceMap[user];
        }else{
            return conPersonProposalMap[proposalOrder].assignBalanceMap[user];
        }
    }
    function initialize ()
        public virtual initializer{
        __Ownable_init();
    }
    function createMainContract(
        address sponsor,
        address[] memory persons,
        uint256 stakeBalance,
        ERC20 token,
        ControlledToken controlledToken,
        address judgerOrg_
    ) public onlyOwner{
        judgerOrg = JudgerOrg(judgerOrg_);
        (bool isAcceptable,uint256 minAmount) = judgerOrg.acceptTokenMap(address(token));
        require(isAcceptable == true, "Token is not supported In this team");
        require(stakeBalance>=minAmount, "Token amount is too low");

        basicInfo=BasicInfo({
            startBlockTime: block.timestamp,
            applyJudgeBlockTime: 0,
            endBlockTime: 0,
            controlledToken: controlledToken,
            limitJudgePeriodTime: judgerOrg.limitJudgePeriodTime(),
            exitWaitPeriodTime: judgerOrg.exitWaitPeriodTime(),
            succJudgeProposalOrder: -1,
            succConPersonProposalOrder: -1,
            totalStake: 0,
            token: token,
            status: 0,
            applyExitBlockTime: 0,
            firstApplyJudgeBlockTime:0
        });
        conPersonProposalMapNum = 0;
        judgerMapNum = 0;
        judgerProposalMapNum = 0;
        contractMapNum = 0;
        contractPersonAddrMapNum = 0;
        // contractMap[0] = ContractDetail(block.timestamp,ipfsHash);
        contractMap[0] = ContractDetail(block.timestamp);
        contractMapNum = 1;
        

        for (uint8 i=0;i<persons.length;i++){
            require(contractPersonMap[persons[i]].isJoined == false,"Duplicate personnel");
            contractPersonAddrMap[i] = persons[i];
            contractPersonMap[persons[i]].isJoined = true;
        }
        contractPersonAddrMapNum = uint8(persons.length);
        judgerRateMantissa = judgerOrg.rateMantissa();

    }
    function clearContractPersonBalance(address person) external  onlyOwner{
        contractPersonMap[person].balance = 0;
    }
    function addContract(address sponsor) external  onlyOwner{
        onlyContractPerson(sponsor);
        
        require(basicInfo.status == 1,"Not correct status");
        require(contractMapNum < 255,"Too much Contracts");
        // contractMap[contractMapNum] = ContractDetail(block.timestamp,ipfsHash);
        contractMap[contractMapNum] = ContractDetail(block.timestamp);
        contractMapNum = contractMapNum + 1;
    }
    function token() view external returns (address){
        return address(basicInfo.token);
    }
    function addStakeBalance(address sponsor,uint256 finalBalance) external onlyOwner {
        require(basicInfo.status == 1 || basicInfo.status == 0,"Not correct status");
        require(address(basicInfo.controlledToken) != address(0),"Not registered token");
        onlyContractPerson(sponsor);
        contractPersonMap[sponsor].balance = contractPersonMap[sponsor].balance + finalBalance;
        basicInfo.totalStake = basicInfo.totalStake + finalBalance;
    }

    function applyExit(address sponsor) external onlyOwner {
        onlyContractPerson(sponsor);
        require((basicInfo.status == 1 && judgerOrg.assignJudgerNum()>judgerOrg.idleJudgerSupply()) || 
        (basicInfo.firstApplyJudgeBlockTime + basicInfo.limitJudgePeriodTime <= block.timestamp
          && basicInfo.succConPersonProposalOrder == -1
          && basicInfo.succJudgeProposalOrder == -1
          && basicInfo.status == 2
          && basicInfo.firstApplyJudgeBlockTime !=0), "Contract has not been signed or has been assigned judgers");
        require(basicInfo.applyExitBlockTime == 0,"applyExistBlock not zero"); 
        basicInfo.applyExitBlockTime = block.timestamp;
    }
    function exitStakeBalance(address sponsor,uint256 stakeBalance) external onlyOwner returns(bool,bool) {
        onlyContractPerson(sponsor);
        require(stakeBalance<=contractPersonMap[sponsor].balance, "Exceeds stake balance");
        require(stakeBalance > 0,"amount can not be zero");
        require(basicInfo.status == 0 || basicInfo.status == 3 || 
        (basicInfo.applyExitBlockTime !=0 && basicInfo.applyExitBlockTime + basicInfo.exitWaitPeriodTime <= block.timestamp),"Contract has been signed or exit time has not expired");

        contractPersonMap[sponsor].balance = contractPersonMap[sponsor].balance - stakeBalance;
        IERC20(basicInfo.token).safeTransfer(sponsor, stakeBalance);
        basicInfo.totalStake = basicInfo.totalStake - stakeBalance;
        bool isJudgeFinished = false;
        if (basicInfo.status == 2)
            isJudgeFinished = true;

        basicInfo.status = 3;

        if(basicInfo.totalStake == 0){
            basicInfo.status = 4;
            basicInfo.endBlockTime = block.timestamp;
            return (true,isJudgeFinished);
        }
        return (false,isJudgeFinished);
    }
     function _signContract(address sponsor,uint8 contractOrder,int8 signStatus) internal returns(bool) {
        onlyValidContractOrder(contractOrder);
        onlyContractPerson(sponsor);
        require(contractMap[contractOrder].signInfoMap[sponsor].status == 0,"Has Signed");
        contractMap[contractOrder].signInfoMap[sponsor].blockTime = block.timestamp;
        contractMap[contractOrder].signInfoMap[sponsor].status = signStatus;
       
        if (contractOrder == 0){
            require(basicInfo.status == 0,"Not correct status");

            basicInfo.endBlockTime = block.timestamp;
            basicInfo.status = 1;
            for (uint8 i=0; i<contractPersonAddrMapNum; i++){
                if (contractMap[contractOrder].signInfoMap[contractPersonAddrMap[i]].status != 1){
                    basicInfo.status = 0;
                }
            }
            if (basicInfo.status == 1){
                return true;
            }
        }
        return false;
                
    }
    function signContract(address sponsor,uint8 contractOrder,int8 signStatus) external onlyOwner returns(bool){
        return _signContract(sponsor,contractOrder,signStatus);
    }

    
    function launchProposal(address sponsor,address[] memory persons,uint256[] memory balance) external onlyOwner {
        require(persons.length == balance.length,"Array length must be same");
        require(persons.length < 10,"Array length>10");

        require(basicInfo.status == 1,"Not correct status");
        onlyContractPerson(sponsor);
        conPersonProposalMap[conPersonProposalMapNum] = Proposal(uint8(persons.length),0,0,sponsor);
        
        uint256 totalStakeTemp = basicInfo.totalStake;
        for (uint8 i=0;i<persons.length;i++){
            require(contractPersonMap[persons[i]].isJoined == true ,"Not contract person");
            require(balance[i] <= totalStakeTemp, "Balance overflow" );
            totalStakeTemp = totalStakeTemp - balance[i];
            conPersonProposalMap[conPersonProposalMapNum].assignAddrMap[i] = persons[i];
            conPersonProposalMap[conPersonProposalMapNum].assignBalanceMap[persons[i]] = balance[i];
        }
        require (totalStakeTemp == 0, "Balance remain not zero");
        
        conPersonProposalMapNum = conPersonProposalMapNum + 1;
        // _signProposal(kindle,summaryOrder,summary.conPersonProposalMapNum-1, 1);
        // emit launchProposalEvent(msg.sender,kindle,summaryOrder,summary.conPersonProposalMapNum-1);
    }
    function _signProposal(address sponsor,uint256 proposalOrder,int8 signStatus) internal  returns(bool){
        onlyValidConPersonProposalOrder(proposalOrder);
        require(basicInfo.status == 1,"Not correct status");
        onlyContractPerson(sponsor);
        Proposal storage proposal = conPersonProposalMap[proposalOrder];
        SignInfo storage signInfo = conPersonProposalMap[proposalOrder].signInfoMap[sponsor];
        signInfo.blockTime = block.timestamp;
        require(signInfo.status == 0,"Has signed");
        
        signInfo.status = signStatus;
        if (signStatus == 1){
            proposal.agreeNum = proposal.agreeNum + 1;
        }else if (signStatus == -1){
            proposal.rejectNum = proposal.rejectNum + 1;    
        }
        uint256 signNum = proposal.agreeNum + proposal.rejectNum;
        if(signNum == contractPersonAddrMapNum){
            if (proposal.rejectNum == 0 ){
                for (uint8 i=0; i<proposal.assignAddrMapNum; i++ ){
                    IERC20(basicInfo.token).safeTransfer(proposal.assignAddrMap[i], proposal.assignBalanceMap[proposal.assignAddrMap[i]]);
                }
                require(IERC20(basicInfo.token).balanceOf(address(this))==0,"The Proposal not assign all tokens");
                basicInfo.succConPersonProposalOrder = int256(proposalOrder);
                basicInfo.totalStake = 0;
                basicInfo.endBlockTime = block.timestamp;
                basicInfo.status = 4;
                return true;
            }
        }
        return false;
    }
    function signProposal(address sponsor,uint256 proposalOrder,int8 signStatus) external onlyOwner returns(bool) {
        return _signProposal(sponsor,proposalOrder, signStatus);
    }

    
    function launchJudgerProposal(address sponsor,address[] memory persons,uint256[] memory balance) external{
        onlyJudgerPerson(sponsor);
        require(basicInfo.status == 2,"Not correct status");
        judgerProposalMap[judgerProposalMapNum] = Proposal(uint8(persons.length),0,0,sponsor);
        uint256 totalStakeTemp = basicInfo.totalStake-judgerBalance;
        for (uint8 i=0;i<persons.length;i++){
            require(contractPersonMap[persons[i]].isJoined == true ,"Not contract person");
            require(balance[i] <= totalStakeTemp, "Balance overflow" );
            totalStakeTemp = totalStakeTemp - balance[i];
            judgerProposalMap[judgerProposalMapNum].assignAddrMap[i] = persons[i];
            judgerProposalMap[judgerProposalMapNum].assignBalanceMap[persons[i]] = balance[i];
        }
        // summary.judgerProposalMap[summary.judgerProposalMapNum].assignAddrMapNum = persons.length;
        require (totalStakeTemp == 0, "Balance remain not zero");
        judgerProposalMapNum = judgerProposalMapNum + 1;
        // _signJudgerProposal(kindle,summaryOrder,summary.judgerProposalMapNum-1, 1);
        // emit launchJudgerProposalEvent(msg.sender,kindle,summaryOrder,summary.judgerProposalMapNum-1);
    }
    function _signJudgerProposal(address sponsor,uint256 proposalOrder,int8 signStatus) internal returns(bool) {
        onlyValidJudgerProposalOrder(proposalOrder);
        onlyJudgerPerson(sponsor);
        require(basicInfo.status == 2,"Not correct status");
        Proposal storage proposal = judgerProposalMap[proposalOrder];
        SignInfo storage signInfo = judgerProposalMap[proposalOrder].signInfoMap[sponsor];
        signInfo.blockTime = block.timestamp;
        require(signInfo.status == 0,"Has signed");
        
        signInfo.status = signStatus;
        if (signStatus == 1){
            proposal.agreeNum = proposal.agreeNum + 1;
        }else if (signStatus == -1){
            proposal.rejectNum = proposal.rejectNum + 1;    
        }
        uint256 signNum = proposal.agreeNum + proposal.rejectNum;

        if (proposal.agreeNum > (judgerMapNum/2) ){

            IERC20(basicInfo.token).safeTransfer(address(judgerOrg), judgerBalance);
            for (uint8 i=0; i<proposal.assignAddrMapNum; i++ ){
                IERC20(basicInfo.token).safeTransfer(proposal.assignAddrMap[i], proposal.assignBalanceMap[proposal.assignAddrMap[i]]);
            }
            require(IERC20(basicInfo.token).balanceOf(address(this))==0,"The Proposal not assign all tokens");

            basicInfo.totalStake = 0;
            basicInfo.succJudgeProposalOrder = int256(proposalOrder);
            basicInfo.status = 4;
            return true;
        }
        return false;
    }
    function signJudgerProposal(address sponsor,uint256 proposalOrder,int8 signStatus) external onlyOwner returns(bool) {
        return _signJudgerProposal(sponsor,proposalOrder, signStatus);
    }
    function applyJudge(address sponsor,uint8 judgerNum_) external onlyOwner {
        onlyContractPerson(sponsor);
        require(basicInfo.status == 1 || 
         (basicInfo.applyJudgeBlockTime + basicInfo.limitJudgePeriodTime <= block.timestamp
          && basicInfo.succConPersonProposalOrder == -1 
          && basicInfo.succJudgeProposalOrder == -1 
          && basicInfo.status == 2 
          && basicInfo.applyJudgeBlockTime != 0),"Not meet the conditions");

        for(uint8 i=0;i<judgerMapNum;i++){
            judgerExistedMap[judgerMap[i]] = false;
        }
        judgerMapNum = judgerNum_;
        // judgerNumMap[judgerMapNum-1] = judgerNum;
        basicInfo.status = 2;
        if (basicInfo.applyJudgeBlockTime == 0){
            basicInfo.firstApplyJudgeBlockTime = block.timestamp;
        }
        basicInfo.applyJudgeBlockTime = block.timestamp;
        
        judgerBalance = FixedPoint.multiplyUintByMantissa(basicInfo.totalStake, judgerRateMantissa);
    }
    function setJudger(uint256 judgerOrder,uint8 order,address judger) external  {
        judgerMap[order] = judger;
        judgerExistedMap[judger] = true;
    }
    function onlyValidContractOrder(uint256 contractOrder) private{
        require(contractOrder < contractMapNum , "Not valid contractOrder");
    }
    
    function onlyValidJudgerProposalOrder(uint256 proposalOrder) private{
        require(proposalOrder < judgerProposalMapNum , "Not valid summaryOrder");
    }
    function onlyValidConPersonProposalOrder(uint256 proposalOrder) private{
        require(proposalOrder < conPersonProposalMapNum , "Not valid summaryOrder");
    }
    function onlyJudgerPerson(address sponsor) private{
        require(judgerExistedMap[sponsor] == true, "Not judge");
    }
    function onlyContractPerson(address sponsor) private{
        require(contractPersonMap[sponsor].isJoined == true, "Not contract person");
    }
}
