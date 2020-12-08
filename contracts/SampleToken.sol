/**
 *Submitted for verification at Etherscan.io on 2020-01-22
*/

// File: contracts/PlayXCoin.sol

pragma solidity >=0.5.0;

import "./erc20/ERC20Capped.sol";
import "./erc20/ERC20Detailed.sol";


/**
 * @title NOA contract 
 */
contract NOAToken is ERC20Capped, ERC20Detailed {
    uint noOfTokens = 1000000000; // 1,000,000,000 (1B)    
    
    uint publishedTimeStamp =  0;

    address internal vault;
    address internal owner;
    address internal admin;
    
    address internal sales;
    address internal team;
    address internal adviser;
    address internal bounty;
    address internal partner;
    address internal reserved;

    event OwnerChanged(address indexed previousOwner, address indexed newOwner);
    event VaultChanged(address indexed previousVault, address indexed newVault);
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);
    event ReserveChanged(address indexed _address, uint amount);
    event Recalled(address indexed from, uint amount);

    struct lockup {
        address addr;
        bool isEnabled;
        uint8 rule;
        uint256 withdrawalAmount;
        
        uint totalSupplyLocked;
        uint initialRate;
        uint increaseRate;
    }

    uint8 SALES_RULE    = 0;
    uint8 TEAM_RULE     = 1;
    uint8 ADVISOR_RULE  = 2;
    uint8 PARTNER_RULE  = 3;
    uint8 RESERVE_RULE  = 4;
    uint8 TEST_RULE     = 5;
    
    uint32[10][] times;
    
    mapping(address => uint) private reserves;
    mapping(address => uint) private amountofWithdrawal;
    mapping(address => lockup) private listOfLocked;

    /**
       * modifier to limit access to the owner only
       */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /**
     * initialize ERC20
     *
     * all token will deposit into the vault
     * later, the vault, owner will be multi sign contract to protect privileged operations
     *
     * @param _symbol token symbol
     * @param _name   token name
     * @param _owner  owner address
     * @param _admin  admin address
     * @param _vault  vault address
     *
     * Cap the mintable amount to 1,000,000,000
     *
     */
    
    constructor (string memory _symbol, string memory _name, address _owner,
        address _admin, address _vault) ERC20Detailed(_name, _symbol, 9) ERC20Capped(1000000000000000000)
    public {
        require(bytes(_symbol).length > 0);
        require(bytes(_name).length > 0);

        owner = _owner;
        admin = _admin;
        vault = _vault;

        // mint coins to the vault
        _mint(vault, noOfTokens * (10 ** uint(decimals())));

        times.push([
            // Sales
            1 minutes, 90 days, 180 days,  270 days, 360 days, 
            450 days, 540 days, 630 days, 720 days, 810 days
        ]);
        
        times.push([
            // Team
            180 days, 270 days, 360 days, 450 days, 540 days, 
            630 days, 720 days, 810 days, 900 days, 990 days
        ]);
        
        times.push([
            // Advisor
            150 days, 240 days, 330 days, 420 days, 510 days, 
            600 days, 690 days, 780 days, 870 days, 960 days
        ]);
        
        times.push([
            // Partner
            150 days, 240 days, 330 days, 420 days, 510 days, 
            600 days, 690 days, 780 days, 870 days, 960 days
        ]);
        
        times.push([
            // Reserve
            365 days,  730 days, 1460 days, 2190 days, 2920 days, 
            3650 days, 4380 days, 4380 days, 4380 days, 4380 days
        ]);

        publishedTimeStamp =  block.timestamp;
    }

    function releasedTokenAmount(address targetAddr) public view returns (uint256) {
        uint256 p = 0;
        uint utcNow = now;
        uint k = 0;
        for(k = 0 ; k < times.length ; k++) {
            uint8 id = listOfLocked[targetAddr].rule;
            uint32[10] memory lockupTable = times[id];
                
            if( (utcNow - publishedTimeStamp) >= lockupTable[k] ) {
                p = listOfLocked[targetAddr].initialRate + (k* listOfLocked[targetAddr].increaseRate);
            } else {
                break;
            }
        }
        
        p = (p > 100 ? 100 : p);
        return (uint(listOfLocked[targetAddr].totalSupplyLocked) /  100) * p;
    }
    
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(_from != vault);
        require(_value <= balanceOf(_from).sub(reserves[_from]));
        return super.transferFrom(_from, _to, _value);
    }
    
    function transfer(address _to, uint256 _value) public returns (bool) {
        require(address(msg.sender) != address(_to));
        
        uint spend =  0;
        uint maxiumToken = 0;
        
        if(listOfLocked[msg.sender].addr != address(0) &&
            listOfLocked[msg.sender].addr == address(msg.sender) &&
            listOfLocked[msg.sender].isEnabled == true) {
                
            maxiumToken = releasedTokenAmount(msg.sender);
            if(amountofWithdrawal[msg.sender] > 0) {
                spend = amountofWithdrawal[msg.sender];
            }
            require(maxiumToken >= _value + spend);
        }
        
        amountofWithdrawal[msg.sender] =  amountofWithdrawal[msg.sender] + _value;
        
        return super.transfer(_to, _value);
    }
    
    function removeLockup(address targetAddr) onlyOwner public returns (bool _result) {
        require(targetAddr != address(0));
        
        if(listOfLocked[targetAddr].isEnabled  == true) { 
            lockup memory item;
            item.isEnabled = false;
            item.totalSupplyLocked = 0;
            item.initialRate = 100;
            item.increaseRate= 0;
            
            listOfLocked[targetAddr] = item;
            
            return true;
        }
        
        return false;
    }
    
    function setLockup(uint8 ruleId, address targetAddr) onlyOwner public {
    
        require(ruleId >= SALES_RULE && ruleId < times.length);
        require(targetAddr != address(0));

        lockup memory item;
        
        item.addr = targetAddr;
        item.rule = ruleId;
        item.withdrawalAmount = 0;
        
        uint256 _totalOfAmount = noOfTokens * (10 ** uint(decimals()));
        if(ruleId == SALES_RULE) { 
            item.isEnabled = true;
            item.totalSupplyLocked = (uint(_totalOfAmount) /  100) * 15;
            item.initialRate = 20;
            item.increaseRate = 10;
        } else if(ruleId == TEAM_RULE) { 
            item.isEnabled = true;
            item.totalSupplyLocked = (uint(_totalOfAmount) /  100) * 16;
            item.initialRate = 20;
            item.increaseRate = 10;
        } else if(ruleId == ADVISOR_RULE) { 
            item.isEnabled = true;
            item.totalSupplyLocked = (uint(_totalOfAmount) /  100) * 5;
            item.initialRate = 20;
            item.increaseRate = 10;
        } else if(ruleId == PARTNER_RULE) { 
            item.isEnabled = true;
            item.totalSupplyLocked = (uint(_totalOfAmount) /  100) * 10;
            item.initialRate = 20;
            item.increaseRate = 10;
        } else if(ruleId == RESERVE_RULE) { 
            item.isEnabled = true;
            item.totalSupplyLocked = (uint(_totalOfAmount) /  100) * 50;
            item.initialRate = 20;
            item.increaseRate = 20;
        } 
        
        listOfLocked[targetAddr] = item;
    }
    
    function getPublishedTimeStamp() public view returns (uint _result) {
        return (now - publishedTimeStamp);
    }
    
    function withdrawalOf(address _address) public view returns (uint _reserve) {
        return amountofWithdrawal[_address];
    }

    // for audit
    function getLockInfo(address targetAddr) public view returns (address _addr, bool _isEnabled, uint8 _rule, uint256 _withdrawalAmount, uint _totalSupplyLocked, uint _initialRate, uint _increaseRate) {
        return (
            listOfLocked[targetAddr].addr,
            listOfLocked[targetAddr].isEnabled,
            listOfLocked[targetAddr].rule,
            listOfLocked[targetAddr].withdrawalAmount,
            listOfLocked[targetAddr].totalSupplyLocked,
            listOfLocked[targetAddr].initialRate,
            listOfLocked[targetAddr].increaseRate
        );
    }
}
