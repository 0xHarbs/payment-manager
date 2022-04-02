//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CompanyFactory {
    address public owner;
    using Counters for Counters.Counter;
    Counters.Counter public numCompanies;
    Counters.Counter public numPayees;
    Counters.Counter public adminCount;
    Counters.Counter public taxBucketCount;
    Counters.Counter public taxDeductionCount;

    // =========== STRUCTS & ENUMS ========= //
    struct Company {
        uint256 companyId;
        string name;
        address owner;
        address manager;
        uint256 numOfPayees;
        uint256 payrollSum;
        uint256 lastPayment;
        Payee[] payees;
    }

    struct Payee {
        uint256 id;
        uint256 taxBucket;
        uint256 salary;
        uint256 lastPayment;
        string name;
        address account;
        bool verifiedTaxBucket;
    }

    struct TaxBucket {
        string countryOfDomicile;
        string description;
        bool approved;
        uint256[] taxDeductions;
    }

    struct TaxDeductions {
        string name;
        string description;
        uint256 deduction;
        bool approved;
        DeductionType deductionType;
        Due due;
    }

    enum Due {
        DAILY,
        WEEKLY,
        FORTNIGHTLY,
        MONTHLY,
        QUARTERLY,
        YEARLY
    }

    enum DeductionType {
        PERCENTAGE,
        VALUE
    }

    // ============= EVENTS ============== //
    event OwnershipChange(
        address previousOwner,
        address newOwner,
        uint256 timestamp
    );

    event ManagerChange(
        address previousManager,
        address newManager,
        uint256 timestamp
    );

    // =============== MODIFIERS ========= //
    modifier onlyAdmins() {
        require(
            contractAdmins[msg.sender] || msg.sender == owner,
            "You are not a contract admin"
        );
        _;
    }

    modifier onlyCompanyAdmins(uint256 companyId) {
        require(
            companyList[companyId].owner == msg.sender ||
                companyList[companyId].manager == msg.sender,
            "You are not a company admin"
        );
        _;
    }

    modifier isValidAddress(address _address) {
        require(_address != address(0), "Address is not correct");
        require(!isContract(_address), "Address can not be a contract");
        _;
    }

    // ========== MAPPINGS ======= //
    mapping(uint256 => Company) public companyList;
    mapping(uint256 => Payee) public payeeList;
    mapping(uint256 => TaxBucket) public taxBucketList;
    mapping(uint256 => TaxDeductions) public taxDeductionList;
    mapping(address => bool) private contractAdmins;

    constructor() {
        owner = msg.sender;
        contractAdmins[msg.sender] = true;
    }

    // ============ ADMIN FUNCTIONS ============ //
    function flipAdminState(address _address) external onlyAdmins {
        contractAdmins[_address] = !contractAdmins[_address];
        if (contractAdmins[_address] == true) {
            adminCount.increment();
        } else {
            adminCount.decrement();
        }
    }

    function createTaxBucket(
        string memory _domicileName,
        string memory _description,
        uint256[] memory _deductionIds
    ) external onlyAdmins {
        taxBucketCount.increment();
        TaxBucket storage taxBucket = taxBucketList[taxBucketCount.current()];
        taxBucket.countryOfDomicile = _domicileName;
        taxBucket.description = _description;
        taxBucket.taxDeductions = _deductionIds;
    }

    function editTaxBucket(
        uint256 _bucketId,
        string memory _domicileName,
        string memory _description,
        uint256[] memory _deductionIds
    ) external onlyAdmins {
        TaxBucket storage taxBucket = taxBucketList[_bucketId];
        taxBucket.countryOfDomicile = _domicileName;
        taxBucket.description = _description;
        taxBucket.taxDeductions = _deductionIds;
    }

    function flipStateTaxBucket(uint256 _bucketId) external onlyAdmins {
        taxBucketList[_bucketId].approved = !taxBucketList[_bucketId].approved;
    }

    function createTaxDeductions(
        string memory _deductionName,
        string memory _description,
        uint256 _deduction,
        DeductionType _deductionType,
        Due _due
    ) external onlyAdmins {
        taxDeductionCount.increment();
        TaxDeductions storage taxDeduction = taxDeductionList[
            taxDeductionCount.current()
        ];
        taxDeduction.name = _deductionName;
        taxDeduction.description = _description;
        taxDeduction.deduction = _deduction;
        taxDeduction.deductionType = _deductionType;
        taxDeduction.due = _due;
    }

    function flipStateTaxDeductions(uint256 _deductionId) external onlyAdmins {
        taxDeductionList[_deductionId].approved = !taxDeductionList[
            _deductionId
        ].approved;
    }

    // ========= COMPANY OWNER FUNCTIONS ======== //
    // @dev Create a company and establishes the owner as sender and manager as input address
    function createCompany(string memory _name, address _manager) external {
        numCompanies.increment();
        Company storage company = companyList[numCompanies.current()];
        company.companyId = numCompanies.current();
        company.name = _name;
        company.owner = msg.sender;
        company.manager = _manager;
    }

    // @dev Function to add payees to Company array
    function addPayees(
        uint256 _companyId,
        uint256 _salary,
        uint256 _taxBucketId,
        string memory _name,
        address _address
    ) external onlyCompanyAdmins(_companyId) isValidAddress(_address) {
        require(
            !addressAlreadyConnected(_address, _companyId),
            "Address is already connected to the company"
        );
        numPayees.increment();
        Payee storage payee = payeeList[numPayees.current()];
        Company storage company = companyList[_companyId];
        payee.id = numPayees.current();
        payee.name = _name;
        payee.account = _address;
        payee.salary = _salary;
        payee.taxBucket = _taxBucketId;
        if (taxBucketList[_taxBucketId].approved) {
            payee.verifiedTaxBucket = true;
        }
        company.payees.push(payee);
        company.numOfPayees += 1;
        company.payrollSum += _salary;
    }

    // @dev Allows owner or manager to edit the salary of a payee
    function editSalary(
        uint256 _companyId,
        address _address,
        uint256 _newSalary
    ) external onlyCompanyAdmins(_companyId) {
        Company storage company = companyList[_companyId];
        bool foundPayee;

        for (uint256 i; i < company.numOfPayees; i++) {
            if (company.payees[i].account == _address) {
                foundPayee = true;
                if (_newSalary > company.payees[i].salary) {
                    uint256 difference = _newSalary - company.payees[i].salary;
                    company.payrollSum += difference;
                } else {
                    uint256 difference = company.payees[i].salary - _newSalary;
                    company.payrollSum -= difference;
                }
                company.payees[i].salary = _newSalary;
                payeeList[company.payees[i].id] = company.payees[i];
                break;
            }
        }
        require(foundPayee, "Payee not found at your company");
    }

    // @dev Removes payee from Company payee array and replaces gap with payee at end of array
    function removePayee(uint256 _companyId, address _address)
        external
        onlyCompanyAdmins(_companyId)
    {
        Company storage company = companyList[_companyId];
        bool foundPayee;

        for (uint256 i; i < company.numOfPayees; i++) {
            if (
                company.payees[i].account == _address && company.numOfPayees > 1
            ) {
                foundPayee = true;
                company.payrollSum -= company.payees[i].salary;
                delete payeeList[company.payees[i].id];
                company.payees[i] = company.payees[company.numOfPayees];
                delete company.payees[company.numOfPayees];
                company.numOfPayees -= 1;
                break;
            } else if (company.payees[i].account == _address) {
                foundPayee = true;
                company.payrollSum -= company.payees[i].salary;
                delete payeeList[company.payees[i].id];
                delete company.payees[i];
                company.numOfPayees -= 1;
                break;
            }
        }
        require(foundPayee, "Payee not found at your company");
    }

    // @dev Lets owner change the manager of the company
    function setManager(uint256 _companyId, address _manager)
        external
        onlyCompanyAdmins(_companyId)
        isValidAddress(_manager)
    {
        Company storage company = companyList[_companyId];
        address previousManager = company.manager;
        company.manager = _manager;
        emit ManagerChange(previousManager, _manager, block.timestamp);
    }

    // @dev Renounces ownership to a valid address that is not a contract
    function renounceOwnership(uint256 _companyId, address _newOwner)
        external
        onlyCompanyAdmins(_companyId)
        isValidAddress(_newOwner)
    {
        Company storage company = companyList[_companyId];
        company.owner = _newOwner;
        emit OwnershipChange(msg.sender, _newOwner, block.timestamp);
    }

    // =========== HELPER FUNCTIONS ===================//
    // @dev Helper function to check if an address is a contract
    function isContract(address _address) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_address)
        }
        return (size > 0);
    }

    function addressAlreadyConnected(address _address, uint256 _companyId)
        internal
        view
        returns (bool)
    {
        for (uint256 i; i < companyList[_companyId].numOfPayees; i++) {
            if (companyList[_companyId].payees[i].account == _address) {
                return true;
            }
        }
        return false;
    }
}
