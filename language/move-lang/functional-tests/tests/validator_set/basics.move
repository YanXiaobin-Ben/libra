//! account: bob, 1000000, 0, validator
//! account: vivian, 1000000, 0, validator
//! account: alice, 0, 0, address

//! new-transaction
script {
use 0x1::LibraSystem;
fun main(account: &signer) {
    LibraSystem::initialize_validator_set(account);
}
}
// check: "Keep(ABORTED { code: 1,"

//! new-transaction
script {
    use 0x1::LibraSystem;
    fun main(account: &signer) {
        LibraSystem::update_config_and_reconfigure(account, {{bob}});
    }
}
// check: "Keep(ABORTED { code: 2051,"

//! new-transaction
//! sender: libraroot
//! args: 0, {{alice}}, {{alice::auth_key}}, b"alice"
stdlib_script::create_validator_operator_account
// check: EXECUTED

//! new-transaction
//! sender: bob
script {
    use 0x1::ValidatorConfig;
    fun main(account: &signer) {
        ValidatorConfig::set_operator(account, 0x0);
    }
}
// check: "Keep(ABORTED { code: 775,"

//! new-transaction
//! sender: bob
script {
    use 0x1::Signer;
    use 0x1::ValidatorConfig;
    fun main(account: &signer) {
        ValidatorConfig::set_operator(account, Signer::address_of(account))
    }
}
// check: "Keep(ABORTED { code: 775,"

//! new-transaction
//! sender: bob
script {
    use 0x1::ValidatorConfig;
    // delegate to alice
    fun main(account: &signer) {
        ValidatorConfig::set_operator(account, {{alice}});
        ValidatorConfig::remove_operator(account);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: bob
script {
    use 0x1::ValidatorConfig;
    fun main(account: &signer) {
        ValidatorConfig::set_config(account, {{vivian}},
                                    x"d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a",
                                    x"", x"", x"", x"");
    }
}
// check: "Keep(ABORTED { code: 263,"

//! new-transaction
//! sender: bob
script {
    use 0x1::ValidatorConfig;
    fun main(account: &signer) {
        ValidatorConfig::set_config(account, {{vivian}}, x"d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a", x"", x"", x"", x"");
    }
}
// check: "Keep(ABORTED { code: 263,"

//! new-transaction
script {
    use 0x1::ValidatorConfig;
    fun main(account: &signer) {
        ValidatorConfig::publish(account, account, x"")
    }
}
// check: "Keep(ABORTED { code: 2,"

//! new-transaction
//! sender: bob
script {
    use 0x1::ValidatorConfig;
    fun main(account: &signer) {
        ValidatorConfig::set_config(account, {{bob}}, x"0000000000000000000000000000000000000000000000000000000000000000", x"", x"", x"", x"");
    }
}
// check: "Keep(ABORTED { code: 519"

//! new-transaction
//! sender: bob
script {
    use 0x1::ValidatorConfig;
    fun main() {
        let _ = ValidatorConfig::get_config({{alice}});
    }
}
// check: "Keep(ABORTED { code: 5,"

//! new-transaction
//! sender: bob
script {
    use 0x1::ValidatorConfig;
    fun main() {
        let config = ValidatorConfig::get_config({{bob}});
        let _ = ValidatorConfig::get_validator_network_identity_pubkey(&config);
        let _ = ValidatorConfig::get_validator_network_address(&config);
    }
}
// check: EXECUTED
