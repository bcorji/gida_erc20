use starknet::ContractAddress;

#[starknet::interface]
pub trait ierc20<TContractState> {
    fn get_name(self: @TContractState) -> felt252;
    // return the name of the token
    fn get_symbol(self: @TContractState) -> felt252;
    // return the symbol of the token
    fn get_decimals(self: @TContractState) -> u8;
    // return the decimals of the token
    fn get_total_supply(self: @TContractState) -> u256;
    // return the total supply of the token
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    // return a specific account's balance of the token
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    // return the amount that the owner of the account gives a dApp (or a smart contract) permission to spend
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256);
    // transfer an amount of the tokens from the caller address to the recipient
    fn transfer_from(
        ref self: TContractState, 
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u256
    );
    // transfer an amount of the tokens from one account (the sender) to another (the recipient)
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256);
    // approve the spending of tokens by a spender
    fn increase_allowance(
        ref self: TContractState, 
        spender: ContractAddress, 
        added_value: u256
    );
    // Add to what a contract or dApp is permitted to spend
    fn decrease_allowance(
        ref self: TContractState, 
        spender: ContractAddress, 
        subtracted_value: u256
    );
    // remove from what a contract or a dApp is allowed to spend
}

#[starknet::contract]
pub mod erc20 {
    use starknet::event::EventEmitter;
use starknet::{
        storage::{
            StoragePointerReadAccess, 
            StoragePointerWriteAccess, 
            StoragePathEntry,
            Map
        }, 
        ContractAddress,
        get_caller_address,
    };
    use core::num::traits::Zero;
    use super::ierc20;

    #[storage]
    pub struct Storage {
        name: felt252,
        symbol: felt252,
        decimals: u8,
        balances: Map::<ContractAddress, u256>,
        allowances: Map::<(ContractAddress, ContractAddress), u256>,
        total_supply: u256
    }


    #[event]
    #[derive(Copy, Drop, starknet::Event)]
    pub enum Event {
        Transfer: Transfer,
        Approval: Approval
    }

    #[derive(Copy, Drop, starknet::Event)]
    pub struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        amount: u256
    }

    #[derive(Copy, Drop, starknet::Event)]
    pub struct Approval {
        owner: ContractAddress,
        spender: ContractAddress,
        amount: u256
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, 
        recipient: ContractAddress, 
        name: felt252, 
        symbol: felt252, 
        decimals: u8, 
        total_supply: u256
    ) {
        self.name.write(name);
        self.symbol.write(symbol);
        self.decimals.write(decimals);
        self.total_supply.write(total_supply);
        self.balances.entry(recipient).write(total_supply);
    }

    #[abi(embed_v0)]
    impl erc20impl of ierc20<ContractState> {
        fn get_name(self: @ContractState) -> felt252 {
            self.name.read()
        }
        fn get_symbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }
        fn get_decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }
        fn get_total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.entry(account).read()
        }
        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            self.allowances.entry((owner, spender)).read()
        }
        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            let owner = get_caller_address();
            assert!(!owner.is_zero(), "Cannot call with zero address");
            assert!(!recipient.is_zero(), "Cannot transfer to zero address");
            let owner_balance = self.balances.entry(owner).read();
            let recipient_balance = self.balances.entry(recipient).read();
            assert!(owner_balance >= amount, "Cannot transfer more than what you have");
            self.balances.entry(owner).write(owner_balance - amount);
            self.balances.entry(recipient).write(recipient_balance + amount);

            self.emit(Transfer { from: owner, to: recipient, amount })
        }
        fn transfer_from(
            ref self: ContractState, 
            sender: ContractAddress, 
            recipient: ContractAddress, 
            amount: u256
        ) {
            assert!(!sender.is_zero(), "Cannot send from zero address");
            assert!(!recipient.is_zero(), "Cannot send to the zero address");
            let current_allowance = self.allowances.entry((sender, recipient)).read();
            let new_allowance = current_allowance - amount;
            self.allowances.entry((sender, recipient)).write(new_allowance);
        }
        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) {
            let owner = get_caller_address();
            assert!(!owner.is_zero(), "Owner should not be zero address");
            assert!(!spender.is_zero(), "Spender should not be zero address");
            self.allowances.entry((owner, spender)).write(amount);
            self.emit(Approval { owner, spender, amount })
        }
        fn increase_allowance(
            ref self: ContractState, 
            spender: ContractAddress, 
            added_value: u256
        ) {
            let owner = get_caller_address();
            assert!(!owner.is_zero(), "Owner should not be zero address");
            assert!(!spender.is_zero(), "Spender should not be zero address");
            let owner_balance = self.balances.entry(owner).read();
            let current_allowance = self.allowances.entry((owner, spender)).read();
            assert!(owner_balance >= added_value, "Cannot increase allowance by more than balance");
            self.balances.entry(owner).write(owner_balance - added_value);
            self.allowances.entry((owner, spender)).write(current_allowance + added_value);
        }
        fn decrease_allowance(
            ref self: ContractState, 
            spender: ContractAddress, 
            subtracted_value: u256
        ) {
            let owner = get_caller_address();
            assert!(!owner.is_zero(), "Owner should not be zero address");
            assert!(!spender.is_zero(), "Spender should not be zero address");
            let owner_balance = self.balances.entry(owner).read();
            let current_allowance = self.allowances.entry((owner, spender)).read();
            assert!(current_allowance >= subtracted_value, "Cannot deduct more than available");
            self.balances.entry(owner).write(owner_balance + subtracted_value);
            self.allowances.entry((owner, spender)).write(current_allowance - subtracted_value);
        }
    }
}