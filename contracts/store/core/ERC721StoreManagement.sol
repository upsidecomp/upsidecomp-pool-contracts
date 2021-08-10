// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract ERC721StoreManagement is Initializable {
    address private _manager;

    function initialize (
      address manager
    ) public initializer {
        _manager = manager;
    }

    modifier onlyManager(address manager) {
        require(manager == _manager, "not manager");
        _;
    }
}
