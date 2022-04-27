require 'spec_helper'

TEST_DEBOT = "testDebot"
TEST_DEBOT_TARGET = "testDebotTarget"

DebotData = TonSdk::KwStruct.new(:debot_addr, :target_addr, :keys, :abi)

def init_simple_debot(name)
  keys = test_client.generate_sign_keys
  debot_abi = load_abi(name: name)
  signer = TonSdk::Abi::Signer.new(type_: :keys, keys: keys)
  deploy_debot_params = TonSdk::Abi::ParamsOfEncodeMessage.new(
    abi: debot_abi,
    deploy_set: TonSdk::Abi::DeploySet.new(tvc: load_tvc(name: name)),
    signer: signer,
    processing_try_index: nil,
    address: nil,
    call_set: TonSdk::Abi::CallSet.new(function_name: "constructor")
  )

  debot_addr = test_client.deploy_with_giver_async(deploy_debot_params, 100_000_000_000)

  test_client.net_process_function(
    address: debot_addr,
    abi: debot_abi,
    function_name: "setABI",
    input: {"dabi": debot_abi.to_h.to_json.unpack("H*")[0].upcase},
    signer: signer
  )

  DebotData.new(
    debot_addr: debot_addr,
    target_addr: "",
    keys: keys,
    abi: debot_abi
  )
end

#
# def init_debot
#   keys = test_client.request_no_params(
#     "crypto.generate_random_sign_keys",
#     is_single_thread_only: true
#   )
#
#   target_abi = load_abi(name: TEST_DEBOT_TARGET)
#   debot_abi = load_abi(name: TEST_DEBOT)
#
#   target_deploy_params = TonSdk::Abi::ParamsOfEncodeMessage.new(
#     abi: target_abi,
#     deploy_set: TonSdk::Abi::DeploySet.new(
#       tvc: load_tvc(name: TEST_DEBOT_TARGET)
#     ),
#     signer: TonSdk::Abi::Signer.new(
#       type_: :keys,
#       keys: keys
#     ),
#     processing_try_index: nil,
#     address: nil,
#     call_set: TonSdk::Abi::CallSet.new(
#       function_name: "constructor"
#     )
#   )
#
#   target_addr = test_client.request(
#     "abi.encode_message",
#     target_deploy_params
#   )
#
#   target_future = test_client.deploy_with_giver_async(
#     TonSdk::Abi::ParamsOfEncodeMessage.new(
#       abi: target_abi,
#       deploy_set: TonSdk::Abi::DeploySet.new(
#         tvc: load_tvc(name: TEST_DEBOT_TARGET)
#       ),
#       signer: TonSdk::Abi::Signer.new(
#         type_: :keys,
#         keys: keys
#       ),
#       processing_try_index: nil,
#       address: nil,
#       call_set: TonSdk::Abi::CallSet.new(
#         function_name: "constructor"
#       )
#     )
#   )
#
#   debot_future = test_client.deploy_with_giver_async(
#     TonSdk::Abi::ParamsOfEncodeMessage.new(
#       abi: debot_abi,
#       deploy_set: TonSdk::Abi::DeploySet.new(
#         tvc: load_tvc(name: TEST_DEBOT)
#       ),
#       signer: TonSdk::Abi::Signer.new(
#         type_: :keys,
#         keys: keys
#       ),
#       processing_try_index: nil,
#       address: nil,
#       call_set: TonSdk::Abi::CallSet.new(
#         function_name: "constructor",
#         header: nil,
#         input: nil
#       )
#     )
#   )
#
#   {
#     targetAbi: target_abi,
#     targetAddr: target_addr
#   }
#
#   binding.irb
#
# end

