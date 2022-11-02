pragma solidity 0.5.11;

import "./AdminControl.sol";
import "./SponsorWhitelistControl.sol";

contract InternalContractsHandler {
    // internal contracts
    SponsorWhitelistControl public constant SPONSOR = SponsorWhitelistControl(
        address(0x0888000000000000000000000000000000000001)
    );

    AdminControl public constant adminControl = AdminControl(
        address(0x0888000000000000000000000000000000000000)
    );

    constructor() public {
        // register all users as sponsees
        address[] memory users = new address[](1);
        users[0] = address(0);
        SPONSOR.addPrivilege(users);

        // remove contract admin
        adminControl.setAdmin(address(this), address(0));
        require(
            adminControl.getAdmin(address(this)) == address(0),
            "require admin == null"
        );
    }
}
