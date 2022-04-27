require 'base64'
require 'async/await'

CONTRACTS_PATH = "data/contracts"
TESTS_DATA_DIR = "spec/data"
ASYNC_OPERATION_TIMEOUT_SECONDS = 5
GIVER_ADDRESS = "0:841288ed3b55d9cdafa806807f02a0ae0c169aa5edfe88a789a6482429756a94"
AMOUNT_FROM_GIVER = 500000000

module AbiVersion
  V1 = "abi_v1"
  V2 = "abi_v2"
end

class TestClient

  def initialize(config: nil)
    @config = config || default_config
  end

  def client_config
    @_client_config ||= TonSdk::ClientConfig.new(config)
  end

  def client_context
    @_client_context ||= TonSdk::ClientContext.new(client_config.to_h.to_json)
  end

  def sign_detached(data:, keys:)
    sign_keys = request(
      "crypto.nacl_sign_keypair_from_secret_key",
      TonSdk::Crypto::ParamsOfNaclSignKeyPairFromSecret.new(secret: keys.secret.dup)
    )
    result = request(
      "crypto.nacl_sign_detached",
      TonSdk::Crypto::ParamsOfNaclSignDetached.new(unsigned: data, secret: sign_keys.secret.dup)
    )
    result.signature
  end

  def request(function_name, params, await: false)
    klass_name = function_name.split(".").first
    method_ = function_name.split(".").last
    klass = Kernel.const_get("TonSdk::#{klass_name.capitalize}")
    puts "#{method_}"
    klass.__send__(method_, client_context.context, params) do |r|
      @response = r
    end
    if await
      sleep 0.1 unless @response
    end

    response = @response
    @response = nil

    return if response.nil?

    if response.success?
      response.result
    else
      response.error.message
    end
  end

  # Workaround for single threaded requests
  def request_no_params(function_name, **args)
    klass_name = function_name.split(".").first
    method_ = function_name.split(".").last
    klass = Kernel.const_get("TonSdk::#{klass_name.capitalize}")
    klass.send(method_, client_context.context, **args) { |r| @response = r }
    response = @response
    @response = nil

    return if response.nil?

    if response.success?
      response.result
    else
      response.error.message
    end
  end

  def generate_sign_keys
    request_no_params(
      "crypto.generate_random_sign_keys",
      is_single_thread_only: true
    )
  end

  def net_process_function(address:, abi:, function_name:, input:, signer:)
    net_process_message(
      TonSdk::Processing::ParamsOfProcessMessage.new(
        message_encode_params: TonSdk::Abi::ParamsOfEncodeMessage.new(
          address: address,
          abi: abi,
          call_set: TonSdk::Abi::CallSet.new(
            header: nil,
            function_name: function_name,
            input: input
          ),
          processing_try_index: nil,
          signer: signer
        ),
        send_events: false
      )
    )
  end

  def encode_message(params)
    request("abi.encode_message", params)
  end

  def net_process_message(params)
    request(
      "processing.process_message",
      params,
      await: true
    )
  end

  def deploy_with_giver_async(params, value)
    msg = request("abi.encode_message", params)

    get_tokens_from_giver_async(msg.address, value)

    net_process_message(
      TonSdk::Processing::ParamsOfProcessMessage.new(
        message_encode_params: params,
        send_events: false
      )
    )

    msg.address
  end

  def get_tokens_from_giver_async(account, value)
    run_result = net_process_function(
      address: giver_address,
      abi: giver_abi,
      function_name: "sendTransaction",
      input: {
        dest: account,
        value: value,
        bounce: false
      },
      signer: TonSdk::Abi::Signer.new(type_: :keys, keys: giver_keys)
    )

    # wait for tokens reception
    request(
      "net.query_transaction_tree",
      TonSdk::Net::ParamsOfQueryTransactionTree.new(
        in_msg: run_result.transaction["in_msg"]
      ),
      await: true
    )
  end

  def calc_giver_address(keys)
    encode_message(
      TonSdk::Abi::ParamsOfEncodeMessage.new(
        abi: giver_abi,
        deploy_set: TonSdk::Abi::DeploySet.new(tvc: load_tvc(name: "GiverV2")),
        signer: TonSdk::Abi::Signer.new(type_: :keys, keys: keys)
      )
    ).address
  end

  def giver_address
    @_giver_address ||= calc_giver_address(giver_keys)
  end

  def giver_abi
    @_giver_abi ||= load_abi(name: "GiverV2")
  end

  def giver_keys
    @_giver_keys ||= TonSdk::Crypto::KeyPair.new(
      public_: "2ada2e65ab8eeab09490e3521415f45b6e42df9c760a639bcf53957550b25a16",
      secret: "172af540e43a524763dd53b26a066d472a97c4de37d5498170564510608250c3"
    )
  end

  # pub(crate) async fn deploy_with_giver_async(
  #                       &self,
  # params: ParamsOfEncodeMessage,
  #   value: Option<u64>,
  # ) -> String {
  #   let msg = self.encode_message(params.clone()).await.unwrap();
  #
  #   self.get_tokens_from_giver_async(&msg.address, value).await;
  #
  #   let _ = self
  #     .net_process_message(
  #       ParamsOfProcessMessage {
  #         message_encode_params: params,
  #           send_events: false,
  #       },
  #       Self::default_callback,
  #       )
  #     .await
  #     .unwrap();
  #
  #   msg.address
  # }

  def self.abi(name:)
    self.new(
      config: {
        abi: load_abi(name: name)
      }
    )
  end

  private

  attr_reader :config

  def default_config
    {
      network: TonSdk::NetworkConfig.new(
        endpoints: ["http://tonos"]
        #endpoints: ["net.ton.dev"]
      )
    }
  end
