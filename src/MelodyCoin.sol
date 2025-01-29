// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract MelodyCoin {
    uint8 public constant RESERVE_PERCENTAGE = 2;
    uint8 public constant BURN_PERCENTAGE = 2; // reserve gets 0.2% -> 2/1000
    bool public paused;
    uint8 public decimals_;
    uint16 public constant PERCENTAGE_FACTOR = 1000; // burn percentage is 0.2%
    address public immutable owner_;
    address public contractAddress;
    string public name_;
    string public symbol_;
    uint256 public constant FAUCET_ONE_TIME_DELIVERY_AMOUNT = 1e17; // 0.1 in wei
    uint256 public constant FAUCET_USER_THRESHOLD_BALANCE = 15e17;
    uint256 public constant FAUCET_VALIDATION_INTERVAL = 24 hours;
    uint256 public totalSupply_;
    uint256 public maxCap_;

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;
    mapping(address => uint256) private faucetRecords;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Burn(address indexed from, address indexed to, uint256 amount);
    event Mint(uint256 amount);
    event Paused(uint256 timestamp);
    event UnPaused(uint256 timestamp);

    error InvalidAddress();
    error NotAnOwner();
    error InsufficientFunds(uint256 balance, uint256 amount);
    error TooHighBalance(address account);
    error TooFrequentRequests(address account);
    error DepletedFaucetReserves();
    error ContractPaused();
    error MaxCapExceeded();
    error InsufficientAllowance();
    error FrontRunApprovalCheck(string msg);

    modifier onlyOwner() {
        if (msg.sender != owner_) {
            revert NotAnOwner();
        }
        _;
    }

    modifier isContractPaused() {
        if (paused) {
            revert ContractPaused();
        }
        _;
    }

    modifier noZeroAddrTransfer(address _receipent) {
        if (_receipent == address(0)) {
            revert InvalidAddress();
        }
        _;
    }

    modifier hasSufficientFunds(uint256 _balance, uint256 _amount) {
        if (_balance < _amount) {
            revert InsufficientFunds(_balance, _amount);
        }
        _;
    }

    modifier faucetMaxBalanceCheck(address _account) {
        if (balances[_account] >= FAUCET_USER_THRESHOLD_BALANCE) {
            revert TooHighBalance(_account);
        }
        _;
    }

    modifier faucetDayIntervalCheck(address _account) {
        if (block.timestamp < faucetRecords[_account] + FAUCET_VALIDATION_INTERVAL) {
            revert TooFrequentRequests(_account);
        }
        _;
    }

    modifier faucetBalanceCheck() {
        if (balances[contractAddress] <= FAUCET_ONE_TIME_DELIVERY_AMOUNT) {
            revert DepletedFaucetReserves();
        }
        _;
    }

    modifier maxCapCheck(uint256 amount) {
        if (amount + totalSupply_ > maxCap_) {
            revert MaxCapExceeded();
        }
        _;
    }

    modifier hasSufficientAllowance(address sender, uint256 amount) {
        if (allowances[sender][msg.sender] < amount) {
            revert InsufficientAllowance();
        }
        _;
    }

    modifier checkApprovalRace(address spender, uint256 amount) {
        // msg.sender, spender
        if (amount != 0) {
            if (allowances[msg.sender][spender] != 0) {
                revert FrontRunApprovalCheck("Set allowance to zero first, to avoid frontrun race");
            }
        }
        _;
    }

    /**
     * @dev constructor to initialize the token
     *     @param _name is the token name
     *     @param _symbol is the token symbol
     */
    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _initialSupply, uint256 _maxCap) {
        require(_initialSupply <= _maxCap, "Initial supply can't exceed max cap");
        owner_ = msg.sender;
        paused = false;
        name_ = _name;
        symbol_ = _symbol;
        decimals_ = _decimals;
        totalSupply_ = _initialSupply;
        maxCap_ = _maxCap;
        contractAddress = address(this);
        balances[contractAddress] = _initialSupply;

        emit Mint(balances[contractAddress]);
    }

    /**
     * @dev Returns the name of the token
     */
    function name() external view returns (string memory) {
        return name_;
    }

    /**
     * @dev Returns the symbol of the token
     */
    function symbol() external view returns (string memory) {
        return symbol_;
    }

    /**
     * @dev Returns the number of the decimals
     */
    function decimals() external view returns (uint8) {
        return decimals_;
    }

    /**
     * @dev Returns the total supply of the tokens
     */
    function totalSupply() external view returns (uint256) {
        return totalSupply_;
    }

    /**
     * @dev Check token balance of a specific address
     * @param _account Address to check balance for
     * @return Token balance of the account
     */
    function balanceOf(address _account) external view returns (uint256) {
        return balances[_account];
    }

    /**
     * @dev Transfers tokens from sender to recipient
     * @param _recipient Address receiving the tokens
     * @param _amount Number of tokens to transfer
     * @return Boolean indicating transfer success
     */
    function transfer(address _recipient, uint256 _amount)
        external
        noZeroAddrTransfer(_recipient)
        isContractPaused
        hasSufficientFunds(balances[msg.sender], _amount)
        returns (bool)
    {
        uint256 burnAmount = burn(_amount);
        unchecked {
            balances[msg.sender] -= _amount;
            balances[_recipient] += (_amount - burnAmount);
        }
        emit Transfer(msg.sender, _recipient, _amount - burnAmount);
        emit Burn(msg.sender, _recipient, burnAmount);
        return true;
    }

    /**
     * @dev Approves another address to spend tokens on behalf of the owner
     * @param _spender Address allowed to spend tokens
     * @param _amount Number of tokens allowed to spend
     * @return Boolean indicating approval success
     */
    function approve(address _spender, uint256 _amount)
        external
        noZeroAddrTransfer(_spender)
        isContractPaused
        checkApprovalRace(_spender, _amount)
        returns (bool)
    {
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
    function allowance(address _owner, address _spender) external view returns (uint256) {
        return allowances[_owner][_spender];
    }

    /**
     * @dev Transfers tokens from one address to another if allowed
     * @param _sender Address sending the tokens
     * @param _recipient Address receiving the tokens
     * @param _amount Number of tokens to transfer
     * @return Boolean indicating transfer success
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount)
        external
        hasSufficientFunds(balances[_sender], _amount)
        isContractPaused
        hasSufficientAllowance(_sender, _amount)
        returns (bool)
    {
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
    function mint(address _account, uint256 _amount) external onlyOwner isContractPaused maxCapCheck(_amount) {
        uint256 reserveShare = (_amount * RESERVE_PERCENTAGE) / 10; // 20%
        uint256 userShare = _amount - reserveShare;
        unchecked {
            totalSupply_ += _amount;
            balances[_account] += userShare;
            balances[contractAddress] += reserveShare;
        }
        emit Transfer(contractAddress, _account, userShare);
        emit Mint(_amount);
    }

    /**
     * @dev Burn tokens to reduce total supply
     * @param _amount Number of tokens to burn
     */
    function burn(uint256 _amount) internal returns (uint256) {
        uint256 burnAmount = (_amount * BURN_PERCENTAGE) / (PERCENTAGE_FACTOR);
        uint256 reserveAmount = (_amount * RESERVE_PERCENTAGE) / (PERCENTAGE_FACTOR);
        unchecked {
            totalSupply_ = totalSupply_ - (burnAmount);
            balances[contractAddress] += reserveAmount;
        }
        return burnAmount + reserveAmount;
    }

    /**
     * @dev Faucet for new users to collect tokens
     */
    function getFaucetAssets()
        external
        faucetDayIntervalCheck(msg.sender)
        faucetMaxBalanceCheck(msg.sender)
        faucetBalanceCheck
    {
        unchecked {
            balances[contractAddress] -= FAUCET_ONE_TIME_DELIVERY_AMOUNT;
            balances[msg.sender] += FAUCET_ONE_TIME_DELIVERY_AMOUNT;
        }
        faucetRecords[msg.sender] = block.timestamp;
        emit Transfer(address(this), msg.sender, FAUCET_ONE_TIME_DELIVERY_AMOUNT);
    }

    function togglePause() external onlyOwner {
        paused = !paused;
        if (paused) {
            emit Paused(block.timestamp);
        } else {
            emit UnPaused(block.timestamp);
        }
    }

    receive() external payable {
        revert("Contract does not accept ETH");
    }
}
