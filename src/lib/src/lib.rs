#[macro_use]
extern crate lazy_static;

use std::cell::RefCell;
use std::sync::{Arc, Mutex};

use base64::{decode, encode};
use bip39::{Language, Mnemonic};
use rand::{rngs::OsRng, Rng};

extern crate serde;
#[macro_use]
extern crate serde_json;
extern crate serde_derive;
use serde_derive::Deserialize;

use zcash_primitives::consensus::{BlockHeight, NetworkUpgrade};
use zecwalletlitelib::{
    commands,
    lightclient::{lightclient_config::LightClientConfig, LightClient},
    MainNetwork, Parameters,
};


#[derive(Deserialize, Clone)]
pub struct JsAddressParameters {
    pub coin_type: String,
    pub hrp_sapling_extended_spending_key: String,
    pub hrp_sapling_extended_full_viewing_key: String,
    pub hrp_sapling_payment_address: String,
    #[serde(with = "hex_serde")]
    pub b58_pubkey_address_prefix: [u8; 2],
    #[serde(with = "hex_serde")]
    pub b58_script_address_prefix: [u8; 2],
}


#[derive(Clone)]
struct CustomParams {
    coin_type: u32,
    hrp_sapling_extended_spending_key: String,
    hrp_sapling_extended_full_viewing_key: String,
    hrp_sapling_payment_address: String,
    b58_pubkey_address_prefix: [u8; 2],
    b58_script_address_prefix: [u8; 2],
}

impl CustomParams {
    fn from_mainnet() -> Self {
        let mainnet = MainNetwork;
        let mut pubkey_prefix = [0u8; 2];
        let mut script_prefix = [0u8; 2];

        let main_pubkey_prefix = mainnet.b58_pubkey_address_prefix();
        if main_pubkey_prefix.len() == 2 {
            pubkey_prefix.copy_from_slice(main_pubkey_prefix);
        }

        let main_script_prefix = mainnet.b58_script_address_prefix();
        if main_script_prefix.len() == 2 {
            script_prefix.copy_from_slice(main_script_prefix);
        }

        CustomParams {
            coin_type: mainnet.coin_type(),
            hrp_sapling_extended_spending_key: mainnet
                .hrp_sapling_extended_spending_key()
                .to_string(),
            hrp_sapling_extended_full_viewing_key: mainnet
                .hrp_sapling_extended_full_viewing_key()
                .to_string(),
            hrp_sapling_payment_address: mainnet.hrp_sapling_payment_address().to_string(),
            b58_pubkey_address_prefix: pubkey_prefix,
            b58_script_address_prefix: script_prefix,
        }
    }

    fn from_json(params: &str) -> Option<Self> {
        let js_params: JsAddressParameters = serde_json::from_str(params).ok()?;
        let coin_type: u32 = js_params.coin_type.parse().ok()?;

        if js_params.hrp_sapling_extended_spending_key.is_empty() {
            return None;
        }
        if js_params.hrp_sapling_extended_full_viewing_key.is_empty() {
            return None;
        }
        if js_params.hrp_sapling_payment_address.is_empty() {
            return None;
        }

        Some(CustomParams {
            coin_type,
            hrp_sapling_extended_spending_key: js_params.hrp_sapling_extended_spending_key,
            hrp_sapling_extended_full_viewing_key: js_params.hrp_sapling_extended_full_viewing_key,
            hrp_sapling_payment_address: js_params.hrp_sapling_payment_address,
            b58_pubkey_address_prefix: js_params.b58_pubkey_address_prefix,
            b58_script_address_prefix: js_params.b58_script_address_prefix,
        })
    }
}

impl Parameters for CustomParams {
    fn activation_height(&self, nu: NetworkUpgrade) -> Option<BlockHeight> {
        MainNetwork.activation_height(nu)
    }

    fn coin_type(&self) -> u32 {
        self.coin_type
    }

    fn hrp_sapling_extended_spending_key(&self) -> &str {
        &self.hrp_sapling_extended_spending_key
    }

