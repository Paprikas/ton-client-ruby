require_relative './examples_helper.rb'

def generate_random_sign_keys
  TonSdk::Crypto.generate_random_sign_keys(@c_ctx.context) do |r|
    @response = r
  end
  sleep 0.1 until @response
  result = @response.success? ? @response.result : @response.error.message
  puts "Error: #{@response.error.message}" unless @response.success?
  @response = nil
  result
end

def encode_message(params)
  TonSdk::Abi::encode_message(@c_ctx.context, params) do |r|
    @response = r
  end
  sleep 0.1 until @response
  result = @response.success? ? @response.result : @response.error.message
  puts "Error: #{@response.error.message}" unless @response.success?
  @response = nil
  result
end

def process_message(params)
  TonSdk::Processing.process_message(@c_ctx.context, params) do |r|
    @response = r
  end
  sleep 0.1 until @response
  result = @response.success? ? @response.result : @response.error.message
  puts "Error: #{@response.error.message}" unless @response.success?
  @response = nil
  result
end

def load_icon(name)
  icon = IO.binread("./data/contracts/abi_v2/#{name}.png")
  "data:image/png;base64,#{Base64::strict_encode64(icon)}"
end

def init_debot
  debot_name = "helloDebot"
  keys = generate_random_sign_keys
  signer = TonSdk::Abi::Signer.new(type_: :keys, keys: keys)
  debot_abi = load_abi(debot_name)
  deploy_set = TonSdk::Abi::DeploySet.new(
    tvc: load_tvc(debot_name)
  )
  call_set = TonSdk::Abi::CallSet.new(function_name: "constructor")
  deploy_debot_params = TonSdk::Abi::ParamsOfEncodeMessage.new(
    abi: debot_abi,
    deploy_set: deploy_set,
    signer: signer,
    processing_try_index: nil,
    address: nil,
    call_set: call_set
  )
  debot_addr = encode_message(deploy_debot_params).address

  # setAbi
  params_of_process_message = TonSdk::Processing::ParamsOfProcessMessage.new(
    message_encode_params: TonSdk::Abi::ParamsOfEncodeMessage.new(
      address: debot_addr,
      abi: debot_abi,
      call_set: TonSdk::Abi::CallSet.new(
        function_name: "setABI",
        input: {
          "dabi": debot_abi.to_h.to_json.unpack("H*")[0].upcase
        }
      ),
      processing_try_index: nil,
      signer: signer
    ),
    send_events: false
  )
  process_message(params_of_process_message)

  # setIcon
  icon = load_icon(debot_name)
  params_of_process_message = TonSdk::Processing::ParamsOfProcessMessage.new(
    message_encode_params: TonSdk::Abi::ParamsOfEncodeMessage.new(
      address: debot_addr,
      abi: debot_abi,
      call_set: TonSdk::Abi::CallSet.new(
        function_name: "setIcon",
        input: {
          "icon": icon.unpack("H*")[0]
        }
      ),
      processing_try_index: nil,
      signer: signer
    ),
    send_events: false
  )
  process_message(params_of_process_message)

  {
    debot_addr: debot_addr,
    keys: keys,
    abi: debot_abi
  }
end

def fetch_debot(params)
  TonSdk::Debot.fetch(@c_ctx.context, params) do |r|
    @response = r
  end
  sleep 0.1 until @response
  result = @response.success? ? @response.result : @response.error.message
  puts "Error: #{@response.error.message}" unless @response.success?
  @response = nil
  result
end

debot = init_debot

params = TonSdk::Debot::ParamsOfFetch.new(
  address: debot[:debot_addr]
)

fetched_debot = fetch_debot(params)