# async fn init_debot(client: Arc<TestClient>) -> DebotData {
#   let mut debot = DEBOT.lock().await;
#
#   if let Some(data) = &*debot {
#     return data.clone();
#   }
#
#   let target_addr = client.encode_message(target_deploy_params.clone()).await.unwrap().address;
#
#   let debot_future = client.deploy_with_giver_async(ParamsOfEncodeMessage {
#     abi: debot_abi.clone(),
#       deploy_set: Some(DeploySet {
#       tvc: TestClient::tvc(TEST_DEBOT, Some(2)),
#         ..Default::default()
#     }),
#       signer: Signer::Keys { keys: keys.clone() },
#       processing_try_index: None,
#       address: None,
#       call_set: Some(CallSet {
#       function_name: "constructor".to_owned(),
#         header: None,
#         input: Some(json!({
#                             "targetAbi": hex::encode(&target_abi.json_string().unwrap().as_bytes()),
#                             "targetAddr": target_addr,
#                           }))
#     }),
#   },
#                                                     None
#   );
#
#   let (_, debot_addr) = futures::join!(target_future, debot_future);
#
#   let _ = client.net_process_function(
#     debot_addr.clone(),
#     debot_abi.clone(),
#     "setAbi",
#     json!({
#             "debotAbi": hex::encode(&debot_abi.json_string().unwrap().as_bytes())
#           }),
#     Signer::None,
#     ).await.unwrap();
#
#   let data = DebotData {
#     debot_addr,
#       target_addr,
#       keys,
#       abi: debot_abi.json_string().unwrap(),
#   };
#   *debot = Some(data.clone());
#   data
#   }


def init_hello_debot
  data = init_simple_debot("helloDebot")

  test_client.net_process_function(
    address: data.debot_addr,
    abi: data.abi,
    function_name: "setIcon",
    input: {
      "icon": load_icon(name: "helloDebot").unpack("H*")[0]
    },
    signer: TonSdk::Abi::Signer.new(type_: :keys, keys: data.keys)
  )

  data
end

describe TonSdk::Debot do
  context "init" do
    it "checks" do
      debot = init_hello_debot

      response = test_client.request(
        "debot.init",
        TonSdk::Debot::ParamsOfInit.new(
          address: debot.debot_addr
        ),
        await: true
      )

      expect(response).to eq("")
    end

    it "start" do
      debot = init_hello_debot

      response = test_client.request(
        "debot.init",
        TonSdk::Debot::ParamsOfInit.new(
          address: debot.debot_addr
        ),
        await: true
      )

      puts "addR: #{debot.debot_addr}"

      sleep 3

      response = test_client.request(
        "debot.start",
        TonSdk::Debot::ParamsOfStart.new(
          debot_handle: response.debot_handle
        ),
        await: true
      )

      puts response

      # Last exec "Debot start failed: Invalid parameter"

      # expect(response).to eq("")
    end

    it "fetch" do
      debot = init_hello_debot

      response = test_client.request(
        "debot.fetch",
        TonSdk::Debot::ParamsOfFetch.new(
          address: debot.debot_addr
        ),
        await: true
      )

      expect(response.dabi_version).to eq("2.0")
    end

    it "execute" do
      debot = init_hello_debot

      response = test_client.request(
        "debot.init",
        TonSdk::Debot::ParamsOfInit.new(
          address: debot.debot_addr
        ),
        await: true
      )

      sleep 3

      # response = test_client.request(
      #   "debot.execute",
      #   TonSdk::Debot::ParamsOfExecute.new(
      #     debot_handle: response.rebot_handle,
      #     action: TonSdk::
      #   ),
      #   await: true
      # )
    end

    fit "remove" do
      debot = init_hello_debot

      response = test_client.request(
        "debot.init",
        TonSdk::Debot::ParamsOfInit.new(
          address: debot.debot_addr
        ),
        await: true
      )

      sleep 3

      response = test_client.request(
        "debot.execute",
        TonSdk::Debot::ParamsOfRemove.new(
          debot_handle: response.rebot_handle
        ),
        await: true
      )

      puts "response"
    end
  end


  context "init2" do
    it "test_debot_getinfo" do

    end

    it ""

    xit "asd" do
      debot = data
      puts "addr #{debot.debot_addr}"
      debot_info = test_client.request(
        "debot.fetch",
        TonSdk::Debot::ParamsOfFetch.new(
          address: debot.debot_addr
        ),
        await: true
      )
      puts "INFO"
      puts debot_info
    end
  end
end