    fn hrp_sapling_extended_full_viewing_key(&self) -> &str {
        &self.hrp_sapling_extended_full_viewing_key
    }

    fn hrp_sapling_payment_address(&self) -> &str {
        &self.hrp_sapling_payment_address
    }

    fn b58_pubkey_address_prefix(&self) -> &[u8] {
        &self.b58_pubkey_address_prefix
    }

    fn b58_script_address_prefix(&self) -> &[u8] {
        &self.b58_script_address_prefix
    }
}

fn get_address_params(params: &str) -> CustomParams {
    CustomParams::from_json(params).unwrap_or_else(CustomParams::from_mainnet)
}


// We'll use a MUTEX to store a global lightclient instance,
// so we don't have to keep creating it. We need to store it here, in rust
// because we can't return such a complex structure back to JS
lazy_static! {
    static ref LIGHTCLIENT: Mutex<RefCell<Option<Arc<LightClient<CustomParams>>>>> = Mutex::new(RefCell::new(None));
}
pub fn init_new(server_uri: String, params: String, sapling_output_b64: String, sapling_spend_b64: String) -> String {
    let server = LightClientConfig::<CustomParams>::get_server_or_default(Some(server_uri));
    let params = get_address_params(params.as_str());
    let (config, latest_block_height) = match LightClientConfig::create(params, server) {
        Ok((c, h)) => (c, h),
        Err(e) => {
            return format!("Error: {}", e);
        }
    };

    let lightclient = match LightClient::new(&config, latest_block_height) {
        Ok(mut l) => {
            match l.set_sapling_params(&decode(&sapling_output_b64).unwrap(), &decode(&sapling_spend_b64).unwrap()) {
                Ok(_) => l,
                Err(e) => return format!("Error: {}", e)
            }
        },
        Err(e) => {
            return format!("Error: {}", e);
        }
    };

    let seed = match lightclient.do_seed_phrase_sync() {
        Ok(s) => s.dump(),
        Err(e) => {
            return format!("Error: {}", e);
        }
    };

    LIGHTCLIENT.lock().unwrap().replace(Some(Arc::new(lightclient)));

    seed
}

pub fn init_from_seed(server_uri: String, params: String, seed: String, birthday: u64, sapling_output_b64: String, sapling_spend_b64: String) -> String {
    let server = LightClientConfig::<CustomParams>::get_server_or_default(Some(server_uri));
    let params = get_address_params(params.as_str());
    let (config, _latest_block_height) = match LightClientConfig::create(params, server) {
        Ok((c, h)) => (c, h),
        Err(e) => {
            return format!("Error: {}", e);
        }
    };

    let lightclient = match LightClient::new_from_phrase(seed, &config, birthday, false) {
        Ok(mut l) => {
            match l.set_sapling_params(&decode(&sapling_output_b64).unwrap(), &decode(&sapling_spend_b64).unwrap()) {
                Ok(_) => l,
                Err(e) => return format!("Error: {}", e)
            }
        },
        Err(e) => {
            return format!("Error: {}", e);
        }
    };

    let seed = match lightclient.do_seed_phrase_sync() {
        Ok(s) => s.dump(),
        Err(e) => {
            return format!("Error: {}", e);
        }
    };

    LIGHTCLIENT.lock().unwrap().replace(Some(Arc::new(lightclient)));

    seed
}

