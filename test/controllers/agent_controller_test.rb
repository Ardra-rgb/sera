require "test_helper"

class AgentControllerTest < ActionDispatch::IntegrationTest
  test "should get chat" do
    get agent_chat_url
    assert_response :success
  end
end
