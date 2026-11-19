require "test_helper"

class ChatMessagesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @sender = User.create!(email: "sender@example.com", password: "password123", display_name: "Sender")
    @recipient = User.create!(email: "recipient@example.com", password: "password123", display_name: "Recipient")
    @outsider = User.create!(email: "outsider@example.com", password: "password123", display_name: "Outsider")
    @conversation = Conversation.find_or_create_direct(@sender, @recipient)
    sign_in @sender
  end

  test "sends emoji text without losing Unicode" do
    post conversation_messages_path(@conversation), params: { message: { content: "Olá 👋🏽 ❤️ 😀" } }
    assert_response :redirect
    assert_equal "Olá 👋🏽 ❤️ 😀", @conversation.messages.last.content
  end

  test "voice upload persists audio and renders its player" do
    post send_voice_conversation_messages_path(@conversation), params: { audio: upload("voice.webm", "audio/webm", "test audio") }
    assert_response :redirect
    message = @conversation.messages.last
    assert message.type_audio?
    assert_equal "test audio", message.attachment.download
    get conversation_path(@conversation)
    assert_response :success
    assert_select '[data-controller~="audio-player"]'
  end

  test "creates and sends a personal sticker" do
    post stickers_path, params: { sticker: { name: "Hello", image: upload("hello.png", "image/png", png) } }
    assert_response :created
    sticker = @sender.stickers.last
    post send_sticker_conversation_messages_path(@conversation), params: { sticker_id: sticker.id }
    assert_response :redirect
    assert @conversation.messages.last.type_sticker?
    assert_equal sticker.image.blob, @conversation.messages.last.attachment.blob
  end

  test "cannot use another user's sticker" do
    sticker = @recipient.stickers.create!(image: upload("hello.png", "image/png", png))
    assert_no_difference "Message.count" do
      post send_sticker_conversation_messages_path(@conversation), params: { sticker_id: sticker.id }
    end
    assert_response :not_found
  end

  test "outsider cannot send voice or stickers into a conversation" do
    sign_out @sender
    sign_in @outsider
    assert_no_difference "Message.count" do
      post send_voice_conversation_messages_path(@conversation), params: { audio: upload("voice.webm", "audio/webm", "audio") }
      assert_response :not_found
      sign_in @outsider
      post send_sticker_conversation_messages_path(@conversation), params: { sticker_file: upload("hello.png", "image/png", png) }
      assert_response :not_found
    end
  end

  test "forwards audio with attachment and no text" do
    source = @conversation.messages.build(sender: @sender, message_type: :audio)
    source.attachment.attach(upload("voice.webm", "audio/webm", "audio"))
    source.save!
    target = Conversation.find_or_create_direct(@sender, @outsider)
    post forward_conversation_messages_path(@conversation), params: { message_id: source.id, target_conversation_id: target.id }, as: :json
    assert_response :success
    forwarded = target.messages.last
    assert_equal source, forwarded.forwarded_from
    assert_equal source.attachment.blob, forwarded.attachment.blob
  end

  test "link messages enqueue a preview job" do
    assert_enqueued_with(job: LinkPreviewJob) do
      post conversation_messages_path(@conversation), params: { message: { content: "Veja https://example.com" } }
    end
    assert_response :redirect
  end

  private

  def upload(name, type, contents)
    file = Tempfile.new([ "chat-test", File.extname(name) ])
    file.binmode
    file.write(contents)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, type, original_filename: name)
  end

  def png
    Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=")
  end
end
