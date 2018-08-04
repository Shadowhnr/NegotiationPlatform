pragma solidity ^0.4.24;

import "./ownable.sol";

    contract NegotiationPlatform is Ownable
    {
        struct Option
        {
            string asset;
            string optionType;
            uint256 expirationDate;
            uint256 strike;
            uint256 knockType; // knockType = 0 -> vanilla, knockType = 1 -> knockin, knockType = 2  -> knockout
            uint256 knockValue;
        }
        
        struct PendingTransfer
        {
            uint optionId;
            address from;
            uint count;
            uint price;
            string transferType;
        }
        
        mapping (address => uint256) public balances;
        mapping (address => mapping(uint => mapping(address => uint))) ownerToOptions;
        mapping (address => PendingTransfer[]) pendingTransfers;
        
        Option[] public options;
        modifier validOption(uint id)
        {
            require(id >= 0 && id < options.length);
            _;
        }
        function registerOption(string asset,string optionType, uint256 expirationDate,uint256 strike) onlyOwner public
        {
            require(keccak256(abi.encodePacked(asset))==keccak256("DOL") &&(keccak256(abi.encodePacked(optionType)) == keccak256("call") 
                    ||keccak256(abi.encodePacked(optionType)) == keccak256("put")) &&
                    expirationDate >= now && strike >= 0 && strike <= 2**52);
            options.push(Option(asset,optionType,expirationDate,strike,0,0));
        }
        function registerExoticOption(string asset,string optionType, uint256 expirationDate,uint256 strike,uint knockType, uint knockValue) public
        {
            require(keccak256(abi.encodePacked(asset))==keccak256("DOL") &&(keccak256(abi.encodePacked(optionType)) == keccak256("call") 
                    ||keccak256(abi.encodePacked(optionType)) == keccak256("put")) &&
                    expirationDate >= now && strike >= 0 && strike <= 2**52 && 
                    (knockType==0 || knockType==1 || knockType==2) &&
                    knockValue>=0 && knockValue <= 2**52);
            options.push(Option(asset,optionType,expirationDate,strike,knockType,knockValue));
        }
        function consultAvailableOptions(uint pos) public validOption(pos) returns (string,string,uint,uint,uint,uint)
        {
            Option storage option = options[pos];
            return (option.asset,option.optionType,option.expirationDate,option.strike,option.knockType,option.knockValue);
        }
        function buyOptions(uint optionId,address from, uint numberOfOptions, uint optionPrice) public validOption(optionId)
        {
            require(balances[msg.sender] >= numberOfOptions*optionPrice);
            pendingTransfers[from].push(PendingTransfer(optionId,msg.sender,numberOfOptions,numberOfOptions*optionPrice,"buy"));
        }
        function sellOptions(uint optionId,address from,uint numberOfOptions, uint optionPrice) public validOption(optionId)
        {
            pendingTransfers[from].push(PendingTransfer(optionId,msg.sender,numberOfOptions,numberOfOptions*optionPrice,"sell"));
        }
        function getPosition(uint optionId,address from) validOption(optionId) public returns 
        (string,string,uint,uint,uint)
        {
            return (options[optionId].asset,
                    options[optionId].optionType,
                    options[optionId].expirationDate,
                    options[optionId].strike,
                    ownerToOptions[msg.sender][optionId][from]);
        }
        function getBalance() public returns (uint)
        {
            return balances[msg.sender];
        }
        // ptax >= knock_out -> kill option
        function exertOption(uint optionId,address from,uint quantity,uint ptaxTax) validOption(optionId) public 
        {
            if(keccak256(abi.encodePacked(options[optionId].optionType))==keccak256("call"))
            {
                //knockout
                if(options[optionId].expirationDate < now || (options[optionId].knockType == 2 
                   && options[optionId].knockValue < ptaxTax))
                {
                    ownerToOptions[msg.sender][optionId][from] = 0;
                }
                //knockin
                if((options[optionId].knockType == 1
                   && options[optionId].knockValue > ptaxTax))
                {
                    options[optionId].knockType=0;
                }
            }
            else if(keccak256(abi.encodePacked(options[optionId].optionType))==keccak256("put"))
            {
                //knockout
                if(options[optionId].expirationDate < now || (options[optionId].knockType == 2 
                   && options[optionId].knockValue > ptaxTax))
                {
                    ownerToOptions[msg.sender][optionId][from] = 0;
                }
                //knockin
                if((options[optionId].knockType == 1
                   && options[optionId].knockValue < ptaxTax))
                {
                    options[optionId].knockType=0;
                }
            }
            require(ownerToOptions[msg.sender][optionId][from] >= quantity &&
                    options[optionId].expirationDate>=now);
            if(keccak256(abi.encodePacked(options[optionId].optionType))==keccak256("call"))
            {
                require(balances[msg.sender] >= ptaxTax);
                balances[msg.sender] -= (options[optionId].strike - ptaxTax)*quantity;
                balances[from] += (options[optionId].strike - ptaxTax)*quantity;
                ownerToOptions[msg.sender][optionId][from]-= quantity;
            }
            else if(keccak256(abi.encodePacked(options[optionId].optionType))==keccak256("put"))
            {
                balances[msg.sender] += (options[optionId].strike - ptaxTax)*quantity;
                balances[from] -= (options[optionId].strike - ptaxTax)*quantity;
                ownerToOptions[msg.sender][optionId][from] -= quantity;
            }
            //knockin
            if (options[optionId].knockType == 1 
               && options[optionId].knockValue > ptaxTax)
            {
                options[optionId].knockType = 0;
            }
        }
        function getPendingTransfer(uint pos) public returns
        (uint,
         address,
         uint,
         uint,
         string)
        {
            require(pos>=0 && pos < pendingTransfers[msg.sender].length);
            return (pendingTransfers[msg.sender][pos].optionId,
                    pendingTransfers[msg.sender][pos].from,
                    pendingTransfers[msg.sender][pos].count,
                    pendingTransfers[msg.sender][pos].price,
                    pendingTransfers[msg.sender][pos].transferType);
        }
        function approvePendingTransfer(uint pos) public
        {
            require(pos>=0 && pos < pendingTransfers[msg.sender].length);
            if(keccak256(abi.encodePacked(pendingTransfers[msg.sender][pos].transferType))
               == keccak256("buy"))
            {
               require(balances[pendingTransfers[msg.sender][pos].from] >=  pendingTransfers[msg.sender][pos].price);
               balances[pendingTransfers[msg.sender][pos].from] -=  pendingTransfers[msg.sender][pos].price;
               balances[msg.sender] +=  pendingTransfers[msg.sender][pos].price;
                  
            }
            else if(keccak256(abi.encodePacked(pendingTransfers[msg.sender][pos].transferType))
                    == keccak256("sell"))
            {
               require(balances[msg.sender] >=  pendingTransfers[msg.sender][pos].price);
               balances[pendingTransfers[msg.sender][pos].from] +=  pendingTransfers[msg.sender][pos].price;
               balances[msg.sender] -=  pendingTransfers[msg.sender][pos].price;
            }
            ownerToOptions[msg.sender][ pendingTransfers[msg.sender][pos].optionId][ pendingTransfers[msg.sender][pos].from] -=  pendingTransfers[msg.sender][pos].count;
            ownerToOptions[ pendingTransfers[msg.sender][pos].from][ pendingTransfers[msg.sender][pos].optionId][msg.sender] +=  pendingTransfers[msg.sender][pos].count;
            _deletePendingTransfer(pos);
        }
        function _deletePendingTransfer(uint pos) private
        {
            for (uint i = pos; i < pendingTransfers[msg.sender].length-1; i++)
            {
                pendingTransfers[msg.sender][i] = pendingTransfers[msg.sender][i+1];
            }
            pendingTransfers[msg.sender].length--;
        }
    }