pub fn init_from_b64(server_uri: String, params: String, base64_data: String, sapling_output_b64: String, sapling_spend_b64: String) -> String {
    let server = LightClientConfig::<CustomParams>::get_server_or_default(Some(server_uri));
    let params = get_address_params(params.as_str());
    let (config, _latest_block_height) = match LightClientConfig::create(params, server) {
        Ok((c, h)) => (c, h),
        Err(e) => {
            let data = json!({
                "initalized": false,
                "error": format!("{}", e)
            });
            return serde_json::to_string(&data).unwrap();
        }
    };

    let decoded_bytes = match decode(&base64_data) {
        Ok(b) => b,
        Err(e) => {
            let data = json!({
                "initalized": false,
                "error": format!("Decoding Base64 {}", e)
            });
            return serde_json::to_string(&data).unwrap();
        }
    };

    let lightclient = match LightClient::read_from_buffer(&config, &decoded_bytes[..]) {
        Ok(mut l) => {
            match l.set_sapling_params(&decode(&sapling_output_b64).unwrap(), &decode(&sapling_spend_b64).unwrap()) {
                Ok(_) => l,
                Err(e) => {
                    let data = json!({
                        "initalized": false,
                        "error": format!("{}", e)
                    });
                    return serde_json::to_string(&data).unwrap();
                }
            }
        },
        Err(e) => {

            let data = json!({
                "initalized": false,
                "error": format!("{}", e)
            });
            return serde_json::to_string(&data).unwrap();
        }
    };

    LIGHTCLIENT.lock().unwrap().replace(Some(Arc::new(lightclient)));

    let data = json!({
        "initalized": true,
        "error": "none"
    });

    serde_json::to_string(&data).unwrap()

}

pub fn save_to_b64() -> String {
    // Return the wallet as a base64 encoded string
    let lightclient: Arc<LightClient<CustomParams>>;
    {
        let lc = LIGHTCLIENT.lock().unwrap();

        if lc.borrow().is_none() {
            return format!("Error: Light Client is not initialized");
        }

        lightclient = lc.borrow().as_ref().unwrap().clone();
    };

    match lightclient.do_save_to_buffer_sync() {
        Ok(buf) => encode(&buf),
        Err(e) => {
            format!("Error: {}", e)
        }
    }
}

pub fn execute(cmd: String, args_list: String) -> String {
    let resp: String;
    {
        let lightclient: Arc<LightClient<CustomParams>>;
        {
            let lc = LIGHTCLIENT.lock().unwrap();

            if lc.borrow().is_none() {
                return format!("Error: Light Client is not initialized");
            }

            lightclient = lc.borrow().as_ref().unwrap().clone();
        };

        let args = if args_list.is_empty() { vec![] } else { vec![args_list.as_ref()] };
        resp = commands::do_user_command(&cmd, &args, lightclient.as_ref()).clone();
    };

    resp
}

pub fn check_seed_phrase(seed_phrase: &str) ->String {
    match Mnemonic::from_phrase(seed_phrase.to_string(), Language::English) {
        Ok(_) => {
            let data = json!({"checkSeedPhrase": "Ok"});
            return serde_json::to_string(&data).unwrap()
        },
        Err(_) => {
            let data = json!({"checkSeedPhrase": "Error"});
            return serde_json::to_string(&data).unwrap()
        }
    };
}

pub fn get_seed_phrase() -> String {

    let mut seed_bytes = [0u8; 32];
    let mut system_rng = OsRng;
            system_rng.fill(&mut seed_bytes);

    let data = json!({
        "seedPhrase": Mnemonic::from_entropy(&seed_bytes,Language::English,).unwrap().phrase().to_string()
    });

    serde_json::to_string(&data).unwrap()
}

pub fn get_seed_phrase_from_entropy(entropy: &str) -> String {

    let seed_bytes = entropy.as_bytes();

    let data = json!({
        "seedPhrase": Mnemonic::from_entropy(&seed_bytes,Language::English,).unwrap().phrase().to_string()
    });

    serde_json::to_string(&data).unwrap()
}

pub fn get_seed_phrase_from_entropy_b64(entropyb64: &str) -> String {
    
    let seed_bytes = match decode(&entropyb64) {
        Ok(b) => b,
        Err(e) => {
            let data = json!({
                "initalized": false,
                "error": format!("Decoding Base64 {}", e)
            });
            return serde_json::to_string(&data).unwrap();
        }
    };

    let data = json!({
        "seedPhrase": Mnemonic::from_entropy(&seed_bytes,Language::English,).unwrap().phrase().to_string()
    });

    serde_json::to_string(&data).unwrap()
}
