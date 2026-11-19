require "application_system_test_case"

class ChatComposerTest < ApplicationSystemTestCase
  include Warden::Test::Helpers

  setup do
    sender = User.create!(email: "browser-sender@example.com", password: "password123", display_name: "Sender")
    recipient = User.create!(email: "browser-recipient@example.com", password: "password123", display_name: "Recipient")
    @conversation = Conversation.find_or_create_direct(sender, recipient)
    @sender = sender
    login_as sender, scope: :user
  end

  teardown { Warden.test_reset! }

  test "composer picker sends an emoji message" do
    visit conversation_path(@conversation)
    find('button[data-action="click->composer-emoji#toggle"]').click
    picker = find('[data-composer-emoji-target="panel"]')
    button = picker.all("button[data-emoji]").first
    emoji = button["data-emoji"]
    button.click
    assert_field "message_content", with: emoji
    find('[data-voice-recorder-target="sendBtn"]').click
    within("#messages") { assert_text emoji }
    assert_equal emoji, @conversation.messages.last.content
  end

  test "microphone records reviews and sends a voice message" do
    visit conversation_path(@conversation)
    find('[data-voice-recorder-target="micBtn"]').click
    assert_selector '[data-voice-recorder-target="timer"]', text: "0:01", wait: 15
    find('[data-voice-recorder-target="micBtn"]').click
    assert_selector '[data-voice-recorder-target="reviewBar"]', wait: 15
    find('[data-voice-recorder-target="sendVoiceBtn"]').click
    assert_selector '[data-controller~="audio-player"]', wait: 15
    assert @conversation.messages.last.type_audio?
    assert @conversation.messages.last.attachment.attached?
  end

  test "uploads crops and sends a sticker" do
    page.current_window.resize_to(780, 480)
    visit conversation_path(@conversation)
    find('[data-sticker-picker-target="uploadInput"]', visible: :all)
      .attach_file(Rails.root.join("public/icon.png"), make_visible: true)
    assert_selector "#sticker-crop-modal .cropper-container", wait: 15
    find("#crop-shape-square").click
    find("#sticker-crop-send").click
    assert_selector '#messages img[src*="/rails/active_storage/"]', wait: 15
    assert @conversation.messages.last.type_sticker?
    assert_equal 1, @sender.stickers.count
  end

  test "displays a link preview card" do
    @conversation.messages.create!(sender: @sender, content: "https://example.com/article", metadata: {
      "link_preview" => { "url" => "https://example.com/article", "title" => "Example preview" }
    })
    visit conversation_path(@conversation)
    within("#messages") do
      assert_selector 'a[href="https://example.com/article"]', text: "Example preview"
    end
  end
end