end

def test_client
  @_test_client ||= TestClient.new
end

def get_now_for_async_operation = Process.clock_gettime(Process::CLOCK_MONOTONIC)

def get_timeout_for_async_operation = Process.clock_gettime(Process::CLOCK_MONOTONIC) + ASYNC_OPERATION_TIMEOUT_SECONDS

def load_abi(name:, version: AbiVersion::V2)
  cont_json = File.read("#{TESTS_DATA_DIR}/contracts/#{version}/#{name}.abi.json")
  TonSdk::Abi::Abi.new(
    type_: :contract,
    value: TonSdk::Abi::AbiContract.from_json(JSON.parse(cont_json))
  )
end

def load_tvc(name:, version: AbiVersion::V2)
  tvc_cont_bin = IO.binread("#{TESTS_DATA_DIR}/contracts/#{version}/#{name}.tvc")
  Base64::strict_encode64(tvc_cont_bin)
end

def load_boc(name:)
  Base64.strict_encode64(IO.binread("#{TESTS_DATA_DIR}/boc/#{name}.boc"))
end

def load_icon(name:)
  icon = IO.binread("#{TESTS_DATA_DIR}/contracts/abi_v2/#{name}.png")
  "data:image/png;base64,#{Base64::strict_encode64(icon)}"
end

def get_grams_from_giver(ctx, to_address)
  abi = load_abi(name: "Giver", version: AbiVersion::V1)
  par_enc_msg = TonSdk::Abi::ParamsOfEncodeMessage.new(
    address: GIVER_ADDRESS,
    abi: abi,
    call_set: TonSdk::Abi::CallSet.new(
      function_name: "sendGrams",
      input: {
        dest: to_address,
        amount: AMOUNT_FROM_GIVER
      },
    ),
    signer: TonSdk::Abi::Signer.new(type_: :none)
  )

  params = TonSdk::Processing::ParamsOfProcessMessage.new(
    message_encode_params: par_enc_msg,
    send_events: false
  )

  TonSdk::Processing::process_message(ctx, params) do |res|
    if res.success?
      res.result.out_messages.map do |msg|
        Boc.parse_message(ctx, TonSdk::Boc::ParamsOfParse.new(msg))
      end
    else
      raise TonSdk::SdkError.new(message: res.error.message)
    end
  end
end
