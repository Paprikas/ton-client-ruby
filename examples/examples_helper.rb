require 'base64'
require_relative '../lib/ton_sdk_client.rb'

PRINT_RESULT_MAX_LEN = 500
EXAMPLES_DATA_DIR = "examples/data"

def cut_off_long_string(s)
  s2 = s[0..PRINT_RESULT_MAX_LEN]
  "#{s2} ...<cut off>"
end

def load_abi(name)
  cont_json = File.read("./data/contracts/abi_v2/#{name}.abi.json")
  TonSdk::Abi::Abi.new(
    type_: :contract,
    value: TonSdk::Abi::AbiContract.from_json(JSON.parse(cont_json))
  )
end

def load_tvc(name)
  tvc_cont_bin = IO.binread("./data/contracts/abi_v2/#{name}.tvc")
  Base64::strict_encode64(tvc_cont_bin)
end

cfg = TonSdk::ClientConfig.new(
  network: TonSdk::NetworkConfig.new(
    endpoints: ["net.ton.dev"]
  )
)
@c_ctx = TonSdk::ClientContext.new(cfg.to_h.to_json)

graphql_cfg = TonSdk::ClientConfig.new(
  network: TonSdk::NetworkConfig.new(
    endpoints: ["net.ton.dev/graphql"]
  )
)
@graphql_c_ctx = TonSdk::ClientContext.new(graphql_cfg.to_h.to_json)
