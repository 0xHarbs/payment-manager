//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";

// CONTRACT INTERFACE STRUCTURE NEEDS TO BE BUILT TO LINK THIS!!
contract TaxManager {
    using Counters for Counters.Counter;
    Counters.Counter public taxBucketCount;
    Counters.Counter public taxDeductionCount;
    Counters.Counter public adminCount;

    // ============== STRUCTS & ENUMS ======== //
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

    // =============== MODIFIERS ========= //
    modifier onlyAdmins() {
        require(contractAdmins[msg.sender], "You are not a contract admin");
        _;
    }

    // =================== MAPPINGS ============ //
    mapping(uint256 => TaxBucket) public taxBucketList;
    mapping(uint256 => TaxDeductions) public taxDeductionList;
    mapping(address => bool) private contractAdmins;

    constructor() {
        contractAdmins[msg.sender] = true;
    }

    // ========== ADMIN FUNCTIONS ============== //
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

    // =================== PUBLIC FUNCTIONS ================ //
    function deductTaxes() external {}
}
