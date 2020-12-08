pragma solidity ^0.5.0;

import "../MinterRole.sol";

contract MinterRoleMock is MinterRole {
    function addMinter(address account) public onlyMinter {
        _addMinter(account);
    }
    
    function renounceMinter() public {
        _removeMinter(_msgSender());
    }
}
