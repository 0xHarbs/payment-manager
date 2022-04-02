//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CompanyFactory is Ownable {
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
    modifier onlyAdmin() {
        require(contractAdmins[msg.sender]);
        _;
    }

    modifier onlyCompanyOwner(uint256 companyId) {
        require(companyList[companyId].owner == msg.sender);
        _;
    }

    modifier onlyManager(uint256 companyId) {
        require(companyList[companyId].manager == msg.sender);
        _;
    }

    modifier isValidAddress(address _address) {
        require(_address != address(0));
        require(!isContract(_address));
        _;
    }

    // ========== MAPPINGS ======= //
    mapping(uint256 => Company) public companyList;
    mapping(uint256 => Payee) public payeeList;
    mapping(uint256 => TaxBucket) public taxBucketList;
    mapping(uint256 => TaxDeductions) public taxDeductionList;
    mapping(address => bool) private contractAdmins;

    constructor() {}

    // ============ ADMIN FUNCTIONS ============ //
    function addAdmin(address _address) external onlyOwner onlyAdmin {
        adminCount.increment();
        contractAdmins[_address] = true;
    }

    function removeAdmin(address _address) external onlyOwner onlyAdmin {
        adminCount.decrement();
        contractAdmins[_address] = false;
    }

    function createTaxBucket(
        string memory _domicileName,
        string memory _description,
        uint256[] memory _deductionIds
    ) external onlyOwner onlyAdmin {
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
    ) external onlyOwner onlyAdmin {
        TaxBucket storage taxBucket = taxBucketList[_bucketId];
        taxBucket.countryOfDomicile = _domicileName;
        taxBucket.description = _description;
        taxBucket.taxDeductions = _deductionIds;
    }

    function flipStateTaxBucket(uint256 _bucketId)
        external
        onlyOwner
        onlyAdmin
    {
        taxBucketList[_bucketId].approved = !taxBucketList[_bucketId].approved;
    }

    function createTaxDeductions(
        string memory _deductionName,
        string memory _description,
        uint256 _deduction,
        DeductionType _deductionType,
        Due _due
    ) external onlyOwner onlyAdmin {
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

    function flipStateTaxDeductions(uint256 _deductionId)
        external
        onlyOwner
        onlyAdmin
    {
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
    )
        external
        onlyCompanyOwner(_companyId)
        onlyManager(_companyId)
        isValidAddress(_address)
    {
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
    ) external onlyCompanyOwner(_companyId) onlyManager(_companyId) {
        Company storage company = companyList[_companyId];
        bool foundPayee;

        for (uint256 i; i < company.numOfPayees; i++) {
            if (company.payees[i].account == _address) {
                foundPayee = true;
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
        onlyCompanyOwner(_companyId)
        onlyManager(_companyId)
    {
        Company storage company = companyList[_companyId];
        bool foundPayee;

        for (uint256 i; i < company.numOfPayees - 1; i++) {
            if (company.payees[i].account == _address) {
                foundPayee = true;
                company.payrollSum -= company.payees[i].salary;
                company.payees[i] = company.payees[company.numOfPayees];
                delete company.payees[company.numOfPayees];
                company.numOfPayees -= 1;
                break;
            }
        }
        require(foundPayee, "Payee not found at your company");
    }

    // @dev Lets owner change the manager of the company
    function setManager(uint256 _companyId, address _manager)
        external
        onlyCompanyOwner(_companyId)
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
        onlyCompanyOwner(_companyId)
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
}
