//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CompanyFactory.sol";

contract PaymentManager is CompanyFactory {
    using Counters for Counters.Counter;

    uint256 percentageDivision = 100;
    Counters.Counter public bonusCounter;

    // ========= Structs ========== //
    struct Bonuses {
        uint256 lastPayment;
        uint256 numOfBonuses;
        BonusPayee[] bonusPayees;
    }

    struct BonusPayee {
        uint256 id;
        uint256 lastBonus;
        uint256 taxBucket;
        uint8 bonusPercent;
        address account;
    }

    // ============ EVENTS =========== //
    event paymentsMapped(address sender, uint256 amount);
    event BonusesMapped(
        address sender,
        uint256 amount,
        uint256 timestamp,
        address[] bonusPayees
    );

    // ============= MAPPINGS ============= //
    mapping(address => uint256) balances;
    mapping(uint256 => Bonuses) public bonuses;
    mapping(uint256 => BonusPayee) public bonusPayeeList;

    // ========== MODIFIERS ============== //
    modifier bonusExists(uint256 companyId) {
        require(
            bonuses[companyId].lastPayment != 0,
            "Bonus structure does not exist for this company"
        );
        _;
    }

    constructor() {}

    // =========== OWNER PAYMENT FUNCTIONS ======== ///

    // @dev Mapping to allow employees to manually withdraw funds - for large companies
    function paymentMapping(uint256 _companyId)
        external
        payable
        onlyCompanyAdmins(_companyId)
    {
        Company storage company = companyList[_companyId];
        require(msg.value >= company.payrollSum);
        (bool sent, ) = (address(this)).call{value: msg.value}("");
        require(sent, "Transfer did not work");
        for (uint256 i; i < company.numOfPayees; i++) {
            uint256 salary = company.payees[i].salary;
            address payee = company.payees[i].account;
            balances[payee] += salary;
        }
        company.lastPayment = block.timestamp;
        emit paymentsMapped(msg.sender, msg.value);
    }

    // ================= OWNER BONUS FUNCTIONS ============== //

    // @dev Creating a bonus payee struct and adding it to the Company bonus struct
    function addBonusPayee(
        uint256 _companyId,
        uint256 _taxBucketId,
        address _address
    ) external onlyCompanyAdmins(_companyId) isValidAddress(_address) {
        Bonuses storage bonus = bonuses[_companyId];
        bonusCounter.increment();
        BonusPayee storage bonusPayee = bonusPayeeList[bonusCounter.current()];
        bonusPayee.id = bonusCounter.current();
        bonusPayee.account = _address;
        bonusPayee.taxBucket = _taxBucketId;

        bonus.numOfBonuses += 1;
        bonus.bonusPayees.push(bonusPayee);
        bonus.lastPayment = block.timestamp;
    }

    function removeBonusPayee(address _removeAddress, uint256 _companyId)
        external
        onlyCompanyAdmins(_companyId)
        bonusExists(_companyId)
    {
        require(payeeIsValid(_removeAddress, _companyId), "Payee is not valid");
        Bonuses storage bonus = bonuses[_companyId];
        for (uint256 i; i < bonus.numOfBonuses; i++) {
            console.log(bonus.bonusPayees[i].account);
            if (
                bonus.bonusPayees[i].account == _removeAddress &&
                i != bonus.numOfBonuses - 1
            ) {
                delete bonuses[bonus.bonusPayees[i].id];
                bonus.bonusPayees[i] = bonus.bonusPayees[bonus.numOfBonuses];
                delete bonus.bonusPayees[bonus.numOfBonuses];
                bonus.numOfBonuses -= 1;
                break;
            } else if (bonus.bonusPayees[i].account == _removeAddress) {
                delete bonusPayeeList[bonus.bonusPayees[i].id];
                delete bonus.bonusPayees[i];
                bonus.numOfBonuses -= 1;
                break;
            }
        }
    }

    // @dev Pass in the full bonus structure for a companies list of bonus payees
    function updateBonusStructure(
        uint8[] calldata _bonusStructure,
        uint256 _companyId
    ) external onlyCompanyAdmins(_companyId) bonusExists(_companyId) {
        Bonuses storage bonus = bonuses[_companyId];
        require(
            _bonusStructure.length == bonus.numOfBonuses,
            "Bonus structure length is incorrect"
        );
        for (uint256 i; i < bonus.numOfBonuses; i++) {
            bonus.bonusPayees[i].bonusPercent = _bonusStructure[i];
        }
    }

    // @dev Mapping function for payment for larger teams
    function bonusMapping(uint256 _companyId)
        external
        payable
        onlyCompanyAdmins(_companyId)
        bonusExists((_companyId))
    {
        Bonuses storage bonus = bonuses[_companyId];
        address[] memory bonusArray = new address[](bonus.numOfBonuses);
        (bool sent, ) = (address(this)).call{value: msg.value}("");
        require(sent, "Payment did not send");
        for (uint256 i; i < bonus.numOfBonuses; i++) {
            BonusPayee memory payee = bonus.bonusPayees[i];
            uint256 bonusShare = payee.bonusPercent;
            uint256 bonusAmount = (msg.value / 100) * bonusShare;
            balances[payee.account] += bonusAmount;
            bonusArray[i] = payee.account;
        }
        bonus.lastPayment = block.timestamp;
        emit BonusesMapped(msg.sender, msg.value, block.timestamp, bonusArray);
    }

    // ======== PAYEE FUNCTIONS ======== //

    // @dev Allows the payees to withdraw funds from the mapping
    function withdrawPay(uint256 _companyId, uint256 _amount) external {
        require(payeeIsValid(msg.sender, _companyId));
        require(balances[msg.sender] >= _amount);
        balances[msg.sender] -= _amount;
        (bool sent, ) = (msg.sender).call{value: _amount}("");
        require(sent, "Transaction didn't work");
    }

    // ========= HELPER FUNCTIONS ========= //

    // @dev Checks if a payee is linked to a company
    function payeeIsValid(address _address, uint256 _companyId)
        internal
        view
        returns (bool)
    {
        Company memory company = companyList[_companyId];
        for (uint256 i; i < company.numOfPayees; i++) {
            if (company.payees[i].account == _address) {
                return true;
            }
        }
        return false;
    }

    // ========= FALLBACKS TO RECEIVE FUNDS ========= //
    receive() external payable {}

    fallback() external payable {}
}
