pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;

import "sortition-sum-tree-factory/contracts/SortitionSumTreeFactory.sol";
import "@pooltogether/uniform-random-number/contracts/UniformRandomNumber.sol";

import "./helpers/ERC20.sol";
import "./libraries/SafeMath.sol";
import "./libraries/SafeERC20.sol";

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract JudgerOrg is Initializable{

    using SortitionSumTreeFactory for SortitionSumTreeFactory.SortitionSumTrees;
    using SafeERC20 for IERC20;
    /// @notice EIP-20 token decimals for this token
    uint8 public constant decimals = 1;

    /// @notice EIP-20 token symbol for this token
    string public constant symbol = "Judger";

    bytes32 constant private TREE_KEY = keccak256("Judger");
    uint256 constant private MAX_TREE_LEAVES = 5;
    /// @notice Total number of tokens in circulation
    uint256 public totalSupply = 0; // 10 million Pool

    uint256 public idleJudgerSupply = 0;

    /// @notice Address which may mint new tokens
    address public owner;
    
    // Ticket-weighted odds
    SortitionSumTreeFactory.SortitionSumTrees internal sortitionSumTrees;

    address public entrance;

    /// @notice Official record of token balances for each account
    mapping (address => string) public contactMap;
    mapping (address => uint96) internal balances;
    mapping (address => uint8) public caseNum;
    mapping (address => bool) public isIdle;
    string public url;
    string public contact;
    string public remark;
    uint8 public maxCaseNum;
    uint8 public assignJudgerNum;
    uint256 public rateMantissa;
    string public name;
    uint256 public limitJudgePeriodTime;
    uint256 public exitWaitPeriodTime;
    mapping (address => AcceptToken) public acceptTokenMap;
    
    struct AcceptToken{
        bool isAcceptable;
        uint256 minAmount;
    }

    /// @notice A record of each accounts delegate
    mapping (address => address) public delegates;

    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint96 votes;
    }

    /// @notice A record of votes checkpoints for each account, by index
    mapping (address => mapping (uint32 => Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping (address => uint32) public numCheckpoints;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    /// @notice The EIP-712 typehash for the permit struct used by the contract
    bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    /// @notice A record of states for signing / validating signatures
    mapping (address => uint) public nonces;

    address hermes;

    /// @notice An event thats emitted when the owner address is changed
    event OwnerChanged(address owner, address newOwner);

    /// @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);

    /// @notice The standard EIP-20 transfer event
    event Transfer(address indexed from, address indexed to, uint256 amount);

    event setWhiteJudgerEvent(address indexed dst, uint256 amount);
    event setIdleStatusEvent(address indexed from, bool idleStatus);
    event finishEvent(address indexed from);
    event assignJudgerEvent(address indexed from);
    event setAssignJudgerNumEvent(uint8 assignJudgerNum);
    event setMaxCaseNumEvent(uint8 maxCaseNum);
    event setRateMantissaEvent(uint256 rateMantissa);
    event setUrlEvent(string url);
    event setContactEvent(string contact);
    event setContactMapEvent(address indexed from,string contact);
    event setRemarkEvent(string remark);
    event setNameEvent(string name);
    event setTimesEvent(uint256 limitJudgePeriodTime,uint256 exitWaitPeriodTime);
    event setAcceptTokenEvent(address indexed token,bool isAcceptable,uint256 minAmount);
    event transferERC20Event(address indexed erc20,address indexed dest,uint256 balance);

    function initialize(
        address owner_, address entrance_,address firstJudger
    ) public virtual initializer {
        hermes = owner_;
        owner = owner_;
        emit OwnerChanged(address(0), owner);
        entrance = entrance_;
        _setAssignJudgerNum(1);
        _setWhiteJudger(firstJudger,1);
        _setMaxCaseNum(2);
        _setRateMantissa(2e16);
        _setTimes(7 days,14 days);
        sortitionSumTrees.createTree(TREE_KEY, MAX_TREE_LEAVES);
    }
    function setAcceptTokenMap(address acceptToken_, bool isAcceptable_,uint256 minAmount_) external onlyOwner{
        _setAcceptTokenMap(acceptToken_,isAcceptable_,minAmount_);
    }
    function _setAcceptTokenMap(address acceptToken_, bool isAcceptable_,uint256 minAmount_) internal{
        acceptTokenMap[acceptToken_] = AcceptToken({isAcceptable:isAcceptable_,minAmount:minAmount_});
        emit setAcceptTokenEvent(acceptToken_, isAcceptable_, minAmount_);
    }
    function setTimes(uint256 limitJudgePeriodTime_, uint256 exitWaitPeriodTime_) external onlyOwner{
        _setTimes(limitJudgePeriodTime_,exitWaitPeriodTime_);
    }
    function _setTimes(uint256 limitJudgePeriodTime_,uint256 exitWaitPeriodTime_) internal{
        require(exitWaitPeriodTime_>(limitJudgePeriodTime_*15/10),"Exit time should be longer than judge time");
        limitJudgePeriodTime = limitJudgePeriodTime_ ;
        exitWaitPeriodTime = exitWaitPeriodTime_;
        emit setTimesEvent(limitJudgePeriodTime_,exitWaitPeriodTime_);
    }
    function setAssignJudgerNum(uint8 assignJudgerNum_) external onlyOwner{
        _setAssignJudgerNum(assignJudgerNum_);
    }
    function _setAssignJudgerNum(uint8 assignJudgerNum_) internal{
        require(assignJudgerNum_<=25,"Too many judgers");
        assignJudgerNum = assignJudgerNum_;
        emit setAssignJudgerNumEvent(assignJudgerNum_);
    }
    function transferERC20Bat(address[] memory tokens,address[] memory dests,uint256[] memory balances) external onlyOwner{
        require(tokens.length == dests.length,"Length not same");
        require(tokens.length == balances.length,"Length not same");

        for (uint256 i=0;i<tokens.length;i++){
            IERC20(tokens[i]).safeTransfer(dests[i], balances[i]);
            emit transferERC20Event(tokens[i],dests[i],balances[i]);
        }
    }
    function transferERC20(address token,address dest,uint256 balance) external onlyOwner{
        IERC20(token).safeTransfer(dest, balance);
        emit transferERC20Event(token,dest,balance);
    }
    function setRemark(string memory remark_) external onlyOwner{
        require(bytes(remark_).length<500,"Too long");
        remark = remark_;
        emit setRemarkEvent(remark_);
    }
    function setContact(string memory contact_) external onlyOwner{
        require(bytes(contact_).length<200,"Too long");
        contact = contact_;
        emit setContactEvent(contact_);
    }
    function setUrl(string memory url_) external onlyOwner{
        require(bytes(url_).length<500,"Too long");
        url = url_;
        emit setUrlEvent(url_);
    }
    function setName(string memory name_) external onlyOwner{
        require(bytes(name_).length<200,"Too long");
        name = name_;
        emit setNameEvent(name_);
    }
    function setMaxCaseNum(uint8 maxCaseNum_) external onlyOwner{
        _setMaxCaseNum(maxCaseNum_);
    }
    function _setMaxCaseNum(uint8 maxCaseNum_) internal{
        require(maxCaseNum_<30,"Too many cases");
        maxCaseNum = maxCaseNum_;
        emit setMaxCaseNumEvent(maxCaseNum_);
    }
    function setRateMantissa(uint256 rateMantissa_) external onlyOwner{
        _setRateMantissa(rateMantissa_);
    }
    function _setRateMantissa(uint256 rateMantissa_) internal{
        require(rateMantissa_<=5e17,"Too many rateMantissa");
        rateMantissa = rateMantissa_;
        emit setRateMantissaEvent(rateMantissa_);
    }
    function setContactMap(string memory contact_) external onlyWhiteListJudger{
        require(bytes(contact_).length<200,"Too long");
        contactMap[msg.sender] = contact_;
        emit setContactMapEvent(msg.sender,contact_);
    }
    function setIdleStatus(bool idleStatus) external onlyWhiteListJudger{
        _setIdleStatus(msg.sender,idleStatus);
    }
    function updateStatus() external onlyWhiteListJudger{
        _setIdleStatus(msg.sender,isIdle[msg.sender]);
    }
    function updateStatusBat(address[] memory users) external onlyOwner{
        for (uint256 i=0;i<users.length;i++){
            _setIdleStatus(users[i],isIdle[users[i]]);
        }
    }
    
    function _setIdleStatus(address user,bool idleStatus) internal{
        
        if (idleStatus == true){
            isIdle[user] = true;
            if (caseNum[user] < maxCaseNum){
                if (sortitionSumTrees.stakeOf(TREE_KEY, bytes32(uint256(user))) == 0){
                    sortitionSumTrees.set(TREE_KEY, 1, bytes32(uint256(user)));
                    idleJudgerSupply = idleJudgerSupply + 1;
                }
            }else{
                if (sortitionSumTrees.stakeOf(TREE_KEY, bytes32(uint256(user))) == 1){
                    sortitionSumTrees.set(TREE_KEY, 0, bytes32(uint256(user)));
                    idleJudgerSupply = idleJudgerSupply - 1;
                }
            }
        }else{
            isIdle[user] = false;
            if (sortitionSumTrees.stakeOf(TREE_KEY, bytes32(uint256(user))) == 1){
                sortitionSumTrees.set(TREE_KEY, 0, bytes32(uint256(user)));
                idleJudgerSupply = idleJudgerSupply- 1;
            }
        }
        emit setIdleStatusEvent(user,idleStatus);
    }
    function finish(address addr) external onlyMainContract{
        caseNum[addr] = caseNum[addr] - 1;
        if (caseNum[addr] < maxCaseNum){
            if (isIdle[addr] == true){
                if (sortitionSumTrees.stakeOf(TREE_KEY, bytes32(uint256(addr))) == 0){
                    if (balances[addr] == 1){
                        sortitionSumTrees.set(TREE_KEY, 1, bytes32(uint256(addr)));
                        idleJudgerSupply = idleJudgerSupply+ 1;
                    }
                }
            }
        }
        emit finishEvent(addr);
    }
    address[] waitResumeAddress; 
    function assignJudger(uint256 randomNumber,uint8 order) external onlyMainContract  returns (address){

        uint256 bound = idleJudgerSupply;
        address selected;
        if (bound == 0) {
            selected = address(0);
        } else {
            uint256 token = UniformRandomNumber.uniform(randomNumber, bound);
            selected = address(uint256(sortitionSumTrees.draw(TREE_KEY, token)));
            emit assignJudgerEvent(selected);
            caseNum[selected] = caseNum[selected] + 1;
            sortitionSumTrees.set(TREE_KEY, 0, bytes32(uint256(selected)));
            idleJudgerSupply = idleJudgerSupply- 1;
            if (caseNum[selected] < maxCaseNum && balances[selected] == 1){
                if (order < assignJudgerNum){
                    waitResumeAddress.push(selected);
                }
            }
            if(order == assignJudgerNum-1){
                for (uint8 i=0; i<waitResumeAddress.length; i++){
                    sortitionSumTrees.set(TREE_KEY, 1, bytes32(uint256(waitResumeAddress[i])));
                    idleJudgerSupply = idleJudgerSupply + 1;
                    waitResumeAddress[i] = address(0x0);
                }
                delete waitResumeAddress;
            }
        }
        return selected;
    }

    /**
     * @notice Change the owner address
     * @param _owner The address of the new owner
     */
    function setOwner(address _owner) external {
        require(msg.sender == hermes, "only hermes can");
        // require(msg.sender == owner, "Pool::setOwner: only the owner can change the owner address");
        emit OwnerChanged(owner, _owner);
        owner = _owner;
        hermes = address(0);
    }
/**
     * @notice Mint new tokens
     * @param dst The address of the destination account
     * @param rawAmount The number of tokens to be minted
     */
    function _setWhiteJudger(address dst, uint96 rawAmount) internal {
        // require(block.timestamp >= mintingAllowedAfter, "Pool::mint: minting not allowed yet");
        require(dst != address(0), "mint: cannot transfer to the zero address");
        require(rawAmount == 0 || rawAmount == 1 , "mint: cannot transfer to the zero address");
        require((rawAmount == 0 && balances[dst] == 1) || (rawAmount == 1 && balances[dst] == 0), "Can not repeatly set");
        
        if (rawAmount < balances[dst]){
            totalSupply = SafeMath.sub(totalSupply, 1);
            _moveDelegates(delegates[dst], address(0), 1);
        }else{
            totalSupply = SafeMath.add(totalSupply, 1);
            _moveDelegates(address(0), delegates[dst], 1);
        }
        // transfer the amount to the recipient
        balances[dst] =  rawAmount;
        emit setWhiteJudgerEvent(dst, rawAmount);
        _setIdleStatus(dst,false);

        // move delegates
    }

    function setWhiteJudgerBat(address[] memory dst, uint96[] memory rawAmount) external {
        require(dst.length == rawAmount.length,"length not equal");
        for (uint8 i =0;i<dst.length;i++){
            _setWhiteJudger(dst[i],rawAmount[i]);
        }
    }
    /**
     * @notice Mint new tokens
     * @param dst The address of the destination account
     * @param rawAmount The number of tokens to be minted
     */
    function setWhiteJudger(address dst, uint96 rawAmount) external {
        _setWhiteJudger(dst,rawAmount);
    }

    /**
     * @notice Get the number of tokens held by the `account`
     * @param account The address of the account to get the balance of
     * @return The number of tokens held
     */
    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    /**
     * @notice Delegate votes from `msg.sender` to `delegatee`
     * @param delegatee The address to delegate votes to
     */
    function delegate(address delegatee) public {
        return _delegate(msg.sender, delegatee);
    }

    /**
     * @notice Delegates votes from signatory to `delegatee`
     * @param delegatee The address to delegate votes to
     * @param nonce The contract state required to match the signature
     * @param expiry The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function delegateBySig(address delegatee, uint nonce, uint expiry, uint8 v, bytes32 r, bytes32 s) public {
        bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), getChainId(), address(this)));
        bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "delegateBySig: invalid signature");
        require(nonce == nonces[signatory]++, "delegateBySig: invalid nonce");
        require(now <= expiry, "delegateBySig: signature expired");
        return _delegate(signatory, delegatee);
    }

    /**
     * @notice Gets the current votes balance for `account`
     * @param account The address to get votes balance
     * @return The number of current votes for `account`
     */
    function getCurrentVotes(address account) external view returns (uint96) {
        uint32 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address account, uint blockNumber) public view returns (uint96) {
        require(blockNumber < block.number, "getPriorVotes: not yet determined");

        uint32 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }

    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = delegates[delegator];
        uint96 delegatorBalance = balances[delegator];
        delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }


    function _moveDelegates(address srcRep, address dstRep, uint96 amount) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                uint32 srcRepNum = numCheckpoints[srcRep];
                uint96 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
                uint96 srcRepNew = sub96(srcRepOld, amount, "Pool::_moveVotes: vote amount underflows");
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

            if (dstRep != address(0)) {
                uint32 dstRepNum = numCheckpoints[dstRep];
                uint96 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
                uint96 dstRepNew = add96(dstRepOld, amount, "_moveVotes: vote amount overflows");
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _writeCheckpoint(address delegatee, uint32 nCheckpoints, uint96 oldVotes, uint96 newVotes) internal {
      uint32 blockNumber = safe32(block.number, "_writeCheckpoint: block number exceeds 32 bits");

      if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
          checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
      } else {
          checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
          numCheckpoints[delegatee] = nCheckpoints + 1;
      }

      emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function safe96(uint n, string memory errorMessage) internal pure returns (uint96) {
        require(n < 2**96, errorMessage);
        return uint96(n);
    }

    function add96(uint96 a, uint96 b, string memory errorMessage) internal pure returns (uint96) {
        uint96 c = a + b;
        require(c >= a, errorMessage);
        return c;
    }

    function sub96(uint96 a, uint96 b, string memory errorMessage) internal pure returns (uint96) {
        require(b <= a, errorMessage);
        return a - b;
    }

    function getChainId() internal pure returns (uint) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }
    
    modifier onlyWhiteListJudger() {
        require(balances[msg.sender] == 1, "Not whiteList judger");
        _;
    }
    
    modifier onlyMainContract() {
        require(msg.sender == address(entrance), "Not entrance ");
        _;
    }
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner ");
        _;
    }
}