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
    event payrollPaid(address _sender, uint256 timestamp);
    event BonusesPaid(
        address sender,
        uint256 amount,
        uint256 timestamp,
        address[] bonusPayees
    );
    event paymentsMapped(address sender, uint256 amount);

    // ============= MAPPINGS ============= //
    mapping(address => uint256) balances;
    mapping(uint256 => Bonuses) bonuses;
    mapping(uint256 => BonusPayee) bonusPayeeList;

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

    // @dev Automated payment loop for all employees
    function directPayment(uint256 _companyId)
        external
        payable
        onlyCompanyOwner(_companyId)
        onlyManager(_companyId)
    {
        Company storage company = companyList[_companyId];
        uint256 paymentRequired = company.payrollSum +
            (company.payrollSum / percentageDivision);
        require(msg.value > paymentRequired);
        for (uint256 i; i < company.numOfPayees; i++) {
            uint256 salary = company.payees[i].salary;
            (bool sent, ) = (company.payees[i].account).call{value: salary}("");
            require(sent, "Transfer did not work");
        }
        company.lastPayment = block.timestamp;
        emit payrollPaid(msg.sender, block.timestamp);
    }

    // @dev Failsafe mapping to allow employees to manually withdraw funds
    function paymentMapping(uint256 _companyId)
        external
        payable
        onlyCompanyOwner(_companyId)
        onlyManager(_companyId)
    {
        Company storage company = companyList[_companyId];
        uint256 balanceRequired;
        for (uint256 i; i < company.numOfPayees; i++) {
            uint256 lastPaymentToPayee = company.payees[i].salary;
            uint256 threeWeeksAgo = 86400 * 21;
            if (lastPaymentToPayee < block.timestamp - threeWeeksAgo) {
                uint256 salary = company.payees[i].salary;
                address payee = company.payees[i].account;
                balances[payee] = salary;
                balanceRequired += salary;
            }
        }
        require(
            msg.value >=
                balanceRequired + (balanceRequired / percentageDivision)
        );
        (bool sent, ) = (address(this)).call{value: msg.value}("");
        require(sent, "Transfer did not work");
        company.lastPayment = block.timestamp;
        emit paymentsMapped(msg.sender, msg.value);
    }

    // ================= OWNER BONUS FUNCTIONS ============== //
    function createBonus(uint256 _companyId)
        external
        onlyCompanyOwner(_companyId)
        onlyManager(_companyId)
    {}

    function addBonusPayee(
        uint256 _companyId,
        uint256 _taxBucketId,
        address _address
    )
        external
        onlyCompanyOwner(_companyId)
        onlyManager(_companyId)
        isValidAddress(_address)
        bonusExists(_companyId)
    {
        bonusCounter.increment();
        BonusPayee storage bonusPayee = bonusPayeeList[bonusCounter.current()];
        bonusPayee.account = _address;
        bonusPayee.taxBucket = _taxBucketId;
    }

    function updateBonusStructure(uint256[] _bonusStructure, uint256 _companyId)
        external
        onlyCompanyOwner(_companyId)
        onlyManager(_companyId)
        bonusExists(_companyId)
    {
        Bonuses storage bonus = bonuses[_companyId];
        require(
            _bonusStructure.length == bonus.numOfBonuses,
            "Bonus structure length is incorrect"
        );
        for (uint256 i; i < bonus.numOfBonuses; i++) {
            bonus.bonusPayees[i].bonusPercent = _bonusStructure[i];
        }
    }

    // @dev Payment function for bonuses using the bonus struct
    function payBonuses(uint256 _companyId)
        external
        payable
        onlyCompanyOwner(_companyId)
        onlyManager(_companyId)
        bonusExists(_companyId)
    {
        Bonuses storage bonus = bonuses[_companyId];
        address[] memory bonusArray = new address[](bonus.numOfBonuses);
        for (uint256 i; i < bonus.numOfBonuses; i++) {
            BonusPayee storage payee = bonus.bonusPayees[i];
            uint256 bonusShare = payee.bonusPercent;
            uint256 bonusAmount = (msg.value / 100) * bonusShare;
            (bool sent, ) = (payee.account).call{value: bonusAmount}("");
            require(sent, "Payment did not send");
            bonusArray[i] = payee.account;
        }
        bonus.lastPayment = block.timestamp;
        emit BonusesPaid(msg.sender, msg.value, block.timestamp, bonusArray);
    }

    function bonusMapping() external payable {}

    function directBonus() external payable {}

    // ======== PAYEE FUNCTIONS ======== //
    function withdrawPay(uint256 _companyId) external {}

    // ========= FALLBACKS TO RECEIVE FUNDS ========= //
    receive() external payable {}

    fallback() external payable {}
}
