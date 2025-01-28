// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
contract MelodyCoin{
    uint256 public constant RESERVE_PERCENTAGE = 2;
    uint256 public constant BURN_PERCENTAGE = 2; // reserve gets 0.2%
    uint256 public constant PERCENTAGE_FACTOR = 1000; // burn percentage is 0.2%
    uint256 public constant FAUCET_ONE_TIME_DELIVERY_AMOUNT = 100000000000000000; // 0.1 in wei
    uint256 public constant FAUCET_USER_THRESHOLD_BALANCE = 1500000000000000000;
    uint256 public constant FAUCET_VALIDATION_INTERVAL = 24 hours;
    string private name_;
    uint256 public reserveBalance;
    string private symbol_;
    uint8 private decimals_;
    address private immutable owner_;
    uint256 private totalSupply_;
    uint256 private maxCap_;


    mapping(address=>uint256) private balances;
    mapping(address=>mapping(address=>uint256)) private allowances;
    mapping(address=>uint256) private faucetRecords;

    event Transfer(address indexed from,address indexed to,uint256 amount);
    event Approval(address indexed owner,address indexed spender,uint256 amount);
    event Burn(address indexed from, address indexed to, uint256 amount);
    event Mint(uint256 amount);

    modifier onlyOwner(){
        require(msg.sender == owner_,"Only owner can perform this action!");
        _;
    }

    modifier noZeroAddrTransfer(address _receipent){
        require(_receipent != address(0),"Can't transfer to zero address");
        _;
    }

    modifier hasSufficientFunds(uint256 _balance, uint256 _amount){
        require(_balance >= _amount,"No sufficient funds!");
        _;
    }

    modifier faucetMaxBalanceCheck(address _account){
        require(balances[_account] < FAUCET_USER_THRESHOLD_BALANCE,"Too high balance to request faucet!");
        _;
    }

    modifier faucetDayIntervalCheck(address _account){
        require(block.timestamp >= faucetRecords[_account]+FAUCET_VALIDATION_INTERVAL);
        _;
    }

    modifier faucetBalanceCheck(){
        require(reserveBalance > FAUCET_ONE_TIME_DELIVERY_AMOUNT,"Reserves depleted!");
        _;
    }
    /**
        @dev constructor to initialize the token
        @param _name is the token name
        @param _symbol is the token symbol
    */
    constructor (
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _initialSupply,
        uint256 _maxCap
    ) {
        require(_initialSupply <= _maxCap,"Initial supply can't exceed Max Cap");
        owner_ = msg.sender;
        name_ = _name;
        symbol_ = _symbol;
        decimals_ = _decimals;
        totalSupply_ = _initialSupply*(10**_decimals);
        maxCap_ = _maxCap;
        reserveBalance = _initialSupply;

        emit Mint(reserveBalance);
    }

    /**
        @dev Returns the name of the token
    */
    function name() public view returns (string memory){
        return name_;
    }

    /**
        @dev Returns the symbol of the token
    */
    function symbol() public view returns (string memory){
        return symbol_;
    }

    /**
        @dev Returns the number of the decimals
    */
    function decimals() public view returns (uint8){
        return decimals_;
    }

    /**
        @dev Returns the total supply of the tokens
    */
    function totalSupply() public view returns (uint256){
        return totalSupply_;
    }

    /**
        * @dev Check token balance of a specific address
        * @param _account Address to check balance for
        * @return Token balance of the account
    */
    function balanceOf(address _account) public view returns (uint256) {
        return balances[_account];
    }

    /**
        * @dev Transfers tokens from sender to recipient
        * @param _recipient Address receiving the tokens
        * @param _amount Number of tokens to transfer
        * @return Boolean indicating transfer success
    */
    function transfer(address _recipient, uint256 _amount) public noZeroAddrTransfer(_recipient) hasSufficientFunds(balances[msg.sender], _amount) returns (bool) {
        balances[msg.sender] -= _amount;
        uint256 burnAmount = burn(_amount);
        balances[_recipient] += (_amount - burnAmount);
        emit Transfer(msg.sender, _recipient, _amount-burnAmount);
        emit Burn(msg.sender, _recipient, burnAmount);
        return true;
    }

    /**
        * @dev Approves another address to spend tokens on behalf of the owner
        * @param _spender Address allowed to spend tokens
        * @param _amount Number of tokens allowed to spend
        * @return Boolean indicating approval success
    */
    function approve(address _spender, uint256 _amount) public noZeroAddrTransfer(_spender) returns (bool) {
        allowances[msg.sender][_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    /**
        * @dev Returns the number of tokens a spender is allowed to spend on behalf of an owner
        * @param _owner Address of token owner
        * @param _spender Address allowed to spend tokens
        * @return Remaining number of tokens spender is allowed to spend
    */
    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowances[_owner][_spender];
    }

    /**
        * @dev Transfers tokens from one address to another if allowed
        * @param _sender Address sending the tokens
        * @param _recipient Address receiving the tokens
        * @param _amount Number of tokens to transfer
        * @return Boolean indicating transfer success
    */
    function transferFrom(
        address _sender, 
        address _recipient, 
        uint256 _amount
    ) public hasSufficientFunds(balances[_sender], _amount) returns (bool) {
        require(allowances[_sender][msg.sender] >= _amount, "No sufficient allowance!");
        balances[_sender] -= _amount;
        uint256 burnAmount = burn(_amount);
        balances[_recipient] += (_amount - burnAmount);
        allowances[_sender][msg.sender] -= _amount;
        emit Transfer(_sender, _recipient, _amount - burnAmount);
        emit Burn(msg.sender, _recipient, burnAmount);
        return true;
    }

    /**
        * @dev Mint new tokens (needs owner accesss)
        * @param _account Address to receive new tokens
        * @param _amount Number of tokens to mint
    */
    function mint(address _account, uint256 _amount) public onlyOwner(){
        require((totalSupply_+_amount) < maxCap_,"Can't mint tokens, as it exceeds the set Max Cap");
        uint256 reserveShare = (_amount * RESERVE_PERCENTAGE)/10; // 20%
        uint256 userShare = _amount - reserveShare;
        totalSupply_ += _amount;
        balances[_account] += userShare;
        reserveBalance += reserveShare;
        emit Transfer(address(0), _account, userShare);
        emit Mint(_amount);
    }

    /**
        * @dev Burn tokens to reduce total supply
        * @param _amount Number of tokens to burn
    */
    function burn(uint256 _amount) public returns (uint256) {
        uint256 burnAmount = (_amount * BURN_PERCENTAGE)/(PERCENTAGE_FACTOR);
        totalSupply_ -= burnAmount;
        return burnAmount;
    }

    /**
        * @dev Faucet for new users to collect tokens
    */
   function getFaucetAssets() faucetDayIntervalCheck(msg.sender) faucetMaxBalanceCheck(msg.sender) faucetBalanceCheck() external{
        reserveBalance -= FAUCET_ONE_TIME_DELIVERY_AMOUNT;
        balances[msg.sender] += FAUCET_ONE_TIME_DELIVERY_AMOUNT;
        faucetRecords[msg.sender] = block.timestamp;
        emit Transfer(address(this), msg.sender, FAUCET_ONE_TIME_DELIVERY_AMOUNT);
   }
}